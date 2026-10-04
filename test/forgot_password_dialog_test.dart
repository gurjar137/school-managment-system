import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/features/auth/admin_login_screen.dart';

void main() {
  testWidgets('Forgot Password button opens interactive dialog with input and action buttons', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminLoginScreen(),
        ),
      ),
    );

    // Verify Forgot Password button is present
    final forgotPasswordBtn = find.text('Forgot Password?');
    expect(forgotPasswordBtn, findsOneWidget);

    // Tap Forgot Password
    await tester.tap(forgotPasswordBtn);
    await tester.pumpAndSettle();

    // Verify Dialog opened
    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Enter your administrator email address. We will send a secure link to reset your password.'), findsOneWidget);
    expect(find.text('Administrator Email'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Send Reset Link'), findsOneWidget);

    // Test validation on invalid email
    final emailInput = find.widgetWithText(TextFormField, '');
    await tester.enterText(emailInput.first, 'invalid-email');
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address.'), findsOneWidget);

    // Test Cancel button closes dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your administrator email address. We will send a secure link to reset your password.'), findsNothing);
  });
}
