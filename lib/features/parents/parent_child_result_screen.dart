import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/result_models.dart';
import '../../data/models/student_model.dart';
import '../../data/services/grade_service.dart';
import '../../data/services/pdf_service.dart';

class ParentChildResultScreen extends ConsumerStatefulWidget {
  final String? studentId;

  const ParentChildResultScreen({super.key, this.studentId});

  @override
  ConsumerState<ParentChildResultScreen> createState() => _ParentChildResultScreenState();
}

class _ParentChildResultScreenState extends ConsumerState<ParentChildResultScreen> {
  StudentModel? _student;
  bool _isLoadingStudent = true;
  bool _isLoadingResults = false;
  String? _errorMessage;
  bool _isInvalidAccessCode = false;
  bool _isNetworkError = false;

  String? _selectedExamId;
  List<Map<String, dynamic>> _publishedExams = [];
  Map<String, StudentResultModel> _examResultModels = {};
  Map<String, List<Map<String, dynamic>>> _examRawRows = {};

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  void _loadStudentData() async {
    setState(() {
      _isLoadingStudent = true;
      _errorMessage = null;
      _isInvalidAccessCode = false;
      _isNetworkError = false;
    });

    final studentService = ref.read(studentServiceProvider);
    StudentModel? s;
    if (widget.studentId != null) {
      s = await studentService.getStudentById(widget.studentId!);
    } else {
      final all = await studentService.getAllStudents();
      if (all.isNotEmpty) {
        s = all.first;
      }
    }

    if (!mounted) return;

    setState(() {
      _student = s;
      _isLoadingStudent = false;
    });

    if (s != null) {
      _fetchPublishedResults(s);
    }
  }

  Future<void> _fetchPublishedResults(StudentModel student) async {
    final accessCode = student.parentAccessCode.trim();
    if (accessCode.isEmpty) {
      setState(() {
        _errorMessage = 'Parent access code is missing for this student record. Please verify your parent credentials.';
        _isInvalidAccessCode = true;
        _isNetworkError = false;
        _isLoadingResults = false;
        _publishedExams = [];
        _examResultModels = {};
        _examRawRows = {};
      });
      return;
    }

    setState(() {
      _isLoadingResults = true;
      _errorMessage = null;
      _isInvalidAccessCode = false;
      _isNetworkError = false;
    });

    try {
      final resultService = ref.read(resultServiceProvider);
      final response = await resultService.getParentPublishedResults(
        accessCode: accessCode,
        studentId: student.id,
      );

      if (!mounted) return;

      if (response['success'] == false) {
        final err = response['error']?.toString() ?? 'Unable to retrieve examination results.';
        final isAuthErr = err.toLowerCase().contains('code') ||
            err.toLowerCase().contains('access') ||
            err.toLowerCase().contains('unauthorized') ||
            err.toLowerCase().contains('denied');
        setState(() {
          _errorMessage = err;
          _isInvalidAccessCode = isAuthErr;
          _isNetworkError = false;
          _isLoadingResults = false;
          _publishedExams = [];
          _examResultModels = {};
          _examRawRows = {};
        });
        return;
      }

      List<dynamic> rawList = [];
      if (response['results'] is List) {
        rawList = response['results'] as List;
      } else if (response['data'] is List) {
        rawList = response['data'] as List;
      }

      _parseResults(student, rawList);
    } catch (e) {
      if (!mounted) return;
      final errStr = e.toString();
      final isNet = errStr.toLowerCase().contains('socketexception') ||
          errStr.toLowerCase().contains('network') ||
          errStr.toLowerCase().contains('timeout') ||
          errStr.toLowerCase().contains('connection');
      final isAuth = errStr.toLowerCase().contains('access') ||
          errStr.toLowerCase().contains('code') ||
          errStr.toLowerCase().contains('unauthorized');

      setState(() {
        _errorMessage = isNet
            ? 'Network connection error. Please check your internet connection and try again.'
            : isAuth
                ? 'Invalid parent access code. Access to published results was denied.'
                : 'Failed to load examination results: $errStr';
        _isNetworkError = isNet;
        _isInvalidAccessCode = isAuth;
        _isLoadingResults = false;
        _publishedExams = [];
        _examResultModels = {};
        _examRawRows = {};
      });
    }
  }

