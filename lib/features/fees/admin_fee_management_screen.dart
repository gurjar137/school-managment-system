import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/fee_models.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';

class AdminFeeManagementScreen extends ConsumerStatefulWidget {
  const AdminFeeManagementScreen({super.key});

  @override
  ConsumerState<AdminFeeManagementScreen> createState() => _AdminFeeManagementScreenState();
}

class _AdminFeeManagementScreenState extends ConsumerState<AdminFeeManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Student Fees Filters
  String _studentSearchQuery = '';
  String _studentClassFilter = 'All';
  String _studentStatusFilter = 'All';
  final TextEditingController _studentSearchCtrl = TextEditingController();

  // Payments / Transactions Filters
  String _paymentSearchQuery = '';
  String _paymentClassFilter = 'All';
  String _paymentMethodFilter = 'All';
  String _paymentDateFilter = 'All';
  final TextEditingController _paymentSearchCtrl = TextEditingController();

  // Statements Filters
  String _statementSearchQuery = '';
  String _statementClassFilter = 'All';
  final TextEditingController _statementSearchCtrl = TextEditingController();
  Map<String, dynamic>? _selectedStudentForStatement;

  // Receipts Filters
  String _receiptSearchQuery = '';
  final TextEditingController _receiptSearchCtrl = TextEditingController();

  int _refreshKey = 0;
  Future<Map<String, double>>? _statsFuture;
  Future<List<Map<String, dynamic>>>? _scheduleFuture;
  Future<List<FeeStructureModel>>? _structuresFuture;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final feeService = ref.read(feeServiceProvider);
    final user = ref.read(authProvider);
    final schoolId = (user?.schoolId != null && user!.schoolId!.isNotEmpty)
        ? user.schoolId!
        : '';

    if (schoolId.isEmpty) {
      return;
    }

    setState(() {
      _refreshKey++;
      _statsFuture = feeService.getFeeStats(schoolId: schoolId);
      _scheduleFuture = feeService.getCollectionSchedule(schoolId: schoolId);
      _structuresFuture = feeService.getFeeStructures(schoolId: schoolId);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _studentSearchCtrl.dispose();
    _paymentSearchCtrl.dispose();
    _statementSearchCtrl.dispose();
    _receiptSearchCtrl.dispose();
    super.dispose();
  }

  void _triggerRefresh() {
    _loadData();
  }

  String _formatCurrency(double amount) {
    if (amount <= 0) return '₹0';
    final intAmount = amount.toInt();
    final s = intAmount.toString();
    if (s.length <= 3) return '₹$s';
    final lastThree = s.substring(s.length - 3);
    final remaining = s.substring(0, s.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    return '₹$buffer,$lastThree';
  }

  @override
  Widget build(BuildContext context) {
    final feeService = ref.watch(feeServiceProvider);
    final studentService = ref.watch(studentServiceProvider);
    final activeProfile = ref.watch(authProvider.notifier).activeProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final authUser = ref.watch(authProvider);
    final userSchoolId = authUser?.schoolId;
    final String schoolId = (activeProfile?.schoolId != null && activeProfile!.schoolId.isNotEmpty)
        ? activeProfile.schoolId
        : (userSchoolId != null && userSchoolId.isNotEmpty
            ? userSchoolId
            : '');

    return Scaffold(
      key: ValueKey('fee_screen_$_refreshKey'),
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Campus Fee Management', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh All Fee Records',
            onPressed: _triggerRefresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.softLavender,
          labelColor: AppColors.softLavender,
          unselectedLabelColor: AppColors.coolGray,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Overview'),
            Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'Student Fees'),
            Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Fee Structures'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Payments'),
            Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Statements'),
            Tab(icon: Icon(Icons.receipt_outlined, size: 18), text: 'Receipts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // 1. OVERVIEW TAB
          _buildOverviewTab(context, feeService, schoolId, isDark),

          // 2. STUDENT FEES TAB
          _buildStudentFeesTab(context, feeService, studentService, schoolId, isDark),

          // 3. FEE STRUCTURES TAB
          _buildStructuresTab(context, feeService, schoolId, isDark),

          // 4. PAYMENTS TAB
          _buildPaymentsTab(context, feeService, schoolId, isDark),

          // 5. STATEMENTS TAB
          _buildStatementsTab(context, feeService, schoolId, isDark),

          // 6. RECEIPTS TAB
          _buildReceiptsTab(context, feeService, schoolId, isDark),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRecordPaymentModal(context, schoolId),
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Collect Payment'),
      ),
    );
  }

  // ===========================================================================
  // 1. OVERVIEW TAB
  // ===========================================================================
  Widget _buildOverviewTab(BuildContext context, dynamic feeService, String schoolId, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Metrics Card
        FutureBuilder<Map<String, double>>(
          future: _statsFuture ?? feeService.getFeeStats(schoolId: schoolId),
          builder: (context, snapshot) {
            final stats = snapshot.data ?? {'collected': 0.0, 'pending': 0.0, 'overdue': 0.0, 'total': 0.0, 'today_collection': 0.0, 'collection_rate': 0.0};
            final collected = stats['collected'] ?? 0.0;
            final pending = stats['pending'] ?? 0.0;
            final overdue = stats['overdue'] ?? 0.0;
            final total = stats['total'] ?? (collected + pending);
            final todayCollection = stats['today_collection'] ?? 0.0;
            final int percent = total > 0 ? ((collected / total) * 100).round() : 0;

            return BentoCard(
              backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('CAMPUS ANNUAL FEE COLLECTION', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.softLavender.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('$percent% Collected', style: AppTypography.labelSmall.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _formatCurrency(total),
                    style: AppTypography.displayMedium.copyWith(fontSize: 34, color: AppColors.pureWhite, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCol('Collected', _formatCurrency(collected), AppColors.mutedGreen),
                      Container(width: 1, height: 36, color: AppColors.borderDark),
                      _buildSummaryCol('Pending', _formatCurrency(pending), AppColors.warmAmber),
                      Container(width: 1, height: 36, color: AppColors.borderDark),
                      _buildSummaryCol('Overdue', _formatCurrency(overdue), AppColors.softCoral),
                      Container(width: 1, height: 36, color: AppColors.borderDark),
                      _buildSummaryCol("Today's", _formatCurrency(todayCollection), AppColors.lavenderLight),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Quick Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightNavy,
                  foregroundColor: AppColors.pureWhite,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showRecordPaymentModal(context, schoolId),
                icon: const Icon(Icons.add_card_rounded, size: 18),
                label: const Text('Collect Payment'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showCreateStructureDialog(context, schoolId),
                icon: const Icon(Icons.add_chart_rounded, size: 18),
                label: const Text('Add Fee Structure'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Collection Schedule Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Collection Schedule', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
            TextButton(
              onPressed: () => _tabCtrl.animateTo(1),
              child: const Text('View Student Dues'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        FutureBuilder<List<Map<String, dynamic>>>(
          future: _scheduleFuture ?? feeService.getCollectionSchedule(schoolId: schoolId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Calculating collection schedule...');
            }

            final schedule = snapshot.data ?? [];

            if (schedule.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.mutedGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.mutedGreen.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.mutedGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No pending dues scheduled! All student accounts are fully paid or up to date.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 94,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: schedule.length,
                itemBuilder: (context, index) {
                  final item = schedule[index];
                  final isOverdue = item['is_overdue'] == true;
                  final dateStr = (item['due_date_str'] ?? 'No Due Date').toString();
                  final count = item['student_count'] ?? 0;
                  final dueAmt = (item['total_due'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOverdue ? AppColors.softCoral.withOpacity(0.08) : (isDark ? AppColors.darkSurface : AppColors.pureWhite),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isOverdue ? AppColors.softCoral.withOpacity(0.4) : AppColors.coolGray.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateStr, style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: isOverdue ? AppColors.softCoral : AppColors.midnightNavy)),
                            if (isOverdue)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: AppColors.softCoral, borderRadius: BorderRadius.circular(4)),
                                child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_formatCurrency(dueAmt), style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900, color: isOverdue ? AppColors.softCoral : AppColors.midnightNavy)),
                        Text('$count students', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Student Fee Accounts & Dues Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Student Dues Ledger', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
            TextButton(
              onPressed: () => _tabCtrl.animateTo(1),
              child: const Text('View All Students'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        FutureBuilder<List<StudentFeeAccountModel>>(
          future: feeService.getStudentFeeAccountsWithDetails(schoolId: schoolId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Loading student dues...');
            }

            final accounts = snapshot.data ?? [];

            if (accounts.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Student Fee Accounts',
                message: 'Fee accounts will appear here automatically when students are registered with fee details.',
              );
            }

            return Column(
              children: accounts.take(10).map((acc) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BentoCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    acc.studentName.isNotEmpty ? acc.studentName : 'Student',
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    '${acc.className.isNotEmpty ? acc.className : "Class"} ${acc.sectionName.isNotEmpty ? "(${acc.sectionName})" : ""} • Adm: ${acc.admissionNumber}',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(acc.computedStatus),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Net Fee', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                Text(_formatCurrency(acc.netFee), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Paid Amount', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                Text(_formatCurrency(acc.totalPaid), style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pending Due', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                Text(
                                  _formatCurrency(acc.currentDue),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: acc.currentDue > 0 ? AppColors.softCoral : AppColors.mutedGreen,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.midnightNavy,
                                foregroundColor: AppColors.pureWhite,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () => _showRecordPaymentModal(
                                context,
                                schoolId,
                                preselectedStudent: {
                                  'id': acc.studentId,
                                  'name': acc.studentName,
                                  'admission_number': acc.admissionNumber,
                                  'class_name': acc.className,
                                  'pending_fee': acc.currentDue,
                                  'net_fee': acc.netFee,
                                  'total_paid': acc.totalPaid,
                                  'has_fee_account': true,
                                  'fee_account_id': acc.id,
                                },
                              ),
                              icon: const Icon(Icons.payment_rounded, size: 14),
                              label: const Text('Collect', style: TextStyle(fontSize: 12)),
                            ),
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
        const SizedBox(height: 24),

        // Recent Payment Receipts Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Payment Receipts', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
            TextButton(
              onPressed: () => _tabCtrl.animateTo(2),
              child: const Text('View All Statements'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        FutureBuilder<List<PaymentRecordModel>>(
          future: feeService.getRecentPayments(schoolId: schoolId, limit: 15),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Loading recent payments...');
            }

            final payments = snapshot.data ?? [];

            if (payments.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.receipt_outlined,
                title: 'No Payments Recorded Yet',
                message: 'All recorded payments and generated receipts will appear here in real time.',
              );
            }

            return Column(
              children: payments.take(10).map((pay) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BentoCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.mutedGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_rounded, color: AppColors.mutedGreen, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(pay.studentName.isNotEmpty ? pay.studentName : 'Student', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                                  Text(_formatCurrency(pay.amount), style: AppTypography.titleMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${pay.receiptNumber} • ${pay.paymentMethod.name.toUpperCase()}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                  Text('${pay.paidAt.day}/${pay.paidAt.month}/${pay.paidAt.year}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 20, color: AppColors.softLavender),
                          tooltip: 'View Receipt',
                          onPressed: () {
                            _showReceiptModal(
                              context,
                              FeeReceiptModel(
                                receiptNo: pay.receiptNumber,
                                studentName: pay.studentName,
                                className: pay.className ?? 'Campus Record',
                                admissionNumber: pay.admissionNumber ?? '',
                                date: pay.paidAt,
                                amountPaid: pay.amount,
                                paymentMethod: pay.paymentMethod.name.toUpperCase(),
                                transactionRef: pay.referenceNumber ?? pay.transactionReference ?? '',
                                previousBalance: pay.amount,
                                remainingBalance: 0.0,
                                description: pay.notes ?? 'Tuition Fee Payment',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. FEE STRUCTURES TAB
  // ===========================================================================
  Widget _buildStructuresTab(BuildContext context, dynamic feeService, String schoolId, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Academic Fee Structures', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
                Text('Configure class-wise fee schedules and component breakups', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnightNavy,
                foregroundColor: AppColors.pureWhite,
              ),
              onPressed: () => _showCreateStructureDialog(context, schoolId),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Structure'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        FutureBuilder<List<FeeStructureModel>>(
          future: _structuresFuture ?? feeService.getFeeStructures(schoolId: schoolId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Loading fee structures...');
            }

            final structures = snapshot.data ?? [];

            if (structures.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Fee Structures Defined',
                message: 'Create your first fee structure to start assigning tuition, transport, or lab fees to classes.',
                buttonText: 'Create Fee Structure',
                onAction: () => _showCreateStructureDialog(context, schoolId),
              );
            }

            return Column(
              children: structures.map((st) {
                final targetClass = (st.className.isNotEmpty && st.className != 'All') ? st.className : 'All Classes (Campus-Wide)';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BentoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(st.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            Text(
                              'Total: ${_formatCurrency(st.totalBaseAmount)}',
                              style: AppTypography.titleMedium.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.midnightNavy.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(targetClass, style: AppTypography.labelSmall.copyWith(color: AppColors.midnightNavy, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text('${st.components.length} Fee Components', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                          ],
                        ),
                        if (st.description != null && st.description!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(st.description!, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                        ],
                        const Divider(height: 20),
                        ...st.components.map((c) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(c.name, style: AppTypography.bodyMedium),
                                Text(
                                  '${_formatCurrency(c.amount)} (${c.frequency.name.toUpperCase()})',
                                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.softLavender,
                              side: BorderSide(color: AppColors.softLavender.withOpacity(0.5)),
                            ),
                            onPressed: () => _showAssignDialog(context, st, schoolId),
                            icon: const Icon(Icons.people_alt_rounded, size: 16),
                            label: const Text('Assign to Students'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. STUDENT FEES TAB (PRIMARY WORKSPACE)
  // ===========================================================================
  Widget _buildStudentFeesTab(BuildContext context, dynamic feeService, dynamic studentService, String schoolId, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search & Class filter
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _studentSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by student name or admission no...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _studentSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _studentSearchCtrl.clear();
                            setState(() => _studentSearchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  setState(() => _studentSearchQuery = val);
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _studentClassFilter,
              items: ['All', 'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _studentClassFilter = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['All', 'Due', 'Partially Paid', 'Paid', 'Overdue', 'No Fee'].map((st) {
              final isSel = _studentStatusFilter == st;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(st),
                  selected: isSel,
                  onSelected: (_) {
                    setState(() => _studentStatusFilter = st);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Student Statement Cards
        FutureBuilder<List<Map<String, dynamic>>>(
          future: feeService.getStudentFeeStatements(
            schoolId: schoolId,
            className: _studentClassFilter,
            search: _studentSearchQuery,
            statusFilter: _studentStatusFilter,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Loading student fee roster...');
            }

            final students = snapshot.data ?? [];

            if (students.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.person_off_rounded,
                title: 'No Matching Students',
                message: 'No student fee records match the selected class or status filter.',
              );
            }

            return Column(
              children: students.map((s) {
                final sId = s['id'].toString();
                final sName = (s['name'] ?? 'Student').toString();
                final sClass = (s['class_name'] ?? '').toString();
                final sSec = (s['section_name'] ?? '').toString();
                final sAdm = (s['admission_number'] ?? '').toString();
                final grossFee = (s['gross_fee'] as num?)?.toDouble() ?? 0.0;
                final totalFee = (s['total_fee'] as num?)?.toDouble() ?? 0.0;
                final paidFee = (s['paid_fee'] as num?)?.toDouble() ?? 0.0;
                final pendingFee = (s['pending_fee'] as num?)?.toDouble() ?? 0.0;
                final hasAccount = s['has_fee_account'] == true;
                final feeStatus = (s['fee_status'] ?? 'pending').toString().toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BentoCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sName, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                                  Text(
                                    '${sClass.isNotEmpty ? sClass : "Class"} ${sSec.isNotEmpty ? "($sSec)" : ""} • Adm: $sAdm',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusBadge(hasAccount ? feeStatus : 'no fee'),
                          ],
                        ),
                        const Divider(height: 16),
                        if (hasAccount) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Gross Assessment', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                  Text(_formatCurrency(grossFee), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Net Fee', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                  Text(_formatCurrency(totalFee), style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Paid Amount', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                  Text(_formatCurrency(paidFee), style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Pending Due', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                  Text(
                                    _formatCurrency(pendingFee),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: pendingFee > 0 ? AppColors.softCoral : AppColors.mutedGreen,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedStudentForStatement = s;
                                  });
                                  _tabCtrl.animateTo(4);
                                },
                                icon: const Icon(Icons.description_outlined, size: 14),
                                label: const Text('Statement', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.midnightNavy,
                                  foregroundColor: AppColors.pureWhite,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showRecordPaymentModal(context, schoolId, preselectedStudent: s),
                                icon: const Icon(Icons.payment_rounded, size: 14),
                                label: const Text('Collect Payment', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'No fee account assigned for this student.',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontStyle: FontStyle.italic),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.midnightNavy,
                                  foregroundColor: AppColors.pureWhite,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showAssignFeeToStudentDialog(context, schoolId, sId, sName),
                                icon: const Icon(Icons.add_task_rounded, size: 14),
                                label: const Text('Assign Fee', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 4. PAYMENTS TAB (TRANSACTION LOGS)
  // ===========================================================================
  Widget _buildPaymentsTab(BuildContext context, dynamic feeService, String schoolId, bool isDark) {
    PaymentMethod? methodFilter;
    if (_paymentMethodFilter != 'All') {
      methodFilter = PaymentMethod.values.firstWhere(
        (m) => m.name.toLowerCase() == _paymentMethodFilter.toLowerCase(),
        orElse: () => PaymentMethod.cash,
      );
    }

    DateTime? startDate;
    final now = DateTime.now();
    if (_paymentDateFilter == 'Today') {
      startDate = DateTime(now.year, now.month, now.day);
    } else if (_paymentDateFilter == 'Last 7 Days') {
      startDate = now.subtract(const Duration(days: 7));
    } else if (_paymentDateFilter == 'This Month') {
      startDate = DateTime(now.year, now.month, 1);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search & Filters Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _paymentSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by receipt #, student name, or ref...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _paymentSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _paymentSearchCtrl.clear();
                            setState(() => _paymentSearchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  setState(() => _paymentSearchQuery = val);
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _paymentClassFilter,
              items: ['All', 'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _paymentClassFilter = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Method & Date Filter Chips
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...['All', 'Cash', 'UPI', 'BankTransfer', 'Cheque', 'Online'].map((m) {
                      final isSel = _paymentMethodFilter == m;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(m == 'BankTransfer' ? 'Bank' : m),
                          selected: isSel,
                          onSelected: (_) {
                            setState(() => _paymentMethodFilter = m);
                          },
                        ),
                      );
                    }),
                    const VerticalDivider(width: 16),
                    ...['All', 'Today', 'Last 7 Days', 'This Month'].map((d) {
                      final isSel = _paymentDateFilter == d;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(d),
                          selected: isSel,
                          onSelected: (_) {
                            setState(() => _paymentDateFilter = d);
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        FutureBuilder<List<PaymentRecordModel>>(
          future: feeService.getFilteredPayments(
            schoolId: schoolId,
            className: _paymentClassFilter,
            paymentMethod: methodFilter,
            startDate: startDate,
            searchQuery: _paymentSearchQuery,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Loading transaction records...');
            }

            final payments = snapshot.data ?? [];

            if (payments.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: 'No Payments Recorded',
                message: 'No transaction entries match the selected search or filter criteria.',
              );
            }

            return Column(
              children: payments.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BentoCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.mutedGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.receipt_rounded, color: AppColors.mutedGreen, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    p.studentName.isNotEmpty ? p.studentName : 'Student',
                                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    _formatCurrency(p.amount),
                                    style: AppTypography.titleMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${p.receiptNumber} • ${p.className ?? "Class"} • ${p.paymentMethod.name.toUpperCase()}',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                  ),
                                  Text(
                                    '${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year}',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                  ),
                                ],
                              ),
                              if (p.referenceNumber != null && p.referenceNumber!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Ref: ${p.referenceNumber}',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayLight, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, color: AppColors.softLavender, size: 20),
                          tooltip: 'View & Print Receipt',
                          onPressed: () {
                            _showReceiptModal(
                              context,
                              FeeReceiptModel(
                                receiptNo: p.receiptNumber,
                                studentName: p.studentName,
                                className: p.className ?? 'Campus Record',
                                admissionNumber: p.admissionNumber ?? '',
                                date: p.paidAt,
                                amountPaid: p.amount,
                                paymentMethod: p.paymentMethod.name.toUpperCase(),
                                transactionRef: p.referenceNumber ?? p.transactionReference ?? '',
                                previousBalance: p.amount,
                                remainingBalance: 0.0,
                                description: p.notes ?? 'Campus Fee Payment',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 5. STATEMENTS TAB (STUDENT FINANCIAL LEDGER)
  // ===========================================================================
  Widget _buildStatementsTab(BuildContext context, dynamic feeService, String schoolId, bool isDark) {
    if (_selectedStudentForStatement != null) {
      final s = _selectedStudentForStatement!;
      final sId = s['id'].toString();
      final sName = (s['name'] ?? 'Student').toString();
      final sClass = (s['class_name'] ?? '').toString();
      final sSec = (s['section_name'] ?? '').toString();
      final sAdm = (s['admission_number'] ?? '').toString();
      final gross = (s['gross_fee'] as num?)?.toDouble() ?? 0.0;
      final disc = (s['discount_amount'] as num?)?.toDouble() ?? 0.0;
      final waiv = (s['waiver_amount'] as num?)?.toDouble() ?? 0.0;
      final net = (s['total_fee'] as num?)?.toDouble() ?? 0.0;
      final paid = (s['paid_fee'] as num?)?.toDouble() ?? 0.0;
      final pending = (s['pending_fee'] as num?)?.toDouble() ?? 0.0;

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedStudentForStatement = null),
              ),
              const SizedBox(width: 8),
              Text('Student Fee Statement', style: AppTypography.titleLarge),
            ],
          ),
          const SizedBox(height: 12),

          // Statement Header Card
          BentoCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sName, style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900)),
                        Text('$sClass ${sSec.isNotEmpty ? "($sSec)" : ""} • Admission No: $sAdm', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      ],
                    ),
                    _buildStatusBadge(s['fee_status'] ?? 'due'),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCol('Gross Fee', _formatCurrency(gross), AppColors.midnightNavy),
                    _buildSummaryCol('Discount', _formatCurrency(disc), AppColors.softLavender),
                    _buildSummaryCol('Waiver', _formatCurrency(waiv), AppColors.coolGray),
                    _buildSummaryCol('Net Fee', _formatCurrency(net), AppColors.midnightNavy),
                    _buildSummaryCol('Total Paid', _formatCurrency(paid), AppColors.mutedGreen),
                    _buildSummaryCol('Outstanding', _formatCurrency(pending), pending > 0 ? AppColors.softCoral : AppColors.mutedGreen),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showStatementPrintModal(context, s),
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print Statement'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.midnightNavy,
                        foregroundColor: AppColors.pureWhite,
                      ),
                      onPressed: () => _showRecordPaymentModal(context, schoolId, preselectedStudent: s),
                      icon: const Icon(Icons.payment_rounded, size: 16),
                      label: const Text('Collect Payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Transaction Ledger for this Student
          Text('Payment Transaction History', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          FutureBuilder<List<PaymentRecordModel>>(
            future: feeService.getPaymentHistory(schoolId: schoolId, studentId: sId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading student payment history...');
              }

              final history = snapshot.data ?? [];

              if (history.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.receipt_outlined,
                  title: 'No Payments Recorded',
                  message: 'This student has not made any fee payments yet.',
                );
              }

              return Column(
                children: history.map((h) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BentoCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h.receiptNumber, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                              Text('${h.paidAt.day}/${h.paidAt.month}/${h.paidAt.year} • ${h.paymentMethod.name.toUpperCase()}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            ],
                          ),
                          Row(
                            children: [
                              Text(_formatCurrency(h.amount), style: AppTypography.titleMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.print_outlined, size: 18),
                                onPressed: () {
                                  _showReceiptModal(
                                    context,
                                    FeeReceiptModel(
                                      receiptNo: h.receiptNumber,
                                      studentName: sName,
                                      className: sClass,
                                      admissionNumber: sAdm,
                                      date: h.paidAt,
                                      amountPaid: h.amount,
                                      paymentMethod: h.paymentMethod.name.toUpperCase(),
                                      transactionRef: h.referenceNumber ?? h.transactionReference ?? '',
                                      previousBalance: h.amount,
                                      remainingBalance: 0.0,
                                      description: h.notes ?? 'Tuition Fee Payment',
                                    ),
                                  );
                                },
                              ),
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
        ],
      );
    }

    // Default statement browser
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _statementSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search student for statement lookup...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _statementSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _statementSearchCtrl.clear();
                            setState(() => _statementSearchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  setState(() => _statementSearchQuery = val);
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _statementClassFilter,
              items: ['All', 'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _statementClassFilter = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        FutureBuilder<List<Map<String, dynamic>>>(
          future: feeService.getStudentFeeStatements(
            schoolId: schoolId,
            className: _statementClassFilter,
            search: _statementSearchQuery,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Loading student statements...');
            }

            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.description_outlined,
                title: 'No Statement Records Found',
                message: 'No students match your search criteria.',
              );
            }

            return Column(
              children: list.map((st) {
                final sName = (st['name'] ?? 'Student').toString();
                final sClass = (st['class_name'] ?? '').toString();
                final sSec = (st['section_name'] ?? '').toString();
                final sAdm = (st['admission_number'] ?? '').toString();
                final total = (st['total_fee'] as num?)?.toDouble() ?? 0.0;
                final paid = (st['paid_fee'] as num?)?.toDouble() ?? 0.0;
                final pending = (st['pending_fee'] as num?)?.toDouble() ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BentoCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sName, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                              Text('$sClass ${sSec.isNotEmpty ? "($sSec)" : ""} • Adm: $sAdm', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                              const SizedBox(height: 4),
                              Text('Net: ${_formatCurrency(total)} • Paid: ${_formatCurrency(paid)} • Due: ${_formatCurrency(pending)}', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.midnightNavy,
                            foregroundColor: AppColors.pureWhite,
                          ),
                          onPressed: () {
                            setState(() => _selectedStudentForStatement = st);
                          },
                          child: const Text('View Ledger'),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. RECEIPTS TAB (RECEIPT BROWSER & VERIFICATION)
  // ===========================================================================
  Widget _buildReceiptsTab(BuildContext context, dynamic feeService, String schoolId, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search bar
        TextField(
          controller: _receiptSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Search receipts by receipt number, student name, or ref...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _receiptSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _receiptSearchCtrl.clear();
                      setState(() => _receiptSearchQuery = '');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (val) {
            setState(() => _receiptSearchQuery = val);
          },
        ),
        const SizedBox(height: 16),

        FutureBuilder<List<PaymentRecordModel>>(
          future: feeService.getFilteredPayments(
            schoolId: schoolId,
            searchQuery: _receiptSearchQuery,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingStateWidget(message: 'Loading official receipts...');
            }

            final receipts = snapshot.data ?? [];

            if (receipts.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.receipt_outlined,
                title: 'No Receipts Found',
                message: 'Official payment receipts will be displayed here once transactions are recorded.',
              );
            }

            return Column(
              children: receipts.map((r) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BentoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(r.receiptNumber, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900, color: AppColors.midnightNavy)),
                            Text(_formatCurrency(r.amount), style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: AppColors.mutedGreen)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${r.studentName} (${r.className ?? "Class"}) • Adm: ${r.admissionNumber ?? "—"}',
                              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${r.paidAt.day}/${r.paidAt.month}/${r.paidAt.year}',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mode: ${r.paymentMethod.name.toUpperCase()} ${r.referenceNumber != null && r.referenceNumber!.isNotEmpty ? "• Ref: ${r.referenceNumber}" : ""}',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.midnightNavy,
                                foregroundColor: AppColors.pureWhite,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                _showReceiptModal(
                                  context,
                                  FeeReceiptModel(
                                    receiptNo: r.receiptNumber,
                                    studentName: r.studentName,
                                    className: r.className ?? 'Campus Record',
                                    admissionNumber: r.admissionNumber ?? '',
                                    date: r.paidAt,
                                    amountPaid: r.amount,
                                    paymentMethod: r.paymentMethod.name.toUpperCase(),
                                    transactionRef: r.referenceNumber ?? r.transactionReference ?? '',
                                    previousBalance: r.amount,
                                    remainingBalance: 0.0,
                                    description: r.notes ?? 'Official Tuition & Academic Fees Payment',
                                  ),
                                );
                              },
                              icon: const Icon(Icons.print_outlined, size: 14),
                              label: const Text('View & Print', style: TextStyle(fontSize: 12)),
                            ),
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
      ],
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================
  Widget _buildSummaryCol(String label, String val, Color col) {
    return Column(
      children: [
        Text(val, style: AppTypography.titleLarge.copyWith(color: col, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color col = AppColors.warmAmber;
    String label = 'DUE';

    final s = status.toLowerCase().trim();
    if (s == 'paid') {
      col = AppColors.mutedGreen;
      label = 'PAID';
    } else if (s == 'partially_paid' || s.contains('part')) {
      col = AppColors.warmAmber;
      label = 'PARTIALLY PAID';
    } else if (s == 'overdue') {
      col = AppColors.softCoral;
      label = 'OVERDUE';
    } else if (s == 'no fee' || s.contains('none')) {
      col = AppColors.coolGray;
      label = 'NO FEE';
    } else if (s == 'due' || s == 'pending') {
      col = AppColors.warmAmber;
      label = 'DUE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: col.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: col, fontWeight: FontWeight.w900, fontSize: 10),
      ),
    );
  }

  // ===========================================================================
  // DIALOGS: ASSIGN FEE TO STUDENT, CREATE STRUCTURE, RECORD PAYMENT, RECEIPT
  // ===========================================================================
  void _showAssignFeeToStudentDialog(BuildContext context, String schoolId, String studentId, String studentName) {
    final feeCtrl = TextEditingController();
    final discCtrl = TextEditingController(text: '0');
    final waivCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(text: 'Standard Academic Tuition Fee');
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Assign Fee: $studentName', style: AppTypography.titleLarge),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: feeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Gross Fee Amount (₹)', hintText: 'e.g. 35000'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: discCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Concession / Discount (₹)'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: waivCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Waiver (₹)'),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Due Date', style: TextStyle(fontSize: 14)),
                        subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_rounded, size: 20),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => dueDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(labelText: 'Notes / Remarks'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midnightNavy,
                    foregroundColor: AppColors.pureWhite,
                  ),
                  onPressed: () async {
                    final gross = double.tryParse(feeCtrl.text.trim()) ?? 0.0;
                    if (gross <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid gross fee amount.')));
                      return;
                    }
                    final disc = double.tryParse(discCtrl.text.trim()) ?? 0.0;
                    final waiv = double.tryParse(waivCtrl.text.trim()) ?? 0.0;

                    try {
                      await ref.read(feeServiceProvider).assignFeeToStudent(
                        schoolId: schoolId,
                        studentId: studentId,
                        grossFee: gross,
                        discountAmount: disc,
                        waiverAmount: waiv,
                        dueDate: dueDate,
                        notes: notesCtrl.text.trim(),
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _triggerRefresh();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: AppColors.mutedGreen,
                          content: Text('Fee successfully assigned to $studentName!'),
                        ));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign fee: $e')));
                      }
                    }
                  },
                  child: const Text('Assign Fee'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateStructureDialog(BuildContext context, String schoolId) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedClass = 'All';
    List<Map<String, dynamic>> components = [
      {'name': 'Tuition Fee', 'amount': 2500.0, 'frequency': FeeFrequency.monthly},
      {'name': 'Exam & Assessment Fee', 'amount': 1000.0, 'frequency': FeeFrequency.halfYearly},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double total = components.fold(0.0, (sum, c) => sum + (c['amount'] as double));

            return AlertDialog(
              title: Text('Create Academic Fee Structure', style: AppTypography.titleLarge),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Structure Name', hintText: 'e.g. Grade 10 Standard Annual Fee'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedClass,
                        decoration: const InputDecoration(labelText: 'Target Class'),
                        items: ['All', 'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'Campus-Wide (All Classes)' : c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedClass = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description / Remarks (Optional)'),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Fee Components (${components.length})', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                components.add({'name': 'Additional Fee', 'amount': 500.0, 'frequency': FeeFrequency.yearly});
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Component'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...components.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final comp = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: comp['name'] as String,
                                  decoration: const InputDecoration(labelText: 'Component', isDense: true),
                                  onChanged: (val) => comp['name'] = val,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: (comp['amount'] as double).toStringAsFixed(0),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Amount (₹)', isDense: true),
                                  onChanged: (val) => comp['amount'] = double.tryParse(val) ?? 0.0,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.softCoral, size: 20),
                                onPressed: components.length > 1
                                    ? () {
                                        setModalState(() => components.removeAt(idx));
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Base Amount:', style: AppTypography.titleSmall),
                          Text(_formatCurrency(total), style: AppTypography.titleMedium.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    final feeComps = components.map((c) {
                      return FeeComponentModel(
                        id: '',
                        feeStructureId: '',
                        schoolId: schoolId,
                        name: c['name'] as String,
                        amount: c['amount'] as double,
                        frequency: c['frequency'] as FeeFrequency,
                      );
                    }).toList();

                    String? resolvedAyId;
                    try {
                      final years = await ref.read(classSectionServiceProvider).fetchAcademicYears(schoolId);
                      resolvedAyId = years.where((y) => y.status == AccountStatus.active).firstOrNull?.id;
                    } catch (_) {}

                    await ref.read(feeServiceProvider).createFeeStructure(
                      schoolId: schoolId,
                      academicYearId: resolvedAyId,
                      className: selectedClass == 'All' ? '' : selectedClass,
                      name: name,
                      description: descCtrl.text.trim(),
                      components: feeComps,
                    );

                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      _triggerRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.mutedGreen,
                          content: Text('Fee structure "$name" created successfully!'),
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

  void _showAssignDialog(BuildContext context, FeeStructureModel structure, String schoolId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Assign "${structure.name}"', style: AppTypography.titleLarge),
          content: Text(
            'This will apply ${_formatCurrency(structure.totalBaseAmount)} in fees to all students in ${structure.className.isNotEmpty ? structure.className : "all classes"}.\n\nExisting student ledgers and pending balances will be updated automatically.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await ref.read(feeServiceProvider).assignFeeStructure(
                  schoolId: schoolId,
                  academicYearId: structure.academicYearId,
                  feeStructureId: structure.id,
                  className: structure.className,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _triggerRefresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.mutedGreen,
                      content: Text('Fee structure assigned to ${structure.className.isNotEmpty ? structure.className : "students"} successfully!'),
                    ),
                  );
                }
              },
              child: const Text('Confirm & Assign'),
            ),
          ],
        );
      },
    );
  }

  void _showRecordPaymentModal(BuildContext context, String schoolId, {Map<String, dynamic>? preselectedStudent}) {
    final studentService = ref.read(studentServiceProvider);
    final feeService = ref.read(feeServiceProvider);
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;
    Map<String, dynamic>? currentStudent = preselectedStudent;
    bool isSubmitting = false;

    if (preselectedStudent != null) {
      final pend = (preselectedStudent['pending_fee'] as num?)?.toDouble() ?? 0.0;
      if (pend > 0) {
        amountCtrl.text = pend.toStringAsFixed(0);
      }
    }

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hasAccount = currentStudent?['has_fee_account'] != false;
            final pendingDue = (currentStudent?['pending_fee'] as num?)?.toDouble() ?? 0.0;

            return AlertDialog(
              title: Text('Record Fee Payment', style: AppTypography.titleLarge),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (currentStudent == null) ...[
                        FutureBuilder<List<StudentModel>>(
                          future: studentService.getAllStudents(schoolId: schoolId),
                          builder: (context, snapshot) {
                            final students = snapshot.data ?? [];
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Select Student', isDense: true),
                              items: students.map((s) {
                                return DropdownMenuItem(
                                  value: s.id,
                                  child: Text('${s.name} (${s.className})'),
                                );
                              }).toList(),
                              onChanged: (val) async {
                                if (val != null) {
                                  final found = students.firstWhere((s) => s.id == val);
                                  final feeAcc = await feeService.getStudentFeeAccount(found.id, schoolId: schoolId);
                                  setModalState(() {
                                    final due = feeAcc?.currentDue ?? found.pendingFee;
                                    currentStudent = {
                                      'id': found.id,
                                      'name': found.name,
                                      'admission_number': found.admissionNumber,
                                      'class_name': found.className,
                                      'pending_fee': due,
                                      'net_fee': feeAcc?.netFee ?? found.totalFee,
                                      'total_paid': feeAcc?.totalPaid ?? found.paidFee,
                                      'has_fee_account': feeAcc != null,
                                      'fee_account_id': feeAcc?.id,
                                    };
                                    if (due > 0) {
                                      amountCtrl.text = due.toStringAsFixed(0);
                                    } else {
                                      amountCtrl.clear();
                                    }
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.midnightNavy.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(currentStudent!['name'].toString(), style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                                      Text('Class: ${currentStudent!['class_name']} • Adm: ${currentStudent!['admission_number']}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Pending Due', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                                      Text(
                                        _formatCurrency(pendingDue),
                                        style: AppTypography.titleSmall.copyWith(
                                          color: pendingDue > 0 ? AppColors.softCoral : AppColors.mutedGreen,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (!hasAccount) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.warmAmber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: AppColors.warmAmber, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'No active fee account found for this student. Fee account must be created before recording offline payments.',
                                          style: AppTypography.labelSmall.copyWith(color: AppColors.warmAmber),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (pendingDue <= 0 && (currentStudent!['net_fee'] ?? 0.0) > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.mutedGreen.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.mutedGreen, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'All fees for this student have been fully paid.',
                                          style: AppTypography.labelSmall.copyWith(color: AppColors.mutedGreen),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Payment Amount (₹)', hintText: 'Enter amount to collect'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PaymentMethod>(
                        value: selectedMethod,
                        decoration: const InputDecoration(labelText: 'Payment Mode'),
                        items: const [
                          DropdownMenuItem(value: PaymentMethod.cash, child: Text('CASH')),
                          DropdownMenuItem(value: PaymentMethod.upi, child: Text('UPI / GPAY / PHONEPE')),
                          DropdownMenuItem(value: PaymentMethod.bankTransfer, child: Text('BANK TRANSFER / NEFT')),
                          DropdownMenuItem(value: PaymentMethod.cheque, child: Text('CHEQUE / DEMAND DRAFT')),
                          DropdownMenuItem(value: PaymentMethod.online, child: Text('DEBIT / CREDIT CARD')),
                        ],
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedMethod = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: refCtrl,
                        decoration: const InputDecoration(labelText: 'Transaction / Cheque Ref. No (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(labelText: 'Notes / Remarks (e.g. Q1 Tuition Installment)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                          if (currentStudent == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
                            return;
                          }
                          if (!hasAccount) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cannot record payment: Student has no fee account configured.')),
                            );
                            return;
                          }
                          if (amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment amount must be greater than zero')));
                            return;
                          }
                          if (pendingDue > 0 && amt > pendingDue) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Payment amount (₹$amt) cannot exceed remaining balance (₹$pendingDue).')),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);

                          try {
                            final receipt = await ref.read(feeServiceProvider).recordPayment(
                              schoolId: schoolId,
                              studentId: currentStudent!['id'].toString(),
                              studentName: currentStudent!['name'].toString(),
                              className: (currentStudent!['class_name'] ?? '').toString(),
                              admissionNumber: (currentStudent!['admission_number'] ?? '').toString(),
                              amount: amt,
                              paymentMethod: selectedMethod,
                              transactionReference: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : 'Tuition & Academic Fees',
                            );

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              _triggerRefresh();
                              _showReceiptModal(context, receipt);
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e')));
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Generate Receipt & Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReceiptModal(BuildContext context, FeeReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.mutedGreen, size: 48),
                const SizedBox(height: 8),
                Text('PAYMENT SUCCESSFUL', style: AppTypography.titleLarge.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w900)),
                Text('OFFICIAL SCHOOL FEE RECEIPT', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray, letterSpacing: 1.2)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Receipt No: ${receipt.receiptNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.midnightNavy)),
                      Text('${receipt.date.day}/${receipt.date.month}/${receipt.date.year}', style: const TextStyle(color: AppColors.coolGray, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _receiptRow('Student Name', receipt.studentName),
                if (receipt.admissionNumber.isNotEmpty) _receiptRow('Admission No.', receipt.admissionNumber),
                _receiptRow('Class', receipt.className),
                _receiptRow('Payment Method', receipt.paymentMethod),
                if (receipt.transactionRef.isNotEmpty) _receiptRow('Ref. Number', receipt.transactionRef),
                const Divider(height: 24),
                _receiptRow('Amount Paid', _formatCurrency(receipt.amountPaid), isBold: true, highlightColor: AppColors.mutedGreen),
                _receiptRow('Remaining Due', _formatCurrency(receipt.remainingBalance), isBold: true),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt sent to print spooler / PDF exporter')));
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print / Save PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightNavy,
                          foregroundColor: AppColors.pureWhite,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
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
  }

  void _showStatementPrintModal(BuildContext context, Map<String, dynamic> student) {
    final sName = (student['name'] ?? 'Student').toString();
    final sAdm = (student['admission_number'] ?? '').toString();
    final sClass = (student['class_name'] ?? '').toString();
    final gross = (student['gross_fee'] as num?)?.toDouble() ?? 0.0;
    final disc = (student['discount_amount'] as num?)?.toDouble() ?? 0.0;
    final waiv = (student['waiver_amount'] as num?)?.toDouble() ?? 0.0;
    final net = (student['total_fee'] as num?)?.toDouble() ?? 0.0;
    final paid = (student['paid_fee'] as num?)?.toDouble() ?? 0.0;
    final pending = (student['pending_fee'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text('CAMPUS FINANCIAL STATEMENT', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w900, color: AppColors.midnightNavy)),
                      Text('STUDENT FEE LEDGER & BALANCE RECORD', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray, letterSpacing: 1.1)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.midnightNavy.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _receiptRow('Student Name', sName, isBold: true),
                      _receiptRow('Admission No.', sAdm),
                      _receiptRow('Class & Section', sClass),
                      _receiptRow('Statement Date', '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('Financial Assessment Summary', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _receiptRow('Gross Fee Assessed', _formatCurrency(gross)),
                if (disc > 0) _receiptRow('Fee Concession / Discount', '- ${_formatCurrency(disc)}'),
                if (waiv > 0) _receiptRow('Institutional Waiver', '- ${_formatCurrency(waiv)}'),
                const Divider(height: 12),
                _receiptRow('Net Annual Fee Payable', _formatCurrency(net), isBold: true),
                _receiptRow('Total Amount Paid', _formatCurrency(paid), isBold: true, highlightColor: AppColors.mutedGreen),
                const Divider(height: 12),
                _receiptRow('Outstanding Balance Due', _formatCurrency(pending), isBold: true, highlightColor: pending > 0 ? AppColors.softCoral : AppColors.mutedGreen),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statement queued to printer / PDF file saved.')));
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Statement'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightNavy,
                          foregroundColor: AppColors.pureWhite,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
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
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: highlightColor ?? AppColors.midnightNavy,
            ),
          ),
        ],
      ),
    );
  }
}

