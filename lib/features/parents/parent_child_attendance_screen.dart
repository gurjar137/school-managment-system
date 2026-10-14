import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/widgets/app_back_button.dart';
import '../../data/models/student_model.dart';
import '../../data/models/attendance_model.dart';

class ParentChildAttendanceScreen extends ConsumerStatefulWidget {
  final String? studentId;

  const ParentChildAttendanceScreen({super.key, this.studentId});

  @override
  ConsumerState<ParentChildAttendanceScreen> createState() => _ParentChildAttendanceScreenState();
}

class _ParentChildAttendanceScreenState extends ConsumerState<ParentChildAttendanceScreen> {
  String? _activeChildId;
  StudentModel? _activeChild;
  List<StudentModel> _students = [];
  bool _isLoading = true;
  final int _selectedMonth = DateTime.now().month;
  final int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  void _loadStudents() async {
    final studentService = ref.read(studentServiceProvider);
    final students = await studentService.getAllStudents();
    if (mounted) {
      setState(() {
        _students = students;
        if (students.isNotEmpty) {
          if (widget.studentId != null && students.any((s) => s.id == widget.studentId)) {
            _activeChildId = widget.studentId;
            _activeChild = students.firstWhere((s) => s.id == widget.studentId);
          } else {
            _activeChildId = students.first.id;
            _activeChild = students.first;
          }
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = ref.watch(attendanceServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leadingWidth: AppBackButton.leadingWidth,
          leading: const AppBackButton(fallbackPath: '/attendance'),
          title: Text('Child Attendance Summary', style: AppTypography.titleLarge),
        ),
        body: const LoadingStateWidget(message: 'Loading attendance...'),
      );
    }

    if (_students.isEmpty || _activeChildId == null) {
      return Scaffold(
        appBar: AppBar(
          leadingWidth: AppBackButton.leadingWidth,
          leading: const AppBackButton(fallbackPath: '/attendance'),
          title: Text('Child Attendance Summary', style: AppTypography.titleLarge),
        ),
        body: const EmptyStateWidget(
          icon: Icons.person_search_rounded,
          title: 'No Students Added Yet',
          message: 'No student records exist for attendance tracking.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leadingWidth: AppBackButton.leadingWidth,
        leading: const AppBackButton(fallbackPath: '/attendance'),
        title: Text('Child Attendance Summary', style: AppTypography.titleLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Multi-Child Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _activeChildId,
                items: _students.map((s) {
                  final label = s.fullClassCode.isNotEmpty ? '${s.name} (Class ${s.fullClassCode})' : s.name;
                  return DropdownMenuItem(
                    value: s.id,
                    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _activeChildId = v;
                      _activeChild = _students.firstWhere((s) => s.id == v);
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Attendance Summary Metric Banner
          FutureBuilder<AttendanceSummaryModel>(
            future: attendanceService.getStudentAttendanceSummary(
              schoolId: _activeChild?.schoolId ?? '',
              studentId: _activeChildId!,
              studentName: _activeChild?.name ?? '',
            ),
            builder: (context, snapshot) {
              final summary = snapshot.data ?? AttendanceSummaryModel(
                studentId: _activeChildId!,
                studentName: _activeChild?.name ?? '',
                totalWorkingDays: 0,
                presentCount: 0,
                absentCount: 0,
                lateCount: 0,
                leaveCount: 0,
              );

              return BentoCard(
                backgroundColor: isDark ? AppColors.darkSurface : AppColors.midnightNavy,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('OVERALL ATTENDANCE PERCENTAGE', style: AppTypography.labelSmall.copyWith(color: AppColors.lavenderLight)),
                    const SizedBox(height: 6),
                    Text(
                      '${summary.attendancePercentage.toStringAsFixed(2)}%',
                      style: AppTypography.displayMedium.copyWith(fontSize: 34, color: AppColors.pureWhite, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricCol('Present', '${summary.presentCount}', AppColors.mutedGreen),
                        _buildMetricCol('Absent', '${summary.absentCount}', AppColors.softCoral),
                        _buildMetricCol('Late', '${summary.lateCount}', AppColors.warmAmber),
                        _buildMetricCol('Working', '${summary.totalWorkingDays}', AppColors.softLavender),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          Text('Monthly Attendance History', style: AppTypography.titleLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 12),

          FutureBuilder<List<AttendanceRecordModel>>(
            future: attendanceService.getMonthlyAttendanceForChild(
              schoolId: _activeChild?.schoolId ?? '',
              studentId: _activeChildId!,
              year: _selectedYear,
              month: _selectedMonth,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingStateWidget(message: 'Loading monthly attendance log...');
              }

              final logs = snapshot.data ?? [];

              if (logs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No attendance records found for this month.',
                      style: TextStyle(color: AppColors.coolGray),
                    ),
                  ),
                );
              }

              return Column(
                children: logs.map((log) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BentoCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.softLavender),
                              const SizedBox(width: 10),
                              Text(
                                '${log.attendanceDate.day}/${log.attendanceDate.month}/${log.attendanceDate.year}',
                                style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          _buildStatusBadge(log.status),
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
    );
  }

  Widget _buildMetricCol(String label, String val, Color col) {
    return Column(
      children: [
        Text(val, style: AppTypography.titleLarge.copyWith(color: col, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.bodySmall.copyWith(color: AppColors.coolGrayLight)),
      ],
    );
  }

  Widget _buildStatusBadge(AttendanceStatus status) {
    Color col;
    String label;

    switch (status) {
      case AttendanceStatus.absent:
        col = AppColors.softCoral;
        label = 'ABSENT';
        break;
      case AttendanceStatus.late:
        col = AppColors.warmAmber;
        label = 'LATE';
        break;
      case AttendanceStatus.present:
      default:
        col = AppColors.mutedGreen;
        label = 'PRESENT';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: col.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: col, fontWeight: FontWeight.w900, fontSize: 10),
      ),
    );
  }
}
