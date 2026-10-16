import 'dart:convert';

enum NotificationType { match, intro, wali, chat, milestone, system }

/// In-app notification card for the /notifications screen.
class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? deepLink;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.deepLink,
  });

  NotificationItem markRead() =>
      NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: true,
        deepLink: deepLink,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'isRead': isRead,
    'deepLink': deepLink,
  };

  static NotificationItem fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String,
        type:
            NotificationType.values.asNameMap()[json['type']] ??
            NotificationType.system,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int? ?? 0,
        ),
        isRead: json['isRead'] as bool? ?? false,
        deepLink: json['deepLink'] as String?,
      );

  static String encodeList(List<NotificationItem> list) =>
      jsonEncode(list.map((n) => n.toJson()).toList());

  static List<NotificationItem> decodeList(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .cast<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList();
  }
}
