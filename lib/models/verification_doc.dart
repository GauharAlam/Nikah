import 'dart:convert';

enum VerificationDocStatus {
  missing,
  pending,
  underReview,
  approved,
  rejected,
  resubmissionRequired;

  static VerificationDocStatus fromWire(Object? value) => switch (value) {
        'pending' => pending,
        'under_review' => underReview,
        'approved' => approved,
        'rejected' => rejected,
        'resubmission_required' => resubmissionRequired,
        _ => missing,
      };

  bool get needsUpload => this == missing || this == rejected || this == resubmissionRequired;
  bool get isWaiting => this == pending || this == underReview;
}

extension VerificationDocStatusX on VerificationDocStatus {
  String get label => switch (this) {
    VerificationDocStatus.missing => 'Not started',
    VerificationDocStatus.pending => 'Waiting for review',
    VerificationDocStatus.underReview => 'Under review',
    VerificationDocStatus.approved => 'Approved',
    VerificationDocStatus.rejected => 'Not accepted',
    VerificationDocStatus.resubmissionRequired => 'New upload needed',
  };

  String get detail => switch (this) {
    VerificationDocStatus.missing => 'Tap to upload this document.',
    VerificationDocStatus.pending => 'Your upload is in the queue.',
    VerificationDocStatus.underReview => 'Our team is reviewing your upload.',
    VerificationDocStatus.approved => 'We reviewed this document.',
    VerificationDocStatus.rejected => 'Tap to upload a different document.',
    VerificationDocStatus.resubmissionRequired => 'Tap to upload it again.',
  };
}

/// A single document in the verified badge flow (name proof,
/// education proof, photo proof…).
class VerificationDoc {
  final String id;
  final String title;
  final String subtitle;
  final VerificationDocStatus status;
  final bool isRequired;
  final String rejectionReason;

  const VerificationDoc({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    this.isRequired = true,
    this.rejectionReason = '',
  });

  VerificationDoc copyWith({
    VerificationDocStatus? status,
    String? rejectionReason,
  }) =>
      VerificationDoc(
        id: id,
        title: title,
        subtitle: subtitle,
        status: status ?? this.status,
        isRequired: isRequired,
        rejectionReason: rejectionReason ?? this.rejectionReason,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'status': status.name,
        'isRequired': isRequired,
      };

  factory VerificationDoc.fromJson(Map<String, dynamic> json) =>
      VerificationDoc(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        status: VerificationDocStatus.values
                .asNameMap()[json['status']] ??
            VerificationDocStatus.missing,
        isRequired: json['isRequired'] as bool? ?? true,
      );

  /// What a real member starts with, before anything is uploaded.
  static const List<VerificationDoc> blank = <VerificationDoc>[
    VerificationDoc(
      id: 'name-proof',
      title: 'Name proof',
      subtitle: 'Aadhaar, passport or driving licence',
      status: VerificationDocStatus.missing,
    ),
    VerificationDoc(
      id: 'education-proof',
      title: 'Education proof',
      subtitle: 'Degree certificate, mark sheet or university ID',
      status: VerificationDocStatus.missing,
    ),
    VerificationDoc(
      id: 'employment-proof',
      title: 'Employment proof (optional)',
      subtitle: 'Employment letter or business proof',
      status: VerificationDocStatus.missing,
      isRequired: false,
    ),
  ];

  static const List<VerificationDoc> seeds = <VerificationDoc>[
    VerificationDoc(
      id: 'name-proof',
      title: 'Name proof',
      subtitle: 'Passport / Aadhaar / National ID matching your profile name',
      status: VerificationDocStatus.approved,
    ),
    VerificationDoc(
      id: 'education-proof',
      title: 'Education proof',
      subtitle: 'Highest degree certificate or marksheet',
      status: VerificationDocStatus.pending,
    ),
    VerificationDoc(
      id: 'photo-proof',
      title: 'Photo proof',
      subtitle: 'A second selfie to confirm your profile photos',
      status: VerificationDocStatus.missing,
    ),
    VerificationDoc(
      id: 'income-proof',
      title: 'Income proof (optional)',
      subtitle: 'Payslip or ITR',
      status: VerificationDocStatus.missing,
      isRequired: false,
    ),
  ];

  static String encodeList(List<VerificationDoc> list) =>
      jsonEncode(list.map((d) => d.toJson()).toList());

  static List<VerificationDoc> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return List<VerificationDoc>.from(seeds);
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) return List<VerificationDoc>.from(seeds);
      return decoded
          .cast<Map<String, dynamic>>()
          .map(VerificationDoc.fromJson)
          .toList();
    } catch (_) {
      return List<VerificationDoc>.from(seeds);
    }
  }
}
