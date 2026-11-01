import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/models/nikah_journey.dart';
import 'package:nikah_app/models/proposal.dart';
import 'package:nikah_app/models/ward_profile.dart';
import 'package:nikah_app/providers/app_store.dart';

import '../helpers/fake_backend.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

Proposal proposal(String id, ProposalDirection direction, ProposalStatus status) => Proposal(
      id: id,
      profileId: id,
      direction: direction,
      status: status,
      createdAt: DateTime(2026),
    );

void main() {
  late FakeBackend backend;
  late RemoteAppStore store;

  Future<void> signIn({bool approved = true}) async {
    backend.auth.add(AuthUser(uid: 'me', isApproved: approved));
    await settle();
    await settle();
    await settle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backend = FakeBackend();
    store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
    addTearDown(store.dispose);
  });

  test('waits for the first auth state, then shows a signed-out member', () async {
    expect(store.isRestoring, isTrue);
    backend.auth.add(null);
    await settle();
    expect(store.isRestoring, isFalse);
    expect(store.isSignedIn, isFalse);
  });

  test('a real member never sees demo data', () async {
    await signIn();
    expect(store.directory, isEmpty);
    expect(store.discoveredProfiles, isEmpty);
    expect(store.notifications, isEmpty);
    expect(store.pendingIncomingProposals, isEmpty);
    expect(store.chatThreadIds, isEmpty);
  });

  test('signing in alone does not activate the account', () async {
    await signIn(approved: false);
    expect(store.isSignedIn, isTrue);
    expect(store.isLoggedIn, isFalse);
    expect(store.reviewStage, ReviewStage.draft);
  });

  test('only the server approval opens the app, and it refreshes claims', () async {
    await signIn(approved: false);
    backend.account.add(const AccountState(stage: ReviewStage.submitted));
    await settle();
    expect(store.isLoggedIn, isFalse);

    backend.account.add(const AccountState(stage: ReviewStage.approved));
    await settle();
    expect(store.isLoggedIn, isTrue);
    expect(backend.calls, contains('refreshClaims'));
  });

  test('a rejection carries the reviewer reason', () async {
    await signIn(approved: false);
    backend.account.add(const AccountState(stage: ReviewStage.rejected, rejectionReason: 'Blurry photo'));
    await settle();
    expect(store.rejectionReason, 'Blurry photo');
  });

  test('a saved draft restores the member to their step', () async {
    backend.draft = <String, dynamic>{'fullName': 'Sara', 'step': 4, 'gender': 'female'};
    await signIn(approved: false);
    expect(store.profile!.displayName, 'Sara');
    expect(store.profile!.onboardingStep, 4);
    expect(store.profile!.hasGender, isTrue);
  });

  test('the draft keeps the fields the server validates', () async {
    await signIn(approved: false);
    await store.saveDraft(const WardProfile(
      displayName: 'Sara',
      hasGender: true,
      phoneCode: '+91',
      phone: '9876543210',
      qualification: 'Diploma',
    ));
    expect(backend.savedDraft!['fullName'], 'Sara');
    expect(backend.savedDraft!['gender'], 'female');
    expect(backend.savedDraft!['phone'], '+919876543210');
    expect(backend.savedDraft!['qualificationGraduate'], isFalse);
  });

  test('discovery pages through the server without repeating anyone', () async {
    await signIn();
    backend.pages = <IntroductionPage>[
      IntroductionPage(<MatchProfile>[card('a'), card('b')], 100),
      IntroductionPage(<MatchProfile>[card('b'), card('c')], null),
    ];
    await store.refreshIntroductions();
    expect(store.discoveredProfiles.map((MatchProfile p) => p.id), <String>['a', 'b']);

    await store.loadMoreIntroductions();
    expect(store.discoveredProfiles.map((MatchProfile p) => p.id), <String>['a', 'b', 'c']);
    expect(backend.calls, contains('fetchIntroductions:100'));

    final int calls = backend.calls.length;
    await store.loadMoreIntroductions();
    expect(backend.calls.length, calls, reason: 'nothing further to load');
  });

  test('a discovery failure becomes a retryable state', () async {
    await signIn();
    backend.failNext = const BackendException('You appear to be offline.');
    await store.refreshIntroductions();
    expect(store.introductionsError, 'You appear to be offline.');
    await store.refreshIntroductions();
    expect(store.introductionsError, isNull);
  });

  test('Incompatible spends a server decision and drops the card', () async {
    await signIn();
    backend.pages = <IntroductionPage>[
      IntroductionPage(<MatchProfile>[card('a'), card('b'), card('c'), card('d')], 1),
    ];
    await store.refreshIntroductions();
    store.markIncompatible('a');
    await settle();
    expect(backend.calls, contains('hide:a'));
    expect(store.discoveredProfiles.map((MatchProfile p) => p.id), isNot(contains('a')));
  });

  test('a proposal goes to the server and creates no local match', () async {
    await signIn();
    expect(store.sendProposal('a'), isTrue);
    await settle();
    expect(backend.calls, contains('propose:a'));
    expect(store.isApproved('a'), isFalse);
  });

  test('the local limit stops an obviously refused proposal', () async {
    await signIn();
    backend.account.add(const AccountState(stage: ReviewStage.approved, proposalsSentToday: 5));
    await settle();
    expect(store.proposalsLeft, 0);
    expect(store.sendProposal('a'), isFalse);
    await settle();
    expect(backend.calls, isNot(contains('propose:a')));
  });

  test('limits come from server config', () async {
    await signIn();
    backend.limits.add(const AppLimits(proposalsPerDay: 8, decisionsPerDay: 20, pendingLimit: 30));
    await settle();
    expect(store.dailyProposalLimit, 8);
    expect(store.decisionsPerDay, 20);
    expect(store.pendingLimit, 30);
  });

  test('credits are the monthly allowance plus the server balance', () async {
    await signIn();
    backend.account.add(const AccountState(stage: ReviewStage.approved, contactCreditsLeft: -4));
    await settle();
    expect(store.contactCredits, 26);
  });

  test('an unanswered proposal cannot be accepted, an incoming one can', () async {
    await signIn();
    backend.proposals.add(<Proposal>[
      proposal('out', ProposalDirection.outgoing, ProposalStatus.pending),
      proposal('in', ProposalDirection.incoming, ProposalStatus.pending),
      proposal('done', ProposalDirection.incoming, ProposalStatus.declined),
    ]);
    await settle();
    expect(store.acceptProposal('out'), isFalse);
    expect(store.acceptProposal('done'), isFalse);
    expect(store.acceptProposal('in'), isTrue);
    await settle();
    expect(backend.calls, contains('respond:in:true'));
    expect(store.isApproved('in'), isFalse, reason: 'the match arrives from the server');
  });

  test('matches and messages arrive from the server', () async {
    await signIn();
    backend.matches.add(const <MatchThread>[MatchThread(pairId: 'p', otherId: 'a', isOpen: true)]);
    await settle();
    expect(store.isApproved('a'), isTrue);

    backend.messages.add(<ChatMessage>[
      ChatMessage(id: '1', text: 'Salam', time: '', createdAt: DateTime(2026), sender: MessageSender.match),
    ]);
    await settle();
    expect(store.messages('a').single.text, 'Salam');
    expect(store.chatThreadIds, contains('a'));

    store.sendMessage('a', 'Wa alaikum salam');
    await settle();
    expect(backend.calls, contains('message:p:Wa alaikum salam'));
  });

  test('a closed match cannot be messaged and leaves the lists', () async {
    await signIn();
    backend.matches.add(const <MatchThread>[MatchThread(pairId: 'p', otherId: 'a', isOpen: true)]);
    await settle();
    backend.matches.add(const <MatchThread>[MatchThread(pairId: 'p', otherId: 'a', isOpen: false)]);
    await settle();
    expect(store.isApproved('a'), isFalse);
    store.sendMessage('a', 'Salam');
    await settle();
    expect(backend.calls.where((String c) => c.startsWith('message')), isEmpty);
  });

  test('shared numbers are only what the server revealed', () async {
    await signIn();
    expect(store.sharedPhone('a'), '');
    backend.shares.add(<String, String>{'a': '+911234567890'});
    await settle();
    expect(store.isContactShared('a'), isTrue);
    expect(store.sharedPhone('a'), '+911234567890');
  });

  test('server failures reach the member', () async {
    await signIn(approved: false);
    backend.failNext = const BackendException('Daily proposal limit reached.');
    store.sendProposal('a');
    await settle();
    await settle();
    expect(store.errors.value, 'Daily proposal limit reached.');
  });

  test('unknown failures show a generic message', () async {
    await signIn(approved: false);
    backend.failNext = StateError('secret internal detail');
    store.sendProposal('a');
    await settle();
    await settle();
    expect(store.errors.value, isNot(contains('secret')));
  });

  test('an unknown profile shows a placeholder, never someone else', () async {
    await signIn(approved: false);
    expect(store.profileById('nobody').name, 'Member');
  });

  test('signing out clears the member from memory', () async {
    await signIn();
    backend.matches.add(const <MatchThread>[MatchThread(pairId: 'p', otherId: 'a', isOpen: true)]);
    await settle();
    backend.auth.add(null);
    await settle();
    await settle();
    expect(store.isSignedIn, isFalse);
    expect(store.isApproved('a'), isFalse);
    expect(store.profile, isNull);
  });

  test('deleting the account calls the server and clears preferences', () async {
    await signIn();
    store.acceptPledge();
    store.resetAll();
    await settle();
    await settle();
    expect(backend.calls, contains('deleteAccount'));
    expect(store.pledgeAccepted, isFalse);
  });

  test('privacy changes reach the server once approved', () async {
    await signIn();
    backend.account.add(const AccountState(stage: ReviewStage.approved));
    await settle();
    store.updatePrivacy(photoPrivacy: 'matches');
    await settle();
    expect(backend.calls, contains('privacy:matches'));
    expect(store.profile!.photoPrivacy, 'matches');
  });

  test('journey steps and answers go to the server', () async {
    await signIn();
    backend.matches.add(const <MatchThread>[
      MatchThread(pairId: 'p', otherId: 'a', isOpen: true, myStep: 'families', theirStep: 'questions'),
    ]);
    await settle();
    expect(store.journeyStep('a'), JourneyStep.families);
    expect(store.theirJourneyStep('a'), JourneyStep.questions);

    store.setJourneyStep('a', JourneyStep.istikhara);
    await settle();
    expect(backend.calls, contains('journey:istikhara'));

    await store.saveAnswers('a', <String, String>{'deen1': 'Yes'});
    expect(await store.myAnswers('a'), <String, String>{'deen1': 'Yes'});
  });

  test('an approved member marks activity', () async {
    await signIn();
    expect(backend.calls, contains('touchActive'));
  });

  test('the free limit comes from the server', () async {
    await signIn();
    backend.pages = <IntroductionPage>[
      IntroductionPage(<MatchProfile>[card('a')], null, freeLeft: 0, limitReached: true),
    ];
    await store.refreshIntroductions();
    expect(store.freeProfilesLeft, 0);
    expect(store.reachedProfileLimit, isTrue);

    backend.account.add(AccountState(
      stage: ReviewStage.approved,
      premiumUntil: DateTime.now().add(const Duration(days: 30)),
    ));
    await settle();
    expect(store.reachedProfileLimit, isFalse);
    expect(store.freeProfilesLeft, isNull);
  });

  test('a guardian sees the shared summaries and gives an opinion', () async {
    await signIn(approved: false);
    backend.account.add(const AccountState(familyOf: 'member1'));
    await settle();
    expect(store.isGuardian, isTrue);

    backend.familyStream.add(const FamilyState(
      shortlist: <FamilyPick>[FamilyPick(id: 'c', title: 'Sara, 26', summary: 'MBA')],
    ));
    await settle();
    expect(store.guardianView!.shortlist.single.title, 'Sara, 26');

    store.giveFamilyOpinion('c', 'good');
    await settle();
    expect(backend.calls, contains('opinion:member1:c:good'));
  });

  test('edits and family sharing go to the server', () async {
    await signIn();
    backend.account.add(const AccountState(stage: ReviewStage.approved));
    await settle();
    store.submitEdits();
    await store.shareWithFamily('a');
    await settle();
    expect(backend.calls, containsAll(<String>['submitEdits', 'shareFamily:a']));
    expect((await store.inviteInfo()).code, 'ABC234');
  });

  test('match percent comes from the server card', () {
    expect(MatchProfile.fromCard(<String, dynamic>{'id': 'x', 'matchPercent': 73}).matchPercent, 73);
  });

  test('purchases are granted by the server only', () async {
    await signIn();
    await store.validatePurchase(productId: 'barkat_monthly', platform: 'android', token: 't');
    expect(backend.calls, contains('purchase:barkat_monthly'));
    expect(store.isPremium, isFalse);
    backend.account.add(AccountState(
      stage: ReviewStage.approved,
      premiumUntil: DateTime.now().add(const Duration(days: 30)),
    ));
    await settle();
    expect(store.isPremium, isTrue);
    expect(store.proposalsLeft, greaterThan(1000));
  });
}
