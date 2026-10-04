import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/class_section_models.dart';
import '../../../data/models/academic_models.dart';
import '../../../data/models/timetable_model.dart';
import '../../../data/services/timetable_service.dart';

class TimetablePeriodDialog extends StatefulWidget {
  final String schoolId;
  final String academicYearId;
  final List<SchoolClassModel> availableClasses;
  final List<SectionModel> availableSections;
  final List<TeacherModel> availableTeachers;
  final List<SubjectModel> availableSubjects;
  final TimetableService timetableService;
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

  List<SectionModel> get _filteredSections {
    if (_selectedClassId == null) return [];
    return widget.availableSections.where((s) => s.classId == _selectedClassId).toList();
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
    final selectedSection = widget.availableSections.where((s) => s.id == _selectedSectionId).firstOrNull;

    return TimetableEntryModel(
      id: widget.initialEntry?.id ?? '',
      schoolId: widget.schoolId,
      academicYearId: widget.academicYearId,
      classId: _selectedClassId,
      sectionId: _selectedSectionId,
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
    if (!_formKey.currentState!.validate()) return;

    final candidate = _buildCandidate();

    // Check for hard conflict
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

    // If editing published entry, request confirmation
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
        final updated = await widget.timetableService.updateEntry(candidate, forcePublishedUpdate: true);
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 800),
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

                // Scrollable Form Fields
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // Row 1: Class and Section
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedClassId,
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
                              onChanged: (val) {
                                setState(() {
                                  _selectedClassId = val;
                                  final secs = _filteredSections;
                                  _selectedSectionId = secs.isNotEmpty ? secs.first.id : null;
                                });
                                _checkLiveConflict();
                              },
                              validator: (val) => val == null ? 'Select class' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedSectionId,
                              decoration: const InputDecoration(
                                labelText: 'Section',
                                prefixIcon: Icon(Icons.grid_view_rounded),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Sections')),
                                ..._filteredSections.map((s) {
                                  return DropdownMenuItem(
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

                      // Row 4: Subject
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _subjectController,
                              decoration: InputDecoration(
                                labelText: 'Subject *',
                                hintText: 'e.g. Mathematics',
                                prefixIcon: const Icon(Icons.book_outlined),
                                suffixIcon: widget.availableSubjects.isNotEmpty
                                    ? PopupMenuButton<SubjectModel>(
                                        icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                                        tooltip: 'Select from Subject Catalog',
                                        onSelected: (sub) {
                                          setState(() {
                                            _subjectController.text = sub.name;
                                            _selectedSubjectId = sub.id;
                                          });
                                          _checkLiveConflict();
                                        },
                                        itemBuilder: (ctx) {
                                          return widget.availableSubjects.map((s) {
                                            return PopupMenuItem(
                                              value: s,
                                              child: Text(s.name),
                                            );
                                          }).toList();
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => _checkLiveConflict(),
                              validator: (val) =>
                                  val == null || val.trim().isEmpty ? 'Subject is required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 5: Teacher Assignment
                      DropdownButtonFormField<String>(
                        initialValue: _selectedTeacherId,
                        decoration: const InputDecoration(
                          labelText: 'Teacher',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Teacher Assigned')),
                          ...widget.availableTeachers.map((t) {
                            return DropdownMenuItem(
                              value: t.id,
                              child: Text(t.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedTeacherId = val;
                            if (val != null) {
                              final t = widget.availableTeachers.where((t) => t.id == val).firstOrNull;
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
                      onPressed: _isSaving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.midnightNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite),
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
