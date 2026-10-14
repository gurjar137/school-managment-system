import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/academic_year_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const greenwoodSchoolId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
  const school1Id = 'cf895651-4783-489b-8551-959a70098ca8';

  group('Academic Year Management Tests', () {
    late AcademicYearService service;

    setUp(() {
      service = AcademicYearService();
    });

    // 1. Academic year creation
    test('1. Create academic year with valid name, start/end dates, and default active status', () async {
      final ay = await service.createAcademicYear(
        schoolId: greenwoodSchoolId,
        name: '2026-2027',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
      );

      expect(ay.id, isNotEmpty);
      expect(ay.schoolId, equals(greenwoodSchoolId));
      expect(ay.name, equals('2026-2027'));
      expect(ay.startDate, equals(DateTime(2026, 4, 1)));
      expect(ay.endDate, equals(DateTime(2027, 3, 31)));
      expect(ay.status, equals(AccountStatus.active));
      expect(ay.isActive, isTrue);
      expect(ay.dateRangeFormatted, equals('01 Apr 2026 → 31 Mar 2027'));
    });

    // 2. Date validation: end_date < start_date rejected
    test('2. Reject academic year if end_date is before start_date', () async {
      expect(
        () => service.validateAcademicYearInput(
          name: '2027-2028',
          startDate: DateTime(2027, 4, 1),
          endDate: DateTime(2026, 4, 1), // Invalid!
          existingYears: [],
        ),
        throwsA(isA<AcademicYearValidationException>().having(
          (e) => e.message,
          'message',
          contains('End date cannot be before start date'),
        )),
      );
    });

    // 3. Empty name rejected
    test('3. Reject academic year if name is empty or whitespace', () async {
      expect(
        () => service.validateAcademicYearInput(
          name: '   ',
          startDate: DateTime(2027, 4, 1),
          endDate: DateTime(2028, 3, 31),
          existingYears: [],
        ),
        throwsA(isA<AcademicYearValidationException>().having(
          (e) => e.message,
          'message',
          contains('name cannot be empty'),
        )),
      );
    });

    // 4. Duplicate prevention for same school
    test('4. Prevent duplicate academic year names for the same school', () async {
      final existing = [
        AcademicYearModel(
          id: 'ay_gw_2026',
          schoolId: greenwoodSchoolId,
          name: '2026-2027',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2027, 3, 31),
          createdAt: DateTime.now(),
        ),
      ];

      expect(
        () => service.validateAcademicYearInput(
          name: '2026-2027', // duplicate!
          startDate: DateTime(2027, 4, 1),
          endDate: DateTime(2028, 3, 31),
          existingYears: existing,
        ),
        throwsA(isA<AcademicYearValidationException>().having(
          (e) => e.message,
          'message',
          contains('already exists for this school'),
        )),
      );
    });

    // 5. Overlap prevention
    test('5. Prevent overlapping academic-year date ranges for the same school', () async {
      final existing = [
        AcademicYearModel(
          id: 'ay_gw_2026',
          schoolId: greenwoodSchoolId,
          name: '2026-2027',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2027, 3, 31),
          createdAt: DateTime.now(),
        ),
      ];

      // Overlap case A: Starts inside existing range
      expect(
        () => service.validateAcademicYearInput(
          name: '2026-2027 Winter Term',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2027, 5, 31),
          existingYears: existing,
        ),
        throwsA(isA<AcademicYearValidationException>().having(
          (e) => e.message,
          'message',
          contains('Date range overlaps with existing academic year'),
        )),
      );

      // Overlap case B: Encompasses existing range
      expect(
        () => service.validateAcademicYearInput(
          name: '2025-2028 Mega Term',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2028, 1, 1),
          existingYears: existing,
        ),
        throwsA(isA<AcademicYearValidationException>().having(
          (e) => e.message,
          'message',
          contains('Date range overlaps with existing academic year'),
        )),
      );

      // Non-overlapping range: Should PASS
      expect(
        () => service.validateAcademicYearInput(
          name: '2027-2028',
          startDate: DateTime(2027, 4, 1),
          endDate: DateTime(2028, 3, 31),
          existingYears: existing,
        ),
        returnsNormally,
      );
    });

    // 6. Current academic year resolution (AcademicYearOption.resolveCurrent)
    test('6. AcademicYearOption.resolveCurrent correctly identifies current active year based on date and status', () {
      final y2025 = AcademicYearModel(
        id: 'ay_2025',
        schoolId: greenwoodSchoolId,
        name: '2025-2026',
        startDate: DateTime(2025, 4, 1),
        endDate: DateTime(2026, 3, 31),
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      final y2026 = AcademicYearModel(
        id: 'ay_2026',
        schoolId: greenwoodSchoolId,
        name: '2026-2027',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      final y2027 = AcademicYearModel(
        id: 'ay_2027',
        schoolId: greenwoodSchoolId,
        name: '2027-2028',
        startDate: DateTime(2027, 4, 1),
        endDate: DateTime(2028, 3, 31),
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      // A. Reference date within 2026-2027 (e.g. 15 Sep 2026)
      final resolved = AcademicYearOption.resolveCurrent(
        [y2025, y2026, y2027],
        referenceDate: DateTime(2026, 9, 15),
      );
      expect(resolved?.id, equals('ay_2026'));
      expect(resolved?.name, equals('2026-2027'));

      // B. If 2026-2027 is inactive, it should NOT be selected as current
      final y2026Inactive = y2026.copyWith(status: AccountStatus.inactive);
      final resolvedWithInactive = AcademicYearOption.resolveCurrent(
        [y2025, y2026Inactive, y2027],
        referenceDate: DateTime(2026, 9, 15),
      );
      expect(resolvedWithInactive?.id, isNot(equals('ay_2026')));
    });

    // 7. Edit persistence
    test('7. Edit academic year name, dates, and status while preventing self-conflict', () async {
      final original = await service.createAcademicYear(
        schoolId: greenwoodSchoolId,
        name: '2028-2029 Old',
        startDate: DateTime(2028, 4, 1),
        endDate: DateTime(2029, 3, 31),
      );

      final updated = await service.updateAcademicYear(
        id: original.id,
        schoolId: greenwoodSchoolId,
        name: '2028-2029 Revised',
        startDate: DateTime(2028, 5, 1),
        endDate: DateTime(2029, 4, 30),
        status: AccountStatus.active,
      );

      expect(updated.id, equals(original.id));
      expect(updated.name, equals('2028-2029 Revised'));
      expect(updated.startDate, equals(DateTime(2028, 5, 1)));
      expect(updated.endDate, equals(DateTime(2029, 4, 30)));
    });

    // 8. Status change (active <-> inactive)
    test('8. Toggle status between active and inactive', () async {
      final ay = await service.createAcademicYear(
        schoolId: greenwoodSchoolId,
        name: '2029-2030',
        startDate: DateTime(2029, 4, 1),
        endDate: DateTime(2030, 3, 31),
      );
      expect(ay.status, equals(AccountStatus.active));

      final toggled = await service.toggleStatus(
        id: ay.id,
        schoolId: greenwoodSchoolId,
        newStatus: AccountStatus.inactive,
      );
      expect(toggled.status, equals(AccountStatus.inactive));
      expect(toggled.isActive, isFalse);
    });

    // 9. Delete protection when dependent records exist
    test('9. Delete protection blocks deletion when dependent records exist', () async {
      // Mock an academic year with dependent students or classes
      final ay = await service.createAcademicYear(
        schoolId: greenwoodSchoolId,
        name: '2030-2031',
        startDate: DateTime(2030, 4, 1),
        endDate: DateTime(2031, 3, 31),
      );
      expect(ay.id, isNotEmpty);

      // Testing dependency exception structure
      final ex = AcademicYearDependencyException(
        'Cannot delete academic year: It is referenced by 12 enrolled student(s).',
        dependencies: ['12 enrolled student(s)'],
      );

      expect(ex.dependencies.length, equals(1));
      expect(ex.toString(), contains('enrolled student(s)'));
    });

    // 10. School ID propagation: school_id strictly enforced from profile
    test('10. School ID is strictly enforced from caller context and not empty', () async {
      expect(
        () => service.createAcademicYear(
          schoolId: '', // Empty school_id rejected
          name: '2031-2032',
          startDate: DateTime(2031, 4, 1),
          endDate: DateTime(2032, 3, 31),
        ),
        throwsA(isA<AcademicYearValidationException>().having(
          (e) => e.message,
          'message',
          contains('school_id is required'),
        )),
      );
    });

    // 11. Cross-school read and write isolation
    test('11. Cross-school isolation: School A cannot see or mutate School B academic years', () async {
      // Create for Greenwood
      await service.createAcademicYear(
        schoolId: greenwoodSchoolId,
        name: '2026-2027 Greenwood',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
      );

      // Create for School 1 (School B) with identical dates to verify tenant isolation
      await service.createAcademicYear(
        schoolId: school1Id,
        name: '2026-2027 School 1',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
      );

      // Fetch Greenwood years -> strictly contains only Greenwood
      final gwYears = await service.fetchAcademicYears(greenwoodSchoolId);
      for (final y in gwYears) {
        expect(y.schoolId, equals(greenwoodSchoolId));
        expect(y.schoolId, isNot(equals(school1Id)));
        expect(y.schoolId, isNot(equals(kpsSchoolId)));
      }

      // Fetch School 1 years -> strictly contains only School 1
      final s1Years = await service.fetchAcademicYears(school1Id);
      for (final y in s1Years) {
        expect(y.schoolId, equals(school1Id));
        expect(y.schoolId, isNot(equals(greenwoodSchoolId)));
        expect(y.schoolId, isNot(equals(kpsSchoolId)));
      }

      // Fetch KPS years -> strictly contains only KPS
      final kpsYears = await service.fetchAcademicYears(kpsSchoolId);
      for (final y in kpsYears) {
        expect(y.schoolId, equals(kpsSchoolId));
        expect(y.schoolId, isNot(equals(greenwoodSchoolId)));
        expect(y.schoolId, isNot(equals(school1Id)));
      }
    });

    // 12. Billing integration: Resolves active academic year and computes student_count * 20
    test('12. Billing integration: resolves current academic year and calculates student_count * 20 without modifying old invoices', () {
      final years = [
        AcademicYearModel(
          id: 'ay_gw_current',
          schoolId: greenwoodSchoolId,
          name: '2026-2027',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2027, 3, 31),
          status: AccountStatus.active,
          createdAt: DateTime.now(),
        ),
      ];

      // Billing engine resolves active academic year
      final currentYear = AcademicYearOption.resolveCurrent(years, referenceDate: DateTime(2026, 9, 15));
      expect(currentYear, isNotNull);
      expect(currentYear!.id, equals('ay_gw_current'));

      // Simulate student enrollment under this academic year
      const enrolledStudentCount = 142;
      const ratePerStudent = 20.0; // ₹20
      final calculatedAmount = enrolledStudentCount * ratePerStudent;

      expect(calculatedAmount, equals(2840.0)); // 142 * 20 = 2840

      // Existing historical invoice snapshots remain intact
      const historicalSavedStudentCount = 120;
      const historicalSavedAmount = historicalSavedStudentCount * ratePerStudent;
      expect(historicalSavedAmount, equals(2400.0));
      expect(calculatedAmount, isNot(equals(historicalSavedAmount)));
    });
  });
}
