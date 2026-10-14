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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                _buildDesktopSidebar(context, ref, user, isTeacher, selectedIndex, isDark),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: child),
              ],
            ),
          );
        }

        return Scaffold(
          body: child,
          bottomNavigationBar: _buildBottomNav(context, isTeacher, selectedIndex, isDark),
        );
      },
    );
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
    bool isTeacher,
    int selectedIndex,
    bool isDark,
  ) {
    final navItems = isTeacher
        ? [
            _DesktopNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Dashboard'),
            _DesktopNavItem(1, Icons.people_rounded, Icons.people_outline_rounded, 'My Class'),
            _DesktopNavItem(2, Icons.fact_check_rounded, Icons.fact_check_outlined, 'Attendance'),
            _DesktopNavItem(3, Icons.assignment_rounded, Icons.assignment_outlined, 'Homework'),
            _DesktopNavItem(4, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Results'),
            _DesktopNavItem(5, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
          ]
        : [
            _DesktopNavItem(0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
            _DesktopNavItem(1, Icons.badge_rounded, Icons.badge_outlined, 'Staff & Teachers'),
            _DesktopNavItem(2, Icons.people_rounded, Icons.people_outline_rounded, 'Students'),
            _DesktopNavItem(3, Icons.payments_rounded, Icons.payments_outlined, 'Fees'),
            _DesktopNavItem(4, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Reports'),
            _DesktopNavItem(5, Icons.widgets_rounded, Icons.widgets_outlined, 'More'),
          ];

    final bgColor = isDark ? AppColors.darkSurface : AppColors.pureWhite;
    final primaryColor = isDark ? AppColors.softLavender : AppColors.midnightNavy;

    return Container(
      width: 250,
      color: bgColor,
      child: Column(
        children: [
          // Institution & Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.midnightNavy,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.midnightNavy.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.pureWhite, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'School OS',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.schoolName ?? (isTeacher ? 'Staff Workspace' : 'Institution Command'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.coolGray,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 10),

          // Navigation Links
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = selectedIndex == item.index;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Material(
                    color: isSelected
                        ? (isDark ? AppColors.softLavender.withOpacity(0.18) : AppColors.midnightNavy.withOpacity(0.08))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      hoverColor: isDark
                          ? AppColors.softLavender.withOpacity(0.08)
                          : AppColors.midnightNavy.withOpacity(0.04),
                      onTap: () => _onItemTapped(item.index, context, isTeacher),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? item.activeIcon : item.inactiveIcon,
                              size: 20,
                              color: isSelected ? primaryColor : AppColors.coolGray,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.label,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? primaryColor : (isDark ? AppColors.pureWhite : AppColors.midnightNavy),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // User Profile & Logout Footer
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final avatarUrl = user?.avatarUrl;
                    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
                    return CircleAvatar(
                      radius: 18,
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
                      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
                      child: !hasAvatar
                          ? Text(
                              (user?.name.isNotEmpty == true ? user!.name[0] : 'U').toUpperCase(),
                              style: AppTypography.labelLarge.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? 'Administrator',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.designation ?? (isTeacher ? 'Teacher' : 'Principal'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.coolGray,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign Out',
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.coolGray),
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/role-selection');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    bool isTeacher,
    int selectedIndex,
    bool isDark,
  ) {
    return Container(
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

class _DesktopNavItem {
  final int index;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _DesktopNavItem(this.index, this.activeIcon, this.inactiveIcon, this.label);
}
