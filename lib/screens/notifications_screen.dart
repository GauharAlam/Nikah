import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/notification_item.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_state.dart';

/// Full notification feed with read-state handling and deep links.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<NotificationItem> items = store.notifications;
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (store.unreadNotificationCount > 0)
            TextButton(
              onPressed: store.markAllNotificationsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'No notifications yet',
              body: 'Introductions, guardian approvals and milestones will '
                  'appear here, in sha Allah.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final NotificationItem item = items[index];
                return _NotificationCard(
                  item: item,
                  onTap: () {
                    store.markNotificationRead(item.id);
                    final String? link = item.deepLink;
                    if (link != null && link.startsWith('/')) {
                      context.go(link);
                    }
                  },
                );
              },
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  String get _timeAgo {
    final Duration diff = DateTime.now().difference(item.createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notificationColor(item.type),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  notificationIcon(item.type),
                  size: 18,
                  color: notificationForegroundColor(item.type),
                ),
              ),
              if (!item.isRead)
                Positioned(
                  top: 1,
                  right: 1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppTheme.goldAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTheme.ts(
                          item.isRead ? 13.5 : 14,
                          item.isRead ? FontWeight.w600 : FontWeight.w800,
                          color: AppTheme.slate900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo,
                      style: AppTheme.ts(11, FontWeight.w600,
                          color: AppTheme.slate400),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.body,
                  style: AppTheme.ts(12.5, FontWeight.w500,
                      color: AppTheme.slate600, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
