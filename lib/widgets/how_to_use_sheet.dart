import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';

/// Explains the three decisions on a profile, with the member's live limits.
Future<void> showHowToUseSheet(BuildContext context, AppStore store) {
  Widget action(IconData icon, Color color, String strong, String rest, String note) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text.rich(TextSpan(children: <InlineSpan>[
                  TextSpan(
                    text: strong,
                    style: AppTheme.ts(14.5, FontWeight.w800, color: AppTheme.slate900),
                  ),
                  TextSpan(
                    text: rest,
                    style: AppTheme.ts(14.5, FontWeight.w500, color: AppTheme.slate700),
                  ),
                ])),
                const SizedBox(height: 4),
                Text(note, style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget stat(int value, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('$value', style: AppTheme.ts(24, FontWeight.w800, color: AppTheme.green)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label, style: AppTheme.ts(14, FontWeight.w500, color: AppTheme.slate700)),
            ),
          ],
        ),
      );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTheme.ivoryWarm,
    builder: (BuildContext ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'How to Use ${AppBrand.name}',
              textAlign: TextAlign.center,
              style: AppTheme.ts(21, FontWeight.w800, color: AppTheme.slate900),
            ),
            const SizedBox(height: 4),
            Text(
              'Three ways to take decision on each profile',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            action(Icons.close_rounded, AppTheme.danger, 'Hides the profile',
                ' for few days.', 'Won\'t send notification.'),
            action(Icons.favorite_rounded, AppTheme.green, 'Shares your interest',
                ' to start chat.', 'Sends notification.'),
            action(Icons.call_rounded, AppTheme.goldAccent, 'Requests contact no.',
                ' to connect.', 'Sends notification.'),
            const SizedBox(height: 6),
            stat(store.decisionsPerDay, 'Decisions you can take'),
            stat(store.pendingLimit, 'Profiles in waiting you can have'),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('how_to_got_it'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    ),
  );
}
