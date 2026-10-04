import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/result_models.dart';
import '../../data/services/grade_service.dart';

class EnterMarksScreen extends ConsumerStatefulWidget {
  final String examId;

  const EnterMarksScreen({super.key, required this.examId});

  @override
  ConsumerState<EnterMarksScreen> createState() => _EnterMarksScreenState();
}

class _EnterMarksScreenState extends ConsumerState<EnterMarksScreen> {
  int _currentStudentIndex = 0;
  List<StudentResultModel> _results = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  final Map<String, TextEditingController> _markControllers = {};
  final _remarksController = TextEditingController();
  StudentAttendanceStatus _currentAttendanceStatus = StudentAttendanceStatus.marked;

  @override
  void initState() {
    super.initState();
    _fetchResults();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _remarksController.dispose();
    for (var ctrl in _markControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _fetchResults() async {
    final service = ref.read(resultServiceProvider);
    final list = await service.getStudentResultsForExam(widget.examId, query: _searchController.text);
    if (mounted) {
      setState(() {
        _results = list;
        _isLoading = false;
      });
      if (list.isNotEmpty) {
        _loadStudentIntoForm(0);
      }
    }
  }

  void _loadStudentIntoForm(int index) {
    if (index >= 0 && index < _results.length) {
      _currentStudentIndex = index;
      final res = _results[index];
      _remarksController.text = res.teacherRemarks;
      _currentAttendanceStatus = res.attendanceStatus;

      final obt = res.subjectResults.isNotEmpty ? res.subjectResults.first.obtainedMarks : 0.0;
      if (!_markControllers.containsKey(res.studentId)) {
        _markControllers[res.studentId] = TextEditingController();
      }
      _markControllers[res.studentId]!.text = (res.attendanceStatus == StudentAttendanceStatus.marked)
          ? obt.toStringAsFixed(0)
          : '';
    }
  }

  void _saveCurrentStudentDraft({bool showToast = true}) async {
    if (_results.isEmpty) return;

    final current = _results[_currentStudentIndex];
    final text = _markControllers[current.studentId]?.text ?? '0';
    final val = double.tryParse(text) ?? 0.0;

    await ref.read(resultServiceProvider).saveStudentMark(
          examId: widget.examId,
          studentId: current.studentId,
          mark: val,
          attendanceStatus: _currentAttendanceStatus,
          remarks: _remarksController.text,
        );

    final updatedList = await ref.read(resultServiceProvider).getStudentResultsForExam(widget.examId, query: _searchController.text);
    if (mounted) {
      setState(() {
        _results = updatedList;
      });

      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.softLavender,
            content: Text('✓ Draft saved for ${current.studentName}'),
          ),
        );
      }
    }
  }

  void _nextStudent() {
    _saveCurrentStudentDraft(showToast: false);
    if (_currentStudentIndex < _results.length - 1) {
      setState(() {
        _loadStudentIntoForm(_currentStudentIndex + 1);
      });
    }
  }

  void _prevStudent() {
    _saveCurrentStudentDraft(showToast: false);
    if (_currentStudentIndex > 0) {
      setState(() {
        _loadStudentIntoForm(_currentStudentIndex - 1);
      });
    }
  }

  void _confirmSubmitResults() {
    _saveCurrentStudentDraft(showToast: false);

    final total = _results.length;
    final incompleteList = _results.where((r) => r.subjectResults.isEmpty && r.attendanceStatus == StudentAttendanceStatus.marked).toList();

    if (incompleteList.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Incomplete Marks Warning', style: AppTypography.titleLarge.copyWith(color: AppColors.softCoral)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${incompleteList.length} student(s) still have missing marks. Please enter marks or set Absent before submitting to Admin.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text('Incomplete Students:', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                const SizedBox(height: 6),
                ...incompleteList.take(5).map((s) => Text('• ${s.studentName} (Roll: ${s.rollNumber})', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue Editing'),
              ),
            ],
          );
        },
      );
      return;
    }

    final absentCount = _results.where((r) => r.attendanceStatus == StudentAttendanceStatus.absent).length;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Submit Results for Admin Review?', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm marks submission for Class 8-A / Mathematics.', style: AppTypography.bodyMedium),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Completed Entries:', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  Text('$total / $total', style: AppTypography.titleSmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Absent Students:', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  Text('$absentCount Students', style: AppTypography.titleSmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(resultServiceProvider).submitExamResultsForReview(widget.examId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Results submitted for Admin review!')),
                  );
                  context.pop();
                }
              },
              child: const Text('Confirm Submission'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingStateWidget(message: 'Loading Class 8-A roster...'));
    }

    if (_results.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyStateWidget(icon: Icons.people_outline, title: 'No Students Found', message: 'No student roster associated with this exam.'),
      );
    }

    final currentStudent = _results[_currentStudentIndex];
    final completedCount = _results.where((r) => r.isComplete).length;
    final totalCount = _results.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Class 8-A Marks Entry Board', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, color: AppColors.softLavender),
            tooltip: 'Save Draft',
            onPressed: () => _saveCurrentStudentDraft(showToast: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress & Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Unit Test 1 • Mathematics', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                    Text('Max Marks: 50', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress: $completedCount / $totalCount Completed', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    Text('${((completedCount / totalCount) * 100).toStringAsFixed(0)}%', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.mutedGreen)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: completedCount / totalCount,
                    minHeight: 8,
                    backgroundColor: AppColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.mutedGreen),
                  ),
                ),
              ],
            ),
          ),

          // Student Carousel Selector Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded),
                  onPressed: _currentStudentIndex > 0 ? _prevStudent : null,
                ),
                Column(
                  children: [
                    Text('Student ${_currentStudentIndex + 1} / $totalCount', style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800)),
                    Text(currentStudent.studentName, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                    Text('Roll No: ${currentStudent.rollNumber} • Adm: ${currentStudent.studentId}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: _currentStudentIndex < totalCount - 1 ? _nextStudent : null,
                ),
              ],
            ),
          ),

          // Marks Input Card Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ATTENDANCE & MARKS ENTRY', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                      const SizedBox(height: 12),

                      // Attendance Chips Row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: StudentAttendanceStatus.values.map((status) {
                            final isSelected = _currentAttendanceStatus == status;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(status.displayName),
                                selected: isSelected,
                                selectedColor: status == StudentAttendanceStatus.marked ? AppColors.softLavender : AppColors.softCoral,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _currentAttendanceStatus = status;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_currentAttendanceStatus == StudentAttendanceStatus.marked) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Mathematics Score:', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                controller: _markControllers[currentStudent.studentId],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                autofocus: true,
                                style: AppTypography.numericHeader.copyWith(fontSize: 24),
                                decoration: const InputDecoration(
                                  suffixText: '/ 50',
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.softCoral.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'STUDENT IS ${_currentAttendanceStatus.displayName} FOR THIS EXAM',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarksController,
                        decoration: const InputDecoration(labelText: 'Teacher Remarks', hintText: 'e.g. Good performance.'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live Score & Grade Calculations Preview
                if (_currentAttendanceStatus == StudentAttendanceStatus.marked)
                  BentoCard(
                    backgroundColor: AppColors.midnightNavy,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('Score', style: AppTypography.bodySmall.copyWith(color: AppColors.lavenderLight)),
                            Text(
                              '${(double.tryParse(_markControllers[currentStudent.studentId]?.text ?? '0') ?? 0).toStringAsFixed(0)} / 50',
                              style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text('Percentage', style: AppTypography.bodySmall.copyWith(color: AppColors.lavenderLight)),
                            Text(
                              '${(((double.tryParse(_markControllers[currentStudent.studentId]?.text ?? '0') ?? 0) / 50) * 100).toStringAsFixed(1)}%',
                              style: AppTypography.titleMedium.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text('Grade', style: AppTypography.bodySmall.copyWith(color: AppColors.lavenderLight)),
                            Text(
                              GradeService.calculateGrade(((double.tryParse(_markControllers[currentStudent.studentId]?.text ?? '0') ?? 0) / 50) * 100),
                              style: AppTypography.titleMedium.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Bar Actions
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _saveCurrentStudentDraft(showToast: true),
                    child: const Text('Save Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmSubmitResults,
                    child: const Text('Submit Results'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
