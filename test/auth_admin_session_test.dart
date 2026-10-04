import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
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

  test('Direct HTTP Auth Signup returns user without touching client session', () async {
    final uniqueNum = DateTime.now().millisecondsSinceEpoch;
    final testEmail = 'staff_unit_${uniqueNum}@example.com';
    final signupUri = Uri.parse('${SupabaseConfig.url}/auth/v1/signup');
    final res = await http.post(
      signupUri,
      headers: {
        'apikey': SupabaseConfig.publishableKey,
        'Authorization': 'Bearer ${SupabaseConfig.publishableKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': testEmail,
        'password': 'TempPassword123!',
        'data': {
          'role': 'teacher',
          'full_name': 'Test Teacher Isolated',
          'school_id': '6254bee9-151d-4332-8a1c-3994af7d2153',
        },
      }),
    );

    expect(res.statusCode, anyOf(200, 201));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final userId = body['id'] ?? (body['user'] as Map<String, dynamic>?)?['id'];
    expect(userId, isNotNull);
    expect(userId.toString().isNotEmpty, true);
  });

  test('Admin session is strictly PRESERVED when creating a new teacher account', () async {
    final client = Supabase.instance.client;
    final authService = AuthService();

    // 1. Create a fresh admin account in Supabase Auth & public.profiles
    final uniqueAdminNum = DateTime.now().millisecondsSinceEpoch;
    final adminEmail = 'admin_unit_${uniqueAdminNum}@testschool.edu';
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
          'full_name': 'Test School Admin',
          'school_id': '6254bee9-151d-4332-8a1c-3994af7d2153',
        },
      }),
    );
    final adminJson = jsonDecode(adminSignupRes.body) as Map<String, dynamic>;
    final adminAuthId = (adminJson['id'] ?? (adminJson['user'] as Map<String, dynamic>?)?['id']) as String;

    final adminProfile = await authService.signInWithEmailAndPassword(
      email: adminEmail,
      password: adminPass,
      requiresAdminPortal: true,
    );

    expect(adminProfile.role, UserRole.schoolAdmin);
    expect(client.auth.currentUser?.id, adminAuthId);
    expect(client.auth.currentUser?.email, adminEmail);

    // 2. Create a brand new teacher via createStaffAccount
    final uniqueNum = DateTime.now().millisecondsSinceEpoch;
    final teacherEmail = 'teacher_sess_${uniqueNum}@example.com';
    final teacherName = 'New Test Teacher $uniqueNum';

    final createdProfile = await authService.createStaffAccount(
      name: teacherName,
      email: teacherEmail,
      phone: '9876543210',
      empId: 'EMP-$uniqueNum',
      designation: 'Senior Faculty',
      subject: 'Science',
      assignedClass: '10 - B',
      password: 'TeacherPassword123!',
      role: UserRole.teacher,
    );

    // 3. Verify created teacher profile
    expect(createdProfile.email, teacherEmail);
    expect(createdProfile.role, UserRole.teacher);
    expect(createdProfile.assignedClass, '10');
    expect(createdProfile.assignedSection, 'B');
    expect(createdProfile.authUserId, isNot(adminAuthId));

    // 4. CRITICAL VERIFICATION: The active Supabase client user MUST STILL BE THE ADMIN!
    expect(
      client.auth.currentUser?.id,
      adminAuthId,
      reason: 'Active Supabase auth user ID must remain the logged-in Admin!',
    );
    expect(
      client.auth.currentUser?.email,
      adminEmail,
      reason: 'Active Supabase auth email must remain the logged-in Admin!',
    );

    // 5. Verify that teacher profile object is completely populated
    expect(createdProfile.id.isNotEmpty, true);
    expect(createdProfile.schoolId, '6254bee9-151d-4332-8a1c-3994af7d2153');
    expect(createdProfile.status, AccountStatus.active);
  });
}

