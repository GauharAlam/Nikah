import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nikah_app/config/app_config.dart';
import 'package:nikah_app/data/backend.dart';
import 'package:nikah_app/models/filters.dart';
import 'package:nikah_app/models/wali.dart';
import 'package:nikah_app/providers/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backend.dart';

void main() {
  group('backend mode', () {
    test('a release build is always Firebase, whatever was passed', () {
      for (final String value in <String>['', 'demo', 'emulator', 'firebase', 'x']) {
        expect(AppConfig.resolveMode(value, release: true), BackendMode.firebase);
      }
    });

    test('a debug build honours the request and defaults to the demo', () {
      expect(AppConfig.resolveMode('', release: false), BackendMode.demo);
      expect(AppConfig.resolveMode('emulator', release: false), BackendMode.emulator);
      expect(AppConfig.resolveMode('firebase', release: false), BackendMode.firebase);
    });
  });

  test('failure kinds tell a screen what to do', () {
    const Map<String, FailureKind> table = <String, FailureKind>{
      'unavailable': FailureKind.offline,
      'network-request-failed': FailureKind.offline,
      'permission-denied': FailureKind.notAllowed,
      'not-found': FailureKind.notFound,
      'resource-exhausted': FailureKind.limitReached,
      'requires-recent-login': FailureKind.recentSignInNeeded,
      'failed-precondition': FailureKind.invalid,
      'internal': FailureKind.other,
    };
    table.forEach((String code, FailureKind kind) {
      expect(BackendException.kindOf(code), kind, reason: code);
    });
  });

  test('filters survive a round trip', () {
    const MatchFilters f = MatchFilters(minAge: 24, sect: 'Sunni', cities: <String>['Delhi']);
    final MatchFilters back = MatchFilters.fromJson(f.toJson());
    expect(back.minAge, 24);
    expect(back.sect, 'Sunni');
    expect(back.cities, <String>['Delhi']);
  });

  group('production store', () {
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

    test('shows nothing seeded', () async {
      backend.auth.add(const AuthUser(uid: 'me'));
      await settle();
      expect(store.guardian.name, Guardian.none.name);
      expect(store.activityLog, isEmpty);
      expect(store.meetings, isEmpty);
      expect(store.notifications, isEmpty);
      expect(store.chatThreadIds, isEmpty);
      expect(store.discoveredProfiles, isEmpty);
    });

    test('eligibility comes from server config', () async {
      backend.auth.add(const AuthUser(uid: 'me'));
      await settle();
      expect(store.graduatesOnly, isTrue);
      backend.limits.add(const AppLimits(graduatesOnly: false, requireIdProof: false));
      await settle();
      expect(store.graduatesOnly, isFalse);
      expect(store.requireIdProof, isFalse);
    });

    test('a second member on the device inherits nothing from the first', () async {
      backend.auth.add(const AuthUser(uid: 'a'));
      await settle();
      store.acceptPledge();
      store.setFilters(const MatchFilters(minAge: 30));
      store.blockProfile('x');
      backend.auth.add(null);
      await settle();
      backend.auth.add(const AuthUser(uid: 'b'));
      await settle();
      expect(store.pledgeAccepted, isFalse);
      expect(store.filters.minAge, const MatchFilters().minAge);
      expect(store.isBlocked('x'), isFalse);
      backend.auth.add(null);
      await settle();
      backend.auth.add(const AuthUser(uid: 'a'));
      await settle();
      expect(store.pledgeAccepted, isTrue);
      expect(store.filters.minAge, 30);
    });
  });

  test('no reference-app branding ships', () {
    final List<String> found = <String>[
      ...Directory('lib').listSync(recursive: true).whereType<File>().map((File f) => f.path),
      'pubspec.yaml',
      'android/app/build.gradle.kts',
      'android/app/src/main/AndroidManifest.xml',
      'ios/Runner/Info.plist',
      'ios/Runner/AppDelegate.swift',
    ].where((String path) => File(path).readAsStringSync().toLowerCase().contains('barkat')).toList();
    expect(found, isEmpty);
  });

  test('only the entry point imports the demo store', () {
    final List<String> offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .where((File f) => f.readAsStringSync().contains('demo_app_store.dart'))
        .map((File f) => f.path)
        .toList()
      ..sort();
    expect(offenders, <String>['lib/main.dart']);
  });
}
