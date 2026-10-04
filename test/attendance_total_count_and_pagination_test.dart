import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/core/theme/app_theme.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/repositories/attendance_repository.dart';
import 'package:school_app/data/services/attendance_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/features/attendance/attendance_screen.dart';

class FakeAuthNotifier extends AuthNotifier {
  FakeAuthNotifier(UserModel user) {
    state = user;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  StudentModel createStudent(int index, {String className = 'Class 5', String section = 'A'}) {
    final pad = index.toString().padLeft(4, '0');
    return StudentModel(
      id: 'stu-uuid-$pad',
      name: 'Student $index',
      rollNumber: index.toString(),
      admissionNumber: 'ADM-$pad',
      className: className,
      section: section,
      avatarUrl: '',
      attendancePercentage: 0.0,
      todayAttendance: AttendanceStatus.notMarked,
      dateOfBirth: '2015-01-01',
      gender: 'Male',
      fatherName: '',
      fatherMobile: '9999999999',
      motherName: '',
      motherMobile: '',
      guardianName: '',
      emergencyContact: '9999999999',
      parentEmail: '',
      address: 'Test Address',
      city: 'Delhi',
      state: 'Delhi',
      pinCode: '110001',
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
  }

  group('Server-Side Attendance TOTAL and Summary Regression Tests', () {
    test('A. Class 5-A: 422 server-side total with 50 loaded students shows TOTAL=422 and 0% initially', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 5',
        assignedSection: 'A',
        initialTotalCount: 422,
      );

      // Verify initial state
      expect(notifier.state.totalClassStudents, equals(422));
      expect(notifier.state.presentCount, equals(0));
      expect(notifier.state.absentCount, equals(0));
      expect(notifier.state.lateCount, equals(0));
      expect(notifier.state.unmarkedCount, equals(422));
      expect(notifier.state.attendancePercentage, equals(0.0));
    });

    test('B. Class with fewer than 50 students (e.g. 10 students)', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 2',
        assignedSection: 'B',
        initialTotalCount: 10,
      );

      expect(notifier.state.totalClassStudents, equals(10));
      expect(notifier.state.unmarkedCount, equals(10));

      notifier.markStudent('s1', AttendanceStatus.present);
      expect(notifier.state.presentCount, equals(1));
      expect(notifier.state.unmarkedCount, equals(9));
      expect(notifier.state.attendancePercentage, equals(10.0));
    });

    test('C. New date with all unmarked has 0% percentage and unmarked=total', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 5',
        assignedSection: 'A',
        initialTotalCount: 422,
      );

      expect(notifier.state.totalClassStudents, equals(422));
      expect(notifier.state.presentCount, equals(0));
      expect(notifier.state.unmarkedCount, equals(422));
      expect(notifier.state.attendancePercentage, equals(0.0));
    });

    test('D. Date with some saved attendance (e.g. 10 present, 2 absent, 1 late) calculates accurately', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 5',
        assignedSection: 'A',
        initialTotalCount: 422,
      );

      for (int i = 1; i <= 10; i++) {
        notifier.markStudent('stu-$i', AttendanceStatus.present);
      }
      for (int i = 11; i <= 12; i++) {
        notifier.markStudent('stu-$i', AttendanceStatus.absent);
      }
      notifier.markStudent('stu-13', AttendanceStatus.late);

      expect(notifier.state.totalClassStudents, equals(422));
      expect(notifier.state.presentCount, equals(10));
      expect(notifier.state.absentCount, equals(2));
      expect(notifier.state.lateCount, equals(1));
      expect(notifier.state.unmarkedCount, equals(422 - 10 - 2 - 1)); // 409
      expect(notifier.state.attendancePercentage, closeTo(10 / 422 * 100, 0.01));
    });

    test('E. After changing class/section updates class & resets state', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 1',
        assignedSection: 'A',
        initialTotalCount: 417,
      );

      notifier.markStudent('s1', AttendanceStatus.present);
      expect(notifier.state.presentCount, equals(1));

      notifier.setClassAndSection('Class 5', 'A');
      expect(notifier.state.selectedClass, equals('Class 5'));
      expect(notifier.state.selectedSection, equals('A'));
      expect(notifier.state.attendanceMap.isEmpty, isTrue);
    });

    test('F. After changing date clears previous date attendance', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 5',
        assignedSection: 'A',
        initialTotalCount: 422,
      );

      notifier.markStudent('s1', AttendanceStatus.present);
      expect(notifier.state.attendanceMap.isNotEmpty, isTrue);

      notifier.setDate(DateTime(2026, 9, 10));
      expect(notifier.state.selectedDate, equals(DateTime(2026, 9, 10)));
      expect(notifier.state.attendanceMap.isEmpty, isTrue);
      expect(notifier.state.presentCount, equals(0));
    });

    test('G. Search/filter does not change TOTAL', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 5',
        assignedSection: 'A',
        initialTotalCount: 422,
      );

      notifier.setSearchQuery('Student 1');
      expect(notifier.state.totalClassStudents, equals(422));

      notifier.setFilterStatus('Present');
      expect(notifier.state.totalClassStudents, equals(422));
    });
  });

  group('Widget Test: 422 Total + 50 Loaded Roster', () {
    final first50Students = List.generate(50, (i) => createStudent(i + 1));

    final teacher5A = UserModel(
      id: 'teacher-5a',
      name: 'Teacher 5A',
      email: 'teacher5a@school.com',
      avatarUrl: '',
      schoolName: 'St. Xavier Academy',
      designation: 'Class Teacher',
      role: UserRole.teacher,
      schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
      assignedClass: 'Class 5',
      assignedSection: 'A',
    );

    testWidgets('Attendance Engine shows TOTAL=422 when only 50 roster rows are loaded', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notifier = AttendanceBoardNotifier(
        attendanceService: AttendanceService(),
        studentService: StudentService(),
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 5',
        assignedSection: 'A',
        initialTotalCount: 422,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(teacher5A)),
            teacherRosterProvider.overrideWith((ref) async => first50Students),
            attendanceBoardProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AttendanceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that TOTAL displays 422
      expect(find.text('422'), findsOneWidget, reason: 'Attendance Engine must show 422 as TOTAL even when 50 students are loaded');
      // Verify that 50 is NOT the total in the metric bar
      expect(find.text('50'), findsNothing);

      // Verify that percentage shows 0% initially
      expect(find.text('0%'), findsOneWidget);

      // Verify that student cards are present
      expect(find.text('Student 1'), findsOneWidget);
    });

    testWidgets('Searching does not change TOTAL from 422', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notifier = AttendanceBoardNotifier(
        attendanceService: AttendanceService(),
        studentService: StudentService(),
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 5',
        assignedSection: 'A',
        initialTotalCount: 422,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => FakeAuthNotifier(teacher5A)),
            teacherRosterProvider.overrideWith((ref) async => first50Students),
            attendanceBoardProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AttendanceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query
      notifier.setSearchQuery('Student 1');
      await tester.pumpAndSettle();

      // TOTAL must still be 422
      expect(find.text('422'), findsOneWidget);
    });
  });
}
