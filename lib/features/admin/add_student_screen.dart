import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/class_section_models.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  final String? classId;
  final String? className;

  const AddStudentScreen({
    super.key,
    this.classId,
    this.className,
  });

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Student Information Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentPhotoController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _dobController = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'O+';

  // 2. Academic Information State & Controllers
  late final TextEditingController _admissionNoController;
  final _rollNoController = TextEditingController();
  final _parentAccessCodeController = TextEditingController();

  // Academic Year & Cascading Class/Section
  List<AcademicYearModel> _availableAcademicYears = [];
  String? _selectedAcademicYearId;
  bool _hasNoActiveAcademicYear = false;
  bool _isLoadingAcademicYears = true;
  String _selectedClass = 'Class 1';
  String _selectedSection = 'A';
  final List<String> _classList = List.generate(12, (i) => 'Class ${i + 1}');
  final List<String> _sectionList = ['A', 'B', 'C', 'D', 'E', 'F'];

  // 3. Contact Information Controllers
  final _parentPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinController = TextEditingController();

  // 4. Additional Information Controllers
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  // 5. Fee Information Controllers
  final _feeAmountController = TextEditingController();
  final _discountController = TextEditingController();
  final _waiverController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _feeNotesController = TextEditingController();
  DateTime? _selectedDueDate;

  bool _isSaving = false;

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroupOptions = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    final studentService = ref.read(studentServiceProvider);
    _admissionNoController = TextEditingController(text: studentService.generateUniqueStudentNumber());
    if (widget.className != null && widget.className!.trim().isNotEmpty) {
      final inputClass = widget.className!.trim();
      _selectedClass = _classList.contains(inputClass) ? inputClass : 'Class 1';
    }
    _loadAcademicYears();
  }

  Future<void> _loadAcademicYears() async {
    setState(() => _isLoadingAcademicYears = true);
    final user = ref.read(authProvider);
    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final schoolId = (activeProfile?.schoolId != null && activeProfile!.schoolId.isNotEmpty)
        ? activeProfile.schoolId
        : (user?.schoolId ?? '');

    try {
      final ays = await ref.read(academicYearServiceProvider).fetchAcademicYears(schoolId);
      if (mounted) {
        final activeYears = ays.where((y) => y.status == AccountStatus.active || y.isCurrent).toList();
        setState(() {
          _availableAcademicYears = ays;
          _isLoadingAcademicYears = false;
          if (activeYears.isNotEmpty) {
            _selectedAcademicYearId = activeYears.first.id;
            _hasNoActiveAcademicYear = false;
          } else if (ays.isNotEmpty) {
            _selectedAcademicYearId = ays.first.id;
            _hasNoActiveAcademicYear = false;
          } else {
            _selectedAcademicYearId = null;
            _hasNoActiveAcademicYear = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAcademicYears = false;
          _hasNoActiveAcademicYear = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _studentPhotoController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _dobController.dispose();
    _admissionNoController.dispose();
    _rollNoController.dispose();
    _parentAccessCodeController.dispose();
    _parentPhoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _notesController.dispose();
    _feeAmountController.dispose();
    _discountController.dispose();
    _waiverController.dispose();
    _dueDateController.dispose();
    _feeNotesController.dispose();
    super.dispose();
  }

  void _resetForm() {
    final studentService = ref.read(studentServiceProvider);
    setState(() {
      _firstNameController.clear();
      _middleNameController.clear();
      _lastNameController.clear();
      _studentPhotoController.clear();
      _fatherNameController.clear();
      _motherNameController.clear();
      _dobController.clear();
      _selectedGender = 'Male';
      _selectedBloodGroup = 'O+';
      _admissionNoController.text = studentService.generateUniqueStudentNumber();
      _rollNoController.clear();
      _parentAccessCodeController.clear();
      _selectedClass = widget.className ?? 'Class 1';
      _selectedSection = 'A';
      _parentPhoneController.clear();
      _emailController.clear();
      _addressController.clear();
      _cityController.clear();
      _stateController.clear();
      _pinController.clear();
      _emergencyNameController.clear();
      _emergencyPhoneController.clear();
      _notesController.clear();
      _feeAmountController.clear();
      _discountController.clear();
      _waiverController.clear();
      _dueDateController.clear();
      _feeNotesController.clear();
      _selectedDueDate = null;
    });
  }

  void _showSuccessDialog(StudentModel created) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 460,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.greenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.mutedGreen, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Registration Complete', style: AppTypography.titleLarge),
                        const SizedBox(height: 2),
                        Text('Student registered successfully', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: AppColors.borderLight, height: 1),
              const SizedBox(height: 16),
              _buildSuccessRow('Student Name', created.name),
              _buildSuccessRow('Roll Number', created.rollNumber.isNotEmpty ? created.rollNumber : 'N/A'),
              _buildSuccessRow('Admission No', created.admissionNumber),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lavenderLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Parent Access Code', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark)),
                        const SizedBox(height: 4),
                        Text(
                          created.parentAccessCode.isNotEmpty ? created.parentAccessCode : created.admissionNumber,
                          style: AppTypography.titleMedium.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppColors.softLavender),
                      tooltip: 'Copy Code',
                      onPressed: () {
                        final code = created.parentAccessCode.isNotEmpty ? created.parentAccessCode : created.admissionNumber;
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Parent Access Code copied to clipboard!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.softLavender,
                    foregroundColor: AppColors.pureWhite,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.invalidate(adminDashboardMetricsProvider);
                    _resetForm();
                    if (context.mounted) {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(true);
                      } else {
                        context.go('/students');
                      }
                    }
                  },
                  child: Text('Done', style: AppTypography.labelLarge.copyWith(color: AppColors.pureWhite)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.midnightNavy)),
          ),
        ],
      ),
    );
  }

  void _saveStudent() async {
    if (_hasNoActiveAcademicYear || _selectedAcademicYearId == null || _selectedAcademicYearId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.softCoral,
          content: Text('No active academic year is configured for this school.'),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final user = ref.read(authProvider);
      final activeProfile = ref.read(authProvider.notifier).activeProfile;
      final schoolId = (activeProfile?.schoolId != null && activeProfile!.schoolId.isNotEmpty)
          ? activeProfile.schoolId
          : (user?.schoolId ?? '');

      final firstName = _firstNameController.text.trim();
      final middleName = _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final fullName = [firstName, if (middleName.isNotEmpty) middleName, lastName].join(' ');

      setState(() => _isSaving = true);

      final enteredFee = double.tryParse(_feeAmountController.text.trim()) ?? 0.0;
      final enteredDiscount = double.tryParse(_discountController.text.trim()) ?? 0.0;
      final enteredWaiver = double.tryParse(_waiverController.text.trim()) ?? 0.0;
      final feeNotes = _feeNotesController.text.trim().isNotEmpty ? _feeNotesController.text.trim() : null;

      final netFee = (enteredFee - enteredDiscount - enteredWaiver).clamp(0.0, double.infinity);

      final student = StudentModel(
        id: '',
        name: fullName,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        admissionNumber: _admissionNoController.text.trim(),
        rollNumber: _rollNoController.text.trim(),
        className: _selectedClass,
        classId: '',
        section: _selectedSection,
        sectionId: '',
        schoolId: schoolId,
        academicYearId: _selectedAcademicYearId!,
        avatarUrl: _studentPhotoController.text.trim(),
        studentPhoto: _studentPhotoController.text.trim(),
        parentAccessCode: _parentAccessCodeController.text.trim(),
        attendancePercentage: 100.0,
        status: AccountStatus.active,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: _dobController.text.trim(),
        gender: _selectedGender,
        fatherName: _fatherNameController.text.trim(),
        fatherMobile: _parentPhoneController.text.trim(),
        motherName: _motherNameController.text.trim(),
        motherMobile: '',
        guardianName: _fatherNameController.text.trim().isNotEmpty
            ? _fatherNameController.text.trim()
            : _motherNameController.text.trim(),
        emergencyContact: _emergencyPhoneController.text.trim().isNotEmpty
            ? _emergencyPhoneController.text.trim()
            : _parentPhoneController.text.trim(),
        parentEmail: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pinCode: _pinController.text.trim(),
        bloodGroup: _selectedBloodGroup,
        medicalNotes: _notesController.text.trim(),
        importantNotes: _notesController.text.trim(),
        studentCode: _admissionNoController.text.trim(),
        totalFee: enteredFee,
        paidFee: 0.0,
        pendingFee: netFee,
        feeStatus: enteredFee > 0 ? PaymentStatus.pending : PaymentStatus.paid,
        paymentHistory: const [],
      );

      final studentService = ref.read(studentServiceProvider);

      try {
        final created = await studentService.addStudent(
          student,
          grossFee: enteredFee,
          discountAmount: enteredDiscount,
          waiverAmount: enteredWaiver,
          dueDate: _selectedDueDate,
          feeNotes: feeNotes,
        );
        if (mounted) {
          setState(() => _isSaving = false);
          _showSuccessDialog(created);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          final rawMsg = e.toString().replaceAll('Exception: ', '').trim();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.softCoral,
              content: Text(rawMsg),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStudentInformationCard(),
                    const SizedBox(height: 20),
                    _buildAcademicInformationCard(),
                    const SizedBox(height: 20),
                    _buildFeeDetailsCard(),
                    const SizedBox(height: 20),
                    _buildContactInformationCard(),
                    const SizedBox(height: 20),
                    _buildAdditionalInformationCard(),
                    const SizedBox(height: 32),
                    _buildActionArea(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. Header
  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.midnightNavy),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/students');
            }
          },
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Student', style: AppTypography.displayMedium.copyWith(color: AppColors.midnightNavy)),
            const SizedBox(height: 2),
            Text('Register a new student in the campus directory', style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray)),
          ],
        ),
      ],
    );
  }

  // 2. Student Information Card
  Widget _buildStudentInformationCard() {
    return _buildCard(
      title: 'Student Information',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _firstNameController,
                  label: 'First Name *',
                  hint: 'e.g. John',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _middleNameController,
                  label: 'Middle Name',
                  hint: 'Optional',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name *',
                  hint: 'e.g. Doe',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _studentPhotoController,
                  label: 'Student Photo (Optional)',
                  hint: 'Photo URL or filename',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateField(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildGenderSelector(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBloodGroupSelector(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _fatherNameController,
                  label: "Father's Name *",
                  hint: "Enter father's name",
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _motherNameController,
                  label: "Mother's Name",
                  hint: "Enter mother's name",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Academic Information Card
  Widget _buildAcademicInformationCard() {
    return _buildCard(
      title: 'Academic Information',
      icon: Icons.school_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning banner if no active academic year
          if (_hasNoActiveAcademicYear)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.softCoral.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.softCoral),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No active academic year is configured for this school.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.softCoral,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 1. Academic Year Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Academic Year *',
                style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.pureWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasNoActiveAcademicYear ? AppColors.softCoral : AppColors.borderLight,
                  ),
                ),
                child: _isLoadingAcademicYears
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedAcademicYearId,
                          hint: Text(
                            _hasNoActiveAcademicYear ? 'No Active Academic Year Available' : 'Select Academic Year',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
                          ),
                          isExpanded: true,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.midnightNavy, fontWeight: FontWeight.w600),
                          items: _availableAcademicYears.map((ay) => DropdownMenuItem<String>(
                            value: ay.id,
                            child: Text(
                              '${ay.name}${ay.status == AccountStatus.active ? " (ACTIVE)" : ""}',
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedAcademicYearId = val;
                                _hasNoActiveAcademicYear = false;
                              });
                            }
                          },
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Cascading Class and Section Dropdowns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class *',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClass,
                          isExpanded: true,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.midnightNavy, fontWeight: FontWeight.w600),
                          items: _classList.map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedClass = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Section Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Section *',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.pureWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSection,
                          isExpanded: true,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.midnightNavy, fontWeight: FontWeight.w600),
                          items: _sectionList.map((s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text('Section $s'),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSection = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Admission No and Roll No
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _admissionNoController,
                  label: 'Admission Number *',
                  hint: 'STU-2026-XXXX',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _rollNoController,
                  label: 'Roll Number *',
                  hint: 'e.g. 101',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Parent Access Code (Optional)
          _buildTextField(
            controller: _parentAccessCodeController,
            label: 'Parent Access Code (Optional)',
            hint: 'Auto-generated if left blank (e.g. PRNT-98234)',
            suffixIcon: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.softLavender),
              tooltip: 'Generate Code',
              onPressed: () {
                final studentService = ref.read(studentServiceProvider);
                studentService.generateUniqueParentAccessCode().then((code) {
                  _parentAccessCodeController.text = code;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // 3b. Fee Details Card
  Widget _buildFeeDetailsCard() {
    return _buildCard(
      title: 'Fee Details',
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _feeAmountController,
                  label: 'Total / Agreed Admission Fee (₹)',
                  hint: 'e.g. 30000',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _discountController,
                  label: 'Discount (₹)',
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _waiverController,
                  label: 'Waiver (₹)',
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDueDate = picked;
                        _dueDateController.text =
                            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                      });
                    }
                  },
                  child: IgnorePointer(
                    child: _buildTextField(
                      controller: _dueDateController,
                      label: 'Fee Due Date',
                      hint: 'YYYY-MM-DD',
                      suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.coolGray),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _feeNotesController,
                  label: 'Fee Notes / Installment Remarks',
                  hint: 'e.g. 1st installment due at joining',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Contact Information Card
  Widget _buildContactInformationCard() {
    return _buildCard(
      title: 'Contact Information',
      icon: Icons.contact_phone_outlined,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _parentPhoneController,
                  label: 'Parent Phone / Mobile *',
                  hint: '+91 98765 43210',
                  keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'parent@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _addressController,
            label: 'Residential Street Address *',
            hint: 'House No., Building, Street Name',
            validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _cityController,
                  label: 'City',
                  hint: 'e.g. New Delhi',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: _pinController,
                  label: 'PIN Code',
                  hint: '110001',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Additional Information Card
  Widget _buildAdditionalInformationCard() {
    return _buildCard(
      title: 'Additional Information',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _emergencyNameController,
                  label: 'Emergency Contact Person',
                  hint: 'e.g. Uncle / Guardian Name',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _emergencyPhoneController,
                  label: 'Emergency Contact Phone',
                  hint: '+91 98765 43210',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _notesController,
            label: 'Special Notes / Medical Details',
            hint: 'e.g. Allergic to penicillin, wears glasses, etc.',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // 6. Action Area
  Widget _buildActionArea() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            side: const BorderSide(color: AppColors.borderLight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSaving
              ? null
              : () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/students');
                  }
                },
          child: Text('Cancel', style: AppTypography.labelLarge.copyWith(color: AppColors.coolGrayDark)),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _hasNoActiveAcademicYear ? AppColors.coolGrayLight : AppColors.softLavender,
            foregroundColor: AppColors.pureWhite,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: _hasNoActiveAcademicYear ? 0 : 1,
          ),
          onPressed: (_isSaving || _hasNoActiveAcademicYear) ? null : _saveStudent,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: AppColors.pureWhite, strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Complete Registration', style: AppTypography.labelLarge.copyWith(color: AppColors.pureWhite)),
                  ],
                ),
        ),
      ],
    );
  }

  // Helper Card Builder
  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.midnightNavy.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.softLavender, size: 20),
              const SizedBox(width: 10),
              Text(title, style: AppTypography.titleMedium.copyWith(color: AppColors.midnightNavy)),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // Helper Input Field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: suffixIcon,
            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.coolGrayLight),
            filled: true,
            fillColor: AppColors.pureWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.softLavender, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.softCoral),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.softCoral, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // Date Field with Picker
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date of Birth', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _dobController,
          readOnly: true,
          style: AppTypography.bodyMedium,
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.coolGrayLight),
            filled: true,
            fillColor: AppColors.pureWhite,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.coolGray, size: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.softLavender, width: 1.5),
            ),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2015, 1, 1),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              _dobController.text =
                  "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
            }
          },
        ),
      ],
    );
  }

  // Gender Selector
  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: _genderOptions.map((g) {
              final isSelected = _selectedGender == g;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedGender = g),
                  child: Center(
                    child: Text(
                      g,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected ? AppColors.softLavender : AppColors.coolGrayDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Blood Group Selector
  Widget _buildBloodGroupSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Blood Group', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            border: Border.all(color: AppColors.borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: _bloodGroupOptions.take(4).map((bg) {
              final isSelected = _selectedBloodGroup == bg;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _selectedBloodGroup = bg),
                  child: Center(
                    child: Text(
                      bg,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected ? AppColors.softLavender : AppColors.coolGrayDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
