import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Global state tracking for Supabase password recovery flows
class RecoverySessionState {
  static bool isProcessing = false;
  static bool codeDetected = false;
  static bool exchangeAttempted = false;
  static String? exchangeResult; // 'success' or 'failure'
  static bool exchangeSuccess = false;
  static int exchangeCount = 0;

  static bool recoveryEventReceived = false;
  static bool openedAfterProcessing = false;
  static String? errorMessage;
  static String recoveryMechanism = 'none'; // 'implicit', 'pkce', or 'none'
  static bool recoveryProcessingStarted = false;
  static bool recoveryProcessingCompleted = false;
  static bool passwordUpdateSuccess = false;

  // Diagnostics required by Section 2 & Section 3
  static bool rawUriContainsCode = false;
  static int rawCodeLength = 0;
  static bool codePassedUnchanged = false;
  static String? exceptionType;
  static String? statusCode;
  static String? errorCode;
  static String? detailedErrorMessage;

  static bool get hasActiveSession {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      final client = Supabase.instance.client;
      return client.auth.currentSession != null || client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  static void printLiveRecoveryDebug({bool? updateSuccess}) {
    if (updateSuccess != null) {
      passwordUpdateSuccess = updateSuccess;
    }
    final sessionActive = hasActiveSession;
    bool userExists = false;
    if (SupabaseConfig.isConfigured) {
      try {
        userExists = Supabase.instance.client.auth.currentUser != null;
      } catch (_) {}
    }

    print('========================================');
    print('=== RECOVERY LIVE DEBUG ===');
    print('recovery parameter detected = $codeDetected');
    print('recovery mechanism = $recoveryMechanism');
    print('recovery processing started = $recoveryProcessingStarted');
    print('recovery processing completed = $recoveryProcessingCompleted');
    print('session active = $sessionActive');
    print('currentUser exists = $userExists');
    print('password update success = $passwordUpdateSuccess');
    print('========================================');
  }

  static void printCodeExchangeDiagnostics() {
    print('========================================');
    print('=== PASSWORD RESET CODE EXCHANGE ===');
    print('recovery code detected = $codeDetected');
    print('exchange attempted = $exchangeAttempted');
    print('exchange success = $exchangeSuccess');
    print('exchange count = $exchangeCount');
    print('exception type = ${exceptionType ?? "none"}');
    print('status code = ${statusCode ?? "none"}');
    print('error code = ${errorCode ?? "none"}');
    print('error message = ${detailedErrorMessage ?? "none"}');
    print('raw URI contains code = $rawUriContainsCode');
    print('parsed code length > 0 = ${rawCodeLength > 0}');
    print('code is passed unchanged to Supabase = $codePassedUnchanged');
    print('========================================');
  }

  static void printSafeDiagnostics({String? contextTag}) {
    final sessionActive = hasActiveSession;
    bool userExists = false;
    if (SupabaseConfig.isConfigured) {
      try {
        userExists = Supabase.instance.client.auth.currentUser != null;
      } catch (_) {}
    }

    print('========================================');
    print('=== RECOVERY FLOW ===');
    if (contextTag != null) {
      print('Context = $contextTag');
    }
    print('browser URL contains recovery code = $codeDetected');
    print('code exchange attempted = $exchangeAttempted');
    print('code exchange result = ${exchangeResult ?? "not_attempted"}');
    print('recovery session active = $sessionActive');
    print('currentUser exists = $userExists');
    print('PASSWORD_RECOVERY event received = $recoveryEventReceived');
    print('ResetPasswordScreen opened before/after recovery processing = ${openedAfterProcessing ? "after" : "before"}');
    print('========================================');
  }
}
