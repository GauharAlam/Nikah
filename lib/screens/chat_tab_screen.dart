/// Chats tab: chaperoned conversation list with live unread badges.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
import '../models/chat_message.dart';
import '../models/match_profile.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_banners.dart';
import '../widgets/app_card.dart';
import '../widgets/app_images.dart';
import '../widgets/empty_state.dart';

/// Bottom-nav "Chats" tab. Every conversation shown here is approved by
/// both Wali and monitored under platform policy.
class ChatTabScreen extends StatelessWidget {
  const ChatTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStore store = context.watch<AppStore>();
    final List<String> threadIds = store.chatThreadIds;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text('Chaperoned Conversations'),
        actions: <Widget>[
          NotificationBell(
            unread: store.unreadNotificationCount,
            onTap: () => context.push(AppRoutes.notifications),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: threadIds.isEmpty
          ? const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              body:
                  'When a Ta\'aruf is approved by both Wali, your '
                  'chaperoned conversations will appear here.',
            )
          : Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: const InfoBanner(
                    icon: Icons.shield_outlined,
                    text:
                        'All conversations remain chaperoned between both '
                        'Wali.',
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    itemCount: threadIds.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String id = threadIds[index];
                      final MatchProfile match = MatchProfile.byId(id);
                      final List<ChatMessage> thread = store.messages(id);
                      final ChatMessage? last = thread.isEmpty
                          ? null
                          : thread.last;

                      return _ConversationRow(
                        key: Key('chat_row_$id'),
                        match: match,
                        preview: store.lastMessagePreview(id),
                        time: last?.time ?? '',
                        unread: store.unreadCount(id),
                        openThread: () => context.push(AppRoutes.chat(id)),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// One conversation card row used inside the thread list.
class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    super.key,
    required this.match,
    required this.preview,
    required this.time,
    required this.unread,
    required this.openThread,
  });

  final MatchProfile match;
  final String preview;
  final String time;
  final int unread;
  final VoidCallback openThread;

  @override
  Widget build(BuildContext context) {
    final String initials = match.firstName.isEmpty
        ? '?'
        : match.firstName.substring(0, 1).toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: openThread,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: <Widget>[
            AppAvatar(url: match.imageUrl, radius: 24, initials: initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          match.firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.ts(
                            14.5,
                            FontWeight.w800,
                            color: AppTheme.slate900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppTheme.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.ts(
                      12.5,
                      FontWeight.w500,
                      color: AppTheme.slate500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  time,
                  style: AppTheme.ts(
                    10.5,
                    FontWeight.w600,
                    color: AppTheme.slate400,
                  ),
                ),
                const SizedBox(height: 6),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unread',
                      style: AppTheme.ts(
                        10,
                        FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppTheme.slate400,
                  ),
              ],
            ),
            if (match.isWaliVerified) ...<Widget>[
              const SizedBox(width: 8),
              const Icon(
                Icons.verified_rounded,
                size: 16,
                color: AppTheme.success,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
