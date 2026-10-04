import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/auth_service.dart';

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

  test('Inspect live Supabase fee schema, academic years, and students', () async {
    final client = Supabase.instance.client;
    try {
      final authRes = await client.auth.signInWithPassword(
        email: 'admin@school.com',
        password: 'password123',
      );
      print('Auth success! User: ${authRes.user?.email} (${authRes.user?.id})');
    } catch (e) {
      print('Auth error: $e');
    }

    try {
      final accounts = await client.from('student_fee_accounts').select();
      print('student_fee_accounts count: ${accounts.length}');
      print('student_fee_accounts content: $accounts');
    } on PostgrestException catch (e) {
      print('student_fee_accounts SELECT error: code=${e.code}, msg=${e.message}, hint=${e.hint}');
    }

    try {
      final payments = await client.from('fee_payments').select();
      print('fee_payments count: ${payments.length}');
      print('fee_payments content: $payments');
    } on PostgrestException catch (e) {
      print('fee_payments SELECT error: code=${e.code}, msg=${e.message}, hint=${e.hint}');
    }

    try {
      final structures = await client.from('fee_structures').select();
      print('fee_structures count: ${structures.length}');
      print('fee_structures content: $structures');
    } on PostgrestException catch (e) {
      print('fee_structures SELECT error: code=${e.code}, msg=${e.message}, hint=${e.hint}');
    }

    try {
      final res = await client.from('schools').select();
      print('Schools: $res');
    } on PostgrestException catch (e) {
      print('Schools PostgrestException: message=${e.message}, code=${e.code}, details=${e.details}, hint=${e.hint}');
    } catch (e) {
      print('Schools other error: $e');
    }

    final rpcs = [
      'get_user_school_id',
      'get_user_role',
      'register_primary_school_admin',
      'lookup_school_by_code',
      'create_student_securely',
      'assign_fee_structure',
      'collect_student_fee_payment',
    ];
    for (final rpc in rpcs) {
      try {
        final res = await client.rpc(rpc);
        print('RPC $rpc: success -> $res');
      } on PostgrestException catch (e) {
        print('RPC $rpc: code=${e.code}, msg=${e.message}');
      } catch (e) {
        print('RPC $rpc: $e');
      }
    }

    try {
      final sch1 = await client.rpc('lookup_school_by_code', params: {'p_code': 'SCH001'});
      print('lookup_school_by_code SCH001: $sch1');
    } catch (e) {
      print('lookup_school_by_code SCH001 error: $e');
    }

    print('\n--- 2. STUDENTS (NO FILTER) ---');
    try {
      final students = await client.from('students').select().limit(5);
      print('students (unfiltered) count: ${students.length}');
      if (students.isNotEmpty) {
        for (final s in students) {
          print('  Student: ${s['first_name']} ${s['last_name']} (ID: ${s['id']}, school_id: ${s['school_id']}, class: ${s['class_name']}-${s['section_name']})');
        }
      }
    } catch (e) {
      print('students query error: $e');
    }

    print('\n--- 4. PROBING student_fee_accounts COLUMNS ---');
    final accountCols = [
      'id', 'school_id', 'academic_year_id', 'student_id', 'gross_fee', 'total_fee',
      'discount_amount', 'waiver_amount', 'net_fee', 'paid_amount', 'balance_amount',
      'due_date', 'notes', 'status', 'created_at', 'updated_at'
    ];
    final foundAccountCols = <String>[];
    for (final col in accountCols) {
      try {
        await client.from('student_fee_accounts').select(col).limit(1);
        foundAccountCols.add(col);
      } catch (_) {}
    }
    print('Found student_fee_accounts columns: $foundAccountCols');

    print('\n--- 5. PROBING fee_payments COLUMNS ---');
    final paymentCols = [
      'id', 'school_id', 'academic_year_id', 'student_id', 'fee_account_id', 'amount',
      'payment_date', 'payment_method', 'reference_number', 'receipt_number', 'notes',
      'created_by', 'created_at', 'updated_at'
    ];
    final foundPaymentCols = <String>[];
    for (final col in paymentCols) {
      try {
        await client.from('fee_payments').select(col).limit(1);
        foundPaymentCols.add(col);
      } catch (_) {}
    }
    print('Found fee_payments columns: $foundPaymentCols');

    print('\n--- 6. PROBING students COLUMNS ---');
    final studentCols = [
      'id', 'school_id', 'name', 'admission_number', 'roll_number', 'class_name',
      'section_name', 'gender', 'dob', 'parent_name', 'parent_phone', 'parent_email',
      'total_fee', 'paid_fee', 'pending_fee', 'fee_status', 'created_at', 'updated_at'
    ];
    final foundStudentCols = <String>[];
    for (final col in studentCols) {
      try {
        await client.from('students').select(col).limit(1);
        foundStudentCols.add(col);
      } catch (_) {}
    }
    print('Found students columns: $foundStudentCols');

    print('\n--- 9. PROBING student name & phone COLUMNS ---');
    final nameCols = [
      'first_name', 'last_name', 'name', 'full_name', 'student_name',
      'father_name', 'mother_name', 'parent_name', 'father_mobile', 'mother_mobile',
      'phone', 'parent_phone', 'mobile', 'email', 'parent_email', 'address', 'dob', 'date_of_birth'
    ];
    final foundNameCols = <String>[];
    for (final col in nameCols) {
      try {
        await client.from('students').select(col).limit(1);
        foundNameCols.add(col);
      } catch (_) {}
    }
    print('Found student name & contact columns: $foundNameCols');
  });
}
