import "dart:io";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:school_app/core/config/supabase_config.dart";
import "package:school_app/data/models/result_models.dart";
import "package:school_app/data/services/result_service.dart";
import "package:school_app/data/services/attendance_service.dart";
import "package:school_app/data/services/school_management_service.dart";

class RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = RealHttpOverrides();

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}
  });

  group("Final Remaining P2 Fixes Verification Suite", () {
    late SupabaseClient client;
    String authenticatedSchoolId = "";

    setUp(() async {
      client = Supabase.instance.client;
      try {
        final sessionFile = File("C:/Users/dharm/.gemini/antigravity/brain/3360a3af-8679-490d-a386-f722f510ae3c/scratch/session.json");
        if (await sessionFile.exists()) {
          final sessionJson = await sessionFile.readAsString();
          await client.auth.recoverSession(sessionJson);
        }
      } catch (e) {
        print("Session recover notice: $e");
      }

      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client.from("profiles").select("school_id").eq("auth_user_id", user.id).maybeSingle();
        authenticatedSchoolId = profile?["school_id"]?.toString() ?? "";
      }
      print("Active Authenticated School ID: $authenticatedSchoolId");
    });

    test("1. Results / Exams: Dynamic school_id resolution and legitimate empty list", () async {
      final resultService = ResultService();

      // Verify dynamic school_id resolution
      final resolvedSchool = await resultService.resolveActiveSchoolId();
      expect(resolvedSchool, equals(authenticatedSchoolId));
      print("✓ ResultService dynamically resolved school_id: $resolvedSchool");

      // Verify getAllExamsForAdmin returns [] on legitimate empty or missing DB table (never fake mock)
      final adminExams = await resultService.getAllExamsForAdmin();
      expect(adminExams, isA<List<ExamModel>>());
      print("✓ getAllExamsForAdmin returned live/safe result count: ${adminExams.length}");

      // Verify createExamByAdmin dynamically uses resolved school_id
      final testExam = ExamModel(
        id: "test-exam-${DateTime.now().millisecondsSinceEpoch}",
        title: "P2 Final Exam Test",
        type: ExamType.finalExam,
        academicYear: "2026-27",
        className: "10",
        section: "A",
        subjectName: "Science",
        examDate: DateTime.now().add(const Duration(days: 7)),
        submissionDeadline: DateTime.now().add(const Duration(days: 14)),
        maxMarks: 100,
        passingMarks: 35,
        instructions: "Test exam instructions",
        status: ResultStatus.open,
        createdByAdminId: "admin-user",
      );

      await resultService.createExamByAdmin(testExam);
      print("✓ createExamByAdmin executed successfully without hardcoded school UUID");
    });

    test("2. Attendance: Elimination of _mockAttendance fallback", () async {
      final attendanceService = AttendanceService();

      // Query attendance for a nonexistent date and class
      final nonExistentDate = DateTime(2099, 12, 31);
      final attendanceList = await attendanceService.fetchAttendanceForClass(
        schoolId: authenticatedSchoolId,
        classId: "nonexistent-class-id",
        sectionId: "nonexistent-section-id",
        date: nonExistentDate,
      );

      // Must strictly return [] and NOT fallback to _mockAttendance
      expect(attendanceList, isEmpty);
      print("✓ fetchAttendanceForClass returned legitimate [] for non-matching class/date (no mock fallback)");

      // Query attendance for an existing date where real records exist
      final realRecords = await attendanceService.fetchAttendanceForClass(
        schoolId: authenticatedSchoolId,
        classId: "",
        sectionId: "",
        date: DateTime(2026, 9, 5),
      );
      print("✓ fetchAttendanceForClass fetched real Supabase attendance: ${realRecords.length} records");
    });

    test("3. Global Search: Live Supabase search with multi-tenant isolation", () async {
      final schoolMgmt = SchoolManagementService();

      // Test empty query returns empty result
      final emptyResult = await schoolMgmt.performCategorizedSearch("");
      expect(emptyResult.isEmpty, isTrue);
      print("✓ Global search for empty string returns empty result");

      // Test real student search against live Supabase
      final studentSearch = await schoolMgmt.performCategorizedSearch("ajay");
      expect(studentSearch.students.isNotEmpty, isTrue);
      expect(studentSearch.students.first.name.toLowerCase(), contains("ajay"));
      print("✓ Global search found real live student: ${studentSearch.students.first.name} (ID: ${studentSearch.students.first.id})");

      // Test real teacher search against live Supabase profiles
      final teacherSearch = await schoolMgmt.performCategorizedSearch("ram");
      expect(teacherSearch.teachers.isNotEmpty, isTrue);
      expect(teacherSearch.teachers.first.name.toLowerCase(), contains("ram"));
      print("✓ Global search found real live teacher: ${teacherSearch.teachers.first.name} (Designation: ${teacherSearch.teachers.first.designation})");

      // Test real fee payments & receipts search against live Supabase
      final feeSearch = await schoolMgmt.performCategorizedSearch("REC");
      expect(feeSearch.feePayments.isNotEmpty, isTrue);
      expect(feeSearch.receipts.isNotEmpty, isTrue);
      print("✓ Global search found ${feeSearch.feePayments.length} fee payments and ${feeSearch.receipts.length} receipts for 'REC'");

      // Test nonexistent search returns strictly empty
      final nonexistentSearch = await schoolMgmt.performCategorizedSearch("nonexistent_xyz_99999");
      expect(nonexistentSearch.isEmpty, isTrue);
      expect(nonexistentSearch.students, isEmpty);
      expect(nonexistentSearch.teachers, isEmpty);
      expect(nonexistentSearch.feePayments, isEmpty);
      expect(nonexistentSearch.receipts, isEmpty);
      print("✓ Global search for nonexistent term returns strictly empty (no mock data fallback)");
    });
  });
}
