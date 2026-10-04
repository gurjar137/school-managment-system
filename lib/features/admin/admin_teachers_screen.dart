import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/user_model.dart';

class AdminTeachersScreen extends ConsumerStatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  ConsumerState<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends ConsumerState<AdminTeachersScreen> {
  Key _refreshKey = UniqueKey();

  void _refresh() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(schoolRepositoryProvider);
    final activeSchoolId = ref.watch(authProvider.notifier).activeProfile?.schoolId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Staff & Faculty Directory', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.softLavender),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.softLavender),
            tooltip: 'Add Teacher',
            onPressed: () async {
              final res = await context.push('/add-teacher');
              if (res == true && mounted) _refresh();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<TeacherModel>>(
        key: _refreshKey,
        future: repo.getTeachers(schoolId: activeSchoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Loading faculty directory...');
          }
          final teachers = snapshot.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.softLavender.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_outlined, color: AppColors.softLavender, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${teachers.length} Faculty Member${teachers.length == 1 ? '' : 's'} Registered',
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.midnightNavy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'All registered teachers with their assigned class and section. Tap Edit to change class assignments.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.coolGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (teachers.isEmpty)
                const EmptyStateWidget(
                  icon: Icons.person_off_rounded,
                  title: 'No Faculty Records Found',
                  message: 'No teachers registered in this school yet. Tap "+ Add Teacher" to create one.',
                ),

              ...teachers.map((teacher) {
                final hasClass = teacher.className.isNotEmpty;
                final hasSection = teacher.sectionName.isNotEmpty;
                final classLabel = hasClass ? 'Class: ${teacher.className}' : 'Class: Not Assigned';
                final sectionLabel = hasSection ? 'Section: ${teacher.sectionName}' : 'Section: Not Assigned';
                final isActive = teacher.status == AccountStatus.active;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BentoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Assignment & Status Badges
                        Row(
                          children: [
                            // Class badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasClass ? AppColors.midnightNavy : AppColors.coolGray.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                classLabel,
                                style: AppTypography.labelSmall.copyWith(
                                  color: hasClass ? AppColors.pureWhite : AppColors.coolGray,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Section badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: hasSection ? AppColors.softLavender.withOpacity(0.2) : AppColors.coolGray.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                sectionLabel,
                                style: AppTypography.labelSmall.copyWith(
                                  color: hasSection ? AppColors.midnightNavy : AppColors.coolGray,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.greenLight : AppColors.softCoral.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'ACTIVE' : 'INACTIVE',
                                style: AppTypography.labelSmall.copyWith(
                                  color: isActive ? AppColors.greenDark : AppColors.softCoral,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Teacher Details
                        Row(
                          children: [
                            AppAvatar(
                              imageUrl: teacher.avatarUrl,
                              name: teacher.name,
                              radius: 24,
                              borderColor: AppColors.softLavender,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacher.name.toUpperCase(),
                                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    teacher.designation.isNotEmpty ? teacher.designation : 'Faculty Member',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.softLavender,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (teacher.email.isNotEmpty)
                                    Text(
                                      teacher.email,
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                    ),
                                  if (teacher.phone.isNotEmpty)
                                    Text(
                                      'Phone: ${teacher.phone}',
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.midnightNavy, size: 22),
                              tooltip: 'Edit Teacher & Assignment',
                              onPressed: () async {
                                final res = await context.push('/edit-teacher', extra: teacher);
                                if (res == true && mounted) _refresh();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final res = await context.push('/edit-teacher', extra: teacher);
                                  if (res == true && mounted) _refresh();
                                },
                                icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                                label: const Text('Edit Assignment'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => context.go('/students'),
                                icon: const Icon(Icons.people_alt_outlined, size: 16),
                                label: const Text('View Roster'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await context.push('/add-teacher');
          if (res == true && mounted) _refresh();
        },
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('+ Add Teacher'),
      ),
    );
  }
}
