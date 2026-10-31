import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/widgets/app_switch.dart';

import '../helpers/test_app.dart';

void main() {
  useFakeImageTransport();

  testWidgets('boots to landing and explores as guest', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await pumpApp(tester);

    expect(find.text('Barkat Nikah'), findsOneWidget);
    expect(
      find.textContaining('Where educated', findRichText: true),
      findsOneWidget,
    );

    await tap(tester, find.text('Explore Profiles as Guest'));

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Proposals'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(store.stage, AuthStage.guest);
    await drain(tester);
  });

  testWidgets('signs in from landing into the home shell', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await pumpApp(tester);

    await tap(tester, find.text('Already a member? Sign In'));
    expect(find.text('Sign In Securely'), findsOneWidget);

    await tap(tester, find.text('Sign In Securely'));

    expect(find.text('Discover'), findsOneWidget);
    expect(store.isLoggedIn, isTrue);
    await drain(tester);
  });

  testWidgets('completes onboarding through to the discovery deck', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await pumpApp(tester);

    await tap(tester, find.text('Create My Account'));

    // Step 1 — account details and honor pledge.
    await tap(
      tester,
      find.text('My intention is a sincere halal Nikah for the sake of Allah.'),
    );
    await tap(
      tester,
      find.text('My Wali (guardian) is aware of and consents to this search.'),
    );
    await tap(
      tester,
      find.text('My biodata is truthful, modest and written with adab.'),
    );

    // Pick the date of birth through the date picker.
    final Finder dobField = find.byWidgetPredicate(
      (Widget w) =>
          w is TextField &&
          w.decoration?.hintText == 'Select date of birth',
    );
    await tap(tester, dobField);
    await tester.pumpAndSettle();
    await tap(tester, find.text('OK'));

    await tap(tester, find.text('Save & Continue'));

    // Step 2 — education & career (demo defaults prefilled).
    await tap(tester, find.text('Save & Continue'));

    // Step 3 — deen & practice.
    await tap(tester, find.text('Save & Continue'));

    // Step 4 — photos & verification: upload one proof document.
    await tap(tester, find.byKey(const Key('upload_doc_photo-proof')));
    expect(
      store.verificationDocs
          .firstWhere((VerificationDoc d) => d.id == 'photo-proof')
          .status,
      VerificationDocStatus.pending,
    );
    await tap(tester, find.text('Save & Continue'));

    // Step 5 — wali details (prefilled for the demo persona).
    await tap(tester, find.text('Save & Continue'));

    // Step 6 — biodata builder.
    await tap(tester, find.text('Review My Biodata'));

    // Review — submit for guardian verification.
    await tap(tester, find.byType(Checkbox));
    await tap(tester, find.text('Submit for Guardian Verification'));

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(store.isLoggedIn, isTrue);
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

  testWidgets('toggles modesty blur in settings', (WidgetTester tester) async {
    final (AppStore store, GoRouter router) =
        await pumpApp(tester, prefs: activePrefs);

    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(store.privacy('blurPhotos'), isTrue);
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
    final (AppStore store, GoRouter router) = await pumpApp(tester);

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
