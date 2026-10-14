import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fee_models.dart';
import '../../core/config/supabase_config.dart';

class FeeService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  // Local caches to guarantee offline resilience and smooth UX
  final List<FeeStructureModel> _cachedStructures = [];
  final List<FeeLedgerModel> _cachedLedgers = [];
  final List<PaymentRecordModel> _cachedPayments = [];

  // --- FETCH ACTIVE ACADEMIC YEAR ID ---
  Future<String?> fetchActiveAcademicYearId(String schoolId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await _client!
            .from('academic_years')
            .select('id')
            .eq('school_id', schoolId)
            .eq('is_active', true)
            .maybeSingle();
        if (res != null && res['id'] != null) {
          return res['id'].toString();
        }
        final latest = await _client!
            .from('academic_years')
            .select('id')
            .eq('school_id', schoolId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (latest != null && latest['id'] != null) {
          return latest['id'].toString();
        }
      } catch (e) {
        debugPrint('[FeeService fetchActiveAcademicYearId Warning]: $e');
      }
    }
    return null;
  }

  // --- FETCH FEE STATS (COLLECTED, PENDING, OVERDUE, TODAY, RATE) ---
  Future<Map<String, double>> getFeeStats({required String schoolId, String? academicYearId}) async {
    double collected = 0.0;
    double pending = 0.0;
    double overdue = 0.0;
    double totalFee = 0.0;
    double todayCollection = 0.0;

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final now = DateTime.now();
        final todayStr = now.toIso8601String().substring(0, 10);

        // 1. Query student_fee_accounts for total gross, discounts, waivers and due dates
        var accountQuery = _client!
            .from('student_fee_accounts')
            .select('id, gross_fee, discount_amount, waiver_amount, due_date, status')
            .eq('school_id', schoolId);

        if (academicYearId != null && academicYearId.isNotEmpty) {
          accountQuery = accountQuery.eq('academic_year_id', academicYearId);
        }

        final accounts = await accountQuery;

        // 2. Query fee_payments for total payments and today's collections
        var payQuery = _client!
            .from('fee_payments')
            .select('amount, fee_account_id, student_id, payment_date')
            .eq('school_id', schoolId);

        if (academicYearId != null && academicYearId.isNotEmpty) {
          payQuery = payQuery.eq('academic_year_id', academicYearId);
        }

        final payments = await payQuery;

        // Sum collected payments
        final Map<String, double> paidByAccount = {};
        for (final p in payments) {
          final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
          collected += amt;
          final pDate = (p['payment_date'] ?? '').toString();
          if (pDate.startsWith(todayStr)) {
            todayCollection += amt;
          }
          final accId = p['fee_account_id']?.toString() ?? p['student_id']?.toString();
          if (accId != null) {
            paidByAccount[accId] = (paidByAccount[accId] ?? 0.0) + amt;
          }
        }

        // Calculate total net fee and overdue
        for (final a in accounts) {
          final gross = (a['gross_fee'] as num?)?.toDouble() ?? 0.0;
          final disc = (a['discount_amount'] as num?)?.toDouble() ?? 0.0;
          final waiv = (a['waiver_amount'] as num?)?.toDouble() ?? 0.0;
          final net = (gross - disc - waiv).clamp(0.0, double.infinity);
          totalFee += net;

          final accId = (a['id'] ?? '').toString();
          final paidForAcc = paidByAccount[accId] ?? 0.0;
          final bal = (net - paidForAcc).clamp(0.0, double.infinity);

          if (bal > 0 && a['due_date'] != null) {
            final due = DateTime.tryParse(a['due_date'].toString());
            if (due != null && now.isAfter(due)) {
              overdue += bal;
            }
          }
        }

        pending = (totalFee - collected).clamp(0.0, double.infinity);

        return {
          'collected': collected,
          'pending': pending,
          'overdue': overdue,
          'total': totalFee,
          'today_collection': todayCollection,
          'collection_rate': totalFee > 0 ? ((collected / totalFee) * 100).clamp(0.0, 100.0) : 0.0,
        };
      } catch (e) {
        debugPrint('[FeeService getFeeStats Error]: $e');
      }
    }

    // Fallback to cached memory if database is unreachable
    for (final l in _cachedLedgers.where((l) => l.schoolId == schoolId)) {
      collected += l.paidAmount;
      pending += l.balanceAmount;
      if (l.computedStatus == FeeLedgerStatus.overdue) {
        overdue += l.balanceAmount;
      }
    }
    return {
      'collected': collected,
      'pending': pending,
      'overdue': overdue,
      'total': collected + pending,
      'today_collection': 0.0,
      'collection_rate': (collected + pending) > 0 ? ((collected / (collected + pending)) * 100) : 0.0,
    };
  }

  // --- FETCH FEE STRUCTURES ---
  Future<List<FeeStructureModel>> getFeeStructures({
    required String schoolId,
    String? className,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var filterQuery = _client!
            .from('fee_structures')
            .select('*, fee_components(*)')
            .eq('school_id', schoolId);

        if (className != null && className.isNotEmpty && className != 'All') {
          filterQuery = filterQuery.or('class_name.eq.$className,class_name.is.null');
        }

        final res = await filterQuery.order('created_at', ascending: false);
        final structures = res.map((r) => FeeStructureModel.fromJson(r)).toList();
        _cachedStructures.clear();
        _cachedStructures.addAll(structures);
        return structures;
      } catch (e) {
        debugPrint('[FeeService getFeeStructures Warning]: $e');
        return [];
      }
    }

    return _cachedStructures.where((s) => s.schoolId == schoolId).toList();
  }

  // --- CREATE FEE STRUCTURE ---
  Future<FeeStructureModel> createFeeStructure({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? className,
    required String name,
    String? academicYear,
    String? description,
    List<FeeComponentModel> components = const [],
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final structRes = await _client!.from('fee_structures').insert({
          'school_id': schoolId,
          'name': name,
          'class_name': (className != null && className.isNotEmpty && className != 'All') ? className : null,
          'academic_year_id': (academicYearId != null && academicYearId.isNotEmpty) ? academicYearId : null,
          if (description != null) 'description': description,
          'is_active': true,
        }).select().single();

        final structId = structRes['id'] as String;

        List<FeeComponentModel> createdComps = [];
        if (components.isNotEmpty) {
          final compRows = components.map((c) => {
            'school_id': schoolId,
            'fee_structure_id': structId,
            'name': c.name,
            'amount': c.amount,
            'frequency': feeFrequencyToDb(c.frequency),
            'due_day': c.dueDay ?? 10,
            if (c.description != null) 'description': c.description,
          }).toList();

          final compsRes = await _client!.from('fee_components').insert(compRows).select();
          createdComps = compsRes.map((c) => FeeComponentModel.fromJson(c)).toList();
        }

        final created = FeeStructureModel.fromJson(structRes, createdComps);
        _cachedStructures.insert(0, created);
        return created;
      } catch (e) {
        debugPrint('[FeeService createFeeStructure Remote Error, using cache]: $e');
      }
    }

    final localId = 'fst_${DateTime.now().millisecondsSinceEpoch}';
    final fallbackComps = components.map((c) => FeeComponentModel(
      id: 'fcp_${DateTime.now().millisecondsSinceEpoch}_${c.name}',
      feeStructureId: localId,
      schoolId: schoolId,
      name: c.name,
      amount: c.amount,
      frequency: c.frequency,
      dueDay: c.dueDay,
      description: c.description,
    )).toList();

    final newStructure = FeeStructureModel(
      id: localId,
      schoolId: schoolId,
      academicYearId: academicYearId ?? '',
      classId: classId ?? '',
      className: className ?? '',
      name: name,
      description: description,
      components: fallbackComps,
    );

    _cachedStructures.insert(0, newStructure);
    return newStructure;
  }

  // --- ASSIGN FEE STRUCTURE TO CLASS OR STUDENT ---
  Future<bool> assignFeeStructure({
    required String schoolId,
    required String academicYearId,
    required String feeStructureId,
    String? className,
    String? studentId,
    double discountAmount = 0.0,
    String? discountReason,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final struct = _cachedStructures.firstWhere(
          (s) => s.id == feeStructureId,
          orElse: () => FeeStructureModel(
            id: feeStructureId,
            schoolId: schoolId,
            academicYearId: academicYearId,
            name: 'Fee Structure',
            components: [],
          ),
        );
        final totalAmount = struct.totalBaseAmount;

        var stuQuery = _client!
            .from('students')
            .select('id, first_name, middle_name, last_name, class_name')
            .eq('school_id', schoolId);

        if (studentId != null && studentId.isNotEmpty) {
          stuQuery = stuQuery.eq('id', studentId);
        } else if (className != null && className.isNotEmpty && className != 'All') {
          stuQuery = stuQuery.eq('class_name', className);
        }

        final students = await stuQuery;
        for (final s in students) {
          final sId = s['id'] as String;

          // Check existing payments for this student
          final payRows = await _client!
              .from('fee_payments')
              .select('amount')
              .eq('student_id', sId);

          double totalPaid = 0.0;
          for (final p in payRows) {
            totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
          }

          final netFee = (totalAmount - discountAmount).clamp(0.0, double.infinity);
          final currentDue = (netFee - totalPaid).clamp(0.0, double.infinity);

          String status = 'due';
          if (currentDue <= 0) {
            status = 'paid';
          } else if (totalPaid > 0) {
            status = 'partially_paid';
          } else {
            status = 'due';
          }

          final dueDateStr = DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10);
          final existingAcc = await _client!
              .from('student_fee_accounts')
              .select('id')
              .eq('school_id', schoolId)
              .eq('student_id', sId)
              .maybeSingle();

          if (existingAcc != null && existingAcc['id'] != null) {
            await _client!.from('student_fee_accounts').update({
              'gross_fee': totalAmount,
              'discount_amount': discountAmount,
              'due_date': dueDateStr,
              'notes': discountReason ?? 'Assigned Fee Structure: ${struct.name}',
              'status': status,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', existingAcc['id']);
          } else {
            await _client!.from('student_fee_accounts').insert({
              'school_id': schoolId,
              'academic_year_id': academicYearId.isNotEmpty ? academicYearId : null,
              'student_id': sId,
              'gross_fee': totalAmount,
              'discount_amount': discountAmount,
              'waiver_amount': 0.0,
              'due_date': dueDateStr,
              'notes': discountReason ?? 'Assigned Fee Structure: ${struct.name}',
              'status': status,
            });
          }
        }
        return true;
      } catch (e) {
        debugPrint('[FeeService assignFeeStructure Error]: $e');
      }
    }
    return false;
  }

  // --- ASSIGN FEE DIRECTLY TO INDIVIDUAL STUDENT ---
  Future<bool> assignFeeToStudent({
    required String schoolId,
    required String studentId,
    required double grossFee,
    double discountAmount = 0.0,
    double waiverAmount = 0.0,
    DateTime? dueDate,
    String? notes,
    String? academicYearId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final activeYear = (academicYearId != null && academicYearId.isNotEmpty)
            ? academicYearId
            : await fetchActiveAcademicYearId(schoolId);

        final payRows = await _client!
            .from('fee_payments')
            .select('amount')
            .eq('student_id', studentId);

        double totalPaid = 0.0;
        for (final p in payRows) {
          totalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
        }

        final netFee = (grossFee - discountAmount - waiverAmount).clamp(0.0, double.infinity);
        final currentDue = (netFee - totalPaid).clamp(0.0, double.infinity);

        String status = 'due';
        if (currentDue <= 0) {
          status = 'paid';
        } else if (totalPaid > 0) {
          status = 'partially_paid';
        } else if (dueDate != null && DateTime.now().isAfter(dueDate)) {
          status = 'overdue';
        } else {
          status = 'due';
        }

        final existing = await _client!
            .from('student_fee_accounts')
            .select('id')
            .eq('school_id', schoolId)
            .eq('student_id', studentId)
            .maybeSingle();

        if (existing != null && existing['id'] != null) {
          await _client!.from('student_fee_accounts').update({
            'gross_fee': grossFee,
            'discount_amount': discountAmount,
            'waiver_amount': waiverAmount,
            'due_date': dueDate?.toIso8601String().substring(0, 10),
            'notes': notes,
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', existing['id']);
        } else {
          await _client!.from('student_fee_accounts').insert({
            'school_id': schoolId,
            'academic_year_id': activeYear,
            'student_id': studentId,
            'gross_fee': grossFee,
            'discount_amount': discountAmount,
            'waiver_amount': waiverAmount,
            'due_date': dueDate?.toIso8601String().substring(0, 10),
            'notes': notes,
            'status': status,
          });
        }
        return true;
      } catch (e) {
        debugPrint('[FeeService assignFeeToStudent Error]: $e');
        rethrow;
      }
    }
    return false;
  }

  // --- FETCH STUDENT FEE ACCOUNTS WITH FULL DETAILS FOR OVERVIEW & DUES ---
  Future<List<StudentFeeAccountModel>> getStudentFeeAccountsWithDetails({
    required String schoolId,
    String? className,
    String? search,
    String? statusFilter,
    String? academicYearId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('student_fee_accounts')
            .select('*, students(id, first_name, middle_name, last_name, admission_number, class_name, section_name)')
            .eq('school_id', schoolId);

        if (academicYearId != null && academicYearId.isNotEmpty) {
          query = query.eq('academic_year_id', academicYearId);
        }

        final rows = await query.order('created_at', ascending: false);

        // Fetch sum of payments per fee_account_id or student_id
        final payRows = await _client!
            .from('fee_payments')
            .select('fee_account_id, student_id, amount')
            .eq('school_id', schoolId);

        final Map<String, double> paidByAccount = {};
        final Map<String, double> paidByStudent = {};
        for (final p in payRows) {
          final amt = (p['amount'] as num?)?.toDouble() ?? 0.0;
          final fId = p['fee_account_id']?.toString();
          final sId = p['student_id']?.toString();
          if (fId != null && fId.isNotEmpty) {
            paidByAccount[fId] = (paidByAccount[fId] ?? 0.0) + amt;
          }
          if (sId != null && sId.isNotEmpty) {
            paidByStudent[sId] = (paidByStudent[sId] ?? 0.0) + amt;
          }
        }

        List<StudentFeeAccountModel> list = [];
        for (final r in rows) {
          final accId = (r['id'] ?? '').toString();
          final stuId = (r['student_id'] ?? '').toString();
          final paidSum = paidByAccount[accId] ?? paidByStudent[stuId] ?? 0.0;
          list.add(StudentFeeAccountModel.fromJson(r, paidSum: paidSum));
        }

        if (className != null && className.isNotEmpty && className != 'All') {
          list = list.where((a) => a.className == className).toList();
        }

        if (search != null && search.trim().isNotEmpty) {
          final term = search.trim().toLowerCase();
          list = list.where((a) {
            return a.studentName.toLowerCase().contains(term) ||
                a.admissionNumber.toLowerCase().contains(term) ||
                a.className.toLowerCase().contains(term);
          }).toList();
        }

        if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
          final sTerm = statusFilter.trim().toLowerCase();
          list = list.where((a) {
            final dbSt = a.dbStatus.toLowerCase();
            final comp = a.computedStatus.toLowerCase();
            final disp = a.displayStatus.toLowerCase();
            if (sTerm.contains('part')) {
              return dbSt == 'partially_paid' || comp.contains('part') || disp.contains('part');
            }
            if (sTerm == 'due' || sTerm == 'pending') {
              return dbSt == 'due' || comp == 'due' || comp == 'pending';
            }
            if (sTerm == 'paid') {
              return dbSt == 'paid' && !comp.contains('part');
            }
            if (sTerm == 'overdue') {
              return dbSt == 'overdue' || comp == 'overdue';
            }
            return dbSt == sTerm || comp == sTerm || disp == sTerm;
          }).toList();
        }

        return list;
      } catch (e) {
        debugPrint('[FeeService getStudentFeeAccountsWithDetails Error]: $e');
      }
    }
    return [];
  }

  // --- FETCH SINGLE STUDENT FEE ACCOUNT ---
  Future<StudentFeeAccountModel?> getStudentFeeAccount(
    String studentId, {
    required String schoolId,
    String? academicYearId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('student_fee_accounts')
            .select('*, students(id, first_name, middle_name, last_name, admission_number, class_name, section_name)')
            .eq('student_id', studentId)
            .eq('school_id', schoolId);

        if (academicYearId != null && academicYearId.isNotEmpty) {
          query = query.eq('academic_year_id', academicYearId);
        }

        final row = await query.maybeSingle();
        if (row == null) return null;

        final accId = (row['id'] ?? '').toString();
        final payRows = await _client!
            .from('fee_payments')
            .select('amount')
            .eq('school_id', schoolId)
            .or('fee_account_id.eq.$accId,student_id.eq.$studentId');

        double paidSum = 0.0;
        for (final p in payRows) {
          paidSum += (p['amount'] as num?)?.toDouble() ?? 0.0;
        }

        return StudentFeeAccountModel.fromJson(row, paidSum: paidSum);
      } catch (e) {
        debugPrint('[FeeService getStudentFeeAccount Error]: $e');
      }
    }
    return null;
  }

  // --- FETCH STUDENT FEE LEDGER (VIA STUDENT FEE ACCOUNT) ---
  Future<List<FeeLedgerModel>> getStudentFeeLedger({
    required String schoolId,
    required String studentId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final acc = await getStudentFeeAccount(studentId, schoolId: schoolId);
        if (acc != null) {
          final isPaid = acc.currentDue <= 0 && acc.netFee > 0;
          final isOverdue = acc.dueDate != null && DateTime.now().isAfter(acc.dueDate!) && acc.currentDue > 0;
          final status = isPaid ? FeeLedgerStatus.paid : (isOverdue ? FeeLedgerStatus.overdue : FeeLedgerStatus.pending);

          return [
            FeeLedgerModel(
              id: acc.id,
              schoolId: schoolId,
              academicYearId: acc.academicYearId,
              studentId: studentId,
              studentName: acc.studentName,
              feeComponentId: 'fee_${acc.id}',
              componentName: 'Academic Fees & Tuition',
              billingPeriod: 'Current Academic Term',
              dueDate: acc.dueDate ?? DateTime.now(),
              amount: acc.grossFee,
              discountAmount: acc.discountAmount + acc.waiverAmount,
              adjustmentAmount: 0.0,
              paidAmount: acc.totalPaid,
              status: status,
            ),
          ];
        }
        return [];
      } catch (e) {
        debugPrint('[FeeService getStudentFeeLedger Warning]: $e');
        rethrow;
      }
    }
    return _cachedLedgers.where((l) => l.schoolId == schoolId && l.studentId == studentId).toList();
  }

  // --- FETCH ALL STUDENT FEE STATEMENTS FOR ADMIN LEDGER TAB ---
  Future<List<Map<String, dynamic>>> getStudentFeeStatements({
    required String schoolId,
    String? className,
    String? search,
    String? statusFilter,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var stuQuery = _client!
            .from('students')
            .select('id, first_name, middle_name, last_name, admission_number, class_name, section_name')
            .eq('school_id', schoolId);

        if (className != null && className.isNotEmpty && className != 'All') {
          stuQuery = stuQuery.eq('class_name', className);
        }

        final students = await stuQuery.order('first_name', ascending: true);

        // Fetch accounts and payments to compile statements
        final accounts = await _client!
            .from('student_fee_accounts')
            .select('id, student_id, gross_fee, discount_amount, waiver_amount, status, due_date')
            .eq('school_id', schoolId);

        final payments = await _client!
            .from('fee_payments')
            .select('student_id, amount')
            .eq('school_id', schoolId);

        final Map<String, Map<String, dynamic>> accountByStudent = {};
        for (final a in accounts) {
          final sId = a['student_id']?.toString();
          if (sId != null) {
            accountByStudent[sId] = a;
          }
        }

        final Map<String, double> paidByStudent = {};
        for (final p in payments) {
          final sId = p['student_id']?.toString();
          if (sId != null) {
            paidByStudent[sId] = (paidByStudent[sId] ?? 0.0) + ((p['amount'] as num?)?.toDouble() ?? 0.0);
          }
        }

        List<Map<String, dynamic>> results = [];
        for (final s in students) {
          final sId = s['id'].toString();
          final fName = s['first_name']?.toString() ?? '';
          final mName = s['middle_name']?.toString() ?? '';
          final lName = s['last_name']?.toString() ?? '';
          final nameParts = [fName, mName, lName].where((p) => p.trim().isNotEmpty).toList();
          final fullName = nameParts.isNotEmpty ? nameParts.join(' ') : 'Student';

          final acc = accountByStudent[sId];
          final double gross = (acc?['gross_fee'] as num?)?.toDouble() ?? 0.0;
          final double disc = (acc?['discount_amount'] as num?)?.toDouble() ?? 0.0;
          final double waiv = (acc?['waiver_amount'] as num?)?.toDouble() ?? 0.0;
          final double net = (gross - disc - waiv).clamp(0.0, double.infinity);
          final double paid = paidByStudent[sId] ?? 0.0;
          final double pending = (net - paid).clamp(0.0, double.infinity);

          String dbStatus = 'due';
          String displayStatus = 'Due';
          String computedStatus = 'DUE';
          if (acc != null) {
            final due = acc['due_date'] != null ? DateTime.tryParse(acc['due_date'].toString()) : null;
            if (pending <= 0) {
              dbStatus = 'paid';
              displayStatus = 'Paid';
              computedStatus = 'PAID';
            } else if (paid > 0) {
              dbStatus = 'partially_paid';
              displayStatus = 'Partially Paid';
              computedStatus = 'PARTIALLY PAID';
            } else if (due != null && DateTime.now().isAfter(due)) {
              dbStatus = 'overdue';
              displayStatus = 'Overdue';
              computedStatus = 'OVERDUE';
            } else {
              dbStatus = 'due';
              displayStatus = 'Due';
              computedStatus = 'DUE';
            }
          } else {
            dbStatus = 'no_fee';
            displayStatus = 'No Fee';
            computedStatus = 'NO FEE';
          }

          results.add({
            'id': sId,
            'name': fullName,
            'first_name': fName,
            'last_name': lName,
            'admission_number': s['admission_number'] ?? '',
            'class_name': s['class_name'] ?? '',
            'section_name': s['section_name'] ?? '',
            'total_fee': net,
            'gross_fee': gross,
            'paid_fee': paid,
            'pending_fee': pending,
            'fee_status': computedStatus,
            'db_status': dbStatus,
            'display_status': displayStatus,
            'status': dbStatus,
            'has_fee_account': acc != null,
          });
        }

        if (search != null && search.trim().isNotEmpty) {
          final term = search.trim().toLowerCase();
          results = results.where((r) {
            final name = (r['name'] ?? '').toString().toLowerCase();
            final adm = (r['admission_number'] ?? '').toString().toLowerCase();
            return name.contains(term) || adm.contains(term);
          }).toList();
        }

        if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'All') {
          final f = statusFilter.trim().toLowerCase();
          results = results.where((r) {
            final dbSt = (r['db_status'] ?? '').toString().toLowerCase();
            final compSt = (r['fee_status'] ?? '').toString().toLowerCase();
            final dispSt = (r['display_status'] ?? '').toString().toLowerCase();
            if (f.contains('part')) {
              return dbSt == 'partially_paid' || compSt.contains('part') || dispSt.contains('part');
            }
            if (f == 'due' || f == 'pending') {
              return dbSt == 'due' || compSt == 'due' || compSt == 'pending';
            }
            if (f == 'paid') {
              return dbSt == 'paid' && !compSt.contains('part');
            }
            if (f == 'overdue') {
              return dbSt == 'overdue' || compSt == 'overdue';
            }
            return dbSt == f || compSt == f || dispSt == f;
          }).toList();
        }

        return results;
      } catch (e) {
        debugPrint('[FeeService getStudentFeeStatements Warning]: $e');
        rethrow;
      }
    }
    return [];
  }

  // --- FETCH STUDENT FEE SUMMARY ---
  Future<FeeSummaryModel> getStudentFeeSummary({
    required String schoolId,
    required String studentId,
    String studentName = '',
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final feeAcc = await getStudentFeeAccount(studentId, schoolId: schoolId);
        if (feeAcc != null) {
          return FeeSummaryModel(
            studentId: studentId,
            studentName: feeAcc.studentName.isNotEmpty ? feeAcc.studentName : studentName,
            totalDue: feeAcc.netFee,
            totalPaid: feeAcc.totalPaid,
            totalOutstanding: feeAcc.currentDue,
            overdueAmount: (feeAcc.dueDate != null && DateTime.now().isAfter(feeAcc.dueDate!))
                ? feeAcc.currentDue
                : 0.0,
          );
        }
      } catch (e) {
        debugPrint('[FeeService getStudentFeeSummary Warning]: $e');
      }
    }

    final ledgers = _cachedLedgers.where((l) => l.schoolId == schoolId && l.studentId == studentId).toList();
    double totalDue = 0.0;
    double totalPaid = 0.0;
    double overdue = 0.0;

    for (var l in ledgers) {
      totalDue += l.netAmount;
      totalPaid += l.paidAmount;
      if (l.computedStatus == FeeLedgerStatus.overdue) {
        overdue += l.balanceAmount;
      }
    }

    final outstanding = (totalDue - totalPaid).clamp(0.0, double.infinity);
    return FeeSummaryModel(
      studentId: studentId,
      studentName: studentName,
      totalDue: totalDue,
      totalPaid: totalPaid,
      totalOutstanding: outstanding,
      overdueAmount: overdue,
    );
  }

  // --- RECORD PAYMENT WITH PERSISTENCE & RECEIPT GENERATION ---
  Future<FeeReceiptModel> recordPayment({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String className,
    String admissionNumber = '',
    required double amount,
    required PaymentMethod paymentMethod,
    String? transactionReference,
    String? notes,
    String? academicYearId,
  }) async {
    if (amount <= 0) {
      throw Exception('Payment amount must be greater than zero');
    }

    final now = DateTime.now();
    final seqNum = now.millisecondsSinceEpoch.toString().substring(7);
    final fallbackReceiptNo = 'REC-${now.year}-$seqNum';

    if (_client != null && SupabaseConfig.isConfigured) {
      final user = _client!.auth.currentUser;
      if (user == null) {
        throw Exception('You must be signed in as an administrator to record payments.');
      }

      // 1. Locate student fee account
      final feeAccount = await getStudentFeeAccount(
        studentId,
        schoolId: schoolId,
        academicYearId: academicYearId,
      );

      if (feeAccount == null) {
        throw Exception('No fee has been assigned to this student yet.');
      }

      if (amount > feeAccount.currentDue) {
        throw Exception(
          'Payment amount (₹${amount.toStringAsFixed(0)}) cannot exceed current due balance of ₹${feeAccount.currentDue.toStringAsFixed(0)}.',
        );
      }

      // 2. Direct schema-aligned insert into fee_payments
      try {
        final paymentPayload = {
          'school_id': schoolId,
          'academic_year_id': (academicYearId != null && academicYearId.isNotEmpty)
              ? academicYearId
              : (feeAccount.academicYearId.isNotEmpty ? feeAccount.academicYearId : null),
          'student_id': studentId,
          'fee_account_id': feeAccount.id,
          'amount': amount,
          'payment_date': now.toIso8601String().substring(0, 10),
          'payment_method': paymentMethodToDb(paymentMethod),
          'reference_number': transactionReference,
          'receipt_number': fallbackReceiptNo,
          'notes': notes ?? 'Tuition & Academic Fees Payment',
          'created_by': user.id,
        };

        final insertRes = await _client!.from('fee_payments').insert(paymentPayload).select().single();
        final actualReceiptNo = insertRes['receipt_number']?.toString() ?? fallbackReceiptNo;

        // 3. Recalculate total paid from valid fee_payments
        final paymentsQuery = await _client!
            .from('fee_payments')
            .select('amount')
            .eq('fee_account_id', feeAccount.id);

        double recalculatedTotalPaid = 0.0;
        for (final p in paymentsQuery) {
          recalculatedTotalPaid += (p['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // 4. Calculate net fee and current due
        final netFee = (feeAccount.grossFee - feeAccount.discountAmount - feeAccount.waiverAmount).clamp(0.0, double.infinity);
        final currentDue = (netFee - recalculatedTotalPaid).clamp(0.0, double.infinity);

        // 5. Calculate status using exact database-allowed values:
        // If currentDue <= 0: status = "paid"
        // Else if totalPaid > 0: status = "partially_paid"
        // Else if dueDate exists AND today > dueDate: status = "overdue"
        // Else: status = "due"
        String newStatus;
        if (currentDue <= 0) {
          newStatus = 'paid';
        } else if (recalculatedTotalPaid > 0) {
          newStatus = 'partially_paid';
        } else if (feeAccount.dueDate != null && now.isAfter(feeAccount.dueDate!)) {
          newStatus = 'overdue';
        } else {
          newStatus = 'due';
        }

        // 6. Update student_fee_accounts status with EXACT database-allowed value
        await _client!.from('student_fee_accounts').update({
          'status': newStatus,
          'updated_at': now.toIso8601String(),
        }).eq('id', feeAccount.id);

        return FeeReceiptModel(
          receiptNo: actualReceiptNo,
          studentName: studentName,
          admissionNumber: admissionNumber,
          className: className,
          date: now,
          amountPaid: amount,
          paymentMethod: paymentMethod.name.toUpperCase(),
          transactionRef: transactionReference ?? '',
          previousBalance: feeAccount.currentDue,
          remainingBalance: currentDue,
          description: notes ?? 'Tuition & Academic Fees Payment',
        );
      } on PostgrestException catch (e) {
        debugPrint('[FeeService recordPayment PostgrestException]: ${e.message} (code: ${e.code})');
        throw Exception('Payment could not be recorded: ${e.message}');
      } catch (e) {
        debugPrint('[FeeService recordPayment Error]: $e');
        throw Exception('Payment could not be recorded: $e');
      }
    }

    // Local cached payment (only for offline mock mode)
    final receipt = FeeReceiptModel(
      receiptNo: fallbackReceiptNo,
      studentName: studentName,
      admissionNumber: admissionNumber,
      className: className,
      date: now,
      amountPaid: amount,
      paymentMethod: paymentMethod.name.toUpperCase(),
      transactionRef: transactionReference ?? '',
      previousBalance: amount,
      remainingBalance: 0.0,
      description: notes ?? 'Offline Campus Payment',
    );

    final newPayment = PaymentRecordModel(
      id: 'pay_${now.millisecondsSinceEpoch}',
      schoolId: schoolId,
      studentId: studentId,
      studentName: studentName,
      receiptNumber: fallbackReceiptNo,
      amount: amount,
      paymentMethod: paymentMethod,
      paymentStatus: PaymentRecordStatus.success,
      referenceNumber: transactionReference ?? 'OFFLINE-$seqNum',
      transactionReference: transactionReference ?? 'OFFLINE-$seqNum',
      paidAt: now,
      recordedBy: 'School Administrator',
      notes: notes,
    );
    _cachedPayments.insert(0, newPayment);

    return receipt;
  }

  // --- FETCH RECENT PAYMENTS ---
  Future<List<PaymentRecordModel>> getRecentPayments({
    required String schoolId,
    int limit = 20,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await _client!
            .from('fee_payments')
            .select('*, students(first_name, middle_name, last_name, admission_number, class_name)')
            .eq('school_id', schoolId)
            .order('created_at', ascending: false)
            .limit(limit);

        return res.map((r) => PaymentRecordModel.fromJson(r)).toList();
      } catch (e) {
        debugPrint('[FeeService getRecentPayments Warning]: $e');
      }
    }
    return _cachedPayments.where((p) => p.schoolId == schoolId).take(limit).toList();
  }

  // --- FETCH PAYMENT HISTORY ---
  Future<List<PaymentRecordModel>> getPaymentHistory({
    required String schoolId,
    String? studentId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var filterQuery = _client!
            .from('fee_payments')
            .select('*, students(first_name, middle_name, last_name, admission_number, class_name)')
            .eq('school_id', schoolId);

        if (studentId != null && studentId.isNotEmpty) {
          filterQuery = filterQuery.eq('student_id', studentId);
        }

        final res = await filterQuery.order('payment_date', ascending: false);
        return res.map((r) => PaymentRecordModel.fromJson(r)).toList();
      } catch (e) {
        debugPrint('[FeeService getPaymentHistory Warning]: $e');
      }
    }

    if (studentId != null) {
      return _cachedPayments.where((p) => p.schoolId == schoolId && p.studentId == studentId).toList();
    }
    return _cachedPayments.where((p) => p.schoolId == schoolId).toList();
  }

  // --- FETCH COLLECTION SCHEDULE GROUPED BY DUE DATE ---
  Future<List<Map<String, dynamic>>> getCollectionSchedule({
    required String schoolId,
    String? academicYearId,
  }) async {
    final accounts = await getStudentFeeAccountsWithDetails(
      schoolId: schoolId,
      academicYearId: academicYearId,
    );

    final Map<String, List<StudentFeeAccountModel>> grouped = {};
    for (final acc in accounts) {
      if (acc.currentDue > 0) {
        final key = acc.dueDate != null
            ? '${acc.dueDate!.year}-${acc.dueDate!.month.toString().padLeft(2, '0')}-${acc.dueDate!.day.toString().padLeft(2, '0')}'
            : 'No Due Date';
        grouped.putIfAbsent(key, () => []).add(acc);
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<Map<String, dynamic>> schedule = [];
    grouped.forEach((dateStr, list) {
      double totalDue = 0.0;
      for (final a in list) {
        totalDue += a.currentDue;
      }
      bool isOverdue = false;
      DateTime? parsedDate;
      if (dateStr != 'No Due Date') {
        parsedDate = DateTime.tryParse(dateStr);
        if (parsedDate != null && parsedDate.isBefore(today)) {
          isOverdue = true;
        }
      }
      schedule.add({
        'due_date_str': dateStr,
        'due_date': parsedDate,
        'student_count': list.length,
        'total_due': totalDue,
        'is_overdue': isOverdue,
        'accounts': list,
      });
    });

    schedule.sort((a, b) {
      final DateTime? d1 = a['due_date'] as DateTime?;
      final DateTime? d2 = b['due_date'] as DateTime?;
      if (d1 == null) return 1;
      if (d2 == null) return -1;
      return d1.compareTo(d2);
    });

    return schedule;
  }

  // --- FETCH FILTERED PAYMENTS FOR TRANSACTIONS & RECEIPTS TAB ---
  Future<List<PaymentRecordModel>> getFilteredPayments({
    required String schoolId,
    DateTime? startDate,
    DateTime? endDate,
    String? className,
    PaymentMethod? paymentMethod,
    String? searchQuery,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('fee_payments')
            .select('*, students(first_name, middle_name, last_name, admission_number, class_name)')
            .eq('school_id', schoolId);

        if (startDate != null) {
          query = query.gte('payment_date', startDate.toIso8601String().substring(0, 10));
        }
        if (endDate != null) {
          query = query.lte('payment_date', endDate.toIso8601String().substring(0, 10));
        }
        if (paymentMethod != null) {
          query = query.eq('payment_method', paymentMethodToDb(paymentMethod));
        }

        final res = await query.order('created_at', ascending: false);
        List<PaymentRecordModel> list = res.map((r) => PaymentRecordModel.fromJson(r)).toList();

        if (className != null && className.isNotEmpty && className != 'All') {
          list = list.where((p) => p.className == className).toList();
        }

        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final term = searchQuery.trim().toLowerCase();
          list = list.where((p) {
            return p.studentName.toLowerCase().contains(term) ||
                (p.admissionNumber ?? '').toLowerCase().contains(term) ||
                p.receiptNumber.toLowerCase().contains(term) ||
                (p.referenceNumber ?? '').toLowerCase().contains(term);
          }).toList();
        }

        return list;
      } catch (e) {
        debugPrint('[FeeService getFilteredPayments Warning]: $e');
      }
    }
    return _cachedPayments.where((p) => p.schoolId == schoolId).toList();
  }
}

