import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('App & School Settings', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(title: 'ACADEMIC CONFIGURATION'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                _buildSettingTile('School Identity & Branding', 'St. Xavier Modern Academy', Icons.school_outlined),
                const Divider(height: 1),
                _buildSettingTile(
                  'Academic Years',
                  'Manage sessions, terms, and date windows',
                  Icons.calendar_month_outlined,
                  onTap: () => context.push('/academic-years'),
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  'Timetable',
                  'Weekly schedule, room & teacher assignments',
                  Icons.calendar_today_outlined,
                  onTap: () => context.push('/timetable'),
                ),
                const Divider(height: 1),
                _buildSettingTile('Class & Section Matrix', '8 Classes, 12 Sections Active', Icons.grid_view_rounded),
                const Divider(height: 1),
                _buildSettingTile('Subject Catalog', '16 Core & Elective Subjects', Icons.book_outlined),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'TELEMETRY & SYNC'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                _buildSettingTile('Attendance Cutoff Time', '09:30 AM Daily Warning', Icons.timer_outlined),
                const Divider(height: 1),
                _buildSettingTile('Offline Queue Auto-Sync', 'Sync when WiFi connects', Icons.sync_rounded),
                const Divider(height: 1),
                _buildSettingTile('Push Notifications', 'Parents & Staff alerts enabled', Icons.notifications_active_outlined),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'SECURITY & ACCOUNT'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                _buildSettingTile(
                  'Change Password',
                  'Update your account password securely',
                  Icons.lock_outline_rounded,
                  onTap: () => context.push('/change-password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'APPEARANCE & SYSTEM'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: AppColors.softLavender),
                  title: Text('Dark Mode Theme', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Switch between Light and Dark Command Center UI', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  trailing: Switch(
                    value: themeMode == ThemeMode.dark,
                    activeThumbColor: AppColors.softLavender,
                    onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.midnightNavy),
      title: Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.coolGray),
      onTap: onTap,
    );
  }
}
