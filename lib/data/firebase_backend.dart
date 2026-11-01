import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../models/filters.dart';
import '../models/match_profile.dart';
import '../models/notification_item.dart';
import '../models/proposal.dart';
import '../models/verification_doc.dart';
import 'backend.dart';

/// [Backend] on Firebase. Reads Firestore directly where rules allow it; every
/// decision with consequences goes through a Cloud Function.
class FirebaseBackend implements Backend {
  FirebaseBackend({this.pushAvailable = true})
      : _auth = FirebaseAuth.instance,
        _db = FirebaseFirestore.instance,
        _storage = FirebaseStorage.instance,
        _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  /// Points every service at the local emulators. The emulators have no
  /// Cloud Messaging, so push stays off.
  factory FirebaseBackend.emulator(String host) {
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instanceFor(region: 'asia-south1').useFunctionsEmulator(host, 5001);
    FirebaseStorage.instance.useStorageEmulator(host, 9199);
    unawaited(FirebaseAuth.instance.useAuthEmulator(host, 9099));
    return FirebaseBackend(pushAvailable: false);
  }

  final bool pushAvailable;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  bool _googleReady = false;
  StreamSubscription<String>? _tokenSub;
  int? _resendToken;
  String? _resendPhone;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable') throw BackendException(_offline, code: e.code);
      if ((e.details as Map<dynamic, dynamic>?)?['reason'] == 'requires-recent-login') {
        throw BackendException(e.message ?? _generic, code: 'requires-recent-login');
      }
      throw BackendException(
        e.code == 'internal' ? _generic : (e.message ?? _generic),
        code: e.code,
      );
    } on FirebaseAuthException catch (e) {
      throw BackendException(_authMessage(e.code), code: e.code);
    } on FirebaseException catch (e) {
      throw BackendException(
        BackendException.kindOf(e.code) == FailureKind.offline ? _offline : _generic,
        code: e.code,
      );
    } on SocketException {
      throw const BackendException(_offline, code: 'unavailable');
    }
  }

  static const String _generic = 'Something went wrong. Please try again.';
  static const String _offline = 'You appear to be offline.';

  static String _authMessage(String code) => switch (code) {
        'invalid-verification-code' => 'That code is not correct.',
        'session-expired' => 'That code has expired. Request a new one.',
        'too-many-requests' => 'Too many attempts. Please try again later.',
        'invalid-phone-number' => 'Enter a valid phone number.',
        'network-request-failed' => _offline,
        'credential-already-in-use' || 'account-exists-with-different-credential' =>
          'This number already has an account. Sign in with it instead.',
        'requires-recent-login' => 'Please verify it is you, then try again.',
        _ => _generic,
      };

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) =>
      _guard(() async {
        final HttpsCallableResult<dynamic> res =
            await _functions.httpsCallable(name).call<dynamic>(data);
        return Map<String, dynamic>.from(res.data as Map? ?? const <String, dynamic>{});
      });

  // ─── Auth ──────────────────────────────────────────────────────────────────

  @override
  Stream<AuthUser?> get authChanges =>
      _auth.idTokenChanges().asyncMap((User? user) async {
        if (user == null) return null;
        final IdTokenResult token = await user.getIdTokenResult();
        return AuthUser(
          uid: user.uid,
          phone: user.phoneNumber ?? '',
          email: user.email ?? '',
          isApproved: token.claims?['approved'] == true,
          isReviewer: token.claims?['reviewer'] == true,
        );
      });

  /// Links to the signed-in account when there is one, otherwise signs in, so
  /// one number can only ever belong to one account.
  Future<void> _apply(PhoneAuthCredential credential) async {
    final User? current = _auth.currentUser;
    if (current == null) {
      await _auth.signInWithCredential(credential);
    } else if ((current.phoneNumber ?? '').isNotEmpty) {
      // Proves it is them again, before something like account deletion.
      await current.reauthenticateWithCredential(credential);
    } else {
      await current.linkWithCredential(credential);
      await current.getIdToken(true);
    }
  }

  @override
  Future<String?> sendOtp(String e164Phone) {
    final Completer<String?> done = Completer<String?>();
    unawaited(_auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      timeout: const Duration(seconds: 60),
      // A resend for the same number keeps its place with the SMS provider.
      forceResendingToken: _resendPhone == e164Phone ? _resendToken : null,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android can read the code itself.
        try {
          await _apply(credential);
          if (!done.isCompleted) done.complete(null);
        } on FirebaseAuthException catch (e) {
          if (!done.isCompleted) {
            done.completeError(BackendException(_authMessage(e.code), code: e.code));
          }
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!done.isCompleted) {
          done.completeError(BackendException(_authMessage(e.code), code: e.code));
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _resendToken = resendToken;
        _resendPhone = e164Phone;
        if (!done.isCompleted) done.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    ));
    return done.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw const BackendException(
        'We could not send a code. Please try again.',
        code: 'unavailable',
      ),
    );
  }

  @override
  Future<void> confirmOtp(String verificationId, String code) => _guard(() => _apply(
        PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code),
      ));

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        if (!_googleReady) {
          await GoogleSignIn.instance.initialize();
          _googleReady = true;
        }
        final GoogleSignInAccount account =
            await GoogleSignIn.instance.authenticate();
        await _auth.signInWithCredential(GoogleAuthProvider.credential(
          idToken: account.authentication.idToken,
        ));
      });

  @override
  Future<void> refreshClaims() async {
    await _auth.currentUser?.getIdToken(true);
  }

  @override
  Future<void> signOut() async {
    final String? uid = _auth.currentUser?.uid;
    await _tokenSub?.cancel();
    if (uid != null && pushAvailable) {
      // ignore: deprecated_member_use
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _db.doc('accounts/$uid/devices/$token').delete();
      }
    }
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    await _call('requestAccountDeletion');
    await _auth.signOut();
  }

  // ─── Account and draft ─────────────────────────────────────────────────────

  @override
  Stream<AccountState> watchAccount(String uid) =>
      _db.doc('accounts/$uid').snapshots().map((DocumentSnapshot<Map<String, dynamic>> s) {
        final Map<String, dynamic> d = s.data() ?? const <String, dynamic>{};
        final DateTime now = DateTime.now().toUtc();
        final String day = now.toIso8601String().substring(0, 10);
        final String month = now.toIso8601String().substring(0, 7);
        return AccountState(
          // A held member is back under review until a reviewer decides.
          stage: d['held'] == true ? ReviewStage.submitted : ReviewStage.fromWire(d['stage']),
          rejectionReason: d['rejectionReason'] as String? ?? '',
          rejectedPhotos: (d['rejectedPhotos'] as List?)?.cast<String>() ?? const <String>[],
          editsPending: d['editsPending'] as bool? ?? false,
          proposalsSentToday: d['proposalDay'] == day ? (d['proposalCount'] as int? ?? 0) : 0,
          decisionsToday: d['decisionDay'] == day ? (d['decisionCount'] as int? ?? 0) : 0,
          contactCreditsLeft: (d['purchasedCredits'] as int? ?? 0) -
              (d['creditMonth'] == month ? (d['creditsSpent'] as int? ?? 0) : 0),
          premiumUntil: (d['premiumUntil'] as Timestamp?)?.toDate(),
          plan: d['plan'] as String? ?? '',
          familyOf: d['familyOf'] as String?,
          subjectOf: d['subjectOf'] as String?,
          subjectCode: d['subjectCode'] as String? ?? '',
          subjectConfirmed: d['subjectConfirmed'] as bool? ?? false,
          paused: d['paused'] as bool? ?? false,
        );
      });

  @override
  Stream<AppLimits> watchLimits() =>
      _db.doc('config/app').snapshots().map((DocumentSnapshot<Map<String, dynamic>> s) {
        final Map<String, dynamic> l =
            (s.data()?['limits'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        return AppLimits(
          proposalsPerDay: l['proposalsPerDay'] as int? ?? 5,
          decisionsPerDay: l['decisionsPerDay'] as int? ?? 10,
          pendingLimit: l['pendingLimit'] as int? ?? 15,
          monthlyContactCredits: l['monthlyContactCredits'] as int? ?? 30,
          requireIdProof: l['requireIdProof'] as bool? ?? true,
          graduatesOnly: l['graduatesOnly'] as bool? ?? true,
          subscriptionIds: _productIds(s.data()?['products'], 'subscription') ?? const AppLimits().subscriptionIds,
          creditIds: _productIds(s.data()?['products'], 'credits') ?? const AppLimits().creditIds,
        );
      });

  static Set<String>? _productIds(Object? products, String kind) {
    if (products is! Map) return null;
    return <String>{
      for (final MapEntry<dynamic, dynamic> e in products.entries)
        if ((e.value as Map?)?['kind'] == kind) e.key as String,
    };
  }

  @override
  Future<Map<String, dynamic>?> loadDraft(String uid) => _guard(() async {
        return (await _db.doc('drafts/$uid').get()).data();
      });

  @override
  Future<void> saveDraft(String uid, Map<String, dynamic> draft) => _guard(() async {
        await _db.doc('drafts/$uid').set(draft, SetOptions(merge: true));
      });

  @override
  Future<void> submitProfile() => _call('submitProfile');

  @override
  Future<String> uploadPhoto(String uid, String localPath, {void Function(double)? onProgress}) =>
      _guard(() async {
        final String path = 'photos/$uid/${DateTime.now().microsecondsSinceEpoch}.jpg';
        final UploadTask task = _storage.ref(path).putFile(
              File(localPath),
              SettableMetadata(contentType: 'image/jpeg'),
            );
        final StreamSubscription<TaskSnapshot> progress = task.snapshotEvents.listen(
          (TaskSnapshot s) {
            if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
          },
          onError: (Object _) {},
        );
        try {
          await task;
        } finally {
          await progress.cancel();
        }
        return path;
      });

  @override
  Future<String> photoUrl(String storagePath) =>
      _guard(() => _storage.ref(storagePath).getDownloadURL());

  @override
  Future<void> deletePhoto(String storagePath) =>
      _guard(() => _storage.ref(storagePath).delete());

  // ─── Discovery ─────────────────────────────────────────────────────────────

  @override
  Future<IntroductionPage> fetchIntroductions(MatchFilters f, int? cursor, {bool nearby = false}) async {
    final Map<String, dynamic> res = await _call('fetchIntroductions', <String, dynamic>{
      if (nearby) 'mode': 'nearby',
      'filters': <String, dynamic>{
        'minAge': f.minAge,
        'maxAge': f.maxAge,
        'maritalStatus': f.marriageStatus,
        'caste': f.caste,
        'almaMater': f.almaMater,
        'education': f.education,
        'profession': f.profession,
        // The Location row offers countries.
        'country': f.location,
        'sect': f.sect,
        'query': f.query,
      },
      'cursor': cursor,
    });
    return IntroductionPage(
      _cards(res['profiles']),
      (res['cursor'] as num?)?.toInt(),
      freeLeft: (res['freeLeft'] as num?)?.toInt(),
      freeLimit: (res['freeLimit'] as num?)?.toInt() ?? 15,
      limitReached: res['limitReached'] as bool? ?? false,
    );
  }

  static List<MatchProfile> _cards(dynamic list) => (list as List? ?? const <dynamic>[])
      .map((dynamic c) => MatchProfile.fromCard(Map<String, dynamic>.from(c as Map)))
      .toList();

  @override
  Future<List<MatchProfile>> getProfiles(List<String> ids) async {
    if (ids.isEmpty) return const <MatchProfile>[];
    final List<MatchProfile> out = <MatchProfile>[];
    for (int i = 0; i < ids.length; i += 30) {
      final List<String> chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      out.addAll(_cards((await _call('getProfiles', <String, dynamic>{'ids': chunk}))['profiles']));
    }
    return out;
  }

  @override
  Future<void> hideProfile(String target) =>
      _call('hideProfile', <String, dynamic>{'target': target});

  // ─── Proposals and contact ─────────────────────────────────────────────────

  @override
  Stream<List<Proposal>> watchProposals(String uid) {
    Proposal map(QueryDocumentSnapshot<Map<String, dynamic>> s) {
      final Map<String, dynamic> d = s.data();
      final bool outgoing = d['from'] == uid;
      return Proposal(
        id: s.id,
        profileId: (outgoing ? d['to'] : d['from']) as String,
        direction: outgoing ? ProposalDirection.outgoing : ProposalDirection.incoming,
        status: ProposalStatus.values.asNameMap()[d['status']] ?? ProposalStatus.pending,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
      );
    }

    final CollectionReference<Map<String, dynamic>> c = _db.collection('proposals');
    return _merge(
      c.where('from', isEqualTo: uid).limit(300).snapshots().map((q) => q.docs.map(map).toList()),
      c.where('to', isEqualTo: uid).limit(300).snapshots().map((q) => q.docs.map(map).toList()),
    );
  }

  /// Latest value of two list streams, concatenated.
  static Stream<List<T>> _merge<T>(Stream<List<T>> a, Stream<List<T>> b) {
    List<T> left = <T>[];
    List<T> right = <T>[];
    late final StreamController<List<T>> out;
    StreamSubscription<List<T>>? sa;
    StreamSubscription<List<T>>? sb;
    out = StreamController<List<T>>(
      onListen: () {
        sa = a.listen((List<T> v) {
          left = v;
          out.add(<T>[...left, ...right]);
        }, onError: out.addError);
        sb = b.listen((List<T> v) {
          right = v;
          out.add(<T>[...left, ...right]);
        }, onError: out.addError);
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> sendProposal(String to) =>
      _call('sendProposal', <String, dynamic>{'to': to});

  @override
  Future<void> respondProposal(String from, {required bool accept}) =>
      _call('respondProposal', <String, dynamic>{'from': from, 'accept': accept});

  @override
  Future<void> withdrawProposal(String to) =>
      _call('withdrawProposal', <String, dynamic>{'to': to});

  @override
  Stream<List<ContactRequestRecord>> watchContactRequests(String uid) {
    ContactRequestRecord map(QueryDocumentSnapshot<Map<String, dynamic>> s) {
      final Map<String, dynamic> d = s.data();
      final bool incoming = d['to'] == uid;
      return ContactRequestRecord(
        profileId: (incoming ? d['from'] : d['to']) as String,
        isIncoming: incoming,
        status: d['status'] as String? ?? 'pending',
      );
    }

    final CollectionReference<Map<String, dynamic>> c = _db.collection('contactRequests');
    return _merge(
      c.where('from', isEqualTo: uid).limit(300).snapshots().map((q) => q.docs.map(map).toList()),
      c.where('to', isEqualTo: uid).limit(300).snapshots().map((q) => q.docs.map(map).toList()),
    );
  }

  @override
  Stream<Map<String, String>> watchSharedContacts(String uid) => _db
      .collection('contactShares')
      .where('users', arrayContains: uid)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> q) {
        final Map<String, String> out = <String, String>{};
        for (final QueryDocumentSnapshot<Map<String, dynamic>> s in q.docs) {
          final String other = (s.data()['users'] as List).cast<String>().firstWhere((String u) => u != uid);
          out[other] = ((s.data()['phones'] as Map?)?[other] as String?) ?? '';
        }
        return out;
      });

  @override
  Future<void> requestContact(String to) =>
      _call('requestContact', <String, dynamic>{'to': to});

  @override
  Future<void> respondContact(String from, {required bool accept}) =>
      _call('respondContact', <String, dynamic>{'from': from, 'accept': accept});

  // ─── Matches and chat ──────────────────────────────────────────────────────

  @override
  Stream<List<MatchThread>> watchMatches(String uid) => _db
      .collection('matches')
      .where('users', arrayContains: uid)
      .limit(200)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> q) => q.docs.map((s) {
            final Map<String, dynamic> d = s.data();
            final String other = (d['users'] as List).cast<String>().firstWhere((String u) => u != uid);
            return MatchThread(
              pairId: s.id,
              otherId: other,
              theirReadAt: ((d['readAt'] as Map?)?[other] as Timestamp?)?.toDate(),
              isOpen: d['status'] == 'active',
              lastMessage: d['lastMessage'] as String? ?? '',
              lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
              unread: ((d['unread'] as Map?)?[uid] as int?) ?? 0,
              myStep: (d['journey'] as Map?)?[uid] as String?,
              theirStep: (d['journey'] as Map?)?[other] as String?,
            );
          }).toList());

  static ChatMessage _message(QueryDocumentSnapshot<Map<String, dynamic>> s, String uid) {
    final Map<String, dynamic> d = s.data();
    final DateTime at = (d['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return ChatMessage(
      id: s.id,
      text: d['text'] as String? ?? '',
      time: DateFormat.jm().format(at),
      createdAt: at,
      sender: d['sender'] == uid ? MessageSender.user : MessageSender.match,
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String pairId, String uid) => _db
      .collection('matches/$pairId/messages')
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> q) =>
          q.docs.reversed.map((s) => _message(s, uid)).toList());

  @override
  Future<List<ChatMessage>> olderMessages(String pairId, String uid, DateTime before) =>
      _guard(() async {
        final QuerySnapshot<Map<String, dynamic>> q = await _db
            .collection('matches/$pairId/messages')
            .orderBy('sentAt', descending: true)
            .startAfter(<Object>[Timestamp.fromDate(before)])
            .limit(30)
            .get();
        return q.docs.reversed.map((s) => _message(s, uid)).toList();
      });

  @override
  Future<void> sendMessage(String pairId, String uid, String text, {required String id}) =>
      _guard(() async {
        final DocumentReference<Map<String, dynamic>> ref =
            _db.doc('matches/$pairId/messages/$id');
        try {
          await ref.set(<String, dynamic>{
            'sender': uid,
            'text': text,
            'sentAt': FieldValue.serverTimestamp(),
          });
        } on FirebaseException catch (e) {
          // A retry of a message that did arrive hits the no-update rule.
          if (e.code != 'permission-denied' || !(await ref.get()).exists) rethrow;
        }
      });

  @override
  Future<void> markThreadRead(String pairId, String uid) => _guard(() async {
        await _db.doc('matches/$pairId').update(<String, dynamic>{
          'readAt.$uid': FieldValue.serverTimestamp(),
          'unread.$uid': 0,
        });
      });

  @override
  Future<void> unmatch(String other) =>
      _call('unmatch', <String, dynamic>{'other': other});

  @override
  Future<void> blockProfile(String target) =>
      _call('blockProfile', <String, dynamic>{'target': target});

  @override
  Future<void> reportProfile(String target, String reason, {String details = '', String context = 'profile'}) =>
      _call('reportProfile', <String, dynamic>{
        'target': target,
        'reason': reason,
        if (details.isNotEmpty) 'details': details,
        'context': context,
      });

  @override
  Future<void> updatePrivacy({
    String? photoPrivacy,
    bool? showCaste,
    bool? allowFamilyShare,
    bool? nearbyOptIn,
    bool? allowContactRequests,
  }) =>
      _call('updatePrivacy', <String, dynamic>{
        'allowContactRequests': ?allowContactRequests,
        'photoPrivacy': ?photoPrivacy,
        'showCaste': ?showCaste,
        'allowFamilyShare': ?allowFamilyShare,
        'nearbyOptIn': ?nearbyOptIn,
      });

  @override
  Future<void> touchActive() => _call('touchActive');

  // ─── Invites and edits ─────────────────────────────────────────────────────

  @override
  Future<InviteInfo> getInviteCode() async {
    final Map<String, dynamic> res = await _call('getInviteCode');
    return InviteInfo(
      res['code'] as String,
      (res['invited'] as num?)?.toInt() ?? 0,
      (res['earned'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> submitEdits() => _call('submitEdits');

  // ─── Family Circle ─────────────────────────────────────────────────────────

  @override
  Stream<FamilyState> watchFamily(String member) {
    final DocumentReference<Map<String, dynamic>> root = _db.doc('family/$member');
    Map<String, String> names = <String, String>{};
    List<FamilyPick> picks = <FamilyPick>[];
    late final StreamController<FamilyState> out;
    StreamSubscription<dynamic>? a;
    StreamSubscription<dynamic>? b;
    void emit() => out.add(FamilyState(guardians: names, shortlist: picks));
    out = StreamController<FamilyState>(
      onListen: () {
        a = root.snapshots().listen((DocumentSnapshot<Map<String, dynamic>> s) {
          names = (s.data()?['names'] as Map?)?.cast<String, String>() ?? <String, String>{};
          emit();
        }, onError: out.addError);
        b = root.collection('shortlist').snapshots().listen((QuerySnapshot<Map<String, dynamic>> q) {
          picks = q.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> s) {
            final Map<String, dynamic> d = s.data();
            return FamilyPick(
              id: s.id,
              title: '${d['firstName']}, ${d['age']}',
              summary: <dynamic>[d['education'], d['university'], d['profession'], d['location'], d['maritalStatus']]
                  .where((dynamic v) => v is String && v.isNotEmpty)
                  .join(' · '),
              opinions: (d['opinions'] as Map?)?.cast<String, String>() ?? const <String, String>{},
            );
          }).toList();
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await a?.cancel();
        await b?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Stream<FamilyAdmin> watchFamilyAdmin(String member) {
    final DocumentReference<Map<String, dynamic>> root = _db.doc('family/$member');
    List<FamilyMember> members = <FamilyMember>[];
    List<FamilyInvitation> invitations = <FamilyInvitation>[];
    List<FamilyEvent> history = <FamilyEvent>[];
    late final StreamController<FamilyAdmin> out;
    final List<StreamSubscription<dynamic>> subs = <StreamSubscription<dynamic>>[];
    void emit() => out.add(FamilyAdmin(members: members, invitations: invitations, history: history));
    out = StreamController<FamilyAdmin>(
      onListen: () {
        subs.addAll(<StreamSubscription<dynamic>>[
          root.collection('memberships').limit(30).snapshots().listen((QuerySnapshot<Map<String, dynamic>> q) {
            members = q.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> s) => FamilyMember(
                  uid: s.id,
                  name: s.data()['name'] as String? ?? '',
                  relationship: s.data()['relationship'] as String? ?? '',
                  permissions: (s.data()['permissions'] as List?)?.cast<String>() ?? const <String>[],
                )).toList();
            emit();
          }, onError: out.addError),
          root.collection('invitations').orderBy('createdAt', descending: true).limit(30).snapshots()
              .listen((QuerySnapshot<Map<String, dynamic>> q) {
            invitations = q.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> s) => FamilyInvitation(
                  id: s.id,
                  name: s.data()['name'] as String? ?? '',
                  relationship: s.data()['relationship'] as String? ?? '',
                  status: s.data()['status'] as String? ?? 'pending',
                  expiresAt: (s.data()['expiresAt'] as Timestamp?)?.toDate(),
                )).toList();
            emit();
          }, onError: out.addError),
          root.collection('history').orderBy('at', descending: true).limit(30).snapshots()
              .listen((QuerySnapshot<Map<String, dynamic>> q) {
            history = q.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> s) => FamilyEvent(
                  action: s.data()['action'] as String? ?? '',
                  at: (s.data()['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
                )).toList();
            emit();
          }, onError: out.addError),
        ]);
      },
      onCancel: () async {
        for (final StreamSubscription<dynamic> s in subs) {
          await s.cancel();
        }
      },
    );
    return out.stream;
  }

  @override
  Future<String> createFamilyInvite({
    required String name,
    required String relationship,
    required String phone,
    required List<String> permissions,
  }) async =>
      (await _call('createFamilyInvite', <String, dynamic>{
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'permissions': permissions,
      }))['code'] as String;

  @override
  Future<void> joinFamily(String code) => _call('joinFamily', <String, dynamic>{'code': code});

  @override
  Future<void> removeGuardian(String guardian, {String? member}) =>
      _call('removeGuardian', <String, dynamic>{'guardian': guardian, 'member': ?member});

  @override
  Future<void> rejectFamilyInvite(String code) =>
      _call('rejectFamilyInvite', <String, dynamic>{'code': code});

  @override
  Future<void> cancelFamilyInvite(String id) =>
      _call('cancelFamilyInvite', <String, dynamic>{'id': id});

  @override
  Future<String> resendFamilyInvite(String id) async =>
      (await _call('resendFamilyInvite', <String, dynamic>{'id': id}))['code'] as String;

  @override
  Future<void> updateGuardianPermissions(String guardian, List<String> permissions) =>
      _call('updateGuardianPermissions', <String, dynamic>{
        'guardian': guardian,
        'permissions': permissions,
      });

  @override
  Future<FamilyOverview> familyOverview(String member) async {
    final Map<String, dynamic> res = await _call('familyOverview', <String, dynamic>{'member': member});
    final Map<dynamic, dynamic>? p = res['profile'] as Map<dynamic, dynamic>?;
    String line(Map<dynamic, dynamic> m, List<String> keys) => keys
        .map((String k) => '${m[k] ?? ''}')
        .where((String v) => v.isNotEmpty)
        .join(' · ');
    return FamilyOverview(
      permissions: (res['permissions'] as List?)?.cast<String>() ?? const <String>[],
      profileSummary: p == null ? null : line(p, <String>['name', 'education', 'profession', 'location']),
      proposals: (res['proposals'] as List?)?.map((dynamic raw) {
        final Map<dynamic, dynamic> m = raw as Map<dynamic, dynamic>;
        return FamilyProposal(
          from: m['from'] as String,
          summary: line(m, <String>['firstName', 'education', 'profession', 'location']),
        );
      }).toList(),
    );
  }

  @override
  Future<void> familyRespondProposal(String member, String from, {required bool accept}) =>
      _call('familyRespondProposal', <String, dynamic>{
        'member': member,
        'from': from,
        'accept': accept,
      });

  @override
  Future<void> confirmSubject(String code, {required bool agree}) =>
      _call('confirmSubject', <String, dynamic>{'code': code, 'agree': agree});

  @override
  Future<void> withdrawSubject() => _call('withdrawSubject');

  @override
  Future<void> setPaused(bool paused) => _call('setAccountPaused', <String, dynamic>{'paused': paused});

  @override
  Future<List<BlockedMember>> listBlocks() async =>
      ((await _call('listBlocks'))['blocks'] as List? ?? const <dynamic>[]).map((dynamic raw) {
        final Map<dynamic, dynamic> m = raw as Map<dynamic, dynamic>;
        return BlockedMember(m['id'] as String, m['name'] as String? ?? 'Member');
      }).toList();

  @override
  Future<void> unblockProfile(String target) =>
      _call('unblockProfile', <String, dynamic>{'target': target});

  @override
  Future<Map<String, dynamic>> exportMyData() => _call('exportMyData');

  @override
  Future<void> shareWithFamily(String profileId) =>
      _call('shareWithFamily', <String, dynamic>{'profile': profileId});

  @override
  Future<void> giveFamilyOpinion(String member, String profileId, String opinion) =>
      _call('giveFamilyOpinion', <String, dynamic>{
        'member': member,
        'profile': profileId,
        'opinion': opinion,
      });

  // ─── Nikah Journey ─────────────────────────────────────────────────────────

  @override
  Future<void> setJourneyStep(String pairId, String uid, String step) => _guard(() async {
        await _db.doc('matches/$pairId').update(<String, dynamic>{'journey.$uid': step});
      });

  @override
  Future<void> saveAnswers(String pairId, String uid, Map<String, String> answers) =>
      _guard(() async {
        await _db.doc('matches/$pairId/answers/$uid').set(<String, dynamic>{
          'answers': answers,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Future<Map<String, String>?> loadAnswers(String pairId, String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> s =
          await _db.doc('matches/$pairId/answers/$uid').get();
      return (s.data()?['answers'] as Map?)?.cast<String, String>();
    } on FirebaseException catch (e) {
      // Rules hide the other person's answers until you have given yours.
      if (e.code == 'permission-denied') return null;
      throw const BackendException(_generic);
    }
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  @override
  Stream<List<NotificationItem>> watchNotifications(String uid) => _db
      .collection('accounts/$uid/notifications')
      .orderBy('createdAt', descending: true)
      .limit(40)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> q) => q.docs.reversed.map((s) {
            final Map<String, dynamic> d = s.data();
            return NotificationItem(
              id: s.id,
              type: switch (d['type']) {
                'match' => NotificationType.match,
                'proposal' || 'contact' => NotificationType.intro,
                'message' => NotificationType.chat,
                _ => NotificationType.system,
              },
              title: d['title'] as String? ?? '',
              body: d['body'] as String? ?? '',
              createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isRead: d['read'] as bool? ?? false,
              deepLink: d['deepLink'] as String?,
            );
          }).toList());

  @override
  Future<void> markNotificationRead(String uid, String id) => _guard(() async {
        await _db.doc('accounts/$uid/notifications/$id').update(<String, dynamic>{'read': true});
      });

  @override
  Future<void> registerPushToken(String uid) => _guard(() async {
        if (!pushAvailable) return;
        await FirebaseMessaging.instance.requestPermission();
        // ignore: deprecated_member_use
        final String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) await _registerDevice(token);
        unawaited(_tokenSub?.cancel());
        // ignore: deprecated_member_use
        _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(
          (String next) => unawaited(_registerDevice(next).catchError((Object _) {})),
        );
      });

  Future<void> _registerDevice(String token) =>
      _call('registerDevice', <String, dynamic>{'token': token, 'platform': Platform.operatingSystem});

  @override
  Stream<Map<String, bool>> watchNotificationPrefs(String uid) => _db
      .doc('accounts/$uid/settings/notifications')
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> s) =>
          (s.data() ?? const <String, dynamic>{}).cast<String, bool>());

  @override
  Future<void> setNotificationPref(String uid, String category, bool on) => _guard(() async {
        await _db
            .doc('accounts/$uid/settings/notifications')
            .set(<String, dynamic>{category: on}, SetOptions(merge: true));
      });

  // ─── Verification ──────────────────────────────────────────────────────────

  @override
  Stream<List<VerificationDoc>> watchDocuments(String uid) => _db
      .collection('accounts/$uid/documents')
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> q) {
        final Map<String, Map<String, dynamic>> byType = <String, Map<String, dynamic>>{
          for (final QueryDocumentSnapshot<Map<String, dynamic>> s in q.docs) s.id: s.data(),
        };
        return VerificationDoc.blank.map((VerificationDoc doc) {
          final Map<String, dynamic>? d = byType[doc.id];
          if (d == null) return doc;
          return doc.copyWith(
            status: VerificationDocStatus.fromWire(d['status']),
            rejectionReason: d['rejectionReason'] as String? ?? '',
          );
        }).toList();
      });

  @override
  Future<void> submitDocument(String uid, String type, List<String> localPaths) async {
    final List<String> paths = await _guard(() async {
      final List<String> uploaded = <String>[];
      for (final String local in localPaths) {
        final String lower = local.toLowerCase();
        final (String ext, String type_) = lower.endsWith('.pdf')
            ? ('pdf', 'application/pdf')
            : lower.endsWith('.png')
                ? ('png', 'image/png')
                : lower.endsWith('.webp')
                    ? ('webp', 'image/webp')
                    : ('jpg', 'image/jpeg');
        final String path = 'verification/$uid/$type/${DateTime.now().microsecondsSinceEpoch}.$ext';
        await _storage.ref(path).putFile(File(local), SettableMetadata(contentType: type_));
        uploaded.add(path);
      }
      return uploaded;
    });
    await _call('submitDocument', <String, dynamic>{'type': type, 'paths': paths});
  }

  // ─── Purchases ─────────────────────────────────────────────────────────────

  @override
  Future<void> validatePurchase({
    required String productId,
    required String platform,
    required String token,
  }) =>
      _call('validatePurchase', <String, dynamic>{
        'productId': productId,
        'platform': platform,
        'token': token,
      });

  @override
  Stream<List<PurchaseRecord>> watchPurchases(String uid) => _db
      .collection('purchases')
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> q) => q.docs.map((s) {
            final Map<String, dynamic> d = s.data();
            return PurchaseRecord(
              productId: d['productId'] as String? ?? '',
              state: d['state'] as String? ?? '',
              createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              expiresAt: d['expiresAt'] == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch((d['expiresAt'] as num).toInt()),
            );
          }).toList());

  // ─── Review tools ──────────────────────────────────────────────────────────

  @override
  Future<List<Map<String, dynamic>>> listReviewQueue() async {
    final Map<String, dynamic> res = await _call('listReviewQueue');
    return (res['items'] as List? ?? const <dynamic>[])
        .map((dynamic i) => Map<String, dynamic>.from(i as Map))
        .toList();
  }

  @override
  Future<List<ReportItem>> listReports() async {
    final Map<String, dynamic> res = await _call('listReports');
    return (res['reports'] as List? ?? const <dynamic>[]).map((dynamic raw) {
      final Map<dynamic, dynamic> r = raw as Map<dynamic, dynamic>;
      return ReportItem(
        id: r['id'] as String,
        target: r['target'] as String,
        name: r['name'] as String? ?? '',
        reason: r['reason'] as String? ?? '',
        details: r['details'] as String? ?? '',
        context: r['context'] as String? ?? 'profile',
        held: r['held'] as bool? ?? false,
        count: (r['count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  @override
  Future<void> resolveReport(String id, {required String decision, String note = ''}) =>
      _call('resolveReport', <String, dynamic>{
        'id': id,
        'decision': decision,
        if (note.isNotEmpty) 'note': note,
      });

  @override
  Future<void> releaseHold(String uid) => _call('releaseHold', <String, dynamic>{'uid': uid});

  @override
  Future<List<String>> documentUrls(String uid, String type) async {
    final Map<String, dynamic> res =
        await _call('getDocumentUrl', <String, dynamic>{'uid': uid, 'type': type});
    return (res['urls'] as List? ?? const <dynamic>[]).cast<String>();
  }

  @override
  Future<void> reviewProfile(
    String uid, {
    required String decision,
    required int version,
    String reason = '',
    List<String> rejectedPhotos = const <String>[],
  }) =>
      _call('reviewProfile', <String, dynamic>{
        'uid': uid,
        'decision': decision,
        'version': version,
        'reason': reason,
        'rejectedPhotos': rejectedPhotos,
      });

  @override
  Future<void> reviewDocument(
    String uid,
    String type, {
    required String decision,
    String reason = '',
  }) =>
      _call('reviewDocument', <String, dynamic>{
        'uid': uid,
        'type': type,
        'decision': decision,
        'reason': reason,
      });
}
