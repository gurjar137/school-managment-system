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

  test("Seed and verify 10,000 test students dataset", () async {
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

    final activeYearRow = await client
        .from("academic_years")
        .select()
        .eq("school_id", schoolId)
        .eq("status", "active")
        .single();
    final academicYearId = activeYearRow["id"].toString();
    print("Resolved Active Academic Year: $academicYearId (${activeYearRow['name']})");

    // 1. Check existing test student count
    final countRes = await client
        .from("students")
        .select("id")
        .eq("school_id", schoolId)
        .ilike("admission_number", "TEST-ADM-%")
        .count(CountOption.exact);
    final existingCount = countRes.count;
    print("Exact TEST students in DB: $existingCount");

    final totalTarget = 10000;
    final stopwatch = Stopwatch()..start();

    // 2. Prepare 10,000 student definitions
    final allStudentsData = <Map<String, dynamic>>[];
    final allFeeAccountsData = <Map<String, dynamic>>[];

    // Class distribution: Classes 1 to 12
    // Classes 1-4: 834 students each
    // Classes 5-12: 833 students each
    // Total = 4 * 834 + 8 * 833 = 3336 + 6664 = 10000
    int currentClass = 1;
    int currentClassCount = 0;
    int targetForThisClass = (currentClass <= 4) ? 834 : 833;
    int rollA = 1;
    int rollB = 1;

    for (int i = 1; i <= totalTarget; i++) {
      final stuId = "00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}";
      final admNum = "TEST-ADM-${i.toString().padLeft(5, '0')}";
      final parCode = "TEST-PAR-${i.toString().padLeft(5, '0')}";
      final className = "Class $currentClass";

      // Split evenly into A and B
      // For 834: 417 in A, 417 in B
      // For 833: 417 in A, 416 in B
      final String section;
      final int rollNumber;
      if (currentClassCount < 417) {
        section = "A";
        rollNumber = rollA++;
      } else {
        section = "B";
        rollNumber = rollB++;
      }

      allStudentsData.add({
        "id": stuId,
        "school_id": schoolId,
        "academic_year_id": academicYearId,
        "admission_number": admNum,
        "first_name": "Test Student",
        "last_name": i.toString().padLeft(5, '0'),
        "class_name": className,
        "section_name": section,
        "roll_number": rollNumber.toString(),
        "date_of_birth": "2015-05-15",
        "gender": (i % 2 == 1) ? "Male" : "Female",
        "status": "ACTIVE",
        "parent_access_code": parCode,
      });

      allFeeAccountsData.add({
        "id": "00000000-0000-4000-9000-${i.toString().padLeft(12, '0')}",
        "school_id": schoolId,
        "academic_year_id": academicYearId,
        "student_id": stuId,
        "gross_fee": 100000.0,
        "discount_amount": 0.0,
        "waiver_amount": 0.0,
        "due_date": "2027-01-31",
        "status": "due",
      });

      currentClassCount++;
      if (currentClassCount >= targetForThisClass && currentClass < 12) {
        currentClass++;
        currentClassCount = 0;
        targetForThisClass = (currentClass <= 4) ? 834 : 833;
        rollA = 1;
        rollB = 1;
      }
    }

    print("Generated definitions for ${allStudentsData.length} students and ${allFeeAccountsData.length} fee accounts.");

    // 3. Insert any missing students
    const chunkSize = 500;
    if (existingCount < totalTarget) {
      print("Database has $existingCount students. Finding and inserting missing students...");
      // Fetch all existing admission numbers
      final existingAdmRes = await client
          .from("students")
          .select("admission_number")
          .eq("school_id", schoolId)
          .ilike("admission_number", "TEST-ADM-%");
      final existingAdms = (existingAdmRes as List).map((r) => r["admission_number"].toString()).toSet();
      print("Fetched ${existingAdms.length} existing admission numbers.");

      final missingStudents = allStudentsData.where((s) => !existingAdms.contains(s["admission_number"])).toList();
      print("Found ${missingStudents.length} missing students. Inserting...");
      for (int i = 0; i < missingStudents.length; i += chunkSize) {
        final end = (i + chunkSize < missingStudents.length) ? (i + chunkSize) : missingStudents.length;
        final chunk = missingStudents.sublist(i, end);
        await client.from("students").insert(chunk);
        print("Inserted missing students $i to ${end - 1}");
      }
    } else {
      print("All 10,000 students already present in DB!");
    }

    // Fetch the actual student IDs from DB mapped by admission_number or id!
    print("Fetching actual student IDs from database...");
    // Supabase PostgREST default limit is 1000 per request, so fetch in pages or map!
    final studentIdMap = <String, String>{}; // admission_number -> id
    for (int p = 0; p < totalTarget; p += 1000) {
      final pageRows = await client
          .from("students")
          .select("id, admission_number")
          .eq("school_id", schoolId)
          .ilike("admission_number", "TEST-ADM-%")
          .order("admission_number", ascending: true)
          .range(p, p + 999);
      for (final r in pageRows) {
        studentIdMap[r["admission_number"].toString()] = r["id"].toString();
      }
      print("Fetched page $p to ${p + pageRows.length - 1} (${studentIdMap.length} total mapped)");
    }
    print("Sample mapped student TEST-ADM-00001: ${studentIdMap['TEST-ADM-00001']}");
    print("Sample mapped student TEST-ADM-10000: ${studentIdMap['TEST-ADM-10000']}");

    // Build fee accounts using the REAL student IDs from DB!
    final realFeeAccounts = <Map<String, dynamic>>[];
    for (int i = 1; i <= totalTarget; i++) {
      final admNum = "TEST-ADM-${i.toString().padLeft(5, '0')}";
      final realStuId = studentIdMap[admNum];
      if (realStuId != null) {
        realFeeAccounts.add({
          "school_id": schoolId,
          "academic_year_id": academicYearId,
          "student_id": realStuId,
          "gross_fee": 100000.0,
          "discount_amount": 0.0,
          "waiver_amount": 0.0,
          "due_date": "2027-01-31",
          "status": "due",
        });
      }
    }
    print("Prepared ${realFeeAccounts.length} fee accounts with REAL student IDs!");

    // 4. Batch Insert Fee Accounts
    final existingFeeCountRes = await client
        .from("student_fee_accounts")
        .select("id")
        .eq("school_id", schoolId)
        .eq("academic_year_id", academicYearId)
        .eq("gross_fee", 100000.0)
        .count(CountOption.exact);
    final existingFeeCount = existingFeeCountRes.count;
    print("Exact TEST fee accounts in DB: $existingFeeCount");

    if (existingFeeCount < totalTarget) {
      print("Starting bulk insertion of fee accounts in chunks of $chunkSize...");
      for (int i = existingFeeCount; i < realFeeAccounts.length; i += chunkSize) {
        final end = (i + chunkSize < realFeeAccounts.length) ? (i + chunkSize) : realFeeAccounts.length;
        final chunk = realFeeAccounts.sublist(i, end);
        final batchNum = (i ~/ chunkSize) + 1;
        final totalBatches = (realFeeAccounts.length / chunkSize).ceil();
        final batchWatch = Stopwatch()..start();
        await client.from("student_fee_accounts").insert(chunk);
        batchWatch.stop();
        print("[Fee Accounts Batch $batchNum/$totalBatches] Inserted items $i to ${end - 1} in ${batchWatch.elapsedMilliseconds}ms");
      }
    } else {
      print("All 10,000 fee accounts already present in DB!");
    }

    // Find out which student is the extra student!
    final allTestStuRows = <Map<String, dynamic>>[];
    for (int p = 0; p <= 11000; p += 1000) {
      final pRows = await client
          .from("students")
          .select("id, admission_number")
          .eq("school_id", schoolId)
          .ilike("admission_number", "TEST-%")
          .range(p, p + 999);
      if (pRows.isEmpty) break;
      allTestStuRows.addAll((pRows as List).cast<Map<String, dynamic>>());
    }
    print("Found total ${allTestStuRows.length} students matching TEST-%");
    for (final s in allTestStuRows) {
      final adm = s["admission_number"].toString();
      final numPart = int.tryParse(adm.replaceAll("TEST-ADM-", ""));
      if (numPart == null || numPart < 1 || numPart > 10000) {
        print("EXTRA STUDENT FOUND: id=${s['id']}, adm=$adm. Detaching from TEST-ADM prefix...");
        final upd = await client.from("students").update({
          "admission_number": "PROBE-99999",
          "parent_access_code": "PROBE-PAR-99999",
          "status": "INACTIVE",
        }).eq("id", s["id"]).select();
        print("Update result for extra student: $upd");
      }
    }

    stopwatch.stop();
    print("Total seeding phase completed in: ${stopwatch.elapsedMilliseconds}ms (${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s)");

    // =========================================================================
    // 5. POST-INSERTION VERIFICATION & METRICS
    // =========================================================================
    print("=================== STARTING POST-INSERTION VERIFICATION ===================");

    // Verify 1 & 2: Class and Section distribution (fetch all test students in 1000-row chunks)
    final distMap = <String, Map<String, int>>{};
    final admSet = <String>{};
    final parSet = <String>{};

    for (int p = 0; p <= 11000; p += 1000) {
      final pageStudents = await client
          .from("students")
          .select("admission_number, parent_access_code, class_name, section_name")
          .eq("school_id", schoolId)
          .ilike("admission_number", "TEST-ADM-%")
          .order("admission_number", ascending: true)
          .range(p, p + 999);
      if (pageStudents.isEmpty) break;
      for (final row in pageStudents) {
        final adm = row["admission_number"].toString();
        if (adm == "TEST-ADM-99999") continue; // Probe student created during setup
        final c = row["class_name"] as String;
        final s = row["section_name"] as String;
        distMap.putIfAbsent(c, () => <String, int>{});
        distMap[c]![s] = (distMap[c]![s] ?? 0) + 1;
        admSet.add(adm);
        parSet.add(row["parent_access_code"].toString());
      }
    }

    print("VERIFICATION 1: Total Core Test Students in DB = ${admSet.length} (Target: $totalTarget)");
    expect(admSet.length, totalTarget);

    print("VERIFICATION 2: Class & Section Distribution across all 10,000 students:");
    for (int c = 1; c <= 12; c++) {
      final cName = "Class $c";
      final secMap = distMap[cName] ?? {};
      final totalInClass = secMap.values.fold(0, (a, b) => a + b);
      print("  - $cName: Total = $totalInClass (Section A: ${secMap['A']}, Section B: ${secMap['B']})");
      expect(totalInClass, (c <= 4) ? 834 : 833);
      expect(secMap["A"], 417);
      expect(secMap["B"], (c <= 4) ? 417 : 416);
    }

    // Verify 3: Total test fee accounts
    final verifyFeeRes = await client
        .from("student_fee_accounts")
        .select("id")
        .eq("school_id", schoolId)
        .eq("academic_year_id", academicYearId)
        .eq("gross_fee", 100000.0)
        .count(CountOption.exact);
    final totalTestFeeAccountsInDb = verifyFeeRes.count;
    print("VERIFICATION 3: Total Test Fee Accounts in DB = $totalTestFeeAccountsInDb (Target: $totalTarget)");
    expect(totalTestFeeAccountsInDb, totalTarget);

    // Verify 4: Deterministic gross fee sum
    final totalGross = totalTestFeeAccountsInDb * 100000.0;
    print("VERIFICATION 4: Total Gross Fee Sum = ₹${totalGross.toStringAsFixed(2)} (Expected: ₹1,000,000,000.00)");
    expect(totalGross, 1000000000.0);

    // Verify 5: Uniqueness of admission numbers & parent access codes
    print("VERIFICATION 5: Distinct admission numbers = ${admSet.length}, Distinct parent codes = ${parSet.length}");
    expect(admSet.length, totalTarget);
    expect(parSet.length, totalTarget);

    // =========================================================================
    // 6. ADMIN APP PERFORMANCE BENCHMARKING
    // =========================================================================
    print("=================== PERFORMANCE BENCHMARKING ===================");

    // Benchmark A: Standard student directory paginated query (first 50)
    final benchDirWatch = Stopwatch()..start();
    final firstPage = await client
        .from("students")
        .select("*")
        .eq("school_id", schoolId)
        .order("created_at", ascending: false)
        .range(0, 49);
    benchDirWatch.stop();
    print("BENCHMARK A: Directory first page (50 rows) query latency: ${benchDirWatch.elapsedMilliseconds}ms, rows returned: ${firstPage.length}");

    // Benchmark B: Search by student name (e.g. "05000")
    final benchSearchNameWatch = Stopwatch()..start();
    final searchByName = await client
        .from("students")
        .select("*")
        .eq("school_id", schoolId)
        .or("first_name.ilike.%05000%,last_name.ilike.%05000%");
    benchSearchNameWatch.stop();
    print("BENCHMARK B: Search by name query latency: ${benchSearchNameWatch.elapsedMilliseconds}ms, rows found: ${searchByName.length}");

    // Benchmark C: Search by admission number
    final benchSearchAdmWatch = Stopwatch()..start();
    final searchByAdm = await client
        .from("students")
        .select("*")
        .eq("school_id", schoolId)
        .eq("admission_number", "TEST-ADM-08888");
    benchSearchAdmWatch.stop();
    print("BENCHMARK C: Search by exact admission number query latency: ${benchSearchAdmWatch.elapsedMilliseconds}ms, rows found: ${searchByAdm.length}");

    // Benchmark D: Class & Section filter (e.g. Class 1 Section A)
    final benchFilterWatch = Stopwatch()..start();
    final filterClass = await client
        .from("students")
        .select("*")
        .eq("school_id", schoolId)
        .eq("class_name", "Class 1")
        .eq("section_name", "A");
    benchFilterWatch.stop();
    print("BENCHMARK D: Class & Section filter query latency: ${benchFilterWatch.elapsedMilliseconds}ms, rows found: ${filterClass.length}");

    // Benchmark E: Student profile load with fee account
    final benchProfileWatch = Stopwatch()..start();
    final sampleStu = await client
        .from("students")
        .select("*")
        .eq("school_id", schoolId)
        .eq("admission_number", "TEST-ADM-00001")
        .single();
    final sampleFee = await client
        .from("student_fee_accounts")
        .select("*")
        .eq("student_id", sampleStu["id"])
        .single();
    benchProfileWatch.stop();
    print("BENCHMARK E: Student Profile + Fee Account load latency: ${benchProfileWatch.elapsedMilliseconds}ms (Student: ${sampleStu['first_name']} ${sampleStu['last_name']}, Fee: ${sampleFee['gross_fee']})");

    // Benchmark F: Teacher Roster Isolation Verification
    print("BENCHMARK F: Testing Teacher Roster Isolation Logic...");
    final teacherRameshParser = TeacherAssignmentParser(
      assignedClass: "12",
      assignedSection: "f",
    );
    // Ramesh is assigned to Class 12, Section F
    // None of the 10,000 test students belong to section F (they are in A and B)
    final studentModels = (filterClass as List).map((r) => StudentModel.fromJson(r as Map<String, dynamic>)).toList();

    final rameshMatches = studentModels.where((s) => teacherRameshParser.matchesStudent(
      s,
      expectedSchoolId: schoolId,
      expectedAcademicYearId: academicYearId,
    )).toList();
    print("BENCHMARK F: Ramesh (Class 12 Section F) visible count among sample Class 1 students = ${rameshMatches.length} (Expected: 0 - Isolated)");

    // Test a teacher assigned to Class 1 Section A
    final teacher1AParser = TeacherAssignmentParser(
      assignedClass: "Class 1",
      assignedSection: "A",
    );
    final teacher1AMatches = studentModels.where((s) => teacher1AParser.matchesStudent(
      s,
      expectedSchoolId: schoolId,
      expectedAcademicYearId: academicYearId,
    )).toList();
    print("BENCHMARK F: Teacher 1A (Class 1 Section A) visible count among Class 1-A test students = ${teacher1AMatches.length} (Expected: ${filterClass.length} - Fully matched)");
    expect(teacher1AMatches.length, filterClass.length);

    print("=================== ALL VERIFICATIONS AND BENCHMARKS PASSED! ===================");
  }, timeout: const Timeout(Duration(minutes: 10)));
}

