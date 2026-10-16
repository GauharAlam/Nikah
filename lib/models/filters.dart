import 'match_profile.dart';

/// Discovery / search filters persisted by [AppStore].
///
/// Mirrors the Barkat filter sheet: age slider + single-select rows for
/// marriage status, caste, alma mater, education, profession and location,
/// plus the contact-sharing mode.
class MatchFilters {
  final int minAge;
  final int maxAge;
  final String marriageStatus;
  final String caste;
  final String almaMater;
  final String education;
  final String profession;
  final String location;
  final String contactSharing;

  /// Legacy fields kept while older screens migrate to the Barkat set.
  final List<String> cities;
  final bool waliVerifiedOnly;
  final List<String> practiceTags;
  final String nikahTimeline;

  static const String anyValue = 'No preference';
  static const String manualApproval = 'Manual approval';

  const MatchFilters({
    this.minAge = 21,
    this.maxAge = 40,
    this.marriageStatus = anyValue,
    this.caste = anyValue,
    this.almaMater = anyValue,
    this.education = anyValue,
    this.profession = anyValue,
    this.location = anyValue,
    this.contactSharing = manualApproval,
    this.cities = const <String>[],
    this.waliVerifiedOnly = false,
    this.practiceTags = const <String>[],
    this.nikahTimeline = 'Any timeline',
  });

  bool get isDefault =>
      minAge == 21 &&
      maxAge == 40 &&
      marriageStatus == anyValue &&
      caste == anyValue &&
      almaMater == anyValue &&
      education == anyValue &&
      profession == anyValue &&
      location == anyValue &&
      contactSharing == manualApproval &&
      cities.isEmpty &&
      !waliVerifiedOnly &&
      practiceTags.isEmpty &&
      nikahTimeline == 'Any timeline';

  int get activeCount {
    var n = 0;
    if (minAge != 21 || maxAge != 40) n++;
    if (marriageStatus != anyValue) n++;
    if (caste != anyValue) n++;
    if (almaMater != anyValue) n++;
    if (education != anyValue) n++;
    if (profession != anyValue) n++;
    if (location != anyValue) n++;
    if (contactSharing != manualApproval) n++;
    if (cities.isNotEmpty) n++;
    if (waliVerifiedOnly) n++;
    if (practiceTags.isNotEmpty) n++;
    if (nikahTimeline != 'Any timeline') n++;
    return n;
  }

  MatchFilters copyWith({
    int? minAge,
    int? maxAge,
    String? marriageStatus,
    String? caste,
    String? almaMater,
    String? education,
    String? profession,
    String? location,
    String? contactSharing,
    List<String>? cities,
    bool? waliVerifiedOnly,
    List<String>? practiceTags,
    String? nikahTimeline,
  }) {
    return MatchFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      marriageStatus: marriageStatus ?? this.marriageStatus,
      caste: caste ?? this.caste,
      almaMater: almaMater ?? this.almaMater,
      education: education ?? this.education,
      profession: profession ?? this.profession,
      location: location ?? this.location,
      contactSharing: contactSharing ?? this.contactSharing,
      cities: cities ?? this.cities,
      waliVerifiedOnly: waliVerifiedOnly ?? this.waliVerifiedOnly,
      practiceTags: practiceTags ?? this.practiceTags,
      nikahTimeline: nikahTimeline ?? this.nikahTimeline,
    );
  }

  /// Whether a Barkat-style profile passes the active filters.
  bool acceptsProfile(MatchProfile p) {
    if (p.age < minAge || p.age > maxAge) return false;
    if (marriageStatus != anyValue && p.maritalStatus != marriageStatus) {
      return false;
    }
    if (caste != anyValue &&
        p.caste != caste &&
        p.caste != 'Beyond Caste') {
      return false;
    }
    if (almaMater != anyValue &&
        !p.university.toLowerCase().contains(almaMater.toLowerCase())) {
      return false;
    }
    if (education != anyValue &&
        p.degreeLevel != education &&
        !p.education.toLowerCase().contains(education.toLowerCase())) {
      return false;
    }
    if (profession != anyValue &&
        p.professionField != profession &&
        !p.profession.toLowerCase().contains(profession.toLowerCase())) {
      return false;
    }
    if (location != anyValue &&
        !p.location.toLowerCase().contains(location.toLowerCase())) {
      return false;
    }
    // Legacy fields still respected when set.
    if (cities.isNotEmpty &&
        !cities.any((c) => p.location.toLowerCase().contains(c.toLowerCase()))) {
      return false;
    }
    if (waliVerifiedOnly && !p.isWaliVerified) return false;
    if (practiceTags.isNotEmpty &&
        !practiceTags.any(p.faithTags.contains)) {
      return false;
    }
    return true;
  }

  bool accepts(
    int age,
    String location,
    bool isWaliVerified,
    List<String> tags,
  ) {
    if (age < minAge || age > maxAge) return false;
    if (cities.isNotEmpty) {
      final city = location.toLowerCase();
      final shown = cities.any((c) => city.contains(c.toLowerCase()));
      if (!shown) return false;
    }
    if (waliVerifiedOnly && !isWaliVerified) return false;
    if (practiceTags.isNotEmpty) {
      final hasAny = practiceTags.any(tags.contains);
      if (!hasAny) return false;
    }
    return true;
  }
}
