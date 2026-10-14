import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/academic_models.dart';

class HomeworkScreen extends ConsumerWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(schoolRepositoryProvider);
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('Homework Assignments', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded),
            onPressed: () => context.push('/homework-create'),
          ),
        ],
      ),
      body: FutureBuilder(
        future: repo.getHomework(schoolId: user?.schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Fetching homework records...');
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error loading homework: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const EmptyStateWidget(
              title: 'No Homework Assigned',
              message: 'No active homework assignments for your classes.',
              icon: Icons.assignment_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final hw = list[index];
              final dateStr = DateFormat('MMM dd, yyyy').format(hw.dueDate);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${hw.subject} • Class ${hw.className}${hw.section}',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender),
                            ),
                          ),
                          _buildStatusBadge(hw.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(hw.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(hw.description, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.event_outlined, size: 16, color: AppColors.coolGray),
                          const SizedBox(width: 4),
                          Text('Due Date: $dateStr', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                          const Spacer(),
                          if (hw.attachmentName != null) ...[
                            const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.softLavender),
                            const SizedBox(width: 4),
                            Text(hw.attachmentName!, style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600)),
                          ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/homework-create'),
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Assign Homework'),
      ),
    );
  }

  Widget _buildStatusBadge(HomeworkStatus status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case HomeworkStatus.active:
        bg = AppColors.greenLight;
        fg = AppColors.greenDark;
        text = 'Active';
        break;
      case HomeworkStatus.dueSoon:
        bg = AppColors.amberLight;
        fg = AppColors.amberDark;
        text = 'Due Soon';
        break;
      case HomeworkStatus.completed:
        bg = AppColors.surfaceLight;
        fg = AppColors.coolGray;
        text = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: AppTypography.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}
