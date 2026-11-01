import 'dart:async';

import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/filters.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/models/notification_item.dart';
import 'package:nikah_app/models/proposal.dart';
import 'package:nikah_app/models/verification_doc.dart';

MatchProfile card(String id) => MatchProfile.fromCard(<String, dynamic>{
      'id': id,
      'name': 'Member $id',
      'age': 27,
      'photos': <String>['https://example.com/$id.jpg'],
    });

/// In-memory [Backend]. Records calls and lets a test push server state.
class FakeBackend implements Backend {
  final StreamController<AuthUser?> auth = StreamController<AuthUser?>.broadcast();
  final StreamController<AccountState> account = StreamController<AccountState>.broadcast();
  final StreamController<AppLimits> limits = StreamController<AppLimits>.broadcast();
  final StreamController<List<Proposal>> proposals = StreamController<List<Proposal>>.broadcast();
  final StreamController<List<String>> bookmarks = StreamController<List<String>>.broadcast();
  final StreamController<List<MatchThread>> matches = StreamController<List<MatchThread>>.broadcast();
  final StreamController<List<ChatMessage>> messages = StreamController<List<ChatMessage>>.broadcast();
  final StreamController<Map<String, String>> shares = StreamController<Map<String, String>>.broadcast();
  final StreamController<List<ContactRequestRecord>> contacts = StreamController<List<ContactRequestRecord>>.broadcast();
  final StreamController<List<NotificationItem>> notifications = StreamController<List<NotificationItem>>.broadcast();
  final StreamController<List<VerificationDoc>> documents = StreamController<List<VerificationDoc>>.broadcast();

  final List<String> calls = <String>[];
  Map<String, dynamic>? draft;
  Map<String, dynamic>? savedDraft;
  List<IntroductionPage> pages = <IntroductionPage>[];

  /// Profiles the server refuses to return.
  final Set<String> hiddenProfiles = <String>{};

  /// Full profiles, in place of the one-photo card.
  Map<String, MatchProfile> fullProfiles = <String, MatchProfile>{};

  /// Holds the next page back until completed.
  Completer<void>? gate;
  Object? failNext;
  Object? failDraft;

  /// Fails only the next call whose name starts with this.
  String? failOn;
  Object? failSend;
  String lastQuery = '';
  bool lastNearby = false;
  int messageListeners = 0;
  List<ChatMessage> olderPage = <ChatMessage>[];
  final List<String> sentIds = <String>[];

  Future<void> _record(String call) async {
    calls.add(call);
    if (failOn != null && call.startsWith(failOn!)) {
      failOn = null;
      throw const BackendException('refused');
    }
    final Object? failure = failNext;
    failNext = null;
    if (failure != null) throw failure;
  }

  @override
  Stream<AuthUser?> get authChanges => auth.stream;
  @override
  Future<String?> sendOtp(String e164Phone) async => 'verification';
  @override
  Future<void> confirmOtp(String verificationId, String code) => _record('confirmOtp');
  @override
  Future<void> signInWithGoogle() => _record('google');
  @override
  Future<void> refreshClaims() => _record('refreshClaims');
  @override
  Future<void> signOut() => _record('signOut');
  @override
  Future<void> deleteAccount() => _record('deleteAccount');
  @override
  Stream<AccountState> watchAccount(String uid) => account.stream;
  @override
  Stream<AppLimits> watchLimits() => limits.stream;
  @override
  Future<Map<String, dynamic>?> loadDraft(String uid) async {
    final Object? failure = failDraft;
    failDraft = null;
    if (failure != null) throw failure;
    return draft;
  }
  @override
  Future<void> saveDraft(String uid, Map<String, dynamic> d) async {
    savedDraft = d;
    await _record('saveDraft');
  }

  @override
  Future<void> submitProfile() => _record('submitProfile');
  @override
  Future<String> uploadPhoto(String uid, String localPath, {void Function(double)? onProgress}) async {
    onProgress?.call(1);
    return 'photos/$uid/1.jpg';
  }

  @override
  Future<String> photoUrl(String storagePath) async => 'https://example.com/p.jpg';
  @override
  Future<void> deletePhoto(String storagePath) => _record('deletePhoto');

