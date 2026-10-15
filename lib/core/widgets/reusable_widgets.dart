import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../data/models/student_model.dart';

// Bento Card Component
class BentoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Border? border;
  final VoidCallback? onTap;

  const BentoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AppColors.darkSurface : AppColors.cardBackground);
    final bd = border ?? Border.all(color: isDark ? AppColors.borderDark : AppColors.border, width: 1);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: bd,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return PressableScaleWidget(
        onTap: onTap!,
        child: content,
      );
    }
    return content;
  }
}

// Pressable Scale Feedback Widget
class PressableScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scaleFactor;

  const PressableScaleWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleFactor = 0.98,
  });

  @override
  State<PressableScaleWidget> createState() => _PressableScaleWidgetState();
}

class _PressableScaleWidgetState extends State<PressableScaleWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// User Avatar Widget
class AppAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double radius;
  final Color? borderColor;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 24,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderColor != null ? Border.all(color: borderColor!, width: 2) : null,
        color: AppColors.softLavender.withOpacity(0.2),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                initials,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.softLavender,
                  fontSize: radius * 0.7,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Attendance Status Chip Component
class AttendanceStatusChip extends StatelessWidget {
  final AttendanceStatus status;

  const AttendanceStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case AttendanceStatus.present:
        bg = AppColors.greenLight;
        fg = AppColors.greenDark;
        label = 'Present ✓';
        icon = Icons.check_circle_rounded;
        break;
      case AttendanceStatus.absent:
        bg = AppColors.coralLight;
        fg = AppColors.coralDark;
        label = 'Absent ×';
        icon = Icons.cancel_rounded;
        break;
      case AttendanceStatus.late:
        bg = AppColors.amberLight;
        fg = AppColors.amberDark;
        label = 'Late ⏱';
        icon = Icons.access_time_filled_rounded;
        break;
      case AttendanceStatus.notMarked:
        bg = AppColors.surfaceLight;
        fg = AppColors.coolGray;
        label = 'Not Marked';
        icon = Icons.help_outline_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// Circular Attendance Progress Bar Widget
class AttendanceProgressCircle extends StatelessWidget {
  final double percentage;
  final double size;
  final double strokeWidth;

  const AttendanceProgressCircle({
    super.key,
    required this.percentage,
    this.size = 100,
    this.strokeWidth = 10,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (percentage / 100).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color progressColor;
    if (percentage >= 90) {
      progressColor = AppColors.mutedGreen;
    } else if (percentage >= 75) {
      progressColor = AppColors.warmAmber;
    } else {
      progressColor = AppColors.softCoral;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Today',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.coolGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Section Header Widget
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionTitle;
  final VoidCallback? onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionTitle,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionTitle != null)
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionTitle!,
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.softLavender,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Custom Search Bar Widget
class CustomSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  const CustomSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.onFilterTap,
    this.controller,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.coolGray),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (onClear != null && (controller?.text.isNotEmpty == true))
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: AppColors.coolGray, size: 20),
              onPressed: onClear,
            ),
          if (onFilterTap != null) ...[
            Container(
              height: 24,
              width: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: AppColors.softLavender),
              onPressed: onFilterTap,
            ),
          ],
        ],
      ),
    );
  }
}

// Empty State Component
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.softLavender.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 44, color: AppColors.softLavender),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
            textAlign: TextAlign.center,
          ),
          if (buttonText != null && onAction != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              child: Text(buttonText!),
            ),
          ],
        ],
      ),
    ),
  );
}
}

// Loading State Component
class LoadingStateWidget extends StatelessWidget {
  final String message;

  const LoadingStateWidget({super.key, this.message = 'Loading data...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.softLavender,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
          ),
        ],
      ),
    );
  }
}
