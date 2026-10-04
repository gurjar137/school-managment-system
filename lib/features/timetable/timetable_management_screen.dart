import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/class_section_models.dart';
import '../../data/models/timetable_model.dart';
import 'widgets/duplicate_day_dialog.dart';
import 'widgets/publish_timetable_dialog.dart';
import 'widgets/timetable_period_dialog.dart';

class TimetableManagementScreen extends ConsumerStatefulWidget {
  const TimetableManagementScreen({super.key});

  @override
  ConsumerState<TimetableManagementScreen> createState() => _TimetableManagementScreenState();
}

class _TimetableManagementScreenState extends ConsumerState<TimetableManagementScreen> {
  bool _isLoading = true;
  bool _isGeneratingDemo = false;
  String? _errorMessage;
  String _resolvedSchoolId = '';

  // Metadata caches
  List<AcademicYearModel> _academicYears = [];
  AcademicYearModel? _selectedYear;

  List<SchoolClassModel> _classes = [];
  SchoolClassModel? _selectedClass;

  List<SectionModel> _sections = [];
  SectionModel? _selectedSection;

  List<TeacherModel> _teachers = [];
  TeacherModel? _selectedTeacherFilter;

  List<SubjectModel> _subjects = [];

  // Active Timetable entries
  List<TimetableEntryModel> _entries = [];
  String _searchQuery = '';
  TimetableGridViewMode _viewMode = TimetableGridViewMode.weekly;
  int _selectedDailyTab = 1; // 1 = Mon ... 6 = Sat
  bool _hideUnmatchedTeachers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = ref.read(authProvider);
      String schoolId = profile?.schoolId?.trim() ?? '';
      if (schoolId.isEmpty) {
        final ap = ref.read(authProvider.notifier).activeProfile;
        schoolId = ap?.schoolId.trim() ?? '';
      }
      if (schoolId.isEmpty) {
        schoolId = await ref.read(classSectionServiceProvider).fetchActiveSchoolId();
      }

      _resolvedSchoolId = schoolId;

