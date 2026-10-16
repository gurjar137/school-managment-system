import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/class_section_models.dart';
import '../../data/models/user_model.dart';

class ClassesListScreen extends ConsumerStatefulWidget {
  const ClassesListScreen({super.key});

  @override
  ConsumerState<ClassesListScreen> createState() => _ClassesListScreenState();
}

class _ClassesListScreenState extends ConsumerState<ClassesListScreen> {
  String? _selectedYearId;
  String? _schoolId;
  List<AcademicYearModel> _years = [];
  Future<List<SchoolClassModel>>? _classesFuture;
  bool _isLoadingInitial = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    final service = ref.read(classSectionServiceProvider);
    final user = ref.read(authProvider);

    String resolvedSchoolId = user?.schoolId ?? '';
    if (resolvedSchoolId.isEmpty) {
      resolvedSchoolId = await service.fetchActiveSchoolId();
    }
    _schoolId = resolvedSchoolId;

    try {
      var years = await service.fetchAcademicYears(_schoolId!);
      if (years.isEmpty) {
        try {
          years = await ref.read(academicYearServiceProvider).fetchAcademicYears(_schoolId!);
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _years = years;
          if (_years.isNotEmpty) {
            final activeYear = _years.firstWhere((y) => y.isCurrent, orElse: () => _years.first);
            _selectedYearId = activeYear.id;
          }
          _isLoadingInitial = false;
        });
        if (_selectedYearId != null) {
          _refreshClasses();
        }
      }
    } catch (e) {
      debugPrint('[ClassesListScreen _initData error]: $e');
      if (mounted) {
        setState(() => _isLoadingInitial = false);
      }
    }
  }

  void _refreshClasses() {
    if (_schoolId == null || _selectedYearId == null) return;
    final service = ref.read(classSectionServiceProvider);
    setState(() {
      _classesFuture = service.fetchClasses(_schoolId!, _selectedYearId!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final canManage = user?.role.isAdministrator ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('Classes & Sections Management', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Classes',
            onPressed: _refreshClasses,
          ),
          if (canManage)
            IconButton(
              icon: Icon(Icons.add_circle_outline_rounded, color: isDark ? AppColors.pureWhite : AppColors.primaryAccent),
              tooltip: 'Add Class',
              onPressed: () => _showAddClassModal(context),
            ),
        ],
      ),
      body: _isLoadingInitial
          ? const LoadingStateWidget(message: 'Initializing academic sessions...')
          : Column(
              children: [
                // Academic Session Header Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryAccent),
                          const SizedBox(width: 8),
                          Text('Academic Session:', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      if (_years.isNotEmpty && _selectedYearId != null)
                        DropdownButton<String>(
                          value: _selectedYearId,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                          items: _years.map((y) {
                            return DropdownMenuItem<String>(
                              value: y.id,
                              child: Text(
                                'Session ${y.name}${y.isCurrent ? ' (Active)' : ''}',
                                style: AppTypography.titleSmall.copyWith(
                                  color: isDark ? AppColors.pureWhite : AppColors.primaryAccent,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null && v != _selectedYearId) {
                              setState(() => _selectedYearId = v);
                              _refreshClasses();
                            }
                          },
                        )
                      else
                        Text('No Academic Sessions Found', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                    ],
                  ),
                ),

                Expanded(
                  child: _classesFuture == null
                      ? const LoadingStateWidget(message: 'Loading school classes...')
                      : FutureBuilder<List<SchoolClassModel>>(
                          future: _classesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const LoadingStateWidget(message: 'Loading school classes...');
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.softCoral),
                                      const SizedBox(height: 12),
                                      Text('Failed to load classes', style: AppTypography.titleMedium),
                                      const SizedBox(height: 6),
                                      Text('${snapshot.error}', textAlign: TextAlign.center, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _refreshClasses,
                                        icon: const Icon(Icons.refresh_rounded),
                                        label: const Text('Try Again'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final classes = snapshot.data ?? [];

                            if (classes.isEmpty) {
                              return EmptyStateWidget(
                                icon: Icons.class_outlined,
                                title: 'No Classes Configured',
                                message: 'No classes have been added for this academic session.',
                                buttonText: canManage ? 'Add Class' : null,
                                onAction: canManage ? () => _showAddClassModal(context) : null,
                              );
                            }

                            return RefreshIndicator(
                              onRefresh: () async => _refreshClasses(),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: classes.length,
                                itemBuilder: (context, idx) {
                                  final cls = classes[idx];

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: BentoCard(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.softLavender.withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Icon(Icons.school_rounded, color: AppColors.softLavender, size: 22),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(cls.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                                                      Text('Display Order: ${cls.displayOrder}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  _buildStatusBadge(cls.status),
                                                  if (canManage) ...[
                                                    const SizedBox(width: 8),
                                                    PopupMenuButton<String>(
                                                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.coolGray),
                                                      onSelected: (action) async {
                                                        if (action == 'delete') {
                                                          _confirmDeleteClass(context, cls);
                                                        }
                                                      },
                                                      itemBuilder: (ctx) => [
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Row(
                                                            children: [
                                                              Icon(Icons.delete_outline_rounded, color: AppColors.softCoral, size: 18),
                                                              SizedBox(width: 8),
                                                              Text('Delete Class', style: TextStyle(color: AppColors.softCoral)),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.midnightNavy.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  '${cls.sectionsCount} Sections Configured',
                                                  style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w800, color: AppColors.midnightNavy),
                                                ),
                                              ),
                                              ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.midnightNavy,
                                                  foregroundColor: AppColors.pureWhite,
                                                ),
                                                onPressed: () async {
                                                  await context.push('/class-sections/${cls.id}', extra: cls);
                                                  _refreshClasses();
                                                },
                                                icon: const Icon(Icons.tune_rounded, size: 16),
                                                label: const Text('Manage Sections'),
                                              ),
                                            ],
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
                ),
              ],
            ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAddClassModal(context),
              backgroundColor: AppColors.midnightNavy,
              foregroundColor: AppColors.pureWhite,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Class'),
            )
          : null,
    );
  }

  void _showAddClassModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text('Add New Class', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Class Name (e.g. Class 9, Grade 10)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: orderCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Display Order'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty && _schoolId != null && _selectedYearId != null) {
                  try {
                    await ref.read(classSectionServiceProvider).createClass(
                      schoolId: _schoolId!,
                      academicYearId: _selectedYearId!,
                      name: nameCtrl.text,
                      displayOrder: int.tryParse(orderCtrl.text) ?? 1,
                    );
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    _refreshClasses();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Class "${nameCtrl.text}" created successfully!')),
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
              child: const Text('Save Class'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteClass(BuildContext context, SchoolClassModel cls) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Delete Class?'),
          content: Text('Are you sure you want to delete "${cls.name}" and all its configured sections?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral, foregroundColor: AppColors.pureWhite),
              onPressed: () async {
                try {
                  await ref.read(classSectionServiceProvider).deleteClass(cls.id);
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _refreshClasses();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Class "${cls.name}" deleted.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.softCoral, content: Text('Error deleting class: $e')),
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

  Widget _buildStatusBadge(AccountStatus status) {
    final isActive = status == AccountStatus.active;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.mutedGreen : AppColors.softCoral).withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: AppTypography.bodySmall.copyWith(
          color: isActive ? AppColors.mutedGreen : AppColors.softCoral,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
