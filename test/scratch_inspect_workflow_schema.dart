import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';

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

  test('Check register_primary_school_admin RPC', () async {
    final client = Supabase.instance.client;
    final authRes = await client.auth.signInWithPassword(
      email: 'admin@school.com',
      password: 'password123',
    );
    print('Logged in user: ${authRes.user?.id}');

    try {
      final res = await client.rpc('register_primary_school_admin', params: {
        'p_school_name': 'Greenwood International',
        'p_address': 'Main Campus',
        'p_admin_name': 'Lead Administrator',
        'p_admin_email': 'admin@school.com',
      });
      print('register_primary_school_admin RPC result: $res');
    } catch (e) {
      print('register_primary_school_admin RPC error: $e');
    }

    try {
      final sId = await client.rpc('get_user_school_id');
      print('get_user_school_id after register: $sId');
    } catch (e) {
      print('get_user_school_id error: $e');
    }

    try {
      final role = await client.rpc('get_user_role');
      print('get_user_role after register: $role');
    } catch (e) {
      print('get_user_role error: $e');
    }
  });
}
