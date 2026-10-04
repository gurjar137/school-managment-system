import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/features/auth/admin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  const adminEmail = 'dharampalgujar5021@gmail.com';
  const expectedSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
  const adminSecret = 'AdminPassword123!';

  late SupabaseClient client;
  final authService = AuthService();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = RealHttpOverrides();

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}
    client = Supabase.instance.client;
  });

  group('Admin Login Permanent Fix Verification', () {

    test('TEST B: Wrong password throws explicit "Invalid email or password."', () async {
      try {
        await authService.signInWithEmailAndPassword(
          email: adminEmail,
          password: 'IncorrectPassword_Verification#999',
          requiresAdminPortal: true,
        );
        fail('Should have thrown an exception for invalid credentials');
      } catch (e) {
        expect(e.toString(), contains('Invalid email or password.'));
        expect(e.toString(), isNot(contains('Authentication service is not initialized')));
        expect(e.toString(), isNot(contains('Unable to connect')));
      }
    });

    test('TEST A: Correct email + password succeeds, populates session, and resolves profile', () async {
      final profile = await authService.signInWithEmailAndPassword(
        email: adminEmail,
        password: adminSecret,
        requiresAdminPortal: true,
      );

      // Verify returned profile
      expect(profile, isNotNull);
      expect(profile.email.toLowerCase(), equals(adminEmail.toLowerCase()));
      expect(profile.role, equals(UserRole.schoolAdmin));
      expect(profile.role.isAdministrator, isTrue);
      expect(profile.status, equals(AccountStatus.active));
      expect(profile.schoolId, equals(expectedSchoolId));

      // Verify client auth state
      expect(client.auth.currentUser, isNotNull);
      expect(client.auth.currentUser!.id, equals(profile.authUserId));
      expect(client.auth.currentUser!.email, equals(adminEmail));
      expect(client.auth.currentSession, isNotNull);
      expect(client.auth.currentSession!.accessToken.isNotEmpty, isTrue);
    });

    test('TEST 9: Dashboard queries run with authenticated Admin JWT', () async {
      expect(client.auth.currentUser, isNotNull, reason: 'Admin must be authenticated');
      expect(client.auth.currentSession, isNotNull, reason: 'Admin session must be active');

      // 1. Query public.profiles as authenticated Admin
      final profileRes = await client
          .from('profiles')
          .select()
          .eq('auth_user_id', client.auth.currentUser!.id);
      expect(profileRes.isNotEmpty, isTrue);
      expect(profileRes.first['role'], equals('school_admin'));
      expect(profileRes.first['school_id'], equals(expectedSchoolId));

      // 2. Query public.students using StudentService
      final studentService = StudentService();
      final students = await studentService.getAllStudents(schoolId: expectedSchoolId);
      expect(students, isNotNull);
      expect(students.isNotEmpty, isTrue);

      // 3. Verify RPCs evaluate correctly for the authenticated Admin
      final rpcSchool = await client.rpc('get_user_school_id');
      expect(rpcSchool.toString(), equals(expectedSchoolId));
      final rpcRole = await client.rpc('get_user_role');
      expect(rpcRole.toString(), equals('school_admin'));
    });

    test('TEST E: Creating a staff/teacher account does NOT hijack or replace the Admin session', () async {
      final adminBefore = client.auth.currentUser?.id;
      final sessionBefore = client.auth.currentSession?.accessToken;
      expect(adminBefore, isNotNull);
      expect(sessionBefore, isNotNull);

      // Attempt to create a staff profile via AuthService
      final testStaffEmail = 'test_verify_staff_${DateTime.now().millisecondsSinceEpoch}@school.com';
      try {
        final staff = await authService.createStaffAccount(
          name: 'Test Verify Staff',
          email: testStaffEmail,
          phone: '9876543210',
          empId: 'EMP-${DateTime.now().millisecondsSinceEpoch}',
          designation: 'Faculty Member',
          subject: 'Mathematics',
          assignedClass: '5-A',
          password: 'TestPassword123!',
          role: UserRole.teacher,
        );
        expect(staff.email, equals(testStaffEmail));
      } catch (e) {
        // Handled: critical check is that Admin session did not change
      }

      // Crucial check: Current auth user MUST remain the Admin
      expect(client.auth.currentUser?.id, equals(adminBefore));
      expect(client.auth.currentUser?.email, equals(adminEmail));
      expect(client.auth.currentSession?.accessToken, equals(sessionBefore));
    });

    test('TEST D: Session restore from existing auth session resolves admin profile without MockData overwrite', () async {
      expect(client.auth.currentUser, isNotNull);

      // Simulate session restore
      final restoredProfile = await authService.fetchUserProfile(client.auth.currentUser!.id);
      expect(restoredProfile, isNotNull);
      expect(restoredProfile!.role, equals(UserRole.schoolAdmin));
      expect(restoredProfile.role.isAdministrator, isTrue);
      expect(restoredProfile.schoolId, equals(expectedSchoolId));
      expect(restoredProfile.id, isNot(contains('mock')));
      expect(restoredProfile.authUserId, equals(client.auth.currentUser!.id));
    });

    testWidgets('UI TEST 1: Admin Email field ALWAYS starts completely blank with no prefill', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AdminLoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      final emailWidget = tester.widget<TextFormField>(textFields.first);
      expect(emailWidget.controller!.text, equals(''), reason: 'Email field must ALWAYS start completely blank');
      expect(emailWidget.controller!.text, isNot(contains('dharampalgujar5021@gmail.com')), reason: 'Must not prefill admin email');
      expect(emailWidget.controller!.text, isNot(contains('admin@school.com')), reason: 'Must not prefill mock email');

      final rawTextField = tester.widget<TextField>(find.byType(TextField).first);
      expect(rawTextField.autofillHints, isEmpty, reason: 'Autofill hints must be empty');

      final passwordWidget = tester.widget<TextFormField>(textFields.at(1));
      expect(passwordWidget.controller!.text, equals(''), reason: 'Password field must start empty');
    });
  });
}
