import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/providers/app_providers.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String timeAgo;
  final String category;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.category,
    this.isRead = false,
  });
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final repo = ref.read(schoolRepositoryProvider);
      final list = await repo.getNotifications();
      if (mounted) {
        setState(() {
          _notifications.clear();
          for (final n in list) {
            final diff = DateTime.now().difference(n.timestamp);
            String timeStr;
            if (diff.inMinutes < 60) {
              timeStr = '${diff.inMinutes}m ago';
            } else if (diff.inHours < 24) {
              timeStr = '${diff.inHours}h ago';
            } else {
              timeStr = DateFormat('MMM dd').format(n.timestamp);
            }
            _notifications.add(NotificationItem(
              id: n.id,
              title: n.title,
              message: n.message,
              timeAgo: timeStr,
              category: n.category,
              isRead: !n.isUnread,
            ));
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var list = _notifications;
    if (_selectedCategory != 'All') {
      list = list.where((n) => n.category == _selectedCategory).toList();
    }

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Notification Center ($unreadCount)', style: AppTypography.titleLarge),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                setState(() {
                  for (var n in _notifications) {
                    n.isRead = true;
                  }
                });
              },
              child: const Text('Mark All Read'),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingStateWidget(message: 'Loading notifications...')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Results', 'Fees', 'School'].map((cat) {
                      final isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                if (list.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.notifications_off_outlined,
                    title: 'No Notifications',
                    message: 'No notifications in this category.',
                  )
                else
                  ...list.map((n) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            n.isRead = !n.isRead;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: BentoCard(
                          backgroundColor: n.isRead ? null : AppColors.softLavender.withOpacity(0.08),
                          border: n.isRead ? null : Border.all(color: AppColors.softLavender.withOpacity(0.4)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.softLavender.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  n.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                                  color: AppColors.softLavender,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(n.title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                        Text(n.timeAgo, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 9)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n.message, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
