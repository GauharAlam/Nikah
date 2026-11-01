import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/app_router.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/verification_doc.dart';
import 'package:nikah_app/models/ward_profile.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  group('onboarding steps', () {
    test('a draft from the seven-step flow resumes at the matching step', () {
      expect(<int>[1, 2, 3, 4].map((int s) => WardProfile.migrateStep(s, null)), everyElement(1));
      expect(WardProfile.migrateStep(5, null), 3);
      expect(WardProfile.migrateStep(6, null), 4);
      expect(WardProfile.migrateStep(7, null), 5);
    });

    test('a current draft keeps its step', () {
      expect(WardProfile.migrateStep(6, 2), 6);
      expect(WardProfile.migrateStep(null, null), 1);
    });
  });

  test('new profile fields survive the draft round trip', () {
    const WardProfile p = WardProfile(
      familyType: 'Joint family',
      familyBackground: 'Teachers',
      familyValues: 'Practising',
      familyLocation: 'Lucknow',
      siblings: '2',
      preferredLanguage: 'Urdu',
      graduationYear: '2020',
      educationStatus: 'Completed',
      employmentStatus: 'Employed',
      careerDescription: 'Paediatrics',
    );
    final WardProfile back = WardProfile.fromDraft(p.toDraft(qualificationGraduate: true));
    expect(back.familyType, 'Joint family');
    expect(back.familyBackground, 'Teachers');
    expect(back.familyValues, 'Practising');
    expect(back.familyLocation, 'Lucknow');
    expect(back.siblings, '2');
    expect(back.preferredLanguage, 'Urdu');
    expect(back.graduationYear, '2020');
    expect(back.educationStatus, 'Completed');
    expect(back.employmentStatus, 'Employed');
    expect(back.careerDescription, 'Paediatrics');
  });

  test('review and document states read from the server', () {
    expect(ReviewStage.fromWire('changes_requested'), ReviewStage.changesRequested);
    expect(ReviewStage.fromWire(null), ReviewStage.draft);
    expect(VerificationDocStatus.fromWire('under_review'), VerificationDocStatus.underReview);
    expect(VerificationDocStatus.fromWire('resubmission_required'),
        VerificationDocStatus.resubmissionRequired);
    expect(VerificationDocStatus.fromWire(null), VerificationDocStatus.missing);
    expect(VerificationDocStatus.resubmissionRequired.needsUpload, isTrue);
    expect(VerificationDocStatus.underReview.isWaiting, isTrue);
    expect(VerificationDocStatus.approved.needsUpload, isFalse);
  });

  test('no document label implies a background check or a guarantee', () {
    for (final VerificationDocStatus s in VerificationDocStatus.values) {
      final String text = '${s.label} ${s.detail}'.toLowerCase();
      expect(text, isNot(contains('guarantee')));
      expect(text, isNot(contains('background')));
      expect(text, isNot(contains('barkat')));
    }
  });

  group('session start', () {
    late FakeBackend backend;
    late RemoteAppStore store;

    Future<void> settle() async {
      for (int i = 0; i < 6; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      backend = FakeBackend();
      store = RemoteAppStore(await SharedPreferences.getInstance(), backend);
      addTearDown(store.dispose);
    });

    test('a failed draft load offers a retry and never shows an empty profile', () async {
      backend.failDraft = const BackendException('offline', code: 'unavailable');
      backend.auth.add(const AuthUser(uid: 'me'));
      await settle();
      expect(store.startupError, isNotNull);
      expect(store.isRestoring, isTrue);
      expect(guardRoute(store, AppRoutes.onboarding), AppRoutes.splash);

      store.retryStartup();
      await settle();
      expect(store.startupError, isNull);
      expect(store.isRestoring, isFalse);
      expect(store.profile, isNotNull);
    });

    test('an auth stream failure offers a retry', () async {
      backend.auth.addError(StateError('boom'));
      await settle();
      expect(store.startupError, isNotNull);
    });

    test('a request for changes lets the member edit, like a rejection', () async {
      backend.auth.add(const AuthUser(uid: 'me', phone: '+911'));
      await settle();
      backend.account.add(const AccountState(
        stage: ReviewStage.changesRequested,
        rejectionReason: 'Clearer photo please',
        rejectedPhotos: <String>['photos/me/1.jpg'],
      ));
      await settle();
      expect(guardRoute(store, AppRoutes.homeDiscovery), AppRoutes.reviewStatus);
      expect(guardRoute(store, AppRoutes.onboarding), isNull);
      expect(store.rejectedPhotos, <String>['photos/me/1.jpg']);
      expect(store.verifiedPhone, '+911');
    });

    test('an account without a verified phone can reach the phone step', () async {
      backend.auth.add(const AuthUser(uid: 'me'));
      await settle();
      backend.account.add(const AccountState());
      await settle();
      expect(store.verifiedPhone, isEmpty);
      expect(guardRoute(store, AppRoutes.verifyPhone), isNull);
    });
  });
}
