import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';

class NoticesScreen extends ConsumerWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(schoolRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Official Notices & Bulletins', style: AppTypography.titleLarge),
      ),
      body: FutureBuilder(
        future: repo.getNotices(),
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
