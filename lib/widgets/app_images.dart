import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Network image with graceful error + loading states (fixes the old
/// grey-box behaviour when offline).
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorIcon = Icons.person_off_outlined,
    this.filterQuality,
    this.color,
  });

  final String url;
  final BoxFit fit;
  final double? borderRadius;
  final IconData errorIcon;
  final FilterQuality? filterQuality;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.network(
      url,
      fit: fit,
      color: color,
      colorBlendMode: color != null ? BlendMode.srcATop : null,
      filterQuality: filterQuality ?? FilterQuality.low,
      errorBuilder: (_, _, _) => Container(
        color: AppTheme.emeraldDeep,
        alignment: Alignment.center,
        child: Icon(errorIcon, color: AppTheme.gold.withValues(alpha: 0.8), size: 30),
      ),
      frameBuilder: (_, Widget child, int? frame, bool wasSync) {
        if (wasSync || frame != null) return child;
        return Container(
          color: AppTheme.emeraldDeep,
          alignment: Alignment.center,
          child: const Icon(
            Icons.hourglass_empty_rounded,
            color: AppTheme.gold,
            size: 22,
          ),
        );
      },
    );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: BorderRadius.circular(borderRadius!), child: image);
  }
}

/// Circular avatar with initials fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.url,
    this.radius = 22,
    this.initials,
  });

  final double radius;
  final String? initials;
  final String url;

  @override
  Widget build(BuildContext context) {
    final String? trimmed = url.trim().isEmpty ? null : url.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.slate300,
      foregroundImage: trimmed == null ? null : NetworkImage(trimmed),
      onForegroundImageError: trimmed == null ? null : (_, _) {},
      child: initials == null
          ? const Icon(Icons.person, color: AppTheme.slate500)
          : Text(
              initials!,
              style: AppTheme.ts(radius > 18 ? 14 : 12, FontWeight.w800, color: AppTheme.slate600),
            ),
    );
  }
}
