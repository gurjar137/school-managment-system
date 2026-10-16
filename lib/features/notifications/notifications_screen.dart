import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/academic_models.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final user = ref.read(authProvider);
      final repo = ref.read(schoolRepositoryProvider);
      final list = await repo.getNotifications(
        schoolId: user?.schoolId,
        userId: user?.id,
        role: user?.role,
      );
      if (mounted) {
        setState(() {
          _notifications.clear();
          _notifications.addAll(list);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'leaves':
      case 'leave':
        return Icons.event_note_rounded;
      case 'notices':
      case 'notice':
        return Icons.campaign_rounded;
      case 'meetings':
      case 'meeting':
        return Icons.video_call_rounded;
      case 'academic':
      case 'results':
      case 'exam':
        return Icons.school_rounded;
      case 'fees':
      case 'fee':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'leaves':
      case 'leave':
        return AppColors.warmAmber;
      case 'notices':
      case 'notice':
        return AppColors.primaryAccent;
      case 'meetings':
      case 'meeting':
        return AppColors.mutedGreen;
      case 'fees':
      case 'fee':
        return AppColors.softCoral;
      case 'academic':
      case 'results':
        return AppColors.indigo;
      default:
        return AppColors.secondaryText;
    }
  }

  Future<void> _handleNotificationTap(NotificationModel n) async {
    final user = ref.read(authProvider);
    final repo = ref.read(schoolRepositoryProvider);

    // Mark as read in repo & cache
    if (n.isUnread) {
      await repo.markNotificationRead(n.id, schoolId: user?.schoolId);
      ref.invalidate(unreadNotificationsCountProvider);
      setState(() {
        final idx = _notifications.indexWhere((item) => item.id == n.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isUnread: false);
        }
      });
    }

    // Navigate to related record if present
    if (!mounted) return;
    final type = n.relatedRecordType?.toLowerCase() ?? '';
    if (type == 'leave') {
      context.push('/teacher-leaves');
    } else if (type == 'notice') {
      context.push('/notices');
    } else if (type == 'meeting') {
      context.push('/meetings');
    } else if (type == 'academic' || type == 'results' || type == 'exam') {
      context.push('/results');
    } else if (type == 'fees' || type == 'fee') {
      context.push('/fees');
    }
  }

  @override
  Widget build(BuildContext context) {
    var list = _notifications;
    if (_selectedCategory != 'All') {
      list = list.where((n) => n.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    }

    final unreadCount = _notifications.where((n) => n.isUnread).length;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Campus Notification Center ($unreadCount)', style: AppTypography.titleLarge),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                final user = ref.read(authProvider);
                final repo = ref.read(schoolRepositoryProvider);
                await repo.markAllNotificationsRead(schoolId: user?.schoolId, userId: user?.id);
                ref.invalidate(unreadNotificationsCountProvider);
                setState(() {
                  for (int i = 0; i < _notifications.length; i++) {
                    _notifications[i] = _notifications[i].copyWith(isUnread: false);
                  }
                });
              },
              child: const Text('Mark All Read'),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => _loadNotifications(),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingStateWidget(message: 'Loading notifications...')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Leaves', 'Notices', 'Meetings', 'Academic', 'Fees'].map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: AppColors.primaryAccent.withValues(alpha: 0.18),
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.primaryAccent : AppColors.coolGray,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: list.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.notifications_off_outlined,
                          title: 'No Notifications',
                          message: _selectedCategory != 'All'
                              ? 'No notifications in the $_selectedCategory category.'
                              : 'You are all caught up! No notifications to display.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          itemBuilder: (context, idx) {
                            final n = list[idx];
                            final timeAgo = _formatTimeAgo(n.timestamp);
                            final icon = _getCategoryIcon(n.category);
                            final color = _getCategoryColor(n.category);
                            final hasActionRoute = n.relatedRecordType != null && n.relatedRecordType!.isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _handleNotificationTap(n),
                                borderRadius: BorderRadius.circular(16),
                                child: BentoCard(
                                  backgroundColor: n.isUnread
                                      ? AppColors.primaryAccent.withValues(alpha: 0.05)
                                      : null,
                                  border: n.isUnread
                                      ? Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.35), width: 1.2)
                                      : null,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(icon, color: color, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Builder(builder: (c) {
                                              final isDark = Theme.of(c).brightness == Brightness.dark;
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                n.title,
                                                                style: AppTypography.titleSmall.copyWith(
                                                                  fontWeight: n.isUnread ? FontWeight.w800 : FontWeight.w600,
                                                                  color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                                                                ),
                                                              ),
                                                            ),
                                                            if (n.isUnread) ...[
                                                              const SizedBox(width: 6),
                                                              Container(
                                                                width: 7,
                                                                height: 7,
                                                                decoration: const BoxDecoration(
                                                                  color: AppColors.primaryAccent,
                                                                  shape: BoxShape.circle,
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        timeAgo,
                                                        style: AppTypography.bodySmall.copyWith(
                                                          color: AppColors.coolGray,
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 5),
                                                  Text(
                                                    n.message,
                                                    style: AppTypography.bodySmall.copyWith(
                                                      color: n.isUnread
                                                          ? (isDark ? AppColors.pureWhite : AppColors.primaryText)
                                                          : (isDark ? AppColors.coolGray : AppColors.secondaryText),
                                                    ),
                                                  ),
                                                  if (hasActionRoute) ...[
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          'Tap to view details →',
                                                          style: AppTypography.labelSmall.copyWith(
                                                            color: AppColors.primaryAccent,
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              );
                                            }),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
