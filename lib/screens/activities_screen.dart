// Activities tab — the trust timeline of everything that happened on the
// account (Barkat style).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification_item.dart';
import '../models/wali.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_card.dart';
import '../widgets/app_inputs.dart';
import '../widgets/empty_state.dart';

enum _ActivityTab { timeline, notifications }

/// Activities tab of the home shell.
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  _ActivityTab _tab = _ActivityTab.timeline;

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<ActivityLogEntry> log = store.activityLog;
    final List<NotificationItem> notifications = store.notifications;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Activities',
          style: AppTheme.ts(17, FontWeight.w800, color: AppTheme.slate900),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: AppSegmentedToggle<_ActivityTab>(
              options: <SegmentedOption<_ActivityTab>>[
                SegmentedOption<_ActivityTab>(
                  value: _ActivityTab.timeline,
                  label: 'Timeline (${log.length})',
                  icon: Icons.timeline_rounded,
                ),
                SegmentedOption<_ActivityTab>(
                  value: _ActivityTab.notifications,
                  label: 'Alerts (${notifications.length})',
                  icon: Icons.notifications_none_rounded,
                ),
              ],
              selected: _tab,
              onChanged: (_ActivityTab next) => setState(() => _tab = next),
            ),
          ),
          Expanded(
            child: _tab == _ActivityTab.timeline
                ? (log.isEmpty
                    ? const EmptyState(
                        icon: Icons.timeline_rounded,
                        title: 'Nothing yet',
                        body: 'Proposals, chats and verifications will appear '
                            'here as your search progresses.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: log.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, int index) =>
                            _TimelineTile(entry: log[index]),
                      ))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, int index) =>
                        _AlertTile(item: notifications[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

IconData _kindIcon(ActivityKind kind) => switch (kind) {
  ActivityKind.intro => Icons.favorite_rounded,
  ActivityKind.chat => Icons.chat_bubble_rounded,
  ActivityKind.meeting => Icons.event_available_rounded,
  ActivityKind.verification => Icons.verified_user_rounded,
  ActivityKind.general => Icons.bolt_rounded,
};

Color _kindBg(ActivityKind kind) => switch (kind) {
  ActivityKind.intro => const Color(0xFFFDE8E8),
  ActivityKind.chat => AppTheme.successBg,
  ActivityKind.meeting => const Color(0xFFEFE9FB),
  ActivityKind.verification => AppTheme.successBg,
  ActivityKind.general => AppTheme.slate100,
};

Color _kindFg(ActivityKind kind) => switch (kind) {
  ActivityKind.intro => AppTheme.danger,
  ActivityKind.chat => AppTheme.green,
  ActivityKind.meeting => const Color(0xFF6B4ED0),
  ActivityKind.verification => AppTheme.success,
  ActivityKind.general => AppTheme.slate600,
};

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry});

  final ActivityLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kindBg(entry.kind),
              shape: BoxShape.circle,
            ),
            child: Icon(_kindIcon(entry.kind), size: 18, color: _kindFg(entry.kind)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.title,
                        style: AppTheme.ts(
                          13.5,
                          FontWeight.w800,
                          color: AppTheme.slate900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relative(entry.createdAt),
                      style: AppTheme.ts(10.5, FontWeight.w600, color: AppTheme.slate400),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.detail,
                  style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: notificationColor(item.type),
              shape: BoxShape.circle,
            ),
            child: Icon(
              notificationIcon(item.type),
              size: 18,
              color: notificationForegroundColor(item.type),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTheme.ts(
                          item.isRead ? 13.5 : 13.5,
                          item.isRead ? FontWeight.w700 : FontWeight.w800,
                          color: AppTheme.slate900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!item.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          color: AppTheme.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500, height: 1.4),
                ),
                const SizedBox(height: 5),
                Text(
                  _relative(item.createdAt),
                  style: AppTheme.ts(10.5, FontWeight.w600, color: AppTheme.slate400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _relative(DateTime time) {
  final Duration diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
