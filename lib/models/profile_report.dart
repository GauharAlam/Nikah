import 'dart:convert';

/// A report filed against another profile.
class ProfileReport {
  final String profileId;
  final String reason;
  final DateTime createdAt;

  const ProfileReport({
    required this.profileId,
    required this.reason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'profileId': profileId,
        'reason': reason,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ProfileReport.fromJson(Map<String, dynamic> json) => ProfileReport(
        profileId: json['profileId'] as String,
        reason: json['reason'] as String,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );

  static String encodeList(List<ProfileReport> list) =>
      jsonEncode(list.map((ProfileReport r) => r.toJson()).toList());

  static List<ProfileReport> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return <ProfileReport>[];
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return <ProfileReport>[];
      return decoded
          .cast<Map<String, dynamic>>()
          .map(ProfileReport.fromJson)
          .toList();
    } catch (_) {
      return <ProfileReport>[];
    }
  }
}
