import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nikah_app/l10n/app_strings.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/models/ward_profile.dart';
import 'package:nikah_app/providers/demo_app_store.dart';
import 'package:nikah_app/services/biodata_pdf.dart';
import 'package:nikah_app/services/profile_strength.dart';

const WardProfile member = WardProfile(
  displayName: 'Sara Khan',
  phoneCode: '+91',
  phone: '9876543210',
  city: 'Delhi',
  height: '5\'4"',
  maritalStatus: 'Never married',
  qualification: 'MBA',
  profession: 'Doctor',
  caste: 'Syed',
  sect: 'Sunni',
  almaMaters: <String>['Aligarh Muslim University'],
  aboutMe: 'A short introduction.',
);

void main() {
  tearDown(() => AppStrings.current = AppLanguage.english);

  group('biodata', () {
    test('leaves out the phone number unless asked', () {
      final List<String> labels =
          BiodataPdf.rows(member, includePhone: false).map(((String, String) r) => r.$1).toList();
      expect(labels, isNot(contains('Contact')));
      expect(
        BiodataPdf.rows(member, includePhone: true).last,
        ('Contact', '+919876543210'),
      );
    });

    test('respects hidden caste and skips empty rows', () {
      final List<String> labels = BiodataPdf.rows(
        member.copyWith(showCaste: false),
        includePhone: false,
      ).map(((String, String) r) => r.$1).toList();
      expect(labels, isNot(contains('Caste')));
      expect(labels, isNot(contains('Children')));
    });

    test('produces a real PDF, even with text the font cannot show', () async {
      final List<int> bytes = await BiodataPdf.build(
        member.copyWith(aboutMe: 'नमस्ते and hello'),
        appName: 'App',
        link: 'https://example.com',
      );
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    });
  });

  group('profile strength', () {
    test('an empty profile starts at zero with a next step', () {
      final ProfileStrength s = profileStrength(const WardProfile(), VerificationDoc.blank);
      expect(s.percent, 0);
      expect(s.nextTip, 'Add your basic details');
    });

    test('rises as the profile fills, and pending documents count', () {
      final ProfileStrength s = profileStrength(
        member.copyWith(photos: <String>['a']),
        <VerificationDoc>[
          VerificationDoc.blank.first.copyWith(status: VerificationDocStatus.pending),
        ],
      );
      expect(s.percent, 55);
      expect(s.nextTip, 'Upload your education proof');
    });

    test('a complete profile reaches 100', () {
      final ProfileStrength s = profileStrength(
        member.copyWith(
          photos: <String>['a', 'b', 'c'],
          aboutMe: 'x' * 40,
          extraPractices: <String>['Fajr'],
        ),
        VerificationDoc.blank
            .map((VerificationDoc d) => d.copyWith(status: VerificationDocStatus.approved))
            .toList(),
      );
      expect(s.percent, 100);
      expect(s.nextTip, isNull);
    });
  });

  group('language', () {
    test('translates known text and keeps unknown text', () {
      expect(tr('Next'), 'Next');
      AppStrings.current = AppLanguage.hindi;
      expect(tr('Next'), 'आगे');
      expect(tr('No such text'), 'No such text');
      AppStrings.current = AppLanguage.hinglish;
      expect(tr('Next'), 'Aage');
    });

    test('every row has both translations', () {
      for (final MapEntry<String, List<String>> e in AppStrings.table.entries) {
        expect(e.value.length, 2, reason: e.key);
        expect(e.value.every((String t) => t.trim().isNotEmpty), isTrue, reason: e.key);
      }
    });

    test('the choice survives a restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final DemoAppStore store = DemoAppStore(prefs);
      addTearDown(store.dispose);
      store.setLanguage(AppLanguage.hindi);
      AppStrings.current = AppLanguage.english;

      final DemoAppStore reopened = DemoAppStore(prefs);
      addTearDown(reopened.dispose);
      expect(reopened.language, AppLanguage.hindi);
    });

    test('translating never changes stored values', () {
      AppStrings.current = AppLanguage.hindi;
      final Map<String, dynamic> draft = member.toDraft(qualificationGraduate: true);
      expect(draft['maritalStatus'], 'Never married');
    });
  });
}
