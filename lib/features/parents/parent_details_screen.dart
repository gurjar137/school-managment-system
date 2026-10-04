import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/parent_model.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';

class ParentDetailsScreen extends ConsumerStatefulWidget {
  final ParentModel? targetParent;

  const ParentDetailsScreen({super.key, this.targetParent});

  @override
  ConsumerState<ParentDetailsScreen> createState() => _ParentDetailsScreenState();
}

class _ParentDetailsScreenState extends ConsumerState<ParentDetailsScreen> {
  late ParentModel _parent;

  @override
  void initState() {
    super.initState();
    _parent = widget.targetParent ?? ParentModel(
      id: '',
      schoolId: '',
      parentCode: '',
      name: '',
      email: '',
      phone: '',
      address: '',
      city: '',
      state: '',
      postalCode: '',
      status: AccountStatus.active,
      linkedStudentsCount: 0,
      createdAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentService = ref.watch(parentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_parent.name, style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Parent ID Highlight Card
          BentoCard(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('UNIQUE PARENT APP LOGIN KEY', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                const SizedBox(height: 8),
                SelectableText(
                  _parent.parentCode,
                  style: AppTypography.displayMedium.copyWith(fontSize: 26, color: AppColors.pureWhite, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.softLavender,
                        foregroundColor: AppColors.pureWhite,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _parent.parentCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Copied Parent ID "${_parent.parentCode}"')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Parent ID'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Contact & Address Details
          BentoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Parent Contact Details', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                const Divider(height: 20),
                _buildInfoRow('Full Name', _parent.name),
                _buildInfoRow('Primary Mobile Phone', _parent.phone),
                if (_parent.email != null) _buildInfoRow('Email Address', _parent.email!),
                if (_parent.address != null) _buildInfoRow('Address', '${_parent.address}, ${_parent.city ?? ''} ${_parent.state ?? ''}'),
                _buildInfoRow('Account Status', _parent.status.displayName),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Linked Children Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Linked Children (${_parent.linkedStudentsCount})', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.softLavender,
                  foregroundColor: AppColors.pureWhite,
                ),
                onPressed: () => _showLinkStudentModal(context),
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Link Student'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          FutureBuilder<List<ParentStudentLinkModel>>(
            future: parentService.getLinkedStudentsForParent(_parent.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading linked children...');
              }
              final links = snapshot.data ?? [];

              if (links.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.child_care_rounded,
                  title: 'No Linked Children',
                  message: 'This parent is not currently linked to any student record.',
                );
              }

              return Column(
                children: links.map((link) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BentoCard(
                      child: Row(
                        children: [
                          AppAvatar(
                            imageUrl: link.avatarUrl ?? '',
                            name: link.studentName,
                            radius: 20,
                            borderColor: AppColors.softLavender,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(link.studentName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                Text('${link.studentClass} • ${link.admissionNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.softLavender.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              link.relationship,
                              style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800, fontSize: 10),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.link_off_rounded, color: AppColors.softCoral, size: 20),
                            tooltip: 'Unlink Child',
                            onPressed: () => _confirmUnlink(context, link),
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
    );
  }

  void _showLinkStudentModal(BuildContext context) {
    final studentNameCtrl = TextEditingController();
    final admNoCtrl = TextEditingController();
    String selectedRelation = 'FATHER';
    String selectedStudentId = '';
    String studentClass = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return FutureBuilder<List<StudentModel>>(
              future: ref.read(studentServiceProvider).getAllStudents(
                schoolId: _parent.schoolId.isNotEmpty ? _parent.schoolId : null,
              ),
              builder: (context, snapshot) {
                final students = snapshot.data ?? [];

                return AlertDialog(
                  title: Text('Link Student to ${_parent.name}', style: AppTypography.titleLarge),
                  content: snapshot.connectionState == ConnectionState.waiting
                      ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                      : SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (students.isNotEmpty) ...[
                                DropdownButtonFormField<String>(
                                  value: selectedStudentId.isNotEmpty ? selectedStudentId : null,
                                  decoration: const InputDecoration(labelText: 'Select Enrolled Student'),
                                  isExpanded: true,
                                  items: students.map((s) {
                                    return DropdownMenuItem(
                                      value: s.id,
                                      child: Text(
                                        '${s.name} (${s.className}-${s.section} | ${s.admissionNumber})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final found = students.firstWhere((s) => s.id == val);
                                      setModalState(() {
                                        selectedStudentId = found.id;
                                        studentClass = '${found.className}-${found.section}';
                                        studentNameCtrl.text = found.name;
                                        admNoCtrl.text = found.admissionNumber;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextFormField(
                                controller: studentNameCtrl,
                                decoration: const InputDecoration(labelText: 'Student Full Name'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: admNoCtrl,
                                decoration: const InputDecoration(labelText: 'Admission Number (e.g. ADM-2026-001)'),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: selectedRelation,
                                decoration: const InputDecoration(labelText: 'Relationship to Student'),
                                items: const [
                                  DropdownMenuItem(value: 'FATHER', child: Text('Father')),
                                  DropdownMenuItem(value: 'MOTHER', child: Text('Mother')),
                                  DropdownMenuItem(value: 'GUARDIAN', child: Text('Guardian')),
                                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setModalState(() => selectedRelation = v);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () async {
                        final finalName = studentNameCtrl.text.trim();
                        final finalAdm = admNoCtrl.text.trim();
                        if (finalName.isEmpty) return;

                        try {
                          final sid = selectedStudentId.isNotEmpty
                              ? selectedStudentId
                              : 'stu_${DateTime.now().millisecondsSinceEpoch}';
                          final sClass = studentClass.isNotEmpty ? studentClass : 'Class 8-A';

                          await ref.read(parentServiceProvider).linkStudentToParent(
                            schoolId: _parent.schoolId,
                            parentId: _parent.id,
                            studentId: sid,
                            studentName: finalName,
                            studentClass: sClass,
                            admissionNumber: finalAdm,
                            relationship: selectedRelation,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            setState(() {
                              _parent = _parent.copyWith(linkedStudentsCount: _parent.linkedStudentsCount + 1);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Linked $finalName to ${_parent.name}!')),
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
                      child: const Text('Save Link'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmUnlink(BuildContext context, ParentStudentLinkModel link) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unlink Child?'),
          content: Text('Remove ${link.studentName} from ${_parent.name}\'s account? After removal, this parent will no longer be authorized to access this student\'s records.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral, foregroundColor: AppColors.pureWhite),
              onPressed: () async {
                await ref.read(parentServiceProvider).unlinkStudentFromParent(link.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  setState(() {
                    _parent = _parent.copyWith(linkedStudentsCount: _parent.linkedStudentsCount > 0 ? _parent.linkedStudentsCount - 1 : 0);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.midnightNavy, content: Text('Unlinked ${link.studentName} from parent account.')),
                  );
                }
              },
              child: const Text('Remove Link'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
          Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
