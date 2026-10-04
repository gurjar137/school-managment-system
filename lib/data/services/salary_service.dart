import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/salary_models.dart';
import '../models/academic_models.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';

class SalaryService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  final Map<String, SalaryStructure> _teacherSalaries = {};
  final List<SalaryPaymentRecord> _salaryRecords = [];
  bool _initialized = false;

  SalaryService() {
    _initPersistentCache();
  }

  // --- RESOLVE ACTIVE SCHOOL ID ---
  Future<String> fetchActiveSchoolId() async {
    if (_client != null && SupabaseConfig.isConfigured) {
      final user = _client!.auth.currentUser;
      if (user != null) {
        try {
          final prof = await _client!
              .from('profiles')
              .select('school_id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
          if (prof != null && prof['school_id'] != null && prof['school_id'].toString().isNotEmpty) {
            return prof['school_id'].toString();
          }
        } catch (_) {}
      }
      throw const TenantResolutionException('Active school could not be resolved for current user. Please log in again.');
    }
    return 'offline_mock_school';
  }

  // --- PERSISTENT CACHE INITIALIZATION ---
  Future<void> _initPersistentCache() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Restore Structures
      final structStr = prefs.getString('cached_salary_structures_json');
      if (structStr != null && structStr.isNotEmpty) {
        final decoded = jsonDecode(structStr) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            _teacherSalaries[key] = SalaryStructure.fromJson(val);
          }
        });
      }

      // 2. Restore Payment Records
      final recordsStr = prefs.getString('cached_salary_payments_json');
      if (recordsStr != null && recordsStr.isNotEmpty) {
        final decodedList = jsonDecode(recordsStr);
        if (decodedList is List) {
          for (final item in decodedList) {
            if (item is Map<String, dynamic>) {
              final rec = SalaryPaymentRecord.fromJson(item);
              if (!_salaryRecords.any((r) => r.paymentId == rec.paymentId)) {
                _salaryRecords.add(rec);
              }
            }
          }
        }
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[SalaryService Cache Restore Warning]: $e');
    }
  }

  Future<void> _persistStructures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mapToSave = _teacherSalaries.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString('cached_salary_structures_json', jsonEncode(mapToSave));
    } catch (e) {
      debugPrint('[SalaryService Structure Save Warning]: $e');
    }
  }

  Future<void> _persistPayments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _salaryRecords.map((r) => r.toJson()).toList();
      await prefs.setString('cached_salary_payments_json', jsonEncode(listToSave));
    } catch (e) {
      debugPrint('[SalaryService Payments Save Warning]: $e');
    }
  }

  // --- GET SALARY STRUCTURE ---
  Future<SalaryStructure> getSalaryStructure(String teacherId) async {
    await _initPersistentCache();

    if (_teacherSalaries.containsKey(teacherId)) {
      return _teacherSalaries[teacherId]!;
    }

    // Default structure for unconfigured faculty
    const defaultStructure = SalaryStructure(
      basicSalary: 24000.0,
      allowances: [
        SalaryAllowance(type: 'HRA', amount: 4000.0),
        SalaryAllowance(type: 'Transport', amount: 1000.0),
      ],
      deductions: [
        SalaryDeduction(type: 'PF', amount: 1000.0),
      ],
    );

    _teacherSalaries[teacherId] = defaultStructure;
    await _persistStructures();
    return defaultStructure;
  }

  // --- UPDATE SALARY STRUCTURE ---
  Future<void> updateSalaryStructure(String teacherId, SalaryStructure updated) async {
    await _initPersistentCache();
    _teacherSalaries[teacherId] = updated;
    await _persistStructures();

    // Supabase write if table exists
    if (_client != null && SupabaseConfig.isConfigured) {
      final schoolId = await fetchActiveSchoolId();
      try {
        await _client!.from('salary_structures').upsert({
          'school_id': schoolId,
          'staff_profile_id': teacherId,
          'basic_salary': updated.basicSalary,
          'allowances': updated.allowances.map((a) => a.toJson()).toList(),
          'deductions': updated.deductions.map((d) => d.toJson()).toList(),
          'net_salary': updated.netSalary,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } on PostgrestException catch (e) {
        debugPrint('[SalaryService updateSalaryStructure DB Error]: ${e.message}');
        if (e.code == 'PGRST205' || e.message.contains('does not exist')) {
          throw UnsupportedError('Backend table public.salary_structures is not yet provisioned in the live database.');
        }
        rethrow;
      }
    }
  }

  // --- GET SALARY HISTORY ---
  Future<List<SalaryPaymentRecord>> getSalaryHistory([String? teacherId]) async {
    await _initPersistentCache();

    if (_client != null && SupabaseConfig.isConfigured) {
      final schoolId = await fetchActiveSchoolId();
      try {
        var query = _client!
            .from('salary_payments')
            .select()
            .eq('school_id', schoolId);

        if (teacherId != null && teacherId.isNotEmpty) {
          query = query.eq('staff_profile_id', teacherId);
        }

        final res = await query.order('created_at', ascending: false);
        if (res.isNotEmpty) {
          for (final row in res) {
            final rec = SalaryPaymentRecord.fromJson(row);
            final idx = _salaryRecords.indexWhere((r) => r.paymentId == rec.paymentId);
            if (idx != -1) {
              _salaryRecords[idx] = rec;
            } else {
              _salaryRecords.insert(0, rec);
            }
          }
          await _persistPayments();
        }
      } catch (e) {
        debugPrint('[SalaryService getSalaryHistory DB Note]: $e');
      }
    }

    if (teacherId != null && teacherId.isNotEmpty) {
      return _salaryRecords.where((r) => r.teacherId == teacherId).toList();
    }
    return List.unmodifiable(_salaryRecords);
  }

  // --- RECORD SALARY PAYMENT ---
  Future<SalarySlipModel> recordSalaryPayment({
    required TeacherModel teacher,
    required String monthYear,
    required double amountPaid,
    required String paymentMethod,
    required String referenceNo,
    required String notes,
  }) async {
    await _initPersistentCache();
    final struct = await getSalaryStructure(teacher.id);
    final status = amountPaid >= struct.netSalary ? SalaryStatus.paid : SalaryStatus.partial;
    final now = DateTime.now();
    final seqNum = now.millisecondsSinceEpoch.toString().substring(7);

    String persistedId = 'SAL-$seqNum';

    if (_client != null && SupabaseConfig.isConfigured) {
      final schoolId = await fetchActiveSchoolId();
      try {
        final payload = {
          'school_id': schoolId,
          'staff_profile_id': teacher.id,
          'staff_name': teacher.name,
          'amount_paid': amountPaid,
          'net_salary': struct.netSalary,
          'payment_date': now.toIso8601String().substring(0, 10),
          'payment_method': paymentMethod.toLowerCase().replaceAll(' ', '_'),
          'reference_no': referenceNo.isNotEmpty ? referenceNo : 'SAL-TXN-$seqNum',
          'status': status == SalaryStatus.paid ? 'PAID' : 'PARTIAL',
        };

        final res = await _client!.from('salary_payments').insert(payload).select('id').maybeSingle();
        if (res != null && res['id'] != null) {
          persistedId = res['id'].toString();
        }
      } on PostgrestException catch (e) {
        debugPrint('[SalaryService recordSalaryPayment DB Error]: ${e.message}');
        if (e.code == 'PGRST205' || e.message.contains('does not exist')) {
          throw UnsupportedError('Backend table public.salary_payments is not yet provisioned in the live database.');
        }
        rethrow;
      }
    }

    final record = SalaryPaymentRecord(
      paymentId: persistedId,
      teacherId: teacher.id,
      staffName: teacher.name,
      month: monthYear,
      netSalary: struct.netSalary,
      amountPaid: amountPaid,
      paymentDate: now,
      paymentMethod: paymentMethod,
      referenceNo: referenceNo.isNotEmpty ? referenceNo : 'SAL-TXN-$seqNum',
      status: status,
      notes: notes,
    );

    _salaryRecords.insert(0, record);
    await _persistPayments();

    return SalarySlipModel(
      slipNo: 'SLIP-2026-$seqNum',
      month: monthYear,
      teacherName: teacher.name,
      employeeId: teacher.id.toUpperCase(),
      designation: teacher.designation,
      basicSalary: struct.basicSalary,
      allowances: struct.allowances,
      deductions: struct.deductions,
      netSalary: struct.netSalary,
      status: status,
      paymentDate: now,
    );
  }
}
