import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared scaffold for the 6-step onboarding flow: step kicker, title,
/// progress bar (n/6) and back affordance.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget child;

  static const List<String> stepLabels = <String>[
    'Account',
    'Education',
    'Practice',
    'Photos',
    'Wali',
    'Biodata',
  ];

  @override
  Widget build(BuildContext context) {
    final double progress = step / 6;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        // Router-driven back: use raw pop; TitleBar icon only.
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.sage.withValues(alpha: 0.6)),
          ),
          child: Text(
            'STEP $step OF 6 · ${stepLabels[step - 1].toUpperCase()}',
            style: AppTheme.ts(
              10,
              FontWeight.w800,
              color: AppTheme.green,
              letterSpacing: 0.9,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(9),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 7, top: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppTheme.slate200,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          children: <Widget>[
            Text(
              title,
              style: AppTheme.ts(23, FontWeight.w800, color: AppTheme.slate900, height: 1.2),
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: AppTheme.bodySmall),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}
