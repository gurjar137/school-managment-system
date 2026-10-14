import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:school_app/core/providers/app_providers.dart";
import "package:school_app/data/models/user_model.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/repositories/school_repository.dart";
import "package:school_app/features/students/students_list_screen.dart";
import "package:school_app/features/students/student_profile_screen.dart";

class FakeOverflowRepository extends SchoolRepository {
  final StudentModel longNameStudent = StudentModel(
    id: "test-stu-overflow-1",
    name: "Sri Ramachandra Venkatasubramanian The Third of Bangalore",
    rollNumber: "9999",
    admissionNumber: "ADM-2026-LONG-000999",
    className: "Class 1",
    section: "A",
    avatarUrl: "",
    attendancePercentage: 94.5,
    todayAttendance: AttendanceStatus.present,
    dateOfBirth: "2018-05-14",
    gender: "Male",
    fatherName: "Sri Venkateswara Ramachandran Senior",
    fatherMobile: "+91 9876543210",
    motherName: "Srimathi Lakshmi Ramachandran",
    motherMobile: "+91 9876543211",
    guardianName: "Sri Venkateswara Ramachandran Senior",
    emergencyContact: "+91 9876543210",
    parentEmail: "venkatasubramanian.parent@example.com",
    address: "123 Long Heritage Boulevard, Near Temple Gate",
    city: "Bangalore",
    state: "Karnataka",
    pinCode: "560001",
    bloodGroup: "AB+ Positive",
    medicalNotes: "None",
    importantNotes: "Merit scholarship candidate",
    totalFee: 45000,
    paidFee: 30000,
    pendingFee: 15000,
    feeStatus: PaymentStatus.partial,
    paymentHistory: [],
  );

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
    return [longNameStudent];
  }

  @override
  Future<StudentModel?> getStudentById(String id) async {
    return longNameStudent;
  }
}

class FakeAuthNotifier extends AuthNotifier {
  final UserRole fixedRole;

  FakeAuthNotifier(this.fixedRole) : super() {
    state = UserModel(
      id: "user-1",
      name: fixedRole == UserRole.teacher ? "Teacher Ramesh" : "Admin Sharma",
      email: "user@test.com",
      role: fixedRole,
      assignedClass: "Class 1",
      assignedSection: "A",
      avatarUrl: "",
      schoolName: "St. Xavier Academy",
      designation: fixedRole == UserRole.teacher ? "Class Teacher" : "Administrator",
    );
  }

  @override
  UserProfileModel? get activeProfile => UserProfileModel(
    id: "prof-1",
    authUserId: "user-1",
    schoolId: "6254bee9-151d-4332-8a1c-3994af7d2153",
    schoolName: "St. Xavier Academy",
    name: fixedRole == UserRole.teacher ? "Teacher Ramesh" : "Admin Sharma",
    email: "user@test.com",
    role: fixedRole,
    status: AccountStatus.active,
    assignedClass: "Class 1",
    assignedSection: "A",
    designation: fixedRole == UserRole.teacher ? "Class Teacher" : "Administrator",
    createdAt: DateTime.now(),
  );
}

void main() {
  const viewports = [
    Size(320, 640),
    Size(360, 740),
    Size(390, 844),
    Size(430, 932),
  ];

  group("StudentsListScreen — Compact Screen Overflow Tests", () {
    for (final size in viewports) {
      testWidgets("No RenderFlex overflow at width ${size.width.toInt()}px with long student name", (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeOverflowRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              schoolRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith((ref) => FakeAuthNotifier(UserRole.teacher)),
            ],
            child: const MaterialApp(
              home: StudentsListScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: "Expected 0 RenderFlex overflow at ${size.width}px");
        expect(find.textContaining("Class 1"), findsWidgets);
        expect(find.text("94.5%"), findsOneWidget);
        expect(find.text("Attendance"), findsOneWidget);
      });
    }
  });

  group("StudentProfileScreen — Compact Screen Overflow & Tab Tests", () {
    for (final size in viewports) {
      testWidgets("Teacher: No RenderFlex overflow at width ${size.width.toInt()}px & Fees tab hidden", (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeOverflowRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              schoolRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith((ref) => FakeAuthNotifier(UserRole.teacher)),
            ],
            child: const MaterialApp(
              home: StudentProfileScreen(studentId: "test-stu-overflow-1"),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: "Expected 0 RenderFlex overflow at ${size.width}px");
        expect(find.text("Overview & Info"), findsOneWidget);
        expect(find.text("Parents & Contact"), findsOneWidget);
        expect(find.text("Fees & Dues"), findsNothing);
        expect(find.text("Academics"), findsOneWidget);
        expect(find.text("Attendance & Medical"), findsOneWidget);

        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.tabs.length, equals(4));

        final tabBarView = tester.widget<TabBarView>(find.byType(TabBarView));
        expect(tabBarView.children.length, equals(4));
      });

      testWidgets("Admin: No RenderFlex overflow at width ${size.width.toInt()}px & Fees tab visible", (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = FakeOverflowRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              schoolRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith((ref) => FakeAuthNotifier(UserRole.schoolAdmin)),
            ],
            child: const MaterialApp(
              home: StudentProfileScreen(studentId: "test-stu-overflow-1"),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: "Expected 0 RenderFlex overflow at ${size.width}px");
        expect(find.text("Overview & Info"), findsOneWidget);
        expect(find.text("Parents & Contact"), findsOneWidget);
        expect(find.text("Fees & Dues"), findsOneWidget);
        expect(find.text("Academics"), findsOneWidget);
        expect(find.text("Attendance & Medical"), findsOneWidget);

        final tabBar = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabBar.tabs.length, equals(5));

        final tabBarView = tester.widget<TabBarView>(find.byType(TabBarView));
        expect(tabBarView.children.length, equals(5));
      });
    }
  });
}
