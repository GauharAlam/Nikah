import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Switch row used by wali hub / onboarding permission lists — replaces
/// the two duplicated `_buildSwitchRow`/`_buildSwitchTile` helpers.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.slate100.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTheme.ts(13.5, FontWeight.w700, color: AppTheme.slate900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTheme.ts(11.5, FontWeight.w500, color: AppTheme.slate500, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Settings-style white switch tile used on profile/settings screens.
class SwitchTile extends StatelessWidget {
  const SwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: AppTheme.slate600),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AppTheme.ts(14, FontWeight.w700, color: AppTheme.slate800)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
