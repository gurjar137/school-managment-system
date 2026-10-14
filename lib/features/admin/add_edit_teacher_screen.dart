import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/class_section_models.dart';
import '../../core/widgets/app_back_button.dart';

class AddEditTeacherScreen extends ConsumerStatefulWidget {
  final TeacherModel? teacherToEdit;
  final StaffMemberModel? staffToEdit;
  final UserRole initialRole;

  const AddEditTeacherScreen({
    super.key,
    this.teacherToEdit,
    this.staffToEdit,
    this.initialRole = UserRole.teacher,
  });

  @override
  ConsumerState<AddEditTeacherScreen> createState() => _AddEditTeacherScreenState();
}

class _AddEditTeacherScreenState extends ConsumerState<AddEditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _empIdController;
  late TextEditingController _subjectController;
  late TextEditingController _designationController;
  late TextEditingController _passwordController;
  late TextEditingController _confirmPasswordController;
  late TextEditingController _classController;
  late TextEditingController _sectionController;

  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  List<SchoolClassModel> _availableClasses = [];

  bool get isEditMode => widget.teacherToEdit != null || widget.staffToEdit != null;

  bool get isTeacherMode {
    if (widget.staffToEdit != null) return widget.staffToEdit!.isTeacher;
    if (widget.teacherToEdit != null) return true;
    return widget.initialRole == UserRole.teacher;
  }

  @override
  void initState() {
    super.initState();
    final t = widget.teacherToEdit;
    final s = widget.staffToEdit;

    _nameController = TextEditingController(text: t?.name ?? s?.name ?? '');
    _emailController = TextEditingController(text: t?.email ?? s?.email ?? '');
    _phoneController = TextEditingController(text: t?.phone ?? s?.phone ?? '');
    _empIdController = TextEditingController(
      text: t?.employeeId ?? s?.employeeId ?? 'EMP-',
    );
    _subjectController = TextEditingController(
      text: t?.subjects.isNotEmpty == true ? t!.subjects.first : (s?.subject ?? (isTeacherMode ? 'Mathematics' : '')),
    );
    _designationController = TextEditingController(
      text: t?.designation ?? s?.designation ?? (isTeacherMode ? 'Faculty Member' : 'Office Staff'),
    );
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _classController = TextEditingController(text: t?.className ?? s?.assignedClass ?? '');
    _sectionController = TextEditingController(text: t?.sectionName ?? s?.assignedSection ?? '');

    if (isTeacherMode) {
      _fetchClassesForSchool();
    }
  }

  Future<void> _fetchClassesForSchool() async {
    try {
      final activeSchoolId = ref.read(authProvider.notifier).activeProfile?.schoolId ?? '';
      if (activeSchoolId.isNotEmpty) {
        final classes = await ref.read(classSectionServiceProvider).fetchClasses(activeSchoolId, '');
        if (mounted) {
          setState(() {
            _availableClasses = classes;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _empIdController.dispose();
    _subjectController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _classController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final activeSchoolId = activeProfile?.schoolId ??
        widget.teacherToEdit?.schoolId ??
        widget.staffToEdit?.schoolId ??
        '';

    if (activeSchoolId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.softCoral,
            content: Text('No active school detected for current administrator. Cannot proceed.'),
          ),
        );
      }
      return;
    }

    final className = _classController.text.trim();
    final sectionName = _sectionController.text.trim();
    final assignedClassStr = (className.isNotEmpty && sectionName.isNotEmpty)
        ? '$className - $sectionName'
        : (className.isNotEmpty ? className : sectionName);

    final recordId = widget.teacherToEdit?.id ?? widget.staffToEdit?.id ?? _empIdController.text.trim();
    final authUserId = widget.teacherToEdit?.authUserId ?? widget.staffToEdit?.authUserId;

    try {
      final teacherService = ref.read(teacherServiceProvider);
      final authService = ref.read(authServiceProvider);

      if (isEditMode) {
        if (isTeacherMode) {
          final updatedTeacher = TeacherModel(
            id: recordId,
            schoolId: activeSchoolId,
            employeeId: _empIdController.text.trim(),
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            subjects: [_subjectController.text.trim()],
            assignedClass: className,
            assignedSection: sectionName,
            totalStudents: widget.teacherToEdit?.totalStudents ?? 0,
            avatarUrl: widget.teacherToEdit?.avatarUrl ?? '',
            phone: _phoneController.text.trim(),
            designation: _designationController.text.trim(),
            authUserId: authUserId,
            status: widget.teacherToEdit?.status ?? widget.staffToEdit?.status ?? AccountStatus.active,
          );
          await teacherService.updateTeacher(updatedTeacher);
        } else {
          await teacherService.updateStaffMember(
            id: recordId,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            designation: _designationController.text.trim(),
          );
        }

        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.mutedGreen,
              content: Text('Details for ${_nameController.text.trim()} updated successfully!'),
            ),
          );
          context.pop(true);
        }
      } else {
        // Create new account
        final targetRole = isTeacherMode ? UserRole.teacher : UserRole.staff;
        final staffProfile = await authService.createStaffAccount(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          empId: _empIdController.text.trim(),
          designation: _designationController.text.trim(),
          subject: isTeacherMode ? _subjectController.text.trim() : '',
          assignedClass: isTeacherMode ? assignedClassStr : '',
          password: _passwordController.text,
          role: targetRole,
        );

        if (isTeacherMode) {
          final newTeacher = TeacherModel(
            id: _empIdController.text.trim(),
            schoolId: activeSchoolId,
            employeeId: _empIdController.text.trim(),
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            subjects: [_subjectController.text.trim()],
            assignedClass: className,
            assignedSection: sectionName,
            totalStudents: 0,
            avatarUrl: '',
            phone: _phoneController.text.trim(),
            designation: _designationController.text.trim(),
            authUserId: staffProfile.authUserId,
            status: AccountStatus.active,
          );
          await teacherService.addTeacher(newTeacher);
        }

        if (mounted) {
          setState(() => _isSaving = false);
          _showCreatedSuccessDialog(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            empId: _empIdController.text.trim(),
            roleName: isTeacherMode ? 'Teacher / Faculty' : 'School Staff',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.softCoral,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _showCreatedSuccessDialog({
    required String name,
    required String email,
    required String empId,
    required String roleName,
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
              Expanded(
                child: Text('Account Provisioned', style: AppTypography.titleLarge),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A secure account has been created for . They will be required to change their password upon first login.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softLavender.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ', style: AppTypography.labelLarge),
                    const SizedBox(height: 4),
                    Text('Email: ', style: AppTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Employee ID: ', style: AppTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Role: ', style: AppTypography.bodyMedium),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.lock_reset_rounded, size: 16, color: AppColors.softLavender),
                        const SizedBox(width: 6),
                        Text(
                          'First Login: Password Change Required',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.softLavender,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy Credentials'),
              onPressed: () {
                final details = 'School Portal Login\nName: \nEmail: \nEmployee ID: \nRole: ';
                Clipboard.setData(ClipboardData(text: details));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Login details copied to clipboard!')),
                );
              },
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop(true);
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = isEditMode
        ? (isTeacherMode ? 'Edit Teacher Details' : 'Edit Staff Details')
        : (isTeacherMode ? 'Create New Teacher' : 'Create Other Staff');

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: AppBackButton(
          fallbackPath: '/teachers',
          onBeforeBack: () async {
            if (!isEditMode && (_nameController.text.isNotEmpty || _emailController.text.isNotEmpty)) {
              return await showDiscardChangesDialog(context);
            }
            return true;
          },
        ),
        title: Text(title, style: AppTypography.titleLarge),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role Indicator Banner (Strictly Locked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isTeacherMode
                      ? AppColors.softLavender.withOpacity(0.15)
                      : AppColors.mutedGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isTeacherMode
                        ? AppColors.softLavender.withOpacity(0.4)
                        : AppColors.mutedGreen.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isTeacherMode ? Icons.school_rounded : Icons.badge_rounded,
                      color: isTeacherMode ? AppColors.softLavender : AppColors.mutedGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isTeacherMode
                            ? 'Role: Teacher / Faculty (Locked)'
                            : 'Role: School Operational Staff (Locked)',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.midnightNavy,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.midnightNavy.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Locked',
                        style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text('PERSONAL INFORMATION', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  hintText: isTeacherMode ? 'e.g. Dr. Rajesh Kumar' : 'e.g. Anita Sharma',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: isEditMode,
                      decoration: InputDecoration(
                        labelText: isEditMode ? 'Email (Immutable)' : 'Email Address *',
                        hintText: 'staff@school.edu',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: isEditMode,
                        fillColor: isEditMode ? AppColors.coolGray.withOpacity(0.08) : null,
                      ),
                      validator: (v) {
                        if (v == null || !v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+91 98765 43210',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Text('PROFESSIONAL DETAILS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _empIdController,
                      decoration: const InputDecoration(
                        labelText: 'Employee ID',
                        hintText: 'EMP-001',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Employee ID required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isTeacherMode
                        ? TextFormField(
                            controller: _subjectController,
                            decoration: const InputDecoration(
                              labelText: 'Primary Subject',
                              hintText: 'e.g. Mathematics, Science',
                              prefixIcon: Icon(Icons.menu_book_rounded),
                            ),
                          )
                        : TextFormField(
                            controller: _designationController,
                            decoration: const InputDecoration(
                              labelText: 'Designation *',
                              hintText: 'e.g. Accountant, Librarian',
                              prefixIcon: Icon(Icons.work_outline_rounded),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Designation is required' : null,
                          ),
                  ),
                ],
              ),
              if (isTeacherMode) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _designationController,
                  decoration: const InputDecoration(
                    labelText: 'Designation',
                    hintText: 'e.g. Senior Faculty, TGT, PRT',
                    prefixIcon: Icon(Icons.work_outline_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Authentication fields (Only when creating new user)
              if (!isEditMode) ...[
                Text('AUTHENTICATION & TEMPORARY ACCESS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded, color: AppColors.softLavender, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Assign an initial temporary password (min 8 chars). The user will be required to change it on their first login.',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.deepSlate),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Initial Password (Min 8 Chars) *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (isEditMode) return null;
                          if (v == null || v.trim().length < 8) return 'Min 8 characters required';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password *',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) {
                          if (isEditMode) return null;
                          if (v == null || v.trim().isEmpty) return 'Confirm password';
                          if (v.trim() != _passwordController.text.trim()) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Teacher Assignment section
              if (isTeacherMode) ...[
                Text('CLASS & SECTION ASSIGNMENT', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                const SizedBox(height: 10),
                if (_availableClasses.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _availableClasses.any((c) => c.name == _classController.text.trim())
                              ? _classController.text.trim()
                              : null,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Class (Optional)',
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Not Assigned / General'),
                            ),
                            ..._availableClasses.map((c) => DropdownMenuItem<String>(
                              value: c.name,
                              child: Text(c.name),
                            )),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _classController.text = val ?? '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sectionController,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Section',
                            hintText: 'e.g. A, B, Rose',
                            prefixIcon: Icon(Icons.grid_view_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _classController,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Class (e.g. 5, 10)',
                            hintText: 'e.g. Class 5',
                            prefixIcon: Icon(Icons.meeting_room_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _sectionController,
                          decoration: const InputDecoration(
                            labelText: 'Assigned Section (e.g. A, B)',
                            hintText: 'e.g. A',
                            prefixIcon: Icon(Icons.grid_view_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: AppColors.pureWhite)
                      : Text(
                          isEditMode
                              ? 'Save Changes'
                              : (isTeacherMode ? 'Register Teacher' : 'Register Staff Member'),
                          style: AppTypography.labelLarge,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
