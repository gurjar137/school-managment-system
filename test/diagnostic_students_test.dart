import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('Diagnose students and classes queries in Supabase', () async {
    final client = Supabase.instance.client;
    final authService = AuthService();
    final studentService = StudentService();
    const schoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';

    print('=== 1. DIAGNOSE UNANIMOUS / ANON QUERY TO STUDENTS ===');
    try {
      final anonRes = await client.from('students').select().eq('school_id', schoolId);
      print('Anon query count: ${anonRes.length}');
      print('Anon query rows: $anonRes');
    } catch (e) {
      print('Anon query exception: $e');
    }

    print('\n=== 2. CREATE / SIGN IN ADMIN WITH VALID PROFILE ===');
    final uniqueAdminNum = DateTime.now().millisecondsSinceEpoch;
    final adminEmail = 'admin_diag_${uniqueAdminNum}@school.edu';
    final adminPass = 'AdminPass123!';

    final adminSignupRes = await http.post(
      Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
      headers: {
        'apikey': SupabaseConfig.publishableKey,
        'Authorization': 'Bearer ${SupabaseConfig.publishableKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': adminEmail,
        'password': adminPass,
        'data': {
          'role': 'school_admin',
          'full_name': 'Diagnostic Admin',
          'school_id': schoolId,
        },
      }),
    );
    final adminJson = jsonDecode(adminSignupRes.body) as Map<String, dynamic>;
    final adminAuthId = (adminJson['id'] ?? (adminJson['user'] as Map<String, dynamic>?)?['id']) as String;
    print('Created admin auth id: $adminAuthId');

    // Create matching profile
    try {
      final profRes = await client.from('profiles').insert({
        'auth_user_id': adminAuthId,
        'school_id': schoolId,
        'full_name': 'Diagnostic Admin',
        'role': 'school_admin',
        'status': 'active',
      }).select();
      print('Created admin profile: $profRes');
    } catch (e) {
      print('Profile insert note: $e');
    }

    // Sign in client
    final adminProfile = await authService.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPass,
      requiresAdminPortal: true,
    );
    print('Logged in user: ${client.auth.currentUser?.email}');
    print('Logged in uid: ${client.auth.currentUser?.id}');
    print('Active profile role: ${adminProfile.role}');

    print('\n=== 3. QUERY HELPER RPCs ===');
    try {
      final helperSchool = await client.rpc('get_user_school_id');
      print('get_user_school_id() = $helperSchool');
      final helperRole = await client.rpc('get_user_role');
      print('get_user_role() = $helperRole');
    } catch (e) {
      print('Helper RPC exception: $e');
    }

    print('\n=== 4. QUERY STUDENTS AS AUTHENTICATED ADMIN ===');
    try {
      final allStudents = await client.from('students').select('*');
      print('Raw students count (no filter): ${allStudents.length}');
      if (allStudents.isNotEmpty) {
        print('Sample student row: ${allStudents.first}');
      }
    } catch (e) {
      print('Students select * exception: $e');
    }

    try {
      final schoolStudents = await client.from('students').select('*').eq('school_id', schoolId);
      print('School students count: ${schoolStudents.length}');
      for (final s in schoolStudents) {
        print('  - id: ${s['id']}, name: ${s['full_name'] ?? s['name'] ?? '${s['first_name']} ${s['last_name']}'}, adm: ${s['admission_number']}, class: ${s['class_name'] ?? s['class']}, section: ${s['section_name'] ?? s['section']}, status: ${s['status']}');
      }
    } catch (e) {
      print('Students school_id query exception: $e');
    }

    print('\n=== 5. QUERY STUDENT SERVICE getAllStudents ===');
    try {
      final serviceStudents = await studentService.getAllStudents(schoolId: schoolId);
      print('StudentService.getAllStudents count: ${serviceStudents.length}');
      for (final s in serviceStudents) {
        print('  - Model: ${s.name}, Class: ${s.className}, Section: ${s.section}, Adm: ${s.admissionNumber}');
      }
    } catch (e) {
      print('studentService.getAllStudents exception: $e');
    }

    print('\n=== 6. DIAGNOSE TOTAL CLASSES QUERY ===');
    try {
      final rawClasses = await client.from('classes').select().eq('school_id', schoolId);
      print('Classes count: ${rawClasses.length}');
      print('Classes: $rawClasses');
    } catch (e) {
      print('Classes query exception: $e');
    }
  });
}
