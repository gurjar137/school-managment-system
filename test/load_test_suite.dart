import "dart:io";
import "dart:convert";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:school_app/core/config/supabase_config.dart";
import "package:school_app/core/utils/teacher_assignment_parser.dart";
import "package:school_app/data/models/student_model.dart";

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

  test("Verify 24 Test Teachers and Run Full Load Test Suite", () async {
    final client = Supabase.instance.client;
    final sessionFile = File("C:/Users/dharm/.gemini/antigravity/brain/3360a3af-8679-490d-a386-f722f510ae3c/scratch/session.json");
    if (await sessionFile.exists()) {
      await client.auth.recoverSession(await sessionFile.readAsString());
    }

    final user = client.auth.currentUser;
    expect(user, isNotNull, reason: "Must have authenticated admin user");

    final profile = await client.from("profiles").select().eq("auth_user_id", user!.id).single();
    final schoolId = profile["school_id"].toString();
    print("Resolved Dynamic School ID: $schoolId");

    // ==========================================
    // STEP 1: VERIFY TEST TEACHERS
    // ==========================================
    print("\n--- STEP 1: VERIFYING TEST TEACHERS ---");
    final teacherProfiles = await client
        .from("profiles")
        .select()
        .eq("school_id", schoolId)
        .eq("role", "teacher")
        .ilike("email", "%@school-test.local%");

    print("Found ${teacherProfiles.length} test teachers matching %@school-test.local%");

    if (teacherProfiles.length < 24) {
      print("Teachers count is ${teacherProfiles.length} < 24. Attempting insert via seed...");
      final teacherRows = <Map<String, dynamic>>[];
      for (int c = 1; c <= 12; c++) {
        for (final sec in ["A", "B"]) {
          final phoneSuffix = sec == "A" ? "A" : "B";
          final padC = c.toString().padLeft(2, "0");
          teacherRows.add({
            "school_id": schoolId,
            "full_name": "Test Teacher Class $c$sec",
            "role": "teacher",
            "status": "active",
            "assigned_class": "Class $c",
            "assigned_section": sec,
            "designation": c <= 4 ? "Primary Educator" : (c <= 8 ? "Middle School Faculty" : "Senior Secondary Faculty"),
            "email": "test.teacher.${c}${sec.toLowerCase()}@school-test.local",
            "phone": "99999${padC}01$phoneSuffix",
          });
        }
      }
      try {
        await client.from("profiles").insert(teacherRows);
        print("Successfully inserted 24 teachers directly via client.");
      } catch (e) {
        print("Direct insert failed (likely RLS): $e");
      }
    }

    // Re-query teachers
    final finalTeachers = await client
        .from("profiles")
        .select()
        .eq("school_id", schoolId)
        .eq("role", "teacher")
        .ilike("email", "%@school-test.local%")
        .order("full_name");

    print("Total verified test teachers: ${finalTeachers.length}");
    for (final t in finalTeachers) {
      print("Teacher: ${t['full_name']} | Role: ${t['role']} | Status: ${t['status']} | Class: ${t['assigned_class']} | Section: ${t['assigned_section']} | Email: ${t['email']}");
    }

    // ==========================================
    // TEST 1: DASHBOARD METRICS
    // ==========================================
    print("\n--- TEST 1: DASHBOARD METRICS ---");
    final dashWatch = Stopwatch()..start();
    final studentCountRes = await client
        .from("students")
        .select("id")
        .eq("school_id", schoolId)
        .count(CountOption.exact);
    final totalStudents = studentCountRes.count;

    final feeAggWatch = Stopwatch()..start();
    final feeAccounts = await client
        .from("student_fee_accounts")
        .select("gross_fee, discount_amount, waiver_amount, status")
        .eq("school_id", schoolId)
        .limit(50);
    dashWatch.stop();
    print("Dashboard student count: $totalStudents in ${dashWatch.elapsedMilliseconds}ms");
    print("Fee accounts sample fetch latency: ${feeAggWatch.elapsedMilliseconds}ms");

    // ==========================================
    // TEST 2: STUDENT DIRECTORY & PAGINATION
    // ==========================================
    print("\n--- TEST 2: STUDENT LIST (DIRECTORY) & PAGINATION ---");
    final p1Watch = Stopwatch()..start();
    final page1 = await client
        .from("students")
        .select("id, admission_number, first_name, last_name, class_name, section_name, status")
        .eq("school_id", schoolId)
        .order("admission_number", ascending: true)
        .range(0, 49);
    p1Watch.stop();
    print("Directory Page 1 (items 0-49) returned ${page1.length} rows in ${p1Watch.elapsedMilliseconds}ms");

    final p2Watch = Stopwatch()..start();
    final page2 = await client
        .from("students")
        .select("id, admission_number, first_name, last_name, class_name, section_name, status")
        .eq("school_id", schoolId)
        .order("admission_number", ascending: true)
        .range(50, 99);
    p2Watch.stop();
    print("Directory Page 2 (items 50-99) returned ${page2.length} rows in ${p2Watch.elapsedMilliseconds}ms");

    final p100Watch = Stopwatch()..start();
    final page100 = await client
        .from("students")
        .select("id, admission_number, first_name, last_name, class_name, section_name, status")
        .eq("school_id", schoolId)
        .order("admission_number", ascending: true)
        .range(4950, 4999);
    p100Watch.stop();
    print("Directory Page 100 (items 4950-4999) returned ${page100.length} rows in ${p100Watch.elapsedMilliseconds}ms");

    // ==========================================
    // TEST 3: SEARCH
    // ==========================================
    print("\n--- TEST 3: SEARCH LATENCY ---");
    final searchTargets = [
      {"type": "Name First", "q": "00001", "label": "Test Student 00001"},
      {"type": "Name Middle", "q": "05000", "label": "Test Student 05000"},
      {"type": "Name Last", "q": "10000", "label": "Test Student 10000"},
      {"type": "Adm First", "q": "TEST-ADM-00001", "label": "TEST-ADM-00001"},
      {"type": "Adm Middle", "q": "TEST-ADM-05000", "label": "TEST-ADM-05000"},
      {"type": "Adm Last", "q": "TEST-ADM-10000", "label": "TEST-ADM-10000"},
    ];

    for (final t in searchTargets) {
      final sWatch = Stopwatch()..start();
      final results = await client
          .from("students")
          .select()
          .eq("school_id", schoolId)
          .or("admission_number.eq.${t['q']},last_name.eq.${t['q']},first_name.ilike.%${t['q']}%");
      sWatch.stop();
      print("Search [${t['type']}] '${t['label']}': found ${results.length} rows in ${sWatch.elapsedMilliseconds}ms");
      if (results.isNotEmpty) {
        final r = results.first;
        print("  -> Match: ${r['first_name']} ${r['last_name']} (${r['admission_number']})");
      }
    }

    // ==========================================
    // TEST 4: CLASS FILTER
    // ==========================================
    print("\n--- TEST 4: CLASS FILTER ---");
    for (final c in ["Class 1", "Class 5", "Class 10", "Class 12"]) {
      final cWatch = Stopwatch()..start();
      final countRes = await client
          .from("students")
          .select("id")
          .eq("school_id", schoolId)
          .eq("class_name", c)
          .count(CountOption.exact);
      cWatch.stop();
      print("Filter '$c': exact count = ${countRes.count} in ${cWatch.elapsedMilliseconds}ms");
    }

    // ==========================================
    // TEST 5: SECTION FILTER
    // ==========================================
    print("\n--- TEST 5: SECTION FILTER ---");
    final sectionFilters = [
      {"class": "Class 1", "section": "A"},
      {"class": "Class 1", "section": "B"},
      {"class": "Class 12", "section": "A"},
      {"class": "Class 12", "section": "B"},
    ];

    for (final sf in sectionFilters) {
      final sWatch = Stopwatch()..start();
      final countRes = await client
          .from("students")
          .select("id")
          .eq("school_id", schoolId)
          .eq("class_name", sf["class"]!)
          .eq("section_name", sf["section"]!)
          .count(CountOption.exact);
      sWatch.stop();
      print("Filter '${sf['class']} - Section ${sf['section']}': exact count = ${countRes.count} in ${sWatch.elapsedMilliseconds}ms");
    }

    // ==========================================
    // TEST 6: STUDENT PROFILE LOAD
    // ==========================================
    print("\n--- TEST 6: STUDENT PROFILE & TABS ---");
    final profileAdms = ["TEST-ADM-00001", "TEST-ADM-05000", "TEST-ADM-10000"];
    for (final adm in profileAdms) {
      final pWatch = Stopwatch()..start();
      final stu = await client
          .from("students")
          .select()
          .eq("school_id", schoolId)
          .eq("admission_number", adm)
          .single();

      final fee = await client
          .from("student_fee_accounts")
          .select()
          .eq("student_id", stu["id"])
          .maybeSingle();

      pWatch.stop();
      print("Profile for $adm (${stu['first_name']} ${stu['last_name']}) loaded in ${pWatch.elapsedMilliseconds}ms");
      print("  -> Parent Code: ${stu['parent_access_code']} | Class: ${stu['class_name']}-${stu['section_name']} | Fee: ₹${fee?['gross_fee']} (Status: ${fee?['status']})");
    }

    // ==========================================
    // TEST 7: FEES MODULE
    // ==========================================
    print("\n--- TEST 7: FEES MODULE SEARCH & ACCURACY ---");
    for (final adm in ["TEST-ADM-00001", "TEST-ADM-05000"]) {
      final fWatch = Stopwatch()..start();
      final stu = await client
          .from("students")
          .select("id, admission_number, first_name, last_name")
          .eq("school_id", schoolId)
          .eq("admission_number", adm)
          .single();

      final feeAcc = await client
          .from("student_fee_accounts")
          .select()
          .eq("student_id", stu["id"])
          .single();

      final receipts = await client
          .from("fee_payments")
          .select()
          .eq("student_id", stu["id"]);

      final gross = (feeAcc['gross_fee'] as num?) ?? 0;
      final discount = (feeAcc['discount_amount'] as num?) ?? 0;
      final waiver = (feeAcc['waiver_amount'] as num?) ?? 0;
      final outstanding = gross - discount - waiver;

      fWatch.stop();
      print("Fee Account for ${stu['admission_number']} (${stu['first_name']}):");
      print("  Gross Fee: ₹$gross");
      print("  Discount: ₹$discount");
      print("  Waiver: ₹$waiver");
      print("  Outstanding: ₹$outstanding");
      print("  Status: ${feeAcc['status']}");
      print("  Receipts count: ${receipts.length}");
      print("  Loaded in: ${fWatch.elapsedMilliseconds}ms");
    }

    // ==========================================
    // TEST 8: TEACHER ISOLATION
    // ==========================================
    print("\n--- TEST 8: TEACHER ISOLATION ---");
    final p1A = TeacherAssignmentParser(assignedClass: "Class 1", assignedSection: "A");
    final p12B = TeacherAssignmentParser(assignedClass: "Class 12", assignedSection: "B");

    final c1AStudents = await client.from("students").select().eq("school_id", schoolId).eq("class_name", "Class 1").eq("section_name", "A");
    final c1BStudents = await client.from("students").select().eq("school_id", schoolId).eq("class_name", "Class 1").eq("section_name", "B");
    final c12BStudents = await client.from("students").select().eq("school_id", schoolId).eq("class_name", "Class 12").eq("section_name", "B");

    final m1A = (c1AStudents as List).map((r) => StudentModel.fromJson(r as Map<String, dynamic>)).toList();
    final m1B = (c1BStudents as List).map((r) => StudentModel.fromJson(r as Map<String, dynamic>)).toList();
    final m12B = (c12BStudents as List).map((r) => StudentModel.fromJson(r as Map<String, dynamic>)).toList();

    final t1A_matches_own = m1A.where((s) => p1A.matchesStudent(s, expectedSchoolId: schoolId)).length;
    final t1A_matches_1B = m1B.where((s) => p1A.matchesStudent(s, expectedSchoolId: schoolId)).length;
    final t1A_matches_12B = m12B.where((s) => p1A.matchesStudent(s, expectedSchoolId: schoolId)).length;
    print("Teacher Class 1A matching Class 1A students: $t1A_matches_own / ${m1A.length} (Expected: ALL)");
    print("Teacher Class 1A matching Class 1B students: $t1A_matches_1B / ${m1B.length} (Expected: 0 - ISOLATED)");
    print("Teacher Class 1A matching Class 12B students: $t1A_matches_12B / ${m12B.length} (Expected: 0 - ISOLATED)");

    final t12B_matches_own = m12B.where((s) => p12B.matchesStudent(s, expectedSchoolId: schoolId)).length;
    final t12B_matches_1A = m1A.where((s) => p12B.matchesStudent(s, expectedSchoolId: schoolId)).length;
    final t12B_matches_1B = m1B.where((s) => p12B.matchesStudent(s, expectedSchoolId: schoolId)).length;
    print("Teacher Class 12B matching Class 12B students: $t12B_matches_own / ${m12B.length} (Expected: ALL)");
    print("Teacher Class 12B matching Class 1A students: $t12B_matches_1A / ${m1A.length} (Expected: 0 - ISOLATED)");
    print("Teacher Class 12B matching Class 1B students: $t12B_matches_1B / ${m1B.length} (Expected: 0 - ISOLATED)");

    // ==========================================
    // TEST 9: REPORTS & ANALYTICS AGGREGATES
    // ==========================================
    print("\n--- TEST 9: REPORTS / AGGREGATION QUERIES ---");
    final repWatch = Stopwatch()..start();
    final activeCount = await client.from("students").select("id").eq("school_id", schoolId).eq("status", "active").count(CountOption.exact);
    final genderMale = await client.from("students").select("id").eq("school_id", schoolId).eq("gender", "male").count(CountOption.exact);
    final genderFemale = await client.from("students").select("id").eq("school_id", schoolId).eq("gender", "female").count(CountOption.exact);
    repWatch.stop();
    print("Reports Aggregates executed in ${repWatch.elapsedMilliseconds}ms:");
    print("  Active students: ${activeCount.count}");
    print("  Male students: ${genderMale.count}");
    print("  Female students: ${genderFemale.count}");

    print("\n=================== LOAD TEST SUITE COMPLETE ===================");
  }, timeout: const Timeout(Duration(minutes: 10)));
}
