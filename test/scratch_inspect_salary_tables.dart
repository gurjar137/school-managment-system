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

  test('Inspect live database tables for salary and payroll', () async {
    final client = Supabase.instance.client;
    try {
      final authRes = await client.auth.signInWithPassword(
        email: 'admin@school.com',
        password: 'password123',
      );
      print('Logged in user: ${authRes.user?.id}');
    } catch (e) {
      print('Login error: $e');
    }

    final tables = ['salary_structures', 'salary_payments', 'monthly_payrolls', 'salary_records'];
    for (final t in tables) {
      try {
        final res = await client.from(t).select().limit(1);
        print('TABLE $t: EXISTS, rows: $res');
      } catch (e) {
        print('TABLE $t: ERROR -> $e');
      }
    }
  });
}
