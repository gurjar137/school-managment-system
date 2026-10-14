import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/school_management_app_model.dart';
import 'package:school_app/data/models/school_app_access_state.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/services/tenant_access_service.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
  const otherSchoolId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

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
  });

  group('Admin Portal Login & Role Security Tests', () {
    test('1. Valid School Admin Login succeeds with admin role and KPS school ID', () async {
      final authService = AuthService();
      final adminProfile = await authService.signInWithEmailAndPassword(
        email: 'admin@school.com',
        password: 'password123',
        requiresAdminPortal: true,
      );

      expect(adminProfile, isNotNull);
      expect(adminProfile.email, equals('admin@school.com'));
      expect(adminProfile.role, equals(UserRole.schoolAdmin));
      expect(adminProfile.role.isAdministrator, isTrue);
      expect(adminProfile.schoolId, equals(kpsSchoolId));
      expect(adminProfile.status, equals(AccountStatus.active));
    });

    test('2. Staff Login remains functional for class teacher with teacher role', () async {
      final authService = AuthService();
      final teacherProfile = await authService.signInWithEmailAndPassword(
        email: 'test.teacher.1a@school-test.local',
        password: 'TestPass123!',
        requiresAdminPortal: false,
      );

      expect(teacherProfile, isNotNull);
      expect(teacherProfile.email, equals('test.teacher.1a@school-test.local'));
      expect(teacherProfile.role, equals(UserRole.teacher));
      expect(teacherProfile.role.isAdministrator, isFalse);
      expect(teacherProfile.schoolId, equals(kpsSchoolId));
      expect(teacherProfile.assignedClass, isNotEmpty);
      expect(teacherProfile.status, equals(AccountStatus.active));
    });

    test('3. Staff account is securely denied access to Admin Portal with explicit error', () async {
      final authService = AuthService();

      await expectLater(
        authService.signInWithEmailAndPassword(
          email: 'test.teacher.1a@school-test.local',
          password: 'TestPass123!',
          requiresAdminPortal: true,
        ),
        throwsA(
          predicate((e) =>
              e is Exception &&
              e.toString().contains('This account does not have administrator access. Please use Staff Login.')),
        ),
      );

      // Verify that unauthorized session was revoked and not kept active
      expect(Supabase.instance.client.auth.currentUser, isNull);
    });

    test('4. Admin account can log in via Staff Login and retains administrator role', () async {
      final authService = AuthService();
      final profile = await authService.signInWithEmailAndPassword(
        email: 'admin@school.com',
        password: 'password123',
        requiresAdminPortal: false,
      );

      expect(profile, isNotNull);
      expect(profile.role, equals(UserRole.schoolAdmin));
      expect(profile.role.isAdministrator, isTrue);
      expect(profile.schoolId, equals(kpsSchoolId));
    });

    test('5. Non-admin profile cannot escalate privileges via client-side metadata', () async {
      final authService = AuthService();

      // Sign in as teacher
      await authService.signInWithEmailAndPassword(
        email: 'test.teacher.1a@school-test.local',
        password: 'TestPass123!',
        requiresAdminPortal: false,
      );

      final user = Supabase.instance.client.auth.currentUser;
      expect(user, isNotNull);

      // Authoritative database resolution must always enforce teacher role, ignoring client metadata
      final authoritativeProfile = await authService.fetchUserProfile(user!.id);
      expect(authoritativeProfile?.role, equals(UserRole.teacher));
      expect(authoritativeProfile?.role.isAdministrator, isFalse);
    });

    test('6. Logout cleanly terminates session and allows switching between staff and admin', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authService = AuthService();
      final notifier = container.read(authProvider.notifier);

      // 1. Sign in as teacher
      final teacherProfile = await authService.signInWithEmailAndPassword(
        email: 'test.teacher.1a@school-test.local',
        password: 'TestPass123!',
        requiresAdminPortal: false,
      );
      notifier.setUserProfile(teacherProfile);
      expect(container.read(authProvider)?.role, equals(UserRole.teacher));

      // 2. Perform logout
      await notifier.logout();
      expect(container.read(authProvider), isNull);
      expect(Supabase.instance.client.auth.currentUser, isNull);

      // 3. Switch to admin account
      final adminProfile = await authService.signInWithEmailAndPassword(
        email: 'admin@school.com',
        password: 'password123',
        requiresAdminPortal: true,
      );
      notifier.setUserProfile(adminProfile);
      expect(container.read(authProvider)?.role, equals(UserRole.schoolAdmin));
      expect(container.read(authProvider)?.schoolId, equals(kpsSchoolId));

      // Clean up after test
      await notifier.logout();
    });

    test('7. Tenant isolation blocks cross-school access attempts', () {
      final activeSchool = SchoolModel(
        id: kpsSchoolId,
        schoolCode: 'KPS',
        name: 'Kamal Public School',
        status: AccountStatus.active,
        createdAt: DateTime(2025, 1, 1),
      );

      final matchingApp = SchoolManagementAppModel(
        id: 'kps-app',
        schoolId: kpsSchoolId,
        appName: 'KPS App',
        appIdentifier: 'KPS_APP',
        status: 'active',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      // Access granted when school matches
      final grantedResult = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: matchingApp,
        subscription: null,
        configuredSchoolId: kpsSchoolId,
      );
      expect(grantedResult.isAllowed, isTrue);

      // Access blocked with appMismatch when configuredSchoolId is another school
      final mismatchResult = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: matchingApp,
        subscription: null,
        configuredSchoolId: otherSchoolId,
      );
      expect(mismatchResult.isBlocked, isTrue);
      expect(mismatchResult.status, equals(AppAccessStatus.appMismatch));
      expect(mismatchResult.userMessage, contains('not configured for this school'));
    });
  });
}
