import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/school_os_widgets.dart';
import '../../data/models/academic_models.dart';
import '../dashboard/widgets/dashboard_charts.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final countAsync = ref.watch(teacherStudentCountProvider);
    final studentCount = countAsync.value ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = ref.watch(schoolRepositoryProvider);
    final attendancePointsAsync = ref.watch(dashboardAttendanceTrendProvider);

    final assignedClassDisplay = (user?.assignedClass != null && user!.assignedClass!.isNotEmpty)
        ? (user.assignedSection != null && user.assignedSection!.isNotEmpty && !user.assignedClass!.toLowerCase().contains(user.assignedSection!.toLowerCase()))
            ? '${user.assignedClass} - ${user.assignedSection}'
            : user.assignedClass!
        : 'Not Assigned';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.mainBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Teacher Profile Banner (Light-first design)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.border,
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppAvatar(
                          imageUrl: user?.avatarUrl ?? '',
                          name: user?.name ?? 'Teacher',
                          radius: 32,
                          borderColor: AppColors.primaryAccent,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user?.name ?? 'Teacher',
                                    style: AppTypography.titleLarge.copyWith(
                                      color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.softMint,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                                    ),
                                    child: Text(
                                      'FACULTY',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Subject: ${user?.subject ?? "Assigned Subjects"}',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                user?.schoolName ?? 'School OS',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Divider(color: isDark ? AppColors.borderDark : AppColors.border, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeaderStat(
                          'ASSIGNED CLASS',
                          assignedClassDisplay,
                          AppColors.primaryAccent,
                          isDark,
                        ),
                        Container(width: 1, height: 28, color: isDark ? AppColors.borderDark : AppColors.border),
                        _buildHeaderStat(
                          'TOTAL ENROLLED',
                          countAsync.isLoading
                              ? '...'
                              : (assignedClassDisplay == 'Not Assigned' || studentCount == 0)
                                  ? '0 Students'
                                  : '$studentCount Student${studentCount == 1 ? '' : 's'}',
                          AppColors.success,
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Teacher Control Center Grid
              const SectionHeader(title: 'Teacher Control Center'),
              const SizedBox(height: 10),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.3,
                children: [
                  _buildSectionTile(
                    context,
                    title: assignedClassDisplay != 'Not Assigned'
                        ? 'My Class $assignedClassDisplay'
                        : 'My Class Roster',
                    subtitle: studentCount == 0
                        ? 'No students enrolled'
                        : '$studentCount Student${studentCount == 1 ? "" : "s"} Enrolled',
                    icon: Icons.groups_rounded,
                    color: AppColors.primaryAccent,
                    onTap: () => context.go('/students'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'Take Attendance',
                    subtitle: assignedClassDisplay != 'Not Assigned'
                        ? 'Class $assignedClassDisplay Attendance'
                        : 'Daily Attendance Marking',
                    icon: Icons.fact_check_rounded,
                    color: AppColors.success,
                    onTap: () => context.go('/attendance'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'Homework & Tasks',
                    subtitle: 'Assign & Track Classwork',
                    icon: Icons.assignment_rounded,
                    color: AppColors.warning,
                    onTap: () => context.push('/homework'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'Marks & Evaluations',
                    subtitle: 'Assessments & Grade Records',
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFF8B5CF6),
                    onTap: () => context.push('/results'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'My Schedule',
                    subtitle: 'Weekly Timetable Periods',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.primaryAccent,
                    onTap: () => context.push('/schedule'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'Leave Applications',
                    subtitle: 'Submit & Track Requests',
                    icon: Icons.event_note_rounded,
                    color: const Color(0xFF0EA5E9),
                    onTap: () => context.push('/teacher-leaves'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Class Attendance Telemetry Widget
              SchoolOsSectionCard(
                title: 'Weekly Class Attendance Trends',
                subtitle: 'Attendance consistency for enrolled students this week',
                icon: Icons.analytics_rounded,
                iconColor: AppColors.primaryAccent,
                trailing: TextButton(
                  child: const Text('View Analytics', style: TextStyle(color: AppColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () => context.push('/attendance-analytics'),
                ),
                child: DashboardAttendanceTrendChart(
                  points: attendancePointsAsync.valueOrNull ?? const [],
                  isLoading: attendancePointsAsync.isLoading,
                ),
              ),
              const SizedBox(height: 24),

              // Class Notices Section
              SectionHeader(
                title: 'Official School Bulletins',
                actionTitle: 'View All',
                onActionTap: () => context.push('/notices'),
              ),
              const SizedBox(height: 10),
              FutureBuilder<List<NoticeModel>>(
                future: repo.getNotices(),
                builder: (context, snapshot) {
                  final notices = snapshot.data ?? [];
                  final latestNotice = notices.isNotEmpty ? notices.first : null;

                  if (latestNotice == null) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                      child: const Center(
                        child: Text('No active notices at this time.', style: TextStyle(color: AppColors.secondaryText)),
                      ),
                    );
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push('/notices'),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.campaign_rounded, color: AppColors.primaryAccent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SchoolOsBadge(text: latestNotice.category.toUpperCase(), color: AppColors.primaryAccent),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('MMM d, yyyy').format(latestNotice.date),
                                      style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  latestNotice.title,
                                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  latestNotice.content,
                                  style: const TextStyle(color: AppColors.secondaryText, fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.secondaryText),
                        ],
                      ),
                    ),
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

  Widget _buildHeaderStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.titleMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.coolGrayLight : AppColors.secondaryText,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BentoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.secondaryText, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: AppTypography.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.pureWhite : AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
