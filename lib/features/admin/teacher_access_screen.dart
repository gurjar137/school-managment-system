import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/access_models.dart';
import '../../data/models/user_model.dart';

class TeacherAccessScreen extends ConsumerStatefulWidget {
  const TeacherAccessScreen({super.key});

  @override
  ConsumerState<TeacherAccessScreen> createState() => _TeacherAccessScreenState();
}

class _TeacherAccessScreenState extends ConsumerState<TeacherAccessScreen> {
  @override
  Widget build(BuildContext context) {
    final accessService = ref.watch(accessServiceProvider);
    final activeSchoolId = ref.watch(authProvider.notifier).activeProfile?.schoolId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/teachers'),
        title: Text('Teacher Login Permissions', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.softLavender),
            tooltip: 'Add Teacher Access',
            onPressed: () => _showAddEditAccessDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Info
          BentoCard(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TEACHER ACCESS CONTROL', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    const Icon(Icons.security_rounded, color: AppColors.softLavender, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Manage Authorized Teacher Accounts', style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Only authorized teacher email addresses will be permitted to access the School App.', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const SectionHeader(title: 'Authorized Teacher Accounts'),
          const SizedBox(height: 10),

          FutureBuilder<List<TeacherAccessModel>>(
            future: accessService.getTeacherAccessAccounts(schoolId: activeSchoolId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading authorized accounts...');
              }
              final accounts = snapshot.data ?? [];

              return Column(
                children: accounts.map((acc) {
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(acc.teacherName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                    Text(acc.email, style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              _buildStatusBadge(acc.isEnabled),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${acc.employeeId} • ${acc.assignedClass}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                              Text('Subject: ${acc.subject}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Switch(
                                    value: acc.isEnabled,
                                    activeThumbColor: AppColors.softLavender,
                                    onChanged: (val) => _confirmToggleAccess(context, acc, val),
                                  ),
                                  Text(acc.isEnabled ? 'Access Enabled' : 'Access Revoked', style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('Edit'),
                                onPressed: () => _showAddEditAccessDialog(context, recordToEdit: acc),
                              ),
                            ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditAccessDialog(context),
        backgroundColor: AppColors.midnightNavy,
        foregroundColor: AppColors.pureWhite,
        icon: const Icon(Icons.add_rounded),
        label: const Text('+ Add Teacher Access'),
      ),
    );
  }

  void _confirmToggleAccess(BuildContext context, TeacherAccessModel acc, bool enable) {
    if (enable) {
      ref.read(accessServiceProvider).toggleTeacherAccessStatus(acc.id, true);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Access ENABLED for ${acc.teacherName}')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Disable Access for ${acc.teacherName}?', style: AppTypography.titleLarge),
          content: Text(
            'Disabling access will prevent ${acc.email} from logging in. Existing teacher permissions will be revoked.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(accessServiceProvider).toggleTeacherAccessStatus(acc.id, false);
                setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Access DISABLED for ${acc.teacherName}')),
                  );
                }
              },
              child: const Text('Disable Access'),
            ),
          ],
        );
      },
    );
  }

  void _showAddEditAccessDialog(BuildContext context, {TeacherAccessModel? recordToEdit}) {
    final isEditing = recordToEdit != null;

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: recordToEdit?.teacherName ?? '');
    final emailCtrl = TextEditingController(text: recordToEdit?.email ?? '');
    final empCtrl = TextEditingController(text: recordToEdit?.employeeId ?? 'EMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final classCtrl = TextEditingController(text: recordToEdit?.assignedClass ?? 'Class 8-A');
    final subjectCtrl = TextEditingController(text: recordToEdit?.subject ?? 'Mathematics');
    final designationCtrl = TextEditingController(text: 'Senior Faculty');
    final passwordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    bool obscurePassword = true;
    bool obscureConfirmPassword = true;
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Teacher Access' : 'Add Authorized Teacher Access',
                style: AppTypography.titleLarge,
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.softCoral.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dialogError!,
                            style: AppTypography.bodySmall.copyWith(color: AppColors.softCoral, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Teacher Full Name', hintText: 'Enter teacher full name'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Full Name required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Teacher Email', hintText: 'teacher@school.com'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Email Address required' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: empCtrl,
                              decoration: const InputDecoration(labelText: 'Employee ID', hintText: 'EMP-001'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Employee ID required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: subjectCtrl,
                              decoration: const InputDecoration(labelText: 'Primary Subject', hintText: 'Mathematics'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Subject required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: classCtrl,
                              decoration: const InputDecoration(labelText: 'Assigned Class', hintText: 'Class 8-A'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Assigned Class required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: designationCtrl,
                              decoration: const InputDecoration(labelText: 'Designation', hintText: 'Senior Faculty'),
                            ),
                          ),
                        ],
                      ),

                      if (!isEditing) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'ACCOUNT CREDENTIALS',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Set a temporary password for this teacher. They can change it after their first login.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: passwordCtrl,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Initial Password',
                            hintText: 'Min 8 characters',
                            suffixIcon: IconButton(
                              icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                            ),
                          ),
                          validator: (v) {
                            if (isEditing) return null;
                            if (v == null || v.length < 8) return 'Password must be at least 8 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: confirmPasswordCtrl,
                          obscureText: obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                              onPressed: () => setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword),
                            ),
                          ),
                          validator: (v) {
                            if (isEditing) return null;
                            if (v == null || v.isEmpty) return 'Confirm Password required';
                            if (v != passwordCtrl.text) return 'Passwords do not match.';
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          if (!isEditing) {
                            if (passwordCtrl.text != confirmPasswordCtrl.text) {
                              setDialogState(() => dialogError = 'Passwords do not match.');
                              return;
                            }
                            if (passwordCtrl.text.length < 8) {
                              setDialogState(() => dialogError = 'Password must be at least 8 characters.');
                              return;
                            }
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            dialogError = null;
                          });

                          try {
                            if (recordToEdit != null) {
                              final updated = recordToEdit.copyWith(
                                teacherName: nameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                employeeId: empCtrl.text.trim(),
                                assignedClass: classCtrl.text.trim(),
                                subject: subjectCtrl.text.trim(),
                              );
                              await ref.read(accessServiceProvider).updateTeacherAccess(updated);
                            } else {
                              // Create Supabase Auth Account & Profile
                              await ref.read(authServiceProvider).createStaffAccount(
                                name: nameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                phone: '+91 98765 00000',
                                empId: empCtrl.text.trim(),
                                designation: designationCtrl.text.trim(),
                                subject: subjectCtrl.text.trim(),
                                assignedClass: classCtrl.text.trim(),
                                password: passwordCtrl.text,
                                role: UserRole.teacher,
                              );

                              final newAcc = TeacherAccessModel(
                                id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
                                teacherId: 'tch_${DateTime.now().millisecondsSinceEpoch}',
                                teacherName: nameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                employeeId: empCtrl.text.trim(),
                                assignedClass: classCtrl.text.trim(),
                                subject: subjectCtrl.text.trim(),
                                isEnabled: true,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              await ref.read(accessServiceProvider).addTeacherAccess(newAcc);
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              setState(() {});

                              if (!isEditing) {
                                _showTeacherCreatedSuccessModal(
                                  name: nameCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  empId: empCtrl.text.trim(),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.mutedGreen,
                                    content: Text('Teacher access updated!'),
                                  ),
                                );
                              }
                            }
                          } catch (err) {
                            if (ctx.mounted) {
                              setDialogState(() {
                                isSubmitting = false;
                                dialogError = err.toString().replaceAll('Exception: ', '');
                              });
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pureWhite))
                      : Text(isEditing ? 'Save Changes' : 'Authorize & Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTeacherCreatedSuccessModal({
    required String name,
    required String email,
    required String empId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.mutedGreen, size: 28),
              const SizedBox(width: 10),
              Text('Teacher Account Created', style: AppTypography.titleLarge),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Teacher account successfully generated in Supabase Auth & Linked Profile.', style: AppTypography.bodyMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.deepSlate.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Teacher Name: $name', style: AppTypography.labelLarge),
                    const SizedBox(height: 4),
                    Text('Email: $email', style: AppTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Employee ID: $empId', style: AppTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Role: Teacher', style: AppTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Notice: Temporary password has been set.', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy Login Details'),
              onPressed: () {
                final details = 'Teacher Login\nName: $name\nEmail: $email\nEmployee ID: $empId';
                Clipboard.setData(ClipboardData(text: details));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Teacher login details copied to clipboard!')),
                );
              },
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isEnabled ? AppColors.mutedGreen.withOpacity(0.15) : AppColors.softCoral.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isEnabled ? AppColors.mutedGreen : AppColors.softCoral),
          ),
          const SizedBox(width: 4),
          Text(
            isEnabled ? 'Active' : 'Disabled',
            style: AppTypography.bodySmall.copyWith(color: isEnabled ? AppColors.mutedGreen : AppColors.softCoral, fontWeight: FontWeight.w800, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
