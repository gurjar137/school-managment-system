import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/user_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _resolveRoleDisplay(UserModel? user) {
    if (user == null) return 'School Admin';
    if (user.role == UserRole.superAdmin || user.role == UserRole.schoolAdmin) {
      return 'School Admin';
    }
    return user.role.displayName;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
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
                  Text(
                    user?.name ?? 'School Administrator',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _resolveRoleDisplay(user),
                    style: AppTypography.labelMedium.copyWith(
                      color: AppColors.softLavender,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.schoolName ?? 'School Campus',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                  ),
                  if (user?.email != null && user!.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Actions
            BentoCard(
              child: Column(
                children: [
                  _buildProfileOption(
                    Icons.edit_outlined,
                    'Edit Profile Details',
                    () => _showEditProfileDialog(context, ref, user),
                    textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                  const Divider(height: 1),
                  _buildProfileOption(
                    Icons.dark_mode_outlined,
                    'Dark Mode Theme',
                    () => ref.read(themeProvider.notifier).toggleTheme(),
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      activeColor: AppColors.softLavender,
                      onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(),
                    ),
                    textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                  const Divider(height: 1),
                  _buildProfileOption(
                    Icons.lock_outline_rounded,
                    'Security & Passcode',
                    () => _showSecurityDialog(context, ref, user),
                    textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                  const Divider(height: 1),
                  _buildProfileOption(
                    Icons.settings_outlined,
                    'System Preferences',
                    () => context.push('/settings'),
                    textColor: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                  const Divider(height: 1),
                  _buildProfileOption(
                    Icons.swap_horiz_rounded,
                    'Switch Role / Mode',
                    () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/role-selection');
                      }
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

  // --- 1. EDIT PROFILE DETAILS DIALOG ---
  void _showEditProfileDialog(BuildContext context, WidgetRef ref, UserModel? user) {
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.name);
    final designationCtrl = TextEditingController(text: user.designation);
    final avatarCtrl = TextEditingController(text: user.avatarUrl);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.edit_outlined, color: AppColors.indigo),
                  const SizedBox(width: 10),
                  Text(
                    'Edit Profile Details',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Email (Read-only)
                        Text(
                          'EMAIL ADDRESS',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.softLavender : AppColors.indigo,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.mainBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 18, color: AppColors.coolGray),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  user.email,
                                  style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Display Name (Editable)
                        Text(
                          'FULL NAME *',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.softLavender : AppColors.indigo,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Your Full Name',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Full Name is required.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Designation
                        Text(
                          'DESIGNATION',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.softLavender : AppColors.indigo,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: designationCtrl,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Principal & Director',
                            prefixIcon: Icon(Icons.badge_outlined, size: 18),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Avatar URL
                        Text(
                          'AVATAR IMAGE URL',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.softLavender : AppColors.indigo,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: avatarCtrl,
                          decoration: const InputDecoration(
                            hintText: 'https://...',
                            prefixIcon: Icon(Icons.image_outlined, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);
                          try {
                            final authService = ref.read(authServiceProvider);
                            await authService.updateUserProfile(
                              userId: user.id,
                              name: nameCtrl.text.trim(),
                              designation: designationCtrl.text.trim(),
                              avatarUrl: avatarCtrl.text.trim(),
                            );

                            await ref.read(authProvider.notifier).updateProfile(
                              name: nameCtrl.text.trim(),
                              designation: designationCtrl.text.trim(),
                              avatarUrl: avatarCtrl.text.trim(),
                            );

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.mutedGreen,
                                  content: Text('Profile details updated successfully!'),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.softCoral,
                                  content: Text('Failed to update profile: $e'),
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 2. SECURITY & PASSCODE DIALOG ---
  void _showSecurityDialog(BuildContext context, WidgetRef ref, UserModel? user) {
    if (user == null) return;

    final formKey = GlobalKey<FormState>();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final pinCtrl = TextEditingController();

    bool isPasscodeEnabled = false;
    bool isSaving = false;
    String? securityError;

    // Load initial passcode state
    SharedPreferences.getInstance().then((sp) {
      isPasscodeEnabled = sp.getBool('app_pin_enabled_${user.id}') ?? false;
      pinCtrl.text = sp.getString('app_pin_code_${user.id}') ?? '';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: AppColors.indigo),
                  const SizedBox(width: 10),
                  Text(
                    'Security & Passcode',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (securityError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.softCoral.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.softCoral, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.softCoral),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    securityError!,
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Section 1: Change Password
                        Text(
                          'CHANGE ACCOUNT PASSWORD',
                          style: AppTypography.labelSmall.copyWith(
                            color: isDark ? AppColors.softLavender : AppColors.indigo,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: newPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'New Password (min. 8 characters)',
                            prefixIcon: Icon(Icons.key_outlined, size: 18),
                          ),
                          validator: (v) {
                            if (v != null && v.isNotEmpty && v.length < 8) {
                              return 'Password must be at least 8 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Confirm New Password',
                            prefixIcon: Icon(Icons.check_circle_outline_rounded, size: 18),
                          ),
                          validator: (v) {
                            if (newPassCtrl.text.isNotEmpty && v != newPassCtrl.text) {
                              return 'Passwords do not match.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Section 2: App Passcode Lock
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'App Passcode Lock',
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                                  ),
                                ),
                                Text(
                                  'Require 4-digit PIN on app launch',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                ),
                              ],
                            ),
                            Switch(
                              value: isPasscodeEnabled,
                              activeColor: AppColors.mutedGreen,
                              onChanged: (val) {
                                setDialogState(() => isPasscodeEnabled = val);
                              },
                            ),
                          ],
                        ),
                        if (isPasscodeEnabled) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              hintText: 'Enter 4-digit PIN',
                              prefixIcon: Icon(Icons.dialpad_rounded, size: 18),
                              counterText: '',
                            ),
                            validator: (v) {
                              if (isPasscodeEnabled && (v == null || v.length != 4)) {
                                return 'PIN must be exactly 4 digits.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() {
                            isSaving = true;
                            securityError = null;
                          });

                          try {
                            // 1. Password change if provided
                            if (newPassCtrl.text.isNotEmpty) {
                              final authService = ref.read(authServiceProvider);
                              await authService.changePassword(newPassword: newPassCtrl.text.trim());
                            }

                            // 2. Passcode update
                            final sp = await SharedPreferences.getInstance();
                            await sp.setBool('app_pin_enabled_${user.id}', isPasscodeEnabled);
                            if (isPasscodeEnabled) {
                              await sp.setString('app_pin_code_${user.id}', pinCtrl.text.trim());
                            } else {
                              await sp.remove('app_pin_code_${user.id}');
                            }

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.mutedGreen,
                                  content: Text('Security settings updated successfully!'),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              securityError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
