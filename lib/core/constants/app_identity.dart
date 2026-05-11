// core/constants/app_identity.dart
// WHY: Single Source of Truth (SSOT) for all brand, legal, and version info.
// Every screen, dialog, platform config, and about page must reference this file.
// Changing the brand name, version, or company requires editing ONLY this file.

/// Centralized application identity — brand, version, legal, and contact info.
///
/// **SSOT Mandate:** No other file should contain hardcoded brand names,
/// version strings, or copyright text. Use [AppIdentity] exclusively.
abstract final class AppIdentity {
  // ─── Brand ─────────────────────────────────────────────
  /// The full marketing name of the application.
  static const String appName = 'Kasir Pro';

  /// Short display label used in compact UI areas (AppBar, badges).
  static const String appNameShort = 'Kasir';

  /// Internal package identifier (matches pubspec.yaml `name`).
  static const String packageName = 'holol_POS';

  // ─── Version ───────────────────────────────────────────
  /// Semantic version string — update here + pubspec.yaml on each release.
  static const String version = '1.0.0';

  /// Build number for store submissions (incremented per release).
  static const int buildNumber = 1;

  /// Full version display string (e.g. "v1.0.0").
  static const String versionDisplay = 'v$version';

  // ─── Company / Publisher ────────────────────────────────
  /// The legal entity that publishes this application.
  static const String companyName = 'Extra Solutions';

  /// The legal entity domain used in bundle IDs.
  static const String companyDomain = 'extrasolutions.com.sa';

  /// Reverse-domain bundle identifier prefix.
  static const String bundleIdPrefix = 'com.extrasolutions';

  /// Full application bundle ID (Android/iOS/macOS).
  static const String bundleId = '$bundleIdPrefix.kasirpro';

  // ─── Developer ─────────────────────────────────────────
  /// Lead developer / maintainer name.
  static const String developerName = 'Extra Solutions Development Team';

  // ─── Legal ─────────────────────────────────────────────
  /// Copyright notice year.
  static const int copyrightYear = 2026;

  /// Full copyright line for dialogs and about screens.
  static const String copyright =
      '© $copyrightYear $companyName. All rights reserved.';

  /// Short legalese for Flutter's showAboutDialog.
  static const String legalese =
      '© $copyrightYear $companyName\n'
      'Professional Point-of-Sale solution for retail businesses.\n'
      'Powered by Backend ORDS integration.';

  // ─── Support / Contact ─────────────────────────────────
  /// Support email address.
  static const String supportEmail = 'support@extrasolutions.com.sa';

  /// Company website URL.
  static const String websiteUrl = 'https://extrasolutions.com.sa';
}
