import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:school_app/core/providers/app_providers.dart";
import "package:school_app/data/models/user_model.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/repositories/school_repository.dart";
import "package:school_app/data/services/student_service.dart";

class MockStudentService extends StudentService {
  MockStudentService() : super();

  @override
  Future<String> fetchActiveSchoolId({String? fallback = "6254bee9-151d-4332-8a1c-3994af7d2153"}) async => "school-123";

  @override
  Future<String?> fetchActiveAcademicYearId(String schoolId) async => "ay-2026";

  @override
  Future<int> getStudentCount({
    String? schoolId,
    String? academicYearId,
    String? className,
    String? section,
    AccountStatus? status,
  }) async {
    if (className == "Class 1" && section == "A") {
      return 417;
    }
    if (className == "Class 12" && section == "B") {
      return 416;
    }
    return 100;
  }
}

class PaginatedFakeRepository extends SchoolRepository {
  final List<StudentModel> allDataset;

  PaginatedFakeRepository(this.allDataset);

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
    var filtered = allDataset.where((s) {
      if (isTeacher) {
        if (teacherAssignedClass != null && teacherAssignedClass.isNotEmpty) {
          if (s.className != teacherAssignedClass) return false;
        }
        if (teacherAssignedSection != null && teacherAssignedSection.isNotEmpty) {
          if (s.section != teacherAssignedSection) return false;
        }
      }
      if (query != null && query.isNotEmpty) {
        if (!s.name.toLowerCase().contains(query.toLowerCase()) &&
            !s.admissionNumber.toLowerCase().contains(query.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();

    if (offset >= filtered.length) return [];
    final end = (offset + limit < filtered.length) ? offset + limit : filtered.length;
    return filtered.sublist(offset, end);
  }
}

class TestAuthNotifier extends AuthNotifier {
  final UserModel? initialUser;
  TestAuthNotifier(this.initialUser) : super() {
    state = initialUser;
  }
}

void main() {
  group("Teacher Dashboard Count & Pagination Tests", () {
    test("teacherStudentCountProvider returns exact assigned student count for Class 1A", () async {
      final mockService = MockStudentService();
      final container = ProviderContainer(
        overrides: [
          studentServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => TestAuthNotifier(
              const UserModel(
                id: "t-1",
                name: "Test Teacher 1A",
                email: "test.teacher.1a@school-test.local",
                role: UserRole.teacher,
                avatarUrl: "",
                schoolId: "school-123",
                schoolName: "Test School",
                designation: "Class Teacher",
                assignedClass: "Class 1",
                assignedSection: "A",
              ),
            ),
          ),
        ],
      );

      final count = await container.read(teacherStudentCountProvider.future);
      expect(count, equals(417));
    });

    test("teacherStudentCountProvider returns exact assigned student count for Class 12B", () async {
      final mockService = MockStudentService();
      final container = ProviderContainer(
        overrides: [
          studentServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => TestAuthNotifier(
              const UserModel(
                id: "t-2",
                name: "Test Teacher 12B",
                email: "test.teacher.12b@school-test.local",
                role: UserRole.teacher,
                avatarUrl: "",
                schoolId: "school-123",
                schoolName: "Test School",
                designation: "Class Teacher",
                assignedClass: "Class 12",
                assignedSection: "B",
              ),
            ),
          ),
        ],
      );

      final count = await container.read(teacherStudentCountProvider.future);
      expect(count, equals(416));
    });

    test("teacherStudentCountProvider returns 0 for unassigned teacher", () async {
      final mockService = MockStudentService();
      final container = ProviderContainer(
        overrides: [
          studentServiceProvider.overrideWithValue(mockService),
          authProvider.overrideWith(
            (ref) => TestAuthNotifier(
              const UserModel(
                id: "t-unassigned",
                name: "Unassigned Teacher",
                email: "teacher@test.local",
                role: UserRole.teacher,
                avatarUrl: "",
                schoolId: "school-123",
                schoolName: "Test School",
                designation: "Teacher",
                assignedClass: "Not Assigned",
                assignedSection: "",
              ),
            ),
          ),
        ],
      );

      final count = await container.read(teacherStudentCountProvider.future);
      expect(count, equals(0));
    });

    test("SchoolRepository getStudents supports range pagination with limit and offset", () async {
      final totalStudents = List<StudentModel>.generate(
        120,
        (i) => StudentModel.fromJson({
          "id": "stu_$i",
          "schoolId": "school-123",
          "admissionNumber": "ADM-$i",
          "rollNumber": "$i",
          "name": "Student $i",
          "className": "Class 1",
          "section": "A",
        }),
      );

      final repo = PaginatedFakeRepository(totalStudents);

      // Page 1: 50 items
      final page1 = await repo.getStudents(
        isTeacher: true,
        teacherAssignedClass: "Class 1",
        teacherAssignedSection: "A",
        limit: 50,
        offset: 0,
      );
      expect(page1.length, equals(50));
      expect(page1.first.admissionNumber, equals("ADM-0"));
      expect(page1.last.admissionNumber, equals("ADM-49"));

      // Page 2: 50 items
      final page2 = await repo.getStudents(
        isTeacher: true,
        teacherAssignedClass: "Class 1",
        teacherAssignedSection: "A",
        limit: 50,
        offset: 50,
      );
      expect(page2.length, equals(50));
      expect(page2.first.admissionNumber, equals("ADM-50"));
      expect(page2.last.admissionNumber, equals("ADM-99"));

      // Page 3: 20 items (remainder of 120)
      final page3 = await repo.getStudents(
        isTeacher: true,
        teacherAssignedClass: "Class 1",
        teacherAssignedSection: "A",
        limit: 50,
        offset: 100,
      );
      expect(page3.length, equals(20));
      expect(page3.first.admissionNumber, equals("ADM-100"));
      expect(page3.last.admissionNumber, equals("ADM-119"));
    });
  });
}
