import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Consistent pill-styled primary button (uses themed ElevatedButton).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.progress = false,
    this.block,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool progress;
  final bool? block;

  @override
  Widget build(BuildContext context) {
    final bool filled = block ?? true;
    final Widget child = Row(
      mainAxisSize: filled ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (progress)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: Colors.white),
        if ((progress || icon != null)) const SizedBox(width: 9),
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    return SizedBox(
      width: filled ? double.infinity : null,
      child: ElevatedButton(
        onPressed: progress ? null : onPressed,
        child: child,
      ),
    );
  }
}

/// Inverse button on dark/emerald backgrounds.
class PositiveOutlinedButton extends StatelessWidget {
  const PositiveOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.gold = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Light-surface gold variant (Barkat contact actions).
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: gold ? AppTheme.goldInk : Colors.white,
          backgroundColor: gold ? AppTheme.warningBg : Colors.transparent,
          side: BorderSide(
            color: gold
                ? AppTheme.goldAccent.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.45),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 17),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Neutral action row used for risky actions (sign out etc.).
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.danger,
          side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label),
      ),
    );
  }
}
