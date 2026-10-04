import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:school_app/core/config/supabase_config.dart";
import "package:school_app/data/services/teacher_service.dart";
import "dart:io";

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

  test("Query live teachers for Greenwood and check existing teacher data", () async {
    final client = Supabase.instance.client;
    final adminEmail = "admin_greenwood@testschool.edu";
    final adminPass = "GreenwoodPass123!";

    await client.auth.signInWithPassword(email: adminEmail, password: adminPass);
    print("Logged in user: ${client.auth.currentUser?.email}");

    // Query profiles directly
    final profs = await client.from("profiles").select().limit(50);
    print("All accessible profiles (${profs.length}):");
    for (final p in profs) {
      print("  - [${p['role']}] name: ${p['full_name'] ?? p['name']}, school: ${p['school_id']}, id: ${p['id']}");
    }

    final tService = TeacherService();
    final greenwoodSchoolId = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11";
    final teachers = await tService.getTeachers(schoolId: greenwoodSchoolId);
    print("Teachers for Greenwood (${teachers.length}):");
    for (final t in teachers) {
      print("  - id: ${t.id}, name: ${t.name}, subjects: ${t.subjects}, designation: ${t.designation}, class: ${t.assignedClass}, sec: ${t.assignedSection}");
    }

    final allTeachers = await tService.getTeachers();
    print("All teachers from TeacherService (${allTeachers.length}):");
    for (final t in allTeachers) {
      print("  - id: ${t.id}, name: ${t.name}, school: ${t.schoolId}, subjects: ${t.subjects}, designation: ${t.designation}, class: ${t.assignedClass}, sec: ${t.assignedSection}");
    }
  });
}
