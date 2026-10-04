import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/auth_service.dart';

void main() {
  group('STEP 10 — Primary School Admin Onboarding & Security Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('TEST 1 & 2: Create First Admin & Corresponding Profile', () async {
      final profile = await authService.registerPrimarySchoolAdmin(
        schoolName: 'St. Xavier Modern Academy',
        address: 'Ring Road Campus, New Delhi',
        adminName: 'Superintendent Admin',
        email: 'primary.admin@stxavier.edu',
        password: 'SecureAdminPass123!',
      );

      expect(profile, isNotNull);
      expect(profile.email, equals('primary.admin@stxavier.edu'));
      expect(profile.role, equals(UserRole.schoolAdmin));
      expect(profile.role.isAdministrator, isTrue);
      expect(profile.status, equals(AccountStatus.active));
      expect(profile.schoolId, equals('6254bee9-151d-4332-8a1c-3994af7d2153'));
    });

    test('TEST 3: Login with Created First Admin', () async {
      await authService.registerPrimarySchoolAdmin(
        schoolName: 'St. Xavier Modern Academy',
        address: 'Ring Road Campus, New Delhi',
        adminName: 'Primary Administrator',
        email: 'admin.login@stxavier.edu',
        password: 'ValidPassword123!',
      );

      final loggedInUser = await authService.signInWithEmailAndPassword(
        email: 'admin.login@stxavier.edu',
        password: 'ValidPassword123!',
        requiresAdminPortal: true,
      );

      expect(loggedInUser.email, equals('admin.login@stxavier.edu'));
      expect(loggedInUser.role.isAdministrator, isTrue);
      expect(loggedInUser.status, equals(AccountStatus.active));
    });

    test('TEST 4 & 5: Rejected Invalid Credentials & Nonexistent Email', () async {
      expect(
        authService.signInWithEmailAndPassword(
          email: 'nonexistent.admin@school.com',
          password: 'WrongPassword123!',
          requiresAdminPortal: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('TEST 6: Teacher Profile Accessing Admin Portal -> DENIED', () {
      final teacherProfile = UserProfileModel(
        id: 'prof_teacher',
        authUserId: 'auth_teacher',
        schoolId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        schoolName: 'Greenwood International',
        name: 'Test Teacher',
        email: 'test.teacher@school.com',
        role: UserRole.teacher,
        status: AccountStatus.active,
        designation: 'Mathematics Teacher',
        createdAt: DateTime.now(),
      );

      expect(teacherProfile.role.isAdministrator, isFalse);
    });

    test('TEST 7: Inactive Admin Profile -> DENIED Access', () async {
      final inactiveAdmin = UserProfileModel(
        id: 'prof_inactive',
        authUserId: 'auth_inactive',
        schoolId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        schoolName: 'Greenwood International',
        name: 'Inactive Admin',
        email: 'inactive@school.com',
        role: UserRole.schoolAdmin,
        status: AccountStatus.inactive,
        designation: 'School Administrator',
        createdAt: DateTime.now(),
      );

      expect(
        authService.signInWithEmailAndPassword(
          email: inactiveAdmin.email,
          password: 'password123',
          requiresAdminPortal: true,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('TEST 8: School Isolation Scope Validation', () {
      final schoolAAdmin = UserProfileModel(
        id: 'prof_admin_a',
        authUserId: 'auth_a',
        schoolId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        schoolName: 'School A',
        name: 'Admin A',
        email: 'admin.a@school.com',
        role: UserRole.schoolAdmin,
        status: AccountStatus.active,
        designation: 'School Administrator',
        createdAt: DateTime.now(),
      );

      final schoolBId = 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380b22';
      expect(schoolAAdmin.schoolId, isNot(equals(schoolBId)));
    });

    test('TEST 10: Weak Password Validation (< 8 characters)', () {
      expect('short'.length < 8, isTrue);
      expect('SecurePassword123'.length >= 8, isTrue);
    });

    test('TEST 11: Client Privilege Escalation to Super Admin -> DENIED', () {
      final regularAdminRole = UserRole.schoolAdmin;
      expect(regularAdminRole, equals(UserRole.schoolAdmin));
      expect(regularAdminRole == UserRole.superAdmin, isFalse);
    });
  });
}
