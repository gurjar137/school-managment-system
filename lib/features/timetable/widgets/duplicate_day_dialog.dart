import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/timetable_model.dart';
import '../../../data/services/timetable_service.dart';

class DuplicateDayDialog extends StatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final List<TimetableEntryModel> classEntries;
  final TimetableService timetableService;

  const DuplicateDayDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.classEntries,
    required this.timetableService,
  });

  @override
  State<DuplicateDayDialog> createState() => _DuplicateDayDialogState();
}

class _DuplicateDayDialogState extends State<DuplicateDayDialog> {
  int _sourceDay = 1;
  int _targetDay = 2;
  bool _isCopying = false;
  String? _errorMessage;

  final List<Map<String, dynamic>> _days = [
    {'val': 1, 'name': 'Monday'},
    {'val': 2, 'name': 'Tuesday'},
    {'val': 3, 'name': 'Wednesday'},
    {'val': 4, 'name': 'Thursday'},
    {'val': 5, 'name': 'Friday'},
    {'val': 6, 'name': 'Saturday'},
  ];

  int get _sourcePeriodCount {
    return widget.classEntries
        .where((e) => e.dayOfWeek == _sourceDay && !e.isCancelled)
        .length;
  }

  Future<void> _executeDuplicate() async {
    if (_sourceDay == _targetDay) {
      setState(() => _errorMessage = 'Source day and target day must be different.');
      return;
    }

    if (_sourcePeriodCount == 0) {
      setState(() => _errorMessage = 'The selected source day has no periods to duplicate.');
      return;
    }

    setState(() {
      _isCopying = true;
      _errorMessage = null;
    });

    try {
      final copied = await widget.timetableService.duplicateDay(
        schoolId: widget.schoolId,
        academicYearId: widget.academicYearId,
        classId: widget.classId,
        sectionId: widget.sectionId,
        sourceDay: _sourceDay,
        targetDay: _targetDay,
        className: widget.className,
        sectionName: widget.sectionName,
      );

      if (mounted) {
        Navigator.pop(context, copied.length);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCopying = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.softLavender.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.copy_rounded, color: AppColors.softLavender, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duplicate Day Schedule', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                        Text('Copy all periods from one day to another', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Class / Section context info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined, size: 18, color: AppColors.coolGray),
                    const SizedBox(width: 8),
                    Text(
                      'Target: Class ${widget.className} ${widget.sectionName.isNotEmpty ? "(${widget.sectionName})" : ""}',
                      style: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Source Day Selector
              DropdownButtonFormField<int>(
                initialValue: _sourceDay,
                decoration: const InputDecoration(
                  labelText: 'Source Day (Copy From)',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                items: _days.map((d) {
                  return DropdownMenuItem<int>(
                    value: d['val'] as int,
                    child: Text(d['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _sourceDay = val;
                      _errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Contains $_sourcePeriodCount active period(s)',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                ),
              ),
              const SizedBox(height: 16),

              // Target Day Selector
              DropdownButtonFormField<int>(
                initialValue: _targetDay,
                decoration: const InputDecoration(
                  labelText: 'Target Day (Paste To)',
                  prefixIcon: Icon(Icons.event_repeat_rounded),
                ),
                items: _days.map((d) {
                  return DropdownMenuItem<int>(
                    value: d['val'] as int,
                    child: Text(d['name'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _targetDay = val;
                      _errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.softCoral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.softCoral.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isCopying ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isCopying ? null : _executeDuplicate,
                    style: FilledButton.styleFrom(backgroundColor: AppColors.midnightNavy),
                    icon: _isCopying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite),
                          )
                        : const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Duplicate Day'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
