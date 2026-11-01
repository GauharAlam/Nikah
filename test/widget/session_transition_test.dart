// The real router and production store through a whole session, because route
// changes driven by store notifications can only be proved by running them.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/main.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  testWidgets('signing in and out moves between screens without a framework error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final FakeBackend backend = FakeBackend();
    final RemoteAppStore store = RemoteAppStore(prefs, backend);
    addTearDown(store.dispose);
    final List<String> duringBuild = <String>[];
    store.addListener(() {
      if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
        duringBuild.add(StackTrace.current.toString());
      }
    });
    final GoRouter router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(value: store, child: NikahApp(router: router)));
    await tester.pump();

    backend.auth.add(null);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('continue_phone')), findsOneWidget);

    backend.auth.add(const AuthUser(uid: 'me', isApproved: true, phone: '+911'));
    await tester.pumpAndSettle();
    backend.account.add(const AccountState(stage: ReviewStage.approved));
    await tester.pumpAndSettle();
    store.acceptPledge();
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, isNot(AppRoutes.landing));

    backend.auth.add(null);
    // Closing the session is asynchronous, and schedules no frame until it ends.
    // Each cancelled subscription resumes on the real event loop.
    for (int i = 0; i < 60 && store.isSignedIn; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(store.isSignedIn, isFalse);
    expect(find.byKey(const Key('continue_phone')), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(duringBuild, isEmpty, reason: 'notifying during a build breaks routing');
  });
}
