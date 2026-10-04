import "dart:io";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:school_app/core/config/supabase_config.dart";
import "package:school_app/data/services/student_service.dart";

class RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = RealHttpOverrides();

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
      ),
    );
  });

  test("Scalability Fix: Server-Side Filters, Count, and Search across 10,000 Students", () async {
    final client = Supabase.instance.client;
    final sessionFile = File("C:/Users/dharm/.gemini/antigravity/brain/3360a3af-8679-490d-a386-f722f510ae3c/scratch/session.json");
    if (await sessionFile.exists()) {
      await client.auth.recoverSession(await sessionFile.readAsString());
    }

    final user = client.auth.currentUser;
    expect(user, isNotNull, reason: "Must have authenticated admin user session");

    final profile = await client.from("profiles").select().eq("auth_user_id", user!.id).single();
    final schoolId = profile["school_id"].toString();
    print("Resolved School ID: $schoolId");

    final studentService = StudentService();

    // ==========================================
    // 1. VERIFY DASHBOARD EXACT COUNT
    // ==========================================
    print("\n--- 1. VERIFY EXACT LIVE COUNT ---");
    final countWatch = Stopwatch()..start();
    final liveTotalStudents = await studentService.getStudentCount(schoolId: schoolId);
    countWatch.stop();
    print("Exact Live Student Count: $liveTotalStudents in ${countWatch.elapsedMilliseconds}ms");
    expect(liveTotalStudents, greaterThanOrEqualTo(10000));
    expect(liveTotalStudents, equals(10013)); // 10,000 test + 13 genuine

    // ==========================================
    // 2. VERIFY SERVER-SIDE SEARCH ACROSS ALL 10,000+ STUDENTS
    // ==========================================
    print("\n--- 2. VERIFY SERVER-SIDE SEARCH ---");
    final searchCases = [
      {"query": "Test Student 00001", "expectedAdm": "TEST-ADM-00001"},
      {"query": "Test Student 05000", "expectedAdm": "TEST-ADM-05000"},
      {"query": "Test Student 10000", "expectedAdm": "TEST-ADM-10000"},
      {"query": "TEST-ADM-00001", "expectedAdm": "TEST-ADM-00001"},
      {"query": "TEST-ADM-05000", "expectedAdm": "TEST-ADM-05000"},
      {"query": "TEST-ADM-10000", "expectedAdm": "TEST-ADM-10000"},
    ];

    for (final sc in searchCases) {
      final sWatch = Stopwatch()..start();
      final results = await studentService.getAllStudents(
        schoolId: schoolId,
        query: sc["query"],
        limit: 10,
      );
      sWatch.stop();
      print("Search '${sc['query']}': returned ${results.length} rows in ${sWatch.elapsedMilliseconds}ms");
      expect(results, isNotEmpty, reason: "Must find ${sc['query']}");
      expect(results.first.admissionNumber, equals(sc["expectedAdm"]));
    }

    // ==========================================
    // 3. VERIFY SERVER-SIDE CLASS FILTERS
    // ==========================================
    print("\n--- 3. VERIFY SERVER-SIDE CLASS FILTERS ---");
    // Class 1: 835 students (834 test + 1 genuine)
    final c1Watch = Stopwatch()..start();
    final c1Count = await studentService.getStudentCount(schoolId: schoolId, className: "Class 1");
    c1Watch.stop();
    print("Class 1 Count: $c1Count in ${c1Watch.elapsedMilliseconds}ms");
    expect(c1Count, equals(839)); // 834 test + 5 genuine

    final c1Page = await studentService.getAllStudents(
      schoolId: schoolId,
      className: "Class 1",
      limit: 50,
      offset: 0,
    );
    print("Class 1 Page 1: ${c1Page.length} rows (all belonging to Class 1)");
    expect(c1Page.length, equals(50));
    expect(c1Page.every((s) => s.className.toLowerCase().contains("1")), isTrue);

    // Class 12: 835 students (833 test + 2 genuine)
    final c12Watch = Stopwatch()..start();
    final c12Count = await studentService.getStudentCount(schoolId: schoolId, className: "Class 12");
    c12Watch.stop();
    print("Class 12 Count: $c12Count in ${c12Watch.elapsedMilliseconds}ms");
    expect(c12Count, equals(835)); // 833 test + 2 genuine

    final c12Page = await studentService.getAllStudents(
      schoolId: schoolId,
      className: "Class 12",
      limit: 50,
      offset: 0,
    );
    print("Class 12 Page 1: ${c12Page.length} rows (all belonging to Class 12)");
    expect(c12Page.length, equals(50));
    expect(c12Page.every((s) => s.className.toLowerCase().contains("12")), isTrue);

    // ==========================================
    // 4. VERIFY SERVER-SIDE SECTION FILTERS
    // ==========================================
    print("\n--- 4. VERIFY SERVER-SIDE SECTION FILTERS ---");
    // Class 1 Section A: 417 students
    final c1AWatch = Stopwatch()..start();
    final c1ACount = await studentService.getStudentCount(
      schoolId: schoolId,
      className: "Class 1",
      section: "A",
    );
    c1AWatch.stop();
    print("Class 1 Section A Count: $c1ACount in ${c1AWatch.elapsedMilliseconds}ms");
    expect(c1ACount, equals(417));

    final c1APage = await studentService.getAllStudents(
      schoolId: schoolId,
      className: "Class 1",
      section: "A",
      limit: 50,
    );
    expect(c1APage.length, equals(50));
    expect(c1APage.every((s) => s.section.toUpperCase() == "A"), isTrue);

    // Class 12 Section B: 416 students
    final c12BWatch = Stopwatch()..start();
    final c12BCount = await studentService.getStudentCount(
      schoolId: schoolId,
      className: "Class 12",
      section: "B",
    );
    c12BWatch.stop();
    print("Class 12 Section B Count: $c12BCount in ${c12BWatch.elapsedMilliseconds}ms");
    expect(c12BCount, equals(416));

    final c12BPage = await studentService.getAllStudents(
      schoolId: schoolId,
      className: "Class 12",
      section: "B",
      limit: 50,
    );
    expect(c12BPage.length, equals(50));
    expect(c12BPage.every((s) => s.section.toUpperCase() == "B"), isTrue);

    // ==========================================
    // 5. VERIFY PAGINATION INTEGRITY
    // ==========================================
    print("\n--- 5. VERIFY PAGINATION INTEGRITY ---");
    final p1 = await studentService.getAllStudents(schoolId: schoolId, limit: 50, offset: 0);
    final p2 = await studentService.getAllStudents(schoolId: schoolId, limit: 50, offset: 50);
    expect(p1.length, equals(50));
    expect(p2.length, equals(50));
    expect(p1.first.id, isNot(equals(p2.first.id)));
    print("Pagination verified: Page 1 (first item: ${p1.first.admissionNumber}), Page 2 (first item: ${p2.first.admissionNumber})");

    // ==========================================
    // 6. VERIFY DIRECT STUDENT PROFILE LOOKUP
    // ==========================================
    print("\n--- 6. VERIFY DIRECT STUDENT PROFILE LOOKUP ---");
    final middleStu = await studentService.getStudentById("TEST-ADM-05000");
    expect(middleStu, isNotNull);
    expect(middleStu!.admissionNumber, equals("TEST-ADM-05000"));
    expect(middleStu.parentAccessCode, equals("TEST-PAR-05000"));
    print("Direct Profile lookup for middle student: ${middleStu.name} (${middleStu.admissionNumber}), Class: ${middleStu.className}-${middleStu.section}");

    // ==========================================
    // 7. VERIFY FEE ACCURACY FOR 10,000 DATASET
    // ==========================================
    print("\n--- 7. VERIFY FEE INTEGRITY ---");
    final feeAcc = await client
        .from("student_fee_accounts")
        .select()
        .eq("school_id", schoolId)
        .eq("student_id", middleStu.id)
        .single();
    expect(feeAcc["gross_fee"], equals(100000.0));
    expect(feeAcc["status"], equals("due"));
    print("Fee Account for ${middleStu.admissionNumber}: Gross ₹${feeAcc['gross_fee']}, Status: ${feeAcc['status']}");

    print("\n=================== ALL SCALABILITY VERIFICATIONS PASSED! ===================");
  }, timeout: const Timeout(Duration(minutes: 5)));
}
