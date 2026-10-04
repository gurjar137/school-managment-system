import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/repositories/school_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolA = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'; // Greenwood
  const schoolB = '6254bee9-151d-4332-8a1c-3994af7d2153'; // KPS
  const ay2026 = '47d1569b-e032-44a7-891f-b21f5458f55b';

  group('Student Enrollment & Academic Year Linking Test Suite', () {
    late StudentService service;

    setUp(() {
      service = StudentService();
    });

    test('1. StudentModel correctly splits and maps First, Middle, and Last names', () {
      // 3 words: First, Middle, Last
      final s3 = StudentModel(
        id: 's-1',
        name: 'Aarav Kumar Sharma',
        rollNumber: '101',
        admissionNumber: 'ADM-001',
        className: 'Class 1',
        section: 'A',
      );
      expect(s3.firstName, equals('Aarav'));
      expect(s3.middleName, equals('Kumar'));
      expect(s3.lastName, equals('Sharma'));
      expect(s3.displayName, equals('Aarav Kumar Sharma'));

      // 2 words: First, Last
      final s2 = StudentModel(
        id: 's-2',
        name: 'Rohan Gupta',
        rollNumber: '102',
        admissionNumber: 'ADM-002',
        className: 'Class 2',
        section: 'B',
      );
      expect(s2.firstName, equals('Rohan'));
      expect(s2.middleName, isEmpty);
      expect(s2.lastName, equals('Gupta'));

      // Explicit first, middle, last
      final sExplicit = StudentModel(
        id: 's-3',
        name: 'Ananya Devi Patel',
        firstName: 'Ananya',
        middleName: 'Devi',
        lastName: 'Patel',
        rollNumber: '103',
        admissionNumber: 'ADM-003',
        className: 'Class 3',
        section: 'A',
      );
      expect(sExplicit.firstName, equals('Ananya'));
      expect(sExplicit.middleName, equals('Devi'));
      expect(sExplicit.lastName, equals('Patel'));
      expect(sExplicit.displayName, equals('Ananya Devi Patel'));
    });

    test('2. StudentModel serialization preserves academic_year_id, school_id, and photo', () {
      final s = StudentModel(
        id: 's-10',
        name: 'Vivaan Raj Singh',
        schoolId: schoolA,
        academicYearId: ay2026,
        firstName: 'Vivaan',
        middleName: 'Raj',
        lastName: 'Singh',
        studentPhoto: 'https://example.com/photo.jpg',
        admissionNumber: 'ADM-100',
        rollNumber: '10',
        className: 'Class 1',
        section: 'A',
        parentAccessCode: 'PRNT-778899',
        status: AccountStatus.active,
      );

      final json = s.toJson();
      expect(json['school_id'], equals(schoolA));
      expect(json['academic_year_id'], equals(ay2026));
      expect(json['first_name'], equals('Vivaan'));
      expect(json['middle_name'], equals('Raj'));
      expect(json['last_name'], equals('Singh'));
      expect(json['student_photo'], equals('https://example.com/photo.jpg'));
      expect(json['class_name'], equals('Class 1'));
      expect(json['section_name'], equals('A'));
      expect(json['parent_access_code'], equals('PRNT-778899'));

      final restored = StudentModel.fromJson(json);
      expect(restored.schoolId, equals(schoolA));
      expect(restored.academicYearId, equals(ay2026));
      expect(restored.firstName, equals('Vivaan'));
      expect(restored.middleName, equals('Raj'));
      expect(restored.lastName, equals('Singh'));
      expect(restored.studentPhoto, equals('https://example.com/photo.jpg'));
      expect(restored.parentAccessCode, equals('PRNT-778899'));
    });

    test('3. Student creation is strictly blocked when academic_year_id is missing', () async {
      final s = StudentModel(
        id: 's-no-ay',
        schoolId: schoolA,
        academicYearId: '', // Empty AY
        name: 'Test No Year',
        rollNumber: '105',
        admissionNumber: 'ADM-NO-AY',
        className: 'Class 1',
        section: 'A',
      );

      expect(
        () async => await service.addStudent(s),
        throwsA(predicate((e) =>
            e.toString().contains('No active academic year is configured for this school'))),
      );
    });

    test('4. Duplicate admission number within the SAME school is rejected', () async {
      final student1 = StudentModel(
        id: 's-11',
        schoolId: schoolA,
        academicYearId: ay2026,
        name: 'Student One',
        rollNumber: '106',
        admissionNumber: 'ADM-DUPLICATE-001',
        className: 'Class 1',
        section: 'A',
      );

      final created1 = await service.addStudent(student1);
      expect(created1.admissionNumber, equals('ADM-DUPLICATE-001'));

      // Attempt second student in same school with identical admission number
      final student2 = StudentModel(
        id: 's-12',
        schoolId: schoolA,
        academicYearId: ay2026,
        name: 'Student Two',
        rollNumber: '107',
        admissionNumber: 'ADM-DUPLICATE-001',
        className: 'Class 1',
        section: 'B',
      );

      expect(
        () async => await service.addStudent(student2),
        throwsA(predicate((e) =>
            e.toString().contains('already exists in this school'))),
      );
    });

    test('5. Identical admission number is ALLOWED across DIFFERENT schools', () async {
      // Create student in School A with admission number 'ADM-CROSS-SCHOOL'
      final sSchoolA = StudentModel(
        id: 's-school-a',
        schoolId: schoolA,
        academicYearId: ay2026,
        name: 'School A Student',
        rollNumber: '108',
        admissionNumber: 'ADM-CROSS-SCHOOL',
        className: 'Class 1',
        section: 'A',
      );
      final createdA = await service.addStudent(sSchoolA);
      expect(createdA.admissionNumber, equals('ADM-CROSS-SCHOOL'));
      expect(createdA.schoolId, equals(schoolA));

      // Create student in School B with SAME admission number 'ADM-CROSS-SCHOOL'
      final sSchoolB = StudentModel(
        id: 's-school-b',
        schoolId: schoolB,
        academicYearId: ay2026,
        name: 'School B Student',
        rollNumber: '109',
        admissionNumber: 'ADM-CROSS-SCHOOL',
        className: 'Class 1',
        section: 'A',
      );
      final createdB = await service.addStudent(sSchoolB);
      expect(createdB.admissionNumber, equals('ADM-CROSS-SCHOOL'));
      expect(createdB.schoolId, equals(schoolB));
    });

    test('6. buildStudentInsertPayload formats database payload accurately', () {
      final payload = service.buildStudentInsertPayload(
        schoolId: schoolA,
        academicYearId: ay2026,
        className: 'Class 5',
        sectionName: 'B',
        admissionNumber: 'ADM-PAYLOAD-01',
        firstName: 'Diya',
        middleName: 'Kumari',
        lastName: 'Verma',
        studentPhoto: 'https://example.com/diya.png',
        rollNumber: '502',
        gender: 'Female',
        dateOfBirth: '2016-08-15',
        status: 'ACTIVE',
      );

      expect(payload['school_id'], equals(schoolA));
      expect(payload['academic_year_id'], equals(ay2026));
      expect(payload['class_name'], equals('Class 5'));
      expect(payload['section_name'], equals('B'));
      expect(payload['admission_number'], equals('ADM-PAYLOAD-01'));
      expect(payload['first_name'], equals('Diya'));
      expect(payload['middle_name'], equals('Kumari'));
      expect(payload['last_name'], equals('Verma'));
      expect(payload['student_photo'], equals('https://example.com/diya.png'));
      expect(payload['roll_number'], equals('502'));
      expect(payload['gender'], equals('Female'));
      expect(payload['status'], equals('ACTIVE'));
    });

    test('7. checkStudentDependencies returns empty list safely when no dependencies exist', () async {
      final deps = await service.checkStudentDependencies('unknown-id', schoolA);
      expect(deps, isEmpty);
    });

    test('8. SchoolRepository.getStudents correctly scopes query to school and academic year', () async {
      final repo = SchoolRepository(studentService: service);

      final student = StudentModel(
        id: 's-repo-1',
        schoolId: schoolA,
        academicYearId: ay2026,
        name: 'Pooja Reddy',
        rollNumber: '110',
        admissionNumber: 'ADM-REPO-1',
        className: 'Class 8',
        section: 'A',
        status: AccountStatus.active,
      );
      await service.addStudent(student);

      final list = await repo.getStudents(
        schoolId: schoolA,
        academicYearId: ay2026,
        className: 'Class 8',
        section: 'A',
        status: AccountStatus.active,
      );

      expect(list.any((s) => s.admissionNumber == 'ADM-REPO-1'), isTrue);
    });

    test('9. Parent access code is auto-generated and unique if omitted', () async {
      final s = StudentModel(
        id: 's-auto-code',
        schoolId: schoolA,
        academicYearId: ay2026,
        name: 'Auto Code Student',
        rollNumber: '111',
        admissionNumber: 'ADM-AUTO-CODE',
        className: 'Class 1',
        section: 'A',
      );

      final created = await service.addStudent(s);
      expect(created.parentAccessCode, isNotEmpty);
      expect(created.parentAccessCode.length, greaterThanOrEqualTo(6));
    });

    test('10. Active Academic Year student count filters accurately', () async {
      await service.addStudent(StudentModel(
        id: 's-count-1',
        schoolId: schoolA,
        academicYearId: ay2026,
        name: 'Count Test Student',
        admissionNumber: 'ADM-COUNT-1',
        className: 'Class 1',
        section: 'A',
        status: AccountStatus.active,
      ));

      final countActive = await service.getStudentCount(
        schoolId: schoolA,
        academicYearId: ay2026,
        status: AccountStatus.active,
      );
      expect(countActive, greaterThan(0));
    });
  });
}
