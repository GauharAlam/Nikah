/// Build-time switches. Production builds pass `--dart-define=BACKEND=firebase`.
class AppConfig {
  AppConfig._();

  static const String _backend =
      String.fromEnvironment('BACKEND', defaultValue: 'demo');

  /// Demo builds run on seeded local data and show a permanent banner.
  static bool get isDemo => _backend != 'firebase';

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
  static const String name = 'Barkat Nikah';
}
