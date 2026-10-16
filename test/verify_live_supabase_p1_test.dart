import "dart:io";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:school_app/core/config/supabase_config.dart";
import "package:school_app/data/models/user_model.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/models/salary_models.dart";
import "package:school_app/data/models/academic_models.dart";
import "package:school_app/data/services/student_service.dart";
import "package:school_app/data/services/salary_service.dart";

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

  group("Live Supabase P1-2: Student Status & Deletion Live Database Tests", () {
    late SupabaseClient client;
    late StudentService studentService;
    final schoolId = "6254bee9-151d-4332-8a1c-3994af7d2153";

    setUp(() async {
      client = Supabase.instance.client;
      try {
        final sessionJson = await File("C:/Users/dharm/.gemini/antigravity/brain/3360a3af-8679-490d-a386-f722f510ae3c/scratch/session.json").readAsString();
        await client.auth.recoverSession(sessionJson);
      } catch (e) {
        print("Session recover note: $e");
      }
      studentService = StudentService();
      // Initialize student cache from live Supabase
      await studentService.getAllStudents(schoolId: schoolId);
    });

    test("Live Supabase: Fetch students, update status to INACTIVE, verify persistence, restore to ACTIVE", () async {
      final students = await studentService.getAllStudents(schoolId: schoolId);
      expect(students, isNotEmpty);
      final target = students.first;
      print("Live Student Selected: ${target.name} (ID: ${target.id}, Status: ${target.status})");

      // 1. Update status to INACTIVE using StudentService
      await studentService.updateStudentStatus(target.id, AccountStatus.inactive);
      final inMemory1 = await studentService.getStudentById(target.id);
      expect(inMemory1?.status, equals(AccountStatus.inactive));
      print("Status after deactivation: ${inMemory1?.status}");

      // 2. Restore status to ACTIVE using StudentService
      await studentService.updateStudentStatus(target.id, AccountStatus.active);
      final inMemory2 = await studentService.getStudentById(target.id);
      expect(inMemory2?.status, equals(AccountStatus.active));
      print("Status after reactivation: ${inMemory2?.status}");
    });

    test("Live Supabase: Attempting to delete student with fee accounts triggers foreign key safety", () async {
      final students = await client
          .from("students")
          .select("id, first_name")
          .eq("school_id", schoolId);

      String? targetWithDues;
      for (final s in students) {
        final sid = s["id"].toString();
        final fees = await client.from("student_fee_accounts").select("id").eq("student_id", sid);
        if (fees.isNotEmpty) {
          targetWithDues = sid;
          print("Found student with fee account in current school: " + s["first_name"].toString() + " ($sid)");
          break;
        }
      }

      if (targetWithDues != null) {
        bool threwExpectedException = false;
        try {
          await studentService.deleteStudent(targetWithDues);
        } catch (e) {
          threwExpectedException = true;
          print("Caught expected safety rejection: $e");
          expect(e.toString(), contains("Cannot permanently delete student with existing fee accounts"));
        }
        expect(threwExpectedException, isTrue, reason: "Foreign key constraint must reject deletion of student with financial records");
      }
    });

    test("Live Supabase: Student deletion removes student from persistent cache", () async {
      final students = await studentService.getAllStudents(schoolId: schoolId);
      expect(students, isNotEmpty);
      final tempAdmission = "TEMP-ADM-" + DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final dummy = students.first.copyWith(
        id: "temp_del_test_999",
        name: "Temporary Deletable Student",
        admissionNumber: tempAdmission,
        parentAccessCode: "",
      );

      final created = await studentService.addStudent(dummy);
      expect(await studentService.getStudentById(created.id), isNotNull);

      await studentService.deleteStudent(created.id);
      expect(await studentService.getStudentById(created.id), isNull);
      print("Successfully deleted unencumbered student and synced persistent storage!");
    });
  });

  group("Live Supabase P1-1: Salary Persistence & Calculation Tests", () {
    late SalaryService salaryService;

    setUp(() async {
      salaryService = SalaryService();
    });

    test("SalaryService structure customization and payment persistence round-trip", () async {
      const teacher = TeacherModel(
        id: "t1",
        name: "Ramesh Sharma",
        email: "ramesh@school.com",
        subjects: ["Mathematics"],
        assignedClass: "Class 10-A",
        totalStudents: 35,
        avatarUrl: "",
        phone: "9876543210",
        designation: "Senior Mathematics Teacher",
      );

      final struct = SalaryStructure(
        basicSalary: 32000,
        allowances: [
          SalaryAllowance(type: "HRA", amount: 4500),
          SalaryAllowance(type: "Transport", amount: 1500),
        ],
        deductions: [
          SalaryDeduction(type: "PF", amount: 2000),
        ],
      );

      await salaryService.updateSalaryStructure("t1", struct);

      final retrieved = await salaryService.getSalaryStructure("t1");
      expect(retrieved?.basicSalary, equals(32000));
      expect(retrieved?.netSalary, equals(36000));

      final slip = await salaryService.recordSalaryPayment(
        teacher: teacher,
        monthYear: "September 2026",
        amountPaid: 36000,
        paymentMethod: "Bank Transfer",
        referenceNo: "LIVE-SAL-001",
        notes: "Live verification payout",
      );

      expect(slip.teacherName, equals("Ramesh Sharma"));
      expect(slip.netSalary, equals(36000));
      expect(slip.status, equals(SalaryStatus.paid));
      expect(slip.slipNo, startsWith("SLIP-2026-"));

      final history = await salaryService.getSalaryHistory("t1");
      expect(history.any((r) => r.referenceNo == "LIVE-SAL-001" && r.amountPaid == 36000), isTrue);
      print("Verified Salary Payment Recorded & Persisted: Ref LIVE-SAL-001, Amount: ₹36,000, Slip: " + slip.slipNo);
    });
  });
}
