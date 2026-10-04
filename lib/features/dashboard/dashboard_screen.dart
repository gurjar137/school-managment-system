import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

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
                        Text(
                          'Good Morning, ${user?.name.split(' ')[0] ?? 'Admin'}',
                          style: AppTypography.displayMedium.copyWith(fontSize: 22),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user?.schoolName ?? "St. Xavier Academy"} • $formattedDate',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/profile'),
                    child: AppAvatar(
                      imageUrl: user?.avatarUrl ?? '',
                      name: user?.name ?? 'Admin',
                      radius: 22,
                      borderColor: AppColors.softLavender,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // SCHOOL PULSE Header
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
                    'SCHOOL PULSE',
                    style: AppTypography.labelMedium.copyWith(
                      letterSpacing: 1.2,
                      color: AppColors.coolGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // SCHOOL PULSE Bento Grid Layout (Distinct visual treatments)
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: BentoCard(
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.pureWhite.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.school_rounded, color: AppColors.lavenderLight, size: 20),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedGreen.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Active',
                                  style: AppTypography.labelSmall.copyWith(color: AppColors.mutedGreen),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '312',
                            style: AppTypography.numericHeader.copyWith(
                              color: AppColors.pureWhite,
                              fontSize: 32,
                            ),
                          ),
                          Text(
                            'Enrolled Students',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        BentoCard(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lavenderLight.withOpacity(0.5),
                          border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                          child: Row(
                            children: [
                              const Icon(Icons.badge_outlined, color: AppColors.softLavender, size: 22),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('24', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800)),
                                  Text('Faculty Staff', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        BentoCard(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: isDark ? AppColors.darkSurface : AppColors.greenLight,
                          border: Border.all(color: AppColors.mutedGreen.withOpacity(0.3)),
                          child: Row(
                            children: [
                              const Icon(Icons.meeting_room_outlined, color: AppColors.mutedGreen, size: 22),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('12', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800)),
                                  Text('Class Sections', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ATTENDANCE OVERVIEW Bento Card
              BentoCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attendance Overview',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Live campus presence telemetry',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                            ),
                          ],
                        ),
                        OutlinedButton(
                          onPressed: () => context.push('/attendance-analytics'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('Analytics', style: AppTypography.labelMedium.copyWith(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const AttendanceProgressCircle(percentage: 94.7, size: 90, strokeWidth: 9),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildAttendancePill(
                                label: 'Present',
                                count: '295 students',
                                color: AppColors.mutedGreen,
                              ),
                              const SizedBox(height: 6),
                              _buildAttendancePill(
                                label: 'Absent',
                                count: '12 students',
                                color: AppColors.softCoral,
                              ),
                              const SizedBox(height: 6),
                              _buildAttendancePill(
                                label: 'Late',
                                count: '5 students',
                                color: AppColors.warmAmber,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.mutedGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up_rounded, color: AppColors.mutedGreen, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Attendance is 3% higher than yesterday',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.greenDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // QUICK ACTIONS Section
              const SectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickActionButton(
                      context,
                      icon: Icons.fact_check_rounded,
                      label: 'Take Attendance',
                      color: AppColors.midnightNavy,
                      textColor: AppColors.pureWhite,
                      onTap: () => context.go('/attendance'),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickActionButton(
                      context,
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Add Student',
                      color: AppColors.softLavender.withOpacity(0.15),
                      textColor: AppColors.softLavender,
                      onTap: () => context.go('/students'),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickActionButton(
                      context,
                      icon: Icons.assignment_add,
                      label: 'Create Homework',
                      color: AppColors.amberLight,
                      textColor: AppColors.amberDark,
                      onTap: () => context.push('/homework-create'),
                    ),
                    const SizedBox(width: 12),
                    _buildQuickActionButton(
                      context,
                      icon: Icons.campaign_rounded,
                      label: 'Create Notice',
                      color: AppColors.coralLight,
                      textColor: AppColors.coralDark,
                      onTap: () => context.push('/notices'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // TODAY'S SCHEDULE Timeline
              SectionHeader(
                title: "Today's Schedule",
                actionTitle: 'Full Timetable',
                onActionTap: () => context.go('/schedule'),
              ),
              const SizedBox(height: 8),
              _buildScheduleTimeline(context),

              const SizedBox(height: 24),

              // RECENT ACTIVITY Section
              const SectionHeader(title: 'Recent Campus Activity'),
              const SizedBox(height: 8),
              _buildRecentActivityList(context),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendancePill({
    required String label,
    required String count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(count, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTimeline(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final scheduleItems = [
      {'time': '08:00 AM', 'title': 'Morning Assembly & Prayer', 'class': 'Main Ground', 'isCurrent': false},
      {'time': '09:00 AM', 'title': 'Mathematics (Algebra)', 'class': 'Class 8A • Room 204', 'isCurrent': true},
      {'time': '10:00 AM', 'title': 'Physics & Optics Lab', 'class': 'Class 9B • Science Lab', 'isCurrent': false},
      {'time': '11:00 AM', 'title': 'English Grammar & Speech', 'class': 'Class 7C • Room 105', 'isCurrent': false},
    ];

    return BentoCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: scheduleItems.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isCurrent = item['isCurrent'] as bool;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    item['time'] as String,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent ? AppColors.softLavender : AppColors.coolGray,
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isCurrent ? AppColors.softLavender : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? AppColors.lavenderLight : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    if (idx < scheduleItems.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? (isDark ? AppColors.softLavender.withOpacity(0.15) : AppColors.lavenderLight)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrent
                          ? Border.all(color: AppColors.softLavender.withOpacity(0.4))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item['title'] as String,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.softLavender,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'NOW',
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 8,
                                    color: AppColors.pureWhite,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['class'] as String,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivityList(BuildContext context) {
    final activities = [
      {
        'icon': Icons.fact_check_rounded,
        'color': AppColors.mutedGreen,
        'title': 'Attendance marked for Class 8A',
        'desc': 'Class educator recorded daily attendance.',
        'time': '10 mins ago'
      },
      {
        'icon': Icons.assignment_rounded,
        'color': AppColors.softLavender,
        'title': 'New Homework Published',
        'desc': 'Mathematics Chapter 4 Worksheet assigned.',
        'time': '1 hour ago'
      },
      {
        'icon': Icons.person_add_rounded,
        'color': AppColors.warmAmber,
        'title': 'New Student Enrolled',
        'desc': 'Student registration completed for Class 8A.',
        'time': '3 hours ago'
      },
    ];

    return BentoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: activities.map((act) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (act['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(act['icon'] as IconData, size: 20, color: act['color'] as Color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        act['title'] as String,
                        style: AppTypography.titleSmall,
                      ),
                      Text(
                        act['desc'] as String,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                      ),
                    ],
                  ),
                ),
                Text(
                  act['time'] as String,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 10),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
