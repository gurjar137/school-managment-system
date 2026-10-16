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
  String _selectedCategory = 'All';
  String _selectedStatus = 'Published'; // 'Published', 'Draft', 'All'

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(schoolRepositoryProvider);
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == UserRole.schoolAdmin;
    final canPublish = isAdmin || user?.role == UserRole.teacher;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Campus Notices & Bulletins', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() => _refreshCounter++),
          ),
          if (canPublish)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Publish Notice',
              onPressed: () => _showNoticeDialog(context),
            ),
        ],
      ),
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: () => _showNoticeDialog(context),
              icon: const Icon(Icons.campaign_rounded),
              label: const Text('Post Announcement'),
              backgroundColor: AppColors.midnightNavy,
              foregroundColor: AppColors.pureWhite,
            )
          : null,
      body: Column(
        children: [
          // Filter Chips & Status Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...['All', 'General', 'Academic', 'Sports', 'Event', 'Exam'].map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        selectedColor: AppColors.primaryAccent.withValues(alpha: 0.18),
                        labelStyle: TextStyle(
                          color: isSel ? AppColors.primaryAccent : AppColors.coolGray,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(height: 24, width: 1, color: AppColors.border),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Drafts'),
                      selected: _selectedStatus == 'Draft',
                      selectedColor: AppColors.warmAmber.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        color: _selectedStatus == 'Draft' ? AppColors.warmAmber : AppColors.coolGray,
                        fontWeight: _selectedStatus == 'Draft' ? FontWeight.w700 : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedStatus = val ? 'Draft' : 'Published';
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: FutureBuilder<List<NoticeModel>>(
              key: ValueKey('$_refreshCounter-$_selectedStatus'),
              future: repo.getNotices(
                schoolId: user?.schoolId,
                userRole: user?.role,
              ),
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

                var list = snapshot.data ?? [];

                // Filter by category
                if (_selectedCategory != 'All') {
                  list = list.where((n) => n.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
                }

                // Filter by status for admin
                if (isAdmin) {
                  if (_selectedStatus == 'Draft') {
                    list = list.where((n) => n.status.toLowerCase() == 'draft').toList();
                  } else {
                    list = list.where((n) => n.status.toLowerCase() == 'published').toList();
                  }
                }

                if (list.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Bulletins',
                    message: _selectedCategory != 'All'
                        ? 'No announcements in $_selectedCategory category.'
                        : 'No official announcements posted yet.',
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
                      child: InkWell(
                        onTap: () => _showNoticeDetailDialog(context, n, isAdmin),
                        borderRadius: BorderRadius.circular(16),
                        child: BentoCard(
                          backgroundColor: n.isPinned ? AppColors.softLavender.withValues(alpha: 0.12) : null,
                          border: n.isPinned
                              ? Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.4), width: 1.5)
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (n.isPinned) ...[
                                    const Icon(Icons.push_pin_rounded, size: 16, color: AppColors.primaryAccent),
                                    const SizedBox(width: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.midnightNavy.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(n.category, style: AppTypography.labelSmall.copyWith(fontSize: 10)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.softLavender.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Target: ${n.targetAudience}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.primaryAccent,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  if (n.status == 'Draft') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.warmAmber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'DRAFT',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.warmAmber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(timeStr, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Builder(builder: (c) {
                                final isDark = Theme.of(c).brightness == Brightness.dark;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      n.content,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: isDark ? AppColors.coolGray : AppColors.primaryText.withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Issued by: ${n.author}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.coolGray,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Text(
                                    'Tap to view details',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primaryAccent,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showNoticeDetailDialog(BuildContext context, NoticeModel notice, bool isAdmin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            if (notice.isPinned) ...[
              const Icon(Icons.push_pin_rounded, color: AppColors.primaryAccent, size: 20),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(notice.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.midnightNavy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(notice.category, style: AppTypography.labelSmall),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.softLavender.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Audience: ${notice.targetAudience}', style: AppTypography.labelSmall),
                    ),
                    const Spacer(),
                    Text(DateFormat('MMM dd, yyyy').format(notice.date), style: AppTypography.bodySmall),
                  ],
                ),
                const SizedBox(height: 14),
                Text(notice.content, style: AppTypography.bodyMedium),
                if (notice.attachmentUrl != null && notice.attachmentUrl!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.attachment_rounded, size: 16, color: AppColors.primaryAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Attachment: ${notice.attachmentUrl}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.primaryAccent),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                Text(
                  'Issued by: ${notice.author}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (isAdmin) ...[
            if (notice.status.toLowerCase() == 'draft')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mutedGreen,
                  foregroundColor: AppColors.pureWhite,
                ),
                icon: const Icon(Icons.publish_rounded, size: 16),
                label: const Text('Publish Now'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final repo = ref.read(schoolRepositoryProvider);
                  final user = ref.read(authProvider);
                  await repo.updateNotice(
                    notice.copyWith(status: 'Published'),
                    schoolId: user?.schoolId,
                  );
                  ref.invalidate(unreadNotificationsCountProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() => _refreshCounter++);
                    messenger.showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.mutedGreen,
                        content: Text('Notice published! Notification delivered to target audience.'),
                      ),
                    );
                  }
                },
              ),
            TextButton.icon(
              icon: Icon(
                notice.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                size: 16,
                color: AppColors.primaryAccent,
              ),
              label: Text(
                notice.isPinned ? 'Unpin' : 'Pin to Top',
                style: const TextStyle(color: AppColors.primaryAccent),
              ),
              onPressed: () async {
                final repo = ref.read(schoolRepositoryProvider);
                final user = ref.read(authProvider);
                await repo.updateNotice(
                  notice.copyWith(isPinned: !notice.isPinned),
                  schoolId: user?.schoolId,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(() => _refreshCounter++);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(notice.isPinned ? 'Notice unpinned.' : 'Notice pinned to top.')),
                  );
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primaryAccent),
              label: const Text('Edit', style: TextStyle(color: AppColors.primaryAccent)),
              onPressed: () {
                Navigator.pop(ctx);
                _showNoticeDialog(context, existingNotice: notice);
              },
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete Notice?'),
                    content: const Text('Are you sure you want to remove this bulletin announcement and its notifications?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.softCoral,
                          foregroundColor: AppColors.pureWhite,
                        ),
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final repo = ref.read(schoolRepositoryProvider);
                  final user = ref.read(authProvider);
                  await repo.deleteNotice(notice.id, schoolId: user?.schoolId);
                  ref.invalidate(unreadNotificationsCountProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    setState(() => _refreshCounter++);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Notice deleted successfully.')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.softCoral)),
            ),
          ],
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showNoticeDialog(BuildContext context, {NoticeModel? existingNotice}) {
    final isEditing = existingNotice != null;
    final titleController = TextEditingController(text: existingNotice?.title ?? '');
    final contentController = TextEditingController(text: existingNotice?.content ?? '');
    final attachmentController = TextEditingController(text: existingNotice?.attachmentUrl ?? '');
    String category = existingNotice?.category ?? 'General';
    String targetAudience = existingNotice?.targetAudience ?? 'All Staff';
    String status = existingNotice?.status ?? 'Published';
    bool isPinned = existingNotice?.isPinned ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              isEditing ? 'Edit School Announcement' : 'Post School Announcement',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
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
                          hintText: 'e.g. Mid-Term Examination Datesheet',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: category,
                              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'General', child: Text('General')),
                                DropdownMenuItem(value: 'Academic', child: Text('Academic')),
                                DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                                DropdownMenuItem(value: 'Event', child: Text('Event')),
                                DropdownMenuItem(value: 'Exam', child: Text('Exam')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => category = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: targetAudience,
                              decoration: const InputDecoration(labelText: 'Target Audience', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'All Staff', child: Text('All Staff')),
                                DropdownMenuItem(value: 'Teachers Only', child: Text('Teachers Only')),
                                DropdownMenuItem(value: 'Parents', child: Text('Parents')),
                                DropdownMenuItem(value: 'Everyone', child: Text('Everyone')),
                              ],
                              onChanged: (val) {
                                if (val != null) setDialogState(() => targetAudience = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Publication Status', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'Published', child: Text('Publish Immediately')),
                          DropdownMenuItem(value: 'Draft', child: Text('Save as Draft')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => status = val);
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: contentController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notice Content *',
                          hintText: 'Type full details and instructions...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter content' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: attachmentController,
                        decoration: const InputDecoration(
                          labelText: 'Supporting Link / URL (Optional)',
                          hintText: 'https://...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pin this announcement to top'),
                        value: isPinned,
                        onChanged: (val) => setDialogState(() => isPinned = val ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.midnightNavy,
                  foregroundColor: AppColors.pureWhite,
                ),
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    final messenger = ScaffoldMessenger.of(context);
                    final repo = ref.read(schoolRepositoryProvider);
                    final user = ref.read(authProvider);

                    if (isEditing) {
                      final updatedNotice = existingNotice.copyWith(
                        title: titleController.text.trim(),
                        content: contentController.text.trim(),
                        category: category,
                        targetAudience: targetAudience,
                        status: status,
                        isPinned: isPinned,
                        attachmentUrl: attachmentController.text.trim().isNotEmpty ? attachmentController.text.trim() : null,
                      );

                      Navigator.of(ctx).pop();
                      await repo.updateNotice(updatedNotice, schoolId: user?.schoolId);
                      ref.invalidate(unreadNotificationsCountProvider);

                      if (mounted) {
                        setState(() => _refreshCounter++);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Notice updated successfully!'),
                            backgroundColor: AppColors.mutedGreen,
                          ),
                        );
                      }
                    } else {
                      final newNotice = NoticeModel(
                        id: '',
                        schoolId: user?.schoolId ?? '',
                        title: titleController.text.trim(),
                        content: contentController.text.trim(),
                        category: category,
                        targetAudience: targetAudience,
                        status: status,
                        date: DateTime.now(),
                        author: user?.name ?? 'Administration',
                        isPinned: isPinned,
                        isUnread: true,
                        attachmentUrl: attachmentController.text.trim().isNotEmpty ? attachmentController.text.trim() : null,
                      );

                      Navigator.of(ctx).pop();
                      await repo.addNotice(newNotice, schoolId: user?.schoolId);
                      ref.invalidate(unreadNotificationsCountProvider);

                      if (mounted) {
                        setState(() => _refreshCounter++);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(status == 'Published' ? 'Notice published successfully!' : 'Notice saved as draft.'),
                            backgroundColor: status == 'Published' ? AppColors.mutedGreen : AppColors.warmAmber,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(
                  isEditing
                      ? 'Save Changes'
                      : (status == 'Published' ? 'Publish Notice' : 'Save Draft'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
