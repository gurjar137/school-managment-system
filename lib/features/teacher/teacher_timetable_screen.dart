import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../data/models/class_section_models.dart';
import '../../data/models/timetable_model.dart';
import '../../data/models/user_model.dart';

/// Modern, Mobile-First, Read-Only Published Timetable Screen for Teacher App.
/// 
/// Strictly displays timetable entries where:
/// - teacher_profile_id = authenticated teacher
/// - school_id = authenticated teacher's school_id
/// - status = PUBLISHED
class TeacherTimetableScreen extends ConsumerStatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  ConsumerState<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends ConsumerState<TeacherTimetableScreen> {
  int _selectedTab = 0; // 0 = Today, 1 = Week View
  bool _isLoading = true;
  String? _errorMessage;

  List<AcademicYearModel> _academicYears = [];
  AcademicYearModel? _selectedYear;

  List<TimetableEntryModel> _publishedEntries = [];
  int _selectedWeekDay = 1; // 1 = Monday ... 6 = Saturday

  @override
  void initState() {
    super.initState();
    // Default selected day in week view matches today (or Monday if Sunday)
    final todayWeekday = DateTime.now().weekday;
    _selectedWeekDay = (todayWeekday >= 1 && todayWeekday <= 6) ? todayWeekday : 1;

    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = ref.read(authProvider);
    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final effectiveSchoolId = user?.schoolId?.trim().isNotEmpty == true
        ? user!.schoolId!.trim()
        : activeProfile?.schoolId.trim() ?? '';
    final effectiveTeacherId = user?.id.trim().isNotEmpty == true
        ? user!.id.trim()
        : activeProfile?.id.trim() ?? '';

    if (effectiveSchoolId.isEmpty || effectiveTeacherId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authenticated teacher session found. Please log in as a teacher.';
      });
      return;
    }

    final isInactive = user?.status == AccountStatus.inactive || activeProfile?.status == AccountStatus.inactive;
    if (isInactive) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Teacher profile is inactive. Please contact your school administrator.';
      });
      return;
    }

    try {
      final effectiveSchoolId = user?.schoolId?.trim().isNotEmpty == true
          ? user!.schoolId!.trim()
          : ref.read(authProvider.notifier).activeProfile?.schoolId.trim() ?? '';

      // 1. Fetch Academic Years scoped strictly to the teacher's school
      final ayService = ref.read(academicYearServiceProvider);
      final years = await ayService.fetchAcademicYears(effectiveSchoolId);
      final currentYear = AcademicYearOption.resolveCurrent(years);

      _academicYears = years;
      _selectedYear = currentYear ?? (years.isNotEmpty ? years.first : null);

      // 2. Fetch Teacher's Published Timetable
      await _loadPublishedTimetable();
    } catch (e) {
      debugPrint('[TeacherTimetableScreen _initData error]: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load teacher schedule: $e';
        });
      }
    }
  }

  Future<void> _loadPublishedTimetable() async {
    final user = ref.read(authProvider);
    final schoolId = user?.schoolId?.trim().isNotEmpty == true
        ? user!.schoolId!.trim()
        : ref.read(authProvider.notifier).activeProfile?.schoolId.trim() ?? '';
    final teacherId = user?.id.trim().isNotEmpty == true
        ? user!.id.trim()
        : ref.read(authProvider.notifier).activeProfile?.id.trim() ?? '';
    final teacherName = user?.name.trim() ?? ref.read(authProvider.notifier).activeProfile?.name ?? '';

    if (schoolId.isEmpty || teacherId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final activeProfile = ref.read(authProvider.notifier).activeProfile;
    final isInactive = user?.status == AccountStatus.inactive || activeProfile?.status == AccountStatus.inactive;
    if (isInactive) {
      if (mounted) {
        setState(() {
          _publishedEntries = [];
          _isLoading = false;
        });
      }
      return;
    }

    final timetableService = ref.read(timetableServiceProvider);
    final entries = await timetableService.fetchTeacherPublishedTimetable(
      schoolId: schoolId,
      teacherProfileId: teacherId,
      teacherName: teacherName,
      academicYearId: _selectedYear?.id,
    );

    if (mounted) {
      setState(() {
        _publishedEntries = entries;
        _isLoading = false;
      });
    }
  }

  // --- TIME & STATUS HELPERS ---
  int get _nowMinutes {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  int get _todayWeekday => DateTime.now().weekday; // 1=Mon ... 7=Sun

  List<TimetableEntryModel> get _todayEntries {
    if (_todayWeekday > 6) return []; // Sunday has no regular school periods
    return _publishedEntries
        .where((e) => e.dayOfWeek == _todayWeekday && e.isPublished && !e.isCancelled)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  List<TimetableEntryModel> get _selectedDayEntries {
    return _publishedEntries
        .where((e) => e.dayOfWeek == _selectedWeekDay && e.isPublished && !e.isCancelled)
        .toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }

  TimetableEntryModel? get _currentPeriod {
    final nowMin = _nowMinutes;
    for (final e in _todayEntries) {
      if (nowMin >= e.startMinutes && nowMin <= e.endMinutes) {
        return e;
      }
    }
    return null;
  }

  TimetableEntryModel? get _nextPeriod {
    final nowMin = _nowMinutes;
    for (final e in _todayEntries) {
      if (e.startMinutes > nowMin) {
        return e;
      }
    }
    return null;
  }

  Color _getSubjectColor(String subjectName) {
    final colors = [
      const Color(0xFF4F46E5), // Indigo
      const Color(0xFF059669), // Emerald
      const Color(0xFFD97706), // Amber
      const Color(0xFFDC2626), // Coral
      const Color(0xFF2563EB), // Blue
      const Color(0xFF0D9488), // Teal
      const Color(0xFF9333EA), // Purple
      const Color(0xFFEA580C), // Orange
    ];
    final hash = subjectName.hashCode.abs();
    return colors[hash % colors.length];
  }

  IconData _getSubjectIcon(String subjectName) {
    final s = subjectName.toLowerCase();
    if (s.contains('math')) return Icons.calculate_outlined;
    if (s.contains('physic') || s.contains('chem') || s.contains('bio') || s.contains('scien')) {
      return Icons.science_outlined;
    }
    if (s.contains('eng') || s.contains('lit') || s.contains('lang')) return Icons.menu_book_outlined;
    if (s.contains('hist') || s.contains('civic') || s.contains('social')) return Icons.public_outlined;
    if (s.contains('geo')) return Icons.explore_outlined;
    if (s.contains('art') || s.contains('draw') || s.contains('craft')) return Icons.palette_outlined;
    if (s.contains('music')) return Icons.music_note_outlined;
    if (s.contains('sport') || s.contains('phys') || s.contains('pe') || s.contains('pt')) {
      return Icons.sports_basketball_outlined;
    }
    if (s.contains('comp') || s.contains('it') || s.contains('code')) return Icons.computer_outlined;
    return Icons.school_outlined;
  }

  String _formatRoom(String room) {
    final trimmed = room.trim();
    if (trimmed.toLowerCase().startsWith('room') ||
        trimmed.toLowerCase().startsWith('lab') ||
        trimmed.toLowerCase().startsWith('hall')) {
      return trimmed;
    }
    return 'Room $trimmed';
  }

  String _formatClassSection(TimetableEntryModel slot) {
    final cName = slot.className ?? 'Class';
    final sName = slot.sectionName;
    if (sName != null && sName.isNotEmpty) {
      return '$cName $sName';
    }
    return cName;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.pureWhite,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'My Timetable',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.mutedGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.mutedGreen, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 11, color: AppColors.mutedGreen),
                      const SizedBox(width: 4),
                      Text(
                        'PUBLISHED',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.mutedGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${user?.name ?? "Teacher"} • ${_selectedYear?.name ?? "2026-2027"} Session',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.coolGray,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          // Academic Year Selector
          if (_academicYears.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AcademicYearModel>(
                  value: _selectedYear,
                  isDense: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  items: _academicYears.map((ay) {
                    return DropdownMenuItem(
                      value: ay,
                      child: Text(ay.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedYear = val);
                      _loadPublishedTimetable();
                    }
                  },
                ),
              ),
            )
          else if (_selectedYear != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _selectedYear!.name,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.midnightNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Schedule',
            onPressed: _loadPublishedTimetable,
          ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: LoadingStateWidget(message: 'Loading your published timetable...'));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: AppTypography.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initData,
                style: FilledButton.styleFrom(backgroundColor: AppColors.midnightNavy),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_publishedEntries.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return Column(
      children: [
        // Modern Segmented Control for Today / Week View
        _buildSegmentedControl(isDark),

        // Active View
        Expanded(
          child: _selectedTab == 0 ? _buildTodayView(isDark) : _buildWeekView(isDark),
        ),
      ],
    );
  }

  // --- MODERN SEGMENTED CONTROL ---
  Widget _buildSegmentedControl(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Today Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? (isDark ? AppColors.darkSurface : AppColors.pureWhite)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.today_rounded,
                      size: 16,
                      color: _selectedTab == 0
                          ? (isDark ? AppColors.pureWhite : AppColors.midnightNavy)
                          : AppColors.coolGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Today',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _selectedTab == 0
                            ? (isDark ? AppColors.pureWhite : AppColors.midnightNavy)
                            : AppColors.coolGray,
                      ),
                    ),
                    if (_todayEntries.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppColors.midnightNavy : AppColors.coolGray.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_todayEntries.length}',
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Week View Tab
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? (isDark ? AppColors.darkSurface : AppColors.pureWhite)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_view_week_rounded,
                      size: 16,
                      color: _selectedTab == 1
                          ? (isDark ? AppColors.pureWhite : AppColors.midnightNavy)
                          : AppColors.coolGray,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Week View',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _selectedTab == 1
                            ? (isDark ? AppColors.pureWhite : AppColors.midnightNavy)
                            : AppColors.coolGray,
                      ),
                    ),
                    if (_publishedEntries.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppColors.mutedGreen : AppColors.coolGray.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_publishedEntries.length}',
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.softLavender.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_outlined, size: 52, color: AppColors.midnightNavy),
            ),
            const SizedBox(height: 20),
            Text(
              'No published timetable yet',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your school administrator has not published a timetable for you.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.coolGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _initData,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.midnightNavy,
                side: const BorderSide(color: AppColors.midnightNavy),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check for Updates', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // --- TODAY VIEW ---
  Widget _buildTodayView(bool isDark) {
    final entries = _todayEntries;
    final current = _currentPeriod;
    final next = _nextPeriod;

    return RefreshIndicator(
      onRefresh: _loadPublishedTimetable,
      color: AppColors.midnightNavy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
        // 1. Current / Next Period Hero Highlight Banner
        if (current != null)
          _buildCurrentPeriodHero(current, isDark)
        else if (next != null)
          _buildNextPeriodHero(next, isDark)
        else if (entries.isNotEmpty && _nowMinutes > entries.last.endMinutes)
          _buildDayCompletedCard(isDark),

        // 2. Today Summary Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.midnightNavy),
                  const SizedBox(width: 8),
                  Text(
                    _getTodayFormattedString(),
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.midnightNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  entries.isEmpty ? '0 Periods' : '${entries.length} Period${entries.length == 1 ? "" : "s"}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.midnightNavy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Chronological List of Today's Period Cards or Day-Off State
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(
                  _todayWeekday == 7 ? Icons.beach_access_rounded : Icons.event_available_rounded,
                  size: 44,
                  color: AppColors.coolGray.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  _todayWeekday == 7 ? 'Sunday - School Holiday' : 'No Classes Scheduled for Today',
                  style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  _todayWeekday == 7
                      ? 'Enjoy your weekend! View the Week tab for upcoming classes.'
                      : 'You do not have any periods scheduled on this day.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _selectedTab = 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.midnightNavy,
                    side: const BorderSide(color: AppColors.midnightNavy),
                  ),
                  icon: const Icon(Icons.calendar_view_week_rounded, size: 16),
                  label: const Text('View Weekly Schedule'),
                ),
              ],
            ),
          )
        else
          ...entries.map((slot) => _buildTeacherPeriodCard(slot, isDark, isTodayView: true)),
      ],
      ),
    );
  }

  // --- HERO: CURRENT PERIOD ---
  Widget _buildCurrentPeriodHero(TimetableEntryModel slot, bool isDark) {
    final endsIn = slot.endMinutes - _nowMinutes;
    final accentColor = _getSubjectColor(slot.subjectName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warmAmber.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warmAmber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_fill_rounded, size: 12, color: AppColors.midnightNavy),
                    SizedBox(width: 4),
                    Text(
                      'CURRENT PERIOD',
                      style: TextStyle(
                        color: AppColors.midnightNavy,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  endsIn > 0 ? 'Ends in $endsIn min' : 'Ending now',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getSubjectIcon(slot.subjectName), size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.subjectName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatClassSection(slot),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(
                '${slot.startTime} – ${slot.endTime}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const SizedBox(width: 12),
              if (slot.room != null && slot.room!.isNotEmpty) ...[
                Icon(Icons.meeting_room_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  _formatRoom(slot.room!),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                '${slot.durationMinutes} min',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HERO: NEXT PERIOD ---
  Widget _buildNextPeriodHero(TimetableEntryModel slot, bool isDark) {
    final startsIn = slot.startMinutes - _nowMinutes;
    final accentColor = _getSubjectColor(slot.subjectName);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mutedGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'NEXT PERIOD',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  startsIn > 0 ? 'Starts in $startsIn min' : 'Starting shortly',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getSubjectIcon(slot.subjectName), size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      slot.subjectName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatClassSection(slot),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.access_time_filled_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(
                '${slot.startTime} – ${slot.endTime}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const SizedBox(width: 12),
              if (slot.room != null && slot.room!.isNotEmpty) ...[
                Icon(Icons.meeting_room_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  _formatRoom(slot.room!),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                '${slot.durationMinutes} min',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DAY COMPLETED CARD ---
  Widget _buildDayCompletedCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mutedGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mutedGreen.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.task_alt_rounded, color: AppColors.mutedGreen, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'All scheduled teaching periods completed for today!',
              style: TextStyle(
                color: AppColors.mutedGreen,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WEEK VIEW ---
  Widget _buildWeekView(bool isDark) {
    final days = [
      {'val': 1, 'name': 'Monday', 'short': 'Mon'},
      {'val': 2, 'name': 'Tuesday', 'short': 'Tue'},
      {'val': 3, 'name': 'Wednesday', 'short': 'Wed'},
      {'val': 4, 'name': 'Thursday', 'short': 'Thu'},
      {'val': 5, 'name': 'Friday', 'short': 'Fri'},
      {'val': 6, 'name': 'Saturday', 'short': 'Sat'},
    ];

    final currentDayEntries = _selectedDayEntries;

    return Column(
      children: [
        // Horizontal Day Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
            border: Border(
              bottom: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: days.map((d) {
                final val = d['val'] as int;
                final name = d['name'] as String;
                final isSelected = _selectedWeekDay == val;
                final isToday = val == _todayWeekday;
                final count = _publishedEntries
                    .where((e) => e.dayOfWeek == val && e.isPublished && !e.isCancelled)
                    .length;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$name ($count)',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 12,
                            color: isSelected
                                ? AppColors.pureWhite
                                : (isDark ? AppColors.pureWhite : AppColors.midnightNavy),
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppColors.warmAmber : AppColors.mutedGreen,
                            ),
                          ),
                        ],
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.midnightNavy,
                    checkmarkColor: AppColors.pureWhite,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onSelected: (s) {
                      if (s) setState(() => _selectedWeekDay = val);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Vertically stacked period cards for selected day
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPublishedTimetable,
            color: AppColors.midnightNavy,
            child: currentDayEntries.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.event_busy_rounded, size: 40, color: AppColors.coolGray.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'No periods scheduled for ${_getDayName(_selectedWeekDay)}',
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You have no assigned classes on this day.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: currentDayEntries.length,
                    itemBuilder: (ctx, idx) {
                      final slot = currentDayEntries[idx];
                      return _buildTeacherPeriodCard(slot, isDark);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // --- TEACHER PERIOD CARD WIDGET ---
  Widget _buildTeacherPeriodCard(TimetableEntryModel slot, bool isDark, {bool isTodayView = false}) {
    final accentColor = _getSubjectColor(slot.subjectName);
    final isNow = isTodayView && _isOngoingNow(slot);
    final startsIn = isTodayView ? (slot.startMinutes - _nowMinutes) : null;
    final endsIn = isTodayView ? (slot.endMinutes - _nowMinutes) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNow ? AppColors.amberDark : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
          width: isNow ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isNow ? AppColors.amberDark.withValues(alpha: 0.15) : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: isNow ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: isNow ? 6 : 4.5,
              color: isNow ? AppColors.amberDark : accentColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Row 1: Time range + Duration pill + Status / Ongoing Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            '${slot.startTime} – ${slot.endTime}',
                            style: AppTypography.labelSmall.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${slot.durationMinutes} min',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.coolGray,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    if (slot.periodNumber != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'P${slot.periodNumber}',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.coolGray,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                if (isNow)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.amberDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_fill_rounded, size: 10, color: AppColors.pureWhite),
                        const SizedBox(width: 3),
                        Text(
                          endsIn != null && endsIn > 0 ? 'NOW ($endsIn m)' : 'NOW',
                          style: const TextStyle(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isTodayView && startsIn != null && startsIn > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.midnightNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Starts in $startsIn m',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.midnightNavy,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.mutedGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PUBLISHED',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.mutedGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Subject Icon + Title
            Row(
              children: [
                Icon(_getSubjectIcon(slot.subjectName), size: 17, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    slot.subjectName,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.pureWhite : AppColors.midnightNavy,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: Class & Section + Room details
            Row(
              children: [
                // Class & Section Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.softLavender.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 13, color: AppColors.midnightNavy),
                      const SizedBox(width: 5),
                      Text(
                        _formatClassSection(slot),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.midnightNavy,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Room Chip
                if (slot.room != null && slot.room!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 13, color: AppColors.coolGray),
                        const SizedBox(width: 5),
                        Text(
                          _formatRoom(slot.room!),
                          style: AppTypography.bodySmall.copyWith(
                            color: isDark ? AppColors.pureWhite : const Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    ],
    ),
    ),
    );
  }

  bool _isOngoingNow(TimetableEntryModel slot) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes >= slot.startMinutes && currentMinutes <= slot.endMinutes;
  }

  String _getTodayFormattedString() {
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dayNames[now.weekday - 1];
    final month = monthNames[now.month - 1];
    return '$day, $month ${now.day}';
  }

  String _getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }
}
