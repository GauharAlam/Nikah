import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded-square forest-green app mark with the white mosque glyph —
/// mirrors the Barkat logo lockup.
class BarkatLogoMark extends StatelessWidget {
  const BarkatLogoMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.brandWash,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.slate900.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.mosque_rounded,
        size: size * 0.56,
        color: Colors.white,
      ),
    );
  }
}

/// Logo mark + "Barkat Nikah" wordmark used on the entry pages.
///
/// Renders the wordmark text exactly once so tests can locate it with a
/// single `find.text('Barkat Nikah')`.
class BarkatLockup extends StatelessWidget {
  const BarkatLockup({super.key, this.markSize = 34, this.fontSize = 17});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BarkatLogoMark(size: markSize),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            'Barkat Nikah',
            style: AppTheme.ts(
              fontSize,
              FontWeight.w800,
              color: AppTheme.slate900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Gold laurel "100% reviewed" seal used on marketing surfaces.
class GoldSeal extends StatelessWidget {
  const GoldSeal({super.key, this.size = 46});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE9CE6E), AppTheme.goldAccent, Color(0xFFB8973B)],
        ),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.slate900.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded, size: size * 0.30, color: Colors.white),
          Text(
            '100%',
            style: AppTheme.ts(size * 0.17, FontWeight.w800, color: Colors.white),
          ),
          Text(
            'REVIEWED',
            style: AppTheme.ts(
              size * 0.115,
              FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small white university chip used on the landing hero ("AMU · Jamia …").
class CampusChip extends StatelessWidget {
  const CampusChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTheme.ts(10.5, FontWeight.w700, color: AppTheme.slate800),
      ),
    );
  }
}
