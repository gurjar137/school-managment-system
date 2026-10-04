import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Brand Header
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.midnightNavy,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.midnightNavy.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.account_balance_rounded,
                        color: AppColors.softLavender,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School OS Portal',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        'School Management OS',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.coolGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Title Greeting
              Text(
                'Welcome Back 👋',
                style: AppTypography.displayMedium.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to continue to access your institution command panel.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
              ),
              const SizedBox(height: 32),

              // Option 1: ADMIN LOGIN
              _buildSelectionCard(
                context,
                title: 'Continue as Admin',
                subtitle: 'School Owner, Principal & Administrators',
                description: 'Full administrative access to Students, Faculty, Fees, Salary, Results, and Campus Settings.',
                icon: Icons.admin_panel_settings_rounded,
                accentColor: AppColors.softLavender,
                buttonText: 'Admin Portal Login',
                onTap: () => context.push('/login/admin'),
              ),
              const SizedBox(height: 20),

              // Option 2: STAFF / TEACHER LOGIN
              _buildSelectionCard(
                context,
                title: 'Continue as Staff',
                subtitle: 'Class Teachers & Academic Staff',
                description: 'Scoped access to assigned classes, 1-Tap Attendance Board, Marks Entry, and Homework.',
                icon: Icons.school_rounded,
                accentColor: AppColors.mutedGreen,
                buttonText: 'Staff Portal Login',
                onTap: () => context.push('/login/staff'),
              ),

              const SizedBox(height: 36),

              // ONBOARDING / SETUP TRIGGER
              Center(
                child: Column(
                  children: [
                    Text(
                      'Setting up a new campus?',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/onboarding/school-setup'),
                      icon: const Icon(Icons.add_business_rounded, size: 16, color: AppColors.softLavender),
                      label: const Text('Create New School & Owner Account', style: TextStyle(color: AppColors.softLavender)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.coolGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: accentColor, size: 18),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: AppColors.pureWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onTap,
                child: Text(buttonText, style: AppTypography.labelMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
