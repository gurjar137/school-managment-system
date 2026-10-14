import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/animated_count_text.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final metricsAsync = ref.watch(adminDashboardMetricsProvider);
    final metrics = metricsAsync.valueOrNull ?? const AdminDashboardMetrics();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                metrics.schoolName,
                                style: AppTypography.displayMedium.copyWith(fontSize: 19),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.softLavender.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                metrics.schoolCode,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.softLavender,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Central Administrator Control Panel',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: AppAvatar(
                          imageUrl: user?.avatarUrl ?? '',
                          name: user?.name ?? 'Admin',
                          radius: 22,
                          borderColor: AppColors.softLavender,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: AppColors.softCoral, size: 22),
                        tooltip: 'Log Out & Switch Role',
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) {
                            context.go('/role-selection');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Global Search Bar Shortcut Trigger
              GestureDetector(
                onTap: () => context.push('/admin-student-search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.softLavender.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.softLavender.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.softLavender),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Search student by name, admission, roll or parent mobile...',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.softLavender.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'GLOBAL',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.softLavender,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // SCHOOL STATS SUMMARY (2x2 Grid)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.softLavender,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SCHOOL METRICS',
                    style: AppTypography.labelMedium.copyWith(
                      letterSpacing: 1.2,
                      color: AppColors.coolGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              LayoutBuilder(
                builder: (context, constraints) {
                  final cardStudents = _buildAdminStatCard(
                    title: 'Total Students',
                    value: '${metrics.totalStudents}',
                    badgeText: 'All Classes',
                    color: AppColors.midnightNavy,
                    textColor: AppColors.pureWhite,
                    icon: Icons.groups_rounded,
                    onTap: () => context.go('/students'),
                  );
                  final cardTeachers = _buildAdminStatCard(
                    title: 'Total Teachers',
                    value: '${metrics.totalTeachers}',
                    badgeText: 'Faculty',
                    color: isDark ? AppColors.darkSurface : AppColors.lavenderLight.withOpacity(0.6),
                    textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                    icon: Icons.badge_rounded,
                    onTap: () => context.go('/teachers'),
                  );
                  final cardClasses = _buildAdminStatCard(
                    title: 'Total Classes',
                    value: '${metrics.totalClasses}',
                    badgeText: 'Sections',
                    color: isDark ? AppColors.darkSurface : AppColors.greenLight,
                    textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                    icon: Icons.meeting_room_rounded,
                    onTap: () => context.push('/classes'),
                  );
                  final cardFees = _buildAdminStatCard(
                    title: 'Pending Fees',
                    value: _formatCurrency(metrics.pendingFees),
                    badgeText: metrics.pendingFees > 0 ? 'Dues Active' : 'No Dues',
                    color: isDark ? AppColors.darkSurface : AppColors.amberLight,
                    textColor: isDark ? AppColors.pureWhite : AppColors.amberDark,
                    icon: Icons.payments_rounded,
                    onTap: () => context.go('/fees'),
                  );

                  if (constraints.maxWidth >= 950) {
                    return Row(
                      children: [
                        Expanded(child: cardStudents),
                        const SizedBox(width: 12),
                        Expanded(child: cardTeachers),
                        const SizedBox(width: 12),
                        Expanded(child: cardClasses),
                        const SizedBox(width: 12),
                        Expanded(child: cardFees),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cardStudents),
                          const SizedBox(width: 12),
                          Expanded(child: cardTeachers),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: cardClasses),
                          const SizedBox(width: 12),
                          Expanded(child: cardFees),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Responsive Two-Column Layout for Hubs on Desktop
              LayoutBuilder(
                builder: (context, constraints) {
                  final controlHub = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'Administrative Control Hub'),
                      const SizedBox(height: 8),
                      BentoCard(
                        child: Column(
                          children: [
                            _buildAdminOption(
                              context,
                              icon: Icons.search_rounded,
                              title: 'Global Student Search',
                              subtitle: metrics.totalStudents > 0
                                  ? 'Search across ${metrics.totalStudents} students instantly'
                                  : 'Search students instantly',
                              color: AppColors.softLavender,
                              onTap: () => context.push('/admin-student-search'),
                            ),
                            const Divider(height: 1),
                            _buildAdminOption(
                              context,
                              icon: Icons.badge_outlined,
                              title: 'Class-Wise Teacher Directory',
                              subtitle: metrics.teacherDirectorySubtitle,
                              color: AppColors.mutedGreen,
                              onTap: () => context.go('/teachers'),
                            ),
                            const Divider(height: 1),
                            _buildAdminOption(
                              context,
                              icon: Icons.payments_outlined,
                              title: 'Campus Fees & Revenue Dashboard',
                              subtitle: 'Collected ${_formatCurrency(metrics.collectedFees)} • Pending ${_formatCurrency(metrics.pendingFees)}',
                              color: AppColors.warmAmber,
                              onTap: () => context.go('/fees'),
                            ),
                            const Divider(height: 1),
                            _buildAdminOption(
                              context,
                              icon: Icons.analytics_outlined,
                              title: 'Campus Attendance Telemetry',
                              subtitle: 'Today campus presence: 94.7%',
                              color: AppColors.midnightNavy,
                              onTap: () => context.push('/attendance-analytics'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final pendingHub = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.softCoral,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PENDING ACTIONS & APPROVALS',
                            style: AppTypography.labelMedium.copyWith(
                              letterSpacing: 1.2,
                              color: AppColors.coolGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      BentoCard(
                        child: Column(
                          children: [
                            _buildAdminOption(
                              context,
                              icon: Icons.fact_check_outlined,
                              title: '4 Results Awaiting Review',
                              subtitle: 'Submitted exams waiting for Admin approval & publishing',
                              color: AppColors.softCoral,
                              onTap: () => context.go('/results'),
                            ),
                            const Divider(height: 1),
                            _buildAdminOption(
                              context,
                              icon: Icons.event_note_rounded,
                              title: '3 Teacher Leave Requests',
                              subtitle: 'Pending leave applications requiring review',
                              color: AppColors.warmAmber,
                              onTap: () => context.push('/teacher-leaves'),
                            ),
                            const Divider(height: 1),
                            _buildAdminOption(
                              context,
                              icon: Icons.search_rounded,
                              title: 'Categorized Global Search',
                              subtitle: 'Search across Students, Teachers, Receipts, and Results',
                              color: AppColors.softLavender,
                              onTap: () => context.push('/global-search'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  if (constraints.maxWidth >= 1050) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: controlHub),
                        const SizedBox(width: 20),
                        Expanded(child: pendingHub),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      controlHub,
                      const SizedBox(height: 24),
                      pendingHub,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ACCESS MANAGEMENT CONTROLS SECTION
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.softLavender,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ACCESS CONTROL & SECURITY',
                    style: AppTypography.labelMedium.copyWith(
                      letterSpacing: 1.2,
                      color: AppColors.coolGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildAdminStatCard(
                      title: 'Teacher Access',
                      value: '${metrics.activeTeacherAccess} Active',
                      badgeText: '${metrics.disabledTeacherAccess} Disabled',
                      color: isDark ? AppColors.darkSurface : AppColors.lavenderLight,
                      textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                      icon: Icons.security_rounded,
                      onTap: () => context.push('/teacher-access'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAdminStatCard(
                      title: 'Parent Codes',
                      value: '${metrics.activeParentCodes} Active',
                      badgeText: '${metrics.revokedParentCodes} Revoked',
                      color: isDark ? AppColors.darkSurface : AppColors.greenLight,
                      textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                      icon: Icons.qr_code_2_rounded,
                      onTap: () => context.push('/parent-codes'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              BentoCard(
                child: Column(
                  children: [
                    _buildAdminOption(
                      context,
                      icon: Icons.manage_accounts_rounded,
                      title: 'Manage School Administrators',
                      subtitle: 'Provision admin accounts, roles, and status',
                      color: AppColors.softLavender,
                      onTap: () => context.push('/manage-admins'),
                    ),
                    const Divider(height: 1),
                    _buildAdminOption(
                      context,
                      icon: Icons.lock_person_outlined,
                      title: 'Teacher Login Permissions',
                      subtitle: 'Control authorized teacher emails & access status',
                      color: AppColors.softLavender,
                      onTap: () => context.push('/teacher-access'),
                    ),
                    const Divider(height: 1),
                    _buildAdminOption(
                      context,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Parent Access Codes (PTM)',
                      subtitle: 'Generate, copy, regenerate, or revoke unique parent keys',
                      color: AppColors.mutedGreen,
                      onTap: () => context.push('/parent-codes'),
                    ),
                    const Divider(height: 1),
                    _buildAdminOption(
                      context,
                      icon: Icons.history_toggle_off_rounded,
                      title: 'Admin Activity & Audit Log',
                      subtitle: 'Review recent access changes & system activity',
                      color: AppColors.warmAmber,
                      onTap: () => context.push('/activity-log'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminStatCard({
    required String title,
    required String value,
    required String badgeText,
    required Color color,
    required Color textColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return BentoCard(
      onTap: onTap,
      backgroundColor: color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: textColor.withOpacity(0.8), size: 22),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: AppTypography.labelSmall.copyWith(
                    color: textColor,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAnimatedValue(value, textColor),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedValue(String val, Color textColor) {
    final cleanNumStr = val.replaceAll(RegExp(r'[^0-9.]'), '');
    final doubleVal = double.tryParse(cleanNumStr);
    final isRupee = val.contains('₹');

    if (doubleVal != null && doubleVal > 0) {
      return AnimatedCountText(
        endValue: doubleVal,
        prefix: isRupee ? '₹' : '',
        style: AppTypography.numericHeader.copyWith(
          color: textColor,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Text(
      val,
      style: AppTypography.numericHeader.copyWith(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildAdminOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.coolGray),
      onTap: onTap,
    );
  }
}
