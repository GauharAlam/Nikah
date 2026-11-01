// Drives the real app UI on a device against the emulators. Each screen stays up
// long enough for tool/screenshots.sh to capture it for review by eye.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/data/firebase_backend.dart';
import 'package:nikah_app/main.dart';
import 'package:nikah_app/models/ward_profile.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every main screen renders with real data', (WidgetTester tester) async {
    await startFirebase();
    final FirebaseBackend b = FirebaseBackend.emulator(host);
    await FirebaseAuth.instance.signOut();

    final String reviewer = 'uir$run';
    final String man = 'uim$run';
    final String woman = 'uiw$run';
    await createUser(reviewer, claims: <String, dynamic>{'reviewer': true});
    await approvedMember(b, woman, 'Sara Ali', Gender.female, reviewer);
    await approvedMember(b, man, 'Zayd Khan', Gender.male, reviewer);
    await FirebaseAuth.instance.signOut();

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final RemoteAppStore store = RemoteAppStore(await SharedPreferences.getInstance(), b);
    final GoRouter router = buildRouter(store);
    await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(value: store, child: BarkatNikahApp(router: router)));

    Future<void> settle() async {
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<void> shot(String name) async {
      debugPrint('SCREEN $name');
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await settle();
    }

    await shot('01_landing');
    await tester.runAsync(() => signInAs(man));
    await settle();
    expect(store.isSignedIn, isTrue);
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    store.acceptPledge();
    await settle();
    expect(store.isLoggedIn, isTrue);

    for (final (String name, String route) in <(String, String)>[
      ('02_discovery', AppRoutes.homeDiscovery),
      ('03_proposals', AppRoutes.homeProposals),
      ('04_matches', AppRoutes.homeMatches),
      ('05_activities', AppRoutes.homeActivities),
      ('06_premium', AppRoutes.homePremium),
      ('07_profile', AppRoutes.homeProfile),
      ('08_settings', AppRoutes.settings),
      ('09_family', AppRoutes.familyCircle),
      ('10_search', AppRoutes.search),
      ('11_verification', AppRoutes.verifyProfile),
      ('12_delete', AppRoutes.deleteAccount),
    ]) {
      router.go(route);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 900)));
      await shot(name);
      expect(tester.takeException(), isNull, reason: name);
    }
    store.dispose();
  });
}
