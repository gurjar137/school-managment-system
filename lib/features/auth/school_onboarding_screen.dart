import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';

class SchoolOnboardingScreen extends ConsumerStatefulWidget {
  const SchoolOnboardingScreen({super.key});

  @override
  ConsumerState<SchoolOnboardingScreen> createState() => _SchoolOnboardingScreenState();
}

class _SchoolOnboardingScreenState extends ConsumerState<SchoolOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolNameCtrl = TextEditingController();
  final _schoolCodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _schoolCodeCtrl.dispose();
    _addressCtrl.dispose();
    _adminNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _submitOnboarding() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final newOwner = await authService.registerPrimarySchoolAdmin(
        schoolName: _schoolNameCtrl.text.trim(),
        schoolCode: _schoolCodeCtrl.text.trim().isNotEmpty ? _schoolCodeCtrl.text.trim() : null,
        address: _addressCtrl.text.trim(),
        adminName: _adminNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      ref.read(authProvider.notifier).setUserProfile(newOwner);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.mutedGreen,
            content: Text('School "${_schoolNameCtrl.text}" onboarded! Registered as Primary Admin.'),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.softCoral, content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: AppBackButton(
          fallbackPath: '/role-selection',
          onBeforeBack: () async {
            final isDirty = _schoolNameCtrl.text.isNotEmpty ||
                _adminNameCtrl.text.isNotEmpty ||
                _emailCtrl.text.isNotEmpty;
            if (isDirty) {
              return await showDiscardChangesDialog(context);
            }
            return true;
          },
        ),
        title: Text('Campus Setup & Primary Admin', style: AppTypography.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Register Primary School Admin 🏫',
                  style: AppTypography.displayMedium.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 6),
                Text(
                  'Establish an official school profile and claim the Primary Administrator (Owner) account for Supabase multi-tenant isolation.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
                ),
                const SizedBox(height: 28),

                Text('INSTITUTION DETAILS', style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _schoolNameCtrl,
                  decoration: const InputDecoration(labelText: 'Official School Name'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter school name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _schoolCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'School Code (Optional)',
                    hintText: 'e.g. KPS (if linking to an existing campus)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Campus Address'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter campus address' : null,
                ),
                const SizedBox(height: 24),

                Text('PRIMARY ADMINISTRATOR (OWNER)', style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _adminNameCtrl,
                  decoration: const InputDecoration(labelText: 'Primary Admin Full Name'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter admin full name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Official Admin Email'),
                  validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Master Account Password'),
                  validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm Password'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _passwordCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitOnboarding,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.pureWhite)
                        : const Text('Complete Onboarding & Claim School'),
                  ),
                ),
                const SizedBox(height: 16),

                Center(
                  child: TextButton.icon(
                    onPressed: () => context.go('/login/admin'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Already have an admin account? Sign In'),
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
