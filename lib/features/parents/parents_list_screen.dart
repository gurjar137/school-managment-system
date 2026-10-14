import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/parent_model.dart';
import '../../data/models/user_model.dart';

class ParentsListScreen extends ConsumerStatefulWidget {
  const ParentsListScreen({super.key});

  @override
  ConsumerState<ParentsListScreen> createState() => _ParentsListScreenState();
}

class _ParentsListScreenState extends ConsumerState<ParentsListScreen> {
  final _searchCtrl = TextEditingController();
  AccountStatus? _selectedStatus;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parentService = ref.watch(parentServiceProvider);
    final user = ref.watch(authProvider);
    final canManage = user?.role.isAdministrator ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/home'),
        title: Text('Parent Registry & Access Keys', style: AppTypography.titleLarge),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.softLavender),
              tooltip: 'Add Parent',
              onPressed: () => _showAddParentModal(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by Parent, Student Name, Adm No, Phone, Parent ID...',
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildFilterChip('All Statuses', _selectedStatus == null, () {
                      setState(() => _selectedStatus = null);
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active', _selectedStatus == AccountStatus.active, () {
                      setState(() => _selectedStatus = AccountStatus.active);
                    }),
                    const SizedBox(width: 8),
                    _buildFilterChip('Inactive', _selectedStatus == AccountStatus.inactive, () {
                      setState(() => _selectedStatus = AccountStatus.inactive);
                    }),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<ParentModel>>(
              future: parentService.fetchParents(
                query: _searchCtrl.text,
                status: _selectedStatus,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading parent registry...');
                }

                final parents = snapshot.data ?? [];

                if (parents.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.family_restroom_rounded,
                    title: 'No Parents Found',
                    message: 'No parent records match your query.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: parents.length,
                  itemBuilder: (context, idx) {
                    final parent = parents[idx];
                    final isActive = parent.status == AccountStatus.active;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      AppAvatar(
                                        imageUrl: parent.profilePhotoUrl ?? '',
                                        name: parent.name,
                                        radius: 20,
                                        borderColor: AppColors.softLavender,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(parent.name, style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                                            Row(
                                              children: [
                                                Text(parent.phone, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                                if (parent.email != null && parent.email!.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Text('• ${parent.email!}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isActive ? AppColors.mutedGreen.withValues(alpha: 0.15) : AppColors.warmAmber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isActive ? 'ACTIVE' : 'INACTIVE',
                                        style: AppTypography.labelSmall.copyWith(
                                          color: isActive ? AppColors.mutedGreen : AppColors.warmAmber,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.softLavender.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            parent.parentCode,
                                            style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: parent.parentCode));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(backgroundColor: AppColors.midnightNavy, content: Text('Copied Parent ID "${parent.parentCode}"')),
                                              );
                                            },
                                            child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.softLavender),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),

                            // Linked Students Info
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.school_outlined, size: 16, color: AppColors.coolGray),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: parent.linkedStudents.isNotEmpty
                                      ? Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: parent.linkedStudents.map((child) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.midnightNavy.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${child.studentName} (${child.studentClass} • ${child.admissionNumber})',
                                                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.midnightNavy),
                                              ),
                                            );
                                          }).toList(),
                                        )
                                      : Text(
                                          'No linked students (${parent.linkedStudentsCount} registered)',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                                        ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (canManage) ...[
                                  if (!isActive)
                                    TextButton.icon(
                                      style: TextButton.styleFrom(foregroundColor: AppColors.mutedGreen),
                                      onPressed: () async {
                                        await parentService.toggleParentStatus(
                                          parent.id,
                                          schoolId: parent.schoolId,
                                          newStatus: AccountStatus.active,
                                        );
                                        setState(() {});
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Access ENABLED for ${parent.name}')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                                      label: const Text('Enable'),
                                    )
                                  else
                                    TextButton.icon(
                                      style: TextButton.styleFrom(foregroundColor: AppColors.softCoral),
                                      onPressed: () async {
                                        await parentService.toggleParentStatus(
                                          parent.id,
                                          schoolId: parent.schoolId,
                                          newStatus: AccountStatus.inactive,
                                        );
                                        setState(() {});
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(backgroundColor: AppColors.softCoral, content: Text('Access DISABLED for ${parent.name}')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.block_rounded, size: 16),
                                      label: const Text('Disable'),
                                    ),
                                  const SizedBox(width: 8),
                                ],
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.midnightNavy,
                                    foregroundColor: AppColors.pureWhite,
                                  ),
                                  onPressed: () => context.push('/parents/${parent.id}', extra: parent),
                                  icon: const Icon(Icons.visibility_rounded, size: 16),
                                  label: const Text('View'),
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
              onPressed: () => _showAddParentModal(context),
              backgroundColor: AppColors.midnightNavy,
              foregroundColor: AppColors.pureWhite,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Parent'),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.midnightNavy : AppColors.coolGray.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isSelected ? AppColors.pureWhite : AppColors.coolGrayDark,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddParentModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Register New Parent', style: AppTypography.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Parent Full Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Phone Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email Address (Optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Residential Address'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
                  try {
                    final user = ref.read(authProvider);
                    final schoolId = user?.schoolId ?? '';
                    final newParent = await ref.read(parentServiceProvider).createParent(
                      schoolId: schoolId,
                      name: nameCtrl.text,
                      phone: phoneCtrl.text,
                      email: emailCtrl.text,
                      address: addressCtrl.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      setState(() {});
                      _showParentCreatedDialog(context, newParent);
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
              child: const Text('Save & Generate Parent ID'),
            ),
          ],
        );
      },
    );
  }

  void _showParentCreatedDialog(BuildContext context, ParentModel parent) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.mutedGreen, size: 24),
              const SizedBox(width: 8),
              Text('Parent ID Generated', style: AppTypography.titleMedium),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Parent account created for ${parent.name}.', style: AppTypography.bodyMedium),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.softLavender.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.softLavender.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Text('UNIQUE PARENT APP LOGIN ID', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                    const SizedBox(height: 6),
                    SelectableText(
                      parent.parentCode,
                      style: AppTypography.displayMedium.copyWith(fontSize: 22, color: AppColors.softLavender, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.midnightNavy, foregroundColor: AppColors.pureWhite),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: parent.parentCode));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Copied Parent ID "${parent.parentCode}" to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy Parent ID'),
            ),
          ],
        );
      },
    );
  }
}
