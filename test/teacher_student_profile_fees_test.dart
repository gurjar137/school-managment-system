import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:school_app/core/providers/app_providers.dart";
import "package:school_app/data/models/user_model.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/repositories/school_repository.dart";
import "package:school_app/features/students/student_profile_screen.dart";

class FakeSchoolRepository extends SchoolRepository {
  final StudentModel testStudent = StudentModel(
    id: "test-stu-1",
    name: "Aman Verma",
    rollNumber: "12",
    admissionNumber: "ADM-2026-0012",
    className: "8",
    section: "A",
    avatarUrl: "",
    attendancePercentage: 92.5,
    todayAttendance: AttendanceStatus.present,
    dateOfBirth: "2012-05-14",
    gender: "Male",
    fatherName: "Rajesh Verma",
    fatherMobile: "9876543210",
    motherName: "Sunita Verma",
    motherMobile: "9876543211",
    guardianName: "Rajesh Verma",
    emergencyContact: "9876543210",
    parentEmail: "rajesh@example.com",
    address: "123 Campus Road",
    city: "Jaipur",
    state: "Rajasthan",
    pinCode: "302001",
    bloodGroup: "B+",
    medicalNotes: "None",
    importantNotes: "Good in mathematics",
    totalFee: 45000,
    paidFee: 30000,
    pendingFee: 15000,
    feeStatus: PaymentStatus.partial,
    paymentHistory: [],
  );

  @override
  Future<StudentModel?> getStudentById(String id) async {
    return testStudent;
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
    designation: fixedRole == UserRole.teacher ? "Class Teacher" : "Administrator",
    createdAt: DateTime.now(),
  );
}

void main() {
  testWidgets("Teacher section: Student File screen hides Fees & Dues tab", (tester) async {
    final fakeRepo = FakeSchoolRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(fakeRepo),
          authProvider.overrideWith((ref) => FakeAuthNotifier(UserRole.teacher)),
        ],
        child: const MaterialApp(
          home: StudentProfileScreen(studentId: "test-stu-1"),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Student Profile loaded
    expect(find.text("Aman Verma"), findsWidgets);

    // Verify TabBar tabs for Teacher
    expect(find.text("Overview & Info"), findsOneWidget);
    expect(find.text("Parents & Contact"), findsOneWidget);
    expect(find.text("Academics"), findsOneWidget);
    expect(find.text("Attendance & Medical"), findsOneWidget);

    // Verify "Fees & Dues" tab is COMPLETELY REMOVED for Teacher
    expect(find.text("Fees & Dues"), findsNothing);

    // Verify Tab count is 4
    final tabBarFinder = find.byType(TabBar);
    expect(tabBarFinder, findsOneWidget);
    final TabBar tabBar = tester.widget(tabBarFinder);
    expect(tabBar.tabs.length, equals(4));

    // Verify TabBarView children count is 4
    final tabBarViewFinder = find.byType(TabBarView);
    expect(tabBarViewFinder, findsOneWidget);
    final TabBarView tabBarView = tester.widget(tabBarViewFinder);
    expect(tabBarView.children.length, equals(4));

    // Verify switching tabs works smoothly without out-of-bounds crash
    await tester.tap(find.text("Academics"));
    await tester.pumpAndSettle();
    expect(tabBar.controller?.index ?? 0, equals(2));

    await tester.tap(find.text("Attendance & Medical"));
    await tester.pumpAndSettle();
    expect(tabBar.controller?.index ?? 0, equals(3));
  });

  testWidgets("Admin section: Student File screen keeps Fees & Dues tab visible", (tester) async {
    final fakeRepo = FakeSchoolRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(fakeRepo),
          authProvider.overrideWith((ref) => FakeAuthNotifier(UserRole.schoolAdmin)),
        ],
        child: const MaterialApp(
          home: StudentProfileScreen(studentId: "test-stu-1"),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Student Profile loaded
    expect(find.text("Aman Verma"), findsWidgets);

    // Verify All 5 tabs exist for Admin
    expect(find.text("Overview & Info"), findsOneWidget);
    expect(find.text("Parents & Contact"), findsOneWidget);
    expect(find.text("Fees & Dues"), findsOneWidget);
    expect(find.text("Academics"), findsOneWidget);
    expect(find.text("Attendance & Medical"), findsOneWidget);

    // Verify Tab count is 5
    final tabBarFinder = find.byType(TabBar);
    expect(tabBarFinder, findsOneWidget);
    final TabBar tabBar = tester.widget(tabBarFinder);
    expect(tabBar.tabs.length, equals(5));

    // Verify TabBarView children count is 5
    final tabBarViewFinder = find.byType(TabBarView);
    expect(tabBarViewFinder, findsOneWidget);
    final TabBarView tabBarView = tester.widget(tabBarViewFinder);
    expect(tabBarView.children.length, equals(5));

    // Verify switching to Fees & Dues tab works for Admin
    await tester.tap(find.text("Fees & Dues"));
    await tester.pumpAndSettle();
    expect(tabBar.controller?.index ?? 0, equals(2));
  });
}
