import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/salary_models.dart';
import '../../data/services/pdf_service.dart';

class AdminSalaryScreen extends ConsumerStatefulWidget {
  const AdminSalaryScreen({super.key});

  @override
  ConsumerState<AdminSalaryScreen> createState() => _AdminSalaryScreenState();
}

class _AdminSalaryScreenState extends ConsumerState<AdminSalaryScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salaryService = ref.watch(salaryServiceProvider);
    final teacherService = ref.watch(teacherServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Teacher Salary & Payroll', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Metrics
          FutureBuilder(
            future: ref.watch(reportServiceProvider).getSalaryReport(),
            builder: (context, snapshot) {
              final report = snapshot.data;
              final expense = report?.monthlyPayrollExpense ?? 0.0;
              final paid = report?.paidSalariesTotal ?? 0.0;
              final pending = report?.pendingSalariesTotal ?? 0.0;

              return BentoCard(
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MONTHLY FACULTY PAYROLL', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    const SizedBox(height: 6),
                    Text('₹ ${expense.toStringAsFixed(2)}', style: AppTypography.numericHeader.copyWith(color: AppColors.pureWhite, fontSize: 30)),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Disbursed: ₹ ${paid.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w700)),
                        Text('Pending Dues: ₹ ${pending.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Faculty Salary Profiles & Payroll'),
          const SizedBox(height: 8),

          FutureBuilder(
            future: teacherService.getTeachers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Calculating faculty payroll...');
              }
              final teachers = snapshot.data ?? [];

              if (teachers.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.badge_outlined,
                  title: 'No Teachers Found',
                  message: 'Add faculty members to configure and process monthly payroll.',
                );
              }

              return Column(
                children: teachers.map((teacher) {
                  return FutureBuilder(
                    future: salaryService.getSalaryStructure(teacher.id),
                    builder: (context, structSnapshot) {
                      if (!structSnapshot.hasData) return const SizedBox.shrink();
                      final struct = structSnapshot.data!;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BentoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppAvatar(imageUrl: teacher.avatarUrl, name: teacher.name, radius: 22, borderColor: AppColors.softLavender),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(teacher.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                        Text('${teacher.designation} • ${teacher.assignedClass}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('₹ ${struct.netSalary.toStringAsFixed(0)}', style: AppTypography.titleSmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w800)),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.softLavender),
                                            tooltip: 'Edit Salary Structure',
                                            onPressed: () => _showEditStructureDialog(context, teacher, struct),
                                          ),
                                        ],
                                      ),
                                      Text('Net Monthly', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 9)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),

                              // Calculation Breakdown
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Basic: ₹${struct.basicSalary.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                  Text('+Allowances: ₹${struct.totalAllowances.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600)),
                                  Text('-Deductions: ₹${struct.totalDeductions.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showRecordSalaryDialog(context, teacher, struct),
                                      icon: const Icon(Icons.payments_outlined, size: 16),
                                      label: const Text('Record Payment'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _generateSalarySlip(context, teacher, struct),
                                      icon: const Icon(Icons.description_outlined, size: 16),
                                      label: const Text('Salary Slip'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditStructureDialog(BuildContext context, TeacherModel teacher, SalaryStructure struct) {
    final basicCtrl = TextEditingController(text: struct.basicSalary.toStringAsFixed(0));
    final hra = struct.allowances.firstWhere((a) => a.type == 'HRA', orElse: () => const SalaryAllowance(type: 'HRA', amount: 4000.0)).amount;
    final transport = struct.allowances.firstWhere((a) => a.type == 'Transport', orElse: () => const SalaryAllowance(type: 'Transport', amount: 1000.0)).amount;
    final pf = struct.deductions.firstWhere((d) => d.type == 'PF', orElse: () => const SalaryDeduction(type: 'PF', amount: 1000.0)).amount;

    final hraCtrl = TextEditingController(text: hra.toStringAsFixed(0));
    final transportCtrl = TextEditingController(text: transport.toStringAsFixed(0));
    final pfCtrl = TextEditingController(text: pf.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Salary Structure: ${teacher.name}', style: AppTypography.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: basicCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Basic Salary (INR)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: hraCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'HRA Allowance (INR)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: transportCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Transport Allowance (INR)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pfCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'PF / Tax Deduction (INR)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final basic = double.tryParse(basicCtrl.text) ?? struct.basicSalary;
                final newHra = double.tryParse(hraCtrl.text) ?? hra;
                final newTrans = double.tryParse(transportCtrl.text) ?? transport;
                final newPf = double.tryParse(pfCtrl.text) ?? pf;

                final updated = SalaryStructure(
                  basicSalary: basic,
                  allowances: [
                    SalaryAllowance(type: 'HRA', amount: newHra),
                    SalaryAllowance(type: 'Transport', amount: newTrans),
                  ],
                  deductions: [
                    SalaryDeduction(type: 'PF', amount: newPf),
                  ],
                );

                await ref.read(salaryServiceProvider).updateSalaryStructure(teacher.id, updated);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Salary structure updated for ${teacher.name}!')),
                  );
                }
              },
              child: const Text('Save Structure'),
            ),
          ],
        );
      },
    );
  }

  void _showRecordSalaryDialog(BuildContext context, TeacherModel teacher, SalaryStructure struct) {
    final amountController = TextEditingController(text: struct.netSalary.toStringAsFixed(0));
    final refController = TextEditingController(text: 'SAL-TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    String method = 'Bank Transfer';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Disburse Salary: ${teacher.name}', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount to Disburse (INR)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: ['Bank Transfer', 'UPI', 'Cheque', 'Cash'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => method = v!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: refController,
                decoration: const InputDecoration(labelText: 'Reference Number / Txn ID'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? struct.netSalary;
                await ref.read(salaryServiceProvider).recordSalaryPayment(
                      teacher: teacher,
                      monthYear: 'August 2026',
                      amountPaid: amount,
                      paymentMethod: method,
                      referenceNo: refController.text,
                      notes: 'Monthly salary disbursed.',
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Salary payment recorded for ${teacher.name}!')),
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

  void _generateSalarySlip(BuildContext context, TeacherModel teacher, SalaryStructure struct) async {
    final slip = SalarySlipModel(
      slipNo: 'SLIP-2026-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      month: 'August 2026',
      teacherName: teacher.name,
      employeeId: teacher.id.toUpperCase(),
      designation: teacher.designation,
      basicSalary: struct.basicSalary,
      allowances: struct.allowances,
      deductions: struct.deductions,
      netSalary: struct.netSalary,
      status: SalaryStatus.paid,
      paymentDate: DateTime.now(),
    );

    final pdfBytes = await PdfService.generateSalarySlipPdf(slip);

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return Dialog.fullscreen(
            child: Scaffold(
              appBar: AppBar(
                title: Text('${teacher.name} - Salary Slip', style: AppTypography.titleLarge),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.print_rounded),
                    onPressed: () => PdfService.printOrSharePdf(pdfBytes, 'Salary_Slip_${teacher.name}'),
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
