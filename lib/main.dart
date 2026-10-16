import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_router.dart';
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
  final AppStore store = AppStore(prefs);
  final GoRouter router = buildRouter(store);

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<AppStore>.value(value: store),
      ],
      child: BarkatNikahApp(router: router),
    ),
  );
}

class BarkatNikahApp extends StatelessWidget {
  const BarkatNikahApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Barkat Nikah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
