import 'dart:convert';

import 'match_profile.dart';

enum MeetingFormat { video, audio, inPerson }

extension MeetingFormatX on MeetingFormat {
  String get label => switch (this) {
    MeetingFormat.video => 'Virtual Video Call',
    MeetingFormat.audio => 'Voice / Audio Call',
    MeetingFormat.inPerson => 'Chaperoned Meet-Up',
  };

  String get detail => switch (this) {
    MeetingFormat.video =>
      'Camera-on family bridge, supervised by both Wali whenever possible.',
    MeetingFormat.audio =>
      'Discreet voice conversation — photo views stay optional.',
    MeetingFormat.inPerson =>
      'Family area cafe or masjid lounge with Wali on site.',
  };

  String get iconKey => switch (this) {
    MeetingFormat.video => 'video_camera_front_outlined',
    MeetingFormat.audio => 'phone_in_talk_outlined',
    MeetingFormat.inPerson => 'mosque',
  };
}

enum MeetingStatus { requested, scheduled, completed, declined }

/// A scheduled chaperoned family call / meeting.
class MeetingRequest {
  final String id;
  final String matchId;
  final MeetingFormat format;
  final DateTime scheduledAt;
  final String location;
  final String notes;
  final MeetingStatus status;

  const MeetingRequest({
    required this.id,
    required this.matchId,
    required this.format,
    required this.scheduledAt,
    required this.location,
    this.notes = '',
    this.status = MeetingStatus.scheduled,
  });

  MatchProfile get match => MatchProfile.byId(matchId);

  Map<String, dynamic> toJson() => {
    'id': id,
    'matchId': matchId,
    'format': format.name,
    'scheduledAt': scheduledAt.millisecondsSinceEpoch,
    'location': location,
    'notes': notes,
    'status': status.name,
  };

  static MeetingRequest fromJson(Map<String, dynamic> json) =>
      MeetingRequest(
        id: json['id'] as String,
        matchId: json['matchId'] as String,
        format:
            MeetingFormat.values.asNameMap()[json['format']] ??
            MeetingFormat.video,
        scheduledAt: DateTime.fromMillisecondsSinceEpoch(
          json['scheduledAt'] as int? ?? 0,
        ),
        location: json['location'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        status:
            MeetingStatus.values.asNameMap()[json['status']] ??
            MeetingStatus.scheduled,
      );

  static String encodeList(List<MeetingRequest> list) =>
      jsonEncode(list.map((m) => m.toJson()).toList());

  static List<MeetingRequest> decodeList(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .cast<Map<String, dynamic>>()
        .map(MeetingRequest.fromJson)
        .toList();
  }
}
