import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/tenant_access_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    // Navigate after 2 seconds: check active Supabase session
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (mounted) {
        // If current route is /update-password (e.g. from deep link/recovery redirect), do not override
        try {
          final uriStr = GoRouterState.of(context).uri.toString();
          if (uriStr.contains('update-password')) {
            return;
          }
        } catch (_) {}

        if (SupabaseConfig.isConfigured) {
          try {
            final client = Supabase.instance.client;
            final user = client.auth.currentUser;
            if (client.auth.currentSession != null && user != null) {
              if (user.userMetadata?['must_change_password'] == true) {
                if (mounted) context.go('/change-password?firstLogin=true');
                return;
              }
              final accessService = TenantAccessService();
              final accessResult = await accessService.validateCurrentSession();
              if (!mounted) return;
              if (accessResult.isAllowed) {
                context.go('/home');
              } else if (accessResult.isSchoolDeactivated) {
                context.go('/access-deactivated', extra: accessResult);
              } else if (accessResult.isSubscriptionExpired) {
                context.go('/subscription-expired', extra: accessResult);
              } else {
                context.go('/access-blocked', extra: accessResult);
              }
              return;
            }
          } catch (e) {
            debugPrint('[SplashScreen Access Check Error]: $e');
          }
        }
        context.go('/role-selection');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.midnightNavy,
              AppColors.midnightNavyLight,
              AppColors.midnightNavyDark,
            ],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.softLavender,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.softLavender.withOpacity(0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.account_balance_rounded,
                      size: 48,
                      color: AppColors.pureWhite,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                Text(
                  'School Management OS',
                  style: AppTypography.displayMedium.copyWith(
                    color: AppColors.pureWhite,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Subtitle badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.pureWhite.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.pureWhite.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    'SCHOOL COMMAND CENTER',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.lavenderLight,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.softLavender),
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
