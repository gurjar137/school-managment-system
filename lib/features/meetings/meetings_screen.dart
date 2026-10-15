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

class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> {
  int _refreshCounter = 0;
  String _selectedFilter = 'upcoming'; // 'upcoming', 'all', 'cancelled'

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(schoolManagementServiceProvider);
    final user = ref.watch(authProvider);
    final isAdmin = user?.role == UserRole.schoolAdmin;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Faculty & Staff Meetings', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => setState(() => _refreshCounter++),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryAccent),
              tooltip: 'Schedule Meeting',
              onPressed: () => _showScheduleMeetingDialog(context),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showScheduleMeetingDialog(context),
              icon: const Icon(Icons.video_call_rounded),
              label: const Text('Schedule Meeting'),
              backgroundColor: AppColors.midnightNavy,
              foregroundColor: AppColors.pureWhite,
            )
          : null,
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                _buildFilterChip('Upcoming', 'upcoming'),
                const SizedBox(width: 8),
                _buildFilterChip('All Meetings', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: FutureBuilder<List<SchoolMeetingModel>>(
              key: ValueKey('$_refreshCounter-$_selectedFilter'),
              future: service.getMeetings(
                schoolId: user?.schoolId,
                userRole: user?.role,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading scheduled meetings...');
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }

                var list = snapshot.data ?? [];
                final now = DateTime.now();

                if (_selectedFilter == 'upcoming') {
                  list = list.where((m) => m.status != 'Cancelled' && m.meetingDate.isAfter(now.subtract(const Duration(days: 1)))).toList();
                } else if (_selectedFilter == 'cancelled') {
                  list = list.where((m) => m.status == 'Cancelled').toList();
                }

                if (list.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.event_available_rounded,
                    title: 'No Meetings Found',
                    message: _selectedFilter == 'upcoming'
                        ? 'There are no upcoming faculty or staff meetings scheduled.'
                        : 'No meetings found for the selected filter.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final m = list[index];
                    final dateStr = DateFormat('EEEE, MMM dd, yyyy').format(m.meetingDate);
                    final isCancelled = m.status == 'Cancelled';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: BentoCard(
                        backgroundColor: isCancelled
                            ? AppColors.softCoral.withValues(alpha: 0.05)
                            : null,
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
                                      Text(m.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Organized by: ${m.organizerName}',
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
                                        color: AppColors.softLavender.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        m.targetAudience,
                                        style: AppTypography.labelSmall.copyWith(
                                          color: AppColors.primaryAccent,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStatusBadge(m.status),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Time & Location Details
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkSurface
                                    : AppColors.warmOffWhite,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primaryAccent),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$dateStr • ${m.startTime} - ${m.endTime}',
                                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.coolGray),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          m.locationOrLink,
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Agenda
                            Text('Agenda:', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                            const SizedBox(height: 2),
                            Text(m.agenda, style: AppTypography.bodyMedium),

                            if (isCancelled && m.cancelReason.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.softCoral.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.softCoral.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Cancellation Reason: ${m.cancelReason}',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],

                            // Admin Actions
                            if (isAdmin && !isCancelled) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: AppColors.softCoral),
                                    ),
                                    onPressed: () => _confirmCancelMeetingDialog(context, m),
                                    icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.softCoral),
                                    label: const Text('Cancel Meeting', style: TextStyle(color: AppColors.softCoral)),
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

  Widget _buildFilterChip(String label, String value) {
    final isSel = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: AppColors.primaryAccent.withValues(alpha: 0.18),
      labelStyle: TextStyle(
        color: isSel ? AppColors.primaryAccent : AppColors.coolGray,
        fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'scheduled':
        bg = AppColors.mutedGreen.withValues(alpha: 0.15);
        fg = AppColors.mutedGreen;
        break;
      case 'rescheduled':
        bg = AppColors.warmAmber.withValues(alpha: 0.15);
        fg = AppColors.warmAmber;
        break;
      case 'cancelled':
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

  Future<void> _confirmCancelMeetingDialog(BuildContext context, SchoolMeetingModel meeting) async {
    final reasonCtrl = TextEditingController(text: 'Administrative rescheduling');
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Scheduled Meeting?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel "${meeting.title}"? Attendees will be automatically notified.'),
            const SizedBox(height: 14),
            TextFormField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Meeting'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(schoolManagementServiceProvider);
      final repo = ref.read(schoolRepositoryProvider);
      await service.cancelMeeting(
        meeting.id,
        reasonCtrl.text.trim(),
        repo: repo,
      );
      ref.invalidate(activeMeetingsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
      if (mounted) {
        setState(() => _refreshCounter++);
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.softCoral,
            content: Text('Meeting cancelled and notifications dispatched.'),
          ),
        );
      }
    }
  }

  void _showScheduleMeetingDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final agendaCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: 'School Conference Hall / Google Meet');
    DateTime meetingDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
    String targetAudience = 'All Staff';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final timeRangeStr = '${startTime.format(context)} - ${endTime.format(context)}';

          return AlertDialog(
            title: Text('Schedule Faculty Meeting', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
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
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Title *',
                          hintText: 'e.g. Term Curriculum & Assessment Planning',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: targetAudience,
                        decoration: const InputDecoration(labelText: 'Target Audience *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'All Staff', child: Text('All Staff & Faculty')),
                          DropdownMenuItem(value: 'Teachers Only', child: Text('Teachers Only')),
                          DropdownMenuItem(value: 'Department Heads', child: Text('Department Heads')),
                          DropdownMenuItem(value: 'Admin Only', child: Text('School Admin Team')),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => targetAudience = v);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Date and Time Pickers
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: meetingDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() => meetingDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Meeting Date *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                                ),
                                child: Text(DateFormat('MMM dd, yyyy').format(meetingDate)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final pickedStart = await showTimePicker(context: context, initialTime: startTime);
                                if (pickedStart != null && context.mounted) {
                                  final pickedEnd = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: (pickedStart.hour + 1) % 24, minute: pickedStart.minute),
                                  );
                                  setDialogState(() {
                                    startTime = pickedStart;
                                    if (pickedEnd != null) endTime = pickedEnd;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Time Range *',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.access_time_rounded, size: 18),
                                ),
                                child: Text(timeRangeStr),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: locationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Location / Virtual Link *',
                          hintText: 'e.g. Conference Hall B or https://meet.google.com/...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter location' : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: agendaCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Meeting Agenda *',
                          hintText: 'Outline key topics and objectives...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please specify agenda' : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() ?? false) {
                    final messenger = ScaffoldMessenger.of(context);
                    final user = ref.read(authProvider);
                    final service = ref.read(schoolManagementServiceProvider);
                    final repo = ref.read(schoolRepositoryProvider);

                    final meeting = SchoolMeetingModel(
                      id: 'meet_${DateTime.now().millisecondsSinceEpoch}',
                      schoolId: user?.schoolId ?? '',
                      title: titleCtrl.text.trim(),
                      agenda: agendaCtrl.text.trim(),
                      meetingDate: meetingDate,
                      startTime: startTime.format(context),
                      endTime: endTime.format(context),
                      locationOrLink: locationCtrl.text.trim(),
                      organizerId: user?.id ?? 'admin',
                      organizerName: user?.name ?? 'School Administration',
                      targetAudience: targetAudience,
                      status: 'Scheduled',
                      createdAt: DateTime.now(),
                    );

                    Navigator.pop(ctx);
                    await service.createMeeting(meeting, repo: repo);
                    ref.invalidate(activeMeetingsProvider);
                    ref.invalidate(unreadNotificationsCountProvider);

                    if (mounted) {
                      setState(() => _refreshCounter++);
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.mutedGreen,
                          content: Text('Meeting scheduled and invitations dispatched!'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Schedule Meeting'),
              ),
            ],
          );
        },
      ),
    );
  }
}
