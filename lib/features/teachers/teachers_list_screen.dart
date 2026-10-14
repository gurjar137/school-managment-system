import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';

class TeachersListScreen extends ConsumerStatefulWidget {
  const TeachersListScreen({super.key});

  @override
  ConsumerState<TeachersListScreen> createState() => _TeachersListScreenState();
}

class _TeachersListScreenState extends ConsumerState<TeachersListScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teacherService = ref.watch(teacherServiceProvider);
    final user = ref.watch(authProvider);
    final canManage = user?.role.isAdministrator ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Faculty & Teachers Directory', style: AppTypography.titleLarge),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.softLavender),
              tooltip: 'Add Teacher',
              onPressed: () async {
                final res = await context.push('/add-teacher');
                if (res == true && mounted) setState(() {});
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Header
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by Teacher Name, Employee ID (EMP-0042)...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<TeacherModel>>(
              future: teacherService.getTeachers(
                schoolId: user?.schoolId,
                query: _searchCtrl.text,
                includeStaff: true,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading faculty directory...');
                }

                final teachers = snapshot.data ?? [];

                if (teachers.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.person_off_rounded,
                    title: 'No Faculty Records Found',
                    message: 'No teachers match your search query.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: teachers.length,
                  itemBuilder: (context, index) {
                    final t = teachers[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BentoCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                AppAvatar(imageUrl: t.avatarUrl, name: t.name, radius: 24, borderColor: AppColors.softLavender),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(t.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.softLavender.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              t.employeeId,
                                              style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800, fontSize: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(t.designation, style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text('Subjects: ${t.subjects.join(", ")}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                      Text('Assigned Class: ${t.assignedClass}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.midnightNavy,
                                    foregroundColor: AppColors.pureWhite,
                                  ),
                                  onPressed: () => context.push('/teacher-assignments/${t.id}', extra: t),
                                  icon: const Icon(Icons.assignment_ind_rounded, size: 16),
                                  label: const Text('Manage Assignments'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () async {
                final res = await context.push('/add-teacher');
                if (res == true && mounted) setState(() {});
              },
              backgroundColor: AppColors.midnightNavy,
              foregroundColor: AppColors.pureWhite,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Teacher'),
            )
          : null,
    );
  }
}
