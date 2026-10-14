import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/school_os_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/school_management_models.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

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

  String _greetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metricsAsync = ref.watch(adminDashboardMetricsProvider);
    final metrics = metricsAsync.valueOrNull ?? const AdminDashboardMetrics();
    final repo = ref.watch(schoolRepositoryProvider);
    final schoolMgmt = ref.watch(schoolManagementServiceProvider);

    final todayFormatted = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    final adminFirstName = (user?.name.isNotEmpty == true) ? user!.name.split(' ').first : 'Administrator';

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. WELCOME SECTION
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greetingText()}, $adminFirstName! 👋',
                          style: AppTypography.displayMedium.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? AppColors.pureWhite : AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${metrics.schoolName} Operations',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.secondaryText,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.secondaryText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              todayFormatted,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.secondaryText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          backgroundColor: isDark ? AppColors.darkSurface : AppColors.cardBackground,
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.secondaryText),
                        label: const Text('Refresh', style: TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                        onPressed: () => ref.refresh(adminDashboardMetricsProvider),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. HERO BANNER & QUICK ACTIONS
              SchoolOsHeroBanner(
                headline: 'Build a Brighter Future Together',
                subtitle: 'Streamline campus administration, monitor student performance, and empower faculty with real-time academic intelligence.',
                actions: [
                  SchoolOsQuickActionItem(
                    label: 'Add Student',
                    icon: Icons.person_add_rounded,
                    onTap: () => context.push('/add-student'),
                  ),
                  SchoolOsQuickActionItem(
                    label: 'Add Teacher',
                    icon: Icons.badge_rounded,
                    onTap: () => context.push('/add-teacher'),
                  ),
                  SchoolOsQuickActionItem(
                    label: 'Collect Fee',
                    icon: Icons.payments_rounded,
                    onTap: () => context.go('/fees'),
                  ),
                  SchoolOsQuickActionItem(
                    label: 'Create Notice',
                    icon: Icons.campaign_rounded,
                    onTap: () => context.push('/notices'),
                  ),
                  SchoolOsQuickActionItem(
                    label: 'Assign Homework',
                    icon: Icons.assignment_rounded,
                    onTap: () => context.push('/homework-create'),
                  ),
                  SchoolOsQuickActionItem(
                    label: 'Create Exam',
                    icon: Icons.bar_chart_rounded,
                    onTap: () => context.push('/create-exam'),
                  ),
                  SchoolOsQuickActionItem(
                    label: 'Generate Report',
                    icon: Icons.pie_chart_rounded,
                    onTap: () => context.go('/reports'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. FOUR SCHOOL METRIC CARDS
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardStudents = SchoolOsMetricCard(
                    title: 'Total Students',
                    value: '${metrics.totalStudents}',
                    subtitle: 'All enrolled classes',
                    badgeText: 'Active Roster',
                    icon: Icons.school_rounded,
                    iconColor: AppColors.indigo,
                    onTap: () => context.go('/students'),
                  );

                  final cardTeachers = SchoolOsMetricCard(
                    title: 'Faculty & Staff',
                    value: '${metrics.totalTeachers}',
                    subtitle: '${metrics.activeTeacherAccess} active accounts',
                    badgeText: 'Teaching Staff',
                    icon: Icons.badge_rounded,
                    iconColor: AppColors.success,
                    onTap: () => context.go('/teachers'),
                  );

                  final cardClasses = SchoolOsMetricCard(
                    title: 'Academic Classes',
                    value: '${metrics.totalClasses}',
                    subtitle: 'Configured grade levels',
                    badgeText: 'Sections',
                    icon: Icons.meeting_room_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/classes'),
                  );

                  final cardFees = SchoolOsMetricCard(
                    title: 'Fee Collections',
                    value: _formatCurrency(metrics.collectedFees),
                    subtitle: 'Pending: ${_formatCurrency(metrics.pendingFees)}',
                    badgeText: metrics.pendingFees > 0 ? 'Dues Active' : 'All Clear',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.warning,
                    onTap: () => context.go('/fees'),
                  );

                  if (constraints.maxWidth >= 950) {
                    return Row(
                      children: [
                        Expanded(child: cardStudents),
                        const SizedBox(width: 14),
                        Expanded(child: cardTeachers),
                        const SizedBox(width: 14),
                        Expanded(child: cardClasses),
                        const SizedBox(width: 14),
                        Expanded(child: cardFees),
                      ],
                    );
                  }

                  if (constraints.maxWidth >= 600) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: cardStudents),
                            const SizedBox(width: 14),
                            Expanded(child: cardTeachers),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: cardClasses),
                            const SizedBox(width: 14),
                            Expanded(child: cardFees),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      cardStudents,
                      const SizedBox(height: 12),
                      cardTeachers,
                      const SizedBox(height: 12),
                      cardClasses,
                      const SizedBox(height: 12),
                      cardFees,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // 4. RESPONSIVE DASHBOARD TELEMETRY GRID
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 1000;

                  final attendanceCard = SchoolOsSectionCard(
                    title: 'Attendance Overview',
                    subtitle: 'Daily student & staff attendance status',
                    icon: Icons.fact_check_rounded,
                    iconColor: AppColors.indigo,
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.indigo),
                      label: const Text('Mark Today', style: TextStyle(color: AppColors.indigo, fontSize: 12)),
                      onPressed: () => context.push('/mark-attendance'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatTile('Total Enrolled', '${metrics.totalStudents}', AppColors.navy),
                            Container(width: 1, height: 36, color: AppColors.border),
                            _buildStatTile('Campus Status', 'Active Session', AppColors.success),
                            Container(width: 1, height: 36, color: AppColors.border),
                            _buildStatTile('Analytics', 'Telemetry', AppColors.indigo),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.analytics_rounded, size: 16, color: AppColors.indigo),
                          label: const Text('View Full Attendance Analytics', style: TextStyle(color: AppColors.indigo, fontSize: 13, fontWeight: FontWeight.w600)),
                          onPressed: () => context.push('/attendance-analytics'),
                        ),
                      ],
                    ),
                  );

                  final financeCard = SchoolOsSectionCard(
                    title: 'Fee Collection & Dues',
                    subtitle: 'Student billing summary & ledger reconciliation',
                    icon: Icons.payments_rounded,
                    iconColor: AppColors.warning,
                    trailing: TextButton(
                      child: const Text('Manage Ledger', style: TextStyle(color: AppColors.indigo, fontSize: 12)),
                      onPressed: () => context.go('/fees'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Collected', style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText, fontSize: 11)),
                                Text(_formatCurrency(metrics.collectedFees), style: AppTypography.titleMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Outstanding Dues', style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText, fontSize: 11)),
                                Text(_formatCurrency(metrics.pendingFees), style: AppTypography.titleMedium.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (metrics.collectedFees + metrics.pendingFees) > 0
                                ? (metrics.collectedFees / (metrics.collectedFees + metrics.pendingFees)).clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 8,
                            backgroundColor: AppColors.border,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                onPressed: () => context.go('/fees'),
                                child: const Text('Collect Fee', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: const BorderSide(color: AppColors.border),
                                ),
                                onPressed: () => context.push('/salary'),
                                child: const Text('Staff Payroll', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  final pendingApprovalsCard = FutureBuilder<List<TeacherLeaveModel>>(
                    future: schoolMgmt.getPendingLeaveRequests(),
                    builder: (context, snapshot) {
                      final leaves = snapshot.data ?? [];
                      final pendingLeavesCount = leaves.length;

                      return SchoolOsSectionCard(
                        title: 'Pending Approvals & Queues',
                        subtitle: 'Action items requiring administrative sign-off',
                        icon: Icons.checklist_rounded,
                        iconColor: AppColors.error,
                        child: Column(
                          children: [
                            _buildActionRow(
                              context,
                              icon: Icons.event_note_rounded,
                              title: '$pendingLeavesCount Leave Applications',
                              subtitle: pendingLeavesCount > 0 ? 'Pending teacher leave requests' : 'All leave applications reviewed',
                              badgeText: pendingLeavesCount > 0 ? 'Requires Action' : 'Clear',
                              badgeColor: pendingLeavesCount > 0 ? AppColors.warning : AppColors.success,
                              onTap: () => context.push('/teacher-leaves'),
                            ),
                            const Divider(height: 16),
                            _buildActionRow(
                              context,
                              icon: Icons.bar_chart_rounded,
                              title: 'Examination Results',
                              subtitle: 'Term assessments awaiting publication',
                              badgeText: 'Review Queue',
                              badgeColor: AppColors.indigo,
                              onTap: () => context.go('/results'),
                            ),
                            const Divider(height: 16),
                            _buildActionRow(
                              context,
                              icon: Icons.search_rounded,
                              title: 'Global School Records Search',
                              subtitle: 'Search across 10,000+ students and teachers',
                              badgeText: 'Search',
                              badgeColor: AppColors.secondaryText,
                              onTap: () => context.push('/global-search'),
                            ),
                          ],
                        ),
                      );
                    },
                  );

                  final noticesCard = FutureBuilder<List<NoticeModel>>(
                    future: repo.getNotices(schoolId: metrics.schoolCode),
                    builder: (context, snapshot) {
                      final notices = snapshot.data ?? [];
                      final topNotices = notices.take(3).toList();

                      return SchoolOsSectionCard(
                        title: 'Latest Campus Bulletins',
                        subtitle: 'Official announcements and notices',
                        icon: Icons.campaign_rounded,
                        iconColor: AppColors.indigo,
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.indigo),
                          label: const Text('New Notice', style: TextStyle(color: AppColors.indigo, fontSize: 12)),
                          onPressed: () => context.push('/notices'),
                        ),
                        child: topNotices.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: Text('No announcements posted yet.', style: TextStyle(color: AppColors.secondaryText)),
                                ),
                              )
                            : Column(
                                children: topNotices.map((n) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => context.push('/notices'),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.indigo.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                n.category.toUpperCase(),
                                                style: const TextStyle(color: AppColors.indigo, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    n.title,
                                                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    DateFormat('MMM d, yyyy').format(n.date),
                                                    style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      );
                    },
                  );

                  final securityCard = SchoolOsSectionCard(
                    title: 'Access Control & Security Hub',
                    subtitle: 'Provisioning, permissions, and parental credentials',
                    icon: Icons.security_rounded,
                    iconColor: AppColors.success,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildSmallStatCard(
                                'Teacher Logins',
                                '${metrics.activeTeacherAccess} Active',
                                '${metrics.disabledTeacherAccess} Disabled',
                                Icons.badge_rounded,
                                AppColors.indigo,
                                () => context.push('/teacher-access'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSmallStatCard(
                                'Parent Access',
                                '${metrics.activeParentCodes} Active',
                                'PTM Keys',
                                Icons.qr_code_2_rounded,
                                AppColors.success,
                                () => context.push('/parent-codes'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.manage_accounts_rounded, size: 16, color: AppColors.secondaryText),
                                label: const Text('Manage Admins', style: TextStyle(fontSize: 12)),
                                onPressed: () => context.push('/manage-admins'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.secondaryText),
                                label: const Text('Audit Log', style: TextStyle(fontSize: 12)),
                                onPressed: () => context.push('/activity-log'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  final scheduleCard = SchoolOsSectionCard(
                    title: 'Timetable & Academic Hub',
                    subtitle: 'Class schedules, periods, and room assignments',
                    icon: Icons.calendar_today_rounded,
                    iconColor: AppColors.indigo,
                    trailing: TextButton(
                      child: const Text('Full Timetable', style: TextStyle(color: AppColors.indigo, fontSize: 12)),
                      onPressed: () => context.go('/schedule'),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metrics.teacherDirectorySubtitle,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.indigo,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                                label: const Text('Manage Timetable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => context.go('/schedule'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.secondaryText),
                                label: const Text('Academic Sessions', style: TextStyle(fontSize: 12)),
                                onPressed: () => context.push('/academic-years'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  if (isWide) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: attendanceCard),
                            const SizedBox(width: 16),
                            Expanded(child: financeCard),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: pendingApprovalsCard),
                            const SizedBox(width: 16),
                            Expanded(child: noticesCard),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: scheduleCard),
                            const SizedBox(width: 16),
                            Expanded(child: securityCard),
                          ],
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      attendanceCard,
                      const SizedBox(height: 16),
                      financeCard,
                      const SizedBox(height: 16),
                      pendingApprovalsCard,
                      const SizedBox(height: 16),
                      noticesCard,
                      const SizedBox(height: 16),
                      scheduleCard,
                      const SizedBox(height: 16),
                      securityCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.secondaryText,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.secondaryText),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: AppTypography.labelSmall.copyWith(color: AppColors.secondaryText, fontSize: 11)),
                ],
              ),
            ),
            SchoolOsBadge(text: badgeText, color: badgeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallStatCard(
    String title,
    String value,
    String badge,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text(title, style: const TextStyle(color: AppColors.secondaryText, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
