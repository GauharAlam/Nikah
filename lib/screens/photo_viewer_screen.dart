/// Full-screen photo viewer with chaperoned-adab framing and fade-in.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/privacy_shield.dart';
import '../theme/app_theme.dart';
import '../widgets/app_images.dart';

/// Immersive black viewer: pinch-zoom image, wali-modesty footer.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.imageUrl, this.personName});

  final String imageUrl;
  final String? personName;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;

  @override
  void initState() {
    super.initState();
    unawaited(PrivacyShield.enable());
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    unawaited(PrivacyShield.disable());
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasImage = widget.imageUrl.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: widget.personName == null || widget.personName!.isEmpty
            ? null
            : Text(
                widget.personName!,
                style: AppTheme.ts(15, FontWeight.w700, color: Colors.white),
              ),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
        child: Column(
          children: <Widget>[
            Expanded(
              child: hasImage
                  ? InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 3,
                      clipBehavior: Clip.none,
                      child: Center(
                        child: AppNetworkImage(
                          url: widget.imageUrl,
                          fit: BoxFit.contain,
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
            ),
            const _ViewerInfoBar(),
          ],
        ),
      ),
    );
  }
}

/// Gold-tinted adab footer with disabled like/reaction affordances.
class _ViewerInfoBar extends StatelessWidget {
  const _ViewerInfoBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.verified_user_outlined,
              size: 15,
              color: AppTheme.gold,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viewed with adab — Photos remain modesty-checked by both '
                'Wali',
                style: AppTheme.ts(
                  11.5,
                  FontWeight.w600,
                  color: AppTheme.gold,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Opacity(
              opacity: 0.45,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const _GhostAction(
                    icon: Icons.favorite_border_rounded,
                    tooltip: 'Likes disabled',
                  ),
                  const _GhostAction(
                    icon: Icons.emoji_emotions_outlined,
                    tooltip: 'Reactions disabled',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Disabled icon action (intentionally inert for chaperone control).
class _GhostAction extends StatelessWidget {
  const _GhostAction({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: Colors.white,
      icon: Icon(icon, size: 17),
    );
  }
}
