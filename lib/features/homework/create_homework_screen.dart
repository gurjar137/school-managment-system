import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/academic_models.dart';
import '../../core/widgets/app_back_button.dart';

import '../../core/utils/uuid_generator.dart';

class CreateHomeworkScreen extends ConsumerStatefulWidget {
  const CreateHomeworkScreen({super.key});

  @override
  ConsumerState<CreateHomeworkScreen> createState() => _CreateHomeworkScreenState();
}

class _CreateHomeworkScreenState extends ConsumerState<CreateHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedSubject = 'Mathematics';
  String _selectedClass = '8';
  String _selectedSection = 'A';
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 2));
  bool _isSaving = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final user = ref.read(authProvider);
        final newItem = HomeworkModel(
          id: generateUuidV4(),
          subject: _selectedSubject,
          className: _selectedClass,
          section: _selectedSection,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          assignedDate: DateTime.now(),
          dueDate: _dueDate,
          attachmentName: 'Assignment_Doc.pdf',
          status: HomeworkStatus.active,
        );

        await ref.read(schoolRepositoryProvider).addHomework(newItem, schoolId: user?.schoolId);

        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.mutedGreen,
              content: Text('Homework assigned successfully!'),
            ),
          );
          context.pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.softCoral,
              content: Text('Failed to assign homework: $e'),
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
        leadingWidth: AppBackButton.leadingWidth,
        leading: AppBackButton(
          fallbackPath: '/homework',
          onBeforeBack: () async {
            if (_titleController.text.isNotEmpty || _descController.text.isNotEmpty) {
              return await showDiscardChangesDialog(context);
            }
            return true;
          },
        ),
        title: Text('Assign New Homework', style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SUBJECT & CLASS TARGET', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      items: ['Mathematics', 'Physics', 'English', 'Computer Science'].map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedSubject = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedClass,
                      items: ['8', '9', '10'].map((c) {
                        return DropdownMenuItem(value: c, child: Text('Class $c'));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedClass = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('HOMEWORK TITLE', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'e.g., Chapter 4 Quadratic Proofs'),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a title' : null,
              ),
              const SizedBox(height: 16),

              Text('ASSIGNMENT INSTRUCTIONS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Describe exercises, page numbers, or submission requirements...'),
                validator: (v) => v == null || v.isEmpty ? 'Please enter description' : null,
              ),
              const SizedBox(height: 20),

              Text('SUBMISSION DEADLINE', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.softLavender),
                      const SizedBox(width: 12),
                      Text(
                        '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                        style: AppTypography.titleSmall,
                      ),
                      const Spacer(),
                      Text('Change Date', style: AppTypography.labelMedium.copyWith(color: AppColors.softLavender)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: AppColors.pureWhite)
                      : Text('Publish Homework', style: AppTypography.labelLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
