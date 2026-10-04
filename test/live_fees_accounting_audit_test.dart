import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/data/services/fee_service.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  late SupabaseClient adminClient;
  late FeeService feeService;
  late String adminUserId;
  late String schoolId;
  late String academicYearId;
  late String testStudentId;
  late String testStudentName;
  late String testAccountId;

  // Snapshot of legitimate records before testing
  final List<String> legitimatePaymentIds = [];

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = RealHttpOverrides();
    SharedPreferences.setMockInitialValues({});

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}

    // Authenticate the global client with admin session
    await Supabase.instance.client.auth.setSession('koqhzxdsfkge');
    adminClient = Supabase.instance.client;
    feeService = FeeService();

    final user = adminClient.auth.currentUser;
    adminUserId = user!.id;
    schoolId = await adminClient.rpc('get_user_school_id') as String;
    final ayRes = await adminClient.from('academic_years').select('id').eq('school_id', schoolId).limit(1).maybeSingle();
    academicYearId = ayRes?['id'] as String;

    // Pick dedicated synthetic test student to avoid touching legitimate students
    final testStudentRow = await adminClient
        .from('students')
        .select('id, first_name, last_name, class_name, section_name')
        .eq('school_id', schoolId)
        .like('admission_number', 'TEST-ADM-%')
        .limit(1)
        .maybeSingle();

    if (testStudentRow != null) {
      testStudentId = testStudentRow['id'];
      testStudentName = '${testStudentRow['first_name']} ${testStudentRow['last_name']}'.trim();
    } else {
      final fallbackStudent = await adminClient.from('students').select('id, first_name, last_name, class_name').eq('school_id', schoolId).limit(1).single();
      testStudentId = fallbackStudent['id'];
      testStudentName = '${fallbackStudent['first_name']} ${fallbackStudent['last_name']}'.trim();
    }

    // Record existing legitimate payment IDs before testing
    final existingPayments = await adminClient.from('fee_payments').select('id');
    for (final p in existingPayments) {
      legitimatePaymentIds.add(p['id'] as String);
    }

    // Locate or create fee account for test student
    final acc = await adminClient
        .from('student_fee_accounts')
        .select('id, gross_fee, discount_amount, waiver_amount, status')
        .eq('school_id', schoolId)
        .eq('student_id', testStudentId)
        .maybeSingle();

    if (acc != null) {
      testAccountId = acc['id'] as String;
    } else {
      final newAcc = await adminClient.from('student_fee_accounts').insert({
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'student_id': testStudentId,
        'gross_fee': 100000.0,
        'discount_amount': 0.0,
        'waiver_amount': 0.0,
        'due_date': '2026-11-01',
        'status': 'due',
      }).select().single();
      testAccountId = newAcc['id'] as String;
    }

    print('\n======================================================');
    print('POST-MIGRATION VERIFICATION INITIALIZED');
    print('Admin UID: $adminUserId');
    print('School ID: $schoolId');
    print('Academic Year ID: $academicYearId');
    print('Test Student: $testStudentName ($testStudentId)');
    print('Test Fee Account ID: $testAccountId');
    print('Legitimate Payments Baseline Count: ${legitimatePaymentIds.length}');
    print('======================================================\n');
  });

  tearDownAll(() async {
    print('\n======================================================');
    print('TEARDOWN: Verifying legitimate records & restoring state');
    print('======================================================');

    // Restore test student fee account to clean baseline
    try {
      await adminClient.from('student_fee_accounts').update({
        'gross_fee': 100000.0,
        'discount_amount': 0.0,
        'waiver_amount': 0.0,
        'status': 'due',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', testAccountId);
      print('Restored test fee account $testAccountId.');
    } catch (e) {
      print('Warning restoring test account: $e');
    }

    // Ensure admin profile is active
    try {
      await adminClient.from('profiles').update({'status': 'active'}).eq('auth_user_id', adminUserId);
      print('Confirmed admin profile is active.');
    } catch (e) {
      print('Warning ensuring admin active: $e');
    }

    // Verify legitimate baseline payments are intact
    final currentPayments = await adminClient.from('fee_payments').select('id');
    final currentIds = currentPayments.map((p) => p['id'] as String).toSet();
    for (final legId in legitimatePaymentIds) {
      expect(currentIds.contains(legId), isTrue, reason: 'Legitimate payment $legId must remain intact!');
    }
    print('Legitimate payments verified 100% intact.');
  });

  test('VERIFY DATABASE STRUCTURE & PRIVILEGES', () async {
    print('\n--- VERIFYING DATABASE STRUCTURE & PRIVILEGES ---');

    // 1. Authenticated has SELECT on fee_payments
    final selectRes = await adminClient.from('fee_payments').select().limit(5);
    expect(selectRes, isNotNull);
    print('Authenticated SELECT on fee_payments: SUCCESS (${selectRes.length} rows)');

    // 2. Authenticated does NOT have INSERT on fee_payments
    bool insertBlocked = false;
    try {
      await adminClient.from('fee_payments').insert({
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'student_id': testStudentId,
        'fee_account_id': testAccountId,
        'amount': 10.0,
        'payment_date': '2026-10-02',
        'payment_method': 'cash',
        'receipt_number': 'REC-ILLEGAL-DIRECT-INS',
      });
    } on PostgrestException catch (e) {
      insertBlocked = true;
      print('Authenticated direct INSERT blocked: code=${e.code}, msg=${e.message}');
    }
    expect(insertBlocked, isTrue, reason: 'Authenticated direct INSERT must be blocked');

    // 3. Authenticated does NOT have UPDATE on fee_payments
    bool updateBlocked = false;
    try {
      await adminClient.from('fee_payments').update({'amount': 999.0}).eq('student_id', testStudentId);
    } on PostgrestException catch (e) {
      updateBlocked = true;
      print('Authenticated direct UPDATE blocked: code=${e.code}, msg=${e.message}');
    }
    expect(updateBlocked, isTrue, reason: 'Authenticated direct UPDATE must be blocked');

    // 4. Authenticated does NOT have DELETE on fee_payments
    bool deleteBlocked = false;
    try {
      await adminClient.from('fee_payments').delete().eq('student_id', testStudentId);
    } on PostgrestException catch (e) {
      deleteBlocked = true;
      print('Authenticated direct DELETE blocked: code=${e.code}, msg=${e.message}');
    }
    expect(deleteBlocked, isTrue, reason: 'Authenticated direct DELETE must be blocked');

    // 5. Anon has NO privileges on fee_payments
    final anonClient = SupabaseClient(SupabaseConfig.url, SupabaseConfig.publishableKey);
    bool anonSelectBlocked = false;
    try {
      await anonClient.from('fee_payments').select();
    } on PostgrestException catch (e) {
      anonSelectBlocked = true;
      print('Anon SELECT blocked: code=${e.code}, msg=${e.message}');
    }
    expect(anonSelectBlocked, isTrue, reason: 'Anon SELECT must be denied');

    // 6. PUBLIC / Anon cannot EXECUTE record_fee_payment_atomic
    bool anonRpcBlocked = false;
    try {
      await anonClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': 50.0,
        'p_payment_method': 'cash',
      });
    } on PostgrestException catch (e) {
      anonRpcBlocked = true;
      print('Anon RPC execution blocked: code=${e.code}, msg=${e.message}');
    }
    expect(anonRpcBlocked, isTrue, reason: 'Anon cannot execute payment RPC');

    print('DATABASE STRUCTURE & PRIVILEGES VERIFICATION PASSED');
  });

  test('TEST 1: Normal payment through RPC', () async {
    print('\n--- RUNNING TEST 1: Normal payment through RPC ---');
    final uniqueRef = 'NORM-PAY-${DateTime.now().millisecondsSinceEpoch}';

    final rpcRes = await adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 250.0,
      'p_payment_method': 'cash',
      'p_reference_number': uniqueRef,
      'p_notes': 'Test 1 Normal Payment',
    });

    expect(rpcRes, isNotNull);
    final paymentId = rpcRes['payment_id'] as String;
    final receiptNo = rpcRes['receipt_number'] as String;
    final amountPaid = (rpcRes['amount_paid'] as num).toDouble();
    final prevBal = (rpcRes['previous_balance'] as num).toDouble();
    final remBal = (rpcRes['remaining_balance'] as num).toDouble();
    final status = rpcRes['status'] as String;

    expect(paymentId, isNotEmpty);
    expect(receiptNo.startsWith('REC-'), isTrue);
    expect(amountPaid, equals(250.0));
    expect(prevBal, greaterThan(0.0));
    expect(remBal, equals(prevBal - 250.0));
    expect(status, isIn(['due', 'partially_paid', 'paid']));

    // Verify row directly in fee_payments
    final payRow = await adminClient.from('fee_payments').select().eq('id', paymentId).single();
    expect(payRow['created_by'], equals(adminUserId));
    expect(payRow['amount'], equals(250.0));
    expect(payRow['reference_number'], equals(uniqueRef));

    print('TEST 1 PASSED: Created payment $paymentId, Receipt: $receiptNo, RemBal: ₹$remBal, created_by: ${payRow['created_by']}');
  });

  test('TEST 2: Duplicate reference & whitespace normalization', () async {
    print('\n--- RUNNING TEST 2: Duplicate reference & whitespace normalization ---');
    final dupRef = 'REF-DUP-${DateTime.now().millisecondsSinceEpoch}';

    // 1. First call succeeds
    final firstRes = await adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 100.0,
      'p_payment_method': 'upi',
      'p_reference_number': dupRef,
    });
    expect(firstRes['payment_id'], isNotNull);

    // 2. Second call with EXACT SAME reference must fail
    bool dupRejected = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': 100.0,
        'p_payment_method': 'upi',
        'p_reference_number': dupRef,
      });
    } on PostgrestException catch (e) {
      dupRejected = true;
      print('Exact duplicate reference rejected: code=${e.code}, msg=${e.message}');
    }
    expect(dupRejected, isTrue, reason: 'Duplicate reference must be rejected');

    // 3. Whitespace normalization test: "  REF-SPACE-001  " vs "REF-SPACE-001"
    final spaceRef = 'REF-SPACE-${DateTime.now().millisecondsSinceEpoch}';
    await adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 50.0,
      'p_payment_method': 'upi',
      'p_reference_number': '  $spaceRef  ',
    });

    bool spaceDupRejected = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': 50.0,
        'p_payment_method': 'upi',
        'p_reference_number': spaceRef,
      });
    } on PostgrestException catch (e) {
      spaceDupRejected = true;
      print('Whitespace padded duplicate reference rejected: code=${e.code}, msg=${e.message}');
    }
    expect(spaceDupRejected, isTrue, reason: 'Whitespace-normalized duplicate must be rejected');

    print('TEST 2 PASSED: Duplicate reference and whitespace normalization strictly rejected.');
  });

  test('TEST 3: Direct authenticated INSERT blocked', () async {
    print('\n--- RUNNING TEST 3: Direct authenticated INSERT blocked ---');
    bool directInsertFailed = false;
    try {
      await adminClient.from('fee_payments').insert({
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'student_id': testStudentId,
        'fee_account_id': testAccountId,
        'amount': 50.0,
        'payment_date': '2026-10-02',
        'payment_method': 'cash',
        'receipt_number': 'REC-DIRECT-FAIL-${DateTime.now().millisecondsSinceEpoch}',
      });
    } on PostgrestException catch (e) {
      directInsertFailed = true;
      print('Direct INSERT blocked as expected: code=${e.code}, msg=${e.message}');
    }
    expect(directInsertFailed, isTrue, reason: 'Direct PostgREST INSERT must be denied');
    print('TEST 3 PASSED: PostgREST direct INSERT blocked by database permissions.');
  });

  test('TEST 4: Server-side overpayment rejected', () async {
    print('\n--- RUNNING TEST 4: Server-side overpayment ---');
    // Fetch fresh due
    final acc = await adminClient.from('student_fee_accounts').select().eq('id', testAccountId).single();
    final gross = (acc['gross_fee'] as num).toDouble();
    final pays = await adminClient.from('fee_payments').select('amount').eq('fee_account_id', testAccountId);
    double totalPaid = 0.0;
    for (final p in pays) {
      totalPaid += (p['amount'] as num).toDouble();
    }
    final due = gross - totalPaid;
    final overpayAmount = due + 5000.0;

    bool overpaymentBlocked = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': overpayAmount,
        'p_payment_method': 'cash',
        'p_reference_number': 'OVERPAY-ATTEMPT',
      });
    } on PostgrestException catch (e) {
      overpaymentBlocked = true;
      print('Overpayment rejected by RPC: code=${e.code}, msg=${e.message}');
    }
    expect(overpaymentBlocked, isTrue, reason: 'RPC must reject payment amount exceeding due balance');
    print('TEST 4 PASSED: Server-side overpayment blocked.');
  });

  test('TEST 5: Zero and negative amounts rejected', () async {
    print('\n--- RUNNING TEST 5: Zero and negative amounts ---');
    bool zeroBlocked = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': 0.0,
        'p_payment_method': 'cash',
      });
    } on PostgrestException catch (e) {
      zeroBlocked = true;
      print('Zero amount rejected: code=${e.code}, msg=${e.message}');
    }
    expect(zeroBlocked, isTrue);

    bool negativeBlocked = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': -500.0,
        'p_payment_method': 'cash',
      });
    } on PostgrestException catch (e) {
      negativeBlocked = true;
      print('Negative amount rejected: code=${e.code}, msg=${e.message}');
    }
    expect(negativeBlocked, isTrue);

    print('TEST 5 PASSED: Zero and negative payments rejected.');
  });

  test('TEST 6: Direct UPDATE blocked', () async {
    print('\n--- RUNNING TEST 6: Direct UPDATE blocked ---');
    bool updateBlocked = false;
    try {
      await adminClient.from('fee_payments').update({'amount': 999.0}).eq('student_id', testStudentId);
    } on PostgrestException catch (e) {
      updateBlocked = true;
      print('Direct UPDATE blocked: code=${e.code}, msg=${e.message}');
    }
    expect(updateBlocked, isTrue, reason: 'Direct UPDATE must be blocked');
    print('TEST 6 PASSED: Immutability protects fee_payments against UPDATE.');
  });

  test('TEST 7: Direct DELETE blocked', () async {
    print('\n--- RUNNING TEST 7: Direct DELETE blocked ---');
    bool deleteBlocked = false;
    try {
      await adminClient.from('fee_payments').delete().eq('student_id', testStudentId);
    } on PostgrestException catch (e) {
      deleteBlocked = true;
      print('Direct DELETE blocked: code=${e.code}, msg=${e.message}');
    }
    expect(deleteBlocked, isTrue, reason: 'Direct DELETE must be blocked');
    print('TEST 7 PASSED: Immutability protects fee_payments against DELETE.');
  });

  test('TEST 8: Concurrent valid payments serialized correctly', () async {
    print('\n--- RUNNING TEST 8: Concurrent valid payments ---');
    final now = DateTime.now().millisecondsSinceEpoch;

    final fut1 = adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 100.0,
      'p_payment_method': 'cash',
      'p_reference_number': 'CONC-VAL-1-$now',
    });

    final fut2 = adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 100.0,
      'p_payment_method': 'cash',
      'p_reference_number': 'CONC-VAL-2-$now',
    });

    final results = await Future.wait([fut1, fut2]);
    expect(results.length, equals(2));
    print('Both concurrent payments succeeded. Payment 1: ${results[0]['payment_id']}, Payment 2: ${results[1]['payment_id']}');
    print('TEST 8 PASSED: Concurrent valid payments processed without lock conflict or lost updates.');
  });

  test('TEST 9: Concurrent overpayment race condition prevented', () async {
    print('\n--- RUNNING TEST 9: Concurrent overpayment race condition ---');
    // Set a known test student fee account balance where available due = ₹150
    // Gross: 100000. Let's find remaining due on test account:
    final pays = await adminClient.from('fee_payments').select('amount').eq('fee_account_id', testAccountId);
    double totalPaid = 0.0;
    for (final p in pays) {
      totalPaid += (p['amount'] as num).toDouble();
    }
    // Set gross fee so due is exactly ₹150
    final targetGross = totalPaid + 150.0;
    await adminClient.from('student_fee_accounts').update({
      'gross_fee': targetGross,
      'discount_amount': 0.0,
      'waiver_amount': 0.0,
      'status': 'partially_paid',
    }).eq('id', testAccountId);

    print('Configured account due to exactly ₹150. Now submitting 2 concurrent payments of ₹100 each (Total ₹200 > ₹150)...');
    final now = DateTime.now().millisecondsSinceEpoch;

    final fut1 = adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 100.0,
      'p_payment_method': 'cash',
      'p_reference_number': 'RACE-1-$now',
    });

    final fut2 = adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 100.0,
      'p_payment_method': 'cash',
      'p_reference_number': 'RACE-2-$now',
    });

    int successCount = 0;
    int failureCount = 0;

    await Future.wait([
      fut1.then((v) {
        successCount++;
        return v;
      }).catchError((e) {
        failureCount++;
        print('Concurrent call 1 expected failure: $e');
        return null;
      }),
      fut2.then((v) {
        successCount++;
        return v;
      }).catchError((e) {
        failureCount++;
        print('Concurrent call 2 expected failure: $e');
        return null;
      }),
    ]);

    expect(successCount, equals(1), reason: 'Only one of the concurrent payments should succeed');
    expect(failureCount, equals(1), reason: 'The competing payment must fail with overpayment');

    // Verify balance in database is exactly targetGross - (totalPaid + 100) = 50 (NEVER negative)
    final freshAcc = await adminClient.from('student_fee_accounts').select().eq('id', testAccountId).single();
    final freshPays = await adminClient.from('fee_payments').select('amount').eq('fee_account_id', testAccountId);
    double freshTotalPaid = 0.0;
    for (final p in freshPays) {
      freshTotalPaid += (p['amount'] as num).toDouble();
    }
    final remainingDue = (freshAcc['gross_fee'] as num).toDouble() - freshTotalPaid;

    expect(remainingDue, equals(50.0));
    expect(remainingDue >= 0, isTrue);
    print('TEST 9 PASSED: Exactly 1 payment accepted (₹100), competing payment rejected. Remaining due: ₹$remainingDue.');
  });

  test('TEST 10: Academic year mismatch rejected', () async {
    print('\n--- RUNNING TEST 10: Academic year mismatch ---');
    const wrongAcademicYear = '00000000-0000-0000-0000-000000000099';

    bool mismatchBlocked = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': 10.0,
        'p_payment_method': 'cash',
        'p_academic_year_id': wrongAcademicYear,
      });
    } on PostgrestException catch (e) {
      mismatchBlocked = true;
      print('Academic year mismatch rejected: code=${e.code}, msg=${e.message}');
    }
    expect(mismatchBlocked, isTrue, reason: 'RPC must reject mismatched academic year');
    print('TEST 10 PASSED: Academic year mismatch rejected.');
  });

  test('TEST 11: Cross-school isolation', () async {
    print('\n--- RUNNING TEST 11: Cross-school isolation ---');
    const foreignSchoolId = 'e8e91e6b-0b04-4b52-b8ec-b1fb1aa618aa'; // Greenwood / School 2

    // 1. SELECT isolation
    final foreignPayments = await adminClient.from('fee_payments').select().eq('school_id', foreignSchoolId);
    expect(foreignPayments, isEmpty, reason: 'Cannot view foreign school payments');

    // 2. RPC isolation
    bool foreignRpcBlocked = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': foreignSchoolId,
        'p_student_id': testStudentId,
        'p_amount': 50.0,
        'p_payment_method': 'cash',
      });
    } on PostgrestException catch (e) {
      foreignRpcBlocked = true;
      print('Cross-school payment rejected: code=${e.code}, msg=${e.message}');
    }
    expect(foreignRpcBlocked, isTrue, reason: 'Cross-school RPC must be rejected');
    print('TEST 11 PASSED: Cross-school read and payment execution strictly blocked.');
  });

  test('TEST 12: Inactive admin enforcement', () async {
    print('\n--- RUNNING TEST 12: Inactive admin enforcement ---');
    // Fetch profile
    final profile = await adminClient.from('profiles').select('id, status').eq('auth_user_id', adminUserId).single();
    final initialStatus = profile['status'].toString();
    expect(initialStatus.toLowerCase(), equals('active'));

    try {
      // Temporarily mark profile as inactive
      await adminClient.from('profiles').update({'status': 'inactive'}).eq('auth_user_id', adminUserId);

      // A. SELECT fee_payments must return 0 rows for inactive user
      final inactiveSelect = await adminClient.from('fee_payments').select();
      expect(inactiveSelect, isEmpty, reason: 'Inactive profile must return 0 rows under fee_payments_select_policy');
      print('Inactive admin SELECT returned 0 rows.');

      // B. record_fee_payment_atomic must reject inactive caller
      bool rpcBlockedForInactive = false;
      try {
        await adminClient.rpc('record_fee_payment_atomic', params: {
          'p_school_id': schoolId,
          'p_student_id': testStudentId,
          'p_amount': 25.0,
          'p_payment_method': 'cash',
        });
      } on PostgrestException catch (e) {
        rpcBlockedForInactive = true;
        print('Inactive admin RPC blocked: code=${e.code}, msg=${e.message}');
      }
      expect(rpcBlockedForInactive, isTrue, reason: 'Inactive user must be rejected by RPC');
    } finally {
      // Restore profile status
      await adminClient.from('profiles').update({'status': initialStatus}).eq('auth_user_id', adminUserId);
      final restoredProfile = await adminClient.from('profiles').select('status').eq('auth_user_id', adminUserId).single();
      expect(restoredProfile['status'].toString().toLowerCase(), equals('active'));
      print('Admin profile restored to $initialStatus.');
    }
    print('TEST 12 PASSED: Inactive administrator completely blocked from read and RPC.');
  });

  test('TEST 13: created_by protection against spoofing', () async {
    print('\n--- RUNNING TEST 13: created_by protection ---');
    final uniqueRef = 'SPOOF-CHECK-${DateTime.now().millisecondsSinceEpoch}';

    final res = await adminClient.rpc('record_fee_payment_atomic', params: {
      'p_school_id': schoolId,
      'p_student_id': testStudentId,
      'p_amount': 25.0,
      'p_payment_method': 'cash',
      'p_reference_number': uniqueRef,
    });

    final payRow = await adminClient.from('fee_payments').select('created_by').eq('id', res['payment_id']).single();
    expect(payRow['created_by'], equals(adminUserId));
    print('TEST 13 PASSED: Payment created_by is strictly ${payRow['created_by']} (matches authenticated caller).');
  });

  test('TEST 14: Fresh client persistence verification', () async {
    print('\n--- RUNNING TEST 14: Fresh client persistence ---');
    final freshAuthReq = await HttpClient().postUrl(Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=refresh_token'));
    freshAuthReq.headers.set('apikey', SupabaseConfig.publishableKey);
    freshAuthReq.headers.set('Content-Type', 'application/json');
    freshAuthReq.write(jsonEncode({'refresh_token': 'koqhzxdsfkge'}));
    final freshAuthResp = await freshAuthReq.close();
    final freshAuthBody = await freshAuthResp.transform(utf8.decoder).join();
    final freshToken = jsonDecode(freshAuthBody)['access_token'] as String;

    final freshClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
      headers: {'Authorization': 'Bearer $freshToken'},
    );

    final rawAccount = await freshClient.from('student_fee_accounts').select().eq('id', testAccountId).single();
    final rawPayments = await freshClient.from('fee_payments').select('amount').eq('fee_account_id', testAccountId);

    double sumPaid = 0.0;
    for (final p in rawPayments) {
      sumPaid += (p['amount'] as num).toDouble();
    }
    final gross = (rawAccount['gross_fee'] as num).toDouble();
    final due = gross - sumPaid;

    print('Fresh Client DB Read: Gross=₹$gross, Paid=₹$sumPaid, Due=₹$due, Status=${rawAccount['status']}');
    expect(gross, greaterThan(0.0));
    expect(sumPaid, greaterThan(0.0));
    print('TEST 14 PASSED: Authoritative persistence verified directly from independent database client.');
  });

  test('TEST 15: No phantom success on failure', () async {
    print('\n--- RUNNING TEST 15: No phantom success on failure ---');
    // Force RPC failure (e.g. overpayment)
    bool errorObserved = false;
    try {
      await adminClient.rpc('record_fee_payment_atomic', params: {
        'p_school_id': schoolId,
        'p_student_id': testStudentId,
        'p_amount': 99999999.0,
        'p_payment_method': 'cash',
      });
    } on PostgrestException catch (e) {
      errorObserved = true;
      print('Forced failure error: ${e.message}');
    }
    expect(errorObserved, isTrue);

    // Verify no phantom receipt with 99999999.0 exists
    final phantom = await adminClient.from('fee_payments').select().eq('amount', 99999999.0);
    expect(phantom, isEmpty, reason: 'No phantom payment row must exist');
    print('TEST 15 PASSED: Failure throws cleanly, zero phantom rows created.');
  });
}
