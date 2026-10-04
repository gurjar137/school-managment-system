import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Account & Profile', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // User Banner Card
            BentoCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  AppAvatar(
                    imageUrl: user?.avatarUrl ?? '',
                    name: user?.name ?? 'Admin',
                    radius: 40,
                    borderColor: AppColors.softLavender,
                  ),
                  const SizedBox(height: 14),
                  Text(user?.name ?? 'School Administrator', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(user?.roleDisplayName ?? 'School Admin', style: AppTypography.labelMedium.copyWith(color: AppColors.softLavender)),
                  const SizedBox(height: 4),
                  Text(user?.schoolName ?? 'School Campus', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Actions
            BentoCard(
              child: Column(
                children: [
                  _buildProfileOption(Icons.edit_outlined, 'Edit Profile Details', () {}),
                  const Divider(height: 1),
                  _buildProfileOption(
                    Icons.dark_mode_outlined,
                    'Dark Mode Theme',
                    () => ref.read(themeProvider.notifier).toggleTheme(),
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      activeThumbColor: AppColors.softLavender,
                      onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(),
                    ),
                  ),
                  const Divider(height: 1),
                  _buildProfileOption(Icons.lock_outline_rounded, 'Security & Passcode', () {}),
                  const Divider(height: 1),
                  _buildProfileOption(Icons.settings_outlined, 'System Preferences', () => context.push('/settings')),
                  const Divider(height: 1),
                  _buildProfileOption(
                    Icons.swap_horiz_rounded,
                    'Switch Role / Mode',
                    () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/role-selection');
                    },
                    textColor: AppColors.softLavender,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Widget? trailing,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.midnightNavy, size: 22),
      title: Text(label, style: AppTypography.titleSmall.copyWith(color: textColor, fontWeight: FontWeight.w600)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.coolGray),
      onTap: onTap,
    );
  }
}
