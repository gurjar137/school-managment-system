import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/result_models.dart';

class AdminResultsScreen extends ConsumerStatefulWidget {
  const AdminResultsScreen({super.key});

  @override
  ConsumerState<AdminResultsScreen> createState() => _AdminResultsScreenState();
}

class _AdminResultsScreenState extends ConsumerState<AdminResultsScreen> {
  String _selectedClass = 'All';
  ResultStatus? _selectedStatusFilter;
  Future<List<ExamModel>>? _examsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshExams());
  }

  void _refreshExams() {
    final resultService = ref.read(resultServiceProvider);
    setState(() {
      _examsFuture = resultService.getAllExamsForAdmin(
        className: _selectedClass,
        status: _selectedStatusFilter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('Admin Exam & Result Reviewer', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Examinations',
            onPressed: _refreshExams,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.softLavender),
            tooltip: 'Create Test / Exam',
            onPressed: () async {
              await context.push('/create-exam');
              _refreshExams();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Metric
          BentoCard(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('EXECUTIVE EXAMINATION CONTROL', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    const Icon(Icons.fact_check_rounded, color: AppColors.softLavender, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Admin Exam Scheduling & Review Hub', style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Create tests, assign to faculty, review marks, return for corrections, or publish.', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filters Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Statuses', _selectedStatusFilter == null, () {
                  setState(() => _selectedStatusFilter = null);
                  _refreshExams();
                }),
                _buildFilterChip('Submitted', _selectedStatusFilter == ResultStatus.submitted, () {
                  setState(() => _selectedStatusFilter = ResultStatus.submitted);
                  _refreshExams();
                }),
                _buildFilterChip('Returned', _selectedStatusFilter == ResultStatus.returned, () {
                  setState(() => _selectedStatusFilter = ResultStatus.returned);
                  _refreshExams();
                }),
                _buildFilterChip('Published', _selectedStatusFilter == ResultStatus.published, () {
                  setState(() => _selectedStatusFilter = ResultStatus.published);
                  _refreshExams();
                }),
                const SizedBox(width: 12),
                _buildFilterChip('All Classes', _selectedClass == 'All', () {
                  setState(() => _selectedClass = 'All');
                  _refreshExams();
                }),
                _buildFilterChip('Class 8', _selectedClass == '8', () {
                  setState(() => _selectedClass = '8');
                  _refreshExams();
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          FutureBuilder<List<ExamModel>>(
            future: _examsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading examinations...');
              }
              final exams = snapshot.data ?? [];

              if (exams.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.quiz_outlined,
                  title: 'No Examinations Found',
                  message: 'No tests or exams match the selected filter criteria.',
                );
              }

              return Column(
                children: exams.map((exam) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: BentoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(exam.title, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                  Text('Class ${exam.fullClassCode} • ${exam.subjectName}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                              _buildStatusBadge(exam.status),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Max Marks: ${exam.maxMarks.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                              Text('Pass Marks: ${exam.passingMarks.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              if (exam.status == ResultStatus.submitted || exam.status == ResultStatus.underReview) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showAdminReviewModal(context, exam),
                                    icon: const Icon(Icons.fact_check_rounded, size: 16),
                                    label: const Text('Review Marks'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showReturnDialog(context, exam),
                                    icon: const Icon(Icons.undo_rounded, size: 16, color: AppColors.softCoral),
                                    label: const Text('Return to Teacher', style: TextStyle(color: AppColors.softCoral, fontSize: 11)),
                                  ),
                                ),
                              ] else if (exam.status == ResultStatus.approved) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.mutedGreen),
                                    onPressed: () async {
                                      await ref.read(resultServiceProvider).publishExamResults(exam.id);
                                      setState(() {});
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Exam "${exam.title}" published! Visible to Parent App.')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.publish_rounded, size: 16),
                                    label: const Text('Publish Results'),
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showAdminReviewModal(context, exam),
                                    icon: const Icon(Icons.visibility_outlined, size: 16),
                                    label: const Text('View Results'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-exam'),
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('+ Create Test / Exam'),
      ),
    );
  }

  void _showReturnDialog(BuildContext context, ExamModel exam) {
    final remarksCtrl = TextEditingController(text: 'Please review and verify missing student marks.');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Return Exam to Teacher?', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Returning "${exam.title}" will unlock marks entry for the assigned teacher.', style: AppTypography.bodyMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Admin Feedback / Required Corrections'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(resultServiceProvider).returnExamToTeacher(exam.id, remarksCtrl.text);
                setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exam "${exam.title}" returned to teacher for corrections.')),
                  );
                }
              },
              child: const Text('Return to Teacher'),
            ),
          ],
        );
      },
    );
  }

  void _showAdminReviewModal(BuildContext context, ExamModel exam) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam.title, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                      Text('Class ${exam.fullClassCode} • ${exam.subjectName}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: FutureBuilder<List<StudentResultModel>>(
                  future: ref.read(resultServiceProvider).getStudentResultsForExam(exam.id),
                  builder: (context, snapshot) {
                    final results = snapshot.data ?? [];
                    if (results.isEmpty) return const LoadingStateWidget(message: 'Loading marks...');

                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, idx) {
                        final res = results[idx];
                        return ListTile(
                          title: Text(res.studentName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Text('Roll: ${res.rollNumber} • Status: ${res.attendanceStatus.displayName}'),
                          trailing: Text(
                            res.attendanceStatus == StudentAttendanceStatus.marked
                                ? '${res.totalObtainedMarks.toStringAsFixed(0)} / ${res.totalMaxMarks.toStringAsFixed(0)} (${res.overallGrade})'
                                : 'ABSENT',
                            style: AppTypography.titleSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(resultServiceProvider).publishExamResults(exam.id);
                    setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Exam "${exam.title}" published to Parent App!')),
                      );
                    }
                  },
                  child: const Text('Approve & Publish Results'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
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
