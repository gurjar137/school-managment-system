import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/core/utils/teacher_assignment_parser.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/repositories/attendance_repository.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/attendance_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/features/attendance/attendance_screen.dart';

void main() {
  group('Teacher Attendance Locked to Assigned Class + Section Tests', () {
    test('1. Teacher Assignment Parser correctly extracts class 12 and section F', () {
      final parser1 = TeacherAssignmentParser(
        assignedClass: '12 - f',
        assignedSection: 'f',
      );
      expect(parser1.rawClass, equals('12'));
      expect(parser1.rawSection, equals('f'));
      expect(parser1.normalizedClass, equals('12'));
      expect(parser1.normalizedSection, equals('f'));

      final parser2 = TeacherAssignmentParser(
        assignedClass: 'Class 12',
        assignedSection: 'Section F',
      );
      expect(parser2.normalizedClass, equals('12'));
      expect(parser2.normalizedSection, equals('f'));
    });

    test('2. Attendance query returns ONLY matching 12-F students and excludes 12-A and 11-F', () async {
      final studentService = StudentService();
      final repo = SchoolRepository(studentService: studentService);

      final student12F = StudentModel(
        id: 'att_stu_12f',
        name: 'Ramesh 12F Student',
        rollNumber: '01',
        admissionNumber: '',
        className: '12',
        section: 'F',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.notMarked,
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
        id: 'att_stu_12a',
        name: 'Other 12A Student',
        admissionNumber: '',
        className: '12',
        section: 'A',
      );

      final student11F = student12F.copyWith(
        id: 'att_stu_11f',
        name: 'Other 11F Student',
        admissionNumber: '',
        className: '11',
        section: 'F',
      );

      await studentService.addStudent(student12F);
      await studentService.addStudent(student12A);
      await studentService.addStudent(student11F);

      // Teacher assigned to 12 - f
      final attendanceStudents = await repo.getStudents(
        teacherAssignedClass: '12',
        teacherAssignedSection: 'F',
      );

      expect(attendanceStudents.length, equals(1));
      expect(attendanceStudents.first.name, equals('Ramesh 12F Student'));
      expect(attendanceStudents.first.className, equals('12'));
      expect(attendanceStudents.first.section, equals('F'));

      // Cross-class verification: 12-A and 11-F must NOT appear
      final names = attendanceStudents.map((s) => s.name).toList();
      expect(names.contains('Other 12A Student'), isFalse);
      expect(names.contains('Other 11F Student'), isFalse);
    });

    test('3. AttendanceBoardNotifier is locked to teacher assigned class and section', () {
      final notifier = AttendanceBoardNotifier(
        attendanceService: AttendanceService(),
        studentService: StudentService(),
        repo: MockAttendanceRepository(),
        assignedClass: '12',
        assignedSection: 'F',
      );

      expect(notifier.state.selectedClass, equals('12'));
      expect(notifier.state.selectedSection, equals('F'));

      // Attempting to change class/section must be a no-op (locked)
      notifier.setClassAndSection('8', 'A');
      expect(notifier.state.selectedClass, equals('12'));
      expect(notifier.state.selectedSection, equals('F'));
    });

    test('4. Attendance save restriction only saves attendance for assigned students', () async {
      final studentService = StudentService();
      final mockRepo = MockAttendanceRepository();
      final notifier = AttendanceBoardNotifier(
        attendanceService: AttendanceService(),
        studentService: studentService,
        repo: mockRepo,
        assignedClass: '12',
        assignedSection: 'F',
      );

      final student12F = StudentModel(
        id: 'att_save_12f',
        name: 'Assigned 12F',
        rollNumber: '01',
        admissionNumber: 'STU-ATT-001',
        className: '12',
        section: 'F',
        avatarUrl: '',
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.notMarked,
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

      await studentService.addStudent(student12F);

      notifier.markStudent('att_save_12f', AttendanceStatus.present);
      // Attempting to inject a student outside assigned class
      notifier.markStudent('foreign_student_id', AttendanceStatus.present);

      final success = await notifier.saveAttendance(assignedStudents: [student12F]);
      expect(success, isTrue);

      // Verify foreign student was excluded from saved map
      expect(notifier.state.attendanceMap.containsKey('att_save_12f'), isTrue);
      expect(notifier.state.attendanceMap.containsKey('foreign_student_id'), isFalse);
    });

    testWidgets('5. AttendanceScreen UI: Shows read-only Class 12, Section F and NO DropdownButton', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final teacherUser = UserModel(
        id: 'teacher_ramesh_test',
        name: 'Ramesh Teacher',
        email: 'ramesh@school.com',
        role: UserRole.teacher,
        avatarUrl: '',
        schoolName: 'Greenwood International School',
        designation: 'Faculty',
        assignedClass: '12 - f',
        assignedSection: 'F',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final authNotifier = AuthNotifier();
              authNotifier.state = teacherUser;
              return authNotifier;
            }),
            teacherRosterProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: AttendanceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify NO DropdownButton is present on the screen
      expect(find.byType(DropdownButton<String>), findsNothing);

      // Verify read-only Class 12 and Section F are displayed
      expect(find.text('Class 12'), findsOneWidget);
      expect(find.text('Section F'), findsOneWidget);

      // Verify zero students empty state
      expect(find.text('No Students Added Yet'), findsOneWidget);
      expect(find.text('0 Students enrolled in this assigned Class & Section.'), findsOneWidget);
    });
  });
}
