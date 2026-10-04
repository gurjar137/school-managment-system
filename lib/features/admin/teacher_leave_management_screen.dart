import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/user_model.dart';
import '../../data/models/school_management_models.dart';

class TeacherLeaveManagementScreen extends ConsumerStatefulWidget {
  const TeacherLeaveManagementScreen({super.key});

  @override
  ConsumerState<TeacherLeaveManagementScreen> createState() => _TeacherLeaveManagementScreenState();
}

class _TeacherLeaveManagementScreenState extends ConsumerState<TeacherLeaveManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final service = ref.watch(schoolManagementServiceProvider);
    final user = ref.watch(authProvider);
    final isTeacher = user?.role == UserRole.teacher;

    return Scaffold(
      appBar: AppBar(
        title: Text(isTeacher ? 'Apply for Leave' : 'Teacher Leave Requests', style: AppTypography.titleLarge),
        actions: [
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.softLavender),
              onPressed: () => _showApplyLeaveModal(context),
            ),
        ],
      ),
      body: FutureBuilder<List<TeacherLeaveModel>>(
        future: service.getAllLeaveRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Loading leave applications...');
          }
          final leaves = snapshot.data ?? [];

          if (leaves.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.event_available_rounded,
              title: 'No Leave Applications',
              message: 'No pending or historical leave applications.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: leaves.length,
            itemBuilder: (context, idx) {
              final leave = leaves[idx];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(leave.teacherName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                              Text('${leave.leaveType} Leave • ${leave.fromDate.day}/${leave.fromDate.month} to ${leave.toDate.day}/${leave.toDate.month}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            ],
                          ),
                          _buildStatusBadge(leave.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Reason: ${leave.reason}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                      const SizedBox(height: 12),

                      if (!isTeacher && leave.status == 'pending') ...[
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGreen),
                                onPressed: () async {
                                  await service.approveLeave(leave.id, 'Approved by Admin');
                                  setState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Leave approved for ${leave.teacherName}!')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Approve'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await service.rejectLeave(leave.id, 'Rejected due to academic schedule');
                                  setState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Leave rejected for ${leave.teacherName}')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.softCoral),
                                label: const Text('Reject', style: TextStyle(color: AppColors.softCoral)),
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
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => _showApplyLeaveModal(context),
              backgroundColor: AppColors.midnightNavy,
              foregroundColor: AppColors.pureWhite,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Apply Leave'),
            )
          : null,
    );
  }

  void _showApplyLeaveModal(BuildContext context) {
    final reasonCtrl = TextEditingController();
    String selectedType = 'Casual';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Apply for Leave', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: const InputDecoration(labelText: 'Leave Type'),
                items: ['Casual', 'Sick', 'Earned'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => selectedType = v!,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Reason for Leave'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final user = ref.read(authProvider);
                final req = TeacherLeaveModel(
                  id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
                  teacherId: user?.id ?? 'tch_001',
                  teacherName: user?.name ?? 'Teacher',
                  leaveType: selectedType,
                  fromDate: DateTime.now().add(const Duration(days: 1)),
                  toDate: DateTime.now().add(const Duration(days: 2)),
                  reason: reasonCtrl.text,
                  status: 'pending',
                  appliedAt: DateTime.now(),
                );
                await ref.read(schoolManagementServiceProvider).applyTeacherLeave(req);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Leave application submitted for Admin approval!')),
                  );
                }
              },
              child: const Text('Submit Application'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'pending':
        bg = AppColors.warmAmber.withOpacity(0.15);
        fg = AppColors.warmAmber;
        break;
      case 'approved':
        bg = AppColors.mutedGreen.withOpacity(0.15);
        fg = AppColors.mutedGreen;
        break;
      default:
        bg = AppColors.softCoral.withOpacity(0.15);
        fg = AppColors.softCoral;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: AppTypography.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }
}
