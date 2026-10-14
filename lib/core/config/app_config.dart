import 'package:flutter/foundation.dart';

/// Centralized configuration for dedicated School Management App builds.
///
/// In the 1 School -> 1 Dedicated App architecture, each school has its own
/// branded mobile application built and published separately.
///
/// Build-time Identity:
/// The app is bound to a specific school tenant via [appIdentifier], provided at
/// compile-time using:
///   `--dart-define=APP_IDENTIFIER=<school_app_identifier>`
///
/// In Android Studio / VS Code:
/// Add `--dart-define=APP_IDENTIFIER=YOUR_SCHOOL_APP_IDENTIFIER` to the Run / Build configuration.
///
/// Runtime Tenant Resolution:
/// `school_id` is NEVER hardcoded in production source code or production configuration.
/// The application resolves the authoritative tenant exclusively from the
/// authenticated user's `profiles.school_id` in Supabase, and verifies that the
/// `school_management_apps` record with [appIdentifier] belongs to that same school.
class AppConfig {
  /// Development/debug-only legacy fallback identifier.
  /// Preserved for backward compatibility with isolated unit tests.
  static const String debugFallbackAppIdentifier = 'SCHOOL_1_APP';

  /// Development/debug-only legacy fallback school UUID for isolated sandbox testing.
  /// Preserved for backward compatibility with isolated unit tests.
  static const String debugFallbackDevSchoolId = 'cf895651-4783-489b-8551-959a70098ca8';

  /// Default development app identifier (preserved for backward compatibility with tests).
  static const String defaultAppIdentifier = debugFallbackAppIdentifier;

  /// Compile-time configured school UUID from `--dart-define=SCHOOL_ID` or `--dart-define=SCHOOL_UUID`.
  /// Returns `null` if the build is a shared multi-tenant application.
  static String? get configuredSchoolId {
    const fromSchoolId = String.fromEnvironment('SCHOOL_ID');
    if (fromSchoolId.trim().isNotEmpty) {
      return fromSchoolId.trim();
    }
    const fromSchoolUuid = String.fromEnvironment('SCHOOL_UUID');
    if (fromSchoolUuid.trim().isNotEmpty) {
      return fromSchoolUuid.trim();
    }
    return null;
  }

  /// Compile-time configured app identifier from `--dart-define=APP_IDENTIFIER`.
  /// Returns `null` if not specified at compile time.
  static String? get configuredAppIdentifier {
    const fromEnv = String.fromEnvironment('APP_IDENTIFIER');
    if (fromEnv.trim().isNotEmpty) {
      return fromEnv.trim();
    }
    return null;
  }

  /// Whether this build is explicitly locked to a dedicated school via build-time configuration.
  static bool get isDedicatedBuild =>
      configuredSchoolId != null || configuredAppIdentifier != null;

  /// Authoritative app identifier for this application build.
  ///
  /// Production (`kReleaseMode`):
  /// Resolves `--dart-define=APP_IDENTIFIER` if passed. If not passed, returns `""`.
  ///
  /// Development (`kDebugMode` / test):
  /// Resolves `--dart-define=APP_IDENTIFIER` if passed, or returns [debugFallbackAppIdentifier]
  /// for backward compatibility with isolated tests.
  static String get appIdentifier {
    final configured = configuredAppIdentifier;
    if (configured != null) {
      return configured;
    }
    if (kReleaseMode) {
      return '';
    }
    return debugFallbackAppIdentifier;
  }

  /// Whether the application build has a configured APP_IDENTIFIER or SCHOOL_ID.
  static bool get isConfigured =>
      configuredAppIdentifier != null || configuredSchoolId != null;

  /// Development-only school ID for isolated local verification.
  ///
  /// Production (`kReleaseMode`):
  /// ALWAYS returns `null`. Production tenant identity is exclusively resolved from
  /// the authenticated user's `profiles.school_id`.
  ///
  /// Development (`kDebugMode` / test):
  /// Resolves `--dart-define=DEV_SCHOOL_ID` if passed, or returns null.
  static String? get devSchoolId {
    if (kReleaseMode) {
      return null;
    }
    const fromEnv = String.fromEnvironment('DEV_SCHOOL_ID');
    if (fromEnv.trim().isNotEmpty) {
      return fromEnv.trim();
    }
    return null;
  }
}
