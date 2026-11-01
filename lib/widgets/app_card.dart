import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard white card with soft border + shadow used across every screen.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.backgroundColor,
    this.radius = 16,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppTheme.slate200.withValues(alpha: 0.55),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.slate900.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: card),
    );
  }
}

/// Uppercase micro label used as a section kicker.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.color,
    this.requiredMark = false,
  });

  final String text;
  final Color? color;
  final bool requiredMark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.overline
                .copyWith(color: color ?? AppTheme.slate500, letterSpacing: 1.2),
          ),
        ),
        if (requiredMark)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text('•', style: TextStyle(color: AppTheme.goldAccent)),
          ),
      ],
    );
  }
}

/// Section title + optional helper line in forms.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AppTheme.h3),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 3),
                Text(subtitle!, style: AppTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 2×2-style demographic info tile with label above value.
class InfoTile extends StatelessWidget {
  const InfoTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.slate100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppTheme.ts(9.5, FontWeight.w700,
                color: AppTheme.slate500, letterSpacing: 1.1),
          ),
          const SizedBox(height: 5),
          Text(value, style: AppTheme.ts(13.5, FontWeight.w700, color: AppTheme.slate900)),
        ],
      ),
    );
  }
}

/// Small tinted chip, selected state variant for faith/practice filters.
class TagChip extends StatelessWidget {
  const TagChip(
    this.label, {
    super.key,
    this.selected = false,
    this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tint = color ?? (selected ? AppTheme.emerald : AppTheme.slate100);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.emerald : AppTheme.slate200,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: selected ? Colors.white : AppTheme.green),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppTheme.ts(12, FontWeight.w700,
                  color: selected ? Colors.white : AppTheme.slate700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon-with-gold-badge used for Wali-verified markers.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.label = 'Wali Verified'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.verified_user_outlined, color: AppTheme.gold, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTheme.ts(11, FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Chaperone-flow info strip rendered on dark headers.
class ChaperoneBadge extends StatelessWidget {
  const ChaperoneBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.shield_outlined, color: AppTheme.gold, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: AppTheme.ts(11, FontWeight.w600, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
