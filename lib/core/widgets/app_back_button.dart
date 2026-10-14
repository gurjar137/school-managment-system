import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../providers/app_providers.dart';
import '../../data/models/user_model.dart';

/// Reusable confirmation dialog for forms with unsaved changes.
Future<bool> showDiscardChangesDialog(
  BuildContext context, {
  String title = 'Discard Unsaved Changes?',
  String message =
      'You have unsaved changes that will be lost if you leave this page. Are you sure you want to go back?',
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warmAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.warmAmber, size: 22),
          ),
          const SizedBox(width: 12),
          Text(title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
      content: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(
          color: isDark ? AppColors.coolGrayLight : AppColors.coolGrayDark,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Stay & Edit', style: AppTypography.labelLarge.copyWith(color: AppColors.coolGray)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.softCoral,
            foregroundColor: AppColors.pureWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A standard, consistent, accessible Back button for all inner school application screens.
///
/// Features:
/// - Left-arrow icon with "Back" label
/// - Matches application design theme, typography, and dark/light mode
/// - 48x40 comfortable touch target and keyboard accessibility (Tab, Enter, Space)
/// - Safe fallback: pops if route history exists; otherwise safely navigates to [fallbackPath]
///   or the user's role-authorized dashboard (/home), preventing blank screens and redirect loops.
/// - Unsaved form protection via [onBeforeBack] callback.
class AppBackButton extends ConsumerWidget {
  /// Default width to reserve when using this button in [AppBar.leading].
  static const double leadingWidth = 96.0;

  /// Optional specific fallback route when browser history is not available (e.g. '/students').
  final String? fallbackPath;

  /// Optional custom onBack override. If omitted, uses standard popping + fallback engine.
  final VoidCallback? onBack;

  /// Optional async hook executed before leaving. Return false to abort navigation.
  final Future<bool> Function()? onBeforeBack;

  /// Tooltip and accessibility label.
  final String tooltip;

  /// Custom icon/label color. Defaults to theme onSurface / midnightNavy.
  final Color? color;

  /// Whether to display the text label "Back" beside the arrow icon.
  final bool showLabel;

  /// Padding around the button content.
  final EdgeInsetsGeometry padding;

  const AppBackButton({
    super.key,
    this.fallbackPath,
    this.onBack,
    this.onBeforeBack,
    this.tooltip = 'Back to previous page',
    this.color,
    this.showLabel = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? (isDark ? AppColors.pureWhite : AppColors.midnightNavy);

    return Semantics(
      button: true,
      label: 'Back',
      tooltip: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => handleBack(context, ref),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
              child: Padding(
                padding: padding,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canFitLabel = showLabel && constraints.maxWidth >= 64;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: effectiveColor,
                        ),
                        if (canFitLabel) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Back',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelLarge.copyWith(
                                color: effectiveColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Executes back navigation with safety guards and role-aware fallbacks.
  Future<void> handleBack(BuildContext context, WidgetRef ref) async {
    if (onBeforeBack != null) {
      final canProceed = await onBeforeBack!();
      if (!canProceed || !context.mounted) return;
    }

    if (onBack != null) {
      onBack!();
      return;
    }

    // 1. Try popping Flutter's Navigator stack if valid history exists
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    // 2. Try popping GoRouter if available
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {}

    // 3. Fallback resolution: browser history is unavailable or previous page was external
    final user = ref.read(authProvider);
    final role = user?.role;
    final target = _resolveSafeFallback(context, role, fallbackPath);

    try {
      final currentLoc = GoRouterState.of(context).uri.path;
      if (currentLoc != target) {
        context.go(target);
      }
    } catch (_) {
      // If GoRouterState is inaccessible, attempt direct push/go
      context.go(target);
    }
  }

  /// Determines the authorized fallback destination based on the user's role.
  static String _resolveSafeFallback(BuildContext context, UserRole? role, String? preferred) {
    if (preferred != null && preferred.isNotEmpty) {
      // Verify user has permission to visit the preferred fallback
      if (role == null) {
        // Unauthenticated users belong on auth selection or login
        if (preferred.startsWith('/login') || preferred == '/role-selection') {
          return preferred;
        }
        return '/role-selection';
      }

      final isTeacher = role == UserRole.teacher;
      if (isTeacher) {
        // Teachers cannot access admin-only screens
        final adminOnlyPaths = [
          '/teachers',
          '/manage-admins',
          '/fees',
          '/admin-fees',
          '/salary',
          '/reports',
          '/school-settings',
          '/academic-years',
          '/teacher-access',
          '/parent-codes',
          '/activity-log',
          '/create-exam',
        ];
        final isForbidden = adminOnlyPaths.any((p) => preferred.startsWith(p));
        if (!isForbidden) {
          return preferred;
        }
      } else {
        // Administrators have access to all internal modules
        return preferred;
      }
    }

    // Default role dashboards
    if (role == null) {
      return '/role-selection';
    }
    return '/home';
  }
}
