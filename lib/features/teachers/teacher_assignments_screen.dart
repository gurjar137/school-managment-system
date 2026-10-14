import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/academic_models.dart';

class TeacherAssignmentsScreen extends ConsumerStatefulWidget {
  final TeacherModel? teacher;

  const TeacherAssignmentsScreen({super.key, this.teacher});

  @override
  ConsumerState<TeacherAssignmentsScreen> createState() => _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState extends ConsumerState<TeacherAssignmentsScreen> {
  late TeacherModel _t;

  @override
  void initState() {
    super.initState();
    _t = widget.teacher ?? const TeacherModel(
      id: '',
      name: 'Faculty Member',
      email: '',
      employeeId: '',
      subjects: [],
      assignedClass: '',
      totalStudents: 0,
      avatarUrl: '',
      phone: '',
      designation: 'Teacher',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_t.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leadingWidth: AppBackButton.leadingWidth,
          leading: const AppBackButton(fallbackPath: '/teachers'),
          title: const Text('Teacher Assignments'),
        ),
        body: const EmptyStateWidget(
          icon: Icons.person_off_rounded,
          title: 'No Teacher Selected',
          message: 'Please select a teacher from the faculty directory.',
        ),
      );
    }

    final teacherService = ref.watch(teacherServiceProvider);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/teachers'),
        title: Text('${_t.name} Assignments', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded, color: AppColors.softLavender),
            tooltip: 'Assign Class & Subject',
            onPressed: () => _showAssignModal(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Teacher Header Summary
          BentoCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: _t.avatarUrl,
                  name: _t.name,
                  radius: 24,
                  borderColor: AppColors.softLavender,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                      Text('${_t.designation} • ID: ${_t.employeeId}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      Text(_t.phone, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('Assigned Classes & Subjects', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 12),

          FutureBuilder<List<TeacherAssignmentModel>>(
            future: teacherService.getTeacherAssignments(schoolId: _t.schoolId, teacherId: _t.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading teacher assignments...');
              }

              final assignments = snapshot.data ?? [];

              if (assignments.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.assignment_ind_outlined,
                  title: 'No Class Assignments',
                  message: 'No classes or subjects assigned to this teacher.',
                );
              }

              return Column(
                children: assignments.map((asg) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BentoCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.class_rounded, color: AppColors.softLavender, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(asg.className, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                                Text('Subject: ${asg.subjectName}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                              ],
                            ),
                          ),
                          if (asg.isClassTeacher)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.midnightNavy,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'CLASS TEACHER',
                                style: AppTypography.labelSmall.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w800, fontSize: 9),
                              ),
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
        onPressed: () => _showAssignModal(context),
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Assign Class'),
      ),
    );
  }

  void _showAssignModal(BuildContext context) {
    String selectedClass = 'Class 1-A';
    String selectedSubject = 'Mathematics';
    bool isClassTeacher = true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Assign Class & Subject', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedClass,
                decoration: const InputDecoration(labelText: 'Target Class & Section'),
                items: const [
                  DropdownMenuItem(value: 'Class 1-A', child: Text('Class 1-A')),
                  DropdownMenuItem(value: 'Class 1-B', child: Text('Class 1-B')),
                  DropdownMenuItem(value: 'Class 10-A', child: Text('Class 10-A')),
                  DropdownMenuItem(value: 'Class 10-B', child: Text('Class 10-B')),
                  DropdownMenuItem(value: 'Class 11-A', child: Text('Class 11-A')),
                  DropdownMenuItem(value: 'Class 11-B', child: Text('Class 11-B')),
                  DropdownMenuItem(value: 'Class 12-A', child: Text('Class 12-A')),
                  DropdownMenuItem(value: 'Class 12-B', child: Text('Class 12-B')),
                ],
                onChanged: (v) {
                  if (v != null) selectedClass = v;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSubject,
                decoration: const InputDecoration(labelText: 'Subject'),
                items: const [
                  DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                  DropdownMenuItem(value: 'Science', child: Text('Science')),
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'Social Science', child: Text('Social Science')),
                ],
                onChanged: (v) {
                  if (v != null) selectedSubject = v;
                },
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Designate as Class Teacher'),
                value: isClassTeacher,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  if (v != null) setState(() => isClassTeacher = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(teacherServiceProvider).assignTeacher(
                    schoolId: _t.schoolId,
                    teacherId: _t.id,
                    academicYearId: 'year_2026_27',
                    classId: 'cls_8',
                    sectionId: 'sec_8_a',
                    subjectId: 'sub_1',
                    className: selectedClass,
                    subjectName: selectedSubject,
                    isClassTeacher: isClassTeacher,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Assigned $selectedClass ($selectedSubject) to ${_t.name}!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.softCoral, content: Text(e.toString().replaceAll('Exception: ', ''))),
                    );
                  }
                }
              },
              child: const Text('Save Assignment'),
            ),
          ],
        );
      },
    );
  }
}
