import 'package:flutter/material.dart';

import '../models/notification_item.dart' show NotificationType;
import '../theme/app_theme.dart';

/// Tinted info strip at the top of forms and portals.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.variant = InfoVariant.info,
    this.trailing,
    this.tight = false,
  });

  final IconData icon;
  final String text;
  final InfoVariant variant;
  final Widget? trailing;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (variant) {
      InfoVariant.success => (AppTheme.successBg, AppTheme.success),
      InfoVariant.warning => (AppTheme.warningBg, AppTheme.warning),
      InfoVariant.danger => (AppTheme.dangerBg, AppTheme.danger),
      InfoVariant.gold => (AppTheme.gold, AppTheme.goldDeep),
      InfoVariant.info => (AppTheme.infoBg, AppTheme.info),
      InfoVariant.neutral => (AppTheme.slate100, AppTheme.slate700),
    };

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 10,
        top: tight ? 10 : 12,
        bottom: tight ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTheme.ts(12, FontWeight.w600, color: fg, height: 1.35),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

enum InfoVariant { success, warning, danger, info, gold, neutral }

/// List of settings/notification rows with divider look.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.leadingBg,
    this.leadingFg,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? leadingBg;
  final Color? leadingFg;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color fg = danger ? AppTheme.danger : AppTheme.slate800;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: leadingBg ?? AppTheme.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: leadingFg ?? (danger ? AppTheme.danger : AppTheme.slate700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppTheme.ts(14, FontWeight.w700, color: fg)),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTheme.ts(12, FontWeight.w500, color: AppTheme.slate500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Notification icon shown in AppBars with unread dot.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.unread, this.onTap});

  final int unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        backgroundColor: AppTheme.danger,
        textColor: Colors.white,
        textStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.fontFamily,
        ),
        offset: const Offset(3, -3),
        child: const Icon(Icons.notifications_none_rounded, size: 24),
      ),
    );
  }
}

/// Icon used by notification cards, colour-coded by [NotificationType].
IconData notificationIcon(NotificationType type) => switch (type) {
  NotificationType.match => Icons.person_search_outlined,
  NotificationType.intro => Icons.handshake_outlined,
  NotificationType.wali => Icons.verified_user_outlined,
  NotificationType.chat => Icons.chat_bubble_outline_rounded,
  NotificationType.milestone => Icons.celebration_outlined,
  NotificationType.system => Icons.info_outline_rounded,
};

Color notificationColor(NotificationType type) => switch (type) {
  NotificationType.match => AppTheme.infoBg,
  NotificationType.intro => AppTheme.successBg,
  NotificationType.wali => AppTheme.gold,
  NotificationType.chat => AppTheme.emerald,
  NotificationType.milestone => AppTheme.warningBg,
  NotificationType.system => AppTheme.slate100,
};

Color notificationForegroundColor(NotificationType type) => switch (type) {
  NotificationType.match => AppTheme.info,
  NotificationType.intro => AppTheme.success,
  NotificationType.wali => AppTheme.goldDeep,
  NotificationType.chat => Colors.white,
  NotificationType.milestone => AppTheme.warning,
  NotificationType.system => AppTheme.slate700,
};
