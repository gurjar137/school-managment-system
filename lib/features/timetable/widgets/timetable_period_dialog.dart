import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/class_section_models.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/models/timetable_model.dart';
import '../../../data/services/timetable_service.dart';
import '../../../data/services/class_section_service.dart';

class TimetablePeriodDialog extends StatefulWidget {
  final String schoolId;
  final String academicYearId;
  final List<SchoolClassModel> availableClasses;
  final List<SectionModel> availableSections;
  final List<TeacherModel> availableTeachers;
  final List<SubjectModel> availableSubjects;
  final TimetableService timetableService;
  final ClassSectionService? classSectionService;
  final List<TimetableEntryModel> existingEntries;
  final TimetableEntryModel? initialEntry;
  final String? preselectedClassId;
  final String? preselectedSectionId;
  final int? preselectedDay;

  const TimetablePeriodDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.availableClasses,
    required this.availableSections,
    required this.availableTeachers,
    required this.availableSubjects,
    required this.timetableService,
    this.classSectionService,
    required this.existingEntries,
    this.initialEntry,
    this.preselectedClassId,
    this.preselectedSectionId,
    this.preselectedDay,
  });

  @override
  State<TimetablePeriodDialog> createState() => _TimetablePeriodDialogState();
}

class _TimetablePeriodDialogState extends State<TimetablePeriodDialog> {
  final _formKey = GlobalKey<FormState>();

  late String? _selectedClassId;
  late String? _selectedSectionId;
  late int _selectedDay;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _subjectController;
  late TextEditingController _roomController;
  late TextEditingController _periodNumberController;
  late TextEditingController _notesController;

  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedSubjectId;
  String? _conflictMessage;
  bool _isSaving = false;
  bool _isCustomSubject = false;
  bool _isLoadingSections = false;
  List<SectionModel> _currentSections = [];

  final List<Map<String, dynamic>> _days = [
    {'val': 1, 'name': 'Monday'},
    {'val': 2, 'name': 'Tuesday'},
    {'val': 3, 'name': 'Wednesday'},
    {'val': 4, 'name': 'Thursday'},
    {'val': 5, 'name': 'Friday'},
    {'val': 6, 'name': 'Saturday'},
  ];

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;

    _selectedClassId = entry?.classId ??
        widget.preselectedClassId ??
        (widget.availableClasses.isNotEmpty ? widget.availableClasses.first.id : null);

    _selectedSectionId = entry?.sectionId ?? widget.preselectedSectionId;
    _selectedDay = entry?.dayOfWeek ?? widget.preselectedDay ?? 1;

    _startTimeController = TextEditingController(text: entry?.startTime ?? '08:00');
    _endTimeController = TextEditingController(text: entry?.endTime ?? '08:45');
    _subjectController = TextEditingController(text: entry?.subjectName ?? '');
    _roomController = TextEditingController(text: entry?.room ?? '');
    _periodNumberController = TextEditingController(
      text: entry?.periodNumber != null ? entry!.periodNumber.toString() : '',
    );
    _notesController = TextEditingController(text: entry?.notes ?? '');

    _selectedTeacherId = entry?.teacherProfileId;
    _selectedTeacherName = entry?.teacherName;
    _selectedSubjectId = entry?.subjectId;

    // Resolve initial subject state
    if (widget.availableSubjects.isNotEmpty) {
      if (_selectedSubjectId != null &&
          widget.availableSubjects.any((s) => s.id == _selectedSubjectId)) {
        _isCustomSubject = false;
        final match = widget.availableSubjects.firstWhere((s) => s.id == _selectedSubjectId);
        if (_subjectController.text.trim().isEmpty) {
          _subjectController.text = match.name;
        }
      } else if (_subjectController.text.trim().isNotEmpty) {
        final match = widget.availableSubjects.where(
          (s) => s.name.trim().toLowerCase() == _subjectController.text.trim().toLowerCase(),
        ).firstOrNull;
        if (match != null) {
          _selectedSubjectId = match.id;
          _isCustomSubject = false;
        } else {
          _isCustomSubject = true;
        }
      } else {
        _isCustomSubject = false;
        _selectedSubjectId = widget.availableSubjects.first.id;
        _subjectController.text = widget.availableSubjects.first.name;
      }
    } else {
      _isCustomSubject = true;
    }

