import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';

class ClassStudentsScreen extends ConsumerStatefulWidget {
  final String? classId;
  final String className;

  const ClassStudentsScreen({
    super.key,
    this.classId,
    required this.className,
  });

  @override
  ConsumerState<ClassStudentsScreen> createState() => _ClassStudentsScreenState();
}

class _ClassStudentsScreenState extends ConsumerState<ClassStudentsScreen> {
  String _searchQuery = '';
  List<StudentModel> _students = [];
  bool _isLoading = true;
  int _totalClassCount = 0;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final repo = ref.read(schoolRepositoryProvider);

    try {
      final classStudents = await repo.getStudents(
        query: _searchQuery,
        className: widget.className,
      );
      final exactTotal = await repo.getStudentCount(
        className: widget.className,
        status: AccountStatus.active,
      );

      if (mounted) {
        setState(() {
          _students = classStudents;
          _totalClassCount = exactTotal;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchQuery = val;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _loadStudents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/classes'),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.className} Students', style: AppTypography.titleLarge),
            Text('Academic Year 2026-2027', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add Student to ${widget.className}',
            onPressed: () async {
              final result = await context.push(
                '/add-student',
                extra: {
                  'className': widget.className,
                },
              );
              if (result == true) {
                _loadStudents();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: CustomSearchBar(
              hintText: 'Search students in ${widget.className}...',
              onChanged: _onSearchChanged,
            ),
          ),

          // Count Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _searchQuery.trim().isNotEmpty
                      ? '${_students.length} Students Found'
                      : '${_totalClassCount > 0 ? _totalClassCount : _students.length} Students in ${widget.className}',
                  style: AppTypography.labelMedium.copyWith(color: AppColors.coolGray, fontWeight: FontWeight.w700),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.softLavender,
                    foregroundColor: AppColors.pureWhite,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Student'),
                  onPressed: () async {
                    final result = await context.push(
                      '/add-student',
                      extra: {
                        'className': widget.className,
                      },
                    );
                    if (result == true) {
                      _loadStudents();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),

          // Students List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadStudents(),
              child: _isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 4,
                      itemBuilder: (context, index) => const StudentCardSkeleton(),
                    )
                  : _students.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            EmptyStateWidget(
                              icon: Icons.school_outlined,
                              title: 'No Students in ${widget.className}',
                              message: 'Tap "+ Add Student" to register the first student for ${widget.className}.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            return _buildStudentTile(context, student);
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push(
            '/add-student',
            extra: {
              'className': widget.className,
            },
          );
          if (result == true) {
            _loadStudents();
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: Text('Add Student to ${widget.className}'),
      ),
    );
  }

  Widget _buildStudentTile(BuildContext context, StudentModel student) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BentoCard(
        onTap: () => context.push('/student/${student.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                AppAvatar(
                  imageUrl: student.avatarUrl,
                  name: student.name,
                  radius: 22,
                  borderColor: AppColors.softLavender,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            student.name,
                            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          if (student.section.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.midnightNavy.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Sec ${student.section}',
                                style: AppTypography.labelSmall.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Roll: ${student.rollNumber.isNotEmpty ? student.rollNumber : "N/A"} • Adm: ${student.admissionNumber}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.coolGray, size: 20),
              ],
            ),
            if (student.fatherName.isNotEmpty || student.fatherMobile.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Parent: ${student.fatherName}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                  ),
                  if (student.fatherMobile.isNotEmpty)
                    Text(
                      student.fatherMobile,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mutedGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
