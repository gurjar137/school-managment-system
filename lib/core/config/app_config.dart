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
  /// Development/debug-only fallback identifier.
  /// Used ONLY in debug/test mode when `--dart-define=APP_IDENTIFIER` is not specified.
  /// In release/production mode, this fallback is disabled to prevent accidental tenant binding.
  static const String debugFallbackAppIdentifier = 'SCHOOL_1_APP';

  /// Development/debug-only fallback school UUID for isolated sandbox testing.
  /// Used ONLY in debug/test mode when explicitly requested.
  /// In release/production mode, this is ALWAYS null.
  static const String debugFallbackDevSchoolId = 'cf895651-4783-489b-8551-959a70098ca8';

  /// Default development app identifier (preserved for backward compatibility with tests).
  static const String defaultAppIdentifier = debugFallbackAppIdentifier;

  /// Authoritative app identifier for this application build.
  ///
  /// Production (`kReleaseMode`):
  /// MUST be passed via `--dart-define=APP_IDENTIFIER=<identifier>`.
  /// If not provided in a release build, returns empty string `""` to prevent silent access.
  ///
  /// Development (`kDebugMode` / test):
  /// Resolves `--dart-define=APP_IDENTIFIER` if passed, or falls back to [debugFallbackAppIdentifier].
  static String get appIdentifier {
    const fromEnv = String.fromEnvironment('APP_IDENTIFIER');
    if (fromEnv.isNotEmpty) {
      return fromEnv.trim();
    }
    // In production release builds, require explicit build-time definition.
    if (kReleaseMode) {
      return '';
    }
    return debugFallbackAppIdentifier;
  }

  /// Whether the application build has a configured APP_IDENTIFIER.
  static bool get isConfigured => appIdentifier.isNotEmpty;

  /// Development-only school ID for isolated local verification.
  ///
  /// Production (`kReleaseMode`):
  /// ALWAYS returns `null`. Production tenant identity is exclusively resolved from
  /// the authenticated user's `profiles.school_id`.
  ///
  /// Development (`kDebugMode` / test):
  /// Resolves `--dart-define=DEV_SCHOOL_ID` if passed, or falls back to [debugFallbackDevSchoolId].
  static String? get devSchoolId {
    if (kReleaseMode) {
      return null;
    }
    const fromEnv = String.fromEnvironment('DEV_SCHOOL_ID');
    if (fromEnv.isNotEmpty) {
      return fromEnv.trim();
    }
    return null;
  }
}