  void _parseResults(StudentModel student, List<dynamic> rawList) {
    if (rawList.isEmpty) {
      setState(() {
        _publishedExams = [];
        _examResultModels = {};
        _examRawRows = {};
        _selectedExamId = null;
        _isLoadingResults = false;
      });
      return;
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Map<String, Map<String, dynamic>> examInfoMap = {};

    for (final item in rawList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final examId = (map['exam_id'] ?? map['id'] ?? 'exam_${grouped.length}').toString();
      final examName = (map['exam_name'] ?? map['exam_title'] ?? map['title'] ?? 'Examination').toString();
      final examDate = (map['exam_date'] ?? '').toString();

      examInfoMap.putIfAbsent(examId, () => {
        'id': examId,
        'title': examName,
        'date': examDate,
      });

      grouped.putIfAbsent(examId, () => []).add(map);
    }

    final List<Map<String, dynamic>> exams = examInfoMap.values.toList();
    final Map<String, StudentResultModel> resultModels = {};

    for (final exam in exams) {
      final examId = exam['id'] as String;
      final rows = grouped[examId] ?? [];

      final List<SubjectResultModel> subjectResults = [];
      double totalMax = 0.0;
      double totalObtained = 0.0;
      String commonRemarks = '';

      for (final row in rows) {
        final subName = (row['subject_name'] ?? row['subject'] ?? 'Subject').toString();
        final maxMarks = (row['max_marks'] as num?)?.toDouble() ?? 100.0;
        final obtained = (row['marks_obtained'] as num?)?.toDouble() ?? 0.0;
        final passMarks = (row['passing_marks'] as num?)?.toDouble() ?? (maxMarks * 0.35);
        final pct = maxMarks > 0 ? (obtained / maxMarks) * 100.0 : 0.0;
        final grade = row['grade']?.toString() ?? GradeService.calculateGrade(pct);
        final isPassed = row['is_passed'] == true || obtained >= passMarks;
        final remarks = (row['remarks'] ?? '').toString();

        if (remarks.isNotEmpty && commonRemarks.isEmpty) {
          commonRemarks = remarks;
        }

        totalMax += maxMarks;
        totalObtained += obtained;

        subjectResults.add(SubjectResultModel(
          subjectName: subName,
          maxMarks: maxMarks,
          obtainedMarks: obtained,
          percentage: pct,
          grade: grade,
          isPassed: isPassed,
        ));
      }

      final overallPercentage = totalMax > 0 ? (totalObtained / totalMax) * 100.0 : 0.0;
      final overallGrade = GradeService.calculateGrade(overallPercentage);
      final isOverallPassed = subjectResults.isNotEmpty && subjectResults.every((s) => s.isPassed);

      resultModels[examId] = StudentResultModel(
        studentId: student.id,
        studentName: student.name,
        rollNumber: student.rollNumber,
        className: student.className,
        section: student.section,
        examId: examId,
        examTitle: exam['title'] as String,
        academicYear: student.academicYearId.isNotEmpty ? student.academicYearId : '2026-27',
        subjectName: subjectResults.isNotEmpty ? subjectResults.first.subjectName : 'General',
        subjectResults: subjectResults,
        totalMaxMarks: totalMax,
        totalObtainedMarks: totalObtained,
        percentage: overallPercentage,
        overallGrade: overallGrade,
        isPassed: isOverallPassed,
        teacherRemarks: commonRemarks.isNotEmpty ? commonRemarks : 'Satisfactory academic performance.',
        status: ResultStatus.published,
        isLocked: true,
        parentId: student.parentAccessCode,
        auditHistory: const [],
      );
    }

    setState(() {
      _publishedExams = exams;
      _examResultModels = resultModels;
      _examRawRows = grouped;
      _isLoadingResults = false;
      if (_selectedExamId == null || !grouped.containsKey(_selectedExamId)) {
        _selectedExamId = exams.isNotEmpty ? exams.first['id'] as String : null;
      }
    });
  }

  void _promptForAccessCode(StudentModel student) async {
    final controller = TextEditingController(text: student.parentAccessCode);
    final enteredCode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Parent Access Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the secure parent access code provided by the school for this student.',
              style: TextStyle(fontSize: 13, color: AppColors.coolGray),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. SCH001-PAR-0001',
                labelText: 'Parent Access Code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (enteredCode != null && enteredCode.isNotEmpty) {
      final updated = student.copyWith(parentAccessCode: enteredCode);
      setState(() {
        _student = updated;
      });
      _fetchPublishedResults(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingStudent) {
      return const Scaffold(
        body: LoadingStateWidget(message: 'Loading academic report card...'),
      );
    }

    if (_student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Academic Report Card')),
        body: const EmptyStateWidget(
          icon: Icons.school_outlined,
          title: 'No Student Found',
          message: 'No student record exists to display report card.',
        ),
      );
    }

    final student = _student!;

    return Scaffold(
      appBar: AppBar(
        title: Text('${student.name} — Report Card', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Results',
            onPressed: () => _fetchPublishedResults(student),
          ),
        ],
      ),
      body: _buildContent(context, student, isDark),
    );
  }

  Widget _buildContent(BuildContext context, StudentModel student, bool isDark) {
    if (_isLoadingResults) {
      return const LoadingStateWidget(message: 'Loading official published results...');
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStudentHeader(student, isDark),
          const SizedBox(height: 32),
          EmptyStateWidget(
            icon: _isInvalidAccessCode
                ? Icons.lock_outline
                : _isNetworkError
                    ? Icons.wifi_off_outlined
                    : Icons.error_outline,
            title: _isInvalidAccessCode
                ? 'Invalid Access Code'
                : _isNetworkError
                    ? 'Connection Error'
                    : 'Unable to Load Results',
            message: _errorMessage!,
            buttonText: _isInvalidAccessCode ? 'Enter Access Code' : 'Retry',
            onAction: _isInvalidAccessCode
                ? () => _promptForAccessCode(student)
                : () => _fetchPublishedResults(student),
          ),
        ],
      );
    }

    if (_publishedExams.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStudentHeader(student, isDark),
          const SizedBox(height: 32),
          const EmptyStateWidget(
            icon: Icons.assignment_outlined,
            title: 'No Published Results Yet',
            message: 'School administrators have not published examination results for this student yet.',
          ),
        ],
      );
    }

    final selectedExam = _publishedExams.firstWhere(
      (e) => e['id'] == _selectedExamId,
      orElse: () => _publishedExams.first,
    );
    final selectedExamId = selectedExam['id'] as String;
    final studentResult = _examResultModels[selectedExamId];
    final rawRows = _examRawRows[selectedExamId] ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Student Header Card
        _buildStudentHeader(student, isDark),
        const SizedBox(height: 16),

        // Published Exams Dropdown Selector
        Text('SELECT PUBLISHED EXAMINATION', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _publishedExams.map((ex) {
              final examId = ex['id'] as String;
              final isSelected = examId == _selectedExamId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(ex['title'] as String),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedExamId = examId;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        if (studentResult == null)
          const EmptyStateWidget(
            icon: Icons.assignment_outlined,
            title: 'No Data for Selected Exam',
            message: 'No published result data found for this examination.',
          )
        else ...[
          // Exam Date & Published Status Badge
          if (selectedExam['date'] != null && selectedExam['date'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.event_outlined, size: 16, color: AppColors.coolGray),
                  const SizedBox(width: 6),
                  Text(
                    'Exam Date: ${selectedExam['date']}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.mutedGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
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
            ),

          // Overall Grade Banner Card
          BentoCard(
            backgroundColor: studentResult.isPassed
                ? AppColors.mutedGreen.withValues(alpha: 0.12)
                : AppColors.softCoral.withValues(alpha: 0.12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Total Score', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    Text(
                      '${studentResult.totalObtainedMarks.toStringAsFixed(0)} / ${studentResult.totalMaxMarks.toStringAsFixed(0)}',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Percentage', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    Text(
                      '${studentResult.percentage.toStringAsFixed(1)}%',
                      style: AppTypography.titleLarge.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Overall Grade', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    Text(
                      studentResult.overallGrade,
                      style: AppTypography.titleLarge.copyWith(
                        color: studentResult.isPassed ? AppColors.mutedGreen : AppColors.softCoral,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subject Breakdown Card
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject-wise Performance', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                const Divider(height: 20),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(1.8),
                    3: FlexColumnWidth(1.6),
                    4: FlexColumnWidth(1.6),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight),
                      children: [
                        Padding(padding: const EdgeInsets.all(8), child: Text('Subject', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray))),
                        Padding(padding: const EdgeInsets.all(8), child: Text('Score', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray), textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('Min Pass', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray), textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('Grade', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray), textAlign: TextAlign.center)),
                        Padding(padding: const EdgeInsets.all(8), child: Text('Status', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray), textAlign: TextAlign.center)),
                      ],
                    ),
                    ...List.generate(studentResult.subjectResults.length, (idx) {
                      final sub = studentResult.subjectResults[idx];
                      final rowMap = idx < rawRows.length ? rawRows[idx] : <String, dynamic>{};
                      final passMarks = (rowMap['passing_marks'] as num?)?.toDouble() ?? (sub.maxMarks * 0.35);

                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(sub.subjectName, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${sub.obtainedMarks.toStringAsFixed(0)} / ${sub.maxMarks.toStringAsFixed(0)}',
                              style: AppTypography.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              passMarks.toStringAsFixed(0),
                              style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              sub.grade,
                              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.softLavender),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              sub.isPassed ? 'PASS' : 'FAIL',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w800,
                                color: sub.isPassed ? AppColors.mutedGreen : AppColors.softCoral,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Teacher Remarks
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Teacher Remarks', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  studentResult.teacherRemarks.isNotEmpty
                      ? studentResult.teacherRemarks
                      : 'Satisfactory academic performance.',
                  style: AppTypography.bodyMedium.copyWith(fontStyle: FontStyle.italic, color: AppColors.coolGray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Printable Report Card PDF Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.midnightNavy,
                foregroundColor: AppColors.pureWhite,
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () async {
                final pdfBytes = await PdfService.generateReportCardPdf(studentResult);
                await PdfService.printOrSharePdf(pdfBytes, 'ReportCard_${student.name}.pdf');
              },
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text(
                'View / Print Official Report Card (PDF)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStudentHeader(StudentModel student, bool isDark) {
    return BentoCard(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          AppAvatar(
            imageUrl: student.avatarUrl,
            name: student.name,
            radius: 28,
            borderColor: AppColors.softLavender,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Class ${student.className}-${student.section} • Roll No: ${student.rollNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
                const SizedBox(height: 2),
                Text('Adm No: ${student.admissionNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.lavenderLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
