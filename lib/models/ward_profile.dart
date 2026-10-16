import 'dart:convert';

import 'wali.dart';

enum AccountFor { myself, daughterSister, sonBrother }

extension AccountForX on AccountFor {
  String get label => switch (this) {
    AccountFor.myself => 'Myself',
    AccountFor.daughterSister => 'Daughter / Sister',
    AccountFor.sonBrother => 'Son / Brother',
  };

  String get detail => switch (this) {
    AccountFor.myself => 'I am seeking a spouse for myself with my Wali\'s blessings.',
    AccountFor.daughterSister =>
      'I am supervising this search on behalf of my daughter or sister.',
    AccountFor.sonBrother =>
      'I am supervising this search on behalf of my son or brother.',
  };
}

enum Gender { male, female }

extension GenderX on Gender {
  String get label => switch (this) {
    Gender.male => 'Brother',
    Gender.female => 'Sister',
  };
}

enum PrayerFrequency { always, mostly, growing }

extension PrayerFrequencyX on PrayerFrequency {
  String get label => switch (this) {
    PrayerFrequency.always => 'Alhamdulillah, always',
    PrayerFrequency.mostly => 'Most days, striving better',
    PrayerFrequency.growing => 'Growing commitment',
  };

  String? get detail => switch (this) {
    PrayerFrequency.always => 'Five daily salah on time, jama\'ah when able',
    PrayerFrequency.mostly => 'Consistent effort with occasional lapses',
    PrayerFrequency.growing => 'Recently returning to regular worship',
  };
}

enum QuranComfort { fluentReciter, intermediate, beginner }

extension QuranComfortX on QuranComfort {
  String get label => switch (this) {
    QuranComfort.fluentReciter => 'Fluent reciter',
    QuranComfort.intermediate => 'Intermediate',
    QuranComfort.beginner => 'Beginner',
  };
}

/// The ward account — built through the 4-step onboarding and shown in
/// profile / edit screens.
class WardProfile {
  final String displayName;
  final Gender gender;
  final DateTime? dateOfBirth;
  final String phoneCode;
  final String phone;
  final String email;
  final String city;
  final String country;
  final String education;
  final String profession;
  final PrayerFrequency prayerFrequency;
  final List<String> extraPractices;
  final QuranComfort quranComfort;
  final List<String> halalLifestyle;
  final String timeline;
  final String relocation;
  final String aboutMe;
  final AccountFor mode;
  final Guardian? guardian;
  final bool waliVerified;
  final DateTime? updatedAt;

  const WardProfile({
    this.displayName = '',
    this.gender = Gender.female,
    this.dateOfBirth,
    this.phoneCode = '+44',
    this.phone = '',
    this.email = '',
    this.city = '',
    this.country = 'United Kingdom',
    this.education = '',
    this.profession = '',
    this.prayerFrequency = PrayerFrequency.always,
    this.extraPractices = const [],
    this.quranComfort = QuranComfort.intermediate,
    this.halalLifestyle = const [],
    this.timeline = 'Nikah: 6-12 mos',
    this.relocation = 'Open to discuss',
    this.aboutMe = '',
    this.mode = AccountFor.myself,
    this.guardian,
    this.waliVerified = false,
    this.updatedAt,
  });

  WardProfile copyWith({
    String? displayName,
    Gender? gender,
    DateTime? dateOfBirth,
    String? phoneCode,
    String? phone,
    String? email,
    String? city,
    String? country,
    String? education,
    String? profession,
    PrayerFrequency? prayerFrequency,
    List<String>? extraPractices,
    QuranComfort? quranComfort,
    List<String>? halalLifestyle,
    String? timeline,
    String? relocation,
    String? aboutMe,
    AccountFor? mode,
    Guardian? guardian,
    bool? waliVerified,
    DateTime? updatedAt,
  }) {
    return WardProfile(
      displayName: displayName ?? this.displayName,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phoneCode: phoneCode ?? this.phoneCode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
      country: country ?? this.country,
      education: education ?? this.education,
      profession: profession ?? this.profession,
      prayerFrequency: prayerFrequency ?? this.prayerFrequency,
      extraPractices: extraPractices ?? this.extraPractices,
      quranComfort: quranComfort ?? this.quranComfort,
      halalLifestyle: halalLifestyle ?? this.halalLifestyle,
      timeline: timeline ?? this.timeline,
      relocation: relocation ?? this.relocation,
      aboutMe: aboutMe ?? this.aboutMe,
      mode: mode ?? this.mode,
      guardian: guardian ?? this.guardian,
      waliVerified: waliVerified ?? this.waliVerified,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  Map<String, dynamic> toJson() => {
    'displayName': displayName,
    'gender': gender.name,
    'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
    'phoneCode': phoneCode,
    'phone': phone,
    'email': email,
    'city': city,
    'country': country,
    'education': education,
    'profession': profession,
    'prayerFrequency': prayerFrequency.name,
    'extraPractices': extraPractices,
    'quranComfort': quranComfort.name,
    'halalLifestyle': halalLifestyle,
    'timeline': timeline,
    'relocation': relocation,
    'aboutMe': aboutMe,
    'mode': mode.name,
    'guardian': guardian?.toJson(),
    'waliVerified': waliVerified,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };

  static WardProfile fromJson(Map<String, dynamic> json) => WardProfile(
    displayName: json['displayName'] as String? ?? '',
    gender: Gender.values.asNameMap()[json['gender']] ?? Gender.female,
    dateOfBirth: json['dateOfBirth'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['dateOfBirth'] as int),
    phoneCode: json['phoneCode'] as String? ?? '+44',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    city: json['city'] as String? ?? '',
    country: json['country'] as String? ?? 'United Kingdom',
    education: json['education'] as String? ?? '',
    profession: json['profession'] as String? ?? '',
    prayerFrequency:
        PrayerFrequency.values.asNameMap()[json['prayerFrequency']] ??
        PrayerFrequency.always,
    extraPractices:
        (json['extraPractices'] as List?)?.cast<String>() ?? const [],
    quranComfort: QuranComfort.values.asNameMap()[json['quranComfort']] ??
        QuranComfort.intermediate,
    halalLifestyle:
        (json['halalLifestyle'] as List?)?.cast<String>() ?? const [],
    timeline: json['timeline'] as String? ?? 'Nikah: 6-12 mos',
    relocation: json['relocation'] as String? ?? 'Open to discuss',
    aboutMe: json['aboutMe'] as String? ?? '',
    mode: AccountFor.values.asNameMap()[json['mode']] ?? AccountFor.myself,
    guardian: json['guardian'] == null
        ? null
        : Guardian.fromJson((json['guardian'] as Map).cast<String, dynamic>()),
    waliVerified: json['waliVerified'] as bool? ?? false,
    updatedAt: json['updatedAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
  );

  static String encode(WardProfile p) => jsonEncode(p.toJson());

  static WardProfile? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return WardProfile.fromJson(decoded);
  }

  /// Fake ward persona used across guardian-side demo screens.
  static const WardProfile demoWard = WardProfile(
    displayName: 'Amina Al-Mansoor',
    gender: Gender.female,
    phoneCode: '+44',
    phone: '7700 900189',
    email: 'amina@example.com',
    city: 'London',
    education: 'Pharmacy — King\'s College',
    profession: 'Community Pharmacist',
    mode: AccountFor.myself,
    guardian: Guardian.seed,
    waliVerified: true,
  );
}
