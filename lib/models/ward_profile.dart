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

  String get title => switch (this) {
    Gender.male => 'Male',
    Gender.female => 'Female',
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
  final String managedBy;
  final bool hasGender;
  final String maritalStatus;
  final String marriageReadiness;
  final String homeState;
  final String workCity;
  final bool workSameAsHome;
  final String caste;
  final String partnerCaste;
  final String height;
  final List<String> almaMaters;
  final String qualification;
  final String incomeRange;
  final String company;
  final List<String> photos;
  final int onboardingStep;
  final String sect;
  final String children;
  final String photoPrivacy;
  final bool showCaste;
  final bool allowFamilyShare;
  final bool intentConfirmed;
  final bool dataConsent;
  final bool candidateConsent;
  final String inviteCode;
  final String preferredLanguage;
  final String familyType;
  final String familyBackground;
  final String familyValues;
  final String familyLocation;
  final String siblings;
  final String graduationYear;
  final String educationStatus;
  final String employmentStatus;
  final String careerDescription;

  const WardProfile({
    this.displayName = '',
    this.gender = Gender.female,
    this.dateOfBirth,
    this.phoneCode = '+91',
    this.phone = '',
    this.email = '',
    this.city = '',
    this.country = '',
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
    this.managedBy = 'self',
    this.hasGender = false,
    this.maritalStatus = '',
    this.marriageReadiness = '',
    this.homeState = '',
    this.workCity = '',
    this.workSameAsHome = true,
    this.caste = '',
    this.partnerCaste = '',
    this.height = '',
    this.almaMaters = const <String>[],
    this.qualification = '',
    this.incomeRange = '',
    this.company = '',
    this.photos = const <String>[],
    this.onboardingStep = 1,
    this.sect = '',
    this.children = '',
    this.photoPrivacy = 'everyone',
    this.showCaste = true,
    this.allowFamilyShare = true,
    this.intentConfirmed = false,
    this.dataConsent = false,
    this.candidateConsent = false,
    this.inviteCode = '',
    this.preferredLanguage = '',
    this.familyType = '',
    this.familyBackground = '',
    this.familyValues = '',
    this.familyLocation = '',
    this.siblings = '',
    this.graduationYear = '',
    this.educationStatus = '',
    this.employmentStatus = '',
    this.careerDescription = '',
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
    String? managedBy,
    bool? hasGender,
    String? maritalStatus,
    String? marriageReadiness,
    String? homeState,
    String? workCity,
    bool? workSameAsHome,
    String? caste,
    String? partnerCaste,
    String? height,
    List<String>? almaMaters,
    String? qualification,
    String? incomeRange,
    String? company,
    List<String>? photos,
    int? onboardingStep,
    String? sect,
    String? children,
    String? photoPrivacy,
    bool? showCaste,
    bool? allowFamilyShare,
    bool? intentConfirmed,
    bool? dataConsent,
    bool? candidateConsent,
    String? inviteCode,
    String? preferredLanguage,
    String? familyType,
    String? familyBackground,
    String? familyValues,
    String? familyLocation,
    String? siblings,
    String? graduationYear,
    String? educationStatus,
    String? employmentStatus,
    String? careerDescription,
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
      managedBy: managedBy ?? this.managedBy,
      hasGender: hasGender ?? this.hasGender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      marriageReadiness: marriageReadiness ?? this.marriageReadiness,
      homeState: homeState ?? this.homeState,
      workCity: workCity ?? this.workCity,
      workSameAsHome: workSameAsHome ?? this.workSameAsHome,
      caste: caste ?? this.caste,
      partnerCaste: partnerCaste ?? this.partnerCaste,
      height: height ?? this.height,
      almaMaters: almaMaters ?? this.almaMaters,
      qualification: qualification ?? this.qualification,
      incomeRange: incomeRange ?? this.incomeRange,
      company: company ?? this.company,
      photos: photos ?? this.photos,
      onboardingStep: onboardingStep ?? this.onboardingStep,
      sect: sect ?? this.sect,
      children: children ?? this.children,
      photoPrivacy: photoPrivacy ?? this.photoPrivacy,
      showCaste: showCaste ?? this.showCaste,
      allowFamilyShare: allowFamilyShare ?? this.allowFamilyShare,
      intentConfirmed: intentConfirmed ?? this.intentConfirmed,
      dataConsent: dataConsent ?? this.dataConsent,
      candidateConsent: candidateConsent ?? this.candidateConsent,
      inviteCode: inviteCode ?? this.inviteCode,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      familyType: familyType ?? this.familyType,
      familyBackground: familyBackground ?? this.familyBackground,
      familyValues: familyValues ?? this.familyValues,
      familyLocation: familyLocation ?? this.familyLocation,
      siblings: siblings ?? this.siblings,
      graduationYear: graduationYear ?? this.graduationYear,
      educationStatus: educationStatus ?? this.educationStatus,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      careerDescription: careerDescription ?? this.careerDescription,
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
    'managedBy': managedBy,
    'hasGender': hasGender,
    'maritalStatus': maritalStatus,
    'marriageReadiness': marriageReadiness,
    'homeState': homeState,
    'workCity': workCity,
    'workSameAsHome': workSameAsHome,
    'caste': caste,
    'partnerCaste': partnerCaste,
    'height': height,
    'almaMaters': almaMaters,
    'qualification': qualification,
    'incomeRange': incomeRange,
    'company': company,
    'photos': photos,
    'onboardingStep': onboardingStep,
    'sect': sect,
    'children': children,
    'photoPrivacy': photoPrivacy,
    'showCaste': showCaste,
    'allowFamilyShare': allowFamilyShare,
    'intentConfirmed': intentConfirmed,
    'dataConsent': dataConsent,
    'candidateConsent': candidateConsent,
    'inviteCode': inviteCode,
    'preferredLanguage': preferredLanguage,
    'familyType': familyType,
    'familyBackground': familyBackground,
    'familyValues': familyValues,
    'familyLocation': familyLocation,
    'siblings': siblings,
    'graduationYear': graduationYear,
    'educationStatus': educationStatus,
    'employmentStatus': employmentStatus,
    'careerDescription': careerDescription,
  };

  static WardProfile fromJson(Map<String, dynamic> json) => WardProfile(
    displayName: json['displayName'] as String? ?? '',
    gender: Gender.values.asNameMap()[json['gender']] ?? Gender.female,
    dateOfBirth: json['dateOfBirth'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['dateOfBirth'] as int),
    phoneCode: json['phoneCode'] as String? ?? '+91',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    city: json['city'] as String? ?? '',
    country: json['country'] as String? ?? '',
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
    managedBy: json['managedBy'] as String? ?? 'self',
    hasGender: json['hasGender'] as bool? ?? false,
    maritalStatus: json['maritalStatus'] as String? ?? '',
    marriageReadiness: json['marriageReadiness'] as String? ?? '',
    homeState: json['homeState'] as String? ?? '',
    workCity: json['workCity'] as String? ?? '',
    workSameAsHome: json['workSameAsHome'] as bool? ?? true,
    caste: json['caste'] as String? ?? '',
    partnerCaste: json['partnerCaste'] as String? ?? '',
    height: json['height'] as String? ?? '',
    almaMaters: (json['almaMaters'] as List?)?.cast<String>() ?? const <String>[],
    qualification: json['qualification'] as String? ?? '',
    incomeRange: json['incomeRange'] as String? ?? '',
    company: json['company'] as String? ?? '',
    photos: (json['photos'] as List?)?.cast<String>() ?? const <String>[],
    onboardingStep: json['onboardingStep'] as int? ?? 1,
    sect: json['sect'] as String? ?? '',
    children: json['children'] as String? ?? '',
    photoPrivacy: json['photoPrivacy'] as String? ?? 'everyone',
    showCaste: json['showCaste'] as bool? ?? true,
    allowFamilyShare: json['allowFamilyShare'] as bool? ?? true,
    intentConfirmed: json['intentConfirmed'] as bool? ?? false,
    dataConsent: json['dataConsent'] as bool? ?? false,
    candidateConsent: json['candidateConsent'] as bool? ?? false,
    inviteCode: json['inviteCode'] as String? ?? '',
    preferredLanguage: json['preferredLanguage'] as String? ?? '',
    familyType: json['familyType'] as String? ?? '',
    familyBackground: json['familyBackground'] as String? ?? '',
    familyValues: json['familyValues'] as String? ?? '',
    familyLocation: json['familyLocation'] as String? ?? '',
    siblings: json['siblings'] as String? ?? '',
    graduationYear: json['graduationYear'] as String? ?? '',
    educationStatus: json['educationStatus'] as String? ?? '',
    employmentStatus: json['employmentStatus'] as String? ?? '',
    careerDescription: json['careerDescription'] as String? ?? '',
  );

  /// Full E.164 number, or empty when unset.
  String get e164Phone {
    final String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? '' : '$phoneCode$digits';
  }

  /// The fields stored in `drafts/{uid}`. Must stay in step with `Draft` in
  /// `functions/src/rules.ts`.
  Map<String, dynamic> toDraft({required bool? qualificationGraduate}) =>
      <String, dynamic>{
        'managedBy': managedBy,
        'fullName': displayName,
        if (hasGender) 'gender': gender.name,
        'maritalStatus': maritalStatus,
        'marriageReadiness': marriageReadiness,
        'homeCity': city,
        'homeState': homeState,
        'homeCountry': country,
        'workCity': workSameAsHome ? city : workCity,
        'workSameAsHome': workSameAsHome,
        'dateOfBirth': dateOfBirth?.millisecondsSinceEpoch,
        'caste': caste,
        'partnerCaste': partnerCaste,
        'height': height,
        'phoneCode': phoneCode,
        'phoneNumber': phone,
        'phone': e164Phone,
        'almaMaters': almaMaters,
        'qualification': qualification,
        'qualificationGraduate': ?qualificationGraduate,
        'profession': profession,
        'incomeRange': incomeRange,
        'company': company,
        'photos': photos,
        'aboutMe': aboutMe,
        'step': onboardingStep,
        'stepVersion': 2,
        'sect': sect,
        'children': children,
        'photoPrivacy': photoPrivacy,
        'showCaste': showCaste,
        'allowFamilyShare': allowFamilyShare,
        'intentConfirmed': intentConfirmed,
        'dataConsent': dataConsent,
        'candidateConsent': candidateConsent,
        'inviteCode': inviteCode,
        'preferredLanguage': preferredLanguage,
        'familyType': familyType,
        'familyBackground': familyBackground,
        'familyValues': familyValues,
        'familyLocation': familyLocation,
        'siblings': siblings,
        'graduationYear': graduationYear,
        'educationStatus': educationStatus,
        'employmentStatus': employmentStatus,
        'careerDescription': careerDescription,
        'prayer': prayerFrequency.label,
        'prayerFrequency': prayerFrequency.name,
        'quranComfort': quranComfort.name,
        'practices': <String>[...extraPractices, ...halalLifestyle],
        'extraPractices': extraPractices,
        'halalLifestyle': halalLifestyle,
      };

  /// Drafts saved under the old seven-step flow resume at the matching step.
  static int migrateStep(int? step, int? version) {
    if (step == null) return 1;
    if (version == 2) return step;
    return switch (step) {
      <= 4 => 1,
      5 => 3,
      6 => 4,
      _ => 5,
    };
  }

  static WardProfile fromDraft(Map<String, dynamic> d) => WardProfile(
        managedBy: d['managedBy'] as String? ?? 'self',
        displayName: d['fullName'] as String? ?? '',
        hasGender: d['gender'] != null,
        gender: Gender.values.asNameMap()[d['gender']] ?? Gender.female,
        maritalStatus: d['maritalStatus'] as String? ?? '',
        marriageReadiness: d['marriageReadiness'] as String? ?? '',
        city: d['homeCity'] as String? ?? '',
        homeState: d['homeState'] as String? ?? '',
        country: d['homeCountry'] as String? ?? '',
        workCity: d['workCity'] as String? ?? '',
        workSameAsHome: d['workSameAsHome'] as bool? ?? true,
        dateOfBirth: d['dateOfBirth'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(d['dateOfBirth'] as int),
        caste: d['caste'] as String? ?? '',
        partnerCaste: d['partnerCaste'] as String? ?? '',
        height: d['height'] as String? ?? '',
        phoneCode: d['phoneCode'] as String? ?? '+91',
        phone: d['phoneNumber'] as String? ?? '',
        almaMaters: (d['almaMaters'] as List?)?.cast<String>() ?? const <String>[],
        qualification: d['qualification'] as String? ?? '',
        profession: d['profession'] as String? ?? '',
        incomeRange: d['incomeRange'] as String? ?? '',
        company: d['company'] as String? ?? '',
        photos: (d['photos'] as List?)?.cast<String>() ?? const <String>[],
        aboutMe: d['aboutMe'] as String? ?? '',
        onboardingStep: migrateStep(d['step'] as int?, d['stepVersion'] as int?),
        sect: d['sect'] as String? ?? '',
        children: d['children'] as String? ?? '',
        photoPrivacy: d['photoPrivacy'] as String? ?? 'everyone',
        showCaste: d['showCaste'] as bool? ?? true,
        allowFamilyShare: d['allowFamilyShare'] as bool? ?? true,
        intentConfirmed: d['intentConfirmed'] as bool? ?? false,
        dataConsent: d['dataConsent'] as bool? ?? false,
        candidateConsent: d['candidateConsent'] as bool? ?? false,
        inviteCode: d['inviteCode'] as String? ?? '',
        preferredLanguage: d['preferredLanguage'] as String? ?? '',
        familyType: d['familyType'] as String? ?? '',
        familyBackground: d['familyBackground'] as String? ?? '',
        familyValues: d['familyValues'] as String? ?? '',
        familyLocation: d['familyLocation'] as String? ?? '',
        siblings: d['siblings'] as String? ?? '',
        graduationYear: d['graduationYear'] as String? ?? '',
        educationStatus: d['educationStatus'] as String? ?? '',
        employmentStatus: d['employmentStatus'] as String? ?? '',
        careerDescription: d['careerDescription'] as String? ?? '',
        prayerFrequency: PrayerFrequency.values.asNameMap()[d['prayerFrequency']] ??
            PrayerFrequency.always,
        quranComfort: QuranComfort.values.asNameMap()[d['quranComfort']] ??
            QuranComfort.intermediate,
        extraPractices: (d['extraPractices'] as List?)?.cast<String>() ?? const <String>[],
        halalLifestyle: (d['halalLifestyle'] as List?)?.cast<String>() ?? const <String>[],
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
