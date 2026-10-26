import 'dart:convert';

/// A suitor / spouse candidate profile shown across discovery, matches,
/// chat and the full biodata sheet.
class MatchProfile {
  final String id;
  final String name;
  final int age;
  final String profession;
  final String location;
  final String imageUrl;
  final bool isWaliVerified;
  final List<String> faithTags;
  final String marriageQuote;
  final String sect;
  final String height;
  final String education;
  final String relocation;
  final List<String> religiousPractices;
  final String waliName;
  final String waliRelation;

  // Biodata sheet extras.
  final String aboutMe;
  final String maritalStatus;
  final String nationality;
  final String languages;
  final List<String> hobbies;

  // Barkat-style card extras.
  final String university;
  final String employer;
  final String caste;
  final int matchPercent;
  final bool isSelfManaged;
  final bool isNew;
  final String marriageReadiness;
  final int replyRate;
  final String degreeLevel;
  final String professionField;

  const MatchProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.profession,
    required this.location,
    required this.imageUrl,
    required this.isWaliVerified,
    required this.faithTags,
    required this.marriageQuote,
    required this.sect,
    required this.height,
    required this.education,
    required this.relocation,
    required this.religiousPractices,
    required this.waliName,
    required this.waliRelation,
    this.aboutMe = '',
    this.maritalStatus = 'Never married',
    this.nationality = 'United Kingdom',
    this.languages = 'English, Arabic',
    this.hobbies = const [],
    this.university = '',
    this.employer = '',
    this.caste = 'Beyond Caste',
    this.matchPercent = 80,
    this.isSelfManaged = true,
    this.isNew = false,
    this.marriageReadiness = 'Ready within 1 year',
    this.replyRate = 95,
    this.degreeLevel = '',
    this.professionField = '',
  });

  String get firstName => name.split(' ').first;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'profession': profession,
    'location': location,
    'imageUrl': imageUrl,
    'isWaliVerified': isWaliVerified,
    'faithTags': faithTags,
    'marriageQuote': marriageQuote,
    'sect': sect,
    'height': height,
    'education': education,
    'relocation': relocation,
    'religiousPractices': religiousPractices,
    'waliName': waliName,
    'waliRelation': waliRelation,
    'aboutMe': aboutMe,
    'maritalStatus': maritalStatus,
    'nationality': nationality,
    'languages': languages,
    'hobbies': hobbies,
    'university': university,
    'employer': employer,
    'caste': caste,
    'matchPercent': matchPercent,
    'isSelfManaged': isSelfManaged,
    'isNew': isNew,
    'marriageReadiness': marriageReadiness,
    'replyRate': replyRate,
    'degreeLevel': degreeLevel,
    'professionField': professionField,
  };

  factory MatchProfile.fromJson(Map<String, dynamic> json) => MatchProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    age: json['age'] as int,
    profession: json['profession'] as String,
    location: json['location'] as String,
    imageUrl: json['imageUrl'] as String,
    isWaliVerified: json['isWaliVerified'] as bool? ?? false,
    faithTags: (json['faithTags'] as List?)?.cast<String>() ?? const [],
    marriageQuote: json['marriageQuote'] as String? ?? '',
    sect: json['sect'] as String? ?? '',
    height: json['height'] as String? ?? '',
    education: json['education'] as String? ?? '',
    relocation: json['relocation'] as String? ?? '',
    religiousPractices:
        (json['religiousPractices'] as List?)?.cast<String>() ?? const [],
    waliName: json['waliName'] as String? ?? '',
    waliRelation: json['waliRelation'] as String? ?? '',
    aboutMe: json['aboutMe'] as String? ?? '',
    maritalStatus: json['maritalStatus'] as String? ?? 'Never married',
    nationality: json['nationality'] as String? ?? 'United Kingdom',
    languages: json['languages'] as String? ?? 'English, Arabic',
    hobbies: (json['hobbies'] as List?)?.cast<String>() ?? const [],
    university: json['university'] as String? ?? '',
    employer: json['employer'] as String? ?? '',
    caste: json['caste'] as String? ?? 'Beyond Caste',
    matchPercent: json['matchPercent'] as int? ?? 80,
    isSelfManaged: json['isSelfManaged'] as bool? ?? true,
    isNew: json['isNew'] as bool? ?? false,
    marriageReadiness:
        json['marriageReadiness'] as String? ?? 'Ready within 1 year',
    replyRate: json['replyRate'] as int? ?? 95,
    degreeLevel: json['degreeLevel'] as String? ?? '',
    professionField: json['professionField'] as String? ?? '',
  );

  static String encodeList(List<MatchProfile> list) =>
      jsonEncode(list.map((p) => p.toJson()).toList());

  static List<MatchProfile> decodeList(String raw) {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .cast<Map<String, dynamic>>()
        .map(MatchProfile.fromJson)
        .toList();
  }

  // ─── Seed directory (mock backend) ────────────────────────────────────────

  static const MatchProfile zayd = MatchProfile(
    id: 'zayd-1',
    name: 'Zayd Al-Faruqi',
    age: 29,
    profession: 'Software Architect',
    location: 'London, UK',
    imageUrl: '', // no licensed demo photo — renders the placeholder
    isWaliVerified: true,
    faithTags: [
      'Prays 5x daily',
      'Strictly Halal',
      'Nikah: 6-12 mos',
      'Sunni / Practicing',
    ],
    marriageQuote:
        'Building a tranquil home grounded in mutual mercy (Rahmah), steady companionship, and values that inspire toward Jannah.',
    sect: 'Sunni / Hanafi',
    height: '5\'11" (180 cm)',
    education: 'M.Sc. Computer Science (Imperial)',
    relocation: 'Open to discuss within UK / Europe',
    religiousPractices: [
      'Salah: Always prays 5 daily prayers on time',
      'Diet: Strictly Halal & Zabiha only',
      'Quran: Daily recitation & weekly tafseer circle',
      'Finances: Strives for ethical, Riba-free home financing',
    ],
    waliName: 'Br. Tariq Al-Faruqi',
    waliRelation: 'Father',
    aboutMe:
        'Practising Londoner who loves weekend hiking, tafseer circles and building things that matter. Raised with strong family ties and a deep respect for the deen.',
    languages: 'English, Arabic, Urdu',
    hobbies: ['Hiking', 'Tafseer circles', 'Chess', 'Coding'],
    university: 'M.Sc. Computer Science • Imperial College London',
    employer: 'Software Architect, Revolut',
    caste: 'Beyond Caste',
    matchPercent: 91,
    isSelfManaged: false,
    marriageReadiness: 'Ready within 6 months',
    replyRate: 96,
    degreeLevel: 'Masters',
    professionField: 'Engineering',
  );

  static const MatchProfile farhan = MatchProfile(
    id: 'farhan-2',
    name: 'Farhan Siddiqui',
    age: 30,
    profession: 'Chartered Architect',
    location: 'Birmingham, UK',
    imageUrl: '', // no licensed demo photo — renders the placeholder
    isWaliVerified: true,
    faithTags: ['Prays 5x daily', 'Maliki', 'Nikah: 3-6 mos', 'Quran fluent'],
    marriageQuote:
        'Seeking a partnership where faith leads first — a household of sabr, shukr and shared ibadah.',
    sect: 'Sunni / Maliki',
    height: '6\'0" (183 cm)',
    education: 'MArch, Manchester School of Architecture',
    relocation: 'Ready to relocate within UK',
    religiousPractices: [
      'Salah: Consistent with sunnah rak\'ahs',
      'Diet: Halal, avoids restaurants without certification',
      'Quran: Completed hifz of Juz 30',
      'Masjid: Active in weekend school volunteering',
    ],
    waliName: 'Br. Abdul Basit Siddiqui',
    waliRelation: 'Father',
    aboutMe:
        'Architect who sketches masjids in his free time. Family-oriented, calm temperament, and serious about building a home upon the Quran and Sunnah.',
    languages: 'English, Urdu, Arabic',
    hobbies: ['Sketching', 'Cricket', 'Arabic calligraphy', 'Volunteering'],
    university: 'MArch, Manchester School of Architecture',
    employer: 'Chartered Architect, Foster + Partners',
    caste: 'Syed',
    matchPercent: 84,
    isSelfManaged: true,
    marriageReadiness: 'Ready within 1 year',
    replyRate: 92,
    degreeLevel: 'Masters',
    professionField: 'Architecture',
  );

  static const MatchProfile imran = MatchProfile(
    id: 'imran-3',
    name: 'Imran Haque',
    age: 27,
    profession: 'NHS Pharmacist',
    location: 'Manchester, UK',
    imageUrl: '', // no licensed demo photo — renders the placeholder
    isWaliVerified: true,
    faithTags: ['Prays 5x daily', 'Hanafi', 'Nikah: 12 mos', 'Hafiz'],
    marriageQuote:
        'A simple, deen-centred life: sincere intention, honest earnings and a spouse who reminds me of Allah.',
    sect: 'Sunni / Hanafi',
    height: '5\'9" (175 cm)',
    education: 'MPharm, University of Bath',
    relocation: 'Flexible across northern England',
    religiousPractices: [
      'Salah: Jumu\'ah sakoon + daily prayers at masjid when possible',
      'Diet: Halal only, learning sunnah nutrition',
      'Quran: Hafiz, leads taraweeh each Ramadan',
      'Charity: Monthly sadaqah standing order',
    ],
    waliName: 'Br. Yusuf Haque',
    waliRelation: 'Brother',
    aboutMe:
        'Hafiz al-Quran and a community khutbah helper. Career stable, health conscious, and looking for a partner to grow in iman together.',
    languages: 'English, Bengali, Arabic',
    hobbies: ['Qirat practice', 'Cycling', 'Cooking', 'Book club'],
    university: 'MPharm, University of Bath',
    employer: 'NHS Pharmacist, St Mary\'s Hospital',
    caste: 'Beyond Caste',
    matchPercent: 88,
    isSelfManaged: true,
    isNew: true,
    marriageReadiness: 'Ready within 1 year',
    replyRate: 89,
    degreeLevel: 'Masters',
    professionField: 'Healthcare',
  );

  static const MatchProfile bilal = MatchProfile(
    id: 'bilal-4',
    name: 'Bilal Osman',
    age: 32,
    profession: 'Secondary School Teacher',
    location: 'Leicester, UK',
    imageUrl: '', // no licensed demo photo — renders the placeholder
    isWaliVerified: false,
    faithTags: ['Prays 5x daily', 'Shafi\'i', 'Nikah: 6-12 mos', 'Deen mentor'],
    marriageQuote:
        'Raising children who love Allah is my dream — looking for a mother figure of values and steady kindness.',
    sect: 'Sunni / Shafi\'i',
    height: '6\'1" (185 cm)',
    education: 'BA Education, PGCE — Leicester',
    relocation: 'Willing to relocate to GCC',
    religiousPractices: [
      'Salah: Punctual, plus weekly halaqah attendance',
      'Diet: Halal, minimal processed food',
      'Quran: Daily morning adhkar & recitation',
      'Teaching: Sunday Islamic school instructor',
    ],
    waliName: 'Br. Mohammed Osman',
    waliRelation: 'Uncle',
    aboutMe:
        'A teacher of teenagers by day and youth-mentor on weekends. Patient, humorous, and rooted in Baloch family traditions.',
    languages: 'English, Somali, Arabic',
    hobbies: ['Mentoring', 'Football', 'Poetry', 'Dawah work'],
    university: 'BA Education, PGCE — University of Leicester',
    employer: 'Secondary School Teacher, Leicester Grammar',
    caste: 'Sheikh',
    matchPercent: 76,
    isSelfManaged: true,
    marriageReadiness: 'Ready after 1 year',
    replyRate: 94,
    degreeLevel: 'Bachelors',
    professionField: 'Education',
  );

  static const MatchProfile salman = MatchProfile(
    id: 'salman-5',
    name: 'Salman Radwan',
    age: 31,
    profession: 'Chartered Accountant',
    location: 'Dubai, UAE',
    imageUrl: '', // no licensed demo photo — renders the placeholder
    isWaliVerified: true,
    faithTags: ['Prays 5x daily', 'Hanafi', 'Nikah: 3-6 mos', 'Riba-free'],
    marriageQuote:
        'Comfort of a home begins with halal earnings and a spouse who is your quiet strength.',
    sect: 'Sunni / Hanafi',
    height: '5\'10" (178 cm)',
    education: 'BSc Accounting — Cairo, ACCA qualified',
    relocation: 'Open to UK / Canada',
    religiousPractices: [
      'Salah: Organisation jama\'ah + personal awrad',
      'Diet: Halal and practising moderation',
      'Quran: Weekly tafseer study with peers',
      'Finance: 100% halal investing, no riba',
    ],
    waliName: 'Br. Idris Radwan',
    waliRelation: 'Father',
    aboutMe:
        'Cairo-raised, Dubai-based finance professional. Balanced between holding a career and keeping the home a sanctuary.',
    languages: 'English, Arabic, French',
    hobbies: ['Swimming', 'Tafseer study', 'Travel', 'Photography'],
    university: 'BSc Accounting, ACCA — Cairo University',
    employer: 'Chartered Accountant, Deloitte',
    caste: 'Beyond Caste',
    matchPercent: 81,
    isSelfManaged: false,
    isNew: true,
    marriageReadiness: 'Ready within 6 months',
    replyRate: 97,
    degreeLevel: 'Bachelors',
    professionField: 'Finance',
  );

  /// Demo directory mirrored from the Chaperone Onboarding mock data.
  static const List<MatchProfile> seeds = <MatchProfile>[
    zayd,
    farhan,
    imran,
    bilal,
    salman,
  ];

  static MatchProfile byId(String id) =>
      seeds.firstWhere((p) => p.id == id, orElse: () => zayd);
}
