import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import 'salary_service.dart';

class StudentReportSummary {
  final int totalStudents;
  final Map<String, int> classWiseCounts;
  final int newAdmissionsThisMonth;

  StudentReportSummary({
    required this.totalStudents,
    required this.classWiseCounts,
    required this.newAdmissionsThisMonth,
  });
}

class FeeReportSummary {
  final double expectedTotal;
  final double collectedTotal;
  final double pendingTotal;
  final Map<String, double> classWiseCollected;

  FeeReportSummary({
    required this.expectedTotal,
    required this.collectedTotal,
    required this.pendingTotal,
    required this.classWiseCollected,
  });
}

class SalaryReportSummary {
  final double monthlyPayrollExpense;
  final double paidSalariesTotal;
  final double pendingSalariesTotal;

  SalaryReportSummary({
    required this.monthlyPayrollExpense,
    required this.paidSalariesTotal,
    required this.pendingSalariesTotal,
  });
}

class ReportService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  Future<StudentReportSummary> getStudentReport() async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final rows = await _client!.from('students').select('standard, section, created_at');
        if (rows.isNotEmpty) {
          final totalStudents = rows.length;
          final Map<String, int> classCounts = {};
          int newAdmissions = 0;
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);

          for (final r in rows) {
            final rawStd = (r['standard'] ?? '').toString().trim();
            final key = rawStd.isEmpty
                ? 'Unassigned'
                : (rawStd.toLowerCase().startsWith('class') || rawStd.toLowerCase().startsWith('grade')
                    ? rawStd
                    : 'Class $rawStd');
            classCounts[key] = (classCounts[key] ?? 0) + 1;

            if (r['created_at'] != null) {
              final created = DateTime.tryParse(r['created_at'].toString());
              if (created != null && created.isAfter(startOfMonth)) {
                newAdmissions++;
              }
            }
          }

          return StudentReportSummary(
            totalStudents: totalStudents,
            classWiseCounts: classCounts,
            newAdmissionsThisMonth: newAdmissions,
          );
        }
      } catch (e) {
        debugPrint('[ReportService getStudentReport error]: $e');
      }
    }

    return StudentReportSummary(
      totalStudents: 0,
      classWiseCounts: {},
      newAdmissionsThisMonth: 0,
    );
  }

  Future<FeeReportSummary> getFeeReport() async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final rows = await _client!.from('student_fee_accounts').select('net_fee, total_paid, current_due, students(standard)');
        if (rows.isNotEmpty) {
          double expected = 0.0;
          double collected = 0.0;
          final Map<String, double> classCol = {};

          for (final r in rows) {
            final due = (r['net_fee'] as num?)?.toDouble() ?? 0.0;
            final paid = (r['total_paid'] as num?)?.toDouble() ?? 0.0;
            final stu = r['students'] as Map<String, dynamic>?;
            final std = (stu?['standard'] ?? '').toString().trim();
            final cls = std.isEmpty
                ? 'Other'
                : (std.toLowerCase().startsWith('class') || std.toLowerCase().startsWith('grade')
                    ? std
                    : 'Class $std');
            expected += due;
            collected += paid;
            classCol[cls] = (classCol[cls] ?? 0.0) + paid;
          }

          return FeeReportSummary(
            expectedTotal: expected,
            collectedTotal: collected,
            pendingTotal: (expected - collected > 0) ? (expected - collected) : 0.0,
            classWiseCollected: classCol,
          );
        }
      } catch (e) {
        debugPrint('[ReportService getFeeReport error]: $e');
      }
    }

    return FeeReportSummary(
      expectedTotal: 0.0,
      collectedTotal: 0.0,
      pendingTotal: 0.0,
      classWiseCollected: {},
    );
  }

  Future<SalaryReportSummary> getSalaryReport() async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final rows = await _client!.from('salary_payments').select('amount_paid, net_salary');
        if (rows.isNotEmpty) {
          double totalPayroll = 0.0;
          double paidTotal = 0.0;
          for (final r in rows) {
            final net = (r['net_salary'] as num?)?.toDouble() ?? 0.0;
            final paid = (r['amount_paid'] as num?)?.toDouble() ?? 0.0;
            totalPayroll += net;
            paidTotal += paid;
          }
          return SalaryReportSummary(
            monthlyPayrollExpense: totalPayroll,
            paidSalariesTotal: paidTotal,
            pendingSalariesTotal: (totalPayroll - paidTotal > 0) ? (totalPayroll - paidTotal) : 0.0,
          );
        }
      } catch (e) {
        debugPrint('[ReportService getSalaryReport error]: $e');
      }
    }

    // Dual-tier fallback to SalaryService cached payrolls/payments
    try {
      final metrics = await SalaryService().getSalaryDashboardMetrics();
      return SalaryReportSummary(
        monthlyPayrollExpense: metrics.monthlyPayrollExpense,
        paidSalariesTotal: metrics.paidSalariesTotal,
        pendingSalariesTotal: metrics.pendingSalariesTotal,
      );
    } catch (_) {}

    return SalaryReportSummary(
      monthlyPayrollExpense: 0.0,
      paidSalariesTotal: 0.0,
      pendingSalariesTotal: 0.0,
    );
  }
}
