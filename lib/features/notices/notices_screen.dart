import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/user_model.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  int _refreshCounter = 0;

  void _showPublishNoticeDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String category = 'General';
    bool isPinned = false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Publish New Notice', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Notice Title *',
                        hintText: 'e.g. Annual Sports Day 2026-27',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'General', child: Text('General')),
                        DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                        DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                        DropdownMenuItem(value: 'Event', child: Text('Event')),
                        DropdownMenuItem(value: 'Exam', child: Text('Exam')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Content *',
                        hintText: 'Enter full announcement details...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter content' : null,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pin to top of notice board'),
                      value: isPinned,
                      onChanged: (val) {
                        setDialogState(() => isPinned = val ?? false);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    final repo = ref.read(schoolRepositoryProvider);
                    final user = ref.read(authProvider);
                    final newNotice = NoticeModel(
                      id: 'notice_${DateTime.now().millisecondsSinceEpoch}',
                      title: titleController.text.trim(),
                      content: contentController.text.trim(),
                      category: category,
                      date: DateTime.now(),
                      author: user?.name ?? 'Administration',
                      isPinned: isPinned,
                      isUnread: true,
                    );
                    Navigator.of(ctx).pop();
                    await repo.addNotice(newNotice, schoolId: user?.schoolId);
                    if (mounted) {
                      setState(() => _refreshCounter++);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notice published successfully!'),
                          backgroundColor: AppColors.mutedGreen,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Publish'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(schoolRepositoryProvider);
    final user = ref.watch(authProvider);
    final canPublish = user?.role == UserRole.schoolAdmin || user?.role == UserRole.teacher;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Official Notices & Bulletins', style: AppTypography.titleLarge),
        actions: [
          if (canPublish)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Publish Notice',
              onPressed: () => _showPublishNoticeDialog(context),
            ),
        ],
      ),
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: () => _showPublishNoticeDialog(context),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Publish Notice'),
              backgroundColor: AppColors.midnightNavy,
              foregroundColor: AppColors.pureWhite,
            )
          : null,
      body: FutureBuilder<List<NoticeModel>>(
        key: ValueKey(_refreshCounter),
        future: repo.getNotices(schoolId: user?.schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Loading school bulletins...');
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading bulletins: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Bulletins',
              message: 'No official bulletins or notices published yet.',
              icon: Icons.campaign_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final n = list[index];
              final timeStr = DateFormat('MMM dd, yyyy').format(n.date);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BentoCard(
                  backgroundColor: n.isPinned ? AppColors.softLavender.withOpacity(0.08) : null,
                  border: n.isPinned ? Border.all(color: AppColors.softLavender, width: 1.5) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (n.isPinned) ...[
                            const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.softLavender),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.midnightNavy.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(n.category, style: AppTypography.labelSmall.copyWith(fontSize: 10)),
                          ),
                          const Spacer(),
                          Text(timeStr, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(n.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(n.content, style: AppTypography.bodyMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Issued by: ${n.author}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
