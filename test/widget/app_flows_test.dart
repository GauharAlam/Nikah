import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/l10n/app_strings.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/providers/demo_app_store.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/models/nikah_journey.dart';
import 'package:nikah_app/models/ward_profile.dart';
import 'package:nikah_app/widgets/app_switch.dart';

import '../helpers/test_app.dart';

/// Taps a row in the open bottom sheet, scrolling that sheet to reach it.
Future<void> sheetTap(WidgetTester tester, Finder row) async {
  await tester.scrollUntilVisible(row, 120, scrollable: find.byType(Scrollable).last);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

class _FakePicker extends ImagePickerPlatform {
  _FakePicker(this.path);
  final String path;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async =>
      <XFile>[XFile(path)];
}

void main() {
  useFakeImageTransport();

  testWidgets('a wrong code is refused, then a new member completes all steps', (
    WidgetTester tester,
  ) async {
    final Directory dir = await tester.runAsync(
      () => Directory.systemTemp.createTemp('photo'),
    ) as Directory;
    addTearDown(() => dir.deleteSync(recursive: true));
    final String photo = '${dir.path}/p.png';
    await tester.runAsync(() => File(photo).writeAsBytes(<int>[0x89, 0x50]));
    final ImagePickerPlatform realPicker = ImagePickerPlatform.instance;
    ImagePickerPlatform.instance = _FakePicker(photo);
    addTearDown(() => ImagePickerPlatform.instance = realPicker);

    final (AppStore store, _) = await pumpApp(tester);

    expect(find.text('Create Account'), findsOneWidget);
    await tap(tester, find.byKey(const Key('continue_phone')));
    await tester.enterText(find.byKey(const Key('phone_input')), '9876543210');
    await tester.pump();
    await tap(tester, find.byKey(const Key('auth_submit')));

    await tester.enterText(find.byKey(const Key('otp_input')), '000000');
    await tester.pump();
    await tap(tester, find.byKey(const Key('auth_submit')));
    expect(find.byKey(const Key('auth_error')), findsOneWidget);
    expect(store.isSignedIn, isFalse);

    await tester.enterText(find.byKey(const Key('otp_input')), DemoAppStore.demoOtp);
    await tester.pump();
    await tap(tester, find.byKey(const Key('auth_submit')));
    expect(store.isSignedIn, isTrue);

    await tap(tester, find.byKey(const Key('start_profile')));
    final Finder next = find.byKey(const Key('onboarding_next'));

    // 1 — basic information: empty fields are refused.
    await tap(tester, next);
    expect(find.text('Basic information'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('full_name')), 'Sara Khan');
    await tap(tester, find.byKey(const Key('pick_gender')));
    await tap(tester, find.text('Female'));
    await tap(tester, find.byKey(const Key('pick_dob')));
    await tap(tester, find.text('OK'));
    await tap(tester, find.byKey(const Key('pick_marital')));
    await tap(tester, find.text('Never married'));
    await tap(tester, find.byKey(const Key('pick_readiness')));
    await tap(tester, find.text('Ready within 1 year'));
    await tap(tester, find.byKey(const Key('pick_home')));
    await tap(tester, find.text('Select country'));
    await tap(tester, find.text('India'));
    await tap(tester, find.text('Select state or region'));
    await tap(tester, find.text('Delhi').last);
    await tap(tester, find.text('Select city'));
    await tap(tester, find.text('Rohini'));
    await tap(tester, find.widgetWithText(FilledButton, 'Done'));
    expect(find.byKey(const Key('phone_verified')), findsOneWidget);
    await tap(tester, next);

    // 2 — personal and family: caste and family details are optional.
    await tap(tester, find.byKey(const Key('who_self')));
    await tap(tester, find.byKey(const Key('pick_height')));
    await sheetTap(tester, find.text('5\'4"'));
    await tap(tester, next);

    // 3 — education: non-graduates cannot continue.
    await tap(tester, find.byKey(const Key('pick_alma')));
    await tap(tester, find.text('Aligarh Muslim University'));
    await tap(tester, find.byKey(const Key('alma_done')));
    await tap(tester, find.byKey(const Key('pick_qualification')));
    await sheetTap(tester, find.text('Diploma'));
    await tap(tester, next);
    expect(find.byKey(const Key('onboarding_error')), findsOneWidget);
    await tap(tester, find.byKey(const Key('pick_qualification')));
    await sheetTap(tester, find.text('MBA'));
    await tap(tester, find.byKey(const Key('pick_profession')));
    await sheetTap(tester, find.text('Doctor'));
    await tap(tester, next);

    // 4 — photos
    await tap(tester, next);
    expect(store.profile!.photos, <String>[photo]);
    await tap(tester, next);

    // 5 — verification
    expect(find.byKey(const Key('step_doc_name-proof')), findsOneWidget);
    await tap(tester, next);

    // 6 — review
    expect(find.text('Review and submit'), findsOneWidget);
    expect(store.isLoggedIn, isFalse, reason: 'intent and consent are required');
    await tap(tester, find.byKey(const Key('confirm_intent')));
    await tap(tester, find.byKey(const Key('confirm_consent')));
    await tap(tester, next);

    expect(store.isLoggedIn, isTrue);
    expect(find.text('Your profile is approved!'), findsOneWidget);
    await tap(tester, find.byKey(const Key('start_bismillah')));
    await tap(tester, find.byKey(const Key('how_to_got_it')));
    expect(find.text('Discover'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('an interrupted member resumes at their saved step', (
    WidgetTester tester,
  ) async {
    final (AppStore store, GoRouter router) = await pumpApp(
      tester,
      prefs: <String, Object>{
        'bk_stage': 'onboarding',
        'bk_profile': WardProfile.encode(
          const WardProfile(onboardingStep: 4, displayName: 'Sara'),
        ),
      },
    );
    expect(store.isSignedIn, isTrue);
    router.go(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    expect(find.text('Add your photos'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('home routes are closed to a signed-out visitor', (
    WidgetTester tester,
  ) async {
    final (_, GoRouter router) = await pumpApp(tester);
    router.go(AppRoutes.homeDiscovery);
    await tester.pumpAndSettle();
    expect(find.text('Create Account'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('sends a message without fabricating a reply', (
    WidgetTester tester,
  ) async {
    final (AppStore store, GoRouter router) =
        await pumpApp(tester, prefs: activePrefs);

    router.go(AppRoutes.homeChats);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_row_zayd-1')), findsOneWidget);
    await tap(tester, find.byKey(const Key('chat_row_zayd-1')));

    expect(find.byKey(const Key('chat_input')), findsOneWidget);
    final int before = store.messages('zayd-1').length;

    await tap(tester, find.byKey(const Key('chat_input')));
    await tester.enterText(
      find.byKey(const Key('chat_input')),
      'Assalamu alaikum, may Allah bless your family.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.messages('zayd-1').length, before + 1);
    expect(store.messages('zayd-1').last.sender, MessageSender.user);

    // No local timer may invent an incoming message or a chaperone note:
    // incoming traffic has to come from a messaging backend.
    await tester.pump(const Duration(seconds: 5));
    expect(store.messages('zayd-1').length, before + 1);
    expect(store.messages('zayd-1').last.sender, MessageSender.user);

    await tester.pumpAndSettle();
    await drain(tester);
  });

  testWidgets('browses the matches deck and shared contacts modes', (
    WidgetTester tester,
  ) async {
    final (_, _) = await pumpApp(tester, prefs: activePrefs);

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();

    // Chat Matches deck — zayd is seeded as an approved chat match.
    expect(find.text('Manage your matches here'), findsOneWidget);
    expect(find.byKey(const Key('match_deck_zayd-1')), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Unmatch'), findsOneWidget);

    // Switch to Shared Contacts — empty for the seeded persona.
    await tap(tester, find.byKey(const Key('matches_mode_contacts')));
    expect(find.text('No shared contacts yet'), findsOneWidget);

    await tap(tester, find.byKey(const Key('matches_mode_chats')));
    expect(find.byKey(const Key('match_deck_zayd-1')), findsOneWidget);
    await drain(tester);
  });

  testWidgets('received proposals can be accepted (journey D)', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await pumpApp(tester, prefs: activePrefs);

    await tester.tap(find.text('Proposals'));
    await tester.pumpAndSettle();

    // The Received tab used to be permanently empty: the store never
    // populated it, so this UI was unreachable (G-02).
    expect(find.textContaining('Received (2)'), findsOneWidget);
    await tap(tester, find.textContaining('Received (2)'));

    expect(find.byKey(const Key('accept_proposal_farhan-2')), findsOneWidget);
    expect(find.byKey(const Key('decline_proposal_farhan-2')), findsOneWidget);
    expect(store.isApproved('farhan-2'), isFalse);

    await tap(tester, find.byKey(const Key('accept_proposal_farhan-2')));

    expect(store.isApproved('farhan-2'), isTrue);
    expect(store.pendingRequestCount, 1);
    await drain(tester);
  });

  testWidgets('received proposals can be declined without matching', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await pumpApp(tester, prefs: activePrefs);

    await tester.tap(find.text('Proposals'));
    await tester.pumpAndSettle();
    await tap(tester, find.textContaining('Received (2)'));

    await tap(tester, find.byKey(const Key('decline_proposal_salman-5')));

    expect(store.isApproved('salman-5'), isFalse);
    expect(store.pendingRequestCount, 1);
    await drain(tester);
  });

  testWidgets('blocking from the profile menu removes the profile', (
    WidgetTester tester,
  ) async {
    final (AppStore store, GoRouter router) =
        await pumpApp(tester, prefs: activePrefs);

    unawaited(router.push(AppRoutes.matchDetail('imran-3')));
    await tester.pumpAndSettle();

    await tap(tester, find.byKey(const Key('detail_more')));
    await tap(tester, find.byKey(const Key('detail_block')));
    await tap(tester, find.byKey(const Key('detail_block_confirm')));

    expect(store.isBlocked('imran-3'), isTrue);
    expect(find.text('Discover'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('tapping a pending document does not approve it', (
    WidgetTester tester,
  ) async {
    final (AppStore store, GoRouter router) =
        await pumpApp(tester, prefs: activePrefs);

    router.go(AppRoutes.verifyProfile);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Education proof'));

    expect(
      store.verificationDocs
          .firstWhere((VerificationDoc d) => d.id == 'education-proof')
          .status,
      VerificationDocStatus.pending,
    );
    await drain(tester);
  });

  testWidgets('a match can open the journey and save answers', (WidgetTester tester) async {
    final (AppStore store, GoRouter router) = await pumpApp(tester, prefs: activePrefs);
    router.go(AppRoutes.journey('zayd-1'));
    await tester.pumpAndSettle();

    await tap(tester, find.byKey(const Key('journey_families')));
    expect(store.journeyStep('zayd-1'), JourneyStep.families);

    await tester.enterText(find.byKey(const Key('answer_deen1')), 'Five prayers');
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('save_answers')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_answers')));
    await tester.pumpAndSettle();

    expect((await store.myAnswers('zayd-1'))['deen1'], 'Five prayers');
    expect(await store.theirAnswers('zayd-1'), isNull);
    await drain(tester);
  });

  testWidgets('a member who used the free profiles sees the plans prompt', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await pumpApp(tester, prefs: activePrefs);
    expect(find.byKey(const Key('free_profiles_left')), findsOneWidget);
    for (final MatchProfile p in store.discoveredProfiles.toList()) {
      store.markProfileViewed(p.id);
    }
    for (final MatchProfile p in store.discoveredProfiles.toList()) {
      store.markIncompatible(p.id);
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unlock_more')), findsOneWidget);
    await tap(tester, find.byKey(const Key('see_plans')));
    expect(find.text('Plans'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('the app can be switched to Hindi from the first screen', (
    WidgetTester tester,
  ) async {
    addTearDown(() => AppStrings.current = AppLanguage.english);
    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('landing_language')));
    await tap(tester, find.text('हिन्दी'));
    expect(find.text('खाता बनाएँ'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);
    await drain(tester);
  });

  testWidgets('the profile tab links to the new features', (WidgetTester tester) async {
    final (_, GoRouter router) = await pumpApp(tester, prefs: activePrefs);
    router.go(AppRoutes.invite);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite_code')), findsOneWidget);
    router.go(AppRoutes.familyCircle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('invite_family')), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a profile can be shared with the Family Circle', (WidgetTester tester) async {
    final (AppStore store, GoRouter router) = await pumpApp(tester, prefs: activePrefs);
    unawaited(router.push(AppRoutes.matchDetail('imran-3')));
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('share_family_circle')));
    expect(store.family.shortlist.single.id, 'imran-3');
    await drain(tester);
  });

  testWidgets('the Safety Centre opens and lists warning signs', (WidgetTester tester) async {
    final (_, GoRouter router) = await pumpApp(tester, prefs: activePrefs);
    router.go(AppRoutes.safety);
    await tester.pumpAndSettle();
    expect(find.text('They ask for money'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('a family profile needs the person\'s agreement', (WidgetTester tester) async {
    final (_, GoRouter router) = await pumpApp(
      tester,
      prefs: <String, Object>{
        'bk_stage': 'onboarding',
        'bk_profile': WardProfile.encode(const WardProfile(onboardingStep: 2, height: '5\'4"')),
      },
    );
    router.go(AppRoutes.onboarding);
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('who_family')));
    await tap(tester, find.byKey(const Key('onboarding_next')));
    expect(find.byKey(const Key('onboarding_error')), findsOneWidget);
    await tap(tester, find.byKey(const Key('candidate_consent')));
    await tap(tester, find.byKey(const Key('onboarding_next')));
    expect(find.byKey(const Key('onboarding_error')), findsOneWidget, reason: 'their phone is required');
    await tester.enterText(find.byKey(const Key('subject_phone')), '+919876543210');
    await tap(tester, find.byKey(const Key('onboarding_next')));
    expect(find.text('Education & profession'), findsOneWidget);
    await drain(tester);
  });

  testWidgets('toggles modesty blur in settings', (WidgetTester tester) async {
    final (AppStore store, GoRouter router) =
        await pumpApp(tester, prefs: activePrefs);

    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(store.privacy('blurPhotos'), isTrue);
    await tester.scrollUntilVisible(
      find.text('Modesty blur on photos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final Finder tile =
        find.widgetWithText(SwitchTile, 'Modesty blur on photos');
    expect(tile, findsOneWidget);

    await tap(
      tester,
      find.descendant(of: tile, matching: find.byType(Switch)),
    );

    expect(store.privacy('blurPhotos'), isFalse);
    await drain(tester);
  });

  testWidgets('marks every notification read', (WidgetTester tester) async {
    final (AppStore store, GoRouter router) =
        await pumpApp(tester, prefs: activePrefs);

    expect(store.unreadNotificationCount, greaterThan(0));

    router.go(AppRoutes.notifications);
    await tester.pumpAndSettle();

    await tap(tester, find.text('Mark all read'));

    expect(store.unreadNotificationCount, 0);
    expect(find.text('Mark all read'), findsNothing);
    await drain(tester);
  });

  testWidgets('applies the wali-verified filter from the filters screen', (
    WidgetTester tester,
  ) async {
    final (AppStore store, GoRouter router) =
        await pumpApp(tester, prefs: activePrefs);

    router.go(AppRoutes.filters);
    await tester.pumpAndSettle();

    expect(store.filters.waliVerifiedOnly, isFalse);

    await tap(
      tester,
      find.descendant(
        of: find.byKey(const Key('wali_verified_switch')),
        matching: find.byType(Switch),
      ),
    );
    await tap(tester, find.byKey(const Key('apply_filters')));

    expect(store.filters.waliVerifiedOnly, isTrue);
    await drain(tester);
  });

}
