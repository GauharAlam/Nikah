import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'config/app_config.dart';
import 'data/firebase_backend.dart';
import 'l10n/app_strings.dart';
import 'providers/app_store.dart';
import 'providers/demo_app_store.dart';
import 'services/app_lock.dart';
import 'services/privacy_shield.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  await PrivacyShield.enable();
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final AppStore store;
  final BackendMode mode = AppConfig.mode;
  // The release check lets the compiler remove the demo from production.
  if (!kReleaseMode && mode == BackendMode.demo) {
    store = DemoAppStore(prefs);
  } else if (!kReleaseMode && mode == BackendMode.emulator) {
    await Firebase.initializeApp(options: _emulatorOptions);
    store = RemoteAppStore(prefs, FirebaseBackend.emulator(AppConfig.emulatorHost));
  } else {
    try {
      await Firebase.initializeApp();
    } on Object {
      runApp(const _SetupRequiredApp());
      return;
    }
    // A failure here must not stop the app. The server decides whether to require it.
    unawaited(FirebaseAppCheck.instance.activate().catchError((Object _) {}));
    store = RemoteAppStore(prefs, FirebaseBackend());
  }
  final GoRouter router = buildRouter(store);
  if (mode == BackendMode.firebase) unawaited(_routePushTaps(router));

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppStore>.value(value: store),
      ],
      child: BarkatNikahApp(router: router),
    ),
  );
}

/// The local emulators accept any values for an isolated `demo-` project. The
/// SDK checks only the shape of the key, so this is a placeholder, not a secret.
const FirebaseOptions _emulatorOptions = FirebaseOptions(
  apiKey: 'AIzaLOCALEMULATORONLYNOTAREALKEY0000000',
  appId: '1:1:android:1',
  messagingSenderId: '1',
  projectId: 'demo-nikah',
  storageBucket: 'demo-nikah.appspot.com',
);

/// Opens the screen named by a tapped notification.
Future<void> _routePushTaps(GoRouter router) async {
  void open(RemoteMessage message) {
    final String? link = safeDeepLink(message.data['deepLink']);
    if (link != null) unawaited(router.push(link));
  }

  final RemoteMessage? initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) open(initial);
  FirebaseMessaging.onMessageOpenedApp.listen(open);
}

class BarkatNikahApp extends StatefulWidget {
  const BarkatNikahApp({super.key, required this.router});

  final GoRouter router;

  @override
  State<BarkatNikahApp> createState() => _BarkatNikahAppState();
}

class _BarkatNikahAppState extends State<BarkatNikahApp> {
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();
  late final AppStore _store = context.read<AppStore>();

  @override
  void initState() {
    super.initState();
    _store.errors.addListener(_showError);
  }

  @override
  void dispose() {
    _store.errors.removeListener(_showError);
    super.dispose();
  }

  void _showError() {
    final String? message = _store.errors.value;
    if (message == null) return;
    _messenger.currentState?.showSnackBar(SnackBar(content: Text(message)));
    _store.errors.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: AppTheme.lightTheme,
      routerConfig: widget.router,
      builder: (BuildContext context, Widget? child) {
        // Rebuilds every screen when the language changes.
        final Widget page = AppLockGate(
          prefs: _store.prefs,
          child: KeyedSubtree(
            key: ValueKey<AppLanguage>(context.select<AppStore, AppLanguage>((AppStore s) => s.language)),
            child: child ?? const SizedBox.shrink(),
          ),
        );
        return AppConfig.isDemo
            ? Banner(message: 'DEMO', location: BannerLocation.topEnd, child: page)
            : page;
      },
    );
  }
}

/// A production build without its Firebase config files.
class _SetupRequiredApp extends StatelessWidget {
  const _SetupRequiredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This build is missing its Firebase configuration.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
