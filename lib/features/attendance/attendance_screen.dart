import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/utils/teacher_assignment_parser.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  final ScrollController _scrollController = ScrollController();
  List<StudentModel> _paginatedStudents = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 50;
  bool _hasNoActiveAcademicYear = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAcademicYearAndLoad();
    });
  }

  Future<void> _checkAcademicYearAndLoad() async {
    final user = ref.read(authProvider);
    final studentService = ref.read(studentServiceProvider);
    final schoolId = (user?.schoolId != null && user!.schoolId!.isNotEmpty)
        ? user.schoolId!
        : await studentService.fetchActiveSchoolId();

    try {
      final activeAyId = await studentService.fetchActiveAcademicYearId(schoolId);
      if (mounted) {
        setState(() {
          _hasNoActiveAcademicYear = activeAyId == null || activeAyId.isEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasNoActiveAcademicYear = true;
        });
      }
    }

    if (!mounted) return;
    await _loadInitialStudents();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMoreStudents();
    }
  }

  Future<void> _loadInitialStudents() async {
    if (!mounted) return;
    final roster = ref.read(teacherRosterProvider).value;
    if (roster != null && roster.isNotEmpty) {
      if (mounted) {
        setState(() {
          _paginatedStudents = List.from(roster);
          _offset = roster.length;
          _hasMore = roster.length >= _pageSize;
        });
      }
    }

    if (!mounted) return;
    final notifier = ref.read(attendanceBoardProvider.notifier);
    await notifier.loadClassAttendanceSummary();

    if (_paginatedStudents.isNotEmpty) return;

    final user = ref.read(authProvider);
    final repo = ref.read(schoolRepositoryProvider);

    final isTeacher = user?.role == UserRole.teacher;
    final teacherParser = TeacherAssignmentParser(
      assignedClass: user?.assignedClass,
      assignedSection: user?.assignedSection,
    );
    final targetClass = teacherParser.rawClass.isNotEmpty ? teacherParser.rawClass : (user?.assignedClass ?? '');
    final targetSection = teacherParser.rawSection.isNotEmpty ? teacherParser.rawSection : (user?.assignedSection ?? '');

    try {
      final students = await repo.getStudents(
        isTeacher: isTeacher,
        teacherAssignedClass: targetClass,
        teacherAssignedSection: targetSection,
        limit: _pageSize,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _paginatedStudents = students;
          _offset = students.length;
          _hasMore = students.length >= _pageSize;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMoreStudents() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final user = ref.read(authProvider);
    final repo = ref.read(schoolRepositoryProvider);

    final isTeacher = user?.role == UserRole.teacher;
    final teacherParser = TeacherAssignmentParser(
      assignedClass: user?.assignedClass,
      assignedSection: user?.assignedSection,
    );
    final targetClass = teacherParser.rawClass.isNotEmpty ? teacherParser.rawClass : (user?.assignedClass ?? '');
    final targetSection = teacherParser.rawSection.isNotEmpty ? teacherParser.rawSection : (user?.assignedSection ?? '');

    try {
      final nextBatch = await repo.getStudents(
        isTeacher: isTeacher,
        teacherAssignedClass: targetClass,
        teacherAssignedSection: targetSection,
        limit: _pageSize,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          final existingIds = _paginatedStudents.map((s) => s.id).toSet();
          final uniqueBatch = nextBatch.where((s) => !existingIds.contains(s.id)).toList();
          _paginatedStudents.addAll(uniqueBatch);
          _offset += nextBatch.length;
          _hasMore = nextBatch.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceBoardProvider);
    final notifier = ref.read(attendanceBoardProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider);

    final teacherParser = TeacherAssignmentParser(
      assignedClass: user?.assignedClass,
      assignedSection: user?.assignedSection,
    );
    final assignedClassDisplay = teacherParser.rawClass.isNotEmpty
        ? teacherParser.rawClass
        : (user?.assignedClass ?? '');
    final assignedSectionDisplay = teacherParser.rawSection.isNotEmpty
        ? teacherParser.rawSection
        : (user?.assignedSection ?? '');

    // Students strictly locked to the teacher's assigned class & section
    final rosterAsync = ref.watch(teacherRosterProvider);
    final List<StudentModel> allStudentsForClass = _paginatedStudents.isNotEmpty
        ? _paginatedStudents
        : (rosterAsync.value ?? []);

    ref.listen<AsyncValue<List<StudentModel>>>(teacherRosterProvider, (prev, next) {
      final students = next.value;
      if (students != null && students.isNotEmpty && _paginatedStudents.isEmpty) {
        setState(() {
          _paginatedStudents = List.from(students);
          _offset = students.length;
          _hasMore = students.length >= _pageSize;
        });
        notifier.loadAttendanceFromDatabase(students);
      }
    });

    var displayedStudents = allStudentsForClass.where((s) {
      final matchesSearch = state.searchQuery.isEmpty ||
          s.name.toLowerCase().contains(state.searchQuery.toLowerCase()) ||
          s.rollNumber.contains(state.searchQuery);
      
      final currentStatus = state.attendanceMap[s.id] ?? AttendanceStatus.notMarked;
      bool matchesFilter = true;
      if (state.filterStatus == 'Present') {
        matchesFilter = currentStatus == AttendanceStatus.present;
      } else if (state.filterStatus == 'Absent') {
        matchesFilter = currentStatus == AttendanceStatus.absent;
      } else if (state.filterStatus == 'Late') {
        matchesFilter = currentStatus == AttendanceStatus.late;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    // Exact server-side metrics: TOTAL, PRESENT, ABSENT, LATE, PERCENTAGE
    final totalCount = state.totalClassStudents > 0
        ? state.totalClassStudents
        : allStudentsForClass.length;
    final presentCount = state.presentCount;
    final absentCount = state.absentCount;
    final lateCount = state.lateCount;
    final attendancePercentage = state.attendancePercentage;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Attendance Engine', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: Icon(
              state.isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
              color: state.isOffline ? AppColors.warmAmber : AppColors.mutedGreen,
            ),
            tooltip: state.isOffline ? 'Offline Mode (Local Queue Active)' : 'Online Mode',
            onPressed: () {
              notifier.toggleOfflineMode();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    state.isOffline
                        ? 'Connected to School Server (Online)'
                        : 'Offline Mode Activated. Attendance will be queued locally.',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.push('/attendance-analytics'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasNoActiveAcademicYear)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softCoral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.softCoral),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.softCoral, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No active academic year is configured for this school. Attendance marking requires an active academic year session.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.softCoral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (user?.role == UserRole.schoolAdmin || user?.role == UserRole.superAdmin) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.softLavender,
                        foregroundColor: AppColors.pureWhite,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => context.push('/academic-years'),
                      child: const Text('Configure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          // Selectors Bar (Class, Section, Date)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            child: Row(
              children: [
                // Read-Only Class Display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_outlined, size: 16, color: AppColors.coolGray),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            assignedClassDisplay.isNotEmpty
                                ? (assignedClassDisplay.toLowerCase().startsWith('class')
                                    ? assignedClassDisplay
                                    : 'Class $assignedClassDisplay')
                                : 'Class --',
                            style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Read-Only Section Display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.coolGray),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            assignedSectionDisplay.isNotEmpty
                                ? (assignedSectionDisplay.toLowerCase().startsWith('sec')
                                    ? assignedSectionDisplay
                                    : 'Section ${assignedSectionDisplay.toUpperCase()}')
                                : 'Section --',
                            style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Date Picker Button
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: state.selectedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2027),
                    );
                    if (picked != null) {
                      notifier.setDate(picked);
                      if (allStudentsForClass.isNotEmpty) {
                        notifier.loadAttendanceFromDatabase(allStudentsForClass);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.softLavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.softLavender),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd MMM').format(state.selectedDate),
                          style: AppTypography.labelMedium.copyWith(color: AppColors.softLavender),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Attendance Telemetry Header Bar
          _buildTopSummary(
            context,
            attendancePercentage: attendancePercentage,
            totalCount: totalCount,
            presentCount: presentCount,
            absentCount: absentCount,
            lateCount: lateCount,
            isDark: isDark,
          ),

          // Quick Action Toolbar (Mark All, Reset, Undo)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: CustomSearchBar(
                    hintText: 'Search student...',
                    onChanged: notifier.setSearchQuery,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.done_all_rounded, color: AppColors.mutedGreen),
                  tooltip: 'Mark All Present',
                  onPressed: () => notifier.markAllPresent(allStudentsForClass),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.undo_rounded, color: AppColors.softLavender),
                  tooltip: 'Undo Last Change',
                  onPressed: state.historyStack.isNotEmpty ? notifier.undo : null,
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.restart_alt_rounded, color: AppColors.softCoral),
                  tooltip: 'Reset Board',
                  onPressed: () => notifier.resetAll(allStudentsForClass),
                ),
              ],
            ),
          ),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['All', 'Present', 'Absent', 'Late'].map((f) {
                final isSelected = state.filterStatus == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: isSelected,
                    onSelected: (_) => notifier.setFilterStatus(f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Student Attendance Board
          Expanded(
            child: rosterAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (allStudentsForClass.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.people_outline_rounded,
                        title: 'No Students Added Yet',
                        message: '0 Students enrolled in this assigned Class & Section.',
                      )
                    : (displayedStudents.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.assignment_turned_in_rounded,
                            title: 'No Matching Students',
                            message: 'No students match the selected filter criteria.',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: displayedStudents.length + (_hasMore && state.searchQuery.isEmpty && state.filterStatus == 'All' ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == displayedStudents.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              final student = displayedStudents[index];
                              final currentStatus = state.attendanceMap[student.id] ?? AttendanceStatus.notMarked;

                              return _buildStudentAttendanceCard(
                                context,
                                student: student,
                                status: currentStatus,
                                isDark: isDark,
                                onStatusChanged: (newStatus) {
                                  notifier.markStudent(student.id, newStatus);
                                },
                              );
                            },
                          ))),
          ),

          // Bottom Floating Save Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isSaving || allStudentsForClass.isEmpty
                      ? null
                      : () async {
                          final ok = await notifier.saveAttendance(assignedStudents: allStudentsForClass);
                          if (ok) {
                            ref.invalidate(teacherRosterProvider);
                            await notifier.loadAttendanceFromDatabase(allStudentsForClass);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.mutedGreen,
                                content: Text(
                                  state.isOffline
                                      ? 'Attendance saved to local queue (Offline Mode)'
                                      : 'Class $assignedClassDisplay - ${assignedSectionDisplay.toUpperCase()} attendance saved successfully!',
                                ),
                              ),
                            );
                          } else {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.softCoral,
                                content: Text(
                                  notifier.lastErrorMessage.isNotEmpty
                                      ? 'Failed to save: ${notifier.lastErrorMessage}'
                                      : 'Failed to save attendance to database. Please try again.',
                                ),
                              ),
                            );
                          }
                        },
                  child: state.isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite),
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                state.isOffline ? 'Save to Offline Queue' : 'Save Attendance Record',
                                style: AppTypography.labelLarge,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummary(
    BuildContext context, {
    required double attendancePercentage,
    required int totalCount,
    required int presentCount,
    required int absentCount,
    required int lateCount,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: BentoCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Circular progress indicator (compact & balanced)
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: totalCount > 0 ? (attendancePercentage / 100).clamp(0.0, 1.0) : 0.0,
                    strokeWidth: 5.5,
                    backgroundColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF1F5F9),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      attendancePercentage >= 90
                          ? AppColors.mutedGreen
                          : (attendancePercentage >= 75 ? AppColors.warmAmber : AppColors.softCoral),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Text(
                        '${attendancePercentage.toStringAsFixed(0)}%',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Responsive metrics breakdown (Expanded columns prevent any horizontal overflow)
            Expanded(
              child: Row(
                children: [
                  _buildHeaderMetric('TOTAL', '$totalCount', AppColors.softLavender),
                  _buildHeaderMetric('PRESENT', '$presentCount', AppColors.mutedGreen),
                  _buildHeaderMetric('ABSENT', '$absentCount', AppColors.softCoral),
                  _buildHeaderMetric('LATE', '$lateCount', AppColors.warmAmber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.coolGray,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAttendanceCard(
    BuildContext context, {
    required StudentModel student,
    required AttendanceStatus status,
    required bool isDark,
    required ValueChanged<AttendanceStatus> onStatusChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                AppAvatar(imageUrl: student.avatarUrl, name: student.name, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                      Text('Roll No: ${student.rollNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    ],
                  ),
                ),
                AttendanceStatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
            // Touch-Friendly Attendance Buttons with neutral unselected state
            Row(
              children: [
                _buildStatusButton(
                  label: 'PRESENT ✓',
                  isSelected: status == AttendanceStatus.present,
                  color: AppColors.mutedGreen,
                  isDark: isDark,
                  onTap: () => onStatusChanged(AttendanceStatus.present),
                ),
                const SizedBox(width: 8),
                _buildStatusButton(
                  label: 'ABSENT ×',
                  isSelected: status == AttendanceStatus.absent,
                  color: AppColors.softCoral,
                  isDark: isDark,
                  onTap: () => onStatusChanged(AttendanceStatus.absent),
                ),
                const SizedBox(width: 8),
                _buildStatusButton(
                  label: 'LATE ⏱',
                  isSelected: status == AttendanceStatus.late,
                  color: AppColors.warmAmber,
                  isDark: isDark,
                  onTap: () => onStatusChanged(AttendanceStatus.late),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required bool isSelected,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? color
                : (isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
              width: 1.2,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  label,
                  style: AppTypography.labelSmall.copyWith(
                    color: isSelected
                        ? AppColors.pureWhite
                        : (isDark ? AppColors.coolGray : const Color(0xFF64748B)),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
