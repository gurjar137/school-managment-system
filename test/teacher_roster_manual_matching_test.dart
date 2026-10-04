import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/utils/teacher_assignment_parser.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/student_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Teacher Assignment Parser & Text Normalization Tests', () {
    test('1. Match Teacher (12 - f) with Student (class_name="12", section_name="F")', () {
      final parser = TeacherAssignmentParser(assignedClass: '12 - f');
      expect(parser.normalizedClass, equals('12'));
      expect(parser.normalizedSection, equals('f'));

      final student = StudentModel(
        id: 'stu_1',
        name: 'John Doe',
        rollNumber: '1',
        admissionNumber: 'STU-2026-0001',
        className: '12',
        section: 'F',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2008-01-01',
        gender: 'Male',
        fatherName: 'Father',
        fatherMobile: '1234567890',
        motherName: 'Mother',
        motherMobile: '1234567890',
        guardianName: 'Guardian',
        emergencyContact: '1234567890',
        parentEmail: 'parent@test.com',
        address: 'Test Address',
        city: 'City',
        state: 'State',
        pinCode: '110001',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 1000,
        paidFee: 1000,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
      );

      expect(parser.matchesStudent(student), isTrue);
    });

    test('2. Teacher (12 - f) with Student (class_name="12", section_name="A") -> DO NOT SHOW', () {
      final parser = TeacherAssignmentParser(assignedClass: '12 - f');
      final student = StudentModel(
        id: 'stu_2',
        name: 'Section A Student',
        rollNumber: '2',
        admissionNumber: 'STU-2026-0002',
        className: '12',
        section: 'A',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2008-01-01',
        gender: 'Female',
        fatherName: 'Father',
        fatherMobile: '1234567890',
        motherName: 'Mother',
        motherMobile: '1234567890',
        guardianName: 'Guardian',
        emergencyContact: '1234567890',
        parentEmail: 'parent@test.com',
        address: 'Test Address',
        city: 'City',
        state: 'State',
        pinCode: '110001',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 1000,
        paidFee: 1000,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
      );

      expect(parser.matchesStudent(student), isFalse);
    });

    test('3. Teacher (12 - f) with Student (class_name="11", section_name="F") -> DO NOT SHOW', () {
      final parser = TeacherAssignmentParser(assignedClass: '12 - f');
      final student = StudentModel(
        id: 'stu_3',
        name: 'Class 11 Student',
        rollNumber: '3',
        admissionNumber: 'STU-2026-0003',
        className: '11',
        section: 'F',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2008-01-01',
        gender: 'Female',
        fatherName: 'Father',
        fatherMobile: '1234567890',
        motherName: 'Mother',
        motherMobile: '1234567890',
        guardianName: 'Guardian',
        emergencyContact: '1234567890',
        parentEmail: 'parent@test.com',
        address: 'Test Address',
        city: 'City',
        state: 'State',
        pinCode: '110001',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 1000,
        paidFee: 1000,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
      );

      expect(parser.matchesStudent(student), isFalse);
    });

    test('4. Handles various formatting: "Class 12 - Section F", "12-F", " 12 ", " f "', () {
      final parser1 = TeacherAssignmentParser(assignedClass: 'Class 12 - Section F');
      expect(parser1.normalizedClass, equals('12'));
      expect(parser1.normalizedSection, equals('f'));

      final parser2 = TeacherAssignmentParser(assignedClass: '12', assignedSection: 'F');
      expect(parser2.normalizedClass, equals('12'));
      expect(parser2.normalizedSection, equals('f'));

      final parser3 = TeacherAssignmentParser(assignedClass: '  12-F  ');
      expect(parser3.normalizedClass, equals('12'));
      expect(parser3.normalizedSection, equals('f'));
    });

    test('5. Enforces School ID isolation', () {
      final parser = TeacherAssignmentParser(assignedClass: '12 - f');
      final studentOtherSchool = StudentModel(
        id: 'stu_other',
        name: 'Other School Student',
        rollNumber: '4',
        admissionNumber: 'STU-2026-0004',
        className: '12',
        section: 'F',
        schoolId: 'school-uuid-9999',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2008-01-01',
        gender: 'Male',
        fatherName: 'Father',
        fatherMobile: '1234567890',
        motherName: 'Mother',
        motherMobile: '1234567890',
        guardianName: 'Guardian',
        emergencyContact: '1234567890',
        parentEmail: 'parent@test.com',
        address: 'Test Address',
        city: 'City',
        state: 'State',
        pinCode: '110001',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 1000,
        paidFee: 1000,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
      );

      expect(
        parser.matchesStudent(studentOtherSchool, expectedSchoolId: 'school-uuid-1111'),
        isFalse,
      );
    });

    test('6. SchoolRepository.getStudents returns only matching 12-F students', () async {
      final studentService = StudentService();
      final repo = SchoolRepository(studentService: studentService);

      final student12F = StudentModel(
        id: 'stu_match_12f',
        name: '12-F Student',
        rollNumber: '12',
        admissionNumber: '',
        className: '12',
        section: 'F',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2008-01-01',
        gender: 'Male',
        fatherName: 'Father',
        fatherMobile: '1234567890',
        motherName: 'Mother',
        motherMobile: '1234567890',
        guardianName: 'Guardian',
        emergencyContact: '1234567890',
        parentEmail: 'parent@test.com',
        address: 'Address',
        city: 'City',
        state: 'State',
        pinCode: '110001',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 1000,
        paidFee: 1000,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
      );

      final student12A = student12F.copyWith(
        id: 'stu_nomatch_12a',
        name: '12-A Student',
        admissionNumber: '',
        className: '12',
        section: 'A',
      );

      final student10F = student12F.copyWith(
        id: 'stu_nomatch_10f',
        name: '10-F Student',
        admissionNumber: '',
        className: '10',
        section: 'F',
      );

      await studentService.addStudent(student12F);
      await studentService.addStudent(student12A);
      await studentService.addStudent(student10F);

      final roster12F = await repo.getStudents(
        teacherAssignedClass: '12 - f',
      );

      expect(roster12F.length, equals(1));
      expect(roster12F.first.name, equals('12-F Student'));
      expect(roster12F.first.className, equals('12'));
      expect(roster12F.first.section, equals('F'));

      // Check another teacher query (e.g. 12-A)
      final roster12A = await repo.getStudents(
        teacherAssignedClass: '12',
        teacherAssignedSection: 'A',
      );
      expect(roster12A.length, equals(1));
      expect(roster12A.first.name, equals('12-A Student'));

      // Check non-existent class
      final emptyRoster = await repo.getStudents(
        teacherAssignedClass: '9 - B',
      );
      expect(emptyRoster, isEmpty);
    });
  });
}
