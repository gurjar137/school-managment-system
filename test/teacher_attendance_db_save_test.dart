import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/repositories/attendance_repository.dart';
import 'package:school_app/data/services/attendance_service.dart';
import 'package:school_app/data/services/student_service.dart';

void main() {
  group('Teacher Attendance Database Save & Persistence Tests', () {
    test('1. Upsert attendance records uses correct fields, lowercase status, and YYYY-MM-DD date', () async {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: '12',
        assignedSection: 'F',
      );

      final realStudent = StudentModel(
        id: '56e0bade-7586-4ba4-b16b-bafec3a6aaa8',
        name: 'dharampal gurjar',
        rollNumber: '01',
        admissionNumber: 'STU-2026-00044729',
        className: '12',
        section: 'f',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.notMarked,
        dateOfBirth: '2015-01-01',
        gender: 'Male',
        fatherName: '',
        fatherMobile: '1234567890',
        motherName: '',
        motherMobile: '',
        guardianName: '',
        emergencyContact: '1234567890',
        parentEmail: '',
        address: 'Delhi',
        city: 'Delhi',
        state: 'Delhi',
        pinCode: '110054',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 0,
        paidFee: 0,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
      );

      await studentService.addStudent(realStudent);

      // Mark student as present
      notifier.markStudent(realStudent.id, AttendanceStatus.present);

      // Save attendance
      final ok = await notifier.saveAttendance(assignedStudents: [realStudent]);
      expect(ok, isTrue);

      // Verify that the record persists in attendanceService
      final dateStr = '${notifier.state.selectedDate.year.toString().padLeft(4, '0')}-${notifier.state.selectedDate.month.toString().padLeft(2, '0')}-${notifier.state.selectedDate.day.toString().padLeft(2, '0')}';
      final fetchedMap = await attendanceService.fetchAttendanceForDate(
        schoolId: realStudent.schoolId,
        attendanceDate: dateStr,
        studentIds: [realStudent.id],
      );

      expect(fetchedMap.containsKey(realStudent.id), isTrue);
      expect(fetchedMap[realStudent.id], equals(AttendanceStatus.present));
    });

    test('2. Upsert updates status when marking absent on same date', () async {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: '12',
        assignedSection: 'F',
      );

      final realStudent = StudentModel(
        id: '56e0bade-7586-4ba4-b16b-bafec3a6aaa8',
        name: 'dharampal gurjar',
        rollNumber: '01',
        admissionNumber: 'STU-2026-00044729',
        className: '12',
        section: 'f',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.notMarked,
        dateOfBirth: '2015-01-01',
        gender: 'Male',
        fatherName: '',
        fatherMobile: '1234567890',
        motherName: '',
        motherMobile: '',
        guardianName: '',
        emergencyContact: '1234567890',
        parentEmail: '',
        address: 'Delhi',
        city: 'Delhi',
        state: 'Delhi',
        pinCode: '110054',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 0,
        paidFee: 0,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
      );

      await studentService.addStudent(realStudent);

      // First save as Present
      notifier.markStudent(realStudent.id, AttendanceStatus.present);
      await notifier.saveAttendance(assignedStudents: [realStudent]);

      // Then update to Absent on same date (UPSERT update)
      notifier.markStudent(realStudent.id, AttendanceStatus.absent);
      await notifier.saveAttendance(assignedStudents: [realStudent]);

      final dateStr = '${notifier.state.selectedDate.year.toString().padLeft(4, '0')}-${notifier.state.selectedDate.month.toString().padLeft(2, '0')}-${notifier.state.selectedDate.day.toString().padLeft(2, '0')}';
      final fetchedMap = await attendanceService.fetchAttendanceForDate(
        schoolId: realStudent.schoolId,
        attendanceDate: dateStr,
        studentIds: [realStudent.id],
      );

      expect(fetchedMap[realStudent.id], equals(AttendanceStatus.absent));
    });

    test('3. Refresh loads persisted attendance records into notifier', () async {
      final attendanceService = AttendanceService();
      final studentService = StudentService();

      final realStudent = StudentModel(
        id: '56e0bade-7586-4ba4-b16b-bafec3a6aaa8',
        name: 'dharampal gurjar',
        rollNumber: '01',
        admissionNumber: 'STU-2026-00044729',
        className: '12',
        section: 'f',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.notMarked,
        dateOfBirth: '2015-01-01',
        gender: 'Male',
        fatherName: '',
        fatherMobile: '1234567890',
        motherName: '',
        motherMobile: '',
        guardianName: '',
        emergencyContact: '1234567890',
        parentEmail: '',
        address: 'Delhi',
        city: 'Delhi',
        state: 'Delhi',
        pinCode: '110054',
        bloodGroup: 'O+',
        medicalNotes: '',
        importantNotes: '',
        totalFee: 0,
        paidFee: 0,
        pendingFee: 0,
        feeStatus: PaymentStatus.paid,
        paymentHistory: const [],
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: '47d1569b-e032-44a7-891f-b21f5458f55b',
      );

      final dateStr = '2026-09-04';
      await attendanceService.upsertAttendanceRecords([
        {
          'student_id': realStudent.id,
          'school_id': realStudent.schoolId,
          'academic_year_id': realStudent.academicYearId,
          'attendance_date': dateStr,
          'status': 'late',
        }
      ]);

      // Fresh notifier instance (simulating fresh screen open / refresh)
      final freshNotifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: '12',
        assignedSection: 'F',
      );
      freshNotifier.setDate(DateTime.parse(dateStr));

      // Initially attendanceMap is empty
      expect(freshNotifier.state.attendanceMap.isEmpty, isTrue);

      // Load from database
      await freshNotifier.loadAttendanceFromDatabase([realStudent]);

      // Persisted attendance status is now loaded
      expect(freshNotifier.state.attendanceMap[realStudent.id], equals(AttendanceStatus.late));
    });
  });
}
