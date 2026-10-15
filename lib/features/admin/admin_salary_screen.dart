import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/salary_models.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/salary_service.dart';

class AdminSalaryScreen extends ConsumerStatefulWidget {
  const AdminSalaryScreen({super.key});

  @override
  ConsumerState<AdminSalaryScreen> createState() => _AdminSalaryScreenState();
}

class _AdminSalaryScreenState extends ConsumerState<AdminSalaryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  late String _selectedMonthYear;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Partial', 'Paid', 'Not Configured'
  bool _isBatchProcessing = false;

  final List<String> _monthOptions = [
    'November 2026',
    'October 2026',
    'September 2026',
    'August 2026',
    'July 2026',
    'June 2026',
    'May 2026',
    'April 2026',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthYear = DateFormat('MMMM yyyy').format(now);
    if (!_monthOptions.contains(_selectedMonthYear)) {
      _monthOptions.insert(0, _selectedMonthYear);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salaryService = ref.watch(salaryServiceProvider);
    final teacherService = ref.watch(teacherServiceProvider);
    final activeProfile = ref.watch(authProvider.notifier).activeProfile;
    final activeSchoolId = activeProfile?.schoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Staff Salary & Monthly Payroll', style: AppTypography.titleLarge),
        actions: [
          // Month Selector in AppBar
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedMonthYear,
                icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.softLavender),
                style: AppTypography.labelMedium.copyWith(color: isDark ? AppColors.pureWhite : AppColors.midnightNavy, fontWeight: FontWeight.bold),
                dropdownColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                items: _monthOptions.map((m) {
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: AppColors.softLavender),
                        const SizedBox(width: 6),
                        Text(m),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedMonthYear = val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Live Real Metrics Header
            FutureBuilder<SalaryDashboardMetrics>(
              future: salaryService.getSalaryDashboardMetrics(
                schoolId: activeSchoolId,
                monthYear: _selectedMonthYear,
              ),
              builder: (context, snapshot) {
                final metrics = snapshot.data ?? const SalaryDashboardMetrics();

                return Column(
                  children: [
                    BentoCard(
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PAYROLL SUMMARY • ${_selectedMonthYear.toUpperCase()}',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.lavenderLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.pureWhite.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${metrics.configuredStaff} / ${metrics.totalStaff} Staff Configured',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.pureWhite,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '₹ ${metrics.monthlyPayrollExpense.toStringAsFixed(2)}',
                            style: AppTypography.numericHeader.copyWith(
                              color: AppColors.pureWhite,
                              fontSize: 32,
                            ),
                          ),
                          Text(
                            'Total Monthly Net Compensation Payable',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.mutedGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Disbursed Amount', style: AppTypography.labelSmall.copyWith(color: AppColors.mutedGreen)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹ ${metrics.paidSalariesTotal.toStringAsFixed(0)}',
                                        style: AppTypography.titleMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.softCoral.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Pending Balance', style: AppTypography.labelSmall.copyWith(color: AppColors.softCoral)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹ ${metrics.pendingSalariesTotal.toStringAsFixed(0)}',
                                        style: AppTypography.titleMedium.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Stats & Batch Generator Row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _isBatchProcessing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.auto_awesome_rounded, size: 18),
                            label: Text(
                              _isBatchProcessing ? 'Generating...' : 'Batch Generate Payroll',
                              style: AppTypography.labelMedium,
                            ),
                            onPressed: _isBatchProcessing
                                ? null
                                : () => _handleBatchGeneratePayroll(context, activeSchoolId),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Chips
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search staff by name or employee ID...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'All',
                  'Pending',
                  'Partial',
                  'Paid',
                  'Not Configured',
                ].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(filter),
                      selectedColor: AppColors.softLavender.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.softLavender,
                      labelStyle: AppTypography.bodySmall.copyWith(
                        color: isSelected ? AppColors.softLavender : AppColors.coolGray,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Faculty & Staff Directory with Salary Structures & Monthly Payrolls
            FutureBuilder<List<TeacherModel>>(
              future: teacherService.getTeachers(
                schoolId: activeSchoolId,
                query: _searchCtrl.text,
                includeStaff: true,
              ),
              builder: (context, teacherSnapshot) {
                if (teacherSnapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading staff & payroll records...');
                }

                final teachers = teacherSnapshot.data ?? [];
                if (teachers.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.person_off_rounded,
                    title: 'No Staff Found',
                    message: 'No teachers or staff match the current filters.',
                  );
                }

                // Fetch all payroll records for this school & selected month
                return FutureBuilder<List<MonthlyPayrollModel>>(
                  future: salaryService.getMonthlyPayrollsForSchool(_selectedMonthYear, schoolId: activeSchoolId),
                  builder: (context, payrollSnapshot) {
                    final payrolls = payrollSnapshot.data ?? [];

                    return Column(
                      children: teachers.map((teacher) {
                        return FutureBuilder<SalaryStructure?>(
                          future: salaryService.getSalaryStructure(teacher.id),
                          builder: (context, structSnapshot) {
                            final struct = structSnapshot.data;
                            final isConfigured = struct != null && struct.basicSalary > 0;

                            // Match payroll record for this teacher if exists
                            MonthlyPayrollModel? payroll;
                            try {
                              payroll = payrolls.firstWhere(
                                (p) => p.staffProfileId == teacher.id || p.employeeId.toLowerCase() == teacher.employeeId.toLowerCase(),
                              );
                            } catch (_) {
                              payroll = null;
                            }

                            // Calculate status
                            final SalaryStatus status = !isConfigured
                                ? SalaryStatus.notConfigured
                                : (payroll != null ? payroll.status : SalaryStatus.pending);

                            // Apply filter
                            if (_selectedFilter == 'Not Configured' && isConfigured) {
                              return const SizedBox.shrink();
                            }
                            if (_selectedFilter == 'Paid' && status != SalaryStatus.paid) {
                              return const SizedBox.shrink();
                            }
                            if (_selectedFilter == 'Pending' && (status != SalaryStatus.pending || !isConfigured)) {
                              return const SizedBox.shrink();
                            }
                            if (_selectedFilter == 'Partial' && status != SalaryStatus.partial) {
                              return const SizedBox.shrink();
                            }

                            final double payableAmount = isConfigured ? struct.netSalary : 0.0;
                            final double paidAmount = payroll?.amountPaid ?? 0.0;
                            final double balanceAmount = isConfigured
                                ? (payroll != null ? payroll.remainingBalance : payableAmount)
                                : 0.0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: BentoCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Avatar, Name, Role, Status Chip
                                    Row(
                                      children: [
                                        AppAvatar(imageUrl: teacher.avatarUrl, name: teacher.name, radius: 24, borderColor: AppColors.softLavender),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(teacher.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                                  ),
                                                  _buildStatusChip(status),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${teacher.employeeId} • ${teacher.designation}${teacher.assignedClass.isNotEmpty ? " • ${teacher.assignedClass}" : ""}',
                                                style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),

                                    // Content based on whether salary is configured
                                    if (!isConfigured) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Salary structure has not been configured yet for this staff member.',
                                                style: AppTypography.bodySmall.copyWith(color: AppColors.midnightNavy),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.midnightNavy,
                                            foregroundColor: AppColors.pureWhite,
                                          ),
                                          onPressed: () => _showEditStructureDialog(context, teacher, struct, activeSchoolId),
                                          icon: const Icon(Icons.tune_rounded, size: 16),
                                          label: const Text('Configure Salary Structure'),
                                        ),
                                      ),
                                    ] else ...[
                                      // Amounts Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Net Monthly', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 10)),
                                              Text('₹ ${payableAmount.toStringAsFixed(0)}', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Text('Disbursed', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 10)),
                                              Text(
                                                '₹ ${paidAmount.toStringAsFixed(0)}',
                                                style: AppTypography.titleSmall.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: paidAmount > 0 ? AppColors.mutedGreen : AppColors.coolGray,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('Pending Balance', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 10)),
                                              Text(
                                                '₹ ${balanceAmount.toStringAsFixed(0)}',
                                                style: AppTypography.titleSmall.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: balanceAmount > 0 ? AppColors.softCoral : AppColors.mutedGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Breakdown: Basic, Allowances, Deductions
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Basic: ₹${struct.basicSalary.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11)),
                                          Text('+Allowances: ₹${struct.totalAllowances.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600, fontSize: 11)),
                                          Text('-Deductions: ₹${struct.totalDeductions.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w600, fontSize: 11)),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.edit_note_rounded, size: 20, color: AppColors.softLavender),
                                            tooltip: 'Edit Structure',
                                            onPressed: () => _showEditStructureDialog(context, teacher, struct, activeSchoolId),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Actions: Record Payment, Salary Slip, Payment History
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: OutlinedButton.icon(
                                              onPressed: balanceAmount <= 0
                                                  ? null
                                                  : () => _showRecordSalaryDialog(context, teacher, struct, payroll, balanceAmount),
                                              icon: const Icon(Icons.payments_outlined, size: 16),
                                              label: Text(balanceAmount <= 0 ? 'Fully Paid' : 'Pay Salary'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _generateSalarySlip(context, teacher, struct, payroll),
                                              icon: const Icon(Icons.description_outlined, size: 16),
                                              label: const Text('Slip'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Payment History',
                                            style: IconButton.styleFrom(
                                              backgroundColor: AppColors.softLavender.withValues(alpha: 0.1),
                                            ),
                                            icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.softLavender),
                                            onPressed: () => _showPaymentHistoryDialog(context, teacher, activeSchoolId),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(SalaryStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case SalaryStatus.paid:
        bg = AppColors.mutedGreen.withValues(alpha: 0.15);
        fg = AppColors.mutedGreen;
        label = 'Paid';
        break;
      case SalaryStatus.partial:
        bg = Colors.orange.withValues(alpha: 0.15);
        fg = Colors.orange.shade800;
        label = 'Partial';
        break;
      case SalaryStatus.pending:
        bg = AppColors.softCoral.withValues(alpha: 0.15);
        fg = AppColors.softCoral;
        label = 'Pending';
        break;
      case SalaryStatus.notConfigured:
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.amber.shade900;
        label = 'Not Configured';
        break;
      case SalaryStatus.overdue:
        bg = Colors.red.withValues(alpha: 0.15);
        fg = Colors.red.shade800;
        label = 'Overdue';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }

  void _handleBatchGeneratePayroll(BuildContext context, String schoolId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.softLavender),
            const SizedBox(width: 8),
            Text('Generate Monthly Payroll', style: AppTypography.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batch calculate payroll for all faculty and operational staff for the period:',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.softLavender.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: AppColors.softLavender, size: 20),
                  const SizedBox(width: 8),
                  Text(_selectedMonthYear, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '• Only staff with active, configured salaries will be processed.\n'
              '• Existing payment records and remaining balances will be preserved.\n'
              '• Idempotent: re-generating updates calculations safely.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Run Calculation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBatchProcessing = true);
    try {
      final activeUser = ref.read(authProvider);
      final count = await ref.read(salaryServiceProvider).generateMonthlyPayroll(
            schoolId: schoolId,
            monthYear: _selectedMonthYear,
            generatedBy: activeUser?.id,
          );

      if (!mounted) return;
      setState(() => _isBatchProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.mutedGreen,
          content: Text('Payroll calculated successfully for $count staff members for $_selectedMonthYear!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isBatchProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.softCoral,
          content: Text('Failed to generate payroll: $e'),
        ),
      );
    }
  }

  void _showEditStructureDialog(
    BuildContext context,
    TeacherModel teacher,
    SalaryStructure? struct,
    String schoolId,
  ) {
    final basicCtrl = TextEditingController(
      text: struct != null && struct.basicSalary > 0 ? struct.basicSalary.toStringAsFixed(0) : '',
    );
    final hra = struct?.allowances.firstWhere((a) => a.type == 'HRA', orElse: () => const SalaryAllowance(type: 'HRA', amount: 0.0)).amount ?? 0.0;
    final transport = struct?.allowances.firstWhere((a) => a.type == 'Transport', orElse: () => const SalaryAllowance(type: 'Transport', amount: 0.0)).amount ?? 0.0;
    final pf = struct?.deductions.firstWhere((d) => d.type == 'PF', orElse: () => const SalaryDeduction(type: 'PF', amount: 0.0)).amount ?? 0.0;
    final tax = struct?.deductions.firstWhere((d) => d.type == 'Tax', orElse: () => const SalaryDeduction(type: 'Tax', amount: 0.0)).amount ?? 0.0;

    final hraCtrl = TextEditingController(text: hra > 0 ? hra.toStringAsFixed(0) : '');
    final transportCtrl = TextEditingController(text: transport > 0 ? transport.toStringAsFixed(0) : '');
    final pfCtrl = TextEditingController(text: pf > 0 ? pf.toStringAsFixed(0) : '');
    final taxCtrl = TextEditingController(text: tax > 0 ? tax.toStringAsFixed(0) : '');

    String salaryType = struct?.salaryType ?? 'Monthly';
    String paymentSchedule = struct?.paymentSchedule ?? 'Monthly';
    bool isActive = struct?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final double basicVal = double.tryParse(basicCtrl.text.trim()) ?? 0.0;
            final double hraVal = double.tryParse(hraCtrl.text.trim()) ?? 0.0;
            final double transVal = double.tryParse(transportCtrl.text.trim()) ?? 0.0;
            final double pfVal = double.tryParse(pfCtrl.text.trim()) ?? 0.0;
            final double taxVal = double.tryParse(taxCtrl.text.trim()) ?? 0.0;
            final double netVal = (basicVal + hraVal + transVal - pfVal - taxVal).clamp(0.0, double.infinity);

            return AlertDialog(
              title: Text(struct == null ? 'Configure Salary: ${teacher.name}' : 'Edit Salary: ${teacher.name}', style: AppTypography.titleLarge),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: basicCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Monthly Base Salary (INR) *',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: hraCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'HRA (₹)'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: transportCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Transport (₹)'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: pfCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'PF Deduction (₹)'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: taxCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(labelText: 'Tax / Other (₹)'),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: salaryType,
                      decoration: const InputDecoration(labelText: 'Salary Frequency'),
                      items: ['Monthly', 'Hourly', 'Daily'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => salaryType = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.softLavender.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Net Monthly Salary:', style: AppTypography.bodySmall),
                          Text(
                            '₹ ${netVal.toStringAsFixed(0)}',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: netVal > 0 ? AppColors.mutedGreen : AppColors.softCoral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final basic = double.tryParse(basicCtrl.text.trim()) ?? 0.0;
                    if (basic <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid base salary greater than 0')),
                      );
                      return;
                    }

                    final allowances = <SalaryAllowance>[];
                    if (hraVal > 0) allowances.add(SalaryAllowance(type: 'HRA', amount: hraVal));
                    if (transVal > 0) allowances.add(SalaryAllowance(type: 'Transport', amount: transVal));

                    final deductions = <SalaryDeduction>[];
                    if (pfVal > 0) deductions.add(SalaryDeduction(type: 'PF', amount: pfVal));
                    if (taxVal > 0) deductions.add(SalaryDeduction(type: 'Tax', amount: taxVal));

                    final updated = SalaryStructure(
                      id: struct?.id.isNotEmpty == true ? struct!.id : 'sal_${schoolId}_${teacher.id}',
                      schoolId: schoolId,
                      staffProfileId: teacher.id,
                      staffName: teacher.name,
                      salaryType: salaryType,
                      basicSalary: basic,
                      allowances: allowances,
                      deductions: deductions,
                      effectiveFrom: struct?.effectiveFrom ?? DateTime.now(),
                      paymentSchedule: paymentSchedule,
                      isActive: isActive,
                      createdAt: struct?.createdAt ?? DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    await ref.read(salaryServiceProvider).updateSalaryStructure(teacher.id, updated);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.mutedGreen,
                          content: Text('Salary structure successfully saved for ${teacher.name}!'),
                        ),
                      );
                    }
                  },
                  child: const Text('Save Structure'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordSalaryDialog(
    BuildContext context,
    TeacherModel teacher,
    SalaryStructure struct,
    MonthlyPayrollModel? payroll,
    double remainingBalance,
  ) {
    final amountController = TextEditingController(text: remainingBalance.toStringAsFixed(0));
    final refController = TextEditingController(
      text: 'SAL-TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final notesController = TextEditingController(text: 'Monthly salary disbursement for $_selectedMonthYear');
    String method = 'Bank Transfer';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Record Salary Payment: ${teacher.name}', style: AppTypography.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Remaining Dues for $_selectedMonthYear:', style: AppTypography.bodySmall),
                      Text('₹ ${remainingBalance.toStringAsFixed(0)}', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.softCoral)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Payment Amount (INR) *',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                    helperText: 'Partial or full amount can be entered',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Payment Method'),
                  items: ['Bank Transfer', 'UPI', 'Cheque', 'Cash'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) {
                    if (v != null) method = v;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: refController,
                  decoration: const InputDecoration(labelText: 'Reference Number / Transaction ID'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                if (enteredAmount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an amount greater than 0')),
                  );
                  return;
                }

                if (enteredAmount > remainingBalance + 1.0) {
                  final proceed = await showDialog<bool>(
                    context: context,
                    builder: (alertCtx) => AlertDialog(
                      title: const Text('Excess Payment Warning'),
                      content: Text('The entered amount (₹$enteredAmount) exceeds the remaining balance (₹$remainingBalance). Do you wish to continue?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(alertCtx, false), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.pop(alertCtx, true), child: const Text('Proceed')),
                      ],
                    ),
                  );
                  if (proceed != true) return;
                }

                await ref.read(salaryServiceProvider).recordSalaryPayment(
                      teacher: teacher,
                      monthYear: _selectedMonthYear,
                      amountPaid: enteredAmount,
                      paymentMethod: method,
                      referenceNo: refController.text.trim(),
                      notes: notesController.text.trim(),
                    );

                if (context.mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.mutedGreen,
                      content: Text('Payment of ₹${enteredAmount.toStringAsFixed(0)} recorded for ${teacher.name}!'),
                    ),
                  );
                }
              },
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentHistoryDialog(BuildContext context, TeacherModel teacher, String schoolId) async {
    final history = await ref.read(salaryServiceProvider).getSalaryHistory(teacher.id, schoolId);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.softLavender),
              const SizedBox(width: 8),
              Expanded(child: Text('Payment History: ${teacher.name}', style: AppTypography.titleLarge)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: history.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No payment transactions recorded for this staff member yet.')),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (ctx, index) => const Divider(height: 16),
                    itemBuilder: (ctx, idx) {
                      final item = history[idx];
                      final dateStr = item.paymentDate != null
                          ? DateFormat('dd MMM yyyy, hh:mm a').format(item.paymentDate!)
                          : '—';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(item.month, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                              Text(
                                '₹ ${item.amountPaid.toStringAsFixed(0)}',
                                style: AppTypography.titleSmall.copyWith(
                                  color: AppColors.mutedGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.paymentMethod} • Ref: ${item.referenceNo}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                          ),
                          Text(
                            dateStr,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 10),
                          ),
                          if (item.remainingBalance > 0)
                            Text(
                              'Remaining balance after payment: ₹${item.remainingBalance.toStringAsFixed(0)}',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontSize: 11),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  void _generateSalarySlip(
    BuildContext context,
    TeacherModel teacher,
    SalaryStructure struct,
    MonthlyPayrollModel? payroll,
  ) async {
    final paid = payroll?.amountPaid ?? 0.0;
    final remaining = payroll?.remainingBalance ?? struct.netSalary;
    final status = paid >= struct.netSalary
        ? SalaryStatus.paid
        : (paid > 0 ? SalaryStatus.partial : SalaryStatus.pending);

    final slip = SalarySlipModel(
      slipNo: 'SLIP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
      month: _selectedMonthYear,
      teacherName: teacher.name,
      employeeId: teacher.employeeId.isNotEmpty ? teacher.employeeId : teacher.id.toUpperCase(),
      designation: teacher.designation,
      basicSalary: struct.basicSalary,
      allowances: struct.allowances,
      deductions: struct.deductions,
      netSalary: struct.netSalary,
      amountPaid: paid,
      remainingBalance: remaining,
      status: status,
      paymentDate: DateTime.now(),
      schoolName: ref.read(authProvider.notifier).activeProfile?.schoolName ?? 'School',
    );

    final pdfBytes = await PdfService.generateSalarySlipPdf(slip);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (dialogCtx) {
          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text('${teacher.name} - Salary Slip ($_selectedMonthYear)', style: AppTypography.titleLarge),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.print_rounded),
                    tooltip: 'Print / Share PDF',
                    onPressed: () => PdfService.printOrSharePdf(pdfBytes, 'Salary_Slip_${teacher.name}_$_selectedMonthYear'),
                  ),
                ],
              ),
              body: PdfPreview(
                build: (format) => pdfBytes,
                allowPrinting: true,
                allowSharing: true,
              ),
            ),
          );
        },
      );
    }
  }
}
