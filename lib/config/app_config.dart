import 'package:flutter/foundation.dart';

/// Which backend a build talks to.
enum BackendMode { firebase, emulator, demo }

/// Build-time switches.
class AppConfig {
  AppConfig._();

  static const String _backend = String.fromEnvironment('BACKEND');

  /// Host of the local Firebase emulators. Android emulators reach the
  /// development machine at 10.0.2.2.
  static const String emulatorHost =
      String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

  /// Release builds are always Firebase, whatever was passed, so a fake backend
  /// can never reach members. Debug builds default to the local demo.
  static BackendMode resolveMode(String value, {required bool release}) {
    if (release) return BackendMode.firebase;
    return switch (value) {
      'firebase' => BackendMode.firebase,
      'emulator' => BackendMode.emulator,
      _ => BackendMode.demo,
    };
  }

  static BackendMode get mode => resolveMode(_backend, release: kReleaseMode);

  /// The only code the demo sign-in accepts. Real codes come from Firebase.
  static const String demoOtp = '123456';

  /// Demo builds run on seeded local data and show a permanent banner.
  static bool get isDemo => mode == BackendMode.demo;

  /// Guardian portal, chaperoned chat and meeting scheduling have no server
  /// support yet, so they stay out of production builds.
  static bool get guardianFeatures => isDemo;

  /// Shown in invites and on the biodata. Set to the store link before release.
  static const String appLink = String.fromEnvironment(
    'APP_LINK',
    defaultValue: 'https://example.com/app',
  );

  /// Where members and policies are sent. Set before release.
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@example.com',
  );
  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://example.com/terms',
  );
  static const String privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://example.com/privacy',
  );
}

/// The product's name. Rename here, then update the platform labels.
class AppBrand {
  AppBrand._();
  static const String name = 'Nikah';
}
