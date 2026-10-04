import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: '');
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

    final entered = _emailCtrl.text.trim();
    debugPrint('[AdminLoginScreen] Sign In initiated for email: $entered');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final profile = await authService.signInWithEmailAndPassword(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
        requiresAdminPortal: true,
      );

      debugPrint('[AdminLoginScreen] Sign In successful -> profile: ${profile.email}, role: ${profile.role}, school: ${profile.schoolId}');

      ref.read(authProvider.notifier).setUserProfile(profile);

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
      debugPrint('[AdminLoginScreen Error]: $e');
      if (mounted) {
        final raw = e.toString().replaceFirst('Exception: ', '').trim();
        String displayMsg = raw;
        final lower = raw.toLowerCase();

        if (lower.contains('failed to fetch') ||
            lower.contains('clientexception') ||
            lower.contains('networkerror') ||
            lower.contains('socketexception') ||
            lower.contains('connection') ||
            lower.contains('connect to the authentication server')) {
          displayMsg = 'Unable to connect to the authentication server. Check your internet connection.';
        } else if (lower.contains('not initialized') || lower.contains('not ready')) {
          displayMsg = 'Authentication service is not ready. Please restart the app.';
        } else if (lower.contains('invalid login credentials') ||
            lower.contains('invalid_credentials') ||
            lower == 'invalid email or password.') {
          displayMsg = 'Invalid email or password.';
        } else if (lower.contains('profile could not be loaded')) {
          displayMsg = 'Admin account authenticated, but the admin profile could not be loaded.';
        }

        setState(() {
          _errorMessage = displayMsg;
          _isLoading = false;
        });
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool isSending = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset, color: AppColors.midnightNavy),
              const SizedBox(width: 10),
              Text('Reset Password', style: AppTypography.titleLarge),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your administrator email address. We will send a secure link to reset your password.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
              ),
              const SizedBox(height: 16),
              if (dialogError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.softCoral.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.softCoral.withOpacity(0.3)),
                  ),
                  child: Text(
                    dialogError!,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: resetEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Administrator Email',
                  hintText: 'admin@school.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = resetEmailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        setDialogState(() {
                          dialogError = 'Please enter a valid email address.';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSending = true;
                        dialogError = null;
                      });

                      try {
                        final authService = ref.read(authServiceProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        await authService.sendPasswordResetEmail(email: email);
                        if (mounted && dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Password reset link sent to $email. Please check your inbox.'),
                              backgroundColor: AppColors.mutedGreen,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSending = false;
                          dialogError = e.toString().replaceFirst('Exception: ', '').trim();
                        });
                      }
                    },
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite),
                    )
                  : const Text('Send Reset Link'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Portal Login', style: AppTypography.titleLarge),
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
                  'School Admin Access 🔐',
                  style: AppTypography.displayMedium.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your administrator credentials to access school telemetry, student records, and settings.',
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
                  autofillHints: const [],
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    hintText: 'Enter your administrator email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => v == null || !v.contains('@') ? 'Enter a valid administrator email' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  autofillHints: const [],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.pureWhite)
                        : const Text('Sign In to Admin Portal'),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/onboarding/school-setup'),
                    icon: const Icon(Icons.domain_add_rounded, size: 18),
                    label: const Text('First Time Setup? Create School Admin Account'),
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
