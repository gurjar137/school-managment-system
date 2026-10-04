import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final countAsync = ref.watch(teacherStudentCountProvider);
    final studentCount = countAsync.value ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assignedClassDisplay = (user?.assignedClass != null && user!.assignedClass!.isNotEmpty)
        ? (user.assignedSection != null && user.assignedSection!.isNotEmpty && !user.assignedClass!.toLowerCase().contains(user.assignedSection!.toLowerCase()))
            ? '${user.assignedClass} - ${user.assignedSection}'
            : user.assignedClass!
        : 'Not Assigned';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Teacher Profile Banner
              BentoCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppAvatar(
                          imageUrl: user?.avatarUrl ?? '',
                          name: user?.name ?? 'Teacher',
                          radius: 32,
                          borderColor: AppColors.softLavender,
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
                                      color: AppColors.pureWhite,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.mutedGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'CLASS TEACHER',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.pureWhite,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Subject: ${user?.subject ?? "Mathematics"}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.lavenderLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                user?.schoolName ?? 'St. Xavier Academy',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.coolGrayLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.borderDark, height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeaderStat('ASSIGNED CLASS', assignedClassDisplay, AppColors.lavenderLight),
                        Container(width: 1, height: 28, color: AppColors.borderDark),
                        _buildHeaderStat(
                          'TOTAL STUDENTS',
                          countAsync.isLoading
                              ? '...'
                              : (assignedClassDisplay == 'Not Assigned' || (countAsync.value ?? 0) == 0)
                                  ? '0 Students'
                                  : '${countAsync.value} Student${(countAsync.value ?? 0) == 1 ? '' : 's'}',
                          AppColors.mutedGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Teacher Sections Grid
              const SectionHeader(title: 'Teacher Control Center'),
              const SizedBox(height: 8),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [
                  _buildSectionTile(
                    context,
                    title: assignedClassDisplay != 'Not Assigned'
                        ? 'My Class $assignedClassDisplay'
                        : 'My Class',
                    subtitle: (countAsync.value ?? 0) == 0
                        ? 'No students added yet.'
                        : '${countAsync.value} Student${(countAsync.value ?? 0) == 1 ? "" : "s"} Enrolled',
                    icon: Icons.meeting_room_rounded,
                    color: AppColors.softLavender,
                    onTap: () => context.go('/students'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'View Roster',
                    subtitle: studentCount == 0
                        ? 'No students added yet.'
                        : 'Class Roster & Contacts ($studentCount)',
                    icon: Icons.people_rounded,
                    color: AppColors.mutedGreen,
                    onTap: () => context.go('/students'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'Take Attendance',
                    subtitle: assignedClassDisplay != 'Not Assigned'
                        ? 'Class $assignedClassDisplay Attendance'
                        : 'Daily Attendance',
                    icon: Icons.fact_check_rounded,
                    color: AppColors.midnightNavy,
                    onTap: () => context.go('/attendance'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'Homework',
                    subtitle: 'Assign & Track Exercises',
                    icon: Icons.assignment_rounded,
                    color: AppColors.warmAmber,
                    onTap: () => context.push('/homework'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'Marks & Results',
                    subtitle: 'Term Evaluations',
                    icon: Icons.bar_chart_rounded,
                    color: AppColors.softCoral,
                    onTap: () => context.push('/exams'),
                  ),
                  _buildSectionTile(
                    context,
                    title: 'My Timetable',
                    subtitle: 'Published Schedule',
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.softLavender,
                    onTap: () => context.push('/timetable'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Class Notices Section
              SectionHeader(
                title: 'Class Bulletins & Notices',
                actionTitle: 'View All',
                onActionTap: () => context.push('/notices'),
              ),
              const SizedBox(height: 8),
              BentoCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.softLavender.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.campaign_rounded, color: AppColors.softLavender, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mathematics Mid-Term Revision Session',
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Scheduled for Class 8-A students on Friday at 02:00 PM.',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildHeaderStat(String label, String value, Color color) {
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
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.coolGrayLight,
            fontSize: 9,
            letterSpacing: 1.0,
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
    return BentoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.coolGray, size: 16),
            ],
          ),
          const Spacer(),
          Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
