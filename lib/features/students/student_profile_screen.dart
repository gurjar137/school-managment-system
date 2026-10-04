import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/parent_model.dart';
import '../../data/models/fee_models.dart';
import '../../data/models/result_models.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StudentModel? _student;
  String? _academicYearName;
  bool _isLoading = true;
  StudentFeeAccountModel? _liveFeeAccount;
  Future<List<dynamic>>? _feeTabFuture;

  bool _isTeacherRole() {
    final user = ref.read(authProvider);
    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final role = activeProfile?.role ?? user?.role;
    return role == UserRole.teacher;
  }

  @override
  void initState() {
    super.initState();
    final isTeacher = _isTeacherRole();
    _tabController = TabController(length: isTeacher ? 4 : 5, vsync: this);
    if (!isTeacher) {
      _feeTabFuture = _loadFeesData();
    }
    _fetchStudent();
  }

  Future<List<dynamic>> _loadFeesData() async {
    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final schoolId = (activeProfile?.schoolId != null && activeProfile!.schoolId.isNotEmpty)
        ? activeProfile.schoolId
        : '';
    if (schoolId.isEmpty) return [];
    final feeService = ref.read(feeServiceProvider);

    final results = await Future.wait([
      feeService.getStudentFeeAccount(widget.studentId, schoolId: schoolId),
      feeService.getPaymentHistory(schoolId: schoolId, studentId: widget.studentId),
    ]);

    if (mounted && results.isNotEmpty && results[0] != null) {
      setState(() {
        _liveFeeAccount = results[0] as StudentFeeAccountModel?;
      });
    }

    return results;
  }

  void _fetchStudent() async {
    final repo = ref.read(schoolRepositoryProvider);
    final student = await repo.getStudentById(widget.studentId);

    String? ayName;
    if (student != null && student.academicYearId.isNotEmpty) {
      try {
        final ays = await ref.read(academicYearServiceProvider).fetchAcademicYears(student.schoolId);
        final found = ays.where((y) => y.id == student.academicYearId).toList();
        if (found.isNotEmpty) {
          ayName = found.first.name;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _student = student;
        _academicYearName = ayName;
        _isLoading = false;
      });
    }
  }

  void _refreshFees() {
    if (mounted && !_isTeacherRole()) {
      setState(() {
        _feeTabFuture = _loadFeesData();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingStateWidget(message: 'Loading comprehensive student file...'),
      );
    }

    if (_student == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyStateWidget(
          icon: Icons.person_off_rounded,
          title: 'Student Profile Not Found',
          message: 'The requested student profile could not be retrieved from campus registry.',
        ),
      );
    }

    final s = _student!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final feeService = ref.watch(feeServiceProvider);
    final user = ref.watch(authProvider);
    final activeProfile = ref.watch(authProvider.notifier).activeProfile;
    final role = activeProfile?.role ?? user?.role;
    final isTeacher = role == UserRole.teacher;

    final expectedTabCount = isTeacher ? 4 : 5;
    if (_tabController.length != expectedTabCount) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: expectedTabCount,
        vsync: this,
        initialIndex: oldIndex >= expectedTabCount ? 0 : oldIndex,
      );
    }

    final schoolId = (activeProfile?.schoolId != null && activeProfile!.schoolId.isNotEmpty)
        ? activeProfile.schoolId
        : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Student File', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded, color: AppColors.mutedGreen),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling Emergency Contact: ${s.emergencyContact}')),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Student Actions',
            onSelected: (val) {
              if (val == 'edit') {
                _showEditStudentDialog(context, s, schoolId);
              } else if (val == 'toggle_status') {
                _showStatusChangeDialog(context, s);
              } else if (val == 'delete') {
                _showDeleteStudentDialog(context, s);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: AppColors.softLavender, size: 20),
                    SizedBox(width: 10),
                    Text('Edit Student / Academic Year'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_status',
                child: Row(
                  children: [
                    Icon(
                      s.status == AccountStatus.active ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                      color: s.status == AccountStatus.active ? AppColors.warmAmber : AppColors.mutedGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(s.status == AccountStatus.active ? 'Deactivate Student' : 'Activate Student'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, color: AppColors.softCoral, size: 20),
                    SizedBox(width: 10),
                    Text('Delete Student', style: TextStyle(color: AppColors.softCoral)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Student Info Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: s.avatarUrl,
                  name: s.name,
                  radius: 34,
                  borderColor: AppColors.softLavender,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Class ${s.fullClassCode} • Roll No: ${s.rollNumber}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Adm No: ${s.admissionNumber}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildBadge(s.status == AccountStatus.active ? 'ACTIVE' : 'INACTIVE', s.status == AccountStatus.active ? AppColors.mutedGreen : AppColors.warmAmber),
                          _buildBadge('AY: ${_academicYearName ?? (s.academicYearId.isNotEmpty ? s.academicYearId : "2026-2027")}', AppColors.softLavender),
                          _buildBadge('Blood: ${s.bloodGroup}', AppColors.softLavender),
                          if (!isTeacher) ...[
                            if (_liveFeeAccount != null)
                              _buildBadge('Fee: ${_liveFeeAccount!.computedStatus}', _getDbFeeStatusColor(_liveFeeAccount!.dbStatus))
                            else
                              _buildBadge('Fee: ${s.feeStatus.name.toUpperCase()}', _getFeeStatusColor(s.feeStatus)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar Navigation
          Container(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceLight,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: isDark ? AppColors.softLavender : AppColors.midnightNavy,
              unselectedLabelColor: AppColors.coolGray,
              indicatorColor: AppColors.softLavender,
              tabs: [
                const Tab(text: 'Overview & Info'),
                const Tab(text: 'Parents & Contact'),
                if (!isTeacher) const Tab(text: 'Fees & Dues'),
                const Tab(text: 'Academics'),
                const Tab(text: 'Attendance & Medical'),
              ],
            ),
          ),

          // Tab Content Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(s),
                _buildParentsTab(s),
                if (!isTeacher) _buildFeesTab(s, schoolId, feeService, isDark),
                _buildAcademicsTab(s),
                _buildAttendanceMedicalTab(s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(StudentModel s) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Summary Stats Row
        Row(
          children: [
            Expanded(
              child: BentoCard(
                child: Column(
                  children: [
                    Text('${s.attendancePercentage.toStringAsFixed(1)}%', style: AppTypography.numericHeader.copyWith(fontSize: 26, color: AppColors.mutedGreen)),
                    Text('Attendance', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: BentoCard(
                child: Column(
                  children: [
                    Text('Class ${s.fullClassCode}', style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.softLavender)),
                    Text('Class & Section', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Secret Code Card
        Text('PARENT ACCESS / SECRET CODE', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        BentoCard(
          backgroundColor: AppColors.lavenderLight.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.softLavender.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.key_rounded, color: AppColors.softLavender, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parent Access Code',
                            style: AppTypography.labelSmall.copyWith(color: AppColors.coolGrayDark, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            s.parentAccessCode.isNotEmpty ? s.parentAccessCode : s.admissionNumber,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.midnightNavy,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.softLavender,
                  foregroundColor: AppColors.pureWhite,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy'),
                onPressed: () {
                  final codeToCopy = s.parentAccessCode.isNotEmpty ? s.parentAccessCode : s.admissionNumber;
                  Clipboard.setData(ClipboardData(text: codeToCopy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Secret code copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('STUDENT IDENTIFICATION', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              _buildDetailRow(Icons.badge_outlined, 'Full Name', s.name),
              const Divider(height: 16),
              _buildDetailRow(Icons.calendar_today_outlined, 'Academic Year', _academicYearName ?? (s.academicYearId.isNotEmpty ? s.academicYearId : 'Current (2026-2027)')),
              const Divider(height: 16),
              _buildDetailRow(Icons.confirmation_number_outlined, 'Admission Number', s.admissionNumber),
              const Divider(height: 16),
              _buildDetailRow(Icons.numbers_rounded, 'Roll Number', s.rollNumber),
              const Divider(height: 16),
              _buildDetailRow(Icons.cake_outlined, 'Date of Birth', s.dateOfBirth),
              const Divider(height: 16),
              _buildDetailRow(Icons.wc_rounded, 'Gender', s.gender),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('RESIDENTIAL ADDRESS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              _buildDetailRow(Icons.home_outlined, 'Address Line', s.address),
              const Divider(height: 16),
              _buildDetailRow(Icons.location_city_outlined, 'City & State', '${s.city}, ${s.state}'),
              const Divider(height: 16),
              _buildDetailRow(Icons.pin_drop_outlined, 'PIN Code', s.pinCode),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParentsTab(StudentModel s) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('FATHER INFORMATION', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              _buildDetailRow(Icons.person_outline, "Father's Name", s.fatherName),
              const Divider(height: 16),
              _buildContactRow("Father's Mobile", s.fatherMobile),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('MOTHER INFORMATION', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              _buildDetailRow(Icons.person_outline, "Mother's Name", s.motherName),
              const Divider(height: 16),
              _buildContactRow("Mother's Mobile", s.motherMobile),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('GUARDIAN & EMERGENCY CONTACT', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              _buildDetailRow(Icons.shield_outlined, 'Guardian Name', s.guardianName),
              const Divider(height: 16),
              _buildContactRow('Emergency Hotline', s.emergencyContact, isEmergency: true),
              const Divider(height: 16),
              _buildDetailRow(Icons.email_outlined, 'Parent Email', s.parentEmail),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('PARENT ACCESS & PORTAL MANAGEMENT', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        FutureBuilder<StudentParentAccessInfo>(
          future: ref.read(parentServiceProvider).getParentAccessForStudent(s.id, schoolId: s.schoolId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const BentoCard(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final info = snapshot.data ?? StudentParentAccessInfo(
              studentId: s.id,
              studentName: s.name,
              schoolId: s.schoolId,
              parentAccessCode: s.parentAccessCode.isNotEmpty ? s.parentAccessCode : null,
              isConfigured: s.parentAccessCode.isNotEmpty,
              isEnabled: s.parentAccessCode.isNotEmpty && s.status == AccountStatus.active,
              status: (s.parentAccessCode.isNotEmpty && s.status == AccountStatus.active)
                  ? AccountStatus.active
                  : AccountStatus.inactive,
            );

            final isAccessActive = info.isEnabled;
            final isConfigured = info.isConfigured;

            return BentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Parent Access', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            'Student: ${info.studentName}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAccessActive
                              ? AppColors.mutedGreen.withValues(alpha: 0.15)
                              : AppColors.warmAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isAccessActive ? 'STATUS: ACTIVE' : 'STATUS: INACTIVE',
                          style: AppTypography.labelSmall.copyWith(
                            color: isAccessActive ? AppColors.mutedGreen : AppColors.warmAmber,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Detail Rows
                  _buildDetailRow(
                    Icons.security_rounded,
                    'Access State',
                    isAccessActive ? 'ENABLED' : 'DISABLED',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.family_restroom_rounded,
                    'Parent Account',
                    info.parentAccountName ?? (info.parentCode != null ? 'Account ${info.parentCode}' : 'Not Configured'),
                  ),
                  if (info.parentEmail != null && info.parentEmail!.isNotEmpty) ...[
                    const Divider(height: 16),
                    _buildDetailRow(Icons.email_outlined, 'Parent Email', info.parentEmail!),
                  ],
                  if (info.parentPhone != null && info.parentPhone!.isNotEmpty) ...[
                    const Divider(height: 16),
                    _buildDetailRow(Icons.phone_outlined, 'Parent Phone', info.parentPhone!),
                  ],
                  const Divider(height: 16),

                  // Access Code display
                  Text('Parent Access Code (Portal Key)', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.softLavender.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isAccessActive && info.parentAccessCode != null
                              ? info.parentAccessCode!
                              : (isConfigured ? 'ACCESS DISABLED' : 'NOT CONFIGURED'),
                          style: AppTypography.numericHeader.copyWith(
                            fontSize: 18,
                            color: isAccessActive ? AppColors.softLavender : AppColors.softCoral,
                          ),
                        ),
                        if (isAccessActive && info.parentAccessCode != null)
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: AppColors.softLavender),
                            tooltip: 'Copy Access Code',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: info.parentAccessCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Parent Code "${info.parentAccessCode}" copied!')),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  Row(
                    children: [
                      if (!isAccessActive)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mutedGreen,
                              foregroundColor: AppColors.pureWhite,
                            ),
                            onPressed: () async {
                              final updated = await ref.read(parentServiceProvider).enableParentAccessForStudent(
                                    studentId: s.id,
                                    schoolId: s.schoolId,
                                  );
                              if (mounted) {
                                setState(() {
                                  if (_student != null && updated.parentAccessCode != null) {
                                    _student = _student!.copyWith(parentAccessCode: updated.parentAccessCode!);
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.mutedGreen,
                                    content: Text('Parent Access ENABLED for ${s.name}!'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Enable Access'),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.softCoral,
                              foregroundColor: AppColors.pureWhite,
                            ),
                            onPressed: () async {
                              await ref.read(parentServiceProvider).disableParentAccessForStudent(
                                    studentId: s.id,
                                    schoolId: s.schoolId,
                                  );
                              if (mounted) {
                                setState(() {
                                  if (_student != null) {
                                    _student = _student!.copyWith(parentAccessCode: '');
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppColors.softCoral,
                                    content: Text('Parent Access DISABLED.'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.block_rounded, size: 18),
                            label: const Text('Disable Access'),
                          ),
                        ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final updated = await ref.read(parentServiceProvider).regenerateParentAccessCode(
                                studentId: s.id,
                                schoolId: s.schoolId,
                              );
                          if (mounted) {
                            setState(() {
                              if (_student != null && updated.parentAccessCode != null) {
                                _student = _student!.copyWith(parentAccessCode: updated.parentAccessCode!);
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.softLavender,
                                content: Text('New Access Code "${updated.parentAccessCode}" generated!'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Regenerate Code'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeesTab(StudentModel s, String schoolId, dynamic feeService, bool isDark) {
    return FutureBuilder<List<dynamic>>(
      future: _feeTabFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingStateWidget(message: 'Loading live fee account & transactions...');
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.softCoral),
                  const SizedBox(height: 12),
                  Text('Unable to load fee details.', style: AppTypography.titleMedium),
                  const SizedBox(height: 6),
                  Text('${snapshot.error}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _refreshFees,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final feeAccount = snapshot.data?[0] as StudentFeeAccountModel?;
        final payments = (snapshot.data?[1] as List<PaymentRecordModel>?) ?? [];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Fee Summary / Account Banner
            if (feeAccount == null)
              BentoCard(
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
                border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.3)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: AppColors.softLavender, size: 20),
                              const SizedBox(width: 8),
                              Text('FEE ACCOUNT STATUS', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
                            ],
                          ),
                          _buildBadge('NO FEE ASSIGNED', AppColors.coolGray),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('No Fee Assigned for Current Session', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'This student currently does not have an active fee account record linked in the campus fee system. You can assign a tuition fee structure or configure a custom gross fee below.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightNavy,
                          foregroundColor: AppColors.pureWhite,
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Assign Fee to Student'),
                        onPressed: () => _showAssignFeeToStudentDialog(context, schoolId, s.id, s.name),
                      ),
                    ],
                  ),
                ),
              )
            else
              BentoCard(
                backgroundColor: AppColors.midnightNavy,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('ANNUAL FEE STATEMENT', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.lavenderLight),
                              tooltip: 'Refresh Fees',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _refreshFees,
                            ),
                          ],
                        ),
                        _buildBadge(feeAccount.computedStatus, _getDbFeeStatusColor(feeAccount.dbStatus)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('NET PAYABLE FEE', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight, letterSpacing: 0.8)),
                            const SizedBox(height: 2),
                            Text('₹ ${feeAccount.netFee.toStringAsFixed(2)}', style: AppTypography.numericHeader.copyWith(color: AppColors.pureWhite, fontSize: 28)),
                          ],
                        ),
                        if (feeAccount.dueDate != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('DUE DATE', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                              const SizedBox(height: 2),
                              Text(
                                '${feeAccount.dueDate!.day}/${feeAccount.dueDate!.month}/${feeAccount.dueDate!.year}',
                                style: const TextStyle(color: AppColors.pureWhite, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Concession & Waiver Breakdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statementItem('Gross Fee', '₹ ${feeAccount.grossFee.toStringAsFixed(0)}'),
                          _statementItem('Discount', '₹ ${feeAccount.discountAmount.toStringAsFixed(0)}'),
                          _statementItem('Waiver', '₹ ${feeAccount.waiverAmount.toStringAsFixed(0)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Paid', style: AppTypography.bodySmall.copyWith(color: AppColors.lavenderLight)),
                            Text('₹ ${feeAccount.totalPaid.toStringAsFixed(2)}', style: AppTypography.titleSmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Outstanding Due', style: AppTypography.bodySmall.copyWith(color: AppColors.lavenderLight)),
                            Text(
                              '₹ ${feeAccount.currentDue.toStringAsFixed(2)}',
                              style: AppTypography.titleSmall.copyWith(
                                color: feeAccount.currentDue > 0 ? AppColors.softCoral : AppColors.mutedGreen,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Action Buttons
                    Row(
                      children: [
                        if (feeAccount.currentDue > 0) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.mutedGreen,
                                foregroundColor: AppColors.pureWhite,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.payments_rounded, size: 18),
                              label: const Text('Collect Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _showRecordPaymentModal(context, schoolId, s, feeAccount),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.pureWhite,
                              side: const BorderSide(color: AppColors.lavenderLight),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.pureWhite),
                            label: const Text('View Statement', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => _showStatementPrintModal(context, s, feeAccount, payments),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            SectionHeader(
              title: 'Payment History & Receipts (${payments.length})',
              actionTitle: 'Refresh',
              onActionTap: _refreshFees,
            ),
            const SizedBox(height: 8),

            if (payments.isEmpty)
              const EmptyStateWidget(
                icon: Icons.receipt_long_rounded,
                title: 'No Payment History',
                message: 'No fee transaction receipts logged for this student yet.',
              )
            else
              ...payments.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: BentoCard(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        final receipt = FeeReceiptModel(
                          receiptNo: p.receiptNumber,
                          studentName: s.name,
                          admissionNumber: s.admissionNumber,
                          className: s.fullClassCode,
                          parentName: s.fatherName.isNotEmpty
                              ? s.fatherName
                              : (s.guardianName.isNotEmpty ? s.guardianName : s.motherName),
                          date: p.paidAt,
                          amountPaid: p.amount,
                          paymentMethod: p.paymentMethod.name.toUpperCase(),
                          transactionRef: p.referenceNumber ?? '',
                          remainingBalance: feeAccount?.currentDue ?? 0.0,
                          description: p.notes ?? 'School Fee Payment',
                        );
                        _showReceiptModal(context, receipt);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.mutedGreen.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.receipt_rounded, size: 16, color: AppColors.mutedGreen),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(p.receiptNumber, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                Text('₹ ${p.amount.toStringAsFixed(2)}', style: AppTypography.titleSmall.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year} • Mode: ${p.paymentMethod.name.toUpperCase()}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                Row(
                                  children: [
                                    Text('View Receipt', style: AppTypography.labelSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.bold)),
                                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.softLavender),
                                  ],
                                ),
                              ],
                            ),
                            if (p.referenceNumber != null && p.referenceNumber!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('Ref: ${p.referenceNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.softLavender, fontSize: 11)),
                            ],
                            if (p.notes != null && p.notes!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('Notes: ${p.notes}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _statementItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.lavenderLight, fontSize: 10)),
        const SizedBox(height: 1),
        Text(value, style: const TextStyle(color: AppColors.pureWhite, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildAcademicsTab(StudentModel s) {
    final resultService = ref.read(resultServiceProvider);

    return FutureBuilder<List<SubjectResultModel>>(
      future: resultService.getStudentAcademics(s.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingStateWidget(message: 'Loading examination results...');
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.school_outlined,
            title: 'No Examination Results Available',
            message: 'No examination or test marks have been recorded for this student yet.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: results.map((res) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: BentoCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(res.subjectName, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                          Text('Max Marks: ${res.maxMarks.toStringAsFixed(0)}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${res.obtainedMarks.toStringAsFixed(0)}/${res.maxMarks.toStringAsFixed(0)}',
                          style: AppTypography.titleSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Grade ${res.grade}',
                          style: AppTypography.bodySmall.copyWith(
                            color: res.isPassed ? AppColors.mutedGreen : AppColors.softCoral,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }

  Widget _buildAttendanceMedicalTab(StudentModel s) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        BentoCard(
          child: Column(
            children: [
              AttendanceProgressCircle(percentage: s.attendancePercentage, size: 110, strokeWidth: 10),
              const SizedBox(height: 14),
              Text('Present Rate: ${s.attendancePercentage}%', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text('MEDICAL & SPECIAL NOTES', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray)),
        const SizedBox(height: 8),
        BentoCard(
          child: Column(
            children: [
              _buildDetailRow(Icons.medical_services_outlined, 'Medical Conditions', s.medicalNotes),
              const Divider(height: 16),
              _buildDetailRow(Icons.star_outline_rounded, 'Important Educator Notes', s.importantNotes),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.softLavender),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.titleSmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(String title, String phone, {bool isEmergency = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                phone,
                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(Icons.phone_forwarded_rounded, color: isEmergency ? AppColors.softCoral : AppColors.mutedGreen),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Calling $phone')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w800),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _getFeeStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppColors.mutedGreen;
      case PaymentStatus.partial:
        return AppColors.warmAmber;
      case PaymentStatus.pending:
      case PaymentStatus.overdue:
        return AppColors.softCoral;
    }
  }

  Color _getDbFeeStatusColor(String dbStatus) {
    switch (dbStatus.toLowerCase()) {
      case 'paid':
        return AppColors.mutedGreen;
      case 'partially_paid':
      case 'partial':
        return AppColors.warmAmber;
      case 'overdue':
        return AppColors.softCoral;
      case 'due':
      default:
        return AppColors.softCoral;
    }
  }

  void _showReceiptModal(BuildContext context, FeeReceiptModel receipt) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.mutedGreen, size: 48),
                const SizedBox(height: 8),
                Text('PAYMENT SUCCESSFUL', style: AppTypography.titleLarge.copyWith(color: AppColors.mutedGreen, fontWeight: FontWeight.w900)),
                Text('OFFICIAL SCHOOL FEE RECEIPT', style: AppTypography.labelSmall.copyWith(color: AppColors.coolGray, letterSpacing: 1.2)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.softLavender.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Receipt No: ${receipt.receiptNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.midnightNavy)),
                      Text('${receipt.date.day}/${receipt.date.month}/${receipt.date.year}', style: const TextStyle(color: AppColors.coolGray, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _receiptRow('Student Name', receipt.studentName),
                if (receipt.admissionNumber.isNotEmpty) _receiptRow('Admission No.', receipt.admissionNumber),
                _receiptRow('Class', receipt.className),
                _receiptRow('Payment Method', receipt.paymentMethod),
                if (receipt.transactionRef.isNotEmpty) _receiptRow('Ref. Number', receipt.transactionRef),
                const Divider(height: 24),
                _receiptRow('Amount Paid', '₹ ${receipt.amountPaid.toStringAsFixed(2)}', isBold: true, highlightColor: AppColors.mutedGreen),
                _receiptRow('Remaining Due', '₹ ${receipt.remainingBalance.toStringAsFixed(2)}', isBold: true),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt sent to print spooler / PDF exporter')));
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print / Save PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightNavy,
                          foregroundColor: AppColors.pureWhite,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _receiptRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.coolGray, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: highlightColor ?? AppColors.midnightNavy,
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordPaymentModal(
    BuildContext context,
    String schoolId,
    StudentModel student,
    StudentFeeAccountModel feeAccount,
  ) {
    final amountCtrl = TextEditingController(text: feeAccount.currentDue > 0 ? feeAccount.currentDue.toStringAsFixed(0) : '');
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: 'Tuition Fee Installment');
    PaymentMethod selectedMethod = PaymentMethod.cash;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppColors.mutedGreen),
                  const SizedBox(width: 8),
                  Text('Collect Fee Payment', style: AppTypography.titleMedium),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.softLavender.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Class ${student.fullClassCode} • Adm No: ${student.admissionNumber}', style: const TextStyle(color: AppColors.coolGray, fontSize: 12)),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Net Fee:', style: TextStyle(fontSize: 12, color: AppColors.coolGray)),
                                Text('₹ ${feeAccount.netFee.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Paid:', style: TextStyle(fontSize: 12, color: AppColors.coolGray)),
                                Text('₹ ${feeAccount.totalPaid.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.mutedGreen, fontSize: 12)),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Outstanding Due:', style: TextStyle(fontSize: 12, color: AppColors.coolGray)),
                                Text('₹ ${feeAccount.currentDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.softCoral, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Payment Amount (₹)', hintText: 'Enter amount to collect'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PaymentMethod>(
                        value: selectedMethod,
                        decoration: const InputDecoration(labelText: 'Payment Mode'),
                        items: const [
                          DropdownMenuItem(value: PaymentMethod.cash, child: Text('CASH')),
                          DropdownMenuItem(value: PaymentMethod.upi, child: Text('UPI / GPAY / PHONEPE')),
                          DropdownMenuItem(value: PaymentMethod.bankTransfer, child: Text('BANK TRANSFER / NEFT')),
                          DropdownMenuItem(value: PaymentMethod.cheque, child: Text('CHEQUE / DEMAND DRAFT')),
                          DropdownMenuItem(value: PaymentMethod.online, child: Text('DEBIT / CREDIT CARD')),
                        ],
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedMethod = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: refCtrl,
                        decoration: const InputDecoration(labelText: 'Transaction / Cheque Ref. No (Optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(labelText: 'Notes / Remarks'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midnightNavy,
                    foregroundColor: AppColors.pureWhite,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                          if (amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment amount must be greater than zero')));
                            return;
                          }
                          if (amt > feeAccount.currentDue) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Payment amount (₹$amt) cannot exceed remaining due (₹${feeAccount.currentDue}).')),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);

                          try {
                            final receipt = await ref.read(feeServiceProvider).recordPayment(
                              schoolId: schoolId,
                              studentId: student.id,
                              studentName: student.name,
                              className: student.fullClassCode,
                              admissionNumber: student.admissionNumber,
                              amount: amt,
                              paymentMethod: selectedMethod,
                              transactionReference: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                              notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : 'School Fee Payment',
                            );

                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                              _refreshFees();
                              _showReceiptModal(context, receipt);
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment error: $e')));
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Generate Receipt & Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAssignFeeToStudentDialog(BuildContext context, String schoolId, String studentId, String studentName) {
    final feeCtrl = TextEditingController();
    final discCtrl = TextEditingController(text: '0');
    final waivCtrl = TextEditingController(text: '0');
    final notesCtrl = TextEditingController(text: 'Standard Academic Tuition Fee');
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Assign Fee: $studentName', style: AppTypography.titleLarge),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: feeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Gross Fee Amount (₹)', hintText: 'e.g. 35000'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: discCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Concession / Discount (₹)'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: waivCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Waiver (₹)'),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Due Date', style: TextStyle(fontSize: 14)),
                        subtitle: Text('${dueDate.day}/${dueDate.month}/${dueDate.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today_rounded, size: 20),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(() => dueDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notesCtrl,
                        decoration: const InputDecoration(labelText: 'Notes / Remarks'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.midnightNavy,
                    foregroundColor: AppColors.pureWhite,
                  ),
                  onPressed: () async {
                    final gross = double.tryParse(feeCtrl.text.trim()) ?? 0.0;
                    if (gross <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid gross fee amount.')));
                      return;
                    }
                    final disc = double.tryParse(discCtrl.text.trim()) ?? 0.0;
                    final waiv = double.tryParse(waivCtrl.text.trim()) ?? 0.0;

                    try {
                      await ref.read(feeServiceProvider).assignFeeToStudent(
                        schoolId: schoolId,
                        studentId: studentId,
                        grossFee: gross,
                        discountAmount: disc,
                        waiverAmount: waiv,
                        dueDate: dueDate,
                        notes: notesCtrl.text.trim(),
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _refreshFees();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: AppColors.mutedGreen,
                          content: Text('Fee successfully assigned to $studentName!'),
                        ));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign fee: $e')));
                      }
                    }
                  },
                  child: const Text('Assign Fee'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatementPrintModal(
    BuildContext context,
    StudentModel s,
    StudentFeeAccountModel feeAccount,
    List<PaymentRecordModel> payments,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 480,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ANNUAL FEE STATEMENT', style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w900)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                _receiptRow('Student', s.name),
                _receiptRow('Admission No.', s.admissionNumber),
                _receiptRow('Class / Section', s.fullClassCode),
                _receiptRow('Gross Fee', '₹ ${feeAccount.grossFee.toStringAsFixed(2)}'),
                _receiptRow('Discount / Concession', '₹ ${feeAccount.discountAmount.toStringAsFixed(2)}'),
                _receiptRow('Waiver', '₹ ${feeAccount.waiverAmount.toStringAsFixed(2)}'),
                const Divider(),
                _receiptRow('Net Fee Payable', '₹ ${feeAccount.netFee.toStringAsFixed(2)}', isBold: true),
                _receiptRow('Total Paid to Date', '₹ ${feeAccount.totalPaid.toStringAsFixed(2)}', isBold: true, highlightColor: AppColors.mutedGreen),
                _receiptRow('Current Outstanding Due', '₹ ${feeAccount.currentDue.toStringAsFixed(2)}', isBold: true, highlightColor: feeAccount.currentDue > 0 ? AppColors.softCoral : AppColors.mutedGreen),
                _receiptRow('Status', feeAccount.computedStatus, isBold: true),
                const SizedBox(height: 12),
                Text('TRANSACTION BREAKDOWN (${payments.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.coolGray)),
                const SizedBox(height: 6),
                if (payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No payment transactions logged.', style: TextStyle(color: AppColors.coolGray, fontSize: 12)),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: payments.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 8),
                      itemBuilder: (context, idx) {
                        final p = payments[idx];
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('${p.paidAt.day}/${p.paidAt.month}/${p.paidAt.year} • ${p.paymentMethod.name.toUpperCase()}', style: const TextStyle(color: AppColors.coolGray, fontSize: 11)),
                              ],
                            ),
                            Text('₹ ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.mutedGreen, fontSize: 12)),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statement exported to PDF / Print queue')));
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print / Save PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.midnightNavy,
                          foregroundColor: AppColors.pureWhite,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStatusChangeDialog(BuildContext context, StudentModel s) {
    final willDeactivate = s.status == AccountStatus.active;
    final targetStatus = willDeactivate ? AccountStatus.inactive : AccountStatus.active;
    final actionLabel = willDeactivate ? 'Deactivate' : 'Activate';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              willDeactivate ? Icons.block_rounded : Icons.check_circle_outline_rounded,
              color: willDeactivate ? AppColors.warmAmber : AppColors.mutedGreen,
            ),
            const SizedBox(width: 8),
            Text('$actionLabel Student'),
          ],
        ),
        content: Text(
          willDeactivate
              ? 'Are you sure you want to deactivate ${s.name}? The student will be marked inactive and hidden from active registers, but all fee and attendance history will be preserved.'
              : 'Are you sure you want to reactivate ${s.name}? The student will be marked active and restored to class registers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate ? AppColors.warmAmber : AppColors.mutedGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(schoolRepositoryProvider).updateStudentStatus(s.id, targetStatus);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${s.name} has been ${willDeactivate ? "deactivated" : "reactivated"} successfully.'),
                      backgroundColor: willDeactivate ? AppColors.warmAmber : AppColors.mutedGreen,
                    ),
                  );
                  _fetchStudent();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update status: $e'),
                      backgroundColor: AppColors.softCoral,
                    ),
                  );
                }
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  void _showDeleteStudentDialog(BuildContext context, StudentModel s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.softCoral),
            SizedBox(width: 8),
            Text('Delete Student Record'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${s.name} (Roll: ${s.rollNumber})?\n\n'
          'NOTE: If this student has existing fee accounts, transaction receipts, or attendance records, '
          'the deletion will be safely rejected to prevent data corruption. In that case, deactivate the student instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softCoral,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(schoolRepositoryProvider).deleteStudent(s.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${s.name} record deleted successfully.'),
                      backgroundColor: AppColors.mutedGreen,
                    ),
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (alertCtx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.error_outline_rounded, color: AppColors.softCoral),
                          SizedBox(width: 8),
                          Text('Deletion Blocked'),
                        ],
                      ),
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(alertCtx),
                          child: const Text('OK'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmAmber),
                          onPressed: () {
                            Navigator.pop(alertCtx);
                            _showStatusChangeDialog(context, s);
                          },
                          child: const Text('Deactivate Instead', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditStudentDialog(BuildContext context, StudentModel s, String schoolId) async {
    final ays = await ref.read(academicYearServiceProvider).fetchAcademicYears(schoolId);

    final firstNameCtrl = TextEditingController(text: s.firstName.isNotEmpty ? s.firstName : s.name.split(' ').first);
    final middleNameCtrl = TextEditingController(text: s.middleName);
    final lastNameCtrl = TextEditingController(text: s.lastName.isNotEmpty ? s.lastName : (s.name.split(' ').length > 1 ? s.name.split(' ').last : ''));
    final rollNoCtrl = TextEditingController(text: s.rollNumber);
    String selectedClass = s.className;
    String selectedSection = s.section;
    String selectedAyId = s.academicYearId.isNotEmpty ? s.academicYearId : (ays.isNotEmpty ? ays.first.id : '');

    final classList = List.generate(12, (i) => 'Class ${i + 1}');
    if (!classList.contains(selectedClass)) {
      classList.insert(0, selectedClass);
    }
    final sectionList = ['A', 'B', 'C', 'D', 'E', 'F'];
    if (!sectionList.contains(selectedSection)) {
      sectionList.insert(0, selectedSection);
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppColors.softLavender),
                SizedBox(width: 8),
                Text('Edit Student Details'),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: firstNameCtrl,
                      decoration: const InputDecoration(labelText: 'First Name *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: middleNameCtrl,
                      decoration: const InputDecoration(labelText: 'Middle Name (Optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lastNameCtrl,
                      decoration: const InputDecoration(labelText: 'Last Name *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rollNoCtrl,
                      decoration: const InputDecoration(labelText: 'Roll Number'),
                    ),
                    const SizedBox(height: 12),
                    if (ays.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: ays.any((y) => y.id == selectedAyId) ? selectedAyId : ays.first.id,
                        decoration: const InputDecoration(labelText: 'Academic Year *'),
                        items: ays.map((ay) => DropdownMenuItem(
                          value: ay.id,
                          child: Text('${ay.name}${ay.status == AccountStatus.active ? " (Active)" : ""}'),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => selectedAyId = val);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedClass,
                            decoration: const InputDecoration(labelText: 'Class'),
                            items: classList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                            onChanged: (val) {
                              if (val != null) setDlgState(() => selectedClass = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSection,
                            decoration: const InputDecoration(labelText: 'Section'),
                            items: sectionList.map((sec) => DropdownMenuItem(value: sec, child: Text('Section $sec'))).toList(),
                            onChanged: (val) {
                              if (val != null) setDlgState(() => selectedSection = val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.softLavender,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ayChanged = selectedAyId.isNotEmpty && selectedAyId != s.academicYearId;
                  if (ayChanged) {
                    final deps = await ref.read(studentServiceProvider).checkStudentDependencies(
                      s.id,
                      s.schoolId,
                    );
                    if (deps.isNotEmpty && dlgCtx.mounted) {
                      final confirmed = await showDialog<bool>(
                        context: dlgCtx,
                        builder: (confirmCtx) => AlertDialog(
                          title: const Text('Confirm Academic Year Change'),
                          content: Text(
                            'Changing the academic year may orphan or disconnect existing records for this student:\n\n'
                            '• ${deps.join("\n• ")}\n\n'
                            'Are you sure you want to proceed?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmCtx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.softCoral),
                              onPressed: () => Navigator.pop(confirmCtx, true),
                              child: const Text('Proceed', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                    }
                  }

                  if (dlgCtx.mounted) {
                    Navigator.pop(dlgCtx);
                  }

                  final fn = firstNameCtrl.text.trim();
                  final mn = middleNameCtrl.text.trim();
                  final ln = lastNameCtrl.text.trim();
                  final fullName = [fn, if (mn.isNotEmpty) mn, ln].join(' ');

                  final updated = s.copyWith(
                    name: fullName.isNotEmpty ? fullName : s.name,
                    firstName: fn.isNotEmpty ? fn : s.firstName,
                    middleName: mn,
                    lastName: ln.isNotEmpty ? ln : s.lastName,
                    rollNumber: rollNoCtrl.text.trim(),
                    className: selectedClass,
                    section: selectedSection,
                    academicYearId: selectedAyId.isNotEmpty ? selectedAyId : s.academicYearId,
                  );

                  try {
                    await ref.read(studentServiceProvider).updateStudent(updated);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Student profile updated successfully.'),
                          backgroundColor: AppColors.mutedGreen,
                        ),
                      );
                      _fetchStudent();
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Failed to update student: $e'),
                          backgroundColor: AppColors.softCoral,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }
}
