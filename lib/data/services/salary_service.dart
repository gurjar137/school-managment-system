import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/salary_models.dart';
import '../models/academic_models.dart';
import '../models/staff_model.dart';
import '../../core/config/supabase_config.dart';
import 'tenant_resolver.dart';
import 'access_service.dart';
import '../repositories/school_repository.dart';

class SalaryDashboardMetrics {
  final int totalStaff;
  final int configuredStaff;
  final int unconfiguredStaff;
  final double monthlyPayrollExpense;
  final double paidSalariesTotal;
  final double pendingSalariesTotal;

  const SalaryDashboardMetrics({
    this.totalStaff = 0,
    this.configuredStaff = 0,
    this.unconfiguredStaff = 0,
    this.monthlyPayrollExpense = 0.0,
    this.paidSalariesTotal = 0.0,
    this.pendingSalariesTotal = 0.0,
  });
}

class SalaryService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  final Map<String, SalaryStructure> _salaryStructures = {}; // key: staffProfileId
  final List<MonthlyPayrollModel> _monthlyPayrolls = [];
  final List<SalaryPaymentRecord> _salaryPayments = [];
  final AccessService _accessService = AccessService();
  bool _initialized = false;

  SalaryService() {
    _initPersistentCache();
  }

  // --- RESOLVE ACTIVE SCHOOL ID ---
  Future<String> fetchActiveSchoolId() async {
    return TenantResolver.resolveActiveSchoolId(client: _client);
  }

  // --- CACHE KEYS ---
  String _structCacheKey(String? schoolId) =>
      'cached_salary_structures_${schoolId?.trim() ?? "default"}';
  String _payrollCacheKey(String? schoolId) =>
      'cached_monthly_payrolls_${schoolId?.trim() ?? "default"}';
  String _paymentCacheKey(String? schoolId) =>
      'cached_salary_payments_${schoolId?.trim() ?? "default"}';

  // --- PERSISTENT CACHE INITIALIZATION ---
  Future<void> _initPersistentCache([String? schoolId]) async {
    if (_initialized && schoolId == null) return;
    try {
      final sId = schoolId ?? await fetchActiveSchoolId();
      final prefs = await SharedPreferences.getInstance();

      // 1. Restore Structures
      final structStr = prefs.getString(_structCacheKey(sId)) ?? prefs.getString('cached_salary_structures_json');
      if (structStr != null && structStr.isNotEmpty) {
        final decoded = jsonDecode(structStr) as Map<String, dynamic>;
        decoded.forEach((key, val) {
          if (val is Map<String, dynamic>) {
            _salaryStructures[key] = SalaryStructure.fromJson(val);
          }
        });
      }

      // 2. Restore Monthly Payrolls
      final payrollStr = prefs.getString(_payrollCacheKey(sId));
      if (payrollStr != null && payrollStr.isNotEmpty) {
        final decodedList = jsonDecode(payrollStr);
        if (decodedList is List) {
          for (final item in decodedList) {
            if (item is Map<String, dynamic>) {
              final pr = MonthlyPayrollModel.fromJson(item);
              final idx = _monthlyPayrolls.indexWhere((p) => p.id == pr.id);
              if (idx != -1) {
                _monthlyPayrolls[idx] = pr;
              } else {
                _monthlyPayrolls.add(pr);
              }
            }
          }
        }
      }

      // 3. Restore Payment Records
      final recordsStr = prefs.getString(_paymentCacheKey(sId)) ?? prefs.getString('cached_salary_payments_json');
      if (recordsStr != null && recordsStr.isNotEmpty) {
        final decodedList = jsonDecode(recordsStr);
        if (decodedList is List) {
          for (final item in decodedList) {
            if (item is Map<String, dynamic>) {
              final rec = SalaryPaymentRecord.fromJson(item);
              final idx = _salaryPayments.indexWhere((r) => r.paymentId == rec.paymentId);
              if (idx != -1) {
                _salaryPayments[idx] = rec;
              } else {
                _salaryPayments.add(rec);
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

  Future<void> _persistStructures([String? schoolId]) async {
    try {
      final sId = schoolId ?? await fetchActiveSchoolId();
      final prefs = await SharedPreferences.getInstance();
      final mapToSave = _salaryStructures.map((k, v) => MapEntry(k, v.toJson(schoolId: sId)));
      await prefs.setString(_structCacheKey(sId), jsonEncode(mapToSave));
    } catch (e) {
      debugPrint('[SalaryService Structure Save Warning]: $e');
    }
  }

  Future<void> _persistPayrolls([String? schoolId]) async {
    try {
      final sId = schoolId ?? await fetchActiveSchoolId();
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _monthlyPayrolls
          .where((p) => p.schoolId.isEmpty || p.schoolId == sId)
          .map((p) => p.toJson(schoolId: sId))
          .toList();
      await prefs.setString(_payrollCacheKey(sId), jsonEncode(listToSave));
    } catch (e) {
      debugPrint('[SalaryService Payrolls Save Warning]: $e');
    }
  }

  Future<void> _persistPayments([String? schoolId]) async {
    try {
      final sId = schoolId ?? await fetchActiveSchoolId();
      final prefs = await SharedPreferences.getInstance();
      final listToSave = _salaryPayments
          .where((r) => r.schoolId.isEmpty || r.schoolId == sId)
          .map((r) => r.toJson(schoolId: sId))
          .toList();
      await prefs.setString(_paymentCacheKey(sId), jsonEncode(listToSave));
    } catch (e) {
      debugPrint('[SalaryService Payments Save Warning]: $e');
    }
  }

  // ===========================================================================
  // SECTION 1: SALARY STRUCTURE OPERATIONS
  // ===========================================================================

  /// Returns true if a staff member has a configured salary structure.
  Future<bool> hasSalaryConfigured(String staffId, {String? schoolId}) async {
    await _initPersistentCache(schoolId);
    return _salaryStructures.containsKey(staffId) && _salaryStructures[staffId]!.basicSalary > 0;
  }

  /// Gets the active salary structure for a staff member.
  /// If unconfigured, returns null (never fabricates fake numbers).
  Future<SalaryStructure?> getSalaryStructure(String staffId, {String? schoolId}) async {
    final sId = schoolId ?? await fetchActiveSchoolId();
    await _initPersistentCache(sId);

    // 1. Check local cache
    if (_salaryStructures.containsKey(staffId)) {
      return _salaryStructures[staffId];
    }

    // 2. Query Supabase if configured
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await client
            .from('salary_structures')
            .select()
            .eq('school_id', sId)
            .eq('staff_profile_id', staffId)
            .order('effective_from', ascending: false)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          final struct = SalaryStructure.fromJson(res);
          _salaryStructures[staffId] = struct;
          await _persistStructures(sId);
          return struct;
        }
      } catch (e) {
        debugPrint('[SalaryService getSalaryStructure DB Note]: $e');
      }
    }

    return null; // Legitimate unconfigured state
  }

  /// Sets or updates an employee's salary structure with effective date.
  Future<SalaryStructure> updateSalaryStructure(
    String staffId,
    SalaryStructure structure, {
    String? schoolId,
    String? adminName,
  }) async {
    final sId = schoolId ?? (structure.schoolId.isNotEmpty ? structure.schoolId : await fetchActiveSchoolId());
    await _initPersistentCache(sId);

    final enriched = structure.copyWith(
      id: structure.id.isNotEmpty ? structure.id : 'struct_${staffId}_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: sId,
      staffProfileId: staffId,
      updatedAt: DateTime.now(),
    );

    _salaryStructures[staffId] = enriched;
    await _persistStructures(sId);

    _accessService.logActivity(
      'Configured Salary Structure',
      'Configured basic salary of ₹${enriched.basicSalary.toStringAsFixed(0)} (Net: ₹${enriched.netSalary.toStringAsFixed(0)}) for ${enriched.staffName.isNotEmpty ? enriched.staffName : staffId}',
      'Staff Payroll',
      adminName: adminName ?? 'School Administrator',
    );

    // Supabase synchronization
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('salary_structures').upsert(enriched.toJson(schoolId: sId));
      } catch (e) {
        debugPrint('[SalaryService updateSalaryStructure DB Note]: $e');
      }
    }

    return enriched;
  }

  // ===========================================================================
  // SECTION 2: MONTHLY PAYROLL GENERATION & CALCULATIONS
  // ===========================================================================

  /// Fetches monthly payroll records for a specific school and month.
  Future<List<MonthlyPayrollModel>> getMonthlyPayrollsForSchool(
    String monthYear, {
    String? schoolId,
  }) async {
    final sId = schoolId ?? await fetchActiveSchoolId();
    await _initPersistentCache(sId);

    // Sync from Supabase if table exists
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await client
            .from('monthly_payrolls')
            .select()
            .eq('school_id', sId)
            .eq('month_year', monthYear);

        if (res.isNotEmpty) {
          for (final row in res) {
            final pr = MonthlyPayrollModel.fromJson(row);
            final idx = _monthlyPayrolls.indexWhere((p) => p.id == pr.id);
            if (idx != -1) {
              _monthlyPayrolls[idx] = pr;
            } else {
              _monthlyPayrolls.add(pr);
            }
          }
          await _persistPayrolls(sId);
        }
      } catch (e) {
        debugPrint('[SalaryService getMonthlyPayrollsForSchool DB Note]: $e');
      }
    }

    return _monthlyPayrolls
        .where((p) => p.monthYear == monthYear && (p.schoolId.isEmpty || p.schoolId == sId))
        .toList();
  }

  /// Generates or recalculates monthly payroll for all eligible teachers/staff in a school.
  /// Prevents duplication and accurately accounts for all valid posted payments for the period.
  Future<List<MonthlyPayrollModel>> generateMonthlyPayroll({
    required String schoolId,
    required String monthYear,
    List<TeacherModel>? teachers,
    List<StaffMemberModel>? staff,
    String? adminName,
    String? generatedBy,
  }) async {
    final creator = adminName ?? generatedBy;
    await _initPersistentCache(schoolId);
    final results = <MonthlyPayrollModel>[];
    final now = DateTime.now();

    // Collect all employee profiles
    final employeeEntries = <Map<String, dynamic>>[];
    if (teachers != null) {
      for (final t in teachers) {
        employeeEntries.add({
          'id': t.id,
          'name': t.name,
          'empId': t.employeeId,
          'designation': t.designation,
          'dept': 'Academic Faculty',
        });
      }
    }

    if (staff != null) {
      for (final s in staff) {
        if (!employeeEntries.any((e) => e['id'] == s.id || e['empId'] == s.employeeId)) {
          employeeEntries.add({
            'id': s.id,
            'name': s.name,
            'empId': s.employeeId,
            'designation': s.designation,
            'dept': s.isTeacher ? 'Academic Faculty' : 'Administrative Staff',
          });
        }
      }
    }

    for (final emp in employeeEntries) {
      final staffId = emp['id'] as String;
      final staffName = emp['name'] as String;
      final empCode = emp['empId'] as String;
      final designation = emp['designation'] as String;
      final dept = emp['dept'] as String;

      final struct = await getSalaryStructure(staffId, schoolId: schoolId);
      final payrollId = 'PRL-$schoolId-$staffId-${monthYear.replaceAll(" ", "_")}';

      // Find existing payments allocated to this staff and period
      final paymentsForPeriod = _salaryPayments.where((p) {
        final matchesStaff = (p.teacherId == staffId || p.staffName == staffName);
        final matchesMonth = p.month.toLowerCase().trim() == monthYear.toLowerCase().trim();
        final matchesSchool = p.schoolId.isEmpty || p.schoolId == schoolId;
        return matchesStaff && matchesMonth && matchesSchool;
      }).toList();

      final totalPaid = paymentsForPeriod.fold(0.0, (sum, p) => sum + p.amountPaid);

      if (struct == null || struct.basicSalary <= 0) {
        // Unconfigured employee payroll record
        final unconfiguredModel = MonthlyPayrollModel(
          id: payrollId,
          schoolId: schoolId,
          staffProfileId: staffId,
          staffName: staffName,
          employeeId: empCode,
          designation: designation,
          department: dept,
          monthYear: monthYear,
          basicSalary: 0.0,
          allowances: const [],
          deductions: const [],
          grossSalary: 0.0,
          netPayable: 0.0,
          amountPaid: totalPaid,
          remainingBalance: 0.0,
          status: SalaryStatus.notConfigured,
          generatedAt: now,
          payments: paymentsForPeriod,
        );

        final idx = _monthlyPayrolls.indexWhere((p) => p.id == payrollId);
        if (idx != -1) {
          _monthlyPayrolls[idx] = unconfiguredModel;
        } else {
          _monthlyPayrolls.add(unconfiguredModel);
        }
        results.add(unconfiguredModel);
      } else {
        // Configured employee payroll record
        final netPayable = struct.netSalary;
        final remaining = (netPayable - totalPaid).clamp(0.0, double.infinity);
        SalaryStatus status;

        if (totalPaid >= netPayable) {
          status = SalaryStatus.paid;
        } else if (totalPaid > 0) {
          status = SalaryStatus.partial;
        } else {
          status = SalaryStatus.pending;
        }

        final payrollModel = MonthlyPayrollModel(
          id: payrollId,
          schoolId: schoolId,
          staffProfileId: staffId,
          staffName: staffName,
          employeeId: empCode,
          designation: designation,
          department: dept,
          monthYear: monthYear,
          basicSalary: struct.basicSalary,
          allowances: struct.allowances,
          deductions: struct.deductions,
          grossSalary: struct.grossSalary,
          netPayable: netPayable,
          amountPaid: totalPaid,
          remainingBalance: remaining,
          status: status,
          generatedAt: now,
          payments: paymentsForPeriod,
        );

        final idx = _monthlyPayrolls.indexWhere((p) => p.id == payrollId);
        if (idx != -1) {
          _monthlyPayrolls[idx] = payrollModel;
        } else {
          _monthlyPayrolls.add(payrollModel);
        }
        results.add(payrollModel);
      }
    }

    await _persistPayrolls(schoolId);

    _accessService.logActivity(
      'Generated Monthly Payroll',
      'Generated and reconciled payroll for $monthYear (${results.length} staff members)',
      'Staff Payroll',
      adminName: creator ?? 'School Administrator',
    );

    // Supabase sync
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final payloads = results.map((r) => r.toJson(schoolId: schoolId)).toList();
        await client.from('monthly_payrolls').upsert(payloads);
      } catch (e) {
        debugPrint('[SalaryService generateMonthlyPayroll DB Note]: $e');
      }
    }

    return results;
  }

  // ===========================================================================
  // SECTION 3: SALARY PAYMENT RECORDING & TRANSACTIONS
  // ===========================================================================

  /// Records an actual salary disbursement transaction.
  /// Deducts from the staff member's remaining balance for that month.
  Future<SalarySlipModel> recordSalaryPayment({
    String? staffId,
    String? staffName,
    String? employeeId,
    String? designation,
    TeacherModel? teacher,
    required String monthYear,
    required double amountPaid,
    required String paymentMethod,
    required String referenceNo,
    required String notes,
    String? schoolId,
    String? adminName,
    SchoolRepository? repo,
  }) async {
    final effectiveStaffId = staffId ?? teacher?.id ?? '';
    final effectiveStaffName = staffName ?? teacher?.name ?? '';
    final effectiveEmpId = employeeId ?? teacher?.employeeId ?? effectiveStaffId;
    final effectiveDesignation = designation ?? teacher?.designation ?? 'Faculty / Staff';
    final sId = schoolId ?? teacher?.schoolId ?? await fetchActiveSchoolId();
    await _initPersistentCache(sId);

    if (amountPaid <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    // Resolve salary structure
    final struct = await getSalaryStructure(effectiveStaffId, schoolId: sId);
    if (struct == null || struct.basicSalary <= 0) {
      throw StateError('Cannot record payment: Salary structure is not configured for $effectiveStaffName.');
    }

    // Resolve or generate current payroll for this period
    final payrollId = 'PRL-$sId-$effectiveStaffId-${monthYear.replaceAll(" ", "_")}';
    var payrollIdx = _monthlyPayrolls.indexWhere((p) => p.id == payrollId);

    double currentPaid = 0.0;
    if (payrollIdx != -1) {
      currentPaid = _monthlyPayrolls[payrollIdx].amountPaid;
    } else {
      // Find historical payments for this period
      final existingPayments = _salaryPayments.where((p) =>
          p.month == monthYear &&
          (p.teacherId == effectiveStaffId || p.staffName == effectiveStaffName) &&
          (p.schoolId.isEmpty || p.schoolId == sId));
      currentPaid = existingPayments.fold(0.0, (sum, p) => sum + p.amountPaid);
    }

    final newTotalPaid = currentPaid + amountPaid;
    final netPayable = struct.netSalary;
    final newRemaining = (netPayable - newTotalPaid).clamp(0.0, double.infinity);

    SalaryStatus status;
    if (newTotalPaid >= netPayable) {
      status = SalaryStatus.paid;
    } else if (newTotalPaid > 0) {
      status = SalaryStatus.partial;
    } else {
      status = SalaryStatus.pending;
    }

    final now = DateTime.now();
    final seqNum = now.millisecondsSinceEpoch.toString().substring(7);
    final paymentId = 'PAY-$sId-$seqNum';
    final txnRef = referenceNo.trim().isNotEmpty ? referenceNo.trim() : 'TXN-$seqNum';

    // 1. Create Payment Record
    final paymentRecord = SalaryPaymentRecord(
      paymentId: paymentId,
      payrollId: payrollId,
      schoolId: sId,
      teacherId: effectiveStaffId,
      staffName: effectiveStaffName,
      month: monthYear,
      netSalary: netPayable,
      amountPaid: amountPaid,
      paymentDate: now,
      paymentMethod: paymentMethod,
      referenceNo: txnRef,
      status: status,
      notes: notes,
      recordedBy: adminName ?? 'School Administrator',
      createdAt: now,
    );

    _salaryPayments.insert(0, paymentRecord);
    await _persistPayments(sId);

    // 2. Update or insert MonthlyPayrollModel
    final updatedPayroll = MonthlyPayrollModel(
      id: payrollId,
      schoolId: sId,
      staffProfileId: effectiveStaffId,
      staffName: effectiveStaffName,
      employeeId: effectiveEmpId,
      designation: effectiveDesignation,
      department: 'Academic Faculty',
      monthYear: monthYear,
      basicSalary: struct.basicSalary,
      allowances: struct.allowances,
      deductions: struct.deductions,
      grossSalary: struct.grossSalary,
      netPayable: netPayable,
      amountPaid: newTotalPaid,
      remainingBalance: newRemaining,
      status: status,
      generatedAt: payrollIdx != -1 ? _monthlyPayrolls[payrollIdx].generatedAt : now,
      finalizedAt: status == SalaryStatus.paid ? now : null,
      payments: [..._salaryPayments.where((p) => p.payrollId == payrollId || (p.month == monthYear && p.teacherId == effectiveStaffId))],
    );

    if (payrollIdx != -1) {
      _monthlyPayrolls[payrollIdx] = updatedPayroll;
    } else {
      _monthlyPayrolls.add(updatedPayroll);
    }
    await _persistPayrolls(sId);

    // 3. Dispatch in-app notification to employee
    if (repo != null) {
      final notif = NotificationModel(
        id: 'notif_salary_${now.millisecondsSinceEpoch}',
        schoolId: sId,
        recipientId: effectiveStaffId,
        recipientRole: 'Teacher',
        title: 'Salary Disbursed: ₹${amountPaid.toStringAsFixed(0)}',
        message: 'Your salary installment for $monthYear (₹${amountPaid.toStringAsFixed(0)}) has been disbursed via $paymentMethod. Ref: $txnRef.',
        timestamp: now,
        category: 'Fees',
        isUnread: true,
        relatedRecordId: paymentId,
        relatedRecordType: 'fee',
      );
      await repo.addNotification(notif);
    }

    // 4. Audit Log
    _accessService.logActivity(
      'Recorded Salary Payment',
      'Disbursed ₹${amountPaid.toStringAsFixed(0)} to $effectiveStaffName for $monthYear via $paymentMethod. Remaining due: ₹${newRemaining.toStringAsFixed(0)}',
      'Staff Payroll',
      adminName: adminName ?? 'School Administrator',
    );

    // 5. Supabase synchronization
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('salary_payments').insert(paymentRecord.toJson(schoolId: sId));
        await client.from('monthly_payrolls').upsert(updatedPayroll.toJson(schoolId: sId));
      } catch (e) {
        debugPrint('[SalaryService recordSalaryPayment DB Note]: $e');
      }
    }

    return SalarySlipModel(
      slipNo: 'SLIP-${now.year}-$seqNum',
      month: monthYear,
      teacherName: effectiveStaffName,
      employeeId: effectiveEmpId.isNotEmpty ? effectiveEmpId : effectiveStaffId.toUpperCase(),
      designation: effectiveDesignation,
      basicSalary: struct.basicSalary,
      allowances: struct.allowances,
      deductions: struct.deductions,
      netSalary: netPayable,
      amountPaid: newTotalPaid,
      remainingBalance: newRemaining,
      status: status,
      paymentDate: now,
      paymentMethod: paymentMethod,
      referenceNo: txnRef,
      schoolName: '',
    );
  }

  // ===========================================================================
  // SECTION 4: PAYMENT HISTORY & REPORTING
  // ===========================================================================

  /// Fetches historical salary payments for a staff member or entire school.
  Future<List<SalaryPaymentRecord>> getSalaryHistory([String? staffId, String? schoolId]) async {
    final sId = schoolId ?? await fetchActiveSchoolId();
    await _initPersistentCache(sId);

    // Sync from Supabase if table exists
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        var query = client
            .from('salary_payments')
            .select()
            .eq('school_id', sId);

        if (staffId != null && staffId.isNotEmpty) {
          query = query.eq('staff_profile_id', staffId);
        }

        final res = await query.order('payment_date', ascending: false).limit(100);
        if (res.isNotEmpty) {
          for (final row in res) {
            final rec = SalaryPaymentRecord.fromJson(row);
            final idx = _salaryPayments.indexWhere((r) => r.paymentId == rec.paymentId);
            if (idx != -1) {
              _salaryPayments[idx] = rec;
            } else {
              _salaryPayments.add(rec);
            }
          }
          await _persistPayments(sId);
        }
      } catch (e) {
        debugPrint('[SalaryService getSalaryHistory DB Note]: $e');
      }
    }

    return _salaryPayments.where((r) {
      final matchesSchool = r.schoolId.isEmpty || r.schoolId == sId;
      if (!matchesSchool) return false;
      if (staffId != null && staffId.isNotEmpty && r.teacherId != staffId) return false;
      return true;
    }).toList();
  }

  /// Calculates live summary metrics for the Salary Dashboard.
  Future<SalaryDashboardMetrics> getSalaryDashboardMetrics({
    String? schoolId,
    String? monthYear,
    List<TeacherModel>? teachers,
    List<StaffMemberModel>? staff,
  }) async {
    final sId = schoolId ?? await fetchActiveSchoolId();
    final mYear = monthYear ?? 'October 2026';
    await _initPersistentCache(sId);

    // Make sure payroll is calculated for the selected month
    final payrolls = await getMonthlyPayrollsForSchool(mYear, schoolId: sId);

    int totalStaffCount = 0;
    int configuredCount = 0;
    int unconfiguredCount = 0;

    final staffIds = <String>{};
    if (teachers != null) {
      for (final t in teachers) {
        staffIds.add(t.id);
      }
    }
    if (staff != null) {
      for (final s in staff) {
        staffIds.add(s.id);
      }
    }
    for (final k in _salaryStructures.keys) {
      staffIds.add(k);
    }

    totalStaffCount = staffIds.length;
    for (final id in staffIds) {
      if (_salaryStructures.containsKey(id) && _salaryStructures[id]!.basicSalary > 0) {
        configuredCount++;
      } else {
        unconfiguredCount++;
      }
    }

    double totalExpense = 0.0;
    double totalPaid = 0.0;
    double totalPending = 0.0;

    for (final pr in payrolls) {
      totalExpense += pr.netPayable;
      totalPaid += pr.amountPaid;
      totalPending += pr.remainingBalance;
    }

    return SalaryDashboardMetrics(
      totalStaff: totalStaffCount,
      configuredStaff: configuredCount,
      unconfiguredStaff: unconfiguredCount,
      monthlyPayrollExpense: totalExpense,
      paidSalariesTotal: totalPaid,
      pendingSalariesTotal: totalPending,
    );
  }
}
