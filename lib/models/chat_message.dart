import 'dart:convert';

enum MessageSender { user, match, system, chaperone }

class ChatMessage {
  final String id;
  final String text;
  final String time;
  final DateTime createdAt;
  final MessageSender sender;
  final String? senderName;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.time,
    required this.createdAt,
    required this.sender,
    this.senderName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'time': time,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'sender': sender.name,
    'senderName': senderName,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    text: json['text'] as String,
    time: json['time'] as String? ?? 'Just now',
    createdAt:
        DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
    sender: MessageSender.values.asNameMap()[json['sender']] ??
        MessageSender.system,
    senderName: json['senderName'] as String?,
  );

  static String encodeList(List<ChatMessage> list) =>
      jsonEncode(list.map((m) => m.toJson()).toList());

  static List<ChatMessage> decodeList(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .cast<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }
}
