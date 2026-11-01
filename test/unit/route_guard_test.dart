import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/providers/app_store.dart';

import '../helpers/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late RemoteAppStore store;

  Future<void> settle() async {
    for (int i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> member(ReviewStage stage, {bool reviewer = false, bool pledged = true}) async {
    backend.auth.add(AuthUser(uid: 'me', isApproved: stage == ReviewStage.approved, isReviewer: reviewer));
    await settle();
    backend.account.add(AccountState(stage: stage));
    await settle();
    if (pledged) store.acceptPledge();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    backend = FakeBackend();
    store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
    addTearDown(store.dispose);
  });

  test('holds on the splash until auth is known', () {
    expect(guardRoute(store, AppRoutes.homeDiscovery), AppRoutes.splash);
    expect(guardRoute(store, AppRoutes.splash), isNull);
  });

  test('signed-out members reach only public routes', () async {
    backend.auth.add(null);
    await settle();
    expect(guardRoute(store, AppRoutes.homeDiscovery), AppRoutes.landing);
    expect(guardRoute(store, AppRoutes.matchDetail('a')), AppRoutes.landing);
    expect(guardRoute(store, AppRoutes.reviewQueue), AppRoutes.landing);
    expect(guardRoute(store, AppRoutes.signIn), isNull);
  });

  test('draft members cannot reach the app', () async {
    await member(ReviewStage.draft);
    expect(guardRoute(store, AppRoutes.homeDiscovery), AppRoutes.startProfile);
    expect(guardRoute(store, AppRoutes.chat('a')), AppRoutes.startProfile);
    expect(guardRoute(store, AppRoutes.onboarding), isNull);
  });

  test('submitted members wait, rejected members can edit', () async {
    await member(ReviewStage.submitted);
    expect(guardRoute(store, AppRoutes.homeDiscovery), AppRoutes.reviewStatus);
    expect(guardRoute(store, AppRoutes.onboarding), AppRoutes.reviewStatus);
    expect(guardRoute(store, AppRoutes.verifyProfile), isNull);

    backend.account.add(const AccountState(stage: ReviewStage.rejected));
    await settle();
    expect(guardRoute(store, AppRoutes.onboarding), isNull);
    expect(guardRoute(store, AppRoutes.homeDiscovery), AppRoutes.reviewStatus);
  });

  test('approved members pledge once, then reach home', () async {
    await member(ReviewStage.approved, pledged: false);
    expect(guardRoute(store, AppRoutes.homeDiscovery), AppRoutes.approved);
    store.acceptPledge();
    expect(guardRoute(store, AppRoutes.approved), AppRoutes.homeDiscovery);
    expect(guardRoute(store, AppRoutes.homeDiscovery), isNull);
  });

  test('the review queue needs the reviewer claim', () async {
    await member(ReviewStage.approved);
    expect(guardRoute(store, AppRoutes.reviewQueue), AppRoutes.homeDiscovery);
  });

  test('a reviewer reaches the queue', () async {
    await member(ReviewStage.approved, reviewer: true);
    expect(guardRoute(store, AppRoutes.reviewQueue), isNull);
  });
}
