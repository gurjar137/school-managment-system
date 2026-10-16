import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';

class SubjectCatalogScreen extends ConsumerStatefulWidget {
  const SubjectCatalogScreen({super.key});

  @override
  ConsumerState<SubjectCatalogScreen> createState() => _SubjectCatalogScreenState();
}

class _SubjectCatalogScreenState extends ConsumerState<SubjectCatalogScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SubjectModel> _subjects = [];
  String _searchQuery = '';
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSubjects());
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final profile = ref.read(authProvider);
    var schoolId = profile?.schoolId?.trim() ?? '';

    if (schoolId.isEmpty) {
      try {
        schoolId = await ref.read(classSectionServiceProvider).fetchActiveSchoolId();
      } catch (_) {}
    }

    if (schoolId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated school context found. Please log in again.';
      });
      return;
    }

    try {
      final service = ref.read(teacherServiceProvider);
      final list = await service.getSubjects(schoolId: schoolId);

      if (mounted) {
        setState(() {
          _subjects = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<SubjectModel> get _filteredSubjects {
    return _subjects.where((s) {
      final matchesQuery = _searchQuery.isEmpty ||
          s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s.code != null && s.code!.toLowerCase().contains(_searchQuery.toLowerCase()));

      final matchesFilter = _selectedFilter == 'ALL' ||
          (s.type?.toUpperCase() == _selectedFilter);

      return matchesQuery && matchesFilter;
    }).toList();
  }

  void _showSubjectDialog({SubjectModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    String selectedType = existing?.type ?? 'THEORY';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              existing == null ? 'Add New Subject' : 'Edit Subject',
              style: AppTypography.titleLarge,
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject Name *',
                        hintText: 'e.g. Mathematics, Physics',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a subject name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subject Code (Optional)',
                        hintText: 'e.g. MATH101, PHY01',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(labelText: 'Subject Category'),
                      items: const [
                        DropdownMenuItem(value: 'THEORY', child: Text('Theory Core')),
                        DropdownMenuItem(value: 'PRACTICAL', child: Text('Practical / Lab')),
                        DropdownMenuItem(value: 'ELECTIVE', child: Text('Elective / Activity')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  var schoolId = ref.read(authProvider)?.schoolId?.trim() ?? '';
                  if (schoolId.isEmpty) {
                    try {
                      schoolId = await ref.read(classSectionServiceProvider).fetchActiveSchoolId();
                    } catch (_) {}
                  }
                  final service = ref.read(teacherServiceProvider);

                  try {
                    if (existing == null) {
                      await service.createSubject(
                        schoolId: schoolId,
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
                        type: selectedType,
                      );
                    } else {
                      await service.updateSubject(
                        id: existing.id,
                        schoolId: schoolId,
                        name: nameCtrl.text.trim(),
                        code: codeCtrl.text.trim().isNotEmpty ? codeCtrl.text.trim() : null,
                        type: selectedType,
                      );
                    }

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.mutedGreen,
                          content: Text(existing == null
                              ? 'Subject created successfully!'
                              : 'Subject updated successfully!'),
                        ),
                      );
                      _loadSubjects();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.softCoral,
                          content: Text(e.toString()),
                        ),
                      );
                    }
                  }
                },
                child: Text(existing == null ? 'Create Subject' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteSubject(SubjectModel subject) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text('Are you sure you want to delete "${subject.name}"? This action cannot be undone if exams or timetables depend on it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
            onPressed: () async {
              Navigator.pop(ctx);
              var schoolId = ref.read(authProvider)?.schoolId?.trim() ?? '';
              if (schoolId.isEmpty) {
                try {
                  schoolId = await ref.read(classSectionServiceProvider).fetchActiveSchoolId();
                } catch (_) {}
              }
              try {
                await ref.read(teacherServiceProvider).deleteSubject(
                  id: subject.id,
                  schoolId: schoolId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.mutedGreen,
                      content: Text('Subject "${subject.name}" deleted successfully.'),
                    ),
                  );
                  _loadSubjects();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.softCoral,
                      content: Text(e.toString()),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('Subject Catalog', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Catalog',
            onPressed: _loadSubjects,
          ),
          IconButton(
            icon: Icon(
              Icons.add_rounded,
              color: isDark ? AppColors.pureWhite : AppColors.primaryAccent,
            ),
            tooltip: 'Add Subject',
            onPressed: () => _showSubjectDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubjectDialog(),
        backgroundColor: AppColors.indigo,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Subject', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const LoadingStateWidget(message: 'Loading subject catalog...')
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadSubjects, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                  children: [
                    // Search and Filter Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search subjects by name or code...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All Subjects (${_subjects.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('THEORY', 'Theory Core'),
                          const SizedBox(width: 8),
                          _buildFilterChip('PRACTICAL', 'Practical / Lab'),
                          const SizedBox(width: 8),
                          _buildFilterChip('ELECTIVE', 'Electives'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_filteredSubjects.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              const Icon(Icons.book_outlined, size: 48, color: AppColors.coolGray),
                              const SizedBox(height: 12),
                              Text(
                                _subjects.isEmpty
                                    ? 'No subjects configured yet for this campus.'
                                    : 'No subjects match your filter.',
                                style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
                              ),
                              const SizedBox(height: 16),
                              if (_subjects.isEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => _showSubjectDialog(),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add First Subject'),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...List.generate(_filteredSubjects.length, (index) {
                        final subject = _filteredSubjects[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border, width: 1),
                          ),
                          elevation: 0,
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getTypeColor(subject.type).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getTypeIcon(subject.type),
                                color: _getTypeColor(subject.type),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              subject.name,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.pureWhite : AppColors.primaryText,
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                if (subject.code != null && subject.code!.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.coolGray.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      subject.code!,
                                      style: AppTypography.labelSmall.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  subject.type ?? 'THEORY',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: _getTypeColor(subject.type),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  tooltip: 'Edit Subject',
                                  onPressed: () => _showSubjectDialog(existing: subject),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.softCoral),
                                  tooltip: 'Delete Subject',
                                  onPressed: () => _confirmDeleteSubject(subject),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = value);
      },
      selectedColor: AppColors.indigo.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.indigo : AppColors.secondaryText,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }

  Color _getTypeColor(String? type) {
    switch (type?.toUpperCase()) {
      case 'PRACTICAL':
        return Colors.teal;
      case 'ELECTIVE':
        return Colors.orange;
      case 'THEORY':
      default:
        return AppColors.indigo;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type?.toUpperCase()) {
      case 'PRACTICAL':
        return Icons.biotech_outlined;
      case 'ELECTIVE':
        return Icons.extension_outlined;
      case 'THEORY':
      default:
        return Icons.menu_book_rounded;
    }
  }
}
