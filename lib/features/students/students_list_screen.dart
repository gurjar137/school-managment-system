import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/skeleton_loader.dart';
import '../../data/models/student_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/class_section_models.dart';

class StudentsListScreen extends ConsumerStatefulWidget {
  const StudentsListScreen({super.key});

  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  String _searchQuery = '';
  List<StudentModel> _allStudents = [];
  List<StudentModel> _filteredStudents = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _pageSize = 50;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  final List<String> _directoryClasses = List.generate(12, (i) => 'Class ${i + 1}');
  Map<String, int> _classStudentCounts = {};
  int _totalStudentCount = 0;
  int _activeAyStudentCount = 0;

  // Filter state
  String? _selectedAcademicYearId;
  List<AcademicYearModel> _academicYears = [];
  String _selectedClass = 'All';
  String _selectedSection = 'All';
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initData();
  }

  Future<void> _initData() async {
    await _loadAcademicYears();
    _loadHeaderMetrics();
    _loadStudents(reset: true);
  }

  Future<void> _loadAcademicYears() async {
    final user = ref.read(authProvider);
    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final schoolId = (activeProfile?.schoolId != null && activeProfile!.schoolId.isNotEmpty)
        ? activeProfile.schoolId
        : (user?.schoolId ?? '');

    try {
      final ays = await ref.read(academicYearServiceProvider).fetchAcademicYears(schoolId);
      if (mounted && ays.isNotEmpty) {
        setState(() {
          _academicYears = ays;
          if (_selectedAcademicYearId == null) {
            final active = ays.where((y) => y.status == AccountStatus.active || y.isCurrent).toList();
            _selectedAcademicYearId = active.isNotEmpty ? active.first.id : ays.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint('[StudentsListScreen _loadAcademicYears Error]: $e');
    }
  }

  Future<void> _loadHeaderMetrics() async {
    final user = ref.read(authProvider);
    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final schoolId = (activeProfile?.schoolId != null && activeProfile!.schoolId.isNotEmpty)
        ? activeProfile.schoolId
        : (user?.schoolId ?? '');
    final repo = ref.read(schoolRepositoryProvider);

    try {
      final total = await repo.getStudentCount(schoolId: schoolId);
      final activeAy = await repo.getStudentCount(
        schoolId: schoolId,
        academicYearId: _selectedAcademicYearId,
        status: AccountStatus.active,
      );
      final classCounts = await repo.getClassStudentCounts(
        classNames: _directoryClasses,
        schoolId: schoolId,
        academicYearId: _selectedAcademicYearId,
      );
      if (mounted) {
        setState(() {
          _totalStudentCount = total;
          _activeAyStudentCount = activeAy;
          _classStudentCounts = classCounts;
        });
      }
    } catch (e) {
      debugPrint('[StudentsListScreen _loadHeaderMetrics Error]: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      _loadMoreStudents();
    }
  }

  AccountStatus? _resolveStatusFilter() {
    if (_selectedStatus == 'ACTIVE') return AccountStatus.active;
    if (_selectedStatus == 'INACTIVE') return AccountStatus.inactive;
    return null;
  }

  void _loadStudents({bool reset = true}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _offset = 0;
        _hasMore = true;
        _isLoadingMore = false;
      });
    }

    final user = ref.read(authProvider);
    final repo = ref.read(schoolRepositoryProvider);

    final isTeacher = user?.role == UserRole.teacher;
    final teacherClass = isTeacher ? user?.assignedClass : null;
    final teacherSection = isTeacher ? user?.assignedSection : null;

    try {
      final students = await repo.getStudents(
        query: _searchQuery,
        className: isTeacher ? null : (_selectedClass == 'All' ? null : _selectedClass),
        section: isTeacher ? null : (_selectedSection == 'All' ? null : _selectedSection),
        academicYearId: _selectedAcademicYearId,
        status: _resolveStatusFilter(),
        isTeacher: isTeacher,
        teacherAssignedClass: teacherClass,
        teacherAssignedSection: teacherSection,
        limit: _pageSize,
        offset: 0,
      );

      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
          _offset = students.length;
          _hasMore = students.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadMoreStudents() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final user = ref.read(authProvider);
    final repo = ref.read(schoolRepositoryProvider);

    final isTeacher = user?.role == UserRole.teacher;
    final teacherClass = isTeacher ? user?.assignedClass : null;
    final teacherSection = isTeacher ? user?.assignedSection : null;

    try {
      final nextBatch = await repo.getStudents(
        query: _searchQuery,
        className: isTeacher ? null : (_selectedClass == 'All' ? null : _selectedClass),
        section: isTeacher ? null : (_selectedSection == 'All' ? null : _selectedSection),
        academicYearId: _selectedAcademicYearId,
        status: _resolveStatusFilter(),
        isTeacher: isTeacher,
        teacherAssignedClass: teacherClass,
        teacherAssignedSection: teacherSection,
        limit: _pageSize,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          final existingIds = _allStudents.map((s) => s.id).toSet();
          final uniqueBatch = nextBatch.where((s) => !existingIds.contains(s.id)).toList();
          _allStudents.addAll(uniqueBatch);
          _filteredStudents = _allStudents;
          _offset += nextBatch.length;
          _hasMore = nextBatch.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onSearchChanged(String val) {
    _searchQuery = val;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      _loadStudents(reset: true);
    });
  }





  Widget _buildHeaderMetricBadges(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.softLavender.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.people_alt_outlined, color: AppColors.softLavender, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Students',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                        ),
                        Text(
                          '$_totalStudentCount',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mutedGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_user_outlined, color: AppColors.mutedGreen, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.mutedGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Active AY Students',
                                style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$_activeAyStudentCount',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.mutedGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassDirectoryStrip(bool isDark) {
    if (_classStudentCounts.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _directoryClasses.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final c = _directoryClasses[index];
          final count = _classStudentCounts[c] ?? 0;
          final isSelected = _selectedClass == c;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedClass = isSelected ? 'All' : c;
              });
              _loadStudents(reset: true);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.softLavender.withValues(alpha: 0.15)
                    : (isDark ? AppColors.darkSurface : AppColors.pureWhite),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.softLavender : AppColors.borderLight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c,
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isSelected ? AppColors.softLavender : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count Students',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.coolGray,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(bool isTeacher) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // 1. Academic Year Dropdown
          if (!isTeacher && _academicYears.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAcademicYearId,
                  hint: const Text('Academic Year', style: TextStyle(fontSize: 12)),
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.midnightNavy),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Academic Years', style: TextStyle(fontSize: 12)),
                    ),
                    ..._academicYears.map((ay) => DropdownMenuItem<String>(
                      value: ay.id,
                      child: Text(
                        '${ay.name}${ay.status == AccountStatus.active ? " (Active)" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedAcademicYearId = val;
                    });
                    _loadHeaderMetrics();
                    _loadStudents(reset: true);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 2. Class Filter
          if (!isTeacher) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.pureWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClass,
                  style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.midnightNavy),
                  items: [
                    const DropdownMenuItem<String>(value: 'All', child: Text('All Classes', style: TextStyle(fontSize: 12))),
                    ..._directoryClasses.map((c) => DropdownMenuItem<String>(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedClass = val);
                      _loadStudents(reset: true);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 3. Section Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSection,
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.midnightNavy),
                items: [
                  const DropdownMenuItem<String>(value: 'All', child: Text('All Sections', style: TextStyle(fontSize: 12))),
                  ...['A', 'B', 'C', 'D', 'E', 'F'].map((s) => DropdownMenuItem<String>(value: s, child: Text('Section $s', style: const TextStyle(fontSize: 12)))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedSection = val);
                    _loadStudents(reset: true);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. Status Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.midnightNavy),
                items: const [
                  DropdownMenuItem<String>(value: 'ALL', child: Text('All Status', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem<String>(value: 'ACTIVE', child: Text('Active Only', style: TextStyle(fontSize: 12, color: AppColors.mutedGreen))),
                  DropdownMenuItem<String>(value: 'INACTIVE', child: Text('Inactive Only', style: TextStyle(fontSize: 12, color: AppColors.warmAmber))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatus = val);
                    _loadStudents(reset: true);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isTeacher = user?.role == UserRole.teacher;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedAy = _academicYears.where((y) => y.id == _selectedAcademicYearId).toList();
    final currentAyName = selectedAy.isNotEmpty ? selectedAy.first.name : '2026-2027';

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallbackPath: '/home'),
        leadingWidth: 96.0,
        title: Text(
          isTeacher ? 'My Class ${user?.assignedClass ?? ""} Roster' : 'Campus Student Directory',
          style: AppTypography.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add Student',
            onPressed: () async {
              await context.push('/add-student');
              _loadHeaderMetrics();
              _loadStudents(reset: true);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Metrics (Total Students & Active AY Students)
          if (!isTeacher) _buildHeaderMetricBadges(isDark),

          // Class Directory Cards Strip
          if (!isTeacher) _buildClassDirectoryStrip(isDark),

          // Search Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: CustomSearchBar(
              hintText: isTeacher
                  ? 'Search Class ${user?.assignedClass ?? ""} students...'
                  : 'Search name, roll no, admission no or parent...',
              onChanged: _onSearchChanged,
              onFilterTap: null,
            ),
          ),

          // Multi-filter Bar (Academic Year, Class, Section, Status)
          _buildFilterBar(isTeacher),
          const SizedBox(height: 4),

          // Count Bar Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isTeacher
                        ? '${_filteredStudents.length} Students in Class ${user?.assignedClass ?? ""}'
                        : (_searchQuery.trim().isNotEmpty
                            ? '${_filteredStudents.length} Students Found'
                            : (_totalStudentCount > 0
                                ? '$_totalStudentCount Students Registered'
                                : '${_filteredStudents.length} Students Registered')),
                    style: AppTypography.labelMedium.copyWith(color: AppColors.coolGray, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Academic Year $currentAyName',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                ),
              ],
            ),
          ),
          const Divider(),

          // Student List View
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _loadHeaderMetrics();
                _loadStudents(reset: true);
              },
              child: _isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 6,
                      itemBuilder: (context, index) => const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: StudentCardSkeleton(),
                      ),
                    )
                  : _filteredStudents.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 60),
                            EmptyStateWidget(
                              icon: Icons.person_search_rounded,
                              title: isTeacher && (user?.assignedClass == null || user!.assignedClass!.trim().isEmpty || user.assignedClass == 'Not Assigned')
                                  ? 'No Class Assigned'
                                  : 'No Students Found',
                              message: isTeacher
                                  ? (user?.assignedClass != null && user!.assignedClass!.trim().isNotEmpty && user.assignedClass != 'Not Assigned'
                                      ? 'No students enrolled yet in Class ${user.assignedClass}.'
                                      : 'You have not been assigned to a class or section yet. Please contact your school administrator to assign your class.')
                                  : 'No students found. Tap the "+" button above to register a new student.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredStudents.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _filteredStudents.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _isLoadingMore
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        )
                                      : TextButton(
                                          onPressed: _loadMoreStudents,
                                          child: const Text('Load More Students'),
                                        ),
                                ),
                              );
                            }
                            final student = _filteredStudents[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildStudentTile(student),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: isTeacher
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/add-student');
                _loadHeaderMetrics();
                _loadStudents(reset: true);
              },
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Student'),
            ),
    );
  }

  Widget _buildStudentTile(StudentModel student) {
    return BentoCard(
      onTap: () async {
        await context.push('/student/${student.id}');
        _loadHeaderMetrics();
        _loadStudents(reset: true);
      },
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              AppAvatar(
                imageUrl: student.avatarUrl,
                name: student.name,
                radius: 22,
                borderColor: AppColors.softLavender,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            student.name,
                            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.midnightNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              student.fullClassCode.startsWith('Class')
                                  ? student.fullClassCode
                                  : 'Class ${student.fullClassCode}',
                              style: AppTypography.labelSmall.copyWith(fontSize: 9),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                      const SizedBox(height: 2),
                      Text(
                        'Roll No: ${student.rollNumber} • Adm: ${student.admissionNumber}',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${student.attendancePercentage.toStringAsFixed(1)}%',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: student.attendancePercentage >= 90 ? AppColors.mutedGreen : AppColors.warmAmber,
                      ),
                    ),
                    Text(
                      'Attendance',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: AppColors.coolGray, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Parent: ${student.fatherName}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling ${student.fatherName} (${student.fatherMobile})')),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 14, color: AppColors.mutedGreen),
                      const SizedBox(width: 4),
                      Text(
                        student.fatherMobile,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.mutedGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }
}
