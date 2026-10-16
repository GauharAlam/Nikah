import 'dart:convert';

enum VerificationDocStatus { missing, pending, approved }

extension VerificationDocStatusX on VerificationDocStatus {
  String get label => switch (this) {
    VerificationDocStatus.missing => 'Not started',
    VerificationDocStatus.pending => 'Under review',
    VerificationDocStatus.approved => 'Approved',
  };

  String get detail => switch (this) {
    VerificationDocStatus.missing => 'Tap to upload this document.',
    VerificationDocStatus.pending => 'Our team is reviewing your upload.',
    VerificationDocStatus.approved => 'Verified by the Barkat team.',
  };
}

/// A single document in the Barkat Verified badge flow (name proof,
/// education proof, photo proof…).
class VerificationDoc {
  final String id;
  final String title;
  final String subtitle;
  final VerificationDocStatus status;
  final bool isRequired;

  const VerificationDoc({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    this.isRequired = true,
  });

  VerificationDoc copyWith({VerificationDocStatus? status}) => VerificationDoc(
        id: id,
        title: title,
        subtitle: subtitle,
        status: status ?? this.status,
        isRequired: isRequired,
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
      subtitle: 'Payslip or ITR — strengthens your trust score',
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
