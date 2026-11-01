import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/ward_profile.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/services/app_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late RemoteAppStore store;

  Future<void> settle() async {
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{'keep': true});
    backend = FakeBackend();
    store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
    addTearDown(store.dispose);
    backend.auth.add(const AuthUser(uid: 'me', isApproved: true, phone: '+911'));
    await settle();
    backend.account.add(const AccountState(stage: ReviewStage.approved, familyOf: 'owner'));
    await settle();
  });

  group('family', () {
    test('the owner sees members, invitations and history from the server', () async {
      backend.familyAdmin.add(FamilyAdmin(
        members: const <FamilyMember>[
          FamilyMember(uid: 'g', name: 'Abu', relationship: 'father', permissions: <String>['view_shortlist']),
        ],
        invitations: const <FamilyInvitation>[
          FamilyInvitation(id: 'i', name: 'Ami', relationship: 'mother', status: 'pending'),
        ],
        history: <FamilyEvent>[FamilyEvent(action: 'joined', at: DateTime(2026))],
      ));
      await settle();
      expect(store.familyAdmin.members.single.name, 'Abu');
      expect(store.familyAdmin.invitations.single.isPending, isTrue);
      expect(store.familyAdmin.history.single.action, 'joined');
    });

    test('invitations carry the chosen relationship and permissions', () async {
      final String code = await store.createFamilyInvite(
        name: 'Abu',
        relationship: 'father',
        phone: '+919000000000',
        permissions: <String>['view_profile'],
      );
      expect(code, 'FAM234');
      expect(backend.calls, contains('invite:father:view_profile'));
    });

    test('permissions change and access is removed through the server', () async {
      await store.updateGuardianPermissions('g', <String>['view_proposals']);
      await store.removeGuardian('g');
      await store.leaveFamily();
      expect(backend.calls, containsAll(<String>[
        'permissions:g:view_proposals',
        'removeGuardian:g',
      ]));
      expect(backend.calls.where((String c) => c.startsWith('removeGuardian')), hasLength(2));
    });

    test('a guardian sees only what the server returned for their permissions', () async {
      backend.overview = const FamilyOverview(
        permissions: <String>['view_proposals'],
        proposals: <FamilyProposal>[FamilyProposal(from: 'x', summary: 'Sara')],
      );
      final FamilyOverview? o = await store.familyOverview();
      expect(o!.profileSummary, isNull);
      expect(o.proposals!.single.from, 'x');
      await store.answerForMember('x', accept: true);
      expect(backend.calls, contains('familyAnswer:owner:x:true'));
    });

    test('no permission label reaches chats, documents or contact details', () {
      for (final String label in familyPermissionLabels.values) {
        expect(label.toLowerCase(), isNot(matches(RegExp('chat|message|document|number|contact'))));
      }
    });
  });

  group('deletion', () {
    test('clears the device only after the server accepts', () async {
      await store.deleteAccount();
      expect(backend.calls, contains('deleteAccount'));
      expect((await SharedPreferences.getInstance()).getBool('keep'), isNull);
    });

    test('an old session keeps everything and asks to verify', () async {
      backend.failNext = const BackendException('verify', code: 'requires-recent-login');
      await expectLater(
        store.deleteAccount(),
        throwsA(isA<BackendException>().having((BackendException e) => e.kind, 'kind', FailureKind.recentSignInNeeded)),
      );
      expect((await SharedPreferences.getInstance()).getBool('keep'), isTrue);
    });
  });

  test('export returns the member\'s data as JSON', () async {
    expect(await store.exportData(), contains('Sara'));
  });

  test('blocks are listed and lifted on the server', () async {
    backend.blocks = const <BlockedMember>[BlockedMember('b', 'Sara')];
    expect((await store.blockedMembers()).single.name, 'Sara');
    await store.unblockProfile('b');
    expect(backend.calls, contains('unblock:b'));
  });

  test('subject phone survives the draft round trip', () {
    const WardProfile p = WardProfile(subjectPhone: '+919000000000');
    expect(WardProfile.fromDraft(p.toDraft(qualificationGraduate: true)).subjectPhone, '+919000000000');
  });

  group('app lock', () {
    Future<void> gate(WidgetTester tester, SharedPreferences prefs, bool result) => tester.pumpWidget(
          MaterialApp(
            home: AppLockGate(prefs: prefs, confirm: () async => result, child: const Text('private')),
          ),
        );

    testWidgets('off by default, the app opens directly', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await gate(tester, await SharedPreferences.getInstance(), true);
      await tester.pump();
      expect(find.byKey(const Key('app_locked')), findsNothing);
    });

    testWidgets('stays covered until the phone confirms the owner', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'bk_app_lock': true});
      await gate(tester, await SharedPreferences.getInstance(), false);
      await tester.pump();
      expect(find.byKey(const Key('app_locked')), findsOneWidget);
    });

    testWidgets('unlocks when confirmed, and asks again after the background', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{'bk_app_lock': true});
      bool answer = true;
      await tester.pumpWidget(MaterialApp(
        home: AppLockGate(
          prefs: await SharedPreferences.getInstance(),
          confirm: () async => answer,
          child: const Text('private'),
        ),
      ));
      await tester.pump();
      expect(find.byKey(const Key('app_locked')), findsNothing);

      answer = false;
      for (final AppLifecycleState state in <AppLifecycleState>[
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();
      expect(find.byKey(const Key('app_locked')), findsOneWidget);
    });
  });
}
