import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_router.dart';
import '../config/app_config.dart';
import '../data/backend.dart';
import '../l10n/app_strings.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_snacks.dart';
import '../widgets/picker_sheets.dart';

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
        label: Text(
          label,
          style: AppTheme.ts(16, FontWeight.w700, color: AppTheme.slate900),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle small = AppTheme.ts(
      12.5,
      FontWeight.w500,
      color: Colors.white70,
    );
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
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) =>
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: box.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                key: const Key('landing_language'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.translate_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.watch<AppStore>().language.label,
                                ),
                                onPressed: () => pickLanguage(context),
                              ),
                            ),
                            const Spacer(flex: 2),
                            const Icon(
                              Icons.mosque_rounded,
                              size: 72,
                              color: AppTheme.gold,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppBrand.name,
                              style: AppTheme.ts(
                                20,
                                FontWeight.w700,
                                color: AppTheme.gold,
                              ),
                            ),
                            const Spacer(flex: 3),
                            Text(
                              tr('Connect & Meet\nEducated Muslims for Nikah'),
                              textAlign: TextAlign.center,
                              style: AppTheme.ts(
                                25,
                                FontWeight.w800,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: <Widget>[
                                const Icon(
                                  Icons.school_rounded,
                                  size: 18,
                                  color: AppTheme.goldAccent,
                                ),
                                Text(
                                  tr('Graduates and Above'),
                                  style: AppTheme.ts(
                                    15,
                                    FontWeight.w600,
                                    color: AppTheme.goldAccent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              tr('Manually reviewed  ·  Alma Mater filter'),
                              textAlign: TextAlign.center,
                              style: AppTheme.ts(
                                12.5,
                                FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            TextButton(
                              key: const Key('how_it_works'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => const _HowItWorks(),
                              ),
                              child: Text(tr('How it works')),
                            ),
                            _authButton(
                              key: const Key('continue_phone'),
                              icon: Icons.phone_outlined,
                              label: tr('Continue with Phone'),
                              onPressed: _busy
                                  ? null
                                  : () => context.push(AppRoutes.signIn),
                            ),
                            const SizedBox(height: 12),
                            _authButton(
                              key: const Key('continue_google'),
                              icon: Icons.g_mobiledata_rounded,
                              label: _busy
                                  ? tr('Signing in…')
                                  : tr('Continue with Google'),
                              onPressed: _busy ? null : _google,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              alignment: WrapAlignment.center,
                              children: <Widget>[
                                Text(
                                  tr('By continuing, you agree to our '),
                                  style: small,
                                ),
                                GestureDetector(
                                  onTap: () => unawaited(
                                    launchUrl(Uri.parse(AppConfig.termsUrl)),
                                  ),
                                  child: Text(tr('Terms'), style: link),
                                ),
                                Text(' & ', style: small),
                                GestureDetector(
                                  onTap: () => unawaited(
                                    launchUrl(Uri.parse(AppConfig.privacyUrl)),
                                  ),
                                  child: Text(
                                    tr('Privacy Policy'),
                                    style: link,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the app is, before anyone signs up.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppTheme.green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTheme.ts(
                    15,
                    FontWeight.w800,
                    color: AppTheme.slate900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(body, style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            point(
              Icons.edit_note_rounded,
              tr('Create your profile'),
              tr('Our team reviews every profile before it goes live.'),
            ),
            point(
              Icons.verified_outlined,
              tr('Verified means reviewed'),
              tr(
                'A badge means we looked at the documents sent. It is not a background check or a guarantee.',
              ),
            ),
            point(
              Icons.lock_outline_rounded,
              tr('Private by default'),
              tr(
                'Your number stays hidden until you accept a request. You choose who sees your photos.',
              ),
            ),
            point(
              Icons.groups_outlined,
              tr('Family if you want'),
              tr(
                'Invite family and decide what each person can do. They never see your chats.',
              ),
            ),
            point(
              Icons.favorite_outline_rounded,
              tr('Only mutual interest'),
              tr('A match opens only when both of you say yes.'),
            ),
          ],
        ),
      ),
    );
  }
}
