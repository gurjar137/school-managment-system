import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/user_model.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final activeSchoolId = ref.watch(authProvider.notifier).activeProfile?.schoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Administrators', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.softLavender),
            onPressed: () => _showAddAdminModal(context),
          ),
        ],
      ),
      body: activeSchoolId.isEmpty
          ? const EmptyStateWidget(
              title: 'No School Selected',
              message: 'Please log in with an active school account to manage administrators.',
              icon: Icons.admin_panel_settings_outlined,
            )
          : FutureBuilder<List<UserProfileModel>>(
              future: authService.getAdminsForSchool(activeSchoolId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading administrator credentials...');
                }
                final admins = snapshot.data ?? [];
                if (admins.isEmpty) {
                  return const EmptyStateWidget(
                    title: 'No Administrators Found',
                    message: 'No administrative accounts found for this school.',
                    icon: Icons.admin_panel_settings_outlined,
                  );
                }

                return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: admins.length,
            itemBuilder: (context, idx) {
              final admin = admins[idx];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BentoCard(
                  child: Row(
                    children: [
                      AppAvatar(imageUrl: admin.avatarUrl ?? '', name: admin.name, radius: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(admin.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                _buildRoleBadge(admin.role),
                              ],
                            ),
                            Text('${admin.designation} • ${admin.email}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('Status: ', style: AppTypography.bodySmall.copyWith(fontSize: 11)),
                                Text(
                                  admin.status.displayName,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: admin.status == AccountStatus.active ? AppColors.mutedGreen : AppColors.softCoral,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          admin.status == AccountStatus.active ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                          color: admin.status == AccountStatus.active ? AppColors.mutedGreen : AppColors.coolGray,
                          size: 32,
                        ),
                        onPressed: () async {
                          final nextStatus = admin.status == AccountStatus.active ? AccountStatus.inactive : AccountStatus.active;
                          await authService.toggleAdminStatus(admin.id, nextStatus);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAdminModal(context),
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Administrator'),
      ),
    );
  }

  void _showAddAdminModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final designationCtrl = TextEditingController(text: 'School Administrator');
    UserRole selectedRole = UserRole.schoolAdmin;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add School Administrator', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Admin Name')),
              const SizedBox(height: 10),
              TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
              const SizedBox(height: 10),
              TextFormField(controller: designationCtrl, decoration: const InputDecoration(labelText: 'Designation')),
              const SizedBox(height: 10),
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Admin Role'),
                items: [
                  DropdownMenuItem(value: UserRole.schoolAdmin, child: Text(UserRole.schoolAdmin.displayName)),
                  DropdownMenuItem(value: UserRole.superAdmin, child: Text(UserRole.superAdmin.displayName)),
                ],
                onChanged: (v) => selectedRole = v!,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                  final schoolId = ref.read(authProvider.notifier).activeProfile?.schoolId ?? '';
                  final schoolName = ref.read(authProvider)?.schoolName ?? '';
                  if (schoolId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot provision account: No active school session.')),
                    );
                    return;
                  }
                  await ref.read(authServiceProvider).createAdminAccount(
                    schoolId: schoolId,
                    schoolName: schoolName,
                    name: nameCtrl.text,
                    email: emailCtrl.text,
                    designation: designationCtrl.text,
                    role: selectedRole,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Admin account created for ${nameCtrl.text}')),
                    );
                  }
                }
              },
              child: const Text('Provision Account'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color bg = AppColors.softLavender.withOpacity(0.15);
    Color fg = AppColors.softLavender;

    if (role == UserRole.owner) {
      bg = AppColors.warmAmber.withOpacity(0.15);
      fg = AppColors.warmAmber;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(role.displayName.toUpperCase(), style: AppTypography.labelSmall.copyWith(color: fg, fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }
}
