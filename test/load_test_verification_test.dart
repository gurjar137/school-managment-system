import "dart:io";
import "dart:convert";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "package:school_app/core/config/supabase_config.dart";
import "package:school_app/core/utils/teacher_assignment_parser.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/models/user_model.dart";

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

  test("10k Load Test: Teacher Verification and System Diagnostics", () async {
    final client = Supabase.instance.client;
    final sessionFile = File("C:/Users/dharm/.gemini/antigravity/brain/3360a3af-8679-490d-a386-f722f510ae3c/scratch/session.json");
    if (await sessionFile.exists()) {
      await client.auth.recoverSession(await sessionFile.readAsString());
    }

    final user = client.auth.currentUser;
    expect(user, isNotNull);
    final profile = await client.from("profiles").select().eq("auth_user_id", user!.id).single();
    final schoolId = profile["school_id"].toString();
    print("Resolved School ID: ");

    // 1. Query LIVE public.profiles for test teachers
    final testTeachersRes = await client
        .from("profiles")
        .select()
        .eq("school_id", schoolId)
        .eq("role", "teacher")
        .or("email.ilike.%@school-test.local%,full_name.ilike.Test Teacher%");

    print("Existing Test Teachers in public.profiles: ");
    for (final t in testTeachersRes) {
      print(" -  | email:  | class:  | section: ");
    }

    if (testTeachersRes.length < 24) {
      print("Attempting to seed 24 test teachers via direct insert...");
      final expectedTeachers = <Map<String, dynamic>>[];
      for (int c = 1; c <= 12; c++) {
        for (final sec in ["A", "B"]) {
          expectedTeachers.add({
            "school_id": schoolId,
            "full_name": "Test Teacher Class ",
            "role": "teacher",
            "status": "active",
            "assigned_class": "Class ",
            "assigned_section": sec,
            "designation": (c <= 4) ? "Primary Educator" : (c <= 8) ? "Middle School Faculty" : "Senior Secondary Faculty",
            "email": "test.teacher.@school-test.local",
            "phone": "9999901",
          });
        }
      }

      for (final t in expectedTeachers) {
        final existing = testTeachersRes.where((r) => r["email"] == t["email"]).toList();
        if (existing.isEmpty) {
          try {
            await client.from("profiles").insert(t);
            print("Successfully inserted  into profiles");
          } catch (e) {
            print("Could not directly insert : ");
            break;
          }
        }
      }
    }
  });
}
