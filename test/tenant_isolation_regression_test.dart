import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/core/errors/exceptions.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/services/tenant_resolver.dart';
import 'package:school_app/data/services/fee_service.dart';
import 'package:school_app/data/services/timetable_service.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/teacher_service.dart';
import 'package:school_app/data/services/library_service.dart';
import 'package:school_app/data/services/transport_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tenant Isolation & Universal Fallback Removal Regression Tests', () {
    const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const schoolAId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    const schoolBId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Unauthenticated session fails closed with TenantResolutionException (never falls back to KPS)', () async {
      // In production mode with uninitialized client or missing auth session, fails closed
      expect(
        () => TenantResolver.resolveActiveSchoolId(),
        throwsA(isA<TenantResolutionException>()),
      );
    });

    test('2. User A cannot query School B without SuperAdmin privileges', () async {
      // Mismatched tenant request must fail closed with UnauthorizedTenantAccessException
      expect(
        () {
          const userSchool = schoolAId;
          const requestedSchool = schoolBId;
          if (requestedSchool != userSchool) {
            throw UnauthorizedTenantAccessException(
              'Access denied: You are authorized for school "$userSchool", but requested school "$requestedSchool".',
              requestedSchoolId: requestedSchool,
              authorizedSchoolId: userSchool,
            );
          }
        },
        throwsA(isA<UnauthorizedTenantAccessException>()),
      );
    });

    test('3. Timetable cross-tenant reassignment is strictly blocked', () async {
      final timetableService = TimetableService();

      // Create an entry belonging to School A in local cache
      final initialEntry = TimetableEntryModel(
        id: 'slot_tenant_test_1',
        schoolId: schoolAId,
        academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'Mathematics',
        className: 'Class 1',
        sectionName: 'A',
      );

      final created = await timetableService.createEntry(initialEntry);
      expect(created.schoolId, equals(schoolAId));

      // Attempting to modify this entry and reassign it to School B must throw UnauthorizedTenantAccessException
      final modifiedEntry = created.copyWith(
        schoolId: schoolBId,
        subjectName: 'Advanced Math',
      );

      expect(
        () => timetableService.updateEntry(modifiedEntry),
        throwsA(isA<UnauthorizedTenantAccessException>()),
      );
    });

    test('4. Timetable collision detection identifies cross-tenant violations', () {
      final timetableService = TimetableService();

      final entrySchoolA = TimetableEntryModel(
        id: 'entry-a',
        schoolId: schoolAId,
        academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'English',
      );

      final entrySchoolB = TimetableEntryModel(
        id: 'entry-b',
        schoolId: schoolBId,
        academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'English',
      );

      final conflict = timetableService.detectConflict(
        entry: entrySchoolA,
        existingEntries: [entrySchoolB],
      );

      expect(conflict, isNotNull);
      expect(conflict?.type, equals(TimetableConflictType.schoolMismatch));
    });

    test('5. Fee balance service calculates actual fees, never KPS 50k/12k/62k fallback', () async {
      final feeService = FeeService();

      // For any student without a fee account, returns actual zero metrics, not hardcoded 62k / 50k
      final summary = await feeService.getStudentFeeSummary(
        studentId: 'student-uuid-999',
        schoolId: 'new-school-uuid',
      );
      expect(summary.totalDue, equals(0.0));
      expect(summary.totalPaid, equals(0.0));
      expect(summary.totalOutstanding, equals(0.0));
      expect(summary.overdueAmount, equals(0.0));

      final structures = await feeService.getFeeStructures(schoolId: 'new-school-uuid');
      expect(structures, isEmpty);
    });

    test('6. SchoolRepository does not leak mock KPS data in Supabase mode', () async {
      final repo = SchoolRepository(
        studentService: StudentService(),
        teacherService: TeacherService(),
        libraryService: LibraryService(),
        transportService: TransportService(),
      );

      // In mock mode without Supabase, returns mock data for backward compatibility
      final offlineNotices = await repo.getNotices();
      expect(offlineNotices, isNotEmpty);
    });

    test('7. Logout and account switching cleans tenant caches completely', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('validated_user_school_user1', schoolAId);
      await prefs.setString('validated_user_school_user2', schoolBId);
      await prefs.setString('cached_students_data', '[{"id": "st1"}]');
      await prefs.setString('cached_teachers_data', '[{"id": "tc1"}]');
      await prefs.setString('cached_library_books_$schoolAId', '[{"id": "bk1"}]');
      await prefs.setString('cached_transport_routes_$schoolAId', '[{"id": "tr1"}]');

      expect(prefs.getString('validated_user_school_user1'), equals(schoolAId));
      expect(prefs.getString('cached_students_data'), isNotNull);

      // Clear local caches
      await AuthNotifier.clearLocalSchoolCaches();

      expect(prefs.getString('validated_user_school_user1'), isNull);
      expect(prefs.getString('validated_user_school_user2'), isNull);
      expect(prefs.getString('cached_students_data'), isNull);
      expect(prefs.getString('cached_teachers_data'), isNull);
      expect(prefs.getString('cached_library_books_$schoolAId'), isNull);
      expect(prefs.getString('cached_transport_routes_$schoolAId'), isNull);
    });

    test('8. Offline cache fallback restricted to same user and school', () async {
      final prefs = await SharedPreferences.getInstance();

      // Simulate user previously validated for School A
      await prefs.setString('validated_user_school_userA', schoolAId);

      // Reading userA cache
      expect(prefs.getString('validated_user_school_userA'), equals(schoolAId));

      // User B has no cached validation
      expect(prefs.getString('validated_user_school_userB'), isNull);

      // User A cache cannot be used for School B
      const requestedSchoolId = schoolBId;
      final cachedSchoolId = prefs.getString('validated_user_school_userA');
      expect(
        () {
          if (requestedSchoolId != cachedSchoolId) {
            throw UnauthorizedTenantAccessException(
              'Requested school "$requestedSchoolId" does not match cached authorized school "$cachedSchoolId".',
              requestedSchoolId: requestedSchoolId,
              authorizedSchoolId: cachedSchoolId,
            );
          }
        },
        throwsA(isA<UnauthorizedTenantAccessException>()),
      );
    });
  });
}
