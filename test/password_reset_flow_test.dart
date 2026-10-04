import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/core/routing/app_router.dart';
import 'package:school_app/core/auth/recovery_session_state.dart';
import 'package:school_app/features/auth/update_password_screen.dart';

void main() {
  group('Password Reset & Redirect Flow Tests', () {
    test('SupabaseConfig.passwordResetRedirectUrl returns valid route', () {
      final url = SupabaseConfig.passwordResetRedirectUrl;
      expect(url, contains('/#/update-password'));
      expect(url, startsWith('http'));
    });

    testWidgets('UpdatePasswordScreen renders form elements when session is active', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UpdatePasswordScreen(bypassSessionCheckForTesting: true),
          ),
        ),
      );

      // Verify header and fields
      expect(find.text('Create New Password 🔐'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('Return to Admin Login'), findsOneWidget);
    });

    testWidgets('UpdatePasswordScreen shows clean form initially and user-friendly error on submit without session', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UpdatePasswordScreen(bypassSessionCheckForTesting: false),
          ),
        ),
      );

      // Clean form is always shown on initial render
      expect(find.text('Create New Password 🔐'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('This password reset link is invalid or has expired. Please request a new link.'), findsNothing);

      // Submit password without session
      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), 'ValidPass123!');
      await tester.enterText(inputs.at(1), 'ValidPass123!');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password reset link has expired. Please request a new one.'), findsOneWidget);
    });

    testWidgets('UpdatePasswordScreen validates password matching and length', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UpdatePasswordScreen(bypassSessionCheckForTesting: true),
          ),
        ),
      );

      final inputs = find.byType(TextFormField);
      expect(inputs, findsNWidgets(2));

      // 1. Enter short password
      await tester.enterText(inputs.at(0), '123');
      await tester.enterText(inputs.at(1), '123');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters long'), findsOneWidget);

      // 2. Enter mismatched passwords
      await tester.enterText(inputs.at(0), 'ValidPassword123');
      await tester.enterText(inputs.at(1), 'DifferentPassword123');
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('Router config includes /update-password route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      final hasUpdatePasswordRoute = router.configuration.routes.any(
        (r) => r is GoRoute && r.path == '/update-password',
      );

      expect(hasUpdatePasswordRoute, isTrue, reason: '/update-password must be registered in GoRouter');
    });

    testWidgets('UpdatePasswordScreen displays preparing state when processing is active', (tester) async {
      RecoverySessionState.isProcessing = true;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UpdatePasswordScreen(bypassSessionCheckForTesting: true),
          ),
        ),
      );

      expect(find.text('Preparing password reset...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      RecoverySessionState.isProcessing = false;
    });

    testWidgets('UpdatePasswordScreen displays error banner when genuine recovery attempt failed', (tester) async {
      RecoverySessionState.isProcessing = false;
      RecoverySessionState.exchangeAttempted = true;
      RecoverySessionState.exchangeSuccess = false;

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: UpdatePasswordScreen(bypassSessionCheckForTesting: false),
          ),
        ),
      );

      expect(
        find.text('This password reset link is invalid or has expired. Please request a new one.'),
        findsOneWidget,
      );
      expect(find.text('Return to Admin Login'), findsOneWidget);

      RecoverySessionState.exchangeAttempted = false;
    });

    test('RecoverySessionState.printLiveRecoveryDebug outputs telemetry safely', () {
      RecoverySessionState.codeDetected = true;
      RecoverySessionState.recoveryMechanism = 'implicit';
      RecoverySessionState.recoveryProcessingStarted = true;
      RecoverySessionState.recoveryProcessingCompleted = true;
      RecoverySessionState.passwordUpdateSuccess = true;

      expect(() => RecoverySessionState.printLiveRecoveryDebug(), returnsNormally);
    });
  });
}
