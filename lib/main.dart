
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_providers.dart';
import 'core/routing/app_router.dart';
import 'core/desktop/desktop_shortcuts_wrapper.dart';

import 'core/auth/recovery_session_state.dart';

Future<void> _processStartupRecovery(SupabaseClient client) async {
  if (!kIsWeb) return;
  if (RecoverySessionState.exchangeCount > 0) return;

  try {
    final uri = Uri.base;
    final rawUrl = uri.toString();

    // Check queryParameters, fragment, and raw URL for 'code'
    String? authCode = uri.queryParameters['code'];
    if (authCode == null || authCode.isEmpty) {
      final fragmentParams = Uri.splitQueryString(uri.fragment);
      authCode = fragmentParams['code'];
    }
    if (authCode == null || authCode.isEmpty) {
      final match = RegExp(r'[?&#]code=([^&#]+)').firstMatch(rawUrl);
      if (match != null) {
        authCode = Uri.decodeComponent(match.group(1)!);
      }
    }

    final hasAccessToken = uri.queryParameters.containsKey('access_token') ||
        Uri.splitQueryString(uri.fragment).containsKey('access_token') ||
        rawUrl.contains('access_token=');
    final isRecoveryType = rawUrl.contains('type=recovery');

    RecoverySessionState.rawUriContainsCode = rawUrl.contains('code=');
    RecoverySessionState.rawCodeLength = authCode?.length ?? 0;
    RecoverySessionState.codePassedUnchanged = authCode != null && authCode.isNotEmpty;
    RecoverySessionState.codeDetected = (authCode != null && authCode.isNotEmpty) || hasAccessToken || isRecoveryType;

    if (!RecoverySessionState.codeDetected) {
      return;
    }

    RecoverySessionState.recoveryProcessingStarted = true;
    RecoverySessionState.isProcessing = true;
    RecoverySessionState.exchangeAttempted = true;
    RecoverySessionState.exchangeCount++;

    if (hasAccessToken || isRecoveryType) {
      RecoverySessionState.recoveryMechanism = 'implicit';
      Uri normalizedUri = uri;
      if (rawUrl.contains('access_token=')) {
        final tokenIndex = rawUrl.indexOf('access_token=');
        final firstHashIndex = rawUrl.indexOf('#');
        if (firstHashIndex != -1 && tokenIndex > firstHashIndex) {
          final origin = uri.origin;
          final fragment = rawUrl.substring(tokenIndex);
          normalizedUri = Uri.parse('$origin/#$fragment');
        }
      }
      await client.auth.getSessionFromUrl(normalizedUri);
      RecoverySessionState.exchangeSuccess = true;
      RecoverySessionState.exchangeResult = 'success';
      RecoverySessionState.detailedErrorMessage = null;
    } else if (authCode != null && authCode.isNotEmpty) {
      RecoverySessionState.recoveryMechanism = 'pkce';
      // Authoritative PKCE exchange
      await client.auth.exchangeCodeForSession(authCode);
      RecoverySessionState.exchangeSuccess = true;
      RecoverySessionState.exchangeResult = 'success';
      RecoverySessionState.detailedErrorMessage = null;
    }
  } on AuthException catch (e) {
    RecoverySessionState.exchangeSuccess = false;
    RecoverySessionState.exchangeResult = 'failure';
    RecoverySessionState.exceptionType = 'AuthException';
    RecoverySessionState.statusCode = e.statusCode ?? 'unknown';
    RecoverySessionState.errorCode = e.code ?? 'unknown';
    RecoverySessionState.detailedErrorMessage = e.message;
    RecoverySessionState.errorMessage =
        'This password reset link is invalid or has expired. Please request a new link.';
    debugPrint('[Recovery AuthException]: ${e.message} (status: ${e.statusCode}, code: ${e.code})');
  } catch (e) {
    RecoverySessionState.exchangeSuccess = false;
    RecoverySessionState.exchangeResult = 'failure';
    RecoverySessionState.exceptionType = e.runtimeType.toString();
    RecoverySessionState.detailedErrorMessage = e.toString();
    RecoverySessionState.errorMessage =
        'This password reset link is invalid or has expired. Please request a new link.';
    debugPrint('[Recovery Error]: $e');
  } finally {
    RecoverySessionState.isProcessing = false;
    RecoverySessionState.recoveryProcessingCompleted = true;
    RecoverySessionState.printLiveRecoveryDebug();
    RecoverySessionState.printCodeExchangeDiagnostics();
    RecoverySessionState.printSafeDiagnostics(contextTag: 'Startup Processing');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (SupabaseConfig.isConfigured) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false, // Authoritative single-exchange in _processStartupRecovery
        ),
      );
      debugPrint('[Supabase] Initialized successfully with shared project.');

      final client = Supabase.instance.client;
      client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          RecoverySessionState.recoveryEventReceived = true;
        }
      });

      await _processStartupRecovery(client);
    } else {
      debugPrint('[Supabase] Running in local/mock mode. Configure SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to connect live backend.');
    }
  } catch (e) {
    debugPrint('[Supabase Initialization Error]: $e');
  }

  runApp(
    const ProviderScope(
      child: SchoolApp(),
    ),
  );
}

class SchoolApp extends ConsumerWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'School Management OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => DesktopShortcutsWrapper(child: child ?? const SizedBox.shrink()),
    );
  }
}
