// Screens on the production store with a fake server, so these prove what a
// real member sees, not what the demo simulates.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/models/proposal.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/screens/account_screens.dart';
import 'package:nikah_app/screens/chat_screen.dart';
import 'package:nikah_app/screens/family_circle_screen.dart';
import 'package:nikah_app/screens/landing_front_screen.dart';
import 'package:nikah_app/screens/match_detail_screen.dart';
import 'package:nikah_app/screens/phone_signin_screen.dart';
import 'package:nikah_app/screens/proposals_screen.dart';
import 'package:nikah_app/screens/review_status_screen.dart';
import 'package:nikah_app/screens/saved_profiles_screen.dart';
import 'package:nikah_app/screens/search_screen.dart';
import 'package:nikah_app/screens/verification_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late RemoteAppStore store;

  Future<void> signIn(WidgetTester tester, {AccountState? account, bool approved = true}) async {
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      backend = FakeBackend();
      store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
      backend.auth.add(AuthUser(uid: 'me', isApproved: approved, phone: '+911'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      backend.account.add(account ?? const AccountState(stage: ReviewStage.approved));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    addTearDown(store.dispose);
  }

  Future<void> show(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp(home: screen),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> showRouted(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final GoRouter router = GoRouter(
      initialLocation: '/x',
      routes: <RouteBase>[
        GoRoute(path: '/x', builder: (_, _) => screen),
        GoRoute(path: AppRoutes.verifyPhone, builder: (_, _) => const Scaffold(body: Text('verify screen'))),
      ],
    );
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  group('saved profiles', () {
    Future<void> saved(WidgetTester tester, List<String> ids) => tester.runAsync(() async {
          backend.bookmarks.add(ids);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });

    testWidgets('the bookmark follows the server, not the tap', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const MatchDetailScreen(matchId: 'p'));
      await tester.tap(find.byKey(const Key('detail_save')));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('bookmark:p:true'));
      expect(store.isBookmarked('p'), isFalse);

      await saved(tester, <String>['p']);
      await tester.pump();
      expect(store.isBookmarked('p'), isTrue);
    });

    testWidgets('a refused save says why', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const MatchDetailScreen(matchId: 'p'));
      backend.failOn = 'bookmark';
      await tester.tap(find.byKey(const Key('detail_save')));
      await tester.pumpAndSettle();
      expect(find.text('refused'), findsOneWidget);
      expect(find.text('Saved.'), findsNothing);
    });

    testWidgets('the list shows only profiles the server returns', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const SavedProfilesScreen());
      expect(find.text('Nothing saved yet'), findsOneWidget);

      backend.hiddenProfiles.add('gone');
      await saved(tester, <String>['a', 'gone']);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('saved_a')), findsOneWidget);
      expect(find.byKey(const Key('saved_gone')), findsNothing);
    });

    testWidgets('more than a server page of saved profiles still loads', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const SavedProfilesScreen());
      await saved(tester, <String>[for (int i = 0; i < 45; i++) 'p$i']);
      await tester.pumpAndSettle();
      expect(backend.calls.where((String c) => c == 'getProfiles').length, 2);
      expect(store.bookmarkedProfiles, hasLength(45));
    });
  });

  group('withdrawing a proposal', () {
    Proposal sent(ProposalStatus status) => Proposal(
          id: 'p1',
          profileId: 'p',
          direction: ProposalDirection.outgoing,
          status: status,
          createdAt: DateTime(2026),
        );

    Future<void> open(WidgetTester tester, ProposalStatus status) async {
      await signIn(tester);
      await tester.runAsync(() async {
        backend.proposals.add(<Proposal>[sent(status)]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await show(tester, const Scaffold(body: ProposalsScreen()));
    }

    testWidgets('it reaches the server only after confirming', (WidgetTester tester) async {
      await open(tester, ProposalStatus.pending);
      await tester.tap(find.byKey(const Key('withdraw_proposal_p')));
      await tester.pumpAndSettle();
      expect(backend.calls, isNot(contains('withdraw:p')));

      await tester.tap(find.byKey(const Key('confirm_withdraw')));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('withdraw:p'));
      expect(find.text('Proposal withdrawn.'), findsOneWidget);
    });

    testWidgets('a refusal is not shown as done', (WidgetTester tester) async {
      await open(tester, ProposalStatus.pending);
      backend.failOn = 'withdraw';
      await tester.tap(find.byKey(const Key('withdraw_proposal_p')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_withdraw')));
      await tester.pumpAndSettle();
      expect(find.text('Proposal withdrawn.'), findsNothing);
      expect(find.text('Could not withdraw. Please try again.'), findsOneWidget);
    });

    testWidgets('an answered proposal cannot be withdrawn', (WidgetTester tester) async {
      await open(tester, ProposalStatus.accepted);
      expect(find.byKey(const Key('withdraw_proposal_p')), findsNothing);
    });
  });

  testWidgets('a profile shows every photo the member added, each once', (WidgetTester tester) async {
    await signIn(tester);
    backend.fullProfiles['p'] = MatchProfile.fromCard(<String, dynamic>{
      'id': 'p',
      'name': 'Member p',
      'age': 27,
      'photos': <String>['https://example.com/1.jpg', 'https://example.com/2.jpg', 'https://example.com/3.jpg'],
    });
    await tester.runAsync(() => store.loadFullProfile('p'));
    await show(tester, const MatchDetailScreen(matchId: 'p'));

    expect(find.text('1/3'), findsOneWidget);
    await tester.drag(find.byKey(const Key('photo_p')), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });

  group('landing and sign-in', () {
    testWidgets('landing offers phone sign-in', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const LandingScreen());
      expect(find.byKey(const Key('continue_phone')), findsOneWidget);
    });

    testWidgets('landing offers an account and a way back in', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const LandingScreen());
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.byKey(const Key('landing_sign_in')), findsOneWidget);
    });

    testWidgets('a code is sent only for a valid number, and a wrong code shows why', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const PhoneSignInScreen());
      final Finder submit = find.byKey(const Key('auth_submit'));
      await tester.enterText(find.byKey(const Key('phone_input')), '123');
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      expect(find.byKey(const Key('otp_input')), findsNothing);

      await tester.enterText(find.byKey(const Key('phone_input')), '9876543210');
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      backend.failNext = const BackendException('That code is not correct.');
      await tester.enterText(find.byKey(const Key('otp_input')), '111111');
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('That code is not correct.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
    });
  });

  group('review status', () {
    testWidgets('a pending profile says so, and shows the code for a family profile', (WidgetTester tester) async {
      await signIn(tester, approved: false, account: const AccountState(stage: ReviewStage.submitted, subjectCode: 'ABC234'));
      await show(tester, const ReviewStatusScreen());
      expect(find.text('Your profile is under review'), findsOneWidget);
      expect(find.byKey(const Key('subject_code')), findsOneWidget);
    });

    testWidgets('a request for changes shows the reason and a way to edit', (WidgetTester tester) async {
      await signIn(tester, approved: false, account: const AccountState(stage: ReviewStage.changesRequested, rejectionReason: 'Clearer photo please'));
      await show(tester, const ReviewStatusScreen());
      expect(find.text('Clearer photo please'), findsOneWidget);
      expect(find.byKey(const Key('edit_after_rejection')), findsOneWidget);
    });
  });

  group('verification', () {
    testWidgets('each state shows its label and the reason for a new upload', (WidgetTester tester) async {
      await signIn(tester);
      await tester.runAsync(() async {
        backend.documents.add(VerificationDoc.blank.map((VerificationDoc d) => d.id == 'name-proof'
            ? d.copyWith(status: VerificationDocStatus.resubmissionRequired, rejectionReason: 'Too dark')
            : d.id == 'education-proof'
                ? d.copyWith(status: VerificationDocStatus.underReview)
                : d).toList());
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await show(tester, const VerificationScreen());
      expect(find.text('Too dark'), findsOneWidget);
      expect(find.textContaining('reviewing your upload'), findsOneWidget);
    });

    testWidgets('a new-upload request opens the source choice', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const VerificationScreen());
      await tester.ensureVisible(find.byKey(const Key('verification_doc_name-proof')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(const Key('verification_doc_name-proof')), matching: find.byType(InkWell)).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('doc_file')), findsOneWidget);
    });
  });

  group('chat', () {
    Future<void> openChat(WidgetTester tester, {bool open = true}) async {
      await signIn(tester);
      await tester.runAsync(() async {
        backend.matches.add(<MatchThread>[MatchThread(pairId: 'p', otherId: 'a', isOpen: open)]);
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await show(tester, const ChatScreen(matchId: 'a'));
    }

    testWidgets('an ended conversation cannot be written to', (WidgetTester tester) async {
      await openChat(tester, open: false);
      expect(find.byKey(const Key('chat_closed')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a failed message offers a retry and never claims it arrived', (WidgetTester tester) async {
      await openChat(tester);
      backend.failSend = const BackendException('offline');
      store.sendMessage('a', 'Salam');
      await tester.pumpAndSettle();
      expect(find.text('Not sent'), findsOneWidget);
      final String id = store.messages('a').single.id;
      await tester.tap(find.byKey(Key('retry_$id')));
      await tester.pumpAndSettle();
      expect(backend.sentIds, <String>[id, id]);
    });

    testWidgets('the screen shows no invented online status', (WidgetTester tester) async {
      await openChat(tester);
      expect(find.textContaining('Online'), findsNothing);
      expect(store.messages('a'), isA<List<ChatMessage>>());
    });
  });

  group('search', () {
    testWidgets('shows results, and an empty message when nothing matches', (WidgetTester tester) async {
      await signIn(tester);
      backend.pages = <IntroductionPage>[IntroductionPage(<dynamic>[card('a')].cast(), null), const IntroductionPage(<Never>[], null)];
      await show(tester, const SearchScreen());
      expect(find.byKey(const Key('search_result_a')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('search_input')), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('No profiles found'), findsOneWidget);
    });
  });

  group('family hub', () {
    testWidgets('shows who has what access, and removes them', (WidgetTester tester) async {
      await signIn(tester);
      await tester.runAsync(() async {
        backend.familyAdmin.add(const FamilyAdmin(members: <FamilyMember>[
          FamilyMember(uid: 'g', name: 'Abu', relationship: 'father', permissions: <String>['view_profile']),
        ]));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await show(tester, const FamilyCircleScreen());
      expect(find.textContaining('Abu'), findsOneWidget);
      expect(find.text('See a summary of my profile'), findsOneWidget);
      await tester.tap(find.byKey(const Key('remove_g')));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('removeGuardian:g'));
    });

    testWidgets('the invitation sheet offers only real permissions', (WidgetTester tester) async {
      await signIn(tester);
      await show(tester, const FamilyCircleScreen());
      await tester.tap(find.byKey(const Key('invite_family')));
      await tester.pumpAndSettle();
      for (final String p in familyPermissionLabels.keys) {
        expect(find.byKey(Key('perm_$p')), findsOneWidget);
      }
    });
  });

  group('delete account', () {
    testWidgets('explains what stays, and needs agreement first', (WidgetTester tester) async {
      await signIn(tester);
      await showRouted(tester, const DeleteAccountScreen());
      expect(find.textContaining('Payment records'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();
      expect(backend.calls, isNot(contains('deleteAccount')));
    });

    testWidgets('an old session is sent to verify before anything is deleted', (WidgetTester tester) async {
      await signIn(tester);
      await showRouted(tester, const DeleteAccountScreen());
      backend.failNext = const BackendException('verify', code: 'requires-recent-login');
      await tester.tap(find.byKey(const Key('delete_agree')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('verify screen'), findsOneWidget);
    });

    testWidgets('a failure is shown and can be tried again', (WidgetTester tester) async {
      await signIn(tester);
      await showRouted(tester, const DeleteAccountScreen());
      backend.failNext = const BackendException('Something went wrong.');
      await tester.tap(find.byKey(const Key('delete_agree')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete_confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete_error')), findsOneWidget);
    });
  });

  testWidgets('blocked members can be lifted, and an empty list says so', (WidgetTester tester) async {
    await signIn(tester);
    backend.blocks = const <BlockedMember>[BlockedMember('b', 'Sara')];
    await show(tester, const BlockedMembersScreen());
    expect(find.text('Sara'), findsOneWidget);
    backend.blocks = const <BlockedMember>[];
    await tester.tap(find.text('Unblock'));
    await tester.pumpAndSettle();
    expect(backend.calls, contains('unblock:b'));
    expect(find.text('Nobody is blocked'), findsOneWidget);
  });
}
