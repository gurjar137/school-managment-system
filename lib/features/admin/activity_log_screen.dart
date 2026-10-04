import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/access_models.dart';

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessService = ref.watch(accessServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Audit & Activity Log', style: AppTypography.titleLarge),
      ),
      body: FutureBuilder<List<ActivityLogModel>>(
        future: accessService.getActivityLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Loading activity logs...');
          }
          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history_rounded,
              title: 'No Activity Logs',
              message: 'No administrative activity logs recorded yet.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, idx) {
              final log = logs[idx];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BentoCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.softLavender.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.security_rounded, color: AppColors.softLavender, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.actionTitle, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(log.details, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('By: ${log.adminName}', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600, fontSize: 9)),
                                Text(
                                  '${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} ${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, "0")}',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 9),
                                ),
                              ],
                            ),
                          ],
                        ),
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
