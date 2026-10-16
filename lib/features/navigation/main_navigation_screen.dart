import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/school_os_widgets.dart';
import '../../data/models/user_model.dart';

class MainNavigationScreen extends ConsumerWidget {
  final Widget child;

  const MainNavigationScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final isTeacher = user?.role == UserRole.teacher;
    final currentPath = GoRouterState.of(context).uri.path;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppColors.mainBackground,
            body: Row(
              children: [
                _buildDesktopSidebar(context, ref, user, isTeacher, currentPath, isDark),
                Expanded(
                  child: Column(
                    children: [
                      SchoolOsTopHeader(
                        onSearchTap: () => context.push('/global-search'),
                      ),
                      Expanded(
                        child: Container(
                          color: isDark ? AppColors.darkBackground : AppColors.mainBackground,
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile / Tablet Layout
        return Scaffold(
          backgroundColor: AppColors.mainBackground,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.cardBackground,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.primaryAccent, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user?.schoolName ?? 'School OS',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: AppColors.secondaryText),
                tooltip: 'Global Search',
                onPressed: () => context.push('/global-search'),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.secondaryText),
                tooltip: 'Notifications',
                onPressed: () => context.push('/notifications'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: AppAvatar(
                    imageUrl: user?.avatarUrl ?? '',
                    name: user?.name ?? 'User',
                    radius: 16,
                    borderColor: AppColors.primaryAccent,
                  ),
                ),
              ),
            ],
          ),
          drawer: _buildMobileDrawer(context, ref, user, isTeacher, currentPath, isDark),
          body: child,
          bottomNavigationBar: _buildBottomNav(context, isTeacher, currentPath, isDark),
        );
      },
    );
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
    bool isTeacher,
    String currentPath,
    bool isDark,
  ) {
    return Container(
      width: 235,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.cardBackground,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Institution & Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.softBlue,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primaryAccent.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.primaryAccent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'School OS',
                        style: AppTypography.titleMedium.copyWith(
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isTeacher ? 'Faculty Workspace' : 'Command Center',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
          Divider(color: isDark ? AppColors.borderDark : AppColors.border, height: 1),

          // Scrollable Navigation Menu
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: isTeacher
                    ? _buildTeacherMenuItems(context, currentPath, isDark)
                    : _buildAdminMenuItems(context, currentPath, isDark),
              ),
            ),
          ),

          // User Profile & Logout Footer
          Divider(color: isDark ? AppColors.borderDark : AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: user?.avatarUrl ?? '',
                  name: user?.name ?? 'Admin',
                  radius: 16,
                  borderColor: AppColors.primaryAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? 'Lead Administrator',
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.designation ?? (isTeacher ? 'Faculty' : 'Principal'),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign Out & Lock Workspace',
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
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

  List<Widget> _buildAdminMenuItems(BuildContext context, String currentPath, bool isDark) {
    final isAcademicActive = currentPath.startsWith('/class') ||
        currentPath.startsWith('/academic-year') ||
        currentPath.startsWith('/subject');
    final isFeesActive = currentPath.startsWith('/fee') || currentPath.startsWith('/salary');

    return [
      _buildSidebarItem(context, 'Dashboard', Icons.grid_view_rounded, '/home', currentPath == '/home' || currentPath == '/', isDark),
      _buildSidebarItem(context, 'Students', Icons.groups_rounded, '/students', currentPath.startsWith('/student'), isDark),
      _buildSidebarItem(context, 'Staff & Teachers', Icons.badge_rounded, '/teachers', currentPath.startsWith('/teacher') && !currentPath.contains('leave') && !currentPath.contains('access'), isDark),
      _buildExpandableSidebarItem(
        context: context,
        label: 'Academic',
        icon: Icons.school_outlined,
        currentPath: currentPath,
        isDark: isDark,
        isActive: isAcademicActive,
        subItems: [
          _SubMenuItem(title: 'Classes & Sections', route: '/classes', isSelected: currentPath.startsWith('/class')),
          _SubMenuItem(title: 'Timetable', route: '/schedule', isSelected: currentPath.startsWith('/schedule')),
          _SubMenuItem(title: 'Academic Sessions', route: '/academic-years', isSelected: currentPath.startsWith('/academic-year')),
          _SubMenuItem(title: 'Subject Catalog', route: '/subject-catalog', isSelected: currentPath.startsWith('/subject')),
        ],
      ),
      _buildSidebarItem(context, 'Attendance', Icons.fact_check_rounded, '/attendance', currentPath.startsWith('/attendance') || currentPath.startsWith('/mark-attendance'), isDark),
      _buildSidebarItem(context, 'Timetable', Icons.calendar_today_rounded, '/schedule', currentPath.startsWith('/schedule') || currentPath.startsWith('/timetable'), isDark),
      _buildSidebarItem(context, 'Homework', Icons.assignment_rounded, '/homework', currentPath.startsWith('/homework'), isDark),
      _buildSidebarItem(context, 'Examinations', Icons.bar_chart_rounded, '/results', currentPath.startsWith('/result') || currentPath.startsWith('/exam'), isDark),
      _buildExpandableSidebarItem(
        context: context,
        label: 'Fees & Finance',
        icon: Icons.account_balance_wallet_rounded,
        currentPath: currentPath,
        isDark: isDark,
        isActive: isFeesActive,
        subItems: [
          _SubMenuItem(title: 'Fees', route: '/fees', isSelected: currentPath.startsWith('/fee')),
          _SubMenuItem(title: 'Staff Payroll', route: '/salary', isSelected: currentPath.startsWith('/salary')),
        ],
      ),
      _buildSidebarItem(context, 'Notice Board', Icons.campaign_rounded, '/notices', currentPath.startsWith('/notice'), isDark),
      _buildSidebarItem(context, 'Transport', Icons.directions_bus_rounded, '/transport', currentPath.startsWith('/transport'), isDark),
      _buildSidebarItem(context, 'Library', Icons.local_library_rounded, '/library', currentPath.startsWith('/library'), isDark),
      _buildSidebarItem(context, 'Inventory', Icons.inventory_2_rounded, '/inventory', currentPath.startsWith('/inventory'), isDark),
      _buildSidebarItem(context, 'Communications', Icons.chat_bubble_outline_rounded, '/notifications', currentPath.startsWith('/notification'), isDark),
      _buildSidebarItem(context, 'Reports', Icons.pie_chart_rounded, '/reports', currentPath.startsWith('/report'), isDark),
      _buildSidebarItem(context, 'Settings', Icons.tune_rounded, '/school-settings', currentPath.startsWith('/school-settings') || currentPath == '/settings', isDark),
      _buildSidebarItem(context, 'More', Icons.more_horiz_rounded, '/more', currentPath == '/more', isDark),
    ];
  }

  List<Widget> _buildTeacherMenuItems(BuildContext context, String currentPath, [bool isDark = false]) {
    return [
      _buildSectionHeader('FACULTY WORKSPACE'),
      _buildSidebarItem(context, 'Dashboard', Icons.grid_view_rounded, '/home', currentPath == '/home' || currentPath == '/', isDark),
      _buildSidebarItem(context, 'My Class Roster', Icons.groups_rounded, '/students', currentPath.startsWith('/student'), isDark),
      _buildSidebarItem(context, 'Take Attendance', Icons.fact_check_rounded, '/attendance', currentPath.startsWith('/attendance') || currentPath.startsWith('/mark-attendance'), isDark),
      _buildSidebarItem(context, 'Homework', Icons.assignment_rounded, '/homework', currentPath.startsWith('/homework'), isDark),
      _buildSidebarItem(context, 'Evaluations & Marks', Icons.bar_chart_rounded, '/results', currentPath.startsWith('/result') || currentPath.startsWith('/exam'), isDark),
      _buildSidebarItem(context, 'My Timetable', Icons.calendar_today_rounded, '/schedule', currentPath.startsWith('/schedule') || currentPath.startsWith('/timetable'), isDark),
      _buildSidebarItem(context, 'Apply For Leave', Icons.event_note_rounded, '/teacher-leaves', currentPath.contains('leave'), isDark),
      _buildSidebarItem(context, 'School Notices', Icons.campaign_rounded, '/notices', currentPath.startsWith('/notice'), isDark),
      _buildSidebarItem(context, 'My Profile', Icons.person_rounded, '/profile', currentPath.startsWith('/profile'), isDark),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.secondaryText,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    String label,
    IconData icon,
    String route,
    bool isSelected, [
    bool isDark = false,
  ]) {
    // Screenshot: Dashboard active state has a bright blue rounded background
    final activeBg = const Color(0xFF2563EB);
    final activeColor = Colors.white;
    final inactiveColor = isDark ? AppColors.coolGrayLight : AppColors.primaryText;
    final inactiveIconColor = AppColors.secondaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceLight,
          onTap: () {
            if (!isSelected) {
              context.go(route);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? activeColor : inactiveIconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? activeColor : inactiveColor,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSidebarItem({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String currentPath,
    required bool isDark,
    required bool isActive,
    required List<_SubMenuItem> subItems,
  }) {
    return _ExpandableItemWidget(
      label: label,
      icon: icon,
      isDark: isDark,
      subItems: subItems,
      isActive: isActive,
    );
  }


  Widget _buildMobileDrawer(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
    bool isTeacher,
    String currentPath,
    bool isDark,
  ) {
    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.cardBackground,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.softLavender,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: AppColors.primaryAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'School OS',
                          style: TextStyle(
                            color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          user?.schoolName ?? 'Command Center',
                          style: const TextStyle(color: AppColors.secondaryText, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: isDark ? AppColors.borderDark : AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: isTeacher
                    ? _buildTeacherMenuItems(context, currentPath, isDark)
                    : _buildAdminMenuItems(context, currentPath, isDark),
              ),
            ),
            Divider(color: isDark ? AppColors.borderDark : AppColors.border),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: Text(
                'Sign Out',
                style: TextStyle(
                  color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/role-selection');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(
    BuildContext context,
    bool isTeacher,
    String currentPath,
    bool isDark,
  ) {
    final navItems = isTeacher
        ? [
            _MobileNavItem('Dashboard', Icons.grid_view_rounded, '/home'),
            _MobileNavItem('My Class', Icons.groups_rounded, '/students'),
            _MobileNavItem('Attendance', Icons.fact_check_rounded, '/attendance'),
            _MobileNavItem('Homework', Icons.assignment_rounded, '/homework'),
            _MobileNavItem('Results', Icons.bar_chart_rounded, '/results'),
          ]
        : [
            _MobileNavItem('Dashboard', Icons.grid_view_rounded, '/home'),
            _MobileNavItem('Students', Icons.groups_rounded, '/students'),
            _MobileNavItem('Staff & Teachers', Icons.badge_rounded, '/teachers'),
            _MobileNavItem('Fees', Icons.account_balance_wallet_rounded, '/fees'),
            _MobileNavItem('More', Icons.menu_rounded, '/more'),
          ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: navItems.map((item) {
              final isSelected = item.route == '/home'
                  ? (currentPath == '/home' || currentPath == '/')
                  : currentPath.startsWith(item.route);

              return GestureDetector(
                onTap: () => context.go(item.route),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.softLavender : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem {
  final String label;
  final IconData icon;
  final String route;

  const _MobileNavItem(this.label, this.icon, this.route);
}

class _SubMenuItem {
  final String title;
  final String route;
  final bool isSelected;

  const _SubMenuItem({
    required this.title,
    required this.route,
    required this.isSelected,
  });
}

class _ExpandableItemWidget extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final bool isActive;
  final List<_SubMenuItem> subItems;

  const _ExpandableItemWidget({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.isActive,
    required this.subItems,
  });

  @override
  State<_ExpandableItemWidget> createState() => _ExpandableItemWidgetState();
}

class _ExpandableItemWidgetState extends State<_ExpandableItemWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primaryAccent;
    final inactiveColor = widget.isDark ? AppColors.coolGrayLight : AppColors.primaryText;
    final inactiveIconColor = AppColors.secondaryText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              hoverColor: widget.isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceLight,
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                child: Row(
                  children: [
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.isActive ? activeColor : inactiveIconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.isActive ? activeColor : inactiveColor,
                          fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                      size: 16,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.subItems.map((sub) {
                  return Material(
                    color: sub.isSelected
                        ? (widget.isDark ? AppColors.primaryAccent.withValues(alpha: 0.2) : AppColors.softLavender)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        if (!sub.isSelected) {
                          context.go(sub.route);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: sub.isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sub.title,
                                style: TextStyle(
                                  color: sub.isSelected ? AppColors.primaryAccent : inactiveColor,
                                  fontSize: 12,
                                  fontWeight: sub.isSelected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

