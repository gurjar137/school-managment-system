import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/teacher_service.dart';

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

  group('Teacher Loading, Logout & Multi-Tenant Isolation Tests', () {
    test('1. AuthNotifier mounts cleanly without CircularDependencyError on initial session', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Reading authProvider must not throw CircularDependencyError
      final auth = container.read(authProvider);
      expect(auth, isNull, reason: 'Unauthenticated initial session should yield null user cleanly');

      // Invalidating and reading again must remain stable
      container.invalidate(authProvider);
      final authAfter = container.read(authProvider);
      expect(authAfter, isNull);
    });

    test('2. Logout thoroughly clears session, local caches, and Riverpod state', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_teachers_data_6254bee9-151d-4332-8a1c-3994af7d2153', '[{"id":"t1"}]');
      await prefs.setString('cached_students_data_6254bee9-151d-4332-8a1c-3994af7d2153', '[{"id":"s1"}]');
      await prefs.setString('cached_salary_data', '[{"id":"sal1"}]');

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set simulated active user
      final notifier = container.read(authProvider.notifier);
      notifier.setUserProfile(UserProfileModel(
        id: 'test_admin_uid',
        authUserId: 'test_admin_uid',
        schoolId: kpsSchoolId,
        schoolName: 'KPS Test',
        name: 'Admin User',
        email: 'admin@school.com',
        role: UserRole.schoolAdmin,
        status: AccountStatus.active,
        designation: 'Administrator',
        createdAt: DateTime.now(),
      ));

      expect(container.read(authProvider), isNotNull);
      expect(notifier.activeProfile?.schoolId, equals(kpsSchoolId));

      // Execute logout
      await notifier.logout();

      // Verify authProvider state reset
      expect(container.read(authProvider), isNull);
      expect(notifier.activeProfile, isNull);

      // Verify all cached_* keys removed from SharedPreferences
      final remainingKeys = prefs.getKeys().where((k) => k.startsWith('cached_')).toList();
      expect(remainingKeys, isEmpty, reason: 'All cached school data must be purged on logout');
    });

    test('3. Teacher loading returns legitimate teacher records for authenticated school', () async {
      final teacherService = TeacherService();

      // Sign in as legitimate KPS teacher
      final client = Supabase.instance.client;
      final authRes = await client.auth.signInWithPassword(
        email: 'test.teacher.1a@school-test.local',
        password: 'TestPass123!',
      );
      expect(authRes.user, isNotNull);

      // Load teachers for KPS
      final kpsTeachers = await teacherService.getTeachers(schoolId: kpsSchoolId);
      expect(kpsTeachers, isNotEmpty, reason: 'KPS must load legitimate teacher records');

      final legitimateTeacher = kpsTeachers.firstWhere(
        (t) => t.email == 'test.teacher.1a@school-test.local',
        orElse: () => const TeacherModel(id: '', schoolId: '', employeeId: '', name: '', email: '', subjects: [], assignedClass: '', totalStudents: 0, avatarUrl: '', phone: '', designation: ''),
      );
      expect(legitimateTeacher.id, isNotEmpty);
      expect(legitimateTeacher.name, contains('Teacher'));
      expect(legitimateTeacher.schoolId, equals(kpsSchoolId));
      expect(legitimateTeacher.assignedClass, isNotEmpty);

      // Verify assignments derivation
      final assignments = await teacherService.getTeacherAssignments(schoolId: kpsSchoolId);
      expect(assignments, isNotEmpty);
      expect(assignments.any((a) => a.teacherId == legitimateTeacher.id), isTrue);

      // Verify no cross-tenant leakage: teachers for otherSchoolId must NOT contain KPS teachers
      final otherTeachers = await teacherService.getTeachers(schoolId: otherSchoolId);
      expect(otherTeachers.any((t) => t.schoolId == kpsSchoolId), isFalse,
          reason: 'KPS teachers must never leak into another school');
    });

    test('4. Dynamic class metric derives from distinct student classes when classes table is empty', () async {
      final studentService = StudentService();

      // Distinct classes query for KPS
      final distinctClasses = await studentService.fetchDistinctClassNames(schoolId: kpsSchoolId);
      expect(distinctClasses, isNotEmpty, reason: 'Should find student classes in KPS');
      expect(distinctClasses.length, greaterThanOrEqualTo(1));
      for (final c in distinctClasses) {
        expect(c.toLowerCase(), contains('class'));
      }
    });

    test('5. Second staff user can sign in after logout with independent role & profile', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authService = AuthService();
      final notifier = container.read(authProvider.notifier);

      // 1. Initial login as teacher
      final teacherProfile = await authService.signInWithEmailAndPassword(
        email: 'test.teacher.1a@school-test.local',
        password: 'TestPass123!',
        requiresAdminPortal: false,
      );
      notifier.setUserProfile(teacherProfile);
      expect(container.read(authProvider)?.role, equals(UserRole.teacher));
      expect(container.read(authProvider)?.schoolId, equals(kpsSchoolId));

      // 2. Logout
      await notifier.logout();
      expect(container.read(authProvider), isNull);
      expect(Supabase.instance.client.auth.currentUser, isNull);

      // 3. Second login with different credentials (e.g. admin@school.com)
      final adminProfile = await authService.signInWithEmailAndPassword(
        email: 'admin@school.com',
        password: 'password123',
        requiresAdminPortal: true,
      );
      notifier.setUserProfile(adminProfile);

      // Verify second user's profile and role resolution
      final currentAuth = container.read(authProvider);
      expect(currentAuth, isNotNull);
      expect(currentAuth?.email, equals('admin@school.com'));
      expect(currentAuth?.role, equals(UserRole.schoolAdmin));
      expect(currentAuth?.schoolId, equals(kpsSchoolId));
      expect(notifier.activeProfile?.role, equals(UserRole.schoolAdmin));
    });
  });
}
