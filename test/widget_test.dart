import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/main.dart';
import 'package:nikah_app/models/chat_message.dart';
import 'package:nikah_app/models/match_profile.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:nikah_app/widgets/app_switch.dart';

const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _TestHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TestHttpClientRequest();
}

class _TestHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _TestHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
}

class _TestHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _TestHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _TestHttpClient();
}

/// State persisted as if the member had already finished onboarding.
const Map<String, Object> _activePrefs = <String, Object>{
  'bk_stage': 'active',
  'bk_onboarded': true,
};

Future<(AppStore, GoRouter)> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(prefs);
  final SharedPreferences sp = await SharedPreferences.getInstance();
  final AppStore store = AppStore(sp);
  addTearDown(store.dispose);
  final GoRouter router = buildRouter(store);

  await tester.pumpWidget(
    ChangeNotifierProvider<AppStore>.value(
      value: store,
      child: BarkatNikahApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return (store, router);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  bool unbuilt;
  try {
    unbuilt = finder.evaluate().isEmpty;
  } on Object {
    unbuilt = true;
  }
  if (unbuilt) {
    await tester.scrollUntilVisible(
      finder,
      150.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }
  try {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  } on Object {
    // Widget has no scrollable ancestor — tap it where it stands.
  }
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Lets snackbars and delayed callbacks expire so no timers outlive the test.
Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('boots to landing and explores as guest', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await _pumpApp(tester);

    expect(find.text('Barkat Nikah'), findsOneWidget);
    expect(
      find.textContaining('Where educated', findRichText: true),
      findsOneWidget,
    );

    await _tap(tester, find.text('Explore Profiles as Guest'));

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Proposals'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(store.stage, AuthStage.guest);
    await _drain(tester);
  });

  testWidgets('signs in from landing into the home shell', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await _pumpApp(tester);

    await _tap(tester, find.text('Already a member? Sign In'));
    expect(find.text('Sign In Securely'), findsOneWidget);

    await _tap(tester, find.text('Sign In Securely'));

    expect(find.text('Discover'), findsOneWidget);
    expect(store.isLoggedIn, isTrue);
    await _drain(tester);
  });

  testWidgets('completes onboarding through to the discovery deck', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await _pumpApp(tester);

    await _tap(tester, find.text('Create My Account'));

    // Step 1 — account details and honor pledge.
    await _tap(
      tester,
      find.text('My intention is a sincere halal Nikah for the sake of Allah.'),
    );
    await _tap(
      tester,
      find.text('My Wali (guardian) is aware of and consents to this search.'),
    );
    await _tap(
      tester,
      find.text('My biodata is truthful, modest and written with adab.'),
    );

    // Pick the date of birth through the date picker.
    final Finder dobField = find.byWidgetPredicate(
      (Widget w) =>
          w is TextField &&
          w.decoration?.hintText == 'Select date of birth',
    );
    await _tap(tester, dobField);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('OK'));

    await _tap(tester, find.text('Save & Continue'));

    // Step 2 — education & career (demo defaults prefilled).
    await _tap(tester, find.text('Save & Continue'));

    // Step 3 — deen & practice.
    await _tap(tester, find.text('Save & Continue'));

    // Step 4 — photos & verification: upload one proof document.
    await _tap(tester, find.byKey(const Key('upload_doc_photo-proof')));
    expect(
      store.verificationDocs
          .firstWhere((VerificationDoc d) => d.id == 'photo-proof')
          .status,
      VerificationDocStatus.pending,
    );
    await _tap(tester, find.text('Save & Continue'));

    // Step 5 — wali details (prefilled for the demo persona).
    await _tap(tester, find.text('Save & Continue'));

    // Step 6 — biodata builder.
    await _tap(tester, find.text('Review My Biodata'));

    // Review — submit for guardian verification.
    await _tap(tester, find.byType(Checkbox));
    await _tap(tester, find.text('Submit for Guardian Verification'));

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(store.isLoggedIn, isTrue);
    await _drain(tester);
  });

  testWidgets('sends a message and receives the chaperoned reply flow', (
    WidgetTester tester,
  ) async {
    final (AppStore store, GoRouter router) =
        await _pumpApp(tester, prefs: _activePrefs);

    router.go(AppRoutes.homeChats);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_row_zayd-1')), findsOneWidget);
    await _tap(tester, find.byKey(const Key('chat_row_zayd-1')));

    expect(find.byKey(const Key('chat_input')), findsOneWidget);
    final int before = store.messages('zayd-1').length;

    await _tap(tester, find.byKey(const Key('chat_input')));
    await tester.enterText(
      find.byKey(const Key('chat_input')),
      'Assalamu alaikum, may Allah bless your family.',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(store.messages('zayd-1').length, before + 1);
    expect(store.messages('zayd-1').last.sender, MessageSender.user);

    // Wali-supervised auto reply arrives after ~1.4s.
    await tester.pump(const Duration(seconds: 2));
    expect(store.messages('zayd-1').length, before + 2);
    expect(store.messages('zayd-1').last.sender, MessageSender.match);

    // The chaperone audit note lands after ~3.2s.
    await tester.pump(const Duration(seconds: 3));
    expect(store.messages('zayd-1').last.sender, MessageSender.chaperone);

    await tester.pumpAndSettle();
    await _drain(tester);
  });

  testWidgets('browses the matches deck and shared contacts modes', (
    WidgetTester tester,
  ) async {
    final (_, _) = await _pumpApp(tester, prefs: _activePrefs);

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();

    // Chat Matches deck — zayd is seeded as an approved chat match.
    expect(find.text('Manage your matches here'), findsOneWidget);
    expect(find.byKey(const Key('match_deck_zayd-1')), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Unmatch'), findsOneWidget);

    // Switch to Shared Contacts — empty for the seeded persona.
    await _tap(tester, find.byKey(const Key('matches_mode_contacts')));
    expect(find.text('No shared contacts yet'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('matches_mode_chats')));
    expect(find.byKey(const Key('match_deck_zayd-1')), findsOneWidget);
    await _drain(tester);
  });

  testWidgets('toggles modesty blur in settings', (WidgetTester tester) async {
    final (AppStore store, GoRouter router) =
        await _pumpApp(tester, prefs: _activePrefs);

    router.go(AppRoutes.settings);
    await tester.pumpAndSettle();

    expect(store.privacy('blurPhotos'), isTrue);
    final Finder tile =
        find.widgetWithText(SwitchTile, 'Modesty blur on photos');
    expect(tile, findsOneWidget);

    await _tap(
      tester,
      find.descendant(of: tile, matching: find.byType(Switch)),
    );

    expect(store.privacy('blurPhotos'), isFalse);
    await _drain(tester);
  });

  testWidgets('marks every notification read', (WidgetTester tester) async {
    final (AppStore store, GoRouter router) =
        await _pumpApp(tester, prefs: _activePrefs);

    expect(store.unreadNotificationCount, greaterThan(0));

    router.go(AppRoutes.notifications);
    await tester.pumpAndSettle();

    await _tap(tester, find.text('Mark all read'));

    expect(store.unreadNotificationCount, 0);
    expect(find.text('Mark all read'), findsNothing);
    await _drain(tester);
  });

  testWidgets('applies the wali-verified filter from the filters screen', (
    WidgetTester tester,
  ) async {
    final (AppStore store, GoRouter router) = await _pumpApp(tester);

    router.go(AppRoutes.filters);
    await tester.pumpAndSettle();

    expect(store.filters.waliVerifiedOnly, isFalse);

    await _tap(
      tester,
      find.descendant(
        of: find.byKey(const Key('wali_verified_switch')),
        matching: find.byType(Switch),
      ),
    );
    await _tap(tester, find.byKey(const Key('apply_filters')));

    expect(store.filters.waliVerifiedOnly, isTrue);
    await _drain(tester);
  });

  testWidgets('enforces the five-a-day proposal quota', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await _pumpApp(tester, prefs: _activePrefs);

    expect(store.proposalsLeft, 5);
    for (final MatchProfile profile in MatchProfile.seeds) {
      expect(store.sendProposal(profile.id), isTrue);
    }
    expect(store.proposalsLeft, 0);
    expect(store.proposalsSentList.length, MatchProfile.seeds.length);
    expect(store.sendProposal('sixth-slot'), isFalse);
    await _drain(tester);
  });

  testWidgets('contact request spends a gold credit and auto-approves', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await _pumpApp(tester, prefs: _activePrefs);

    expect(store.contactCredits, 30);
    expect(store.isContactShared('farhan-2'), isFalse);
    expect(store.requestContact('farhan-2'), isTrue);
    expect(store.contactCredits, 29);
    expect(store.contactRequested('farhan-2'), isTrue);
    expect(store.isContactShared('farhan-2'), isFalse);

    // The demo family approves shortly after (~2.4s).
    await tester.pump(const Duration(milliseconds: 2500));
    expect(store.isContactShared('farhan-2'), isTrue);
    await _drain(tester);
  });

  testWidgets('verification documents drive the Barkat verified badge', (
    WidgetTester tester,
  ) async {
    final (AppStore store, _) = await _pumpApp(tester, prefs: _activePrefs);

    expect(store.isBarkatVerified, isFalse);

    store.submitVerificationDoc('education-proof');
    expect(
      store.verificationDocs
          .firstWhere((VerificationDoc d) => d.id == 'education-proof')
          .status,
      VerificationDocStatus.pending,
    );
    store.approveVerificationDoc('education-proof');

    store.submitVerificationDoc('photo-proof');
    store.approveVerificationDoc('photo-proof');

    expect(store.isBarkatVerified, isTrue);
    expect(store.verificationProgress, 100);
    await _drain(tester);
  });
}
