import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/services/report_service.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportService = ref.watch(reportServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Campus Executive Reports', style: AppTypography.titleLarge),
      ),
      body: Column(
        children: [
          Container(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: isDark ? AppColors.softLavender : AppColors.midnightNavy,
              unselectedLabelColor: AppColors.coolGray,
              indicatorColor: AppColors.softLavender,
              tabs: const [
                Tab(text: 'Student Report'),
                Tab(text: 'Fee Collection'),
                Tab(text: 'Teacher Report'),
                Tab(text: 'Salary Expense'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentReportTab(reportService),
                _buildFeeReportTab(reportService),
                _buildTeacherReportTab(reportService),
                _buildSalaryReportTab(reportService),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentReportTab(ReportService reportService) {
    return FutureBuilder<StudentReportSummary>(
      future: reportService.getStudentReport(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingStateWidget(message: 'Compiling student stats...');
        final rep = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: BentoCard(
                    child: Column(
                      children: [
                        Text('${rep.totalStudents}', style: AppTypography.numericHeader.copyWith(fontSize: 30, color: AppColors.midnightNavy)),
                        Text('Total Enrolled Students', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BentoCard(
                    child: Column(
                      children: [
                        Text('+${rep.newAdmissionsThisMonth}', style: AppTypography.numericHeader.copyWith(fontSize: 30, color: AppColors.mutedGreen)),
                        Text('New Admissions (Aug)', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('CLASS-WISE STUDENT BREAKDOWN', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
            const SizedBox(height: 8),
            BentoCard(
              child: Column(
                children: rep.classWiseCounts.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                        Text('${e.value} Active Students', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFeeReportTab(ReportService reportService) {
    return FutureBuilder<FeeReportSummary>(
      future: reportService.getFeeReport(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingStateWidget(message: 'Auditing revenue metrics...');
        final rep = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BentoCard(
              backgroundColor: AppColors.midnightNavy,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ANNUAL EXPECTED REVENUE', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                  const SizedBox(height: 4),
                  Text('₹ ${(rep.expectedTotal / 100000).toStringAsFixed(2)} Lakhs', style: AppTypography.numericHeader.copyWith(color: AppColors.pureWhite, fontSize: 28)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Collected: ₹${(rep.collectedTotal / 100000).toStringAsFixed(2)} L', style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w700)),
                      Text('Pending: ₹${(rep.pendingTotal / 100000).toStringAsFixed(2)} L', style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('CLASS-WISE FEE COLLECTION PROGRESS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
            const SizedBox(height: 8),
            BentoCard(
              child: Column(
                children: rep.classWiseCollected.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                            Text('₹ ${e.value.toStringAsFixed(0)} Collected', style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: const LinearProgressIndicator(
                            value: 0.85,
                            minHeight: 8,
                            backgroundColor: AppColors.surfaceLight,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.mutedGreen),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeacherReportTab(ReportService reportService) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: BentoCard(
                child: Column(
                  children: [
                    Text('42', style: AppTypography.numericHeader.copyWith(fontSize: 30, color: AppColors.softLavender)),
                    Text('Total Faculty', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BentoCard(
                child: Column(
                  children: [
                    Text('25', style: AppTypography.numericHeader.copyWith(fontSize: 30, color: AppColors.midnightNavy)),
                    Text('Class Teachers', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSalaryReportTab(ReportService reportService) {
    return FutureBuilder<SalaryReportSummary>(
      future: reportService.getSalaryReport(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingStateWidget(message: 'Auditing salary payroll...');
        final rep = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTHLY PAYROLL EXPENSE', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                  const SizedBox(height: 4),
                  Text('₹ ${rep.monthlyPayrollExpense.toStringAsFixed(2)}', style: AppTypography.numericHeader.copyWith(fontSize: 28, color: AppColors.midnightNavy)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Disbursed: ₹${rep.paidSalariesTotal.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w700)),
                      Text('Pending: ₹${rep.pendingSalariesTotal.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