  @override
  Future<IntroductionPage> fetchIntroductions(MatchFilters filters, int? cursor, {bool nearby = false}) async {
    lastQuery = filters.query;
    lastNearby = nearby;
    await _record('fetchIntroductions:$cursor');
    final Completer<void>? held = gate;
    gate = null;
    await held?.future;
    return pages.isEmpty ? const IntroductionPage(<MatchProfile>[], null) : pages.removeAt(0);
  }

  @override
  Future<List<MatchProfile>> getProfiles(List<String> ids) async {
    await _record('getProfiles');
    return ids
        .where((String id) => !hiddenProfiles.contains(id))
        .map((String id) => fullProfiles[id] ?? card(id))
        .toList();
  }

  @override
  Future<void> hideProfile(String target) => _record('hide:$target');
  @override
  Stream<List<String>> watchBookmarks(String uid) => bookmarks.stream;
  @override
  Future<void> setBookmark(String target, {required bool saved}) => _record('bookmark:$target:$saved');
  @override
  Stream<List<Proposal>> watchProposals(String uid) => proposals.stream;
  @override
  Future<void> sendProposal(String to) => _record('propose:$to');
  @override
  Future<void> respondProposal(String from, {required bool accept}) =>
      _record('respond:$from:$accept');
  @override
  Future<void> withdrawProposal(String to) => _record('withdraw:$to');
  @override
  Stream<List<ContactRequestRecord>> watchContactRequests(String uid) => contacts.stream;
  @override
  Stream<Map<String, String>> watchSharedContacts(String uid) => shares.stream;
  @override
  Future<void> requestContact(String to) => _record('contact:$to');
  @override
  Future<void> respondContact(String from, {required bool accept}) =>
      _record('respondContact:$from:$accept');
  @override
  Stream<List<MatchThread>> watchMatches(String uid) => matches.stream;
  @override
  Stream<List<ChatMessage>> watchMessages(String pairId, String uid) {
    messageListeners++;
    return messages.stream;
  }

  @override
  Future<List<ChatMessage>> olderMessages(String pairId, String uid, DateTime before) async => olderPage;
  @override
  Future<void> sendMessage(String pairId, String uid, String text, {required String id}) async {
    sentIds.add(id);
    final Object? failure = failSend;
    failSend = null;
    if (failure != null) throw failure;
    await _record('message:$pairId:$text');
  }

  @override
  Future<void> markThreadRead(String pairId, String uid) => _record('read:$pairId');
  @override
  Future<void> unmatch(String other) => _record('unmatch:$other');
  @override
  Future<void> blockProfile(String target) => _record('block:$target');
  @override
  Future<void> reportProfile(String target, String reason, {String details = '', String context = 'profile'}) =>
      _record('report:$target:$reason:$context');
  @override
  Future<void> updatePrivacy({
    String? photoPrivacy,
    bool? showCaste,
    bool? allowFamilyShare,
    bool? nearbyOptIn,
    bool? allowContactRequests,
  }) =>
      _record('privacy:$photoPrivacy');
  @override
  Future<void> touchActive() => _record('touchActive');
  final StreamController<FamilyState> familyStream = StreamController<FamilyState>.broadcast();
  @override
  Future<InviteInfo> getInviteCode() async => const InviteInfo('ABC234', 1, 2);
  @override
  Future<void> submitEdits() => _record('submitEdits');
  @override
  Stream<FamilyState> watchFamily(String member) => familyStream.stream;
  final StreamController<FamilyAdmin> familyAdmin = StreamController<FamilyAdmin>.broadcast();
  FamilyOverview overview = const FamilyOverview();
  List<BlockedMember> blocks = <BlockedMember>[];
  @override
  Stream<FamilyAdmin> watchFamilyAdmin(String member) => familyAdmin.stream;
  @override
  Future<void> rejectFamilyInvite(String code) => _record('rejectInvite:$code');
  @override
  Future<void> cancelFamilyInvite(String id) => _record('cancelInvite:$id');
  @override
  Future<String> resendFamilyInvite(String id) async {
    await _record('resendInvite:$id');
    return 'NEW234';
  }

