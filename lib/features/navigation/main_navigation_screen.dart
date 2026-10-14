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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: AppColors.mainBackground,
            body: Row(
              children: [
                _buildDesktopSidebar(context, ref, user, isTeacher, currentPath),
                Expanded(
                  child: Column(
                    children: [
                      SchoolOsTopHeader(
                        onSearchTap: () => context.push('/global-search'),
                      ),
                      Expanded(
                        child: Container(
                          color: AppColors.mainBackground,
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
            backgroundColor: AppColors.cardBackground,
            elevation: 0,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.indigo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  user?.schoolName ?? 'School OS',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                    borderColor: AppColors.indigo,
                  ),
                ),
              ),
            ],
          ),
          drawer: _buildMobileDrawer(context, ref, user, isTeacher, currentPath),
          body: child,
          bottomNavigationBar: _buildBottomNav(context, isTeacher, currentPath),
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
  ) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        border: Border(
          right: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Institution & Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.indigo, Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.indigo.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.schoolName ?? (isTeacher ? 'Faculty Workspace' : 'Command Center'),
                        style: AppTypography.labelSmall.copyWith(
                          color: const Color(0xFF94A3B8),
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
          const Divider(color: Color(0xFF1E293B), height: 1),

          // Scrollable Navigation Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: isTeacher
                  ? _buildTeacherMenuItems(context, currentPath)
                  : _buildAdminMenuItems(context, currentPath),
            ),
          ),

          // User Profile & Logout Footer
          const Divider(color: Color(0xFF1E293B), height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: user?.avatarUrl ?? '',
                  name: user?.name ?? 'User',
                  radius: 18,
                  borderColor: AppColors.indigo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user?.name ?? 'Administrator',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.designation ?? (isTeacher ? 'Class Teacher' : 'Campus Admin'),
                        style: AppTypography.labelSmall.copyWith(
                          color: const Color(0xFF94A3B8),
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
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
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

  List<Widget> _buildAdminMenuItems(BuildContext context, String currentPath) {
    return [
      _buildSectionHeader('OVERVIEW'),
      _buildSidebarItem(context, 'Dashboard', Icons.grid_view_rounded, '/home', currentPath == '/home' || currentPath == '/'),

      _buildSectionHeader('ACADEMICS'),
      _buildSidebarItem(context, 'Students', Icons.groups_rounded, '/students', currentPath.startsWith('/student')),
      _buildSidebarItem(context, 'Staff & Teachers', Icons.badge_rounded, '/teachers', currentPath.startsWith('/teacher') && !currentPath.contains('leave') && !currentPath.contains('access')),
      _buildSidebarItem(context, 'Classes & Sections', Icons.meeting_room_rounded, '/classes', currentPath.startsWith('/class')),
      _buildSidebarItem(context, 'Academic Sessions', Icons.calendar_month_rounded, '/academic-years', currentPath.startsWith('/academic-year')),
      _buildSidebarItem(context, 'Timetable', Icons.calendar_today_rounded, '/schedule', currentPath.startsWith('/schedule') || currentPath.startsWith('/timetable')),
      _buildSidebarItem(context, 'Attendance', Icons.fact_check_rounded, '/attendance', currentPath.startsWith('/attendance') || currentPath.startsWith('/mark-attendance')),
      _buildSidebarItem(context, 'Homework', Icons.assignment_rounded, '/homework', currentPath.startsWith('/homework')),
      _buildSidebarItem(context, 'Exams & Results', Icons.bar_chart_rounded, '/results', currentPath.startsWith('/result') || currentPath.startsWith('/exam')),

      _buildSectionHeader('FINANCE & OPERATIONS'),
      _buildSidebarItem(context, 'Fees & Finance', Icons.account_balance_wallet_rounded, '/fees', currentPath.startsWith('/fee')),
      _buildSidebarItem(context, 'Staff Payroll', Icons.receipt_long_rounded, '/salary', currentPath.startsWith('/salary')),
      _buildSidebarItem(context, 'Leave Requests', Icons.event_note_rounded, '/teacher-leaves', currentPath.contains('leave')),
      _buildSidebarItem(context, 'Library Catalog', Icons.local_library_rounded, '/library', currentPath.startsWith('/library')),
      _buildSidebarItem(context, 'Transport Routes', Icons.directions_bus_rounded, '/transport', currentPath.startsWith('/transport')),

      _buildSectionHeader('COMMUNICATIONS'),
      _buildSidebarItem(context, 'Notice Board', Icons.campaign_rounded, '/notices', currentPath.startsWith('/notice')),
      _buildSidebarItem(context, 'Notifications', Icons.notifications_rounded, '/notifications', currentPath.startsWith('/notification')),
      _buildSidebarItem(context, 'Analytics & Reports', Icons.pie_chart_rounded, '/reports', currentPath.startsWith('/report')),

      _buildSectionHeader('SETTINGS & SECURITY'),
      _buildSidebarItem(context, 'Teacher Access', Icons.lock_person_rounded, '/teacher-access', currentPath.startsWith('/teacher-access')),
      _buildSidebarItem(context, 'Parent Access Codes', Icons.qr_code_2_rounded, '/parent-codes', currentPath.startsWith('/parent-code')),
      _buildSidebarItem(context, 'Activity Log', Icons.history_rounded, '/activity-log', currentPath.startsWith('/activity-log')),
      _buildSidebarItem(context, 'School Settings', Icons.tune_rounded, '/school-settings', currentPath.startsWith('/school-settings')),
      _buildSidebarItem(context, 'App Settings', Icons.settings_rounded, '/settings', currentPath == '/settings'),
    ];
  }

  List<Widget> _buildTeacherMenuItems(BuildContext context, String currentPath) {
    return [
      _buildSectionHeader('OVERVIEW'),
      _buildSidebarItem(context, 'Dashboard', Icons.grid_view_rounded, '/home', currentPath == '/home' || currentPath == '/'),

      _buildSectionHeader('ACADEMICS'),
      _buildSidebarItem(context, 'My Class Roster', Icons.groups_rounded, '/students', currentPath.startsWith('/student')),
      _buildSidebarItem(context, 'Take Attendance', Icons.fact_check_rounded, '/attendance', currentPath.startsWith('/attendance') || currentPath.startsWith('/mark-attendance')),
      _buildSidebarItem(context, 'Homework', Icons.assignment_rounded, '/homework', currentPath.startsWith('/homework')),
      _buildSidebarItem(context, 'Evaluations & Marks', Icons.bar_chart_rounded, '/results', currentPath.startsWith('/result') || currentPath.startsWith('/exam')),
      _buildSidebarItem(context, 'My Timetable', Icons.calendar_today_rounded, '/schedule', currentPath.startsWith('/schedule') || currentPath.startsWith('/timetable')),

      _buildSectionHeader('MANAGEMENT'),
      _buildSidebarItem(context, 'Apply For Leave', Icons.event_note_rounded, '/teacher-leaves', currentPath.contains('leave')),
      _buildSidebarItem(context, 'School Notices', Icons.campaign_rounded, '/notices', currentPath.startsWith('/notice')),
      _buildSidebarItem(context, 'My Profile', Icons.person_rounded, '/profile', currentPath.startsWith('/profile')),
    ];
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    String label,
    IconData icon,
    String route,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected ? AppColors.indigo : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          onTap: () {
            if (!isSelected) {
              context.go(route);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(
    BuildContext context,
    WidgetRef ref,
    UserModel? user,
    bool isTeacher,
    String currentPath,
  ) {
    return Drawer(
      backgroundColor: AppColors.navy,
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
                      color: AppColors.indigo,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'School OS',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          user?.schoolName ?? 'Command Center',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E293B)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: isTeacher
                    ? _buildTeacherMenuItems(context, currentPath)
                    : _buildAdminMenuItems(context, currentPath),
              ),
            ),
            const Divider(color: Color(0xFF1E293B)),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
              title: const Text('Sign Out', style: TextStyle(color: Colors.white, fontSize: 14)),
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
            _MobileNavItem('Staff', Icons.badge_rounded, '/teachers'),
            _MobileNavItem('Fees', Icons.account_balance_wallet_rounded, '/fees'),
            _MobileNavItem('More', Icons.menu_rounded, '/more'),
          ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.indigo.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: isSelected ? AppColors.indigo : AppColors.secondaryText,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected ? AppColors.indigo : AppColors.secondaryText,
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
