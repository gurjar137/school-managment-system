import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/school_os_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/access_models.dart';
import '../dashboard/widgets/dashboard_charts.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

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

    final enrollmentPointsAsync = ref.watch(dashboardMonthlyEnrollmentProvider);
    final attendanceBreakdownAsync = ref.watch(dashboardAttendanceBreakdownProvider);
    final feePointsAsync = ref.watch(dashboardMonthlyFeeProvider);
    final classEnrollmentPointsAsync = ref.watch(dashboardClassEnrollmentProvider);

    final repo = ref.watch(schoolRepositoryProvider);
    final accessService = ref.watch(accessServiceProvider);

    final todayFormatted = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());
    final adminFirstName = (user?.name.isNotEmpty == true) ? user!.name.split(' ').first : 'Administrator';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================================================================
              // 1. WELCOME SECTION (Section 1.C of Reference Screenshot)
              // ================================================================
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;

                  final welcomeText = Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.softAmber,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(Icons.wb_sunny_rounded, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greetingText()}, $adminFirstName!',
                              style: AppTypography.displayMedium.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Here is your school overview for today.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.secondaryText,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final dateCard = Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.primaryAccent),
                        const SizedBox(width: 8),
                        Text(
                          todayFormatted,
                          style: TextStyle(
                            color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.softLavender,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'AY 2026–2027',
                            style: TextStyle(
                              color: AppColors.primaryAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        welcomeText,
                        const SizedBox(height: 12),
                        dateCard,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: welcomeText),
                      const SizedBox(width: 16),
                      dateCard,
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ================================================================
              // 2. FOUR METRIC CARDS (Section 1.D of Reference Screenshot)
              // ================================================================
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardStudents = SchoolOsMetricCard(
                    title: 'Total Students',
                    value: '${metrics.totalStudents}',
                    subtitle: 'Active student roster',
                    badgeText: '+12 this month',
                    icon: Icons.people_alt_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBgColor: AppColors.softBlue,
                    onTap: () => context.go('/students'),
                  );

                  final cardTeachers = SchoolOsMetricCard(
                    title: 'Total Teachers',
                    value: '${metrics.totalTeachers}',
                    subtitle: 'Faculty & Staff',
                    badgeText: '${metrics.activeTeacherAccess} Active',
                    icon: Icons.badge_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBgColor: AppColors.softLavender,
                    onTap: () => context.go('/teachers'),
                  );

                  final cardClasses = SchoolOsMetricCard(
                    title: 'Classes & Sections',
                    value: '${metrics.totalClasses}',
                    subtitle: 'Academic Classes',
                    badgeText: 'All Sections',
                    icon: Icons.meeting_room_rounded,
                    iconColor: AppColors.success,
                    iconBgColor: AppColors.softMint,
                    onTap: () => context.push('/classes'),
                  );

                  final cardFees = SchoolOsMetricCard(
                    title: 'Fees Collected',
                    value: formatRupee(metrics.collectedFees),
                    subtitle: 'Fee Collections',
                    badgeText: 'Pending: ${formatRupee(metrics.pendingFees)}',
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.warning,
                    iconBgColor: AppColors.softAmber,
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

                  if (constraints.maxWidth >= 550) {
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
              const SizedBox(height: 20),

              // ================================================================
              // 3. MAIN DASHBOARD TELEMETRY & GRAPH GRID (Sections 1.E to 1.K)
              // ================================================================
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 1150;

                  // 1. Left / Main Content Area
                  final mainContentColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Student Enrollment Bar Chart + Attendance Overview Donut Chart
                      LayoutBuilder(
                        builder: (context, rowConstraints) {
                          final isRowWide = rowConstraints.maxWidth >= 700;

                          final enrollmentWidget = StudentEnrollmentChartCard(
                            totalStudents: metrics.totalStudents,
                            points: enrollmentPointsAsync.valueOrNull ?? const [],
                            isLoading: enrollmentPointsAsync.isLoading,
                          );

                          final attendanceWidget = AttendanceOverviewDonutCard(
                            breakdown: attendanceBreakdownAsync.valueOrNull ?? AttendanceBreakdownData.empty(),
                            isLoading: attendanceBreakdownAsync.isLoading,
                          );

                          if (isRowWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: enrollmentWidget),
                                const SizedBox(width: 16),
                                Expanded(child: attendanceWidget),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              enrollmentWidget,
                              const SizedBox(height: 16),
                              attendanceWidget,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Row 2: Fee Collection Monthly Bar Chart + Students By Class Donut Chart
                      LayoutBuilder(
                        builder: (context, rowConstraints) {
                          final isRowWide = rowConstraints.maxWidth >= 700;

                          final feeWidget = FeeCollectionBarCard(
                            collectedFees: metrics.collectedFees,
                            pendingFees: metrics.pendingFees,
                            points: feePointsAsync.valueOrNull ?? const [],
                            isLoading: feePointsAsync.isLoading,
                          );

                          final classDonutWidget = StudentsByClassDonutCard(
                            points: classEnrollmentPointsAsync.valueOrNull ?? const [],
                            isLoading: classEnrollmentPointsAsync.isLoading,
                          );

                          if (isRowWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: feeWidget),
                                const SizedBox(width: 16),
                                Expanded(child: classDonutWidget),
                              ],
                            );
                          }

                          return Column(
                            children: [
                              feeWidget,
                              const SizedBox(height: 16),
                              classDonutWidget,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Row 3: Bottom Quick Actions Card (Section 1.K)
                      const SchoolOsQuickActionsCard(),
                    ],
                  );

                  // 2. Right-Side Content Column (Upcoming Events + Recent Activities)
                  final rightSidebarColumn = FutureBuilder(
                    future: Future.wait([
                      repo.getNotices(schoolId: metrics.schoolCode),
                      accessService.getActivityLogs(),
                    ]),
                    builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
                      final notices = (snapshot.data != null && snapshot.data!.isNotEmpty)
                          ? (snapshot.data![0] as List<NoticeModel>)
                          : <NoticeModel>[];
                      final activities = (snapshot.data != null && snapshot.data!.length > 1)
                          ? (snapshot.data![1] as List<ActivityLogModel>)
                          : <ActivityLogModel>[];

                      return Column(
                        children: [
                          UpcomingEventsCard(
                            notices: notices,
                            isLoading: snapshot.connectionState == ConnectionState.waiting,
                          ),
                          const SizedBox(height: 16),
                          RecentActivitiesCard(
                            activities: activities,
                            isLoading: snapshot.connectionState == ConnectionState.waiting,
                          ),
                        ],
                      );
                    },
                  );

                  // Desktop Layout: 2-Column Split
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: mainContentColumn),
                        const SizedBox(width: 16),
                        SizedBox(width: 350, child: rightSidebarColumn),
                      ],
                    );
                  }

                  // Narrow / Tablet / Mobile Layout: Vertically reflowed without overflow
                  return Column(
                    children: [
                      mainContentColumn,
                      const SizedBox(height: 16),
                      rightSidebarColumn,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
