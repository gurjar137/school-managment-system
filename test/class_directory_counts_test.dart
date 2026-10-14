import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/features/students/students_list_screen.dart';
import 'package:school_app/features/students/class_students_screen.dart';

class MockCountingRepository extends SchoolRepository {
  final Map<String, int> mockClassCounts;
  final int totalCount;
  final List<StudentModel> mockStudents;

  MockCountingRepository({
    required this.mockClassCounts,
    required this.totalCount,
    required this.mockStudents,
  });

  @override
  Future<Map<String, int>> getClassStudentCounts({
    required List<String> classNames,
    String? schoolId,
    String? academicYearId,
  }) async {
    return mockClassCounts;
  }

  @override
  Future<int> getStudentCount({
    String? schoolId,
    String? academicYearId,
    String? className,
    String? section,
    AccountStatus? status = AccountStatus.active,
  }) async {
    if (className != null && mockClassCounts.containsKey(className)) {
      return mockClassCounts[className]!;
    }
    return totalCount;
  }

  @override
  Future<List<StudentModel>> getStudents({
    String? schoolId,
    String? query,
    String? className,
    String? section,
    String? academicYearId,
    AccountStatus? status,
    bool isTeacher = false,
    String? teacherAssignedClass,
    String? teacherAssignedSection,
    String? gender,
    String? attendanceStatus,
    String? feeStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    var list = mockStudents;
    if (className != null) {
      list = list.where((s) => s.className == className).toList();
    }
    if (offset >= list.length) return [];
    final end = (offset + limit) < list.length ? (offset + limit) : list.length;
    return list.sublist(offset, end);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testClassCounts = {
    'Class 1': 839,
    'Class 2': 834,
    'Class 3': 835,
    'Class 4': 834,
    'Class 5': 838,
    'Class 6': 833,
    'Class 7': 833,
    'Class 8': 833,
    'Class 9': 833,
    'Class 10': 833,
    'Class 11': 833,
    'Class 12': 835,
  };

  final testStudents = List.generate(
    60,
    (i) => StudentModel(
      id: 'student_$i',
      name: 'Student $i',
      rollNumber: '$i',
      admissionNumber: 'ADM-$i',
      className: 'Class 1',
      section: 'A',
      avatarUrl: '',
      attendancePercentage: 100,
      todayAttendance: AttendanceStatus.present,
      dateOfBirth: '2015-01-01',
      gender: 'Male',
      fatherName: 'Father',
      fatherMobile: '1234567890',
      motherName: 'Mother',
      motherMobile: '1234567891',
      guardianName: 'Guardian',
      emergencyContact: '1234567890',
      parentEmail: 'parent@test.com',
      address: 'Address',
      city: 'City',
      state: 'State',
      pinCode: '123456',
      bloodGroup: 'O+',
      medicalNotes: '',
      importantNotes: '',
      totalFee: 50000,
      paidFee: 50000,
      pendingFee: 0,
      feeStatus: PaymentStatus.paid,
      paymentHistory: const [],
    ),
  );

  testWidgets('StudentsListScreen displays exact server-side counts on Class Directory cards', (tester) async {
    final mockRepo = MockCountingRepository(
      mockClassCounts: testClassCounts,
      totalCount: 10013,
      mockStudents: testStudents,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: StudentsListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('839 Students'), findsOneWidget);
    expect(find.text('834 Students'), findsNWidgets(2));
    expect(find.text('10013 Students Registered'), findsOneWidget);
  });

  testWidgets('ClassStudentsScreen displays exact total count and passes className to repo', (tester) async {
    final mockRepo = MockCountingRepository(
      mockClassCounts: testClassCounts,
      totalCount: 10013,
      mockStudents: testStudents,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: ClassStudentsScreen(
            className: 'Class 1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('839 Students in Class 1'), findsOneWidget);
    expect(find.text('Student 0'), findsOneWidget);
  });

  test('MockCountingRepository pagination verification: 50 per page', () async {
    final mockRepo = MockCountingRepository(
      mockClassCounts: testClassCounts,
      totalCount: 10013,
      mockStudents: testStudents,
    );

    final page1 = await mockRepo.getStudents(limit: 50, offset: 0);
    expect(page1.length, 50);
    expect(page1.first.id, 'student_0');
    expect(page1.last.id, 'student_49');

    final page2 = await mockRepo.getStudents(limit: 50, offset: 50);
    expect(page2.length, 10);
    expect(page2.first.id, 'student_50');
    expect(page2.last.id, 'student_59');
  });
}
