import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/app_providers.dart';
import '../../core/widgets/reusable_widgets.dart';
import '../../core/utils/teacher_assignment_parser.dart';
import '../../data/models/student_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/services/attendance_service.dart';

class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  ConsumerState<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, AttendanceStatus> _attendanceMap = {};
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final repo = ref.watch(schoolRepositoryProvider);
    final attendanceService = ref.watch(attendanceServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final teacherParser = TeacherAssignmentParser(
      assignedClass: user?.assignedClass,
      assignedSection: user?.assignedSection,
    );
    final assignedClassDisplay = teacherParser.rawClass.isNotEmpty
        ? teacherParser.rawClass
        : (user?.assignedClass ?? '');
    final assignedSectionDisplay = teacherParser.rawSection.isNotEmpty
        ? teacherParser.rawSection
        : (user?.assignedSection ?? '');

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Attendance Register', style: AppTypography.titleLarge),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.mutedGreen),
            tooltip: 'Mark All Present',
            onPressed: () => _markAllPresent(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Class & Date Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.pureWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 16, color: AppColors.coolGray),
                        const SizedBox(width: 8),
                        Text(
                          assignedClassDisplay.isNotEmpty
                              ? (assignedClassDisplay.toLowerCase().startsWith('class')
                                  ? assignedClassDisplay
                                  : 'Class $assignedClassDisplay')
                              : 'Class --',
                          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.coolGray),
                        const SizedBox(width: 8),
                        Text(
                          assignedSectionDisplay.isNotEmpty
                              ? (assignedSectionDisplay.toLowerCase().startsWith('sec')
                                  ? assignedSectionDisplay
                                  : 'Section ${assignedSectionDisplay.toUpperCase()}')
                              : 'Section --',
                          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.softLavender.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.softLavender, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: AppTypography.titleSmall.copyWith(color: AppColors.softLavender, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<StudentModel>>(
              future: repo.getStudents(
                teacherAssignedClass: user?.assignedClass,
                teacherAssignedSection: user?.assignedSection,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingStateWidget(message: 'Loading class roster...');
                }

                final students = snapshot.data ?? [];

                if (!_isLoaded && students.isNotEmpty) {
                  for (var s in students) {
                    _attendanceMap[s.id] = s.todayAttendance;
                  }
                  _isLoaded = true;
                }

                if (students.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.person_off_rounded,
                    title: 'No Students Found',
                    message: 'No students enrolled in this section.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  itemBuilder: (context, idx) {
                    final student = students[idx];
                    final currentStatus = _attendanceMap[student.id] ?? AttendanceStatus.present;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: BentoCard(
                        child: Row(
                          children: [
                            AppAvatar(
                              imageUrl: student.avatarUrl,
                              name: student.name,
                              radius: 20,
                              borderColor: AppColors.softLavender,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(student.name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800)),
                                  Text('Adm: ${student.admissionNumber}', style: AppTypography.bodySmall.copyWith(color: AppColors.coolGray)),
                                ],
                              ),
                            ),

                            // Status Selector Chips
                            Row(
                              children: [
                                _buildStatusChip(student.id, AttendanceStatus.present, 'P', AppColors.mutedGreen, currentStatus),
                                const SizedBox(width: 4),
                                _buildStatusChip(student.id, AttendanceStatus.absent, 'A', AppColors.softCoral, currentStatus),
                                const SizedBox(width: 4),
                                _buildStatusChip(student.id, AttendanceStatus.late, 'L', AppColors.warmAmber, currentStatus),
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.pureWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.midnightNavy,
            foregroundColor: AppColors.pureWhite,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _isSaving ? null : () => _saveAttendance(attendanceService),
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.cloud_upload_rounded),
          label: Text(_isSaving ? 'Saving Attendance...' : 'Save & Sync Attendance', style: AppTypography.titleMedium.copyWith(color: AppColors.pureWhite)),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String studentId, AttendanceStatus status, String label, Color color, AttendanceStatus current) {
    final isSelected = current == status;
    return InkWell(
      onTap: () {
        setState(() {
          _attendanceMap[studentId] = status;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color, width: isSelected ? 2 : 1),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: isSelected ? AppColors.pureWhite : color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  void _markAllPresent() {
    setState(() {
      _attendanceMap.updateAll((key, value) => AttendanceStatus.present);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Marked all students as Present!')),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoaded = false;
      });
    }
  }

  Future<void> _saveAttendance(AttendanceService service) async {
    setState(() => _isSaving = true);

    final user = ref.read(authProvider);
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.softCoral, content: Text('Error: No active school associated with your account.')),
        );
      }
      return;
    }

    final ayId = await service.fetchActiveAcademicYearId(schoolId);
    if (ayId == null || ayId.isEmpty) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.softCoral, content: Text('Error: Active academic year could not be resolved for this school.')),
        );
      }
      return;
    }

    final markedBy = user?.id ?? 'teacher';

    final List<AttendanceRecordModel> records = [];
    _attendanceMap.forEach((studentId, status) {
      records.add(AttendanceRecordModel(
        id: 'att_${DateTime.now().millisecondsSinceEpoch}_$studentId',
        schoolId: schoolId,
        academicYearId: ayId,
        studentId: studentId,
        classId: '',
        sectionId: '',
        attendanceDate: _selectedDate,
        status: status,
        markedBy: markedBy,
        markedAt: DateTime.now(),
      ));
    });

    try {
      await service.saveClassAttendanceList(records);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: AppColors.mutedGreen, content: Text('Attendance saved & synchronized with Supabase!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.softCoral, content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }
}
