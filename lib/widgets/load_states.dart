import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// A calm placeholder list while data loads.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('app_skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: rows,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Row(
        children: <Widget>[
          const CircleAvatar(radius: 22, backgroundColor: AppTheme.slate200),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(height: 12, width: double.infinity, color: AppTheme.slate200),
                const SizedBox(height: 8),
                Container(height: 10, width: 140, color: AppTheme.slate200),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A failed load, with a way to try again.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.slate400),
            const SizedBox(height: 10),
            Text(message, key: const Key('error_message'), textAlign: TextAlign.center, style: AppTheme.bodySmall),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const Key('error_retry'),
              onPressed: onRetry,
              child: Text(tr('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
