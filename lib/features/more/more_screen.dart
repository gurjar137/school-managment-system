import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/reusable_widgets.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Command Hub & Modules', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ACADEMIC Section
          _buildCategoryHeader('ACADEMIC MANAGEMENT'),
          _buildGridGroup(context, [
            _ModuleItem('Homework', Icons.assignment_outlined, AppColors.softLavender, '/homework'),
            _ModuleItem('Exams', Icons.assignment_turned_in_outlined, AppColors.amberDark, '/exams'),
            _ModuleItem('Timetable', Icons.calendar_today_outlined, AppColors.mutedGreen, '/timetable'),
          ]),
          const SizedBox(height: 24),

          // PEOPLE Section
          _buildCategoryHeader('PEOPLE & CLASSES'),
          _buildGridGroup(context, [
            _ModuleItem('Staff & Teachers', Icons.badge_outlined, AppColors.softLavender, '/teachers'),
            _ModuleItem('Students', Icons.people_outline_rounded, AppColors.mutedGreen, '/students'),
            _ModuleItem('Parents', Icons.family_restroom_rounded, AppColors.midnightNavy, '/parents'),
            _ModuleItem('Classes', Icons.meeting_room_outlined, AppColors.amberDark, '/classes'),
          ]),
          const SizedBox(height: 24),

          // COMMUNICATION Section
          _buildCategoryHeader('COMMUNICATION'),
          _buildGridGroup(context, [
            _ModuleItem('Notices Feed', Icons.campaign_outlined, AppColors.softCoral, '/notices'),
            _ModuleItem('Leave Requests', Icons.event_busy_outlined, AppColors.amberDark, '/leave-requests'),
            _ModuleItem('Notifications', Icons.notifications_none_rounded, AppColors.softLavender, '/notifications'),
          ]),
          const SizedBox(height: 24),

          // ADMINISTRATION Section
          _buildCategoryHeader('ADMINISTRATION & ASSETS'),
          _buildGridGroup(context, [
            _ModuleItem('Fees & Dues', Icons.payments_outlined, AppColors.mutedGreen, '/fees'),
            _ModuleItem('Library', Icons.menu_book_outlined, AppColors.softLavender, '/library'),
            _ModuleItem('Transport', Icons.directions_bus_outlined, AppColors.amberDark, '/transport'),
            _ModuleItem('Reports', Icons.bar_chart_rounded, AppColors.midnightNavy, '/reports'),
          ]),
          const SizedBox(height: 24),

          // SYSTEM Section
          _buildCategoryHeader('SYSTEM PREFERENCES'),
          _buildGridGroup(context, [
            _ModuleItem('User Profile', Icons.person_outline_rounded, AppColors.midnightNavy, '/profile'),
            _ModuleItem('Settings', Icons.settings_outlined, AppColors.coolGray, '/settings'),
          ]),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.coolGray,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGridGroup(BuildContext context, List<_ModuleItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return BentoCard(
          padding: const EdgeInsets.all(8),
          onTap: () => context.push(item.route),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: AppTypography.labelMedium.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModuleItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;

  _ModuleItem(this.title, this.icon, this.color, this.route);
}
