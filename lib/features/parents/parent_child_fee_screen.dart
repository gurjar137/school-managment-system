import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/student_model.dart';
import '../../data/models/fee_models.dart';

class ParentChildFeeScreen extends ConsumerStatefulWidget {
  final String? studentId;

  const ParentChildFeeScreen({super.key, this.studentId});

  @override
  ConsumerState<ParentChildFeeScreen> createState() => _ParentChildFeeScreenState();
}

class _ParentChildFeeScreenState extends ConsumerState<ParentChildFeeScreen> {
  String? _activeChildId;
  StudentModel? _activeChild;
  List<StudentModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    final studentService = ref.read(studentServiceProvider);
    final students = await studentService.getAllStudents();
    if (mounted) {
      setState(() {
        _students = students;
        if (students.isNotEmpty) {
          if (widget.studentId != null && students.any((s) => s.id == widget.studentId)) {
            _activeChildId = widget.studentId;
            _activeChild = students.firstWhere((s) => s.id == widget.studentId);
          } else {
            _activeChildId = students.first.id;
            _activeChild = students.first;
          }
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feeService = ref.watch(feeServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Fee Ledger & Receipts', style: AppTypography.titleLarge),
        ),
        body: const LoadingStateWidget(message: 'Loading fee records...'),
      );
    }

    if (_students.isEmpty || _activeChildId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Fee Ledger & Receipts', style: AppTypography.titleLarge),
        ),
        body: const EmptyStateWidget(
          icon: Icons.receipt_long_rounded,
          title: 'No Fee Records Yet',
          message: 'No student fee records are available.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Fee Ledger & Receipts', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Multi-Child Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _activeChildId,
                items: _students.map((s) {
                  final label = s.fullClassCode.isNotEmpty ? '${s.name} (Class ${s.fullClassCode})' : s.name;
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _activeChildId = v;
                      _activeChild = _students.firstWhere((s) => s.id == v);
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Total Outstanding Banner
          FutureBuilder<FeeSummaryModel>(
            future: feeService.getStudentFeeSummary(
              schoolId: _activeChild?.schoolId ?? '',
              studentId: _activeChildId!,
              studentName: _activeChild?.name ?? '',
            ),
            builder: (context, snapshot) {
              final summary = snapshot.data ?? FeeSummaryModel(
                studentId: _activeChildId!,
                studentName: _activeChild?.name ?? '',
                totalDue: 0.0,
                totalPaid: 0.0,
                totalOutstanding: 0.0,
                overdueAmount: 0.0,
              );

              return BentoCard(
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('TOTAL OUTSTANDING BALANCE', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    const SizedBox(height: 6),
                    Text(
                      '₹${summary.totalOutstanding.toStringAsFixed(0)}',
                      style: AppTypography.displayMedium.copyWith(fontSize: 34, color: AppColors.pureWhite, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricCol('Total Due', '₹${summary.totalDue.toStringAsFixed(0)}', AppColors.softLavender),
                        _buildMetricCol('Total Paid', '₹${summary.totalPaid.toStringAsFixed(0)}', AppColors.mutedGreen),
                        _buildMetricCol('Pending', '₹${summary.totalOutstanding.toStringAsFixed(0)}', AppColors.warmAmber),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          Text('Current Fee Ledger', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 12),

          FutureBuilder<List<FeeLedgerModel>>(
            future: feeService.getStudentFeeLedger(
              schoolId: _activeChild?.schoolId ?? '',
              studentId: _activeChildId!,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading child fee ledger...');
              }

              final ledgers = snapshot.data ?? [];

              if (ledgers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No fee ledger records available.',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                  ),
                );
              }

              return Column(
                children: ledgers.map((log) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BentoCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(log.componentName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                              Text('Due Date: ${log.dueDate.day}/${log.dueDate.month}/${log.dueDate.year}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${log.amount.toStringAsFixed(0)}', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w900)),
                              _buildStatusBadge(log.status),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),

          Text('Payment Receipts', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 12),

          FutureBuilder<List<PaymentRecordModel>>(
            future: feeService.getPaymentHistory(
              schoolId: _activeChild?.schoolId ?? '',
              studentId: _activeChildId,
            ),
            builder: (context, snapshot) {
              final payments = snapshot.data ?? [];

              if (payments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No payment receipts available.',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                  ),
                );
              }

              return Column(
                children: payments.map((pay) {
                  return BentoCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.description_rounded, color: AppColors.softLavender),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(pay.receiptNumber, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                Text('${pay.paymentMethod.name.toUpperCase()} • ${pay.paidAt.day}/${pay.paidAt.month}/${pay.paidAt.year}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                              ],
                            ),
                          ],
                        ),
                        Text('₹${pay.amount.toStringAsFixed(0)}', style: AppTypography.titleMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String val, Color col) {
    return Column(
      children: [
        Text(val, style: AppTypography.titleLarge.copyWith(color: col, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
      ],
    );
  }

  Widget _buildStatusBadge(FeeLedgerStatus status) {
    Color col;
    String label;

    switch (status) {
      case FeeLedgerStatus.pending:
        col = AppColors.warmAmber;
        label = 'PENDING';
        break;
      case FeeLedgerStatus.overdue:
        col = AppColors.softCoral;
        label = 'OVERDUE';
        break;
      case FeeLedgerStatus.paid:
      default:
        col = AppColors.mutedGreen;
        label = 'PAID';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: col.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: col, fontWeight: FontWeight.w900, fontSize: 9),
      ),
    );
  }
}
