import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/models/proposal.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/providers/app_store.dart';

/// Builds a store over mock preferences representing a member who has already
/// finished onboarding.
Future<AppStore> _activeStore() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'bk_stage': 'active',
    'bk_onboarded': true,
  });
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppStore store = AppStore(prefs);
  addTearDown(store.dispose);
  return store;
}

void main() {
  group('proposal quota', () {
    test('enforces the daily proposal quota', () async {
      final AppStore store = await _activeStore();

      expect(store.proposalsLeft, AppStore.proposalQuota);
      for (final MatchProfile profile in MatchProfile.seeds) {
        expect(store.sendProposal(profile.id), isTrue);
      }
      expect(store.proposalsLeft, 0);
      expect(store.proposalsSentList.length, MatchProfile.seeds.length);
      expect(store.sendProposal('sixth-slot'), isFalse);
    });

    test('re-proposing to the same profile does not spend another slot',
        () async {
      final AppStore store = await _activeStore();

      expect(store.sendProposal('zayd-1'), isTrue);
      final int left = store.proposalsLeft;
      expect(store.sendProposal('zayd-1'), isTrue);
      expect(store.proposalsLeft, left);
    });
  });

  group('contact requests', () {
    test('spends a credit and leaves the request pending', () async {
      final AppStore store = await _activeStore();

      expect(store.contactCredits, AppStore.monthlyContactCredits);
      expect(store.isContactShared('farhan-2'), isFalse);

      expect(store.requestContact('farhan-2'), isTrue);
      expect(store.contactCredits, AppStore.monthlyContactCredits - 1);
      expect(store.contactRequested('farhan-2'), isTrue);

      // A request must NOT grant itself the other member's consent. Nothing on
      // this device may accept on their behalf, no matter how long we wait.
      expect(store.isContactShared('farhan-2'), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 3000));
      expect(
        store.isContactShared('farhan-2'),
        isFalse,
        reason: 'contact sharing requires the recipient to accept',
      );
    });

    test('a pending request does not create a match', () async {
      final AppStore store = await _activeStore();

      store.requestContact('imran-3');
      await Future<void>.delayed(const Duration(milliseconds: 3000));

      expect(store.isApproved('imran-3'), isFalse);
      expect(
        store.connectedMatches.any((MatchProfile p) => p.id == 'imran-3'),
        isFalse,
        reason: 'a match requires mutual acceptance, not a one-sided request',
      );
    });

    test('contact sharing cannot create a match', () async {
      final AppStore store = await _activeStore();

      expect(store.acceptContact('imran-3'), isFalse);

      expect(store.isApproved('imran-3'), isFalse);
      expect(store.isContactShared('imran-3'), isFalse);
    });
  });

  group('messaging', () {
    test('a sent message is stored once and no reply is fabricated', () async {
      final AppStore store = await _activeStore();
      store.seedThreadIfEmpty('zayd-1');
      final int before = store.messages('zayd-1').length;

      store.sendMessage('zayd-1', 'Assalamu alaikum.');

      expect(store.messages('zayd-1').length, before + 1);
      expect(store.messages('zayd-1').last.sender, MessageSender.user);

      // No local timer may invent an incoming message or a chaperone note.
      await Future<void>.delayed(const Duration(milliseconds: 4000));
      expect(
        store.messages('zayd-1').length,
        before + 1,
        reason: 'incoming messages must come from a backend, not a timer',
      );
      expect(store.messages('zayd-1').last.sender, MessageSender.user);
    });

    test('an empty message is ignored', () async {
      final AppStore store = await _activeStore();
      store.seedThreadIfEmpty('zayd-1');
      final int before = store.messages('zayd-1').length;

      store.sendMessage('zayd-1', '   ');

      expect(store.messages('zayd-1').length, before);
    });
  });

  group('proposals', () {
    test('sending a proposal does NOT create a match', () async {
      final AppStore store = await _activeStore();

      expect(store.sendProposal('imran-3'), isTrue);

      expect(store.hasProposed('imran-3'), isTrue);
      expect(store.outgoingProposal('imran-3')!.status, ProposalStatus.pending);
      expect(
        store.isApproved('imran-3'),
        isFalse,
        reason: 'a match needs the recipient to accept, not just a send',
      );
    });

    test('incoming proposals are reachable and listed', () async {
      final AppStore store = await _activeStore();

      // Previously this list was permanently empty (G-02).
      expect(store.pendingIncomingProposals, isNotEmpty);
      expect(store.pendingRequestCount, store.pendingIncomingProposals.length);
      expect(
        store.incomingProposalProfiles.map((MatchProfile p) => p.id),
        containsAll(<String>['farhan-2', 'salman-5']),
      );
    });

    test('accepting an incoming proposal creates the match', () async {
      final AppStore store = await _activeStore();
      expect(store.isApproved('farhan-2'), isFalse);

      expect(store.acceptProposal('farhan-2'), isTrue);

      expect(store.incomingProposal('farhan-2')!.status,
          ProposalStatus.accepted);
      expect(store.isApproved('farhan-2'), isTrue);
      expect(store.pendingRequestCount, 1);
      expect(
        store.messages('farhan-2'),
        isEmpty,
        reason: 'a new match starts with no invented conversation',
      );
    });

    test('declining an incoming proposal creates no match', () async {
      final AppStore store = await _activeStore();

      expect(store.declineProposal('salman-5'), isTrue);

      expect(store.incomingProposal('salman-5')!.status,
          ProposalStatus.declined);
      expect(store.isApproved('salman-5'), isFalse);
      expect(
        store.chatMatches.any((MatchProfile p) => p.id == 'salman-5'),
        isFalse,
      );
    });

    test('a proposal cannot be accepted twice', () async {
      final AppStore store = await _activeStore();

      expect(store.acceptProposal('farhan-2'), isTrue);
      expect(
        store.acceptProposal('farhan-2'),
        isFalse,
        reason: 'accepted is terminal',
      );
    });

    test('a declined proposal cannot then be accepted', () async {
      final AppStore store = await _activeStore();

      expect(store.declineProposal('farhan-2'), isTrue);
      expect(store.acceptProposal('farhan-2'), isFalse);
      expect(store.isApproved('farhan-2'), isFalse);
    });

    test('accepting a proposal nobody sent is refused', () async {
      final AppStore store = await _activeStore();

      expect(store.incomingProposal('imran-3'), isNull);
      expect(store.acceptProposal('imran-3'), isFalse);
      expect(store.isApproved('imran-3'), isFalse);
    });

    test('an outgoing proposal cannot be accepted by its sender', () async {
      final AppStore store = await _activeStore();
      store.sendProposal('imran-3');

      expect(
        store.acceptProposal('imran-3'),
        isFalse,
        reason: 'only the recipient may accept',
      );
      expect(store.isApproved('imran-3'), isFalse);
    });

    test('withdrawing frees the heart but does not refund the slot', () async {
      final AppStore store = await _activeStore();
      store.sendProposal('imran-3');
      final int leftAfterSend = store.proposalsLeft;

      expect(store.withdrawProposal('imran-3'), isTrue);

      expect(store.hasProposed('imran-3'), isFalse);
      expect(store.proposalsLeft, leftAfterSend);
      expect(
        store.proposalsSentList.any((MatchProfile p) => p.id == 'imran-3'),
        isFalse,
        reason: 'a withdrawn proposal leaves the sent list',
      );
    });

    test('an incoming proposal cannot be withdrawn by the recipient',
        () async {
      final AppStore store = await _activeStore();
      expect(store.withdrawProposal('farhan-2'), isFalse);
      expect(store.incomingProposal('farhan-2')!.status,
          ProposalStatus.pending);
    });

    test('proposal records survive a reload', () async {
      final AppStore store = await _activeStore();
      store.sendProposal('imran-3');
      store.declineProposal('salman-5');

      // Rebuild over the same mock preferences.
      final AppStore reloaded = AppStore(await SharedPreferences.getInstance());
      addTearDown(reloaded.dispose);

      expect(reloaded.outgoingProposal('imran-3')?.status,
          ProposalStatus.pending);
      expect(reloaded.incomingProposal('salman-5')?.status,
          ProposalStatus.declined);
    });
  });

  group('persistence', () {
    test('chat history survives a reload', () async {
      final AppStore store = await _activeStore();
      store.seedThreadIfEmpty('zayd-1');
      store.sendMessage('zayd-1', 'Assalamu alaikum.');
      final int count = store.messages('zayd-1').length;

      // Rebuilding the store used to throw inside the constructor, because
      // threads were written as JSON strings but read back as JSON arrays.
      final AppStore reloaded = AppStore(await SharedPreferences.getInstance());
      addTearDown(reloaded.dispose);

      expect(reloaded.messages('zayd-1').length, count);
      expect(reloaded.messages('zayd-1').last.text, 'Assalamu alaikum.');
    });

    test('a corrupt chat blob does not break construction', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bk_stage': 'active',
        'bk_onboarded': true,
        'bk_chats': 'this is not json',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final AppStore store = AppStore(prefs);
      addTearDown(store.dispose);

      // Construction completed instead of throwing. The unreadable blob was
      // discarded, so the only thread present is the freshly seeded one.
      expect(store.stage, AuthStage.active);
      expect(
        store.messages('zayd-1').every((ChatMessage m) => m.text.isNotEmpty),
        isTrue,
      );
    });

    test('a legacy double-encoded thread is still readable', () async {
      // The shape earlier builds actually wrote: each map value is itself a
      // JSON *string* rather than a JSON array.
      final String legacy = jsonEncode(<String, dynamic>{
        'bilal-4': jsonEncode(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'm1',
            'text': 'Salam',
            'time': '10:00',
            'createdAt':
                DateTime(2026, 10, 1, 10).millisecondsSinceEpoch,
            'sender': 'user',
          },
        ]),
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bk_stage': 'active',
        'bk_onboarded': true,
        'bk_chats': legacy,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final AppStore store = AppStore(prefs);
      addTearDown(store.dispose);

      expect(store.messages('bilal-4').length, 1);
      expect(store.messages('bilal-4').single.text, 'Salam');
    });

    test('populated comma-separated sets reload without crashing', () async {
      // Exactly what the writers produce. `_decodeSet` used to jsonDecode
      // this and take the app down inside the constructor.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bk_stage': 'active',
        'bk_onboarded': true,
        'bk_likes': 'zayd-1,farhan-2',
        'bk_approved': 'zayd-1',
        'bk_skipped': 'imran-3',
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final AppStore store = AppStore(prefs);
      addTearDown(store.dispose);

      expect(store.isLiked('zayd-1'), isTrue);
      expect(store.isLiked('farhan-2'), isTrue);
      expect(store.isApproved('zayd-1'), isTrue);
      expect(store.hasSkipped('imran-3'), isTrue);
      expect(store.isLiked('salman-5'), isFalse);
    });
  });

  group('block and report', () {
    test('a blocked profile leaves every list and its proposal is declined',
        () async {
      final AppStore store = await _activeStore();
      store.sendProposal('imran-3');
      store.blockProfile('imran-3');
      store.blockProfile('farhan-2');
      store.blockProfile('zayd-1');

      bool listed(Iterable<MatchProfile> l, String id) =>
          l.any((MatchProfile p) => p.id == id);
      expect(listed(store.discoveredProfiles, 'imran-3'), isFalse);
      expect(listed(store.proposalsSentList, 'imran-3'), isFalse);
      expect(listed(store.incomingProposalProfiles, 'farhan-2'), isFalse);
      expect(listed(store.chatMatches, 'zayd-1'), isFalse);
      expect(store.chatThreadIds, isNot(contains('zayd-1')));
      expect(store.incomingProposal('farhan-2')!.status,
          ProposalStatus.declined);
    });

    test('a blocked conversation accepts no new messages', () async {
      final AppStore store = await _activeStore();
      final int before = store.messages('zayd-1').length;

      store.blockProfile('zayd-1');
      store.sendMessage('zayd-1', 'Salam');

      expect(store.messages('zayd-1').length, before);
    });

    test('blocks and reports survive a reload', () async {
      final AppStore store = await _activeStore();
      store.blockProfile('imran-3');
      store.reportProfile('bilal-4', 'Fake profile');

      final AppStore reloaded = AppStore(await SharedPreferences.getInstance());
      addTearDown(reloaded.dispose);

      expect(reloaded.isBlocked('imran-3'), isTrue);
      expect(reloaded.reports.single.profileId, 'bilal-4');
      expect(reloaded.reports.single.reason, 'Fake profile');
    });
  });

  group('account deletion', () {
    test('removes proposals, blocks and reports from storage', () async {
      final AppStore store = await _activeStore();
      store.sendProposal('imran-3');
      store.blockProfile('bilal-4');
      store.reportProfile('bilal-4', 'Fake profile');

      store.resetAll();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bk_proposal_records'), isNull);
      expect(prefs.getString('bk_blocked'), isNull);
      expect(prefs.getString('bk_reports'), isNull);
      expect(store.isLoggedIn, isFalse);
      expect(store.isBlocked('bilal-4'), isFalse);
      expect(store.reports, isEmpty);
    });
  });

  group('verification', () {
    test('the badge follows approvals recorded by the reviewer', () async {
      final List<VerificationDoc> reviewed = VerificationDoc.seeds
          .map((VerificationDoc d) => d.isRequired
              ? d.copyWith(status: VerificationDocStatus.approved)
              : d)
          .toList();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bk_stage': 'active',
        'bk_onboarded': true,
        'bk_docs': VerificationDoc.encodeList(reviewed),
      });
      final AppStore store = AppStore(await SharedPreferences.getInstance());
      addTearDown(store.dispose);

      expect(store.isBarkatVerified, isTrue);
      expect(store.verificationProgress, 100);
    });

    test('submitting does not by itself approve', () async {
      final AppStore store = await _activeStore();

      store.submitVerificationDoc('education-proof');

      expect(store.isBarkatVerified, isFalse);
      expect(
        store.verificationDocs
            .firstWhere((VerificationDoc d) => d.id == 'education-proof')
            .status,
        VerificationDocStatus.pending,
      );
    });
  });

  group('discovery filtering', () {
    test('an incompatible profile leaves the discovery deck', () async {
      final AppStore store = await _activeStore();
      final String id = store.discoveredProfiles.first.id;

      store.markIncompatible(id);
      expect(store.discoveredProfiles.any((MatchProfile p) => p.id == id),
          isFalse);
    });

    test('an unmatched profile leaves both match decks', () async {
      final AppStore store = await _activeStore();
      store.acceptProposal('farhan-2');
      expect(store.chatMatches.any((MatchProfile p) => p.id == 'farhan-2'),
          isTrue);

      store.unmatch('farhan-2');

      expect(store.chatMatches.any((MatchProfile p) => p.id == 'farhan-2'),
          isFalse);
      expect(
          store.sharedContactProfiles
              .any((MatchProfile p) => p.id == 'farhan-2'),
          isFalse);
    });
  });
}
