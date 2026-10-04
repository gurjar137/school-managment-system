import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/timetable_model.dart';
import '../../../data/services/timetable_service.dart';

class PublishTimetableDialog extends StatefulWidget {
  final String schoolId;
  final String academicYearId;
  final String academicYearName;
  final String classId;
  final String className;
  final String sectionId;
  final String sectionName;
  final List<TimetableEntryModel> classEntries;
  final List<TimetableEntryModel> allSchoolEntries;
  final TimetableService timetableService;

  const PublishTimetableDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.academicYearName,
    required this.classId,
    required this.className,
    required this.sectionId,
    required this.sectionName,
    required this.classEntries,
    required this.allSchoolEntries,
    required this.timetableService,
  });

  @override
  State<PublishTimetableDialog> createState() => _PublishTimetableDialogState();
}

class _PublishTimetableDialogState extends State<PublishTimetableDialog> {
  bool _isPublishing = false;
  late List<TimetableConflict> _conflicts;

  @override
  void initState() {
    super.initState();
    _analyzeSchedule();
  }

  void _analyzeSchedule() {
    final conflicts = <TimetableConflict>[];
    final activeEntries = widget.classEntries.where((e) => !e.isCancelled).toList();

    for (final entry in activeEntries) {
      final c = widget.timetableService.detectConflict(
        entry: entry,
        existingEntries: widget.allSchoolEntries,
        excludeEntryId: entry.id,
      );
      if (c != null) {
        conflicts.add(c);
      }
    }

    _conflicts = conflicts;
  }

  Future<void> _handlePublish() async {
    if (_conflicts.isNotEmpty) return;

    setState(() => _isPublishing = true);
    try {
      final count = await widget.timetableService.publishTimetable(
        schoolId: widget.schoolId,
        academicYearId: widget.academicYearId,
        classId: widget.classId,
        sectionId: widget.sectionId,
      );

      if (mounted) {
        Navigator.pop(context, count);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
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
    final activeEntries = widget.classEntries.where((e) => !e.isCancelled).toList();
    final hasConflicts = _conflicts.isNotEmpty;
    final canPublish = activeEntries.isNotEmpty && !hasConflicts;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hasConflicts
                          ? AppColors.softCoral.withValues(alpha: 0.12)
                          : AppColors.mutedGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasConflicts ? Icons.warning_amber_rounded : Icons.verified_rounded,
                      color: hasConflicts ? AppColors.softCoral : AppColors.mutedGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Publish Timetable', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w700)),
                        Text('Verify schedule integrity before publishing', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Summary Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Academic Year:', widget.academicYearName),
                    const Divider(height: 14),
                    _buildSummaryRow('Class:', widget.className),
                    const Divider(height: 14),
                    _buildSummaryRow('Section:', widget.sectionName.isNotEmpty ? widget.sectionName : 'All Sections'),
                    const Divider(height: 14),
                    _buildSummaryRow('Total Periods:', '${activeEntries.length}'),
                    const Divider(height: 14),
                    _buildSummaryRow(
                      'Conflicts Detected:',
                      '${_conflicts.length}',
                      valueColor: hasConflicts ? AppColors.softCoral : AppColors.mutedGreen,
                      isBold: true,
                    ),
                    const Divider(height: 14),
                    _buildSummaryRow(
                      'Status:',
                      hasConflicts
                          ? 'Conflicts must be resolved'
                          : (activeEntries.isEmpty ? 'No periods created' : 'Ready to Publish'),
                      valueColor: hasConflicts ? AppColors.softCoral : AppColors.mutedGreen,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Conflicts Warning List
              if (hasConflicts) ...[
                Text(
                  'Collisions Found:',
                  style: AppTypography.labelMedium.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _conflicts.length,
                    itemBuilder: (ctx, i) {
                      final c = _conflicts[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.close_rounded, size: 16, color: AppColors.softCoral),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(c.message, style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isPublishing ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: canPublish && !_isPublishing ? _handlePublish : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mutedGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: _isPublishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text('Publish Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray)),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? AppColors.midnightNavy,
          ),
        ),
      ],
    );
  }
}
