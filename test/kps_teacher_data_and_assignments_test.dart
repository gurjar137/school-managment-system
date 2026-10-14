import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/access_service.dart';
import 'package:school_app/data/services/fee_service.dart';
import 'package:school_app/data/services/school_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/teacher_service.dart';

class RealHttpOverrides extends HttpOverrides {}

class FakeStudentService extends StudentService {
  @override
  Future<int> getStudentCount({String? schoolId, String? academicYearId, String? className, String? section, AccountStatus? status}) async => 10013;
  @override
  Future<List<String>> fetchDistinctClassNames({required String schoolId}) async => [
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6',
    'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12'
  ];
  @override
  Future<Map<String, dynamic>?> fetchActiveAcademicYearRecord(String schoolId) async => {'id': 'ay_1', 'name': '2026-2027'};
  @override
  Future<List<Map<String, dynamic>>> fetchClasses(String schoolId, String academicYearId, {String academicYearName = ''}) async =>
      List.generate(12, (i) => {'id': 'c${i + 1}', 'name': 'Class ${i + 1}'});
}

class FakeSchoolService extends SchoolService {
  @override
  Future<SchoolModel> fetchSchoolProfile(String schoolIdOrCode) async => SchoolModel(
    id: '6254bee9-151d-4332-8a1c-3994af7d2153',
    schoolCode: 'KPS',
    name: 'Kamal Public School',
    logoUrl: '',
    appName: 'KPS OS',
    primaryColor: '#1E293B',
    secondaryColor: '#6366F1',
    status: AccountStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

class FakeFeeService extends FeeService {
  @override
  Future<Map<String, double>> getFeeStats({required String schoolId, String? academicYearId}) async => {
    'collected': 50000.0,
    'pending': 12000.0,
  };
}

class MockAuthNotifier extends StateNotifier<UserModel?> implements AuthNotifier {
  UserProfileModel? _profile;
  MockAuthNotifier(this._profile)
      : super(
          _profile == null
              ? null
              : UserModel(
                  id: _profile.id,
                  schoolId: _profile.schoolId,
                  name: _profile.name,
                  email: _profile.email,
                  role: _profile.role,
                  avatarUrl: _profile.avatarUrl ?? '',
                  schoolName: _profile.schoolName,
                  designation: _profile.designation,
                  assignedClass: _profile.assignedClass,
                  assignedSection: _profile.assignedSection,
                  subject: _profile.subject,
                  totalStudentsInClass: 0,
                  status: _profile.status,
                ),
        );

  @override
  UserProfileModel? get activeProfile => _profile;

  @override
  void setUserProfile(UserProfileModel profile) {
    _profile = profile;
    state = UserModel(
      id: profile.id,
      schoolId: profile.schoolId,
      name: profile.name,
      email: profile.email,
      role: profile.role,
      avatarUrl: profile.avatarUrl ?? '',
      schoolName: profile.schoolName,
      designation: profile.designation,
      assignedClass: profile.assignedClass,
      assignedSection: profile.assignedSection,
      subject: profile.subject,
      totalStudentsInClass: 0,
      status: profile.status,
    );
  }

  @override
  void login(UserRole role) {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> refreshProfile() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  group('KPS Teacher Data & Class Assignments Verification', () {
    test('1. getTeachers returns all 24 legitimate KPS teachers across Classes 1-12', () async {
      final teacherService = TeacherService();

      final teachers = await teacherService.getTeachers(schoolId: kpsSchoolId);
      expect(teachers, isNotEmpty, reason: 'KPS must have legitimate restored teachers');
      expect(teachers.length, equals(24), reason: 'KPS must have all 24 class teachers across 12 classes');

      // Verify legitimate teacher 1A
      final t1a = teachers.firstWhere((t) => t.email == 'test.teacher.1a@school-test.local');
      expect(t1a.name, equals('Test Teacher Class 1A'));
      expect(t1a.schoolId, equals(kpsSchoolId));
      expect(t1a.assignedClass, contains('1'));
      expect(t1a.assignedSection, equals('A'));
      expect(t1a.status, equals(AccountStatus.active));
      expect(t1a.role, equals(UserRole.teacher));

      // Verify all classes 1 through 12 have assigned teachers
      for (int i = 1; i <= 12; i++) {
        final classTeachers = teachers.where((t) => t.assignedClass == 'Class $i').toList();
        expect(classTeachers.length, equals(2), reason: 'Class $i must have 2 teachers (Sections A & B)');
      }
    });

    test('2. getTeachers with includeStaff=true includes both teachers and administrators', () async {
      final teacherService = TeacherService();

      final allStaff = await teacherService.getTeachers(schoolId: kpsSchoolId, includeStaff: true);
      expect(allStaff.length, equals(25), reason: '24 teachers + 1 administrator');

      final admin = allStaff.firstWhere((s) => s.email == 'admin@school.com');
      expect(admin.role, equals(UserRole.schoolAdmin));
      expect(admin.name, equals('School Administrator'));
      expect(admin.designation, equals('School Administrator'));
      expect(admin.status, equals(AccountStatus.active));
    });

    test('3. getTeacherAssignments derives all 24 class-teacher assignments matching campus structure', () async {
      final teacherService = TeacherService();

      final assignments = await teacherService.getTeacherAssignments(schoolId: kpsSchoolId);
      expect(assignments.length, equals(24), reason: 'Should derive 24 class assignments');

      final assignedClassNames = assignments.map((a) => a.className).toSet();
      for (int i = 1; i <= 12; i++) {
        expect(assignedClassNames.contains('Class $i-A'), isTrue, reason: 'Class $i-A must be assigned');
        expect(assignedClassNames.contains('Class $i-B'), isTrue, reason: 'Class $i-B must be assigned');
      }

      for (final asg in assignments) {
        expect(asg.isClassTeacher, isTrue);
        expect(asg.schoolId, equals(kpsSchoolId));
      }
    });

    test('4. Cross-school isolation: other school ID returns 0 KPS teachers or staff', () async {
      final teacherService = TeacherService();

      final otherTeachers = await teacherService.getTeachers(schoolId: otherSchoolId);
      final leakedKps = otherTeachers.where((t) => t.schoolId == kpsSchoolId).toList();
      expect(leakedKps, isEmpty, reason: 'KPS teachers must NEVER leak into another school');

      final otherAssignments = await teacherService.getTeacherAssignments(schoolId: otherSchoolId);
      final leakedAsg = otherAssignments.where((a) => a.schoolId == kpsSchoolId).toList();
      expect(leakedAsg, isEmpty, reason: 'KPS assignments must NEVER leak into another school');
    });

    test('5. Admin dashboard metrics calculates 10013 students, 24 teachers, 12 classes, and pending fees', () async {
      final adminProfile = UserProfileModel(
        id: 'b773c510-a0b4-47c7-af58-145adc883ca7',
        authUserId: 'b773c510-a0b4-47c7-af58-145adc883ca7',
        schoolId: kpsSchoolId,
        schoolName: 'Kamal Public School',
        name: 'School Administrator',
        email: 'admin@school.com',
        role: UserRole.schoolAdmin,
        status: AccountStatus.active,
        designation: 'School Administrator',
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => MockAuthNotifier(adminProfile)),
          studentServiceProvider.overrideWithValue(FakeStudentService()),
          schoolServiceProvider.overrideWithValue(FakeSchoolService()),
          feeServiceProvider.overrideWithValue(FakeFeeService()),
        ],
      );
      addTearDown(container.dispose);

      final metrics = await container.read(adminDashboardMetricsProvider.future);
      expect(metrics.totalStudents, equals(10013), reason: 'Total students must match verified campus count');
      expect(metrics.totalTeachers, equals(24), reason: 'Total teachers must be 24');
      expect(metrics.totalClasses, equals(12), reason: 'Total classes must be 12');
      expect(metrics.pendingFees, equals(12000.0), reason: 'Pending fees must reflect fee stats');
      expect(metrics.teacherDirectorySubtitle, isNot(equals('No class-teacher assignments yet')));
      expect(metrics.teacherDirectorySubtitle, contains('Class 1'));
    });

    test('6. StudentService fetchDistinctClassNames resolves 12 campus classes for KPS', () async {
      final studentService = StudentService();

      final classes = await studentService.fetchDistinctClassNames(schoolId: kpsSchoolId);
      expect(classes.length, equals(12), reason: 'KPS has 12 distinct classes (Classes 1-12)');
      expect(classes.first, equals('Class 1'));
      expect(classes.last, equals('Class 12'));
    });

    test('7. Teacher assignment updates persist and update in-memory state', () async {
      final teacherService = TeacherService();

      final teachers = await teacherService.getTeachers(schoolId: kpsSchoolId);
      final target = teachers.first;

      await teacherService.updateTeacherAssignment(
        teacherId: target.id,
        className: 'Class 1',
        sectionName: 'B',
      );

      final reloaded = await teacherService.getTeachers(schoolId: kpsSchoolId);
      final updatedTarget = reloaded.firstWhere((t) => t.id == target.id);
      expect(updatedTarget.assignedClass, equals('Class 1'));
      expect(updatedTarget.assignedSection, equals('B'));
    });

    test('8. AccessService provides authorized teacher access records for KPS', () async {
      final accessService = AccessService();

      final accessAccounts = await accessService.getTeacherAccessAccounts(schoolId: kpsSchoolId);
      expect(accessAccounts, isNotEmpty);
      expect(accessAccounts.any((a) => a.email == 'test.teacher.1a@school-test.local'), isTrue);
    });
  });
}
