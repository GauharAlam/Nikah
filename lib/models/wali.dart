import 'dart:convert';

enum GuardianRelation { father, brotherUncle, imam, other }

extension GuardianRelationX on GuardianRelation {
  String get label => switch (this) {
    GuardianRelation.father => 'Father',
    GuardianRelation.brotherUncle => 'Brother / Uncle',
    GuardianRelation.imam => 'Imam / Masjid Scholar',
    GuardianRelation.other => 'Other Guardian',
  };

  String get description => switch (this) {
    GuardianRelation.father => 'The primary Mahram appointed by Qur\'an 4:34.',
    GuardianRelation.brotherUncle =>
      'Next-in-line when no father is present or available.',
    GuardianRelation.imam =>
      'Trusted community scholar supervising if no family remains.',
    GuardianRelation.other => 'A guardian of trust approved by your Imam.',
  };
}

/// The appointed Wali supervising this account.
class Guardian {
  final String name;
  final GuardianRelation relation;
  final String phoneCode;
  final String phone;
  final String email;
  final bool isVerified;
  final bool allowIntroApprovals;
  final bool allowChatAudit;
  final bool allowMeetingApproval;

  const Guardian({
    required this.name,
    required this.relation,
    required this.phoneCode,
    required this.phone,
    required this.email,
    this.isVerified = false,
    this.allowIntroApprovals = true,
    this.allowChatAudit = true,
    this.allowMeetingApproval = true,
  });

  Guardian copyWith({
    String? name,
    GuardianRelation? relation,
    String? phoneCode,
    String? phone,
    String? email,
    bool? isVerified,
    bool? allowIntroApprovals,
    bool? allowChatAudit,
    bool? allowMeetingApproval,
  }) {
    return Guardian(
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phoneCode: phoneCode ?? this.phoneCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      allowIntroApprovals: allowIntroApprovals ?? this.allowIntroApprovals,
      allowChatAudit: allowChatAudit ?? this.allowChatAudit,
      allowMeetingApproval:
          allowMeetingApproval ?? this.allowMeetingApproval,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'relation': relation.name,
    'phoneCode': phoneCode,
    'phone': phone,
    'email': email,
    'isVerified': isVerified,
    'allowIntroApprovals': allowIntroApprovals,
    'allowChatAudit': allowChatAudit,
    'allowMeetingApproval': allowMeetingApproval,
  };

  static Guardian fromJson(Map<String, dynamic> json) => Guardian(
    name: json['name'] as String? ?? '',
    relation:
        GuardianRelation.values.asNameMap()[json['relation']] ??
        GuardianRelation.father,
    phoneCode: json['phoneCode'] as String? ?? '+44',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    isVerified: json['isVerified'] as bool? ?? false,
    allowIntroApprovals: json['allowIntroApprovals'] as bool? ?? true,
    allowChatAudit: json['allowChatAudit'] as bool? ?? true,
    allowMeetingApproval: json['allowMeetingApproval'] as bool? ?? true,
  );

  static String encode(Guardian g) => jsonEncode(g.toJson());

  static Guardian? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return Guardian.fromJson(decoded);
  }

  /// Guardian shown in mock guardian-side screens.
  static const Guardian seed = Guardian(
    name: 'Khalid Al-Mansoor',
    relation: GuardianRelation.father,
    phoneCode: '+44',
    phone: '7700 900188',
    email: 'khalid.almansoor@example.com',
    isVerified: true,
  );
}

enum ActivityKind { intro, chat, meeting, verification, general }

/// A single row in the guardian audit log.
class ActivityLogEntry {
  final String id;
  final ActivityKind kind;
  final String title;
  final String detail;
  final DateTime createdAt;

  const ActivityLogEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'detail': detail,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static ActivityLogEntry fromJson(Map<String, dynamic> json) =>
      ActivityLogEntry(
        id: json['id'] as String,
        kind:
            ActivityKind.values.asNameMap()[json['kind']] ??
            ActivityKind.general,
        title: json['title'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt'] as int? ?? 0,
        ),
      );

  static String encodeList(List<ActivityLogEntry> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ActivityLogEntry> decodeList(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .cast<Map<String, dynamic>>()
        .map(ActivityLogEntry.fromJson)
        .toList();
  }
}
