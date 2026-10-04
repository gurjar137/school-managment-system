import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/result_models.dart';

class TeacherResultsScreen extends ConsumerStatefulWidget {
  const TeacherResultsScreen({super.key});

  @override
  ConsumerState<TeacherResultsScreen> createState() => _TeacherResultsScreenState();
}

class _TeacherResultsScreenState extends ConsumerState<TeacherResultsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final assignedClass = user?.assignedClass ?? 'Class 8-A';
    final subjectName = user?.subject ?? 'Mathematics';

    final resultService = ref.watch(resultServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Assigned Tests & Exams', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TEACHER MARKS ENTRY HUB', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.softLavender.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$assignedClass • $subjectName', style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Admin-Assigned Examinations', style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tap an assigned examination to enter marks for all 42 enrolled students.', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Assigned Tests & Exams'),
          const SizedBox(height: 10),

          FutureBuilder<List<ExamModel>>(
            future: resultService.getExamsForTeacher(assignedClass, subjectName: subjectName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading assigned exams...');
              }
              final exams = snapshot.data ?? [];

              if (exams.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.quiz_outlined,
                  title: 'No Assigned Exams',
                  message: 'No examinations have been assigned by Admin for Class 8-A / Mathematics.',
                );
              }

              return Column(
                children: exams.map((exam) {
                  return FutureBuilder<List<StudentResultModel>>(
                    future: resultService.getStudentResultsForExam(exam.id),
                    builder: (context, resultsSnapshot) {
                      final results = resultsSnapshot.data ?? [];
                      final completedCount = results.where((r) => r.isComplete).length;
                      final totalCount = results.length > 0 ? results.length : 42;
                      final status = exam.status;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BentoCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(exam.title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                        Text('${exam.subjectName} • AY ${exam.academicYear}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (status == ResultStatus.returned) ...[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.softCoral.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.softCoral.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded, color: AppColors.softCoral, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'RETURNED BY ADMIN: Please review and update student marks.',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w700, fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Progress: $completedCount / $totalCount Completed', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w700)),
                                  Text('Max: ${exam.maxMarks.toStringAsFixed(0)} Marks', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                              const SizedBox(height: 6),

                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: totalCount > 0 ? completedCount / totalCount : 0,
                                  minHeight: 6,
                                  backgroundColor: AppColors.surfaceLight,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    status == ResultStatus.published ? AppColors.mutedGreen : AppColors.softLavender,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => context.push('/enter-marks/${exam.id}'),
                                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                                      label: Text(
                                        status == ResultStatus.published
                                            ? 'View Marks'
                                            : (status == ResultStatus.submitted ? 'View Submitted' : 'Enter Marks'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => context.push('/class-analytics/${exam.id}'),
                                      icon: const Icon(Icons.analytics_outlined, size: 18),
                                      label: const Text('Performance'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ResultStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case ResultStatus.upcoming:
      case ResultStatus.open:
      case ResultStatus.marksInProgress:
        bg = AppColors.warmAmber.withOpacity(0.15);
        fg = AppColors.warmAmber;
        break;
      case ResultStatus.submitted:
      case ResultStatus.underReview:
        bg = AppColors.softLavender.withOpacity(0.15);
        fg = AppColors.softLavender;
        break;
      case ResultStatus.returned:
        bg = AppColors.softCoral.withOpacity(0.15);
        fg = AppColors.softCoral;
        break;
      case ResultStatus.approved:
      case ResultStatus.published:
        bg = AppColors.mutedGreen.withOpacity(0.15);
        fg = AppColors.mutedGreen;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status.displayName, style: AppTypography.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w800, fontSize: 10)),
    );
  }
}
