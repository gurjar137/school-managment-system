import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/academic_models.dart';

class LeaveRequestsScreen extends ConsumerStatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  ConsumerState<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends ConsumerState<LeaveRequestsScreen> {
  LeaveStatus _selectedTab = LeaveStatus.pending;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(schoolRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('Student Leave Applications', style: AppTypography.titleLarge),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/teacher-leaves'),
            icon: const Icon(Icons.badge_rounded, size: 18),
            label: const Text('Faculty Leaves'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Segment Tabs
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildTabPill('Pending', LeaveStatus.pending, AppColors.warmAmber),
                const SizedBox(width: 8),
                _buildTabPill('Approved', LeaveStatus.approved, AppColors.mutedGreen),
                const SizedBox(width: 8),
                _buildTabPill('Rejected', LeaveStatus.rejected, AppColors.softCoral),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: FutureBuilder(
              future: repo.getLeaveRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Fetching leave requests...');
                }
                final all = snapshot.data ?? [];
                final list = all.where((l) => l.status == _selectedTab).toList();

                if (list.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.event_available_rounded,
                    title: 'No ${_selectedTab.name.toUpperCase()} Requests',
                    message: 'There are no leave applications in this category.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final l = list[index];
                    final dates = '${DateFormat('MMM dd').format(l.startDate)} - ${DateFormat('MMM dd, yyyy').format(l.endDate)}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l.studentName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.midnightNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                                  child: Text(l.className, style: AppTypography.labelSmall),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Dates: $dates', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Reason: ${l.reason}', style: AppTypography.bodyMedium),
                            if (l.status == LeaveStatus.pending) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await repo.updateLeaveStatus(l.id, LeaveStatus.rejected);
                                        setState(() {});
                                      },
                                      child: const Text('Reject', style: TextStyle(color: AppColors.softCoral)),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await repo.updateLeaveStatus(l.id, LeaveStatus.approved);
                                        setState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGreen),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
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

  Widget _buildTabPill(String label, LeaveStatus status, Color color) {
    final isSelected = _selectedTab == status;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = status),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: isSelected ? AppColors.pureWhite : color,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
