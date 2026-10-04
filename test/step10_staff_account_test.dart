import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STEP 10 — Staff Account Creation & Security Tests', () {
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authService = AuthService();
    });

    test('TEST 1 & 2: School Admin creates Staff Account with Temporary Password', () async {
      final staffProfile = await authService.createStaffAccount(
        name: 'Test Faculty',
        email: 'test.faculty@school.com',
        phone: '+91 98765 99887',
        empId: 'EMP-9901',
        designation: 'Senior Physics Lecturer',
        subject: 'Physics',
        assignedClass: 'Class 10-A',
        password: 'TempPassword123!',
        role: UserRole.teacher,
      );

      expect(staffProfile, isNotNull);
      expect(staffProfile.name, equals('Test Faculty'));
      expect(staffProfile.email, equals('test.faculty@school.com'));
      expect(staffProfile.role, equals(UserRole.teacher));
      expect(staffProfile.status, equals(AccountStatus.active));
      expect(staffProfile.mustChangePassword, isTrue);
    });

    test('TEST 3: Duplicate Staff Email Rejection', () async {
      expect(
        () async => await authService.createStaffAccount(
          name: 'Duplicate Staff',
          email: 'admin@school.com',
          phone: '+91 98765 00000',
          empId: 'EMP-9902',
          designation: 'Staff Member',
          subject: 'General',
          assignedClass: 'Class 8-A',
          password: 'Password123!',
          role: UserRole.teacher,
        ),
        throwsA(predicate((e) => e.toString().toLowerCase().contains('already'))),
      );
    });

    test('TEST 4: Staff Privilege Escalation Rejection (Cannot become schoolAdmin or superAdmin)', () async {
      final staffProfile = await authService.createStaffAccount(
        name: 'Escalation Attempt Staff',
        email: 'escalation.staff@school.com',
        phone: '+91 98765 00001',
        empId: 'EMP-9903',
        designation: 'Lab Assistant',
        subject: 'Chemistry',
        assignedClass: 'Class 9-B',
        password: 'Password123!',
        role: UserRole.superAdmin, // Attempt escalation
      );

      // Role must be downgraded to teacher/staff automatically by server logic
      expect(staffProfile.role.isAdministrator, isFalse);
      expect(staffProfile.role, isNot(equals(UserRole.superAdmin)));
      expect(staffProfile.role, isNot(equals(UserRole.schoolAdmin)));
    });

    test('TEST 5: Staff Login with Email & Temporary Password', () async {
      final staffUser = await authService.signInWithEmailAndPassword(
        email: 'teacher@school.com',
        password: 'password123',
        requiresAdminPortal: false,
      );

      expect(staffUser, isNotNull);
      expect(staffUser.status, equals(AccountStatus.active));
    });

    test('TEST 6: School Admin Login Regression Test', () async {
      final adminUser = await authService.signInWithEmailAndPassword(
        email: 'admin@school.com',
        password: 'password123',
        requiresAdminPortal: true,
      );

      expect(adminUser, isNotNull);
      expect(adminUser.role.isAdministrator, isTrue);
    });
  });
}
