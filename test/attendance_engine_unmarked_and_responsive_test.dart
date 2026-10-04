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

  StudentModel createTestStudent({
    required String id,
    required String name,
    required String rollNumber,
  }) {
    return StudentModel(
      id: id,
      name: name,
      rollNumber: rollNumber,
      admissionNumber: 'ADM-$rollNumber',
      className: 'Class 1',
      section: 'A',
      avatarUrl: '',
      attendancePercentage: 0.0,
      todayAttendance: AttendanceStatus.notMarked,
      dateOfBirth: '2018-01-01',
      gender: 'Male',
      fatherName: '',
      fatherMobile: '9999999999',
      motherName: '',
      motherMobile: '',
      guardianName: '',
      emergencyContact: '9999999999',
      parentEmail: '',
      address: 'Test Address',
      city: 'Test City',
      state: 'Test State',
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

  group('Teacher Attendance Default State & Save Filtering Tests', () {
    test('1. Students with no DB record are initialized as notMarked, not present', () async {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 1',
        assignedSection: 'A',
      );

      final student1 = createTestStudent(id: 's1', name: 'Student One', rollNumber: '01');
      final student2 = createTestStudent(id: 's2', name: 'Student Two', rollNumber: '02');

      await notifier.loadAttendanceFromDatabase([student1, student2]);

      expect(notifier.state.attendanceMap['s1'], equals(AttendanceStatus.notMarked));
      expect(notifier.state.attendanceMap['s2'], equals(AttendanceStatus.notMarked));
    });

    test('2. Tapping status marks student, and tapping same status toggles back to notMarked', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 1',
        assignedSection: 'A',
      );

      notifier.markStudent('s1', AttendanceStatus.present);
      expect(notifier.state.attendanceMap['s1'], equals(AttendanceStatus.present));

      // Tapping PRESENT again toggles it to notMarked
      notifier.markStudent('s1', AttendanceStatus.present);
      expect(notifier.state.attendanceMap['s1'], equals(AttendanceStatus.notMarked));

      // Tapping ABSENT marks it absent
      notifier.markStudent('s1', AttendanceStatus.absent);
      expect(notifier.state.attendanceMap['s1'], equals(AttendanceStatus.absent));
    });

    test('3. Save attendance only writes marked students to DB; unmarked students are omitted', () async {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 1',
        assignedSection: 'A',
      );

      final s1 = createTestStudent(id: 's1', name: 'Student 1', rollNumber: '01');
      final s2 = createTestStudent(id: 's2', name: 'Student 2', rollNumber: '02');
      final s3 = createTestStudent(id: 's3', name: 'Student 3', rollNumber: '03');

      await studentService.addStudent(s1);
      await studentService.addStudent(s2);
      await studentService.addStudent(s3);

      // Explicitly mark only s1 as present and s2 as absent. s3 remains unmarked.
      notifier.markStudent('s1', AttendanceStatus.present);
      notifier.markStudent('s2', AttendanceStatus.absent);

      final ok = await notifier.saveAttendance(assignedStudents: [s1, s2, s3]);
      expect(ok, isTrue);

      final dateStr = '${notifier.state.selectedDate.year.toString().padLeft(4, '0')}-${notifier.state.selectedDate.month.toString().padLeft(2, '0')}-${notifier.state.selectedDate.day.toString().padLeft(2, '0')}';
      final fetchedMap = await attendanceService.fetchAttendanceForDate(
        schoolId: s1.schoolId,
        attendanceDate: dateStr,
        studentIds: ['s1', 's2', 's3'],
      );

      expect(fetchedMap.containsKey('s1'), isTrue, reason: 's1 was marked present');
      expect(fetchedMap['s1'], equals(AttendanceStatus.present));

      expect(fetchedMap.containsKey('s2'), isTrue, reason: 's2 was marked absent');
      expect(fetchedMap['s2'], equals(AttendanceStatus.absent));

      expect(fetchedMap.containsKey('s3'), isFalse, reason: 'Unmarked student s3 must NOT be saved to database');
    });

    test('4. setDate clears attendanceMap and historyStack to avoid bleeding across dates', () {
      final attendanceService = AttendanceService();
      final studentService = StudentService();
      final notifier = AttendanceBoardNotifier(
        attendanceService: attendanceService,
        studentService: studentService,
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 1',
        assignedSection: 'A',
      );

      notifier.markStudent('s1', AttendanceStatus.present);
      expect(notifier.state.attendanceMap['s1'], equals(AttendanceStatus.present));

      notifier.setDate(DateTime.now().subtract(const Duration(days: 1)));
      expect(notifier.state.attendanceMap.isEmpty, isTrue);
    });
  });

  group('Teacher Attendance Responsive UI & Rendering Tests', () {
    final testStudents = [
      createTestStudent(id: 'u1', name: 'Student Alpha', rollNumber: '01'),
      createTestStudent(id: 'u2', name: 'Student Beta', rollNumber: '02'),
      createTestStudent(id: 'u3', name: 'Student Gamma', rollNumber: '03'),
    ];

    final teacherUser = UserModel(
      id: 'teacher-1',
      name: 'Teacher 1A',
      email: 'teacher1a@school.com',
      avatarUrl: '',
      schoolName: 'Test School',
      designation: 'Class Teacher',
      role: UserRole.teacher,
      schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
      assignedClass: 'Class 1',
      assignedSection: 'A',
    );

    Widget buildTestWidget({
      required Size screenSize,
      required AttendanceBoardNotifier customNotifier,
    }) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(teacherUser)),
          teacherRosterProvider.overrideWith((ref) async => testStudents),
          attendanceBoardProvider.overrideWith((ref) => customNotifier),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(size: screenSize),
            child: const AttendanceScreen(),
          ),
        ),
      );
    }

    const testWidths = [320.0, 360.0, 390.0, 430.0, 768.0];

    for (final width in testWidths) {
      testWidgets('Renders cleanly on screen width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final notifier = AttendanceBoardNotifier(
          attendanceService: AttendanceService(),
          studentService: StudentService(),
          repo: MockAttendanceRepository(),
          assignedClass: 'Class 1',
          assignedSection: 'A',
        );

        await tester.pumpWidget(buildTestWidget(
          screenSize: Size(width, 800),
          customNotifier: notifier,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Should not throw overflow or layout exceptions on $width px');

        // Verify summary shows 0% when no students are marked present
        expect(find.text('0%'), findsOneWidget);
        expect(find.text('TOTAL'), findsOneWidget);
        expect(find.text('PRESENT'), findsWidgets);
        expect(find.text('ABSENT'), findsWidgets);
        expect(find.text('LATE'), findsWidgets);

        // Verify that student status chips show Not Marked initially
        expect(find.text('Not Marked'), findsWidgets);
      });
    }

    testWidgets('Tapping PRESENT button selects it, updates chip to Present, and updates top percentage', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final notifier = AttendanceBoardNotifier(
        attendanceService: AttendanceService(),
        studentService: StudentService(),
        repo: MockAttendanceRepository(),
        assignedClass: 'Class 1',
        assignedSection: 'A',
      );

      await tester.pumpWidget(buildTestWidget(
        screenSize: const Size(390, 844),
        customNotifier: notifier,
      ));
      await tester.pumpAndSettle();

      // Initially 0%
      expect(find.text('0%'), findsOneWidget);

      // Find all PRESENT buttons and tap the first one
      final presentButtons = find.text('PRESENT ✓');
      expect(presentButtons, findsNWidgets(testStudents.length));
      await tester.tap(presentButtons.first);
      await tester.pumpAndSettle();

      // Now 1 out of 3 is present => 33%
      expect(find.text('33%'), findsOneWidget);
      expect(find.text('Present ✓'), findsOneWidget);

      // Tapping PRESENT again toggles back to notMarked
      await tester.tap(presentButtons.first);
      await tester.pumpAndSettle();

      // Now back to 0% and 3 Not Marked chips
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Not Marked'), findsWidgets);
    });
  });
}