  @override
  Future<void> updateGuardianPermissions(String guardian, List<String> permissions) =>
      _record('permissions:$guardian:${permissions.join(',')}');
  @override
  Future<FamilyOverview> familyOverview(String member) async {
    await _record('overview:$member');
    return overview;
  }

  @override
  Future<void> familyRespondProposal(String member, String from, {required bool accept}) =>
      _record('familyAnswer:$member:$from:$accept');
  @override
  Future<void> confirmSubject(String code, {required bool agree}) => _record('subject:$code:$agree');
  @override
  Future<void> withdrawSubject() => _record('withdrawSubject');
  @override
  Future<void> setPaused(bool paused) => _record('paused:$paused');
  @override
  Future<List<BlockedMember>> listBlocks() async => blocks;
  @override
  Future<void> unblockProfile(String target) => _record('unblock:$target');
  @override
  Future<Map<String, dynamic>> exportMyData() async => <String, dynamic>{'draft': <String, dynamic>{'fullName': 'Sara'}};
  @override
  Future<String> createFamilyInvite({
    required String name,
    required String relationship,
    required String phone,
    required List<String> permissions,
  }) async {
    await _record('invite:$relationship:${permissions.join(',')}');
    return 'FAM234';
  }
  @override
  Future<void> joinFamily(String code) => _record('join:$code');
  @override
  Future<void> removeGuardian(String guardian, {String? member}) => _record('removeGuardian:$guardian');
  @override
  Future<void> shareWithFamily(String profileId) => _record('shareFamily:$profileId');
  @override
  Future<void> giveFamilyOpinion(String member, String profileId, String opinion) =>
      _record('opinion:$member:$profileId:$opinion');
  final Map<String, Map<String, String>> answers = <String, Map<String, String>>{};
  @override
  Future<void> setJourneyStep(String pairId, String uid, String step) => _record('journey:$step');
  @override
  Future<void> saveAnswers(String pairId, String uid, Map<String, String> a) async {
    answers[uid] = a;
    await _record('answers');
  }

  @override
  Future<Map<String, String>?> loadAnswers(String pairId, String uid) async => answers[uid];
  @override
  Stream<List<NotificationItem>> watchNotifications(String uid) => notifications.stream;
  @override
  Future<void> markNotificationRead(String uid, String id) => _record('notified:$id');
  @override
  Future<void> registerPushToken(String uid) => _record('push');
  @override
  Stream<List<VerificationDoc>> watchDocuments(String uid) => documents.stream;
  @override
  Future<void> submitDocument(String uid, String type, List<String> localPaths) =>
      _record('document:$type');
  @override
  Future<void> validatePurchase({required String productId, required String platform, required String token}) =>
      _record('purchase:$productId:$platform');
  final StreamController<List<PurchaseRecord>> purchaseRecords = StreamController<List<PurchaseRecord>>.broadcast();
  final StreamController<Map<String, bool>> notificationPrefs = StreamController<Map<String, bool>>.broadcast();
  @override
  Stream<List<PurchaseRecord>> watchPurchases(String uid) => purchaseRecords.stream;
  @override
  Stream<Map<String, bool>> watchNotificationPrefs(String uid) => notificationPrefs.stream;
  @override
  Future<void> setNotificationPref(String uid, String category, bool on) => _record('pref:$category:$on');
  @override
  Future<List<Map<String, dynamic>>> listReviewQueue() async => queue;
  List<Map<String, dynamic>> queue = <Map<String, dynamic>>[];
  List<ReportItem> reports = <ReportItem>[];
  @override
  Future<List<ReportItem>> listReports() async => reports;
  @override
  Future<void> resolveReport(String id, {required String decision, String note = ''}) =>
      _record('resolveReport:$id:$decision');
  @override
  Future<void> releaseHold(String uid) => _record('releaseHold:$uid');
  @override
  Future<List<String>> documentUrls(String uid, String type) async => const <String>[];
  @override
  Future<void> reviewProfile(
    String uid, {
    required String decision,
    required int version,
    String reason = '',
    List<String> rejectedPhotos = const <String>[],
  }) =>
      _record('reviewProfile:$uid:$decision:$version');
  @override
  Future<void> reviewDocument(String uid, String type, {required String decision, String reason = ''}) =>
      _record('reviewDocument:$uid:$type:$decision');
}
