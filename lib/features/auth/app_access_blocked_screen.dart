import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    if (_currentResult == null || _currentResult!.isChecking) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleRetry());
    }
  }

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    ref.invalidate(appAccessStateProvider);
    ref.invalidate(currentSchoolProvider);

    try {
      final service = ref.read(tenantAccessServiceProvider);
      final result = await service.validateCurrentSession().timeout(
        const Duration(seconds: 8),
        onTimeout: () => AppAccessResult.blocked(
          status: AppAccessStatus.networkError,
          userMessage: 'Verification timed out. Please check your network connection and retry.',
          detailedReason: 'Timeout after 8 seconds while verifying session access.',
        ),
      );

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRetrying = false;
        _currentResult = AppAccessResult.blocked(
          status: AppAccessStatus.networkError,
          userMessage: 'Unable to verify school access at this time. Please retry.',
          detailedReason: e.toString(),
        );
      });
    }
  }

  Future<void> _handleSignOut() async {
    await ref.read(authProvider.notifier).logout();
    ref.invalidate(appAccessStateProvider);
    ref.invalidate(currentSchoolProvider);
    if (mounted) {
      context.go('/role-selection');
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

                      // Category Badge
                      if (result.categoryBadgeLabel.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _getCategoryBadgeBg(result.failureCategory),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getCategoryBadgeBorder(result.failureCategory)),
                          ),
                          child: Text(
                            result.categoryBadgeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: _getCategoryBadgeText(result.failureCategory),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Access Blocked Category Icon
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: _getIconBgColor(result.failureCategory),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getIconBorderColor(result.failureCategory),
                          ),
                        ),
                        child: Icon(
                          _getCategoryIcon(result.failureCategory),
                          size: 36,
                          color: _getIconColor(result.failureCategory),
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
                          color: _getBoxBgColor(result.failureCategory),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getBoxBorderColor(result.failureCategory)),
                        ),
                        child: Text(
                          result.displayMessage,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _getBoxTextColor(result.failureCategory),
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

                      // Technical / Diagnostic Details Box
                      if (result.detailedReason != null &&
                          result.detailedReason!.isNotEmpty &&
                          result.detailedReason != result.secondaryMessage) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.coolGrayDark),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  result.detailedReason!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Action Buttons: Prioritize Retry for Network, Sign Out for Auth/Access issues
                      if (result.failureCategory == AppAccessFailureCategory.networkOrConnectionFailure) ...[
                        // Primary: Retry Verification
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isRetrying ? null : _handleRetry,
                            icon: _isRetrying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            label: Text(
                              _isRetrying ? 'Retrying Connection...' : 'Retry Verification',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                        // Secondary: Sign Out
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: _isRetrying ? null : _handleSignOut,
                            icon: const Icon(Icons.logout_rounded, size: 18),
                            label: const Text('Sign Out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.midnightNavy,
                              side: const BorderSide(color: AppColors.borderLight),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Primary: Sign Out / Sign In Again
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isRetrying ? null : _handleSignOut,
                            icon: const Icon(Icons.logout_rounded, size: 20),
                            label: Text(
                              result.failureCategory == AppAccessFailureCategory.sessionExpired
                                  ? 'Sign In Again'
                                  : 'Sign Out',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                        // Secondary: Retry Verification
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

  IconData _getCategoryIcon(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.schoolNotFound:
        return Icons.domain_disabled_rounded;
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return Icons.person_off_rounded;
      case AppAccessFailureCategory.authorizationOrRlsDenied:
        return Icons.gpp_bad_rounded;
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return Icons.event_busy_rounded;
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return Icons.wifi_off_rounded;
      case AppAccessFailureCategory.sessionExpired:
        return Icons.lock_clock_rounded;
      case AppAccessFailureCategory.none:
        return Icons.block_rounded;
    }
  }

  Color _getIconBgColor(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.schoolNotFound:
        return const Color(0xFFFEF3C7);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFFEEF2FF);
      case AppAccessFailureCategory.authorizationOrRlsDenied:
        return AppColors.coralLight;
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return AppColors.amberLight;
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFFEFF6FF);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFFF1F5F9);
      case AppAccessFailureCategory.none:
        return AppColors.coralLight;
    }
  }

  Color _getIconBorderColor(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.schoolNotFound:
        return const Color(0xFFF59E0B).withValues(alpha: 0.4);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFF6366F1).withValues(alpha: 0.4);
      case AppAccessFailureCategory.authorizationOrRlsDenied:
        return AppColors.softCoral.withValues(alpha: 0.3);
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return AppColors.warmAmber.withValues(alpha: 0.3);
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFF3B82F6).withValues(alpha: 0.3);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFF64748B).withValues(alpha: 0.3);
      case AppAccessFailureCategory.none:
        return AppColors.softCoral.withValues(alpha: 0.3);
    }
  }

  Color _getIconColor(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.schoolNotFound:
        return const Color(0xFFD97706);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFF4F46E5);
      case AppAccessFailureCategory.authorizationOrRlsDenied:
        return AppColors.softCoral;
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return AppColors.warmAmber;
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFF2563EB);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFF475569);
      case AppAccessFailureCategory.none:
        return AppColors.softCoral;
    }
  }

  Color _getCategoryBadgeBg(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.schoolNotFound:
        return const Color(0xFFFEF3C7);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFFEEF2FF);
      case AppAccessFailureCategory.authorizationOrRlsDenied:
        return const Color(0xFFFEF2F2);
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return const Color(0xFFFFFBEB);
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFFEFF6FF);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFFF1F5F9);
      case AppAccessFailureCategory.none:
        return Colors.transparent;
    }
  }

  Color _getCategoryBadgeBorder(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.schoolNotFound:
        return const Color(0xFFFCD34D);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFFC7D2FE);
      case AppAccessFailureCategory.authorizationOrRlsDenied:
        return const Color(0xFFFECACA);
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return const Color(0xFFFDE68A);
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFFBFDBFE);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFFCBD5E1);
      case AppAccessFailureCategory.none:
        return Colors.transparent;
    }
  }

  Color _getCategoryBadgeText(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.schoolNotFound:
        return const Color(0xFF92400E);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFF3730A3);
      case AppAccessFailureCategory.authorizationOrRlsDenied:
        return const Color(0xFF991B1B);
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return const Color(0xFF92400E);
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFF1E40AF);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFF334155);
      case AppAccessFailureCategory.none:
        return Colors.black;
    }
  }

  Color _getBoxBgColor(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFFEFF6FF);
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return const Color(0xFFFFFBEB);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFFEEF2FF);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFFF8FAFC);
      case AppAccessFailureCategory.schoolNotFound:
      case AppAccessFailureCategory.authorizationOrRlsDenied:
      case AppAccessFailureCategory.none:
        return const Color(0xFFFEF2F2);
    }
  }

  Color _getBoxBorderColor(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFFBFDBFE);
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return const Color(0xFFFDE68A);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFFC7D2FE);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFFE2E8F0);
      case AppAccessFailureCategory.schoolNotFound:
      case AppAccessFailureCategory.authorizationOrRlsDenied:
      case AppAccessFailureCategory.none:
        return const Color(0xFFFECACA);
    }
  }

  Color _getBoxTextColor(AppAccessFailureCategory category) {
    switch (category) {
      case AppAccessFailureCategory.networkOrConnectionFailure:
        return const Color(0xFF1E40AF);
      case AppAccessFailureCategory.subscriptionOrEntitlementProblem:
        return const Color(0xFF92400E);
      case AppAccessFailureCategory.profileOrMembershipMissing:
        return const Color(0xFF3730A3);
      case AppAccessFailureCategory.sessionExpired:
        return const Color(0xFF334155);
      case AppAccessFailureCategory.schoolNotFound:
      case AppAccessFailureCategory.authorizationOrRlsDenied:
      case AppAccessFailureCategory.none:
        return const Color(0xFF991B1B);
    }
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
