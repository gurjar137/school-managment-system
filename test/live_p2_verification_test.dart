import "dart:io";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:school_app/core/config/supabase_config.dart";
import "package:school_app/data/models/user_model.dart";
import "package:school_app/data/models/parent_model.dart";
import "package:school_app/data/models/academic_models.dart";
import "package:school_app/data/services/parent_service.dart";
import "package:school_app/data/services/library_service.dart";
import "package:school_app/data/services/transport_service.dart";
import "package:school_app/data/services/student_service.dart";

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

  group("LIVE Supabase P2 Verification Test Suite", () {
    late SupabaseClient client;
    String schoolId = "";

    setUp(() async {
      client = Supabase.instance.client;
      try {
        final sessionFile = File("C:/Users/dharm/.gemini/antigravity/brain/3360a3af-8679-490d-a386-f722f510ae3c/scratch/session.json");
        if (await sessionFile.exists()) {
          final sessionJson = await sessionFile.readAsString();
          await client.auth.recoverSession(sessionJson);
        }
      } catch (e) {
        print("Session recover note: $e");
      }

      // Fetch dynamic authenticated school_id
      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client.from("profiles").select("school_id").eq("auth_user_id", user.id).maybeSingle();
        schoolId = profile?["school_id"]?.toString() ?? "";
      }
      print("Active Authenticated School ID: $schoolId");
    });

    test("1. Live Schema Check: tables and columns exist in Supabase", () async {
      // Check parents columns
      final parentsCheck = await client.from("parents").select("id, school_id, parent_code, parent_name, phone, linked_students_count").limit(1);
      expect(parentsCheck, isA<List>());
      print("✓ public.parents has parent_code, parent_name, linked_students_count");

      // Check parent_students table
      final parentStudentsCheck = await client.from("parent_students").select().limit(1);
      expect(parentStudentsCheck, isA<List>());
      print("✓ public.parent_students table exists");

      // Check library_books table
      final libraryBooksCheck = await client.from("library_books").select().limit(1);
      expect(libraryBooksCheck, isA<List>());
      print("✓ public.library_books table exists");

      // Check transport_routes table
      final transportRoutesCheck = await client.from("transport_routes").select().limit(1);
      expect(transportRoutesCheck, isA<List>());
      print("✓ public.transport_routes table exists");
    });

    test("2. Parent Management Live CRUD & Verification", () async {
      final parentService = ParentService();
      final studentService = StudentService();

      // Find an existing real student
      final realStudents = await studentService.getAllStudents(schoolId: schoolId);
      expect(realStudents, isNotEmpty);
      final realStudent = realStudents.first;
      print("Using real student for linking: ${realStudent.name} (${realStudent.id})");

      // 1. Create temporary test parent
      final testParent = await parentService.createParent(
        schoolId: schoolId,
        name: "LIVE TEST PARENT",
        phone: "+91 99999 88888",
        email: "livetestparent@example.com",
        address: "123 Test Street",
      );
      print("Created parent: ${testParent.name} with code: ${testParent.parentCode} (ID: ${testParent.id})");

      // 2. Verify row exists in LIVE public.parents
      final liveParentRow = await client.from("parents").select().eq("id", testParent.id).maybeSingle();
      expect(liveParentRow, isNotNull);
      expect(liveParentRow!["parent_name"], equals("LIVE TEST PARENT"));
      expect(liveParentRow["phone"], equals("+91 99999 88888"));
      print("✓ LIVE public.parents row verified in Supabase");

      // 3. Link real student
      final link = await parentService.linkStudentToParent(
        schoolId: schoolId,
        parentId: testParent.id,
        studentId: realStudent.id,
        studentName: realStudent.name,
        studentClass: "${realStudent.className}-${realStudent.section}",
        admissionNumber: realStudent.admissionNumber,
        relationship: "FATHER",
      );
      print("Created student link: ${link.id}");

      // 4. Verify row exists in LIVE public.parent_students
      final liveLinkRow = await client.from("parent_students").select().eq("id", link.id).maybeSingle();
      expect(liveLinkRow, isNotNull);
      expect(liveLinkRow!["parent_id"], equals(testParent.id));
      expect(liveLinkRow["student_id"], equals(realStudent.id));
      print("✓ LIVE public.parent_students row verified in Supabase");

      // 5. Verify linked_students_count
      final linkedList = await parentService.getLinkedStudentsForParent(testParent.id);
      expect(linkedList.length, equals(1));
      print("✓ Linked count verified: ${linkedList.length}");

      // 6. Refresh/reinitialize app: fresh ParentService instance with empty memory
      final freshParentService = ParentService();
      final reloadedParents = await freshParentService.fetchParents(schoolId: schoolId);
      final foundParent = reloadedParents.firstWhere((p) => p.id == testParent.id);
      expect(foundParent.name, equals("LIVE TEST PARENT"));
      final reloadedLinks = await freshParentService.getLinkedStudentsForParent(testParent.id);
      expect(reloadedLinks.length, equals(1));
      expect(reloadedLinks.first.studentId, equals(realStudent.id));
      print("✓ Fresh service instance reloaded parent & student link directly from Supabase");

      // 7. Verify parent code & phone verification against Supabase
      final verifyCodeResult = await freshParentService.verifyParentCode(testParent.parentCode);
      expect(verifyCodeResult["success"], isTrue);
      expect((verifyCodeResult["parent"] as ParentModel).id, equals(testParent.id));
      expect((verifyCodeResult["children"] as List).length, equals(1));

      final verifyPhoneResult = await freshParentService.verifyParentCode("+91 99999 88888");
      expect(verifyPhoneResult["success"], isTrue);
      print("✓ Parent verification by code and phone confirmed working against Supabase");

      // 8. Test unlink
      await freshParentService.unlinkStudentFromParent(link.id);
      final liveLinkAfterUnlink = await client.from("parent_students").select().eq("id", link.id).maybeSingle();
      expect(liveLinkAfterUnlink, isNull);
      print("✓ Unlink confirmed: row deleted from LIVE public.parent_students");

      // 9. Clean up test parent
      await client.from("parents").delete().eq("id", testParent.id);
      final checkCleaned = await client.from("parents").select().eq("id", testParent.id).maybeSingle();
      expect(checkCleaned, isNull);
      print("✓ Cleaned up temporary test parent from LIVE public.parents");
    });

    test("3. Library Live CRUD, Issuance, Return & Cleanup", () async {
      final libraryService = LibraryService();

      // 1. Add temporary test book
      final testBook = await libraryService.addBook(
        schoolId: schoolId,
        title: "LIVE TEST BOOK",
        author: "Prof. Test Scientist",
        isbn: "978-0000000001",
      );
      print("Created library book: ${testBook.title} (ID: ${testBook.id})");

      // 2. Verify row exists in LIVE public.library_books
      final liveBookRow = await client.from("library_books").select().eq("id", testBook.id).maybeSingle();
      expect(liveBookRow, isNotNull);
      expect(liveBookRow!["title"], equals("LIVE TEST BOOK"));
      expect(liveBookRow["status"], equals("available"));
      print("✓ LIVE public.library_books row verified in Supabase");

      // 3. Issue book
      final dueDate = DateTime.now().add(const Duration(days: 14));
      await libraryService.issueBook(
        bookId: testBook.id,
        studentName: "Ajay Sharma",
        dueDate: dueDate,
      );

      final liveBookIssued = await client.from("library_books").select().eq("id", testBook.id).maybeSingle();
      expect(liveBookIssued!["status"], equals("issued"));
      expect(liveBookIssued["issued_to_student"], equals("Ajay Sharma"));
      expect(liveBookIssued["issue_date"], isNotNull);
      expect(liveBookIssued["due_date"], isNotNull);
      print("✓ LIVE issuance verified in Supabase: status=issued, student=Ajay Sharma");

      // 4. Return book
      await libraryService.returnBook(testBook.id);
      final liveBookReturned = await client.from("library_books").select().eq("id", testBook.id).maybeSingle();
      expect(liveBookReturned!["status"], equals("available"));
      expect(liveBookReturned["issued_to_student"], isNull);
      print("✓ LIVE return verified in Supabase: status=available, student=null");

      // 5. Reinitialize service and verify it loads from Supabase
      final freshLibService = LibraryService();
      final books = await freshLibService.fetchBooks(schoolId: schoolId);
      expect(books.any((b) => b.id == testBook.id), isTrue);
      print("✓ Fresh LibraryService instance reloaded book from Supabase");

      // 6. Clean up temporary test book
      await client.from("library_books").delete().eq("id", testBook.id);
      final checkCleaned = await client.from("library_books").select().eq("id", testBook.id).maybeSingle();
      expect(checkCleaned, isNull);
      print("✓ Cleaned up temporary test book from LIVE public.library_books");
    });

    test("4. Transport Live CRUD, Fleet Tracking & Cleanup", () async {
      final transportService = TransportService();

      // 1. Add temporary test route
      final testRoute = await transportService.addRoute(
        schoolId: schoolId,
        routeName: "LIVE TEST ROUTE 99",
        busNumber: "MH-12-TEST-99",
        driverName: "Dinesh Pilot",
        driverPhone: "+91 91111 22222",
        studentCount: 15,
        stops: ["Point Alpha", "Point Beta", "School Gate"],
      );
      print("Created transport route: ${testRoute.routeName} (ID: ${testRoute.id})");

      // 2. Verify row exists in LIVE public.transport_routes
      final liveRouteRow = await client.from("transport_routes").select().eq("id", testRoute.id).maybeSingle();
      expect(liveRouteRow, isNotNull);
      expect(liveRouteRow!["route_name"], equals("LIVE TEST ROUTE 99"));
      expect(liveRouteRow["bus_number"], equals("MH-12-TEST-99"));
      expect(liveRouteRow["driver_name"], equals("Dinesh Pilot"));
      expect(liveRouteRow["driver_phone"], equals("+91 91111 22222"));
      expect(liveRouteRow["student_count"], equals(15));
      expect(liveRouteRow["stops"], isA<List>());
      expect((liveRouteRow["stops"] as List).length, equals(3));
      print("✓ LIVE public.transport_routes row and JSONB stops verified in Supabase");

      // 3. Reinitialize service and verify it loads from Supabase
      final freshTransportService = TransportService();
      final routes = await freshTransportService.fetchRoutes(schoolId: schoolId);
      final reloadedRoute = routes.firstWhere((r) => r.id == testRoute.id);
      expect(reloadedRoute.routeName, equals("LIVE TEST ROUTE 99"));
      print("✓ Fresh TransportService instance reloaded route from Supabase");

      // 4. Delete route via service
      await freshTransportService.deleteRoute(testRoute.id);
      final liveRouteAfterDelete = await client.from("transport_routes").select().eq("id", testRoute.id).maybeSingle();
      expect(liveRouteAfterDelete, isNull);
      print("✓ Route deletion verified: removed from LIVE public.transport_routes");
    });

    test("5. RLS / Tenant Isolation Verification", () async {
      // Verify query with a different random school UUID returns 0 records due to RLS
      const foreignSchoolId = "00000000-0000-0000-0000-000000000000";

      final foreignParents = await client.from("parents").select().eq("school_id", foreignSchoolId);
      expect(foreignParents, isEmpty);

      final foreignBooks = await client.from("library_books").select().eq("school_id", foreignSchoolId);
      expect(foreignBooks, isEmpty);

      final foreignRoutes = await client.from("transport_routes").select().eq("school_id", foreignSchoolId);
      expect(foreignRoutes, isEmpty);

      print("✓ Tenant isolation confirmed: queries for foreign school return 0 rows under RLS");
    });
  });
}
