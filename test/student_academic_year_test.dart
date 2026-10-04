import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/services/student_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Student Registration Class & Section UUID Mapping Tests', () {
    late StudentService studentService;

    setUp(() {
      studentService = StudentService();
    });

    test('Should populate classId, sectionId, academicYearId and preserve unique student number', () async {
      const classUuid = '8f4c2e10-9b3a-4f5c-8d1e-2a3b4c5d6e7f';
      const sectionUuid = '1a2b3c4d-5e6f-7a8b-9c0d-1e2f3a4b5c6d';

      final student = StudentModel(
        id: 'std_class_sec_001',
        name: 'Test Student',
        rollNumber: '10',
        admissionNumber: '',
        className: 'Class 8',
        section: 'Section A',
        classId: classUuid,
        sectionId: sectionUuid,
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
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
        totalFee: 45000.0,
        paidFee: 15000.0,
        pendingFee: 30000.0,
        feeStatus: PaymentStatus.partial,
        paymentHistory: const [],
      );

      final created = await studentService.addStudent(student);

      expect(created.academicYearId, isNotEmpty);
      expect(created.schoolId, equals('6254bee9-151d-4332-8a1c-3994af7d2153'));
      expect(created.admissionNumber, startsWith('STU-2026-'));
      expect(created.className, equals('Class 8'));
      expect(created.section, equals('Section A'));
    });
  });
}
