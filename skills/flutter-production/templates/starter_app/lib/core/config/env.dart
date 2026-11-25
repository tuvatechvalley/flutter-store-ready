import 'package:flutter/foundation.dart';

import '../network/certificate_pinner.dart';

/// Build flavor. Selected with `--dart-define=FLAVOR=prod`.
enum AppFlavor { dev, staging, prod }

/// Thrown at startup when the compile-time configuration is unsafe or invalid.
///
/// The app refuses to start instead of silently running with an insecure
/// configuration (e.g. plain HTTP or no certificate pins in production).
final class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;

  @override
  String toString() => 'ConfigException: $message';
}

/// Compile-time configuration supplied with `--dart-define-from-file`.
///
/// SECURITY: everything in here is compiled into the binary and can be
/// extracted by anyone who downloads the app. Never put secrets (API secret
/// keys, signing keys, admin tokens) in dart-defines, assets or source code.
/// Only public identifiers belong here.
@immutable
final class Env {
  const Env._({
    required this.flavor,
    required this.apiBaseUrl,
    required this.sentryDsn,
    required this.certificatePins,
    required this.useMockApi,
    required this.privacyPolicyUrl,
  });

  final AppFlavor flavor;
  final Uri apiBaseUrl;

  /// Public Sentry DSN (not a secret). Empty disables crash reporting.
  final String sentryDsn;

  /// Base64 SHA-256 hashes of the API server's SubjectPublicKeyInfo.
  final List<String> certificatePins;

  /// Use the in-memory fake backend (for demos, UI work and tests).
  final bool useMockApi;

  /// Public privacy policy page (required by Google Play / App Store).
  final Uri? privacyPolicyUrl;

  bool get isProd => flavor == AppFlavor.prod;
  bool get crashReportingEnabled => sentryDsn.isNotEmpty;

  /// Reads the values passed with `--dart-define` / `--dart-define-from-file`.
  static Env fromEnvironment() => parse(
    flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    apiBaseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.example.com',
    ),
    sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
    certificatePins: const String.fromEnvironment('CERT_PINS'),
    useMockApi: const bool.fromEnvironment('USE_MOCK_API', defaultValue: true),
    privacyPolicyUrl: const String.fromEnvironment('PRIVACY_POLICY_URL'),
    isReleaseBuild: kReleaseMode,
  );

  /// Validates raw configuration. Pure function so it can be unit tested.
  static Env parse({
    required String flavor,
    required String apiBaseUrl,
    required String sentryDsn,
    required String certificatePins,
    required bool useMockApi,
    required bool isReleaseBuild,
    String privacyPolicyUrl = '',
  }) {
    final parsedFlavor = AppFlavor.values.asNameMap()[flavor.trim()];
    if (parsedFlavor == null) {
      throw ConfigException('Unknown FLAVOR "$flavor".');
    }

    final uri = Uri.tryParse(apiBaseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ConfigException('API_BASE_URL must be an absolute URL.');
    }
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw const ConfigException(
        'API_BASE_URL must not contain credentials, query or fragment.',
      );
    }
    final mustBeSecure = isReleaseBuild || parsedFlavor != AppFlavor.dev;
    if (mustBeSecure && uri.scheme != 'https') {
      throw const ConfigException(
        'API_BASE_URL must use https outside of dev builds.',
      );
    }

    final List<String> pins;
    try {
      pins = certificatePins
          .split(',')
          .map((pin) => pin.trim())
          .where((pin) => pin.isNotEmpty)
          .map(CertificatePinner.normalizePin)
          .toList(growable: false);
    } on FormatException catch (e) {
      throw ConfigException('Invalid CERT_PINS: ${e.message}');
    }

    Uri? privacyUri;
    if (privacyPolicyUrl.trim().isNotEmpty) {
      privacyUri = Uri.tryParse(privacyPolicyUrl.trim());
      if (privacyUri == null ||
          privacyUri.scheme != 'https' ||
          privacyUri.host.isEmpty) {
        throw const ConfigException('PRIVACY_POLICY_URL must be an https URL.');
      }
    }

    if (parsedFlavor == AppFlavor.prod) {
      if (privacyUri == null) {
        throw const ConfigException('prod requires PRIVACY_POLICY_URL.');
      }
      if (useMockApi) {
        throw const ConfigException('USE_MOCK_API must be false in prod.');
      }
      if (pins.length < 2) {
        throw const ConfigException(
          'prod requires at least 2 CERT_PINS (current key + backup key).',
        );
      }
    }

    return Env._(
      flavor: parsedFlavor,
      apiBaseUrl: uri,
      sentryDsn: sentryDsn.trim(),
      certificatePins: pins,
      useMockApi: useMockApi,
      privacyPolicyUrl: privacyUri,
    );
  }
}
