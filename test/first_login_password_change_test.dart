import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/features/auth/change_password_screen.dart';
import 'package:school_app/core/providers/app_providers.dart';

void main() {
  group('First-Login & Settings Password Change Security Tests', () {
    test('1. UserProfileModel correctly tracks mustChangePassword flag', () {
      final now = DateTime.now();
      final provisionedAdmin = UserProfileModel(
        id: 'prof-001',
        authUserId: 'auth-001',
        schoolId: 'sch-001',
        schoolName: 'Oakridge International',
        name: 'Jane Admin',
        email: 'admin@oakridge.edu',
        role: UserRole.schoolAdmin,
        status: AccountStatus.active,
        designation: 'Principal',
        mustChangePassword: true,
        createdAt: now,
      );

      expect(provisionedAdmin.mustChangePassword, isTrue);

      final updatedProfile = provisionedAdmin.copyWith(mustChangePassword: false);
      expect(updatedProfile.mustChangePassword, isFalse);
      expect(updatedProfile.name, 'Jane Admin');
      expect(updatedProfile.email, 'admin@oakridge.edu');
    });

    testWidgets('2. ChangePasswordScreen validates minimum 8 chars and matching passwords', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChangePasswordScreen(isFirstLogin: true),
          ),
        ),
      );

      // Verify title for first login
      expect(find.text('Setup Your Permanent Password'), findsOneWidget);
      expect(find.text('Set Permanent Password & Enter Portal'), findsOneWidget);

      // Verify no Cancel button in first login mode
      expect(find.text('Cancel'), findsNothing);

      // Try submitting empty
      await tester.tap(find.text('Set Permanent Password & Enter Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a new password.'), findsOneWidget);

      // Enter short password
      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'short');
      await tester.enterText(textFields.at(1), 'short');
      await tester.tap(find.text('Set Permanent Password & Enter Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters long.'), findsOneWidget);

      // Enter mismatching password
      await tester.enterText(textFields.at(0), 'ValidPass123!');
      await tester.enterText(textFields.at(1), 'DifferentPass123!');
      await tester.tap(find.text('Set Permanent Password & Enter Portal'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match.'), findsOneWidget);
    });

    testWidgets('3. Voluntary ChangePasswordScreen renders Cancel button and voluntary title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChangePasswordScreen(isFirstLogin: false),
          ),
        ),
      );

      expect(find.text('Change Your Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