      if (_resolvedSchoolId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No authenticated school context found. Please log in again.';
        });
        return;
      }

      final ayService = ref.read(academicYearServiceProvider);
      final csService = ref.read(classSectionServiceProvider);
      final tService = ref.read(teacherServiceProvider);

      // 1. Fetch Academic Years
      final years = await ayService.fetchAcademicYears(_resolvedSchoolId);
      final currentYear = AcademicYearOption.resolveCurrent(years);

      _academicYears = years;
      _selectedYear = currentYear ?? (years.isNotEmpty ? years.first : null);

      if (_selectedYear != null) {
        // 2. Fetch Classes for current school & year
        final classes = await csService.fetchClasses(_resolvedSchoolId, _selectedYear!.id);
        _classes = classes;
        _selectedClass = classes.isNotEmpty ? classes.first : null;

        // 3. Fetch Sections for current class
        if (_selectedClass != null) {
          final sections = await csService.fetchSections(_resolvedSchoolId, _selectedClass!.id);
          _sections = sections;
          _selectedSection = sections.isNotEmpty ? sections.first : null;
        }

        // 4. Fetch Live Teachers & Subjects strictly for current school
        final teachers = await tService.getTeachers(schoolId: _resolvedSchoolId);
        _teachers = teachers;

        final subjects = await tService.getSubjects(schoolId: _resolvedSchoolId);
        _subjects = subjects;

        // 5. Fetch Timetable entries
        await _reloadEntries();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[TimetableManagementScreen _initData error]: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load timetable setup: $e';
        });
      }
    }
  }

  Future<void> _reloadEntries() async {
    if (_resolvedSchoolId.isEmpty) return;
    final timetableService = ref.read(timetableServiceProvider);
    final entries = await timetableService.fetchTimetableEntries(
      schoolId: _resolvedSchoolId,
      academicYearId: _selectedYear?.id,
      classId: _selectedClass?.id,
      sectionId: _selectedSection?.id,
    );

    if (mounted) {
      setState(() {
        _entries = entries;
      });
    }
  }

  void _onClassChanged(SchoolClassModel? newClass) async {
    if (newClass == null) return;
    setState(() {
      _selectedClass = newClass;
      _selectedSection = null;
      _isLoading = true;
    });

    final csService = ref.read(classSectionServiceProvider);

    try {
      final sections = await csService.fetchSections(_resolvedSchoolId, newClass.id);
      _sections = sections;
      _selectedSection = sections.isNotEmpty ? sections.first : null;
      await _reloadEntries();
    } catch (e) {
      debugPrint('[TimetableManagementScreen _onClassChanged error]: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSectionChanged(SectionModel? newSection) async {
    setState(() {
      _selectedSection = newSection;
      _isLoading = true;
    });

    await _reloadEntries();

    if (mounted) setState(() => _isLoading = false);
  }

  void _onTeacherFilterChanged(TeacherModel? teacher) {
    setState(() {
      _selectedTeacherFilter = teacher;
    });
  }

  // --- DEMO / DRAFT TIMETABLE GENERATOR ---
  Future<void> _generateExampleDraftTimetable() async {
    if (_selectedYear == null || _selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Academic Year and Class first.'),
          backgroundColor: AppColors.softCoral,
        ),
      );
      return;
    }

    if (_teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No registered teachers found in database for this school. Cannot build demo timetable.'),
          backgroundColor: AppColors.softCoral,
        ),
      );
      return;
    }

    // Safety check: existing entries
    final currentEntries = _entries.where((e) => !e.isCancelled).toList();
    if (currentEntries.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.amberDark),
              SizedBox(width: 8),
              Text('Existing Periods Found'),
            ],
          ),
          content: Text(
            'There are already ${currentEntries.length} period(s) scheduled for Class ${_selectedClass!.name} '
            '${_selectedSection?.name != null ? "(${_selectedSection!.name})" : ""}.\n\n'
            'To protect your data, existing periods will NOT be deleted or overwritten. '
            'Demo draft periods will only be scheduled in open time slots. Do you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.midnightNavy),
              child: const Text('Add Demo Draft Slots'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isGeneratingDemo = true);

    try {
      final timetableService = ref.read(timetableServiceProvider);
      int addedCount = 0;
      int skippedCount = 0;

      // Define standard timetable periods (08:30 to 14:00)
      final periodSlots = [
        {'p': 1, 'start': '08:30', 'end': '09:15'},
        {'p': 2, 'start': '09:15', 'end': '10:00'},
        {'p': 3, 'start': '10:15', 'end': '11:00'}, // after 15m morning recess
        {'p': 4, 'start': '11:00', 'end': '11:45'},
        {'p': 5, 'start': '12:30', 'end': '13:15'}, // after 45m lunch break
        {'p': 6, 'start': '13:15', 'end': '14:00'},
      ];

      // Days: Monday (1) to Friday (5)
      for (int day = 1; day <= 5; day++) {
        for (int pIdx = 0; pIdx < periodSlots.length; pIdx++) {
          final slotInfo = periodSlots[pIdx];
          final periodNumber = slotInfo['p'] as int;
          final startTime = slotInfo['start'] as String;
          final endTime = slotInfo['end'] as String;

          // Alternate real teachers
          final teacherIdx = (day - 1 + pIdx) % _teachers.length;
          final teacher = _teachers[teacherIdx];

          // Use teacher subject or fallback
          final String subjectName;
          if (teacher.subjects.isNotEmpty) {
            subjectName = teacher.subjects[pIdx % teacher.subjects.length].trim();
          } else {
            subjectName = 'Subject not assigned';
          }

          // Assign realistic room
          final String room;
          if (subjectName.toLowerCase().contains('physics') || subjectName.toLowerCase().contains('science')) {
            room = 'Lab 201';
          } else if (subjectName.toLowerCase().contains('math')) {
            room = 'Room 104';
          } else {
            room = 'Hall A';
          }

          final draftEntry = TimetableEntryModel(
            id: '',
            schoolId: _resolvedSchoolId,
            academicYearId: _selectedYear!.id,
            classId: _selectedClass!.id,
            className: _selectedClass!.name,
            sectionId: _selectedSection?.id,
            sectionName: _selectedSection?.name,
            dayOfWeek: day,
            periodNumber: periodNumber,
            startTime: startTime,
            endTime: endTime,
            subjectId: null,
            subjectName: subjectName,
            teacherProfileId: teacher.id,
            teacherName: teacher.name,
            room: room,
            status: TimetableStatus.draft,
            notes: 'Demo / Draft Schedule',
          );

          // Conflict check against all active entries in current list + already added
          final conflict = timetableService.detectConflict(
            entry: draftEntry,
            existingEntries: _entries,
          );

          if (conflict == null) {
            final created = await timetableService.createEntry(draftEntry);
            _entries.add(created);
            addedCount++;
          } else {
            skippedCount++;
          }
        }
      }

      await _reloadEntries();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Demo Draft Schedule created: $addedCount periods added'
              '${skippedCount > 0 ? " ($skippedCount skipped due to overlap)" : ""}. Status: DRAFT.',
            ),
            backgroundColor: AppColors.mutedGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TimetableManagementScreen _generateExampleDraftTimetable error]: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate demo schedule: $e'),
            backgroundColor: AppColors.softCoral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingDemo = false);
    }
  }

  // --- CRUD ACTIONS ---
  void _openAddPeriodDialog({int? defaultDay, TimetableEntryModel? initial}) async {
    if (_selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or configure an active academic year first.'),
          backgroundColor: AppColors.softCoral,
        ),
      );
      return;
    }

    final timetableService = ref.read(timetableServiceProvider);

    final result = await showDialog<TimetableEntryModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TimetablePeriodDialog(
        schoolId: _resolvedSchoolId,
        academicYearId: _selectedYear!.id,
        availableClasses: _classes,
        availableSections: _sections,
        availableTeachers: _teachers,
        availableSubjects: _subjects,
        timetableService: timetableService,
        existingEntries: _entries,
        initialEntry: initial,
        preselectedClassId: _selectedClass?.id,
        preselectedSectionId: _selectedSection?.id,
        preselectedDay: defaultDay,
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initial != null ? 'Period updated successfully.' : 'Period scheduled successfully.',
          ),
          backgroundColor: AppColors.mutedGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reloadEntries();
    }
  }

  void _confirmDeletePeriod(TimetableEntryModel entry) async {
    final isPublished = entry.isPublished;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isPublished ? Icons.warning_amber_rounded : Icons.delete_outline_rounded,
              color: isPublished ? AppColors.amberDark : AppColors.softCoral,
            ),
            const SizedBox(width: 8),
            Text(isPublished ? 'Cancel Published Period?' : 'Delete Period?'),
          ],
        ),
        content: Text(
          isPublished
              ? 'This period is currently PUBLISHED. It will be marked as CANCELLED to preserve historical attendance and logs.'
              : 'Are you sure you want to delete ${entry.subjectName} (${entry.timeRangeFormatted}) from ${entry.dayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Period'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isPublished ? AppColors.amberDark : AppColors.softCoral,
            ),
            child: Text(isPublished ? 'Confirm Cancel' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final timetableService = ref.read(timetableServiceProvider);
      await timetableService.deleteEntry(entry.id, softCancelIfPublished: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublished ? 'Period marked as cancelled.' : 'Period deleted.'),
            backgroundColor: AppColors.mutedGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _reloadEntries();
      }
    }
  }

  void _openPublishDialog() async {
    if (_selectedYear == null || _selectedClass == null) return;
    final timetableService = ref.read(timetableServiceProvider);

    final allSchoolEntries = await timetableService.fetchTimetableEntries(
      schoolId: _resolvedSchoolId,
      academicYearId: _selectedYear!.id,
    );

    if (!mounted) return;

    final publishedCount = await showDialog<int>(
      context: context,
      builder: (ctx) => PublishTimetableDialog(
        schoolId: _resolvedSchoolId,
        academicYearId: _selectedYear!.id,
        academicYearName: _selectedYear!.name,
        classId: _selectedClass!.id,
        className: _selectedClass!.name,
        sectionId: _selectedSection?.id ?? '',
        sectionName: _selectedSection?.name ?? '',
        classEntries: _entries,
        allSchoolEntries: allSchoolEntries,
        timetableService: timetableService,
      ),
    );

    if (publishedCount != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully published $publishedCount period(s)!'),
          backgroundColor: AppColors.mutedGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reloadEntries();
    }
  }

  void _confirmUnpublish() async {
    if (_selectedYear == null || _selectedClass == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history_rounded, color: AppColors.amberDark),
            SizedBox(width: 8),
            Text('Revert to Draft?'),
          ],
        ),
        content: Text(
          'Reverting Class ${_selectedClass!.name} ${_selectedSection?.name != null ? "(${_selectedSection!.name})" : ""} to Draft will allow edits without published restrictions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.amberDark),
            child: const Text('Revert to Draft'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final timetableService = ref.read(timetableServiceProvider);

      final count = await timetableService.unpublishTimetable(
        schoolId: _resolvedSchoolId,
        academicYearId: _selectedYear!.id,
        classId: _selectedClass!.id,
        sectionId: _selectedSection?.id ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reverted $count period(s) to Draft.'),
            backgroundColor: AppColors.amberDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _reloadEntries();
      }
    }
  }

  void _openDuplicateDayDialog() async {
    if (_selectedYear == null || _selectedClass == null) return;
    final timetableService = ref.read(timetableServiceProvider);

    final copiedCount = await showDialog<int>(
      context: context,
      builder: (ctx) => DuplicateDayDialog(
        schoolId: _resolvedSchoolId,
        academicYearId: _selectedYear!.id,
        classId: _selectedClass!.id,
        className: _selectedClass!.name,
        sectionId: _selectedSection?.id ?? '',
        sectionName: _selectedSection?.name ?? '',
        classEntries: _entries,
        timetableService: timetableService,
      ),
    );

    if (copiedCount != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully duplicated $copiedCount period(s)!'),
          backgroundColor: AppColors.mutedGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _reloadEntries();
    }
  }

  // --- DERIVED STATUS & FILTERING ---
  TimetableStatus get _effectiveStatus {
    final nonCancelled = _entries.where((e) => !e.isCancelled).toList();
    if (nonCancelled.isEmpty) return TimetableStatus.draft;
    final publishedCount = nonCancelled.where((e) => e.isPublished).length;
    if (publishedCount == nonCancelled.length) return TimetableStatus.published;
    return TimetableStatus.draft;
  }

  int get _selectedTeacherPeriodCount {
    if (_selectedTeacherFilter == null) return 0;
    return _entries
        .where((e) => (e.teacherProfileId == _selectedTeacherFilter!.id || e.teacherName == _selectedTeacherFilter!.name) && !e.isCancelled)
        .length;
  }

  List<TimetableEntryModel> get _displayedEntries {
    var list = _entries;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((e) {
        final sub = e.subjectName.toLowerCase();
        final t = (e.teacherName ?? '').toLowerCase();
        final r = (e.room ?? '').toLowerCase();
        return sub.contains(q) || t.contains(q) || r.contains(q);
      }).toList();
    }

    if (_selectedTeacherFilter != null && _hideUnmatchedTeachers) {
      list = list.where((e) => (e.teacherProfileId == _selectedTeacherFilter!.id || e.teacherName == _selectedTeacherFilter!.name)).toList();
    }

    return list;
  }

  Color _getSubjectColor(String subjectName) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF059669), // Emerald Green
      const Color(0xFFD97706), // Amber
      const Color(0xFFDC2626), // Coral / Red
      const Color(0xFF2563EB), // Blue
      const Color(0xFF0D9488), // Teal
      const Color(0xFF9333EA), // Purple
      const Color(0xFFEA580C), // Orange
      const Color(0xFF0284C7), // Sky Blue
      const Color(0xFF4F46E5), // Midnight Purple
    ];
    final hash = subjectName.hashCode.abs();
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Timetable Management',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedYear != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.softLavender.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _selectedYear!.name,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.midnightNavy,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  'Centralized schedule engine with conflict protection & live teacher sync',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.coolGray,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Timetable Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _effectiveStatus == TimetableStatus.published
                    ? AppColors.mutedGreen.withValues(alpha: 0.15)
                    : AppColors.amberDark.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _effectiveStatus == TimetableStatus.published
                      ? AppColors.mutedGreen
                      : AppColors.amberDark,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _effectiveStatus == TimetableStatus.published
                        ? Icons.verified_rounded
                        : Icons.edit_calendar_rounded,
                    size: 13,
                    color: _effectiveStatus == TimetableStatus.published
                        ? AppColors.mutedGreen
                        : AppColors.amberDark,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _effectiveStatus == TimetableStatus.published
                        ? 'PUBLISHED'
                        : 'DEMO / DRAFT TIMETABLE',
                    style: AppTypography.labelSmall.copyWith(
                      color: _effectiveStatus == TimetableStatus.published
                          ? AppColors.mutedGreen
                          : AppColors.amberDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Load Demo Schedule button
          OutlinedButton.icon(
            onPressed: (_isLoading || _isGeneratingDemo || _selectedClass == null)
                ? null
                : _generateExampleDraftTimetable,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.midnightNavy,
              side: const BorderSide(color: AppColors.midnightNavy, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: _isGeneratingDemo
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.amberDark),
            label: Text(
              _isGeneratingDemo ? 'Generating...' : 'Load Demo Schedule',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),

          // Duplicate Day
          if (_entries.isNotEmpty && _selectedClass != null)
            TextButton.icon(
              onPressed: _openDuplicateDayDialog,
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('Duplicate Day', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          const SizedBox(width: 8),

          // Publish or Revert action
          if (_entries.isNotEmpty && _selectedClass != null) ...[
            if (_effectiveStatus == TimetableStatus.published)
              TextButton.icon(
                onPressed: _confirmUnpublish,
                icon: const Icon(Icons.history_rounded, size: 16, color: AppColors.amberDark),
                label: const Text(
                  'Revert to Draft',
                  style: TextStyle(color: AppColors.amberDark, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              )
            else
              FilledButton.icon(
                onPressed: _openPublishDialog,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mutedGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                label: const Text('Publish Timetable', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            const SizedBox(width: 8),
          ],

          // Primary + Add Period
          FilledButton.icon(
            onPressed: (_selectedYear != null && _classes.isNotEmpty) ? () => _openAddPeriodDialog() : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.midnightNavy,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 1,
            ),
            icon: const Icon(Icons.add, size: 17),
            label: const Text('+ Add Period', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: LoadingStateWidget(message: 'Loading timetable & academic setup...'));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: AppTypography.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_academicYears.isEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 48, color: AppColors.amberDark),
              const SizedBox(height: 14),
              Text(
                'No active academic year is configured for this school.',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please configure an academic year in Academic Setup before scheduling periods.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.push('/academic-years'),
                child: const Text('Setup Academic Year'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Top Filter Bar
        _buildFilterBar(isDark),

        // Teacher Filter Bar & Stats (if teacher filter active)
        if (_selectedTeacherFilter != null) _buildTeacherHighlightBanner(isDark),

        // View Content
        Expanded(
          child: _displayedEntries.isEmpty
              ? _buildEmptyState(isDark)
              : (_viewMode == TimetableGridViewMode.weekly
                  ? _buildWeeklyGridView(isDark)
                  : _buildDailyListView(isDark)),
        ),

        // Bottom Legend Bar
        _buildLegendBar(isDark),
      ],
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Academic Year Dropdown
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<AcademicYearModel>(
              initialValue: _selectedYear,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Session',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _academicYears.map((ay) {
                return DropdownMenuItem(value: ay, child: Text(ay.name, style: AppTypography.bodySmall));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _reloadEntries();
                }
              },
            ),
          ),

          // Class Selector
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<SchoolClassModel>(
              initialValue: _selectedClass,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Class',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _classes.map((c) {
                return DropdownMenuItem(value: c, child: Text(c.name, style: AppTypography.bodySmall));
              }).toList(),
              onChanged: _onClassChanged,
            ),
          ),

          // Section Selector
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<SectionModel?>(
              initialValue: _selectedSection,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Section',
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<SectionModel?>(
                  value: null,
                  child: Text('All Sections', style: TextStyle(fontSize: 12)),
                ),
                ..._sections.map((s) {
                  return DropdownMenuItem<SectionModel?>(
                    value: s,
                    child: Text('Section ${s.name}', style: AppTypography.bodySmall),
                  );
                }),
              ],
              onChanged: _onSectionChanged,
            ),
          ),

          // Teacher Filter (populated with REAL teachers of authenticated school)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<TeacherModel?>(
              initialValue: _selectedTeacherFilter,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'Teacher Filter',
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.person_search_rounded, size: 16),
                suffixIcon: _selectedTeacherFilter != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => _onTeacherFilterChanged(null),
                      )
                    : null,
              ),
              items: [
                const DropdownMenuItem<TeacherModel?>(
                  value: null,
                  child: Text('All Teachers (Show All)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                ..._teachers.map((t) {
                  final sub = t.subjects.isNotEmpty ? t.subjects.first : 'General';
                  return DropdownMenuItem<TeacherModel?>(
                    value: t,
                    child: Text(
                      '${t.name} ($sub)',
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: _onTeacherFilterChanged,
            ),
          ),

          // Search Field
          SizedBox(
            width: 150,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search subject/room...',
                prefixIcon: const Icon(Icons.search, size: 15),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            ),
          ),

          // View Mode Switcher
          SegmentedButton<TimetableGridViewMode>(
            segments: const [
              ButtonSegment(
                value: TimetableGridViewMode.weekly,
                icon: Icon(Icons.calendar_view_week_rounded, size: 15),
                label: Text('Week Grid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              ButtonSegment(
                value: TimetableGridViewMode.daily,
                icon: Icon(Icons.view_day_rounded, size: 15),
                label: Text('Day View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (set) {
              setState(() => _viewMode = set.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherHighlightBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.midnightNavy.withValues(alpha: 0.06),
        border: Border(
          bottom: BorderSide(color: AppColors.midnightNavy.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.midnightNavy,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.badge_rounded, size: 14, color: AppColors.pureWhite),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              text: 'Active Teacher Filter: ',
              style: AppTypography.bodySmall.copyWith(
                color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: _selectedTeacherFilter!.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: ' (${_selectedTeacherFilter!.subjects.isNotEmpty ? _selectedTeacherFilter!.subjects.join(", ") : "No subjects"})',
                  style: const TextStyle(color: AppColors.coolGray),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.amberDark.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.amberDark, width: 0.8),
            ),
            child: Text(
              '$_selectedTeacherPeriodCount periods/week in this class',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.amberDark,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          // Filter Mode toggle: Highlight vs Only show
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hide others:',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Switch(
                value: _hideUnmatchedTeachers,
                onChanged: (val) => setState(() => _hideUnmatchedTeachers = val),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () => _onTeacherFilterChanged(null),
                icon: const Icon(Icons.close, size: 13),
                label: const Text('Clear Filter', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.softLavender.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_note_rounded, size: 48, color: AppColors.midnightNavy),
            ),
            const SizedBox(height: 18),
            Text(
              'No timetable created yet',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Get started by adding periods manually or generate a realistic demo timetable\nusing real teachers registered in this school.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isGeneratingDemo ? null : _generateExampleDraftTimetable,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.amberDark),
                  label: const Text('Load Demo Schedule', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                FilledButton.icon(
                  onPressed: () => _openAddPeriodDialog(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.midnightNavy,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create First Period', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WEEKLY GRID VIEW ---
  Widget _buildWeeklyGridView(bool isDark) {
    final days = [
      {'val': 1, 'name': 'Monday', 'short': 'MON'},
      {'val': 2, 'name': 'Tuesday', 'short': 'TUE'},
      {'val': 3, 'name': 'Wednesday', 'short': 'WED'},
      {'val': 4, 'name': 'Thursday', 'short': 'THU'},
      {'val': 5, 'name': 'Friday', 'short': 'FRI'},
      {'val': 6, 'name': 'Saturday', 'short': 'SAT'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: days.map((dayMap) {
            final dayVal = dayMap['val'] as int;
            final dayName = dayMap['name'] as String;
            final dayShort = dayMap['short'] as String;
            final dayEntries = _displayedEntries
                .where((e) => e.dayOfWeek == dayVal && !e.isCancelled)
                .toList()
              ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

            return Container(
              width: 270,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              dayShort,
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '($dayName)',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.pureWhite.withValues(alpha: 0.65),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.pureWhite.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${dayEntries.length} slots',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.pureWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Column Content
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        if (dayEntries.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 28,
                                  color: AppColors.coolGray.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No periods scheduled',
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => _openAddPeriodDialog(defaultDay: dayVal),
                                  icon: const Icon(Icons.add, size: 13),
                                  label: const Text('Add Slot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...dayEntries.map((slot) => _buildPeriodCard(slot, isDark)),

                        // Bottom Quick Add Button
                        if (dayEntries.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openAddPeriodDialog(defaultDay: dayVal),
                                icon: const Icon(Icons.add, size: 14),
                                label: const Text('Add Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.midnightNavy,
                                  side: BorderSide(color: AppColors.midnightNavy.withValues(alpha: 0.2)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- DAILY LIST VIEW ---
  Widget _buildDailyListView(bool isDark) {
    final days = [
      {'val': 1, 'name': 'Monday'},
      {'val': 2, 'name': 'Tuesday'},
      {'val': 3, 'name': 'Wednesday'},
      {'val': 4, 'name': 'Thursday'},
      {'val': 5, 'name': 'Friday'},
      {'val': 6, 'name': 'Saturday'},
    ];

    final dayEntries = _displayedEntries
        .where((e) => e.dayOfWeek == _selectedDailyTab && !e.isCancelled)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    return Column(
      children: [
        // Day selector tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: days.map((d) {
                final val = d['val'] as int;
                final name = d['name'] as String;
                final isSelected = _selectedDailyTab == val;
                final count = _displayedEntries.where((e) => e.dayOfWeek == val && !e.isCancelled).length;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      '$name ($count)',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected ? AppColors.pureWhite : (isDark ? AppColors.pureWhite : AppColors.midnightNavy),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.midnightNavy,
                    checkmarkColor: AppColors.pureWhite,
                    onSelected: (s) {
                      if (s) setState(() => _selectedDailyTab = val);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Timeline Entries list
        Expanded(
          child: dayEntries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_available_rounded, size: 44, color: AppColors.coolGray),
                        const SizedBox(height: 12),
                        Text('No periods scheduled for this day', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _openAddPeriodDialog(defaultDay: _selectedDailyTab),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.midnightNavy),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Period'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: dayEntries.length,
                  itemBuilder: (ctx, index) {
                    final slot = dayEntries[index];
                    return _buildTimelineItem(slot, isDark, isLast: index == dayEntries.length - 1);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(TimetableEntryModel slot, bool isDark, {required bool isLast}) {
    final accentColor = _getSubjectColor(slot.subjectName);
    final isTeacherMatch = _selectedTeacherFilter != null && (slot.teacherProfileId == _selectedTeacherFilter!.id || slot.teacherName == _selectedTeacherFilter!.name);
    final isTeacherDimmed = _selectedTeacherFilter != null && (slot.teacherProfileId != _selectedTeacherFilter!.id && slot.teacherName != _selectedTeacherFilter!.name);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time Column
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  slot.startTime,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                ),
                Text(
                  slot.endTime,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${slot.durationMinutes}m',
                    style: TextStyle(color: accentColor, fontWeight: FontWeight.w700, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Timeline vertical track
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTeacherMatch ? AppColors.amberDark : accentColor,
                  border: Border.all(
                    color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isTeacherMatch ? AppColors.amberDark : accentColor).withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),

          // Period Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Opacity(
                opacity: isTeacherDimmed ? 0.35 : 1.0,
                child: _buildPeriodCard(slot, isDark, isWide: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PERIOD CARD WIDGET ---
  Widget _buildPeriodCard(TimetableEntryModel slot, bool isDark, {bool isWide = false}) {
    final accentColor = _getSubjectColor(slot.subjectName);
    final isTeacherMatch = _selectedTeacherFilter != null && (slot.teacherProfileId == _selectedTeacherFilter!.id || slot.teacherName == _selectedTeacherFilter!.name);
    final isTeacherDimmed = _selectedTeacherFilter != null && (slot.teacherProfileId != _selectedTeacherFilter!.id && slot.teacherName != _selectedTeacherFilter!.name);

    final cardContent = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isTeacherMatch ? AppColors.amberDark : accentColor,
            width: isTeacherMatch ? 6 : 4,
          ),
          top: BorderSide(
            color: isTeacherMatch
                ? AppColors.amberDark
                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            width: isTeacherMatch ? 1.5 : 1,
          ),
          right: BorderSide(
            color: isTeacherMatch
                ? AppColors.amberDark
                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            width: isTeacherMatch ? 1.5 : 1,
          ),
          bottom: BorderSide(
            color: isTeacherMatch
                ? AppColors.amberDark
                : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            width: isTeacherMatch ? 1.5 : 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isTeacherMatch
                ? AppColors.amberDark.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: isTeacherMatch ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openAddPeriodDialog(initial: slot),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Row: Time range + Period tag + Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            slot.timeRangeFormatted,
                            style: AppTypography.labelSmall.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (slot.periodNumber != null) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'P${slot.periodNumber}',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.coolGray,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),

                    Row(
                      children: [
                        if (isTeacherMatch)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.amberDark,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'MATCH',
                              style: TextStyle(
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                        // Action Menu
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 16, color: AppColors.coolGray),
                          padding: EdgeInsets.zero,
                          tooltip: 'Period actions',
                          onSelected: (val) {
                            if (val == 'edit') {
                              _openAddPeriodDialog(initial: slot);
                            } else if (val == 'delete') {
                              _confirmDeletePeriod(slot);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Period'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    slot.isPublished ? Icons.block_rounded : Icons.delete_outline_rounded,
                                    size: 16,
                                    color: AppColors.softCoral,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    slot.isPublished ? 'Cancel Period' : 'Delete Period',
                                    style: const TextStyle(color: AppColors.softCoral),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Subject Title
                Text(
                  slot.subjectName,
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Teacher Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: isTeacherMatch
                          ? AppColors.amberDark.withValues(alpha: 0.2)
                          : AppColors.midnightNavy.withValues(alpha: 0.08),
                      child: Icon(
                        Icons.person_rounded,
                        size: 11,
                        color: isTeacherMatch ? AppColors.amberDark : AppColors.midnightNavy,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        slot.teacherName ?? 'No Teacher Assigned',
                        style: AppTypography.bodySmall.copyWith(
                          color: isTeacherMatch
                              ? AppColors.amberDark
                              : (isDark ? const Color(0xFFCBD5E1) : AppColors.midnightNavy),
                          fontWeight: isTeacherMatch ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Room / Location Tag
                if (slot.room != null && slot.room!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 12, color: AppColors.coolGray),
                      const SizedBox(width: 4),
                      Text(
                        slot.room!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.coolGray,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (isTeacherDimmed) {
      return Opacity(
        opacity: 0.32,
        child: cardContent,
      );
    }
    return cardContent;
  }

  // --- LEGEND BAR ---
  Widget _buildLegendBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          Text('Legend: ', style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          _buildLegendDot(AppColors.amberDark, 'Demo / Draft'),
          const SizedBox(width: 12),
          _buildLegendDot(AppColors.mutedGreen, 'Published'),
          const SizedBox(width: 12),
          _buildLegendDot(AppColors.softCoral, 'Cancelled'),
          const SizedBox(width: 20),
          const Icon(Icons.touch_app_outlined, size: 13, color: AppColors.coolGray),
          const SizedBox(width: 4),
          Text(
            'Click any card to edit or reschedule',
            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11),
          ),
          const Spacer(),
          Text(
            'Total Active Periods: ${_entries.where((e) => !e.isCancelled).length}',
            style: AppTypography.labelSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.midnightNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11)),
      ],
    );
  }
}
