import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/services/student_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Student Creation & Unique Student Number System Tests', () {
    late StudentService studentService;

    setUp(() {
      studentService = StudentService();
    });

    test('Should generate unique student number format (STU-2026-XXXX)', () {
      final studentNum1 = studentService.generateUniqueStudentNumber();
      expect(studentNum1, startsWith('STU-2026-'));
      expect(studentNum1.length, greaterThanOrEqualTo(12));
    });

    test('Should successfully add a new student and generate unique student number', () async {
      final newStudent = StudentModel(
        id: 'std_test_001',
        name: 'Test Student',
        rollNumber: '15',
        admissionNumber: '', // Empty triggers auto-generation
        className: '8',
        section: 'A',
        avatarUrl: 'https://example.com/avatar.jpg',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2012-05-15',
        gender: 'Male',
        fatherName: 'Test Father',
        fatherMobile: '+91 98765 43210',
        motherName: 'Test Mother',
        motherMobile: '+91 98765 43211',
        guardianName: 'Test Father',
        emergencyContact: '+91 98765 43210',
        parentEmail: 'parent@gmail.com',
        address: '14 Park Street',
        city: 'New Delhi',
        state: 'Delhi',
        pinCode: '110016',
        bloodGroup: 'O+',
        medicalNotes: 'None',
        importantNotes: 'None',
        totalFee: 45000.0,
        paidFee: 15000.0,
        pendingFee: 30000.0,
        feeStatus: PaymentStatus.partial,
        paymentHistory: const [],
      );

      final created = await studentService.addStudent(newStudent);

      expect(created.admissionNumber, startsWith('STU-2026-'));
      expect(created.name, equals('Test Student'));

      final allStudents = await studentService.getAllStudents();
      expect(allStudents.any((s) => s.admissionNumber == created.admissionNumber), isTrue);
    });

    test('Should prevent duplicate student number registration in same school', () async {
      const duplicateNo = 'STU-2026-DUP001';

      final student1 = StudentModel(
        id: 'std_dup_1',
        name: 'Student One',
        rollNumber: '01',
        admissionNumber: duplicateNo,
        className: '8',
        section: 'A',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2012-01-01',
        gender: 'Male',
        fatherName: 'Father',
        fatherMobile: '+91 90000 00001',
        motherName: 'Mother',
        motherMobile: '+91 90000 00002',
        guardianName: 'Father',
        emergencyContact: '+91 90000 00001',
        parentEmail: 'parent1@test.com',
        address: 'Addr',
        city: 'City',
        state: 'State',
        pinCode: '100000',
        bloodGroup: 'A+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 1000,
        paidFee: 1000,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
      );

      await studentService.addStudent(student1);

      final student2 = student1.copyWith(id: 'std_dup_2', name: 'Student Two');

      expect(
        () async => await studentService.addStudent(student2),
        throwsA(isA<Exception>()),
      );
    });

    test('Should support searching students by Student Number', () async {
      final searchedNumber = 'STU-2026-SEARCH99';

      final student = StudentModel(
        id: 'std_search_1',
        name: 'Unique Search Target',
        rollNumber: '99',
        admissionNumber: searchedNumber,
        className: '9',
        section: 'B',
        avatarUrl: '',
        attendancePercentage: 95.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: '2011-03-20',
        gender: 'Female',
        fatherName: 'Parent',
        fatherMobile: '+91 98888 88888',
        motherName: 'Parent',
        motherMobile: '+91 98888 88889',
        guardianName: 'Parent',
        emergencyContact: '+91 98888 88888',
        parentEmail: 'search@test.com',
        address: 'Addr',
        city: 'City',
        state: 'State',
        pinCode: '100000',
        bloodGroup: 'B+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 1000,
        paidFee: 1000,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
      );

      await studentService.addStudent(student);

      final results = await studentService.getAllStudents(query: searchedNumber);
      expect(results.length, equals(1));
      expect(results.first.admissionNumber, equals(searchedNumber));
    });
  });
}
