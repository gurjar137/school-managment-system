import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:school_app/core/routing/app_router.dart";
import "package:school_app/core/providers/app_providers.dart";
import "package:school_app/data/models/user_model.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/repositories/school_repository.dart";
import "package:school_app/features/students/student_profile_screen.dart";

class MockSchoolRepository extends SchoolRepository {
  final Map<String, StudentModel> mockStudents = {
    "00000000-0000-4000-8000-000000000175": const StudentModel(
      id: "00000000-0000-4000-8000-000000000175",
      name: "Test Student 00175",
      rollNumber: "175",
      admissionNumber: "TEST-ADM-00175",
      className: "1",
      section: "A",
      avatarUrl: "",
      attendancePercentage: 95.0,
      todayAttendance: AttendanceStatus.present,
      dateOfBirth: "2015-05-15",
      gender: "Male",
      fatherName: "Parent 175",
      fatherMobile: "9876543210",
      motherName: "Mother 175",
      motherMobile: "9876543211",
      guardianName: "Parent 175",
      emergencyContact: "9876543210",
      parentEmail: "parent175@example.com",
      address: "175 Campus Road",
      city: "Jaipur",
      state: "Rajasthan",
      pinCode: "302001",
      bloodGroup: "O+",
      medicalNotes: "None",
      importantNotes: "Good student",
      totalFee: 50000,
      paidFee: 50000,
      pendingFee: 0,
      feeStatus: PaymentStatus.paid,
      paymentHistory: [],
    ),
    "TEST-ADM-00001": const StudentModel(
      id: "00000000-0000-4000-8000-000000000001",
      name: "Test Student 00001",
      rollNumber: "1",
      admissionNumber: "TEST-ADM-00001",
      className: "1",
      section: "A",
      avatarUrl: "",
      attendancePercentage: 98.0,
      todayAttendance: AttendanceStatus.present,
      dateOfBirth: "2015-05-15",
      gender: "Male",
      fatherName: "Parent 001",
      fatherMobile: "9876543210",
      motherName: "Mother 001",
      motherMobile: "9876543211",
      guardianName: "Parent 001",
      emergencyContact: "9876543210",
      parentEmail: "parent001@example.com",
      address: "1 Campus Road",
      city: "Jaipur",
      state: "Rajasthan",
      pinCode: "302001",
      bloodGroup: "A+",
      medicalNotes: "None",
      importantNotes: "Exemplary student",
      totalFee: 50000,
      paidFee: 50000,
      pendingFee: 0,
      feeStatus: PaymentStatus.paid,
      paymentHistory: [],
    ),
  };

  @override
  Future<StudentModel?> getStudentById(String id) async {
    if (mockStudents.containsKey(id)) {
      return mockStudents[id];
    }
    for (final s in mockStudents.values) {
      if (s.admissionNumber == id) return s;
    }
    return null;
  }
}

class TestAuthNotifier extends AuthNotifier {
  TestAuthNotifier() : super() {
    state = const UserModel(
      id: "user-1",
      name: "Admin Sharma",
      email: "admin@school.com",
      role: UserRole.schoolAdmin,
      avatarUrl: "",
      schoolName: "St. Xavier Academy",
      designation: "Administrator",
    );
  }

  @override
  UserProfileModel? get activeProfile => UserProfileModel(
    id: "prof-1",
    authUserId: "user-1",
    schoolId: "6254bee9-151d-4332-8a1c-3994af7d2153",
    schoolName: "St. Xavier Academy",
    name: "Admin Sharma",
    email: "admin@school.com",
    role: UserRole.schoolAdmin,
    status: AccountStatus.active,
    designation: "Administrator",
    createdAt: DateTime.now(),
  );
}

void main() {
  testWidgets("Route /student/:id loads StudentProfileScreen for UUID 00000000-0000-4000-8000-000000000175", (tester) async {
    final mockRepo = MockSchoolRepository();
    final authNotifier = TestAuthNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(mockRepo),
          authProvider.overrideWith((ref) => authNotifier),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final router = container.read(routerProvider);

    router.go("/student/00000000-0000-4000-8000-000000000175");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.byType(StudentProfileScreen), findsOneWidget);
    expect(find.text("Test Student 00175"), findsAtLeastNWidgets(1));

    // Cleanup
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets("Route /student/:id loads StudentProfileScreen for admission number TEST-ADM-00001", (tester) async {
    final mockRepo = MockSchoolRepository();
    final authNotifier = TestAuthNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(mockRepo),
          authProvider.overrideWith((ref) => authNotifier),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final router = container.read(routerProvider);

    router.go("/student/TEST-ADM-00001");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.byType(StudentProfileScreen), findsOneWidget);
    expect(find.text("Test Student 00001"), findsAtLeastNWidgets(1));

    // Cleanup
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets("Route /students/:id redirects smoothly to /student/:id without GoException", (tester) async {
    final mockRepo = MockSchoolRepository();
    final authNotifier = TestAuthNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schoolRepositoryProvider.overrideWithValue(mockRepo),
          authProvider.overrideWith((ref) => authNotifier),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(routerProvider);
            return MaterialApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    final router = container.read(routerProvider);

    router.go("/students/00000000-0000-4000-8000-000000000175");
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.byType(StudentProfileScreen), findsOneWidget);
    expect(find.text("Test Student 00175"), findsAtLeastNWidgets(1));

    // Cleanup
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
