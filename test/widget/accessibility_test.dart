// Small phone, large text: the layout must hold, and controls must stay tappable.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/screens/account_screens.dart';
import 'package:nikah_app/screens/family_circle_screen.dart';
import 'package:nikah_app/screens/landing_front_screen.dart';
import 'package:nikah_app/screens/phone_signin_screen.dart';
import 'package:nikah_app/screens/review_status_screen.dart';
import 'package:nikah_app/screens/search_screen.dart';
import 'package:nikah_app/screens/settings_screen.dart';
import 'package:nikah_app/screens/verification_screen.dart';
import 'package:nikah_app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  // The test font is narrower than the real one, which would hide overflows.
  setUpAll(() async {
    final FontLoader loader = FontLoader(AppTheme.fontFamily);
    for (final String weight in <String>['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
      final Uint8List bytes = File('assets/fonts/PlusJakartaSans-$weight.ttf').readAsBytesSync();
      loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  final Map<String, Widget> screens = <String, Widget>{
    'landing': const LandingScreen(),
    'sign-in': const PhoneSignInScreen(),
    'review status': const ReviewStatusScreen(),
    'verification': const VerificationScreen(),
    'settings': const SettingsScreen(),
    'family': const FamilyCircleScreen(),
    'search': const SearchScreen(),
    'delete account': const DeleteAccountScreen(),
    'blocked': const BlockedMembersScreen(),
  };

  for (final MapEntry<String, Widget> s in screens.entries) {
    testWidgets('${s.key} holds at 320dp with large text', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late RemoteAppStore store;
      final FakeBackend backend = FakeBackend();
      await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
        backend.auth.add(const AuthUser(uid: 'me', isApproved: true, phone: '+911'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        backend.account.add(const AccountState(stage: ReviewStage.submitted));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      addTearDown(store.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AppStore>.value(
        value: store,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 640), textScaler: TextScaler.linear(1.5)),
            child: s.value,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  }
}
