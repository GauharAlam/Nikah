import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
import 'config/app_config.dart';
import 'data/firebase_backend.dart';
import 'providers/app_store.dart';
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
  if (AppConfig.isDemo) {
    store = AppStore(prefs);
  } else {
    try {
      await Firebase.initializeApp();
    } on Object {
      runApp(const _SetupRequiredApp());
      return;
    }
    store = RemoteAppStore(prefs, FirebaseBackend());
  }
  final GoRouter router = buildRouter(store);
  if (!AppConfig.isDemo) unawaited(_routePushTaps(router));

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppStore>.value(value: store),
      ],
      child: BarkatNikahApp(router: router),
    ),
  );
}

/// Opens the screen named by a tapped notification.
Future<void> _routePushTaps(GoRouter router) async {
  void open(RemoteMessage message) {
    final Object? link = message.data['deepLink'];
    if (link is String && link.startsWith('/')) unawaited(router.push(link));
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
      builder: (_, Widget? child) => AppConfig.isDemo
          ? Banner(
              message: 'DEMO',
              location: BannerLocation.topEnd,
              child: child ?? const SizedBox.shrink(),
            )
          : child ?? const SizedBox.shrink(),
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
