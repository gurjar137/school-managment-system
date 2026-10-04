import 'dart:convert';
import 'dart:io';

void main() async {
  final url = 'https://hnvjenkeimzkdgkuwbeb.supabase.co';
  final anonKey = 'sb_publishable_19M-FirlFuK29VbdO1d87g_bNOysJwZ';
  final client = HttpClient();

  final req = await client.postUrl(Uri.parse(url + '/auth/v1/token?grant_type=password'));
  req.headers.set('apikey', anonKey);
  req.headers.set('Content-Type', 'application/json');
  req.write(jsonEncode({'email': 'admin@school.com', 'password': 'password123'}));
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  final resJson = jsonDecode(body) as Map<String, dynamic>;
  final token = resJson['access_token'];
  final user = resJson['user'];
  final uid = user['id'];
  print('Logged in as admin@school.com uid: ' + uid.toString());

  // Try inserting profile
  final pReq = await client.postUrl(Uri.parse(url + '/rest/v1/profiles'));
  pReq.headers.set('apikey', anonKey);
  pReq.headers.set('Authorization', 'Bearer ' + token);
  pReq.headers.set('Content-Type', 'application/json');
  pReq.headers.set('Prefer', 'return=representation');
  pReq.write(jsonEncode({
    'auth_user_id': uid,
    'school_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'full_name': 'Greenwood Admin',
    'role': 'school_admin',
    'status': 'active',
  }));
  final pResp = await pReq.close();
  final pBody = await pResp.transform(utf8.decoder).join();
  print('Profile insert attempt: status ' + pResp.statusCode.toString() + ' body: ' + pBody);

  client.close();
}
