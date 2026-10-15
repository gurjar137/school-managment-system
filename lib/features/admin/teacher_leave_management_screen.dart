import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/user_model.dart';
import '../../data/models/school_management_models.dart';

class TeacherLeaveManagementScreen extends ConsumerStatefulWidget {
  const TeacherLeaveManagementScreen({super.key});

  @override
  ConsumerState<TeacherLeaveManagementScreen> createState() => _TeacherLeaveManagementScreenState();
}

class _TeacherLeaveManagementScreenState extends ConsumerState<TeacherLeaveManagementScreen> {
  String _selectedFilter = 'all'; // all, pending, approved, rejected
  int _refreshCounter = 0;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(schoolManagementServiceProvider);
    final user = ref.watch(authProvider);
    final isTeacher = user?.role == UserRole.teacher;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/teachers'),
        title: Text(
          isTeacher ? 'My Leave Applications' : 'Faculty Leave Management',
          style: AppTypography.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() => _refreshCounter++),
          ),
          if (isTeacher)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryAccent),
              tooltip: 'Apply for Leave',
              onPressed: () => _showApplyLeaveModal(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip('All Requests', 'all'),
                  const SizedBox(width: 8),
                  _buildTabChip('Pending Approval', 'pending', badgeColor: AppColors.warmAmber),
                  const SizedBox(width: 8),
                  _buildTabChip('Approved', 'approved', badgeColor: AppColors.mutedGreen),
                  const SizedBox(width: 8),
                  _buildTabChip('Rejected', 'rejected', badgeColor: AppColors.softCoral),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: FutureBuilder<List<TeacherLeaveModel>>(
              key: ValueKey(_refreshCounter),
              future: service.getAllLeaveRequests(schoolId: user?.schoolId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading leave applications...');
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }

                var leaves = snapshot.data ?? [];

                // If teacher, show only their requests
                if (isTeacher && user != null) {
                  leaves = leaves.where((l) => l.teacherId == user.id || l.teacherName == user.name).toList();
                }

                // Apply status filter
                if (_selectedFilter != 'all') {
                  leaves = leaves.where((l) => l.status.toLowerCase() == _selectedFilter).toList();
                }

                if (leaves.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.event_available_rounded,
                    title: 'No Leave Applications',
                    message: _selectedFilter == 'all'
                        ? (isTeacher
                            ? 'You have not submitted any leave requests yet.'
                            : 'No faculty leave applications found for this school.')
                        : 'No ${_selectedFilter.toUpperCase()} leave applications.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: leaves.length,
                  itemBuilder: (context, idx) {
                    final leave = leaves[idx];
                    final durationDays = leave.toDate.difference(leave.fromDate).inDays + 1;
                    final dateRangeStr =
                        '${DateFormat('MMM dd, yyyy').format(leave.fromDate)} - ${DateFormat('MMM dd, yyyy').format(leave.toDate)} ($durationDays ${durationDays == 1 ? 'day' : 'days'})';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: BentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        leave.teacherName,
                                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Applied on ${DateFormat('MMM dd, yyyy • hh:mm a').format(leave.appliedAt)}',
                                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.softLavender.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${leave.leaveType} Leave',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.softLavender,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(leave.status),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Dates Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkSurface
                                    : AppColors.warmOffWhite,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range_rounded, size: 16, color: AppColors.primaryAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    dateRangeStr,
                                    style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Reason
                            Text('Reason:', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                            const SizedBox(height: 2),
                            Text(
                              leave.reason.isNotEmpty ? leave.reason : 'No reason specified',
                              style: AppTypography.bodyMedium,
                            ),

                            // Attachment if any
                            if (leave.attachmentUrl != null && leave.attachmentUrl!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.attachment_rounded, size: 14, color: AppColors.coolGray),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Attachment: ${leave.attachmentUrl}',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.primaryAccent),
                                  ),
                                ],
                              ),
                            ],

                            // Review Info
                            if (leave.reviewedBy != null || leave.adminRemarks.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (leave.status == 'approved' ? AppColors.mutedGreen : AppColors.softCoral)
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: (leave.status == 'approved' ? AppColors.mutedGreen : AppColors.softCoral)
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (leave.reviewedBy != null)
                                      Text(
                                        'Decision by: ${leave.reviewedBy}${leave.reviewedAt != null ? ' on ${DateFormat('MMM dd, yyyy').format(leave.reviewedAt!)}' : ''}',
                                        style: AppTypography.labelSmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: leave.status == 'approved' ? AppColors.mutedGreen : AppColors.softCoral,
                                        ),
                                      ),
                                    if (leave.adminRemarks.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Admin Remarks: ${leave.adminRemarks}',
                                        style: AppTypography.bodySmall,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Actions
                            if (!isTeacher && leave.status.toLowerCase() == 'pending') ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.mutedGreen,
                                        foregroundColor: AppColors.pureWhite,
                                      ),
                                      onPressed: () => _confirmApprovalDialog(context, leave),
                                      icon: const Icon(Icons.check_rounded, size: 16),
                                      label: const Text('Approve'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.softCoral),
                                      ),
                                      onPressed: () => _confirmRejectionDialog(context, leave),
                                      icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.softCoral),
                                      label: const Text('Reject', style: TextStyle(color: AppColors.softCoral)),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isTeacher && leave.status.toLowerCase() == 'pending') ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.softCoral),
                                  ),
                                  onPressed: () => _confirmCancelDialog(context, leave),
                                  icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.softCoral),
                                  label: const Text('Cancel Request', style: TextStyle(color: AppColors.softCoral)),
                                ),
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

  Widget _buildTabChip(String label, String value, {Color? badgeColor}) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryAccent.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryAccent : AppColors.coolGray,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Future<void> _confirmApprovalDialog(BuildContext context, TeacherLeaveModel leave) async {
    final remarkCtrl = TextEditingController(text: 'Approved by Administration');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Leave Application', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approve leave for ${leave.teacherName} (${leave.leaveType} Leave)?', style: AppTypography.bodyMedium),
            const SizedBox(height: 14),
            TextFormField(
              controller: remarkCtrl,
              decoration: const InputDecoration(
                labelText: 'Approval Remarks (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = ref.read(authProvider);
      final service = ref.read(schoolManagementServiceProvider);
      await service.approveLeave(
        leave.id,
        remarkCtrl.text.trim(),
        adminName: user?.name ?? 'School Admin',
        repo: ref.read(schoolRepositoryProvider),
      );
      ref.invalidate(pendingLeavesCountProvider);
      setState(() => _refreshCounter++);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.mutedGreen,
            content: Text('Leave approved for ${leave.teacherName}!'),
          ),
        );
      }
    }
  }

  Future<void> _confirmRejectionDialog(BuildContext context, TeacherLeaveModel leave) async {
    final remarkCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Leave Application', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Please provide a reason for rejecting leave for ${leave.teacherName}:', style: AppTypography.bodyMedium),
              const SizedBox(height: 14),
              TextFormField(
                controller: remarkCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'e.g. Clashes with examination duty',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter rejection reason' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = ref.read(authProvider);
      final service = ref.read(schoolManagementServiceProvider);
      await service.rejectLeave(
        leave.id,
        remarkCtrl.text.trim(),
        adminName: user?.name ?? 'School Admin',
        repo: ref.read(schoolRepositoryProvider),
      );
      ref.invalidate(pendingLeavesCountProvider);
      setState(() => _refreshCounter++);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.softCoral,
            content: Text('Leave rejected for ${leave.teacherName}'),
          ),
        );
      }
    }
  }

  Future<void> _confirmCancelDialog(BuildContext context, TeacherLeaveModel leave) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Leave Request?'),
        content: const Text('Are you sure you want to withdraw this leave request? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw Request'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final user = ref.read(authProvider);
      final service = ref.read(schoolManagementServiceProvider);
      await service.cancelLeave(
        leave.id,
        user?.id ?? leave.teacherId,
        repo: ref.read(schoolRepositoryProvider),
      );
      ref.invalidate(pendingLeavesCountProvider);
      setState(() => _refreshCounter++);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave application withdrawn.')),
        );
      }
    }
  }

  void _showApplyLeaveModal(BuildContext context) {
    final reasonCtrl = TextEditingController();
    final attachmentCtrl = TextEditingController();
    String selectedType = 'Casual';
    DateTime fromDate = DateTime.now().add(const Duration(days: 1));
    DateTime toDate = DateTime.now().add(const Duration(days: 2));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final durationDays = toDate.difference(fromDate).inDays + 1;

            return AlertDialog(
              title: Text('Apply for Leave', style: AppTypography.titleLarge),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selectedType,
                          decoration: const InputDecoration(labelText: 'Leave Type *', border: OutlineInputBorder()),
                          items: ['Casual', 'Sick', 'Earned', 'Maternity/Paternity', 'Bereavement', 'Unpaid']
                              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) => setDialogState(() => selectedType = v!),
                        ),
                        const SizedBox(height: 14),

                        // Date Pickers Row
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: fromDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setDialogState(() {
                                      fromDate = picked;
                                      if (toDate.isBefore(fromDate)) {
                                        toDate = fromDate;
                                      }
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'From Date *',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                  ),
                                  child: Text(DateFormat('MMM dd, yyyy').format(fromDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: toDate.isBefore(fromDate) ? fromDate : toDate,
                                    firstDate: fromDate,
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => toDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'To Date *',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                  ),
                                  child: Text(DateFormat('MMM dd, yyyy').format(toDate)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Total Duration: $durationDays ${durationDays == 1 ? 'day' : 'days'}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.primaryAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: reasonCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason for Leave *',
                            hintText: 'Describe why you are taking leave...',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a reason' : null,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: attachmentCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Supporting Document / Link (Optional)',
                            hintText: 'https://...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final user = ref.read(authProvider);
                      final service = ref.read(schoolManagementServiceProvider);

                      // Overlap validation check
                      final existingLeaves = await service.getAllLeaveRequests(schoolId: user?.schoolId);
                      final teacherId = user?.id ?? 'tch_001';
                      final hasOverlap = existingLeaves.any((l) {
                        if (l.teacherId != teacherId && l.teacherName != user?.name) return false;
                        if (l.status == 'rejected' || l.status == 'cancelled') return false;
                        // Overlap if (fromDate <= l.toDate) && (toDate >= l.fromDate)
                        return !fromDate.isAfter(l.toDate) && !toDate.isBefore(l.fromDate);
                      });

                      if (hasOverlap) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.softCoral,
                              content: Text('You already have a pending or approved leave request for these dates.'),
                            ),
                          );
                        }
                        return;
                      }

                      final req = TeacherLeaveModel(
                        id: 'leave_${DateTime.now().millisecondsSinceEpoch}',
                        schoolId: user?.schoolId ?? '',
                        teacherId: teacherId,
                        teacherName: user?.name ?? 'Teacher',
                        leaveType: selectedType,
                        fromDate: fromDate,
                        toDate: toDate,
                        reason: reasonCtrl.text.trim(),
                        status: 'pending',
                        appliedAt: DateTime.now(),
                        attachmentUrl: attachmentCtrl.text.trim().isNotEmpty ? attachmentCtrl.text.trim() : null,
                      );

                      await service.applyTeacherLeave(req);
                      ref.invalidate(pendingLeavesCountProvider);

                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() => _refreshCounter++);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.mutedGreen,
                            content: Text('Leave application submitted for Admin approval!'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Submit Application'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'pending':
        bg = AppColors.warmAmber.withValues(alpha: 0.15);
        fg = AppColors.warmAmber;
        break;
      case 'approved':
        bg = AppColors.mutedGreen.withValues(alpha: 0.15);
        fg = AppColors.mutedGreen;
        break;
      case 'rejected':
        bg = AppColors.softCoral.withValues(alpha: 0.15);
        fg = AppColors.softCoral;
        break;
      default:
        bg = AppColors.coolGray.withValues(alpha: 0.15);
        fg = AppColors.coolGray;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: AppTypography.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w800, fontSize: 10),
      ),
    );
  }
}
