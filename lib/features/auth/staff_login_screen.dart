import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/user_model.dart';

class StaffLoginScreen extends ConsumerStatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  ConsumerState<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends ConsumerState<StaffLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final profile = await authService.signInWithEmailAndPassword(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        requiresAdminPortal: false,
      );

      ref.read(authProvider.notifier).setUserProfile(profile);

      if (profile.status == AccountStatus.inactive) {
        throw Exception('Your staff account has been deactivated. Please contact your school administrator.');
      }

      if (profile.mustChangePassword) {
        if (mounted) {
          context.go('/change-password?firstLogin=true');
        }
        return;
      }

      final accessService = ref.read(tenantAccessServiceProvider);
      final accessResult = await accessService.validateAccessForUser(authUserId: profile.authUserId);

      if (mounted) {
        if (accessResult.isAllowed) {
          ref.invalidate(appAccessStateProvider);
          ref.invalidate(currentSchoolProvider);
          context.go('/home');
        } else if (accessResult.isSchoolDeactivated) {
          context.go('/access-deactivated', extra: accessResult);
        } else if (accessResult.isSubscriptionExpired) {
          context.go('/subscription-expired', extra: accessResult);
        } else {
          context.go('/access-blocked', extra: accessResult);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Staff & Teacher Login', style: AppTypography.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Teacher & Staff Portal 👨‍🏫',
                  style: AppTypography.displayMedium.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your authorized staff email to access your assigned class roster, attendance board, and marks entry.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
                ),
                const SizedBox(height: 32),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softCoral.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.softCoral),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Authorized Staff Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v == null || !v.contains('@') ? 'Enter a valid staff email address' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mutedGreen,
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.pureWhite)
                        : const Text('Sign In to Staff Portal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
