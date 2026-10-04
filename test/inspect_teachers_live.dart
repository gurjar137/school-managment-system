import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://hnvjenkeimzkdgkuwbeb.supabase.co';
  final anonKey = 'sb_publishable_19M-FirlFuK29VbdO1d87g_bNOysJwZ';

  // 1. Log in as admin@school.com (Greenwood)
  final loginRes = await http.post(
    Uri.parse('$url/auth/v1/token?grant_type=password'),
    headers: {
      'apikey': anonKey,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'email': 'admin@school.com', 'password': 'password123'}),
  );

  print('Login status: ${loginRes.statusCode}');
  String? token;
  if (loginRes.statusCode == 200) {
    final loginData = jsonDecode(loginRes.body);
    token = loginData['access_token'];
    print('Logged in user: ${loginData['user']['email']} ID: ${loginData['user']['id']}');
  }

  final headers = {
    'apikey': anonKey,
    if (token != null) 'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // 2. Fetch profiles
  final profRes = await http.get(
    Uri.parse('$url/rest/v1/profiles?select=id,full_name,role,school_id,phone,created_at&limit=50'),
    headers: headers,
  );
  print('Profiles (${profRes.statusCode}):');
  if (profRes.statusCode == 200) {
    final list = jsonDecode(profRes.body) as List;
    for (final p in list) {
      print(' - [${p['role']}] ${p['full_name']} (id: ${p['id']}, school: ${p['school_id']})');
    }
  } else {
    print(profRes.body);
  }

  // 3. Fetch schools
  final schRes = await http.get(
    Uri.parse('$url/rest/v1/schools?select=id,name&limit=20'),
    headers: headers,
  );
  print('Schools (${schRes.statusCode}): ${schRes.body}');

  // 4. Fetch academic years
  final ayRes = await http.get(
    Uri.parse('$url/rest/v1/academic_years?select=id,name,school_id,is_current&limit=20'),
    headers: headers,
  );
  print('Academic Years: ${ayRes.body}');

  // 5. Fetch classes
  final clsRes = await http.get(
    Uri.parse('$url/rest/v1/classes?select=id,name,school_id,academic_year_id&limit=20'),
    headers: headers,
  );
  print('Classes: ${clsRes.body}');

  // 6. Fetch sections
  final secRes = await http.get(
    Uri.parse('$url/rest/v1/sections?select=id,name,class_id,school_id&limit=20'),
    headers: headers,
  );
  print('Sections: ${secRes.body}');

  // 7. Check timetable_entries
  final ttRes = await http.get(
    Uri.parse('$url/rest/v1/timetable_entries?select=id,status,subject_name,teacher_name,class_id,day_of_week&limit=20'),
    headers: headers,
  );
  print('Timetable entries (${ttRes.statusCode}): ${ttRes.body}');
}
