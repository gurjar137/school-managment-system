import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/school_app_access_state.dart';

class AppAccessBlockedScreen extends ConsumerStatefulWidget {
  final AppAccessResult? initialAccessResult;

  const AppAccessBlockedScreen({
    super.key,
    this.initialAccessResult,
  });

  @override
  ConsumerState<AppAccessBlockedScreen> createState() => _AppAccessBlockedScreenState();
}

class _AppAccessBlockedScreenState extends ConsumerState<AppAccessBlockedScreen> {
  bool _isRetrying = false;
  AppAccessResult? _currentResult;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.initialAccessResult;
  }

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    final service = ref.read(tenantAccessServiceProvider);
    final result = await service.validateCurrentSession();

    if (!mounted) return;
    setState(() {
      _isRetrying = false;
      _currentResult = result;
    });

    if (result.isAllowed) {
      ref.invalidate(appAccessStateProvider);
      ref.invalidate(currentSchoolProvider);
      context.go('/home');
    }
  }

  Future<void> _handleSignOut() async {
    try {
      final client = Supabase.instance.client;
      await client.auth.signOut();
    } catch (_) {}
    ref.invalidate(appAccessStateProvider);
    ref.invalidate(authProvider);
    if (mounted) {
      context.go('/login/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _currentResult ??
        ref.watch(appAccessStateProvider).asData?.value ??
        const AppAccessResult(
          isAllowed: false,
          status: AppAccessStatus.checking,
          userMessage: 'Verifying application access and subscription standing...',
        );

    final school = result.resolvedSchool;

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // School Header / Branding (if resolved)
                      if (school != null) ...[
                        if (school.logoUrl != null && school.logoUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              school.logoUrl!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildSchoolAvatar(school.name),
                            ),
                          )
                        else
                          _buildSchoolAvatar(school.name),
                        const SizedBox(height: 12),
                        Text(
                          school.name,
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.midnightNavy,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                      ],

                      // Access Blocked Icon
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: result.isSubscriptionExpired
                              ? AppColors.amberLight
                              : AppColors.coralLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (result.isSubscriptionExpired
                                    ? AppColors.warmAmber
                                    : AppColors.softCoral)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          result.isSubscriptionExpired
                              ? Icons.event_busy_rounded
                              : Icons.block_rounded,
                          size: 34,
                          color: result.isSubscriptionExpired
                              ? AppColors.warmAmber
                              : AppColors.softCoral,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Dedicated Title
                      Text(
                        result.displayTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.midnightNavy,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Primary User-Facing Message Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: result.isSubscriptionExpired
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: result.isSubscriptionExpired
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFFECACA),
                          ),
                        ),
                        child: Text(
                          result.displayMessage,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: result.isSubscriptionExpired
                                ? const Color(0xFF92400E)
                                : const Color(0xFF991B1B),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary Explanatory Text
                      Text(
                        result.secondaryMessage,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.coolGrayDark,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Action Buttons: Sign Out (Prominent) & Retry
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _handleSignOut,
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: const Text(
                            'Sign Out',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.midnightNavy,
                            foregroundColor: AppColors.pureWhite,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _isRetrying ? null : _handleRetry,
                          icon: _isRetrying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.midnightNavy),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(_isRetrying ? 'Checking Access...' : 'Retry Verification'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.midnightNavy,
                            side: const BorderSide(color: AppColors.borderLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSchoolAvatar(String name) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.lavenderLight,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.midnightNavy,
        ),
      ),
    );
  }
}
