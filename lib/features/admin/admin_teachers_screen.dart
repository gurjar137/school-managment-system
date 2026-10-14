import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
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
  String _selectedFilter = 'all'; // 'all', 'teachers', 'staff'
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  void _refresh() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(schoolRepositoryProvider);
    final activeSchoolId = ref.watch(authProvider.notifier).activeProfile?.schoolId ?? ref.watch(authProvider)?.schoolId ?? '6254bee9-151d-4332-8a1c-3994af7d2153';

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text('Staff & Faculty Directory', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.softLavender),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.softLavender),
            tooltip: 'Add Teacher or Staff',
            onPressed: () async {
              final res = await context.push('/add-teacher');
              if (res == true && mounted) _refresh();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<TeacherModel>>(
        key: _refreshKey,
        future: repo.getTeachers(schoolId: activeSchoolId, includeStaff: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingStateWidget(message: 'Loading staff & faculty directory...');
          }

          if (snapshot.hasError) {
            return EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Failed to Load Staff Directory',
              message: '${snapshot.error}',
              buttonText: 'Retry',
              onAction: _refresh,
            );
          }

          final allStaff = snapshot.data ?? [];
          final teachersCount = allStaff.where((s) => s.isTeacher).length;
          final adminStaffCount = allStaff.where((s) => !s.isTeacher).length;

          // Apply tab filter
          List<TeacherModel> filtered = allStaff;
          if (_selectedFilter == 'teachers') {
            filtered = filtered.where((s) => s.isTeacher).toList();
          } else if (_selectedFilter == 'staff') {
            filtered = filtered.where((s) => !s.isTeacher).toList();
          }

          // Apply text search
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.trim().toLowerCase();
            filtered = filtered.where((s) {
              return s.name.toLowerCase().contains(q) ||
                  s.email.toLowerCase().contains(q) ||
                  s.employeeId.toLowerCase().contains(q) ||
                  s.designation.toLowerCase().contains(q) ||
                  s.className.toLowerCase().contains(q) ||
                  s.roleDisplayName.toLowerCase().contains(q);
            }).toList();
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: AppColors.midnightNavy, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${allStaff.length} Total Personnel Registered',
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.midnightNavy,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$teachersCount Teaching Faculty • $adminStaffCount Administrative & Support Staff',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.coolGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Search Bar
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, employee ID, role, or class...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.softLavender.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.softLavender.withOpacity(0.3)),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All Personnel (${allStaff.length})'),
                      const SizedBox(width: 8),
                      _buildFilterChip('teachers', 'Teachers ($teachersCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('staff', 'Staff & Admin ($adminStaffCount)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.person_off_rounded,
                    title: _searchQuery.isNotEmpty ? 'No Matching Personnel Found' : 'No Staff Records Found',
                    message: _searchQuery.isNotEmpty
                        ? 'No personnel match "$_searchQuery". Try a different search term.'
                        : 'No staff or faculty registered in this school yet. Tap "+ Add Staff" to create one.',
                  ),

                ...filtered.map((person) => _buildPersonCard(context, person)),
              ],
            ),
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
        label: const Text('+ Add Staff / Teacher'),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: AppColors.midnightNavy,
      backgroundColor: AppColors.softLavender.withOpacity(0.12),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.pureWhite : AppColors.midnightNavy,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildPersonCard(BuildContext context, TeacherModel person) {
    final hasClass = person.className.isNotEmpty;
    final hasSection = person.sectionName.isNotEmpty;
    final isActive = person.status == AccountStatus.active;
    final isTeacher = person.isTeacher;
    final isAdmin = person.isAdministrator;

    Color roleBg;
    Color roleFg;
    String roleText;
    IconData roleIcon;

    if (isAdmin) {
      roleBg = AppColors.midnightNavy;
      roleFg = AppColors.pureWhite;
      roleText = 'ADMINISTRATOR';
      roleIcon = Icons.admin_panel_settings_rounded;
    } else if (person.isStaff) {
      roleBg = const Color(0xFF0D9488); // Teal
      roleFg = AppColors.pureWhite;
      roleText = 'STAFF';
      roleIcon = Icons.badge_rounded;
    } else {
      roleBg = AppColors.softLavender;
      roleFg = AppColors.midnightNavy;
      roleText = 'TEACHER';
      roleIcon = Icons.school_rounded;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BentoCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badges Row: Role, Class/Assignment, and Account Status
            Row(
              children: [
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: roleBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(roleIcon, size: 13, color: roleFg),
                      const SizedBox(width: 4),
                      Text(
                        roleText,
                        style: AppTypography.labelSmall.copyWith(
                          color: roleFg,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Assignment Badges (For teachers: Class & Section; For staff/admins: Designation)
                if (isTeacher) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasClass ? AppColors.softLavender.withOpacity(0.2) : AppColors.coolGray.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasClass ? 'Class: ${person.className}' : 'Class: Not Assigned',
                      style: AppTypography.labelSmall.copyWith(
                        color: hasClass ? AppColors.midnightNavy : AppColors.coolGray,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (hasSection)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.softLavender.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Sec: ${person.sectionName}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.midnightNavy,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.softLavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      person.designation.isNotEmpty ? person.designation : 'Campus Staff',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.midnightNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],

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
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Profile Info: Avatar, Name, Designation, Email, Employee ID
            Row(
              children: [
                AppAvatar(
                  imageUrl: person.avatarUrl,
                  name: person.name,
                  radius: 24,
                  borderColor: roleBg,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              person.name.toUpperCase(),
                              style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.coolGray.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              person.employeeId,
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.coolGray,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        person.designation.isNotEmpty ? person.designation : person.roleDisplayName,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.softLavender,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (person.email.isNotEmpty)
                        Text(
                          person.email,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (person.phone.isNotEmpty)
                        Text(
                          'Phone: ${person.phone}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.midnightNavy, size: 22),
                  tooltip: 'Edit Details',
                  onPressed: () async {
                    final res = await context.push('/edit-teacher', extra: person);
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
                      final res = await context.push('/edit-teacher', extra: person);
                      if (res == true && mounted) _refresh();
                    },
                    icon: Icon(isTeacher ? Icons.assignment_ind_outlined : Icons.edit_note_outlined, size: 16),
                    label: Text(isTeacher ? 'Edit Assignment' : 'Edit Profile'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isTeacher
                        ? () => context.go('/students')
                        : () => context.push('/teacher-access'),
                    icon: Icon(isTeacher ? Icons.people_alt_outlined : Icons.security_rounded, size: 16),
                    label: Text(isTeacher ? 'View Roster' : 'Access Control'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