    // Populate initial sections
    if (_selectedClassId != null) {
      final matching = widget.availableSections.where((s) => s.classId == _selectedClassId).toList();
      if (matching.isNotEmpty) {
        _currentSections = matching;
      } else if (widget.classSectionService != null) {
        _loadSectionsForClass(_selectedClassId!);
      }
    }

    _checkLiveConflict();
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    _periodNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSectionsForClass(String classId) async {
    if (widget.classSectionService == null) return;
    setState(() => _isLoadingSections = true);
    try {
      final secs = await widget.classSectionService!.fetchSections(widget.schoolId, classId);
      if (mounted) {
        setState(() {
          _currentSections = secs;
          _isLoadingSections = false;
          if (_selectedSectionId != null && !secs.any((s) => s.id == _selectedSectionId)) {
            _selectedSectionId = null;
          }
        });
        _checkLiveConflict();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSections = false);
    }
  }

  void _checkLiveConflict() {
    final candidate = _buildCandidate();
    final conflict = widget.timetableService.detectConflict(
      entry: candidate,
      existingEntries: widget.existingEntries,
      excludeEntryId: widget.initialEntry?.id,
    );

    setState(() {
      _conflictMessage = conflict?.message;
    });
  }

  TimetableEntryModel _buildCandidate() {
    final selectedClass = widget.availableClasses.where((c) => c.id == _selectedClassId).firstOrNull;
    final selectedSection = _currentSections.where((s) => s.id == _selectedSectionId).firstOrNull ??
        widget.availableSections.where((s) => s.id == _selectedSectionId).firstOrNull;

    return TimetableEntryModel(
      id: widget.initialEntry?.id ?? '',
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
      classDisplayCode: selectedClass?.displayCode ?? widget.initialEntry?.classDisplayCode,
      sectionDisplayCode: selectedSection?.displayCode ?? widget.initialEntry?.sectionDisplayCode,
      className: selectedClass?.name ?? widget.initialEntry?.className,
      sectionName: selectedSection?.name ?? widget.initialEntry?.sectionName,
      dayOfWeek: _selectedDay,
      periodNumber: int.tryParse(_periodNumberController.text.trim()),
      startTime: _startTimeController.text.trim(),
      endTime: _endTimeController.text.trim(),
      subjectId: _selectedSubjectId,
      subjectName: _subjectController.text.trim().isNotEmpty
          ? _subjectController.text.trim()
          : 'General Subject',
      teacherProfileId: _selectedTeacherId,
      teacherName: _selectedTeacherName,
      room: _roomController.text.trim().isNotEmpty ? _roomController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      status: widget.initialEntry?.status ?? TimetableStatus.draft,
    );
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final currentParts = controller.text.split(':');
    final initialHour = currentParts.isNotEmpty ? int.tryParse(currentParts[0]) ?? 8 : 8;
    final initialMinute = currentParts.length > 1 ? int.tryParse(currentParts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );

    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() {
        controller.text = '$h:$m';
      });
      _checkLiveConflict();
    }
  }

  Future<void> _submit() async {
    if (widget.availableClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create period: No classes configured yet.'),
          backgroundColor: AppColors.softCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class.'),
          backgroundColor: AppColors.softCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final candidate = _buildCandidate();

    // Check for collision
    final conflict = widget.timetableService.detectConflict(
      entry: candidate,
      existingEntries: widget.existingEntries,
      excludeEntryId: widget.initialEntry?.id,
    );

    if (conflict != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(conflict.message),
          backgroundColor: AppColors.softCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Confirmation if published
    if (widget.initialEntry != null && widget.initialEntry!.isPublished) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.amberDark),
              SizedBox(width: 8),
              Text('Modify Published Period?'),
            ],
          ),
          content: const Text(
            'This timetable is currently PUBLISHED. Any changes made will update the active school schedule immediately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.amberDark),
              child: const Text('Confirm & Update'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.initialEntry != null) {
        final updated = await widget.timetableService.updateEntry(
          candidate,
          forcePublishedUpdate: true,
        );
        if (mounted) Navigator.pop(context, updated);
      } else {
        final created = await widget.timetableService.createEntry(candidate);
        if (mounted) Navigator.pop(context, created);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.softCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEntry != null;
    final isPublished = widget.initialEntry?.isPublished ?? false;

    // Safe dropdown values to prevent assertion crashes
    final hasValidClass = _selectedClassId != null &&
        widget.availableClasses.any((c) => c.id == _selectedClassId);
    final safeClassValue = hasValidClass
        ? _selectedClassId
        : (widget.availableClasses.isNotEmpty ? widget.availableClasses.first.id : null);

    final hasValidSection = _selectedSectionId == null ||
        _currentSections.any((s) => s.id == _selectedSectionId);
    final safeSectionValue = hasValidSection ? _selectedSectionId : null;

    final hasValidTeacher = _selectedTeacherId == null ||
        widget.availableTeachers.any((t) => t.id == _selectedTeacherId);
    final safeTeacherValue = hasValidTeacher ? _selectedTeacherId : null;

    final hasValidSubject = _selectedSubjectId != null &&
        widget.availableSubjects.any((s) => s.id == _selectedSubjectId);
    final safeSubjectValue = _isCustomSubject
        ? '__custom__'
        : (hasValidSubject
            ? _selectedSubjectId
            : (widget.availableSubjects.isNotEmpty
                ? widget.availableSubjects.first.id
                : '__custom__'));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.softLavender.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEditing ? Icons.edit_calendar_rounded : Icons.add_alarm_rounded,
                            color: AppColors.midnightNavy,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? 'Edit Period Slot' : 'Add Period Slot',
                          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (isPublished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.mutedGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.mutedGreen),
                        ),
                        child: Text(
                          'PUBLISHED',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.mutedGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Conflict Banner
                if (_conflictMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softCoral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.softCoral.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _conflictMessage!,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.softCoral,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Honest Empty Class Banner
                if (widget.availableClasses.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.softCoral.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.softCoral.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.softCoral, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'No Classes Available',
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.softCoral,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No classes were found for this academic session. Please add classes in Classes & Sections first.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            context.push('/classes');
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.midnightNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Manage Classes & Sections'),
                        ),
                      ],
                    ),
                  ),

                // Scrollable Form Fields
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Row 1: Class and Section
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: safeClassValue,
                              decoration: const InputDecoration(
                                labelText: 'Class *',
                                prefixIcon: Icon(Icons.meeting_room_outlined),
                              ),
                              items: widget.availableClasses.map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                );
                              }).toList(),
                              onChanged: widget.availableClasses.isEmpty
                                  ? null
                                  : (val) {
                                      if (val == null) return;
                                      setState(() {
                                        _selectedClassId = val;
                                        _selectedSectionId = null;
                                      });
                                      if (widget.classSectionService != null) {
                                        _loadSectionsForClass(val);
                                      } else {
                                        setState(() {
                                          _currentSections = widget.availableSections
                                              .where((s) => s.classId == val)
                                              .toList();
                                        });
                                      }
                                      _checkLiveConflict();
                                    },
                              validator: (val) => val == null ? 'Select class' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              initialValue: safeSectionValue,
                              decoration: InputDecoration(
                                labelText: 'Section',
                                prefixIcon: const Icon(Icons.grid_view_rounded),
                                suffixIcon: _isLoadingSections
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('All Sections'),
                                ),
                                ..._currentSections.map((s) {
                                  return DropdownMenuItem<String?>(
                                    value: s.id,
                                    child: Text('Section ${s.name}'),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedSectionId = val);
                                _checkLiveConflict();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Day of Week & Period Number
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedDay,
                              decoration: const InputDecoration(
                                labelText: 'Day of Week *',
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              items: _days.map((d) {
                                return DropdownMenuItem<int>(
                                  value: d['val'] as int,
                                  child: Text(d['name'] as String),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedDay = val);
                                  _checkLiveConflict();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _periodNumberController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Period #',
                                hintText: '1',
                                prefixIcon: Icon(Icons.numbers_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Start Time and End Time
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _startTimeController,
                              readOnly: true,
                              onTap: () => _selectTime(_startTimeController),
                              decoration: const InputDecoration(
                                labelText: 'Start Time *',
                                prefixIcon: Icon(Icons.access_time_rounded),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _endTimeController,
                              readOnly: true,
                              onTap: () => _selectTime(_endTimeController),
                              decoration: const InputDecoration(
                                labelText: 'End Time *',
                                prefixIcon: Icon(Icons.update_rounded),
                              ),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Subject Selection
                      if (widget.availableSubjects.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: safeSubjectValue,
                          decoration: const InputDecoration(
                            labelText: 'Subject *',
                            prefixIcon: Icon(Icons.book_outlined),
                          ),
                          items: [
                            ...widget.availableSubjects.map((s) {
                              final codeStr =
                                  (s.code != null && s.code!.isNotEmpty) ? ' (${s.code})' : '';
                              return DropdownMenuItem<String>(
                                value: s.id,
                                child: Text('${s.name}$codeStr'),
                              );
                            }),
                            const DropdownMenuItem<String>(
                              value: '__custom__',
                              child: Text('+ Other / Custom Subject...'),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              if (val == '__custom__') {
                                _isCustomSubject = true;
                                _selectedSubjectId = null;
                              } else {
                                _isCustomSubject = false;
                                _selectedSubjectId = val;
                                final sub = widget.availableSubjects
                                    .where((s) => s.id == val)
                                    .firstOrNull;
                                if (sub != null) {
                                  _subjectController.text = sub.name;
                                }
                              }
                            });
                            _checkLiveConflict();
                          },
                          validator: (val) {
                            if (!_isCustomSubject && (val == null || val.isEmpty)) {
                              return 'Please select a subject';
                            }
                            return null;
                          },
                        ),
                        if (_isCustomSubject) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _subjectController,
                            decoration: const InputDecoration(
                              labelText: 'Custom Subject Name *',
                              hintText: 'e.g. Robotics / Sanskrit',
                              prefixIcon: Icon(Icons.edit_note_rounded),
                            ),
                            onChanged: (_) => _checkLiveConflict(),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? 'Subject name is required'
                                : null,
                          ),
                        ],
                      ] else ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.softLavender.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.midnightNavy.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: AppColors.midnightNavy, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Subject Catalog is empty. You can enter a subject name manually or configure subjects in the catalog.',
                                  style: AppTypography.bodySmall,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  context.push('/subject-catalog');
                                },
                                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                label: const Text('Catalog'),
                              ),
                            ],
                          ),
                        ),
                        TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'Subject Name *',
                            hintText: 'e.g. Mathematics',
                            prefixIcon: Icon(Icons.book_outlined),
                          ),
                          onChanged: (_) => _checkLiveConflict(),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Subject is required' : null,
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Row 5: Teacher Assignment
                      DropdownButtonFormField<String?>(
                        initialValue: safeTeacherValue,
                        decoration: InputDecoration(
                          labelText: 'Assigned Teacher',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          helperText: widget.availableTeachers.isEmpty
                              ? 'No registered teachers found for this school'
                              : null,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No Teacher Assigned'),
                          ),
                          ...widget.availableTeachers.map((t) {
                            final sub =
                                t.subjects.isNotEmpty ? ' (${t.subjects.first})' : '';
                            return DropdownMenuItem<String?>(
                              value: t.id,
                              child: Text('${t.name}$sub'),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedTeacherId = val;
                            if (val != null) {
                              final t =
                                  widget.availableTeachers.where((t) => t.id == val).firstOrNull;
                              _selectedTeacherName = t?.name;
                            } else {
                              _selectedTeacherName = null;
                            }
                          });
                          _checkLiveConflict();
                        },
                      ),
                      const SizedBox(height: 14),

                      // Row 6: Room Number & Notes
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _roomController,
                              decoration: const InputDecoration(
                                labelText: 'Room',
                                hintText: 'e.g. Room 102 / Lab A',
                                prefixIcon: Icon(Icons.room_outlined),
                              ),
                              onChanged: (_) => _checkLiveConflict(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                                hintText: 'Optional instructions',
                                prefixIcon: Icon(Icons.notes_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Footer Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: (_isSaving || widget.availableClasses.isEmpty) ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.midnightNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pureWhite,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(isEditing ? 'Save Changes' : 'Create Period'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
