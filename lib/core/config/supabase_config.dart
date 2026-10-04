import 'package:flutter/foundation.dart';

/// Supabase Configuration for School Admin App
/// 
/// Connects to the shared Supabase project used by both the School Admin App and Parent App.
/// 
/// Security Rules:
/// - Only public/publishable (anon) client keys are used here.
/// - Service-role and secret keys MUST NEVER be embedded in client apps.
class SupabaseConfig {
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const String _envAppBaseUrl = String.fromEnvironment('APP_BASE_URL');

  // Fallback local constants when --dart-define is not provided
  static const String _fallbackUrl = 'https://hnvjenkeimzkdgkuwbeb.supabase.co';
  static const String _fallbackPublishableKey = 'sb_publishable_19M-FirlFuK29VbdO1d87g_bNOysJwZ';

  static String get url {
    final raw = (_envUrl.isNotEmpty ? _envUrl : _fallbackUrl).trim();
    return raw.replaceAll(RegExp(r'/rest/v1/?$'), '').replaceAll(RegExp(r'/+$'), '');
  }

  static String get publishableKey => (_envKey.isNotEmpty ? _envKey : _fallbackPublishableKey).trim();

  static bool get isConfigured =>
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      !url.contains('YOUR_SUPABASE_PROJECT_ID') &&
      !publishableKey.contains('YOUR_SUPABASE_PUBLISHABLE_KEY');

  /// Dynamic redirect URL for Password Reset.
  /// In Web development and production, resolves the current running origin
  /// (e.g. http://localhost:50091 or https://app.example.com).
  /// Supabase appends #access_token=...&type=recovery to this origin, which supabase_flutter
  /// natively receives and exchanges for a valid recovery session.
  static String get passwordResetRedirectUrl {
    String base = 'http://localhost:50091';
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && origin != 'null') {
          base = origin;
        }
      } catch (_) {}
    } else if (_envAppBaseUrl.isNotEmpty) {
      base = _envAppBaseUrl;
    }
    return '$base/#/update-password';
  }
}

