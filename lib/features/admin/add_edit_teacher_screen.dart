import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/staff_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/class_section_models.dart';
import '../../data/models/salary_models.dart';
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
  late TextEditingController _baseSalaryController;
  late TextEditingController _hraController;
  late TextEditingController _transportController;
  late TextEditingController _pfController;
  late TextEditingController _taxController;

  String _salaryType = 'Monthly';
  String _paymentSchedule = 'Monthly';
  DateTime _effectiveDate = DateTime.now();
  bool _isSalaryActive = true;

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

    _baseSalaryController = TextEditingController();
    _hraController = TextEditingController();
    _transportController = TextEditingController();
    _pfController = TextEditingController();
    _taxController = TextEditingController();

    if (isTeacherMode) {
      _fetchClassesForSchool();
    }

    final editStaffId = widget.teacherToEdit?.id ?? widget.staffToEdit?.id;
    if (editStaffId != null && editStaffId.isNotEmpty) {
      _loadExistingSalary(editStaffId);
    }
  }

  Future<void> _loadExistingSalary(String staffId) async {
    try {
      final struct = await ref.read(salaryServiceProvider).getSalaryStructure(staffId);
      if (struct != null && mounted) {
        setState(() {
          _baseSalaryController.text = struct.basicSalary > 0 ? struct.basicSalary.toStringAsFixed(0) : '';
          final hra = struct.allowances.firstWhere((a) => a.type == 'HRA', orElse: () => const SalaryAllowance(type: 'HRA', amount: 0.0)).amount;
          if (hra > 0) _hraController.text = hra.toStringAsFixed(0);
          final transport = struct.allowances.firstWhere((a) => a.type == 'Transport', orElse: () => const SalaryAllowance(type: 'Transport', amount: 0.0)).amount;
          if (transport > 0) _transportController.text = transport.toStringAsFixed(0);
          final pf = struct.deductions.firstWhere((d) => d.type == 'PF', orElse: () => const SalaryDeduction(type: 'PF', amount: 0.0)).amount;
          if (pf > 0) _pfController.text = pf.toStringAsFixed(0);
          final tax = struct.deductions.firstWhere((d) => d.type == 'Tax', orElse: () => const SalaryDeduction(type: 'Tax', amount: 0.0)).amount;
          if (tax > 0) _taxController.text = tax.toStringAsFixed(0);
          _salaryType = struct.salaryType;
          _paymentSchedule = struct.paymentSchedule;
          _effectiveDate = struct.effectiveFrom;
          _isSalaryActive = struct.isActive;
        });
      }
    } catch (_) {}
  }

  double _calculateNet() {
    final base = double.tryParse(_baseSalaryController.text.trim()) ?? 0.0;
    final hra = double.tryParse(_hraController.text.trim()) ?? 0.0;
    final transport = double.tryParse(_transportController.text.trim()) ?? 0.0;
    final pf = double.tryParse(_pfController.text.trim()) ?? 0.0;
    final tax = double.tryParse(_taxController.text.trim()) ?? 0.0;
    final net = base + hra + transport - pf - tax;
    return net > 0 ? net : 0.0;
  }

  Future<void> _saveSalaryStructureIfConfigured({
    required String schoolId,
    required String staffId,
    required String staffName,
  }) async {
    final baseSalaryText = _baseSalaryController.text.trim();
    if (baseSalaryText.isEmpty) return;
    final baseSalary = double.tryParse(baseSalaryText) ?? 0.0;
    if (baseSalary <= 0) return;

    final allowances = <SalaryAllowance>[];
    final hraVal = double.tryParse(_hraController.text.trim()) ?? 0.0;
    if (hraVal > 0) allowances.add(SalaryAllowance(type: 'HRA', amount: hraVal));
    final transVal = double.tryParse(_transportController.text.trim()) ?? 0.0;
    if (transVal > 0) allowances.add(SalaryAllowance(type: 'Transport', amount: transVal));

    final deductions = <SalaryDeduction>[];
    final pfVal = double.tryParse(_pfController.text.trim()) ?? 0.0;
    if (pfVal > 0) deductions.add(SalaryDeduction(type: 'PF', amount: pfVal));
    final taxVal = double.tryParse(_taxController.text.trim()) ?? 0.0;
    if (taxVal > 0) deductions.add(SalaryDeduction(type: 'Tax', amount: taxVal));

    final structure = SalaryStructure(
      id: 'sal_${schoolId}_$staffId',
      schoolId: schoolId,
      staffProfileId: staffId,
      staffName: staffName,
      salaryType: _salaryType,
      basicSalary: baseSalary,
      allowances: allowances,
      deductions: deductions,
      effectiveFrom: _effectiveDate,
      paymentSchedule: _paymentSchedule,
      isActive: _isSalaryActive,
      createdAt: DateTime.now(),
    );

    await ref.read(salaryServiceProvider).updateSalaryStructure(staffId, structure);
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
    _baseSalaryController.dispose();
    _hraController.dispose();
    _transportController.dispose();
    _pfController.dispose();
    _taxController.dispose();
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

        await _saveSalaryStructureIfConfigured(
          schoolId: activeSchoolId,
          staffId: recordId,
          staffName: _nameController.text.trim(),
        );

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

        final isValidUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        final createdStaffId = (staffProfile.id.isNotEmpty && isValidUuid.hasMatch(staffProfile.id))
            ? staffProfile.id
            : (staffProfile.authUserId.isNotEmpty && isValidUuid.hasMatch(staffProfile.authUserId)
                ? staffProfile.authUserId
                : _empIdController.text.trim());

        if (isTeacherMode) {
          final newTeacher = TeacherModel(
            id: createdStaffId,
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

        await _saveSalaryStructureIfConfigured(
          schoolId: activeSchoolId,
          staffId: createdStaffId,
          staffName: _nameController.text.trim(),
        );

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
                'A secure account has been created for $name. They will be required to change their password upon first login.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softLavender.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: $name', style: AppTypography.labelLarge),
                    const SizedBox(height: 4),
                    Text('Email: $email', style: AppTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Employee ID: $empId', style: AppTypography.bodyMedium),
                    const SizedBox(height: 4),
                    Text('Role: $roleName', style: AppTypography.bodyMedium),
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
                final details = 'School Portal Login\nName: $name\nEmail: $email\nEmployee ID: $empId\nRole: $roleName';
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
              ],

              // Salary & Compensation Configuration
              Text('SALARY & COMPENSATION (INR)', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.coolGray.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.coolGray.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _baseSalaryController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Monthly Base Salary (Agreed Basic Amount)',
                        hintText: 'e.g. 35000',
                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                        helperText: 'Leave empty to keep as "Salary Not Configured"',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final val = double.tryParse(v.trim());
                        if (val == null || val < 0) return 'Enter a valid non-negative amount';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _salaryType,
                            decoration: const InputDecoration(
                              labelText: 'Salary Type',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                              DropdownMenuItem(value: 'Hourly', child: Text('Hourly')),
                              DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _salaryType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _effectiveDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setState(() => _effectiveDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Effective From',
                                prefixIcon: Icon(Icons.calendar_today_rounded),
                              ),
                              child: Text(DateFormat('dd MMM yyyy').format(_effectiveDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _hraController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'HRA Allowance (₹)',
                              hintText: '0',
                              prefixIcon: Icon(Icons.home_work_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) return 'Invalid amount';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _transportController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Transport Allowance (₹)',
                              hintText: '0',
                              prefixIcon: Icon(Icons.directions_bus_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) return 'Invalid amount';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pfController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'PF Deduction (₹)',
                              hintText: '0',
                              prefixIcon: Icon(Icons.shield_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) return 'Invalid amount';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _taxController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Tax / Other Deduction (₹)',
                              hintText: '0',
                              prefixIcon: Icon(Icons.money_off_rounded),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) return 'Invalid amount';
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.softLavender.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Projected Monthly Net Salary:', style: AppTypography.bodySmall.copyWith(color: AppColors.deepSlate)),
                              Text(
                                _baseSalaryController.text.trim().isEmpty
                                    ? 'Salary Not Configured'
                                    : '₹ ${_calculateNet().toStringAsFixed(0)} / month',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _baseSalaryController.text.trim().isEmpty
                                      ? AppColors.softCoral
                                      : AppColors.mutedGreen,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isSalaryActive,
                            activeColor: AppColors.mutedGreen,
                            onChanged: (val) => setState(() => _isSalaryActive = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

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
