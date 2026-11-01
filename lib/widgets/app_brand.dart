import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The نکاح arch logo, in gold, for dark surfaces at 40 and above. Smaller than
/// that the arch fades, so use [NikahWordmark].
class NikahLogo extends StatelessWidget {
  const NikahLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/nikah-logo.png',
        width: size,
        height: size,
        semanticLabel: 'Nikah logo',
      );
}

/// نکاح on its own, for small marks. Gold on dark, or green on light.
class NikahWordmark extends StatelessWidget {
  const NikahWordmark({super.key, this.size = 24, this.green = false});

  final double size;
  final bool green;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/brand/nikah-word-${green ? 'green' : 'gold'}.png',
        width: size,
        height: size,
        excludeFromSemantics: true,
      );
}

/// Rounded-square forest-green app mark with the gold نکاح.
class NikahLogoMark extends StatelessWidget {
  const NikahLogoMark({super.key, this.size = 34});

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
      alignment: Alignment.center,
      child: NikahWordmark(size: size * 0.8),
    );
  }
}

/// Logo mark + "Nikah" wordmark used on the entry pages.
///
/// Renders the wordmark text exactly once so tests can locate it with a
/// single `find.text('Nikah')`.
class NikahLockup extends StatelessWidget {
  const NikahLockup({super.key, this.markSize = 34, this.fontSize = 17});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        NikahLogoMark(size: markSize),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            'Nikah',
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
