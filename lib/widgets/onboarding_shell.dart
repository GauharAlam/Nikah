import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header for the seven profile steps, with one progress segment per step.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    required this.bottom,
    this.subtitle,
    this.onBack,
  });

  static const int totalSteps = 7;
  static const List<String> _cheers = <String>[
    'Great start',
    'Keep going',
    'Looking good',
    'Halfway there',
    'Almost there',
    'Ready to review',
    'Last step',
  ];

  final int step;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final int percent = (step * 100 / totalSteps).round();
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              ),
        title: Text(
          'Complete your profile',
          style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
        ),
        actions: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.mint.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$step of $totalSteps',
              style: AppTheme.ts(11.5, FontWeight.w800, color: AppTheme.green),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      for (int i = 1; i <= totalSteps; i++)
                        Expanded(
                          child: Container(
                            height: 5,
                            margin: EdgeInsets.only(right: i == totalSteps ? 0 : 5),
                            decoration: BoxDecoration(
                              color: i <= step ? AppTheme.green : AppTheme.slate200,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '$percent% Complete',
                        style: AppTheme.ts(11.5, FontWeight.w700, color: AppTheme.green),
                      ),
                      Text(
                        _cheers[step - 1],
                        style: AppTheme.ts(11.5, FontWeight.w700, color: AppTheme.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: <Widget>[
                  Text(
                    title,
                    style: AppTheme.ts(18, FontWeight.w800, color: AppTheme.slate900),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(subtitle!, style: AppTheme.bodySmall),
                  ],
                  const SizedBox(height: 18),
                  child,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: bottom,
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain form page for optional sections outside the seven steps.
class ProfileSectionShell extends StatelessWidget {
  const ProfileSectionShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: <Widget>[
            Text(subtitle, style: AppTheme.bodySmall),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
