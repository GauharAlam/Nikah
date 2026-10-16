import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Friendly placeholder for empty lists (no conversations, no
/// notifications, etc.).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Icon(icon, size: 30, color: AppTheme.slate400),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
            ),
            const SizedBox(height: 7),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTheme.ts(13, FontWeight.w500, color: AppTheme.slate500, height: 1.5),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
