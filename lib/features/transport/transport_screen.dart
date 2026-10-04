import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';

class TransportScreen extends ConsumerWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(schoolRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Transport & Fleet Routes', style: AppTypography.titleLarge),
      ),
      body: FutureBuilder(
        future: repo.getTransportRoutes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Tracking bus fleet...');
          }
          final list = snapshot.data ?? [];

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r.routeName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(8)),
                            child: Text(r.busNumber, style: AppTypography.labelSmall.copyWith(color: AppColors.amberDark)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Driver: ${r.driverName} (${r.driverPhone})', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      Text('Commuters: ${r.studentCount} Students Onboard', style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Text('STOPS LINE:', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray, fontSize: 9)),
                      const SizedBox(height: 4),
                      Text(r.stops.join(' ➔ '), style: AppTypography.bodySmall),
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
