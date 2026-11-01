import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../config/app_config.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Shown after first sign-in, before the profile steps.
class StartProfileScreen extends StatelessWidget {
  const StartProfileScreen({super.key});

  Widget _row(IconData icon, String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: AppTheme.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: AppTheme.ts(14.5, FontWeight.w600, color: AppTheme.slate900)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(),
              Text(
                AppBrand.name,
                textAlign: TextAlign.center,
                style: AppTheme.ts(30, FontWeight.w800, color: AppTheme.green),
              ),
              const SizedBox(height: 8),
              Text(
                'Graduates only  ·  Manually reviewed profiles',
                textAlign: TextAlign.center,
                style: AppTheme.bodySmall,
              ),
              const Spacer(),
              _row(Icons.school_outlined, 'Profiles from top universities.'),
              _row(Icons.verified_user_outlined, 'Each profile is manually reviewed.'),
              _row(Icons.tune_rounded, 'Curated profiles everyday.'),
              const Spacer(flex: 2),
              PrimaryButton(
                key: const Key('start_profile'),
                label: 'Complete Your Profile',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.go(AppRoutes.onboarding),
              ),
              const SizedBox(height: 10),
              Text(
                'Takes a few minutes. Reviewed before you go live.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => context.read<AppStore>().signOut(),
                child: const Text('Log out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
