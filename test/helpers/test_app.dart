import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/main.dart';
import 'package:nikah_app/providers/app_store.dart';

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
const Map<String, Object> activePrefs = <String, Object>{
  'bk_stage': 'active',
  'bk_onboarded': true,
};

Future<(AppStore, GoRouter)> pumpApp(
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

Future<void> tap(WidgetTester tester, Finder finder) async {
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
Future<void> drain(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// Installs the fake image transport for a suite that renders network images.
void useFakeImageTransport() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });
  tearDownAll(() {
    HttpOverrides.global = null;
  });
}
