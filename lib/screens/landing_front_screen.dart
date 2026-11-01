import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_router.dart';
import '../config/app_config.dart';
import '../data/backend.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snacks.dart';

/// First screen: sign in with phone or Google.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await context.read<AppStore>().signInWithGoogle();
    } on BackendException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    } on Object {
      if (mounted) showAppSnack(context, 'Google sign-in did not complete.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _authButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        key: key,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.slate900,
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label, style: AppTheme.ts(16, FontWeight.w700, color: AppTheme.slate900)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle small = AppTheme.ts(12.5, FontWeight.w500, color: Colors.white70);
    final TextStyle link = small.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: Colors.white,
    );
    return Scaffold(
      backgroundColor: AppTheme.emeraldDeep,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppTheme.emerald, AppTheme.emeraldDeep],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: <Widget>[
                  const Spacer(flex: 2),
                  const Icon(Icons.mosque_rounded, size: 72, color: AppTheme.gold),
                  const SizedBox(height: 12),
                  Text(
                    AppBrand.name,
                    style: AppTheme.ts(20, FontWeight.w700, color: AppTheme.gold),
                  ),
                  const Spacer(flex: 3),
                  Text(
                    'Connect & Meet\nEducated Muslims for Nikah',
                    textAlign: TextAlign.center,
                    style: AppTheme.ts(25, FontWeight.w800, color: Colors.white, height: 1.25),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const Icon(Icons.school_rounded, size: 18, color: AppTheme.goldAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Graduates and Above',
                        style: AppTheme.ts(15, FontWeight.w600, color: AppTheme.goldAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Manually reviewed  ·  Alma Mater filter',
                    style: AppTheme.ts(12.5, FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  _authButton(
                    key: const Key('continue_phone'),
                    icon: Icons.phone_outlined,
                    label: 'Continue with Phone',
                    onPressed: _busy ? null : () => context.push(AppRoutes.signIn),
                  ),
                  const SizedBox(height: 12),
                  _authButton(
                    key: const Key('continue_google'),
                    icon: Icons.g_mobiledata_rounded,
                    label: _busy ? 'Signing in…' : 'Continue with Google',
                    onPressed: _busy ? null : _google,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Text('By continuing, you agree to our ', style: small),
                      GestureDetector(
                        onTap: () => unawaited(launchUrl(Uri.parse(AppConfig.termsUrl))),
                        child: Text('Terms', style: link),
                      ),
                      Text(' & ', style: small),
                      GestureDetector(
                        onTap: () => unawaited(launchUrl(Uri.parse(AppConfig.privacyUrl))),
                        child: Text('Privacy Policy', style: link),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
