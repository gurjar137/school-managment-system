import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/result_models.dart';

class AdminCreateExamScreen extends ConsumerStatefulWidget {
  const AdminCreateExamScreen({super.key});

  @override
  ConsumerState<AdminCreateExamScreen> createState() => _AdminCreateExamScreenState();
}

class _AdminCreateExamScreenState extends ConsumerState<AdminCreateExamScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController(text: 'Unit Test 1');
  final _yearController = TextEditingController(text: '2026-27');
  final _maxMarksController = TextEditingController(text: '50');
  final _passMarksController = TextEditingController(text: '18');
  final _instructionsController = TextEditingController(text: 'Attempt all questions. Calculator not allowed.');

  ExamType _selectedType = ExamType.unitTest;
  String _selectedClass = '8';
  String _selectedSection = 'A';
  String _selectedSubject = 'Mathematics';

  DateTime _examDate = DateTime.now().add(const Duration(days: 5));
  DateTime _submissionDeadline = DateTime.now().add(const Duration(days: 7));
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _maxMarksController.dispose();
    _passMarksController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final maxM = double.tryParse(_maxMarksController.text) ?? 50.0;
      final passM = double.tryParse(_passMarksController.text) ?? 18.0;

      final exam = ExamModel(
        id: '',
        title: _titleController.text,
        type: _selectedType,
        academicYear: _yearController.text,
        className: _selectedClass,
        section: _selectedSection,
        subjectName: _selectedSubject,
        examDate: _examDate,
        submissionDeadline: _submissionDeadline,
        maxMarks: maxM,
        passingMarks: passM,
        instructions: _instructionsController.text,
        status: ResultStatus.open,
        createdByAdminId: ref.read(authProvider)?.id ?? 'admin_001',
      );

      try {
        final persistedExam = await ref.read(resultServiceProvider).createExamByAdmin(exam);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.mutedGreen,
              content: Text('Test "${persistedExam.title}" created & assigned to Class ${persistedExam.fullClassCode} / ${persistedExam.subjectName}!'),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.softCoral,
              content: Text('Failed to create exam: $e'),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Test / Exam (Admin)', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EXAM GENERAL DETAILS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Exam / Test Name', hintText: 'e.g. Unit Test 1'),
                validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ExamType>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(labelText: 'Exam Type'),
                      items: ExamType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName))).toList(),
                      onChanged: (v) => setState(() => _selectedType = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(labelText: 'Academic Year'),
                      validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text('ASSIGNMENT & SCOPING', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedClass,
                      decoration: const InputDecoration(labelText: 'Assigned Class'),
                      items: ['1', '2', '3', '8', '9', '10'].map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
                      onChanged: (v) => setState(() => _selectedClass = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSection,
                      decoration: const InputDecoration(labelText: 'Section'),
                      items: ['A', 'B', 'C'].map((s) => DropdownMenuItem(value: s, child: Text('Section $s'))).toList(),
                      onChanged: (v) => setState(() => _selectedSection = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                decoration: const InputDecoration(labelText: 'Assigned Subject'),
                items: ['Mathematics', 'Science', 'English', 'Hindi', 'Computer'].map((sub) => DropdownMenuItem(value: sub, child: Text(sub))).toList(),
                onChanged: (v) => setState(() => _selectedSubject = v!),
              ),
              const SizedBox(height: 24),

              Text('MARKS & THRESHOLDS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _maxMarksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Maximum Marks'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _passMarksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Passing Marks'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Teacher Instructions & Guidelines'),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: AppColors.pureWhite)
                      : Text('Assign & Schedule Exam', style: AppTypography.labelLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
