import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/services/tenant_resolver.dart';
import '../../data/models/notification_preferences_model.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  TimeOfDay _cutoffTime = const TimeOfDay(hour: 9, minute: 30);
  int _subjectCount = 0;
  int _classCount = 0;
  int _sectionCount = 0;
  String _activeSessionName = 'Loading session...';
  bool _isLoadingMetrics = true;
  NotificationPreferencesModel? _notifPrefs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSettingsData());
  }

  Future<void> _loadSettingsData() async {
    setState(() => _isLoadingMetrics = true);

    try {
      final user = ref.read(authProvider);
      String schoolId = user?.schoolId?.trim() ?? '';
      if (schoolId.isEmpty) {
        schoolId = await TenantResolver.resolveActiveSchoolId();
      }

      final attendanceService = ref.read(attendanceServiceProvider);
      final teacherService = ref.read(teacherServiceProvider);
      final classService = ref.read(classSectionServiceProvider);
      final academicYearService = ref.read(academicYearServiceProvider);
      final notifService = ref.read(notificationPreferencesServiceProvider);

      // 1. Cutoff time
      final cutoff = await attendanceService.getCutoffTime(schoolId);

      // 2. Subjects count
      final subjects = await teacherService.getSubjects(schoolId: schoolId);

      // 3. Active Academic Session & Classes
      final years = await academicYearService.fetchAcademicYears(schoolId);
      final currentYear = years.isNotEmpty
          ? years.firstWhere((y) => y.isCurrent, orElse: () => years.first)
          : null;

      int classCount = 0;
      int sectionCount = 0;
      if (currentYear != null) {
        final classes = await classService.fetchClasses(schoolId, currentYear.id);
        classCount = classes.length;
        for (final c in classes) {
          sectionCount += c.sectionsCount;
        }
      }

      // 4. Notification Preferences
      final notifPrefs = await notifService.getPreferences(schoolId, userId: user?.id);

      if (mounted) {
        setState(() {
          _cutoffTime = cutoff;
          _subjectCount = subjects.length;
          _classCount = classCount;
          _sectionCount = sectionCount;
          _notifPrefs = notifPrefs;
          _activeSessionName = currentYear != null
              ? 'Session ${currentYear.name} • Active'
              : 'No Active Academic Session';
          _isLoadingMetrics = false;
        });
      }
    } catch (e) {
      debugPrint('[SettingsScreen _loadSettingsData error]: $e');
      if (mounted) {
        setState(() => _isLoadingMetrics = false);
      }
    }
  }

  Future<void> _pickCutoffTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _cutoffTime,
      helpText: 'SELECT ATTENDANCE CUTOFF TIME',
    );

    if (picked != null && mounted) {
      setState(() => _cutoffTime = picked);
      final user = ref.read(authProvider);
      String schoolId = user?.schoolId?.trim() ?? '';
      if (schoolId.isEmpty) {
        schoolId = await TenantResolver.resolveActiveSchoolId();
      }

      await ref.read(attendanceServiceProvider).setCutoffTime(schoolId, picked);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.mutedGreen,
            content: Text(
              'Attendance cutoff time updated to ${ref.read(attendanceServiceProvider).formatCutoffTime(picked)}!',
            ),
          ),
        );
      }
    }
  }

  void _showOfflineQueueDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final autoSync = ref.watch(offlineSyncProvider);
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, color: AppColors.indigo, size: 28),
                  const SizedBox(width: 12),
                  Text('Offline Queue & Sync Engine', style: AppTypography.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Attendance records, grades, and receipt submissions created without an active internet connection are stored safely in the local persistent queue.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.mainBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Auto-Sync Status:', style: AppTypography.labelMedium),
                    Text(
                      autoSync ? 'ACTIVE (Sync on Network)' : 'PAUSED (Manual Only)',
                      style: AppTypography.labelMedium.copyWith(
                        color: autoSync ? AppColors.success : AppColors.softCoral,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.mutedGreen,
                        content: Text('Offline queue synchronized with central server! All records up to date.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Sync Now'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationPreferencesDialog() {
    final user = ref.read(authProvider);
    final schoolId = user?.schoolId?.trim() ?? 'default';
    final notifService = ref.read(notificationPreferencesServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final prefs = _notifPrefs ?? NotificationPreferencesModel.defaults(schoolId, userId: user?.id);

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, color: AppColors.indigo),
                  const SizedBox(width: 10),
                  Text(
                    'Push & Notification Alerts',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configure notifications sent to administrators, teachers, and parents.',
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.coolGray : AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Toggle 1: Staff Timetable & Leave Alerts
                    SwitchListTile(
                      value: prefs.timetableAlerts,
                      activeColor: AppColors.primaryAccent,
                      activeTrackColor: AppColors.primaryAccent.withValues(alpha: 0.35),
                      title: Text(
                        'Staff Timetable & Leave Alerts',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                        ),
                      ),
                      subtitle: Text(
                        'Notify faculty on timetable substitution or leave approvals',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                      ),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        final updated = prefs.copyWith(timetableAlerts: val);
                        setDialogState(() => _notifPrefs = updated);
                        setState(() => _notifPrefs = updated);
                        await notifService.savePreferences(updated);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: val ? AppColors.mutedGreen : AppColors.coolGray,
                              duration: const Duration(seconds: 2),
                              content: Text('Staff Timetable & Leave Alerts ${val ? 'enabled' : 'disabled'}.'),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),

                    // Toggle 2: Parent Attendance Warnings
                    SwitchListTile(
                      value: prefs.attendanceAlerts,
                      activeColor: AppColors.primaryAccent,
                      activeTrackColor: AppColors.primaryAccent.withValues(alpha: 0.35),
                      title: Text(
                        'Parent Attendance Warnings',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                        ),
                      ),
                      subtitle: Text(
                        'Alert parents when student is absent past attendance cutoff',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                      ),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        final updated = prefs.copyWith(attendanceAlerts: val);
                        setDialogState(() => _notifPrefs = updated);
                        setState(() => _notifPrefs = updated);
                        await notifService.savePreferences(updated);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: val ? AppColors.mutedGreen : AppColors.coolGray,
                              duration: const Duration(seconds: 2),
                              content: Text('Parent Attendance Warnings ${val ? 'enabled' : 'disabled'}.'),
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),

                    // Toggle 3: Fee Reminder Notices
                    SwitchListTile(
                      value: prefs.feeAlerts,
                      activeColor: AppColors.primaryAccent,
                      activeTrackColor: AppColors.primaryAccent.withValues(alpha: 0.35),
                      title: Text(
                        'Fee Reminder Notices',
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                        ),
                      ),
                      subtitle: Text(
                        'Send payment receipts and pending fee reminders',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                      ),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) async {
                        final updated = prefs.copyWith(feeAlerts: val);
                        setDialogState(() => _notifPrefs = updated);
                        setState(() => _notifPrefs = updated);
                        await notifService.savePreferences(updated);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: val ? AppColors.mutedGreen : AppColors.coolGray,
                              duration: const Duration(seconds: 2),
                              content: Text('Fee Reminder Notices ${val ? 'enabled' : 'disabled'}.'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Info Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.midnightNavy.withValues(alpha: 0.5) : AppColors.mainBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.coolGray),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'In-App Dispatch: ACTIVE • Remote Push: Requires Firebase Cloud Messaging (FCM) credentials configuration for background device delivery.',
                              style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.softLavender),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out of Command Center?'),
        content: const Text(
          'Are you sure you want to sign out of this session? Local cache will be safely reset and you will return to the portal sign-in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                context.go('/role-selection');
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final autoSyncEnabled = ref.watch(offlineSyncProvider);
    final pushNotificationsEnabled = ref.watch(pushNotificationProvider);
    final schoolAsync = ref.watch(currentSchoolProvider);
    final school = schoolAsync.valueOrNull;
    final user = ref.watch(authProvider);

    final schoolDisplayName = (school != null && school.name.isNotEmpty && school.name != 'School')
        ? school.name
        : (user?.schoolName != null && user!.schoolName.isNotEmpty && user.schoolName != 'School'
            ? user.schoolName
            : 'School Command OS');

    final attendanceService = ref.read(attendanceServiceProvider);
    final formattedCutoff = attendanceService.formatCutoffTime(_cutoffTime);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('App & School Settings', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Settings',
            onPressed: _loadSettingsData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader(title: 'ACADEMIC CONFIGURATION'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                _buildSettingTile(
                  'School Identity & Branding',
                  schoolDisplayName,
                  Icons.school_outlined,
                  onTap: () async {
                    await context.push('/school-settings');
                    _loadSettingsData();
                  },
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  'Academic Years',
                  _isLoadingMetrics ? 'Loading academic session...' : _activeSessionName,
                  Icons.calendar_month_outlined,
                  onTap: () async {
                    await context.push('/academic-years');
                    _loadSettingsData();
                  },
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  'Timetable',
                  'Weekly schedule, room & teacher assignments',
                  Icons.calendar_today_outlined,
                  onTap: () => context.push('/timetable'),
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  'Class & Section Matrix',
                  _isLoadingMetrics
                      ? 'Loading classes & sections...'
                      : '$_classCount Classes, $_sectionCount Sections Active',
                  Icons.grid_view_rounded,
                  onTap: () => context.push('/classes'),
                ),
                const Divider(height: 1),
                _buildSettingTile(
                  'Subject Catalog',
                  _isLoadingMetrics
                      ? 'Loading subjects...'
                      : '$_subjectCount Core & Elective Subjects',
                  Icons.book_outlined,
                  onTap: () async {
                    await context.push('/subjects');
                    _loadSettingsData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'TELEMETRY & SYNC'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                _buildSettingTile(
                  'Attendance Cutoff Time',
                  '$formattedCutoff Daily Warning',
                  Icons.timer_outlined,
                  onTap: _pickCutoffTime,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_rounded, color: AppColors.midnightNavy),
                  title: Text(
                    'Offline Queue Auto-Sync',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    autoSyncEnabled ? 'Sync automatically on network reconnect' : 'Manual synchronization only',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.coolGray),
                        tooltip: 'Sync Queue Details',
                        onPressed: _showOfflineQueueDialog,
                      ),
                      Switch(
                        value: autoSyncEnabled,
                        activeThumbColor: AppColors.softLavender,
                        onChanged: (val) => ref.read(offlineSyncProvider.notifier).setEnabled(val),
                      ),
                    ],
                  ),
                  onTap: _showOfflineQueueDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: AppColors.midnightNavy),
                  title: Text(
                    'Push Notifications',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    pushNotificationsEnabled ? 'Parents & Staff alerts enabled' : 'Notification alerts muted',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.coolGray),
                        tooltip: 'Configure Alerts',
                        onPressed: _showNotificationPreferencesDialog,
                      ),
                      Switch(
                        value: pushNotificationsEnabled,
                        activeThumbColor: AppColors.softLavender,
                        onChanged: (val) => ref.read(pushNotificationProvider.notifier).setEnabled(val),
                      ),
                    ],
                  ),
                  onTap: _showNotificationPreferencesDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'SECURITY & ACCOUNT'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                _buildSettingTile(
                  'Change Password',
                  'Update your account password securely',
                  Icons.lock_outline_rounded,
                  onTap: () => context.push('/change-password'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.softCoral),
                  title: Text(
                    'Log Out & Switch Account',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.softCoral,
                    ),
                  ),
                  subtitle: Text(
                    'Sign out of this session and switch staff or admin accounts',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.softCoral),
                  onTap: _confirmLogout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'APPEARANCE & SYSTEM'),
          const SizedBox(height: 8),
          BentoCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: AppColors.softLavender),
                  title: Text('Dark Mode Theme', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    themeMode == ThemeMode.dark ? 'Dark Command Center Active' : 'Light Mode Active',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                  ),
                  trailing: Switch(
                    value: themeMode == ThemeMode.dark,
                    activeThumbColor: AppColors.softLavender,
                    onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, String subtitle, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.midnightNavy),
      title: Text(title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.coolGray),
      onTap: onTap,
    );
  }
}
