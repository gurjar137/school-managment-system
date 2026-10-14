import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/auth_service.dart';

import '../../core/auth/recovery_session_state.dart';
import '../../core/widgets/app_back_button.dart';

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  final bool bypassSessionCheckForTesting;
  const UpdatePasswordScreen({super.key, this.bypassSessionCheckForTesting = false});

  @override
  ConsumerState<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _authService = AuthService();

  StreamSubscription<AuthState>? _authSub;
  Timer? _processingTimer;
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    RecoverySessionState.openedAfterProcessing = !RecoverySessionState.isProcessing;

    if (RecoverySessionState.isProcessing) {
      _processingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (!RecoverySessionState.isProcessing) {
          timer.cancel();
          setState(() {});
        }
      });
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
        _authSub = client.auth.onAuthStateChange.listen((data) {
          final event = data.event;
          if (event == AuthChangeEvent.passwordRecovery) {
            RecoverySessionState.recoveryEventReceived = true;
          }
          if (_hasActiveSession && mounted) {
            setState(() {});
          }
          RecoverySessionState.printSafeDiagnostics(contextTag: 'ResetPasswordScreen onAuthStateChange');
        });
      } catch (_) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      RecoverySessionState.printSafeDiagnostics(contextTag: 'ResetPasswordScreen PostFrame');
    });
  }

  @override
  void dispose() {
    _processingTimer?.cancel();
    _authSub?.cancel();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  bool get _hasActiveSession {
    if (widget.bypassSessionCheckForTesting) return true;
    if (!SupabaseConfig.isConfigured) return true;
    try {
      final client = Supabase.instance.client;
      return client.auth.currentSession != null || client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  void _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final newPass = _newPasswordCtrl.text.trim();
    final confirmPass = _confirmPasswordCtrl.text.trim();

    if (newPass != confirmPass) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. If recovery processing is still in flight, wait briefly
    if (RecoverySessionState.isProcessing) {
      for (int i = 0; i < 20; i++) {
        if (!RecoverySessionState.isProcessing) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // 2. Security validation: Ensure real Supabase session exists
    if (!_hasActiveSession) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Password reset link has expired. Please request a new one.';
      });
      return;
    }

    // 3. Update password via Supabase Auth
    try {
      await _authService.updatePassword(newPassword: newPass);

      if (mounted) {
        RecoverySessionState.printLiveRecoveryDebug(updateSuccess: true);
        setState(() {
          _isLoading = false;
          _successMessage = 'Password updated successfully! Redirecting to login...';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully. Please sign in with your new password.'),
            backgroundColor: AppColors.mutedGreen,
            duration: Duration(seconds: 3),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          context.go('/login/admin');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final msg = e.message.toLowerCase();
          _errorMessage = (msg.contains('expired') || msg.contains('session') || msg.contains('token'))
              ? 'Password reset link has expired. Please request a new one.'
              : 'Unable to update password. Please try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final msg = e.toString().toLowerCase();
          _errorMessage = (msg.contains('failed to fetch') || msg.contains('network') || msg.contains('connection'))
              ? 'Unable to connect. Please try again.'
              : 'Unable to update password. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // State 1: While recovery processing is in-flight
    if (RecoverySessionState.isProcessing) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Reset Password', style: AppTypography.titleLarge),
          leadingWidth: AppBackButton.leadingWidth,
          leading: const AppBackButton(fallbackPath: '/login/admin'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing password reset...'),
            ],
          ),
        ),
      );
    }

    // State 2: If a recovery exchange was attempted and failed, show invalid/expired error
    final bool genuineRecoveryFailed = RecoverySessionState.exchangeAttempted &&
        !RecoverySessionState.exchangeSuccess &&
        !_hasActiveSession;

    if (genuineRecoveryFailed) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Reset Password', style: AppTypography.titleLarge),
          leadingWidth: AppBackButton.leadingWidth,
          leading: const AppBackButton(fallbackPath: '/login/admin'),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Password 🔐',
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.midnightNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.softCoral.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.softCoral.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.softCoral, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This password reset link is invalid or has expired. Please request a new one.',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.softCoral),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login/admin'),
                        child: const Text('Return to Admin Login'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // State 3: Clean Reset Password Form
    return Scaffold(
      appBar: AppBar(
        title: Text('Reset Password', style: AppTypography.titleLarge),
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/login/admin'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Password 🔐',
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.midnightNavy,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your new administrator password below. Once updated, you will use this password to sign in.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.coolGray,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Success Banner (only upon successful password update)
                    if (_successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.mutedGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.mutedGreen.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: AppColors.mutedGreen, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: AppTypography.bodyMedium.copyWith(color: AppColors.mutedGreen),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Error Banner (only when submission fails)
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.softCoral.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.softCoral.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.softCoral, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTypography.bodyMedium.copyWith(color: AppColors.softCoral),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // New Password Field
                    TextFormField(
                      controller: _newPasswordCtrl,
                      obscureText: _obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        hintText: 'Enter new password (min 6 characters)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your new password';
                        }
                        if (val.trim().length < 6) {
                          return 'Password must be at least 6 characters long';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        hintText: 'Re-enter your new password',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (val.trim() != _newPasswordCtrl.text.trim()) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleUpdatePassword,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.pureWhite,
                                ),
                              )
                            : const Text('Update Password'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Back to Login Link
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Return to Admin Login'),
                        onPressed: () => context.go('/login/admin'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
