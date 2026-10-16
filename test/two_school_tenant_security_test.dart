import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/core/utils/uuid_generator.dart';

void main() {
  test('Two-School Tenant Security & Cross-School Isolation Test', () async {
    final url = SupabaseConfig.url;
    final anonKey = SupabaseConfig.publishableKey;

    const schoolA = '6254bee9-151d-4332-8a1c-3994af7d2153'; // KPS
    const schoolB = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'; // Greenwood

    // 1. Authenticate as Teacher 1A from School A
    final loginRes = await http.post(
      Uri.parse('$url/auth/v1/token?grant_type=password'),
      headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': 'test.teacher.1a@school-test.local', 'password': 'TestPass123!'}),
    );
    expect(loginRes.statusCode, equals(200));
    final tokenA = jsonDecode(loginRes.body)['access_token'] as String;

    final headersA = {
      'apikey': anonKey,
      'Authorization': 'Bearer $tokenA',
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };

    // 2. Cross-School SELECT: Teacher in School A attempts to query School B profiles
    final selectSchoolBProfiles = await http.get(
      Uri.parse('$url/rest/v1/profiles?school_id=eq.$schoolB&select=*'),
      headers: headersA,
    );
    expect(selectSchoolBProfiles.statusCode, equals(200));
    final profilesB = jsonDecode(selectSchoolBProfiles.body) as List;
    expect(profilesB, isEmpty, reason: 'School A teacher must NEVER see School B profiles');

    // 3. Cross-School SELECT: Teacher in School A attempts to query School B academic years
    final selectSchoolBAY = await http.get(
      Uri.parse('$url/rest/v1/academic_years?school_id=eq.$schoolB&select=*'),
      headers: headersA,
    );
    expect(selectSchoolBAY.statusCode, equals(200));
    final ayB = jsonDecode(selectSchoolBAY.body) as List;
    expect(ayB, isEmpty, reason: 'School A teacher must NEVER see School B academic years');

    // 4. Forged Cross-School INSERT: Teacher in School A attempts to insert a student into School B
    final forgedStudentInsert = await http.post(
      Uri.parse('$url/rest/v1/students'),
      headers: headersA,
      body: jsonEncode({
        'id': generateUuidV4(),
        'school_id': schoolB,
        'name': 'Malicious Injection Student',
        'admission_number': 'FORGED-001',
        'class_name': 'Class 10',
        'section_name': 'A',
      }),
    );
    expect(forgedStudentInsert.statusCode, isIn([400, 401, 403, 404, 409]),
      reason: 'Cross-school student insert must be blocked by RLS or foreign key');

    // 5. Forged Cross-School RPC: Caller attempts to create staff profile for School B
    final forgedRpc = await http.post(
      Uri.parse('$url/rest/v1/rpc/create_staff_profile'),
      headers: headersA,
      body: jsonEncode({
        'p_auth_user_id': generateUuidV4(),
        'p_school_id': schoolB,
        'p_full_name': 'Hacker Teacher',
        'p_role': 'teacher',
      }),
    );
    expect(forgedRpc.statusCode, isIn([400, 401, 403, 404]),
      reason: 'Cross-school RPC invocation must fail closed');
  });
}
