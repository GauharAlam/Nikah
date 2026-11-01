import '../models/verification_doc.dart';
import '../models/ward_profile.dart';

class ProfileStrength {
  const ProfileStrength(this.percent, this.nextTip);
  final int percent;

  /// The most useful next step, or null when complete.
  final String? nextTip;
}

/// Scores how complete a profile is. Advice only; it affects nothing else.
ProfileStrength profileStrength(WardProfile p, List<VerificationDoc> docs) {
  bool submitted(String id) => docs.any((VerificationDoc d) =>
      d.id == id &&
      (d.status == VerificationDocStatus.pending ||
          d.status == VerificationDocStatus.approved));

  final List<(bool, int, String)> checks = <(bool, int, String)>[
    (p.displayName.isNotEmpty, 15, 'Add your basic details'),
    (p.photos.isNotEmpty, 20, 'Add a clear photo'),
    (submitted('name-proof'), 15, 'Upload your ID'),
    (submitted('education-proof'), 15, 'Upload your education proof'),
    (p.aboutMe.trim().length >= 30, 15, 'Write a few lines about yourself'),
    (p.photos.length >= 3, 10, 'Add at least 3 photos'),
    (p.extraPractices.isNotEmpty || p.halalLifestyle.isNotEmpty, 5, 'Add your deen and values'),
    (p.sect.isNotEmpty, 5, 'Add your sect'),
  ];
  int percent = 0;
  String? tip;
  for (final (bool done, int weight, String advice) in checks) {
    if (done) {
      percent += weight;
    } else {
      tip ??= advice;
    }
  }
  return ProfileStrength(percent, tip);
}
