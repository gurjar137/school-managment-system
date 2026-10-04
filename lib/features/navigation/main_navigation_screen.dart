import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/user_model.dart';

class MainNavigationScreen extends ConsumerWidget {
  final Widget child;

  const MainNavigationScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context, bool isTeacher) {
    final location = GoRouterState.of(context).uri.toString();
    if (isTeacher) {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/students')) return 1;
      if (location.startsWith('/attendance')) return 2;
      if (location.startsWith('/homework')) return 3;
      if (location.startsWith('/results')) return 4;
      if (location.startsWith('/profile')) return 5;
      return 0;
    } else {
      if (location.startsWith('/home')) return 0;
      if (location.startsWith('/teachers')) return 1;
      if (location.startsWith('/students')) return 2;
      if (location.startsWith('/fees')) return 3;
      if (location.startsWith('/reports')) return 4;
      if (location.startsWith('/more')) return 5;
      return 0;
    }
  }

  void _onItemTapped(int index, BuildContext context, bool isTeacher) {
    if (isTeacher) {
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/students');
          break;
        case 2:
          context.go('/attendance');
          break;
        case 3:
          context.go('/homework');
          break;
        case 4:
          context.go('/results');
          break;
        case 5:
          context.go('/profile');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/home');
          break;
        case 1:
          context.go('/teachers');
          break;
        case 2:
          context.go('/students');
          break;
        case 3:
          context.go('/fees');
          break;
        case 4:
          context.go('/reports');
          break;
        case 5:
          context.go('/more');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isTeacher = user?.role == UserRole.teacher;
    final selectedIndex = _calculateSelectedIndex(context, isTeacher);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: isTeacher
                    ? [
                        _buildNavItem(context, 0, Icons.home_rounded, Icons.home_outlined, 'Dashboard', selectedIndex, isTeacher),
                        _buildNavItem(context, 1, Icons.people_rounded, Icons.people_outline_rounded, 'My Class', selectedIndex, isTeacher),
                        _buildNavItem(context, 2, Icons.fact_check_rounded, Icons.fact_check_outlined, 'Attendance', selectedIndex, isTeacher),
                        _buildNavItem(context, 3, Icons.assignment_rounded, Icons.assignment_outlined, 'Homework', selectedIndex, isTeacher),
                        _buildNavItem(context, 4, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Results', selectedIndex, isTeacher),
                        _buildNavItem(context, 5, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', selectedIndex, isTeacher),
                      ]
                    : [
                        _buildNavItem(context, 0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard', selectedIndex, isTeacher),
                        _buildNavItem(context, 1, Icons.badge_rounded, Icons.badge_outlined, 'Staff & Teachers', selectedIndex, isTeacher),
                        _buildNavItem(context, 2, Icons.people_rounded, Icons.people_outline_rounded, 'Students', selectedIndex, isTeacher),
                        _buildNavItem(context, 3, Icons.payments_rounded, Icons.payments_outlined, 'Fees', selectedIndex, isTeacher),
                        _buildNavItem(context, 4, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Reports', selectedIndex, isTeacher),
                        _buildNavItem(context, 5, Icons.widgets_rounded, Icons.widgets_outlined, 'More', selectedIndex, isTeacher),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    int selectedIndex,
    bool isTeacher,
  ) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onItemTapped(index, context, isTeacher),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.softLavender.withOpacity(0.2) : AppColors.midnightNavy.withOpacity(0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              size: 20,
              color: isSelected
                  ? (isDark ? AppColors.softLavender : AppColors.midnightNavy)
                  : AppColors.coolGray,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? AppColors.softLavender : AppColors.midnightNavy)
                    : AppColors.coolGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
