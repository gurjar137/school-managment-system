import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/class_section_models.dart';

class ClassSectionsScreen extends ConsumerStatefulWidget {
  final SchoolClassModel? targetClass;

  const ClassSectionsScreen({super.key, this.targetClass});

  @override
  ConsumerState<ClassSectionsScreen> createState() => _ClassSectionsScreenState();
}

class _ClassSectionsScreenState extends ConsumerState<ClassSectionsScreen> {
  late SchoolClassModel _cls;
  Future<List<SectionModel>>? _sectionsFuture;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    final fallbackSchoolId = user?.schoolId ?? '';

    _cls = widget.targetClass ?? SchoolClassModel(
      id: '',
      schoolId: fallbackSchoolId,
      academicYearId: '',
      name: 'Class',
      displayOrder: 1,
      sectionsCount: 0,
      createdAt: DateTime.now(),
    );

    _refreshSections();
  }

  void _refreshSections() {
    final service = ref.read(classSectionServiceProvider);
    setState(() {
      if (_cls.schoolId.isEmpty || _cls.id.isEmpty) {
        _sectionsFuture = Future.value([]);
      } else {
        _sectionsFuture = service.fetchSections(_cls.schoolId, _cls.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_cls.name} Sections', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Sections',
            onPressed: _refreshSections,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.softLavender),
            tooltip: 'Add Section',
            onPressed: () => _showAddSectionModal(context),
          ),
        ],
      ),
      body: _sectionsFuture == null
          ? const LoadingStateWidget(message: 'Loading sections for class...')
          : FutureBuilder<List<SectionModel>>(
              future: _sectionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading sections for class...');
                }
                final sections = snapshot.data ?? [];

                if (sections.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.grid_view_rounded,
                    title: 'No Sections Added',
                    message: 'No sections configured for ${_cls.name}.',
                    buttonText: 'Add Section',
                    onAction: () => _showAddSectionModal(context),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refreshSections(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sections.length,
                    itemBuilder: (context, idx) {
                      final sec = sections[idx];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: BentoCard(
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.midnightNavy,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    sec.name,
                                    style: AppTypography.titleLarge.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Section ${sec.name}', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(
                                      sec.capacity != null ? 'Capacity: ${sec.capacity} Students' : 'No Capacity Limit Set',
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.mutedGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sec.status.displayName,
                                  style: AppTypography.bodySmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w800, fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.softCoral, size: 20),
                                tooltip: 'Delete Section',
                                onPressed: () => _confirmDeleteSection(context, sec),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSectionModal(context),
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Section'),
      ),
    );
  }

  void _confirmDeleteSection(BuildContext context, SectionModel sec) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Section?'),
          content: Text('Are you sure you want to delete Section "${sec.name}" from ${_cls.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral, foregroundColor: AppColors.pureWhite),
              onPressed: () async {
                try {
                  await ref.read(classSectionServiceProvider).deleteSection(sec.id);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _refreshSections();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Section "${sec.name}" deleted.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.softCoral, content: Text('Error deleting section: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showAddSectionModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final capacityCtrl = TextEditingController(text: '40');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Add Section to ${_cls.name}', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Section Name (e.g. A, B, Science)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: capacityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Student Capacity'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty) {
                  try {
                    await ref.read(classSectionServiceProvider).createSection(
                      schoolId: _cls.schoolId,
                      academicYearId: _cls.academicYearId,
                      classId: _cls.id,
                      name: nameCtrl.text,
                      capacity: int.tryParse(capacityCtrl.text),
                    );
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    _refreshSections();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Section "${nameCtrl.text}" added to ${_cls.name}!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: AppColors.softCoral, content: Text(e.toString().replaceAll('Exception: ', ''))),
                      );
                    }
                  }
                }
              },
              child: const Text('Save Section'),
            ),
          ],
        );
      },
    );
  }
}
