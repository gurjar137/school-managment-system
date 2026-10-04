import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(schoolRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Campus Library', style: AppTypography.titleLarge),
      ),
      body: FutureBuilder(
        future: repo.getLibraryBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Cataloging books...');
          }
          final list = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final b = list[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BentoCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.softLavender.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.menu_book_rounded, color: AppColors.softLavender, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                            Text('Author: ${b.author}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            if (b.issuedToStudent != null)
                              Text('Issued to: ${b.issuedToStudent}', style: AppTypography.bodySmall.copyWith(color: AppColors.amberDark, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: b.status.name == 'overdue' ? AppColors.coralLight : AppColors.greenLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          b.status.name.toUpperCase(),
                          style: AppTypography.labelSmall.copyWith(
                            color: b.status.name == 'overdue' ? AppColors.coralDark : AppColors.greenDark,
                          ),
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
