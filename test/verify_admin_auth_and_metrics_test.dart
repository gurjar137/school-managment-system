import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/teacher_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
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

  test('Verify Admin Auth Session, Live Student & Teacher RLS Queries, and Dashboard Metrics', () async {
    final client = Supabase.instance.client;
    final authService = AuthService();
    final studentService = StudentService();
    final teacherService = TeacherService();
    const schoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const adminEmail = 'dharampalgujar5021@gmail.com';
    const adminPassword = 'AdminPassword123!';

    // 1. Initial State Check: AuthNotifier should NOT default to MockData when Supabase is configured
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialAuth = container.read(authProvider);
    expect(initialAuth, isNull, reason: 'AuthNotifier should NOT have mock data on startup when Supabase is configured');

    // 2. Sign in with real registered Primary School Admin credentials
    final userProfile = await authService.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
      requiresAdminPortal: true,
    );

    // Verify currentUser is authenticated with real session
    expect(client.auth.currentUser, isNotNull);
    expect(client.auth.currentUser?.email, equals(adminEmail));
    expect(client.auth.currentUser?.id, equals('ce32bc1b-fa13-42ca-b98a-bb894fe386a5'));
    expect(userProfile.role, equals(UserRole.schoolAdmin));
    expect(userProfile.schoolId, equals(schoolId));

    // Update AuthNotifier with the authenticated user profile
    container.read(authProvider.notifier).setUserProfile(userProfile);
    expect(container.read(authProvider)?.email, equals(adminEmail));

    // 3. Verify RPC Helper functions evaluate correctly using RLS
    final rpcSchoolId = await client.rpc('get_user_school_id');
    expect(rpcSchoolId, equals(schoolId));

    final rpcRole = await client.rpc('get_user_role');
    expect(rpcRole, equals('school_admin'));

    // 4. Query live students via StudentService (verifying live DB RLS read without hardcoded mocks)
    final students = await studentService.getAllStudents(schoolId: schoolId);
    expect(students.length, equals(5), reason: 'Should return all 5 live students from Supabase DB');

    final admNumbers = students.map((s) => s.admissionNumber).toSet();
    expect(admNumbers, containsAll([
      'STU-2026-00014252',
      'STU-2026-00021029',
      'STU-2026-00031873',
      'STU-2026-00044729',
      'STU-2026-00051036',
    ]));

    // 5. Query live teachers via TeacherService
    final teachers = await teacherService.getTeachers(schoolId: schoolId);
    expect(teachers.length, equals(2), reason: 'Should return the 2 live teachers (ramesh, ram) from Supabase DB');
    final teacherNames = teachers.map((t) => t.name.toLowerCase()).toSet();
    expect(teacherNames, containsAll(['ramesh', 'ram']));

    // 6. Test adminDashboardMetricsProvider dynamic derivation
    final metrics = await container.read(adminDashboardMetricsProvider.future);
    expect(metrics.totalStudents, equals(5), reason: 'Dashboard metrics should dynamically show exactly 5 students');
    expect(metrics.totalTeachers, equals(2), reason: 'Dashboard metrics should show exactly 2 teachers');
    expect(metrics.totalClasses, equals(4), reason: 'Derived classes count from distinct student classes (3, Class 1, 12, 5)');

    print('\n==========================================================');
    print('ALL VERIFICATION CHECKS PASSED:');
    print('  - Authenticated currentUser ID: ${client.auth.currentUser?.id}');
    print('  - Authenticated email: ${client.auth.currentUser?.email}');
    print('  - get_user_school_id(): $rpcSchoolId');
    print('  - get_user_role(): $rpcRole');
    print('  - Live Students count: ${students.length}');
    for (final s in students) {
      print('    * ${s.admissionNumber} - ${s.name} (Class ${s.className}-${s.section})');
    }
    print('  - Live Teachers count: ${teachers.length}');
    for (final t in teachers) {
      print('    * ${t.name} (${t.assignedClass})');
    }
    print('  - Dashboard Metrics:');
    print('    * Total Students: ${metrics.totalStudents}');
    print('    * Total Teachers: ${metrics.totalTeachers}');
    print('    * Total Classes:  ${metrics.totalClasses}');
    print('==========================================================\n');
  });
}
