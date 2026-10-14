import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_model.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';
import '../../core/utils/teacher_assignment_parser.dart';
import 'student_service.dart';
import 'tenant_resolver.dart';

class ClassAttendanceSummary {
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final Map<String, AttendanceStatus> attendanceMap;

  const ClassAttendanceSummary({
    required this.totalStudents,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    this.attendanceMap = const {},
  });

  int get unmarkedCount =>
      (totalStudents - presentCount - absentCount - lateCount).clamp(0, totalStudents);

  double get attendancePercentage =>
      totalStudents > 0 ? (presentCount / totalStudents * 100) : 0.0;
}

class AttendanceService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  Future<String> fetchActiveSchoolId({String? fallback}) async {
    return TenantResolver.resolveActiveSchoolId(
      client: _client,
      requestedSchoolId: fallback,
    );
  }

  Future<String?> fetchActiveAcademicYearId(String schoolId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final nowStr = DateTime.now().toIso8601String().split('T').first;
        final res = await _client!
            .from('academic_years')
            .select('id, start_date, end_date, status')
            .eq('school_id', schoolId);
        if (res.isNotEmpty) {
          final activeYears = res.where((y) => (y['status']?.toString().toLowerCase() == 'active')).toList();
          final matching = activeYears.where((ay) {
            final s = ay['start_date'] as String?;
            final e = ay['end_date'] as String?;
            if (s != null && e != null) {
              return s.compareTo(nowStr) <= 0 && e.compareTo(nowStr) >= 0;
            }
            return false;
          }).toList();
          if (matching.isNotEmpty) {
            return matching.first['id']?.toString();
          }
          if (activeYears.isNotEmpty) {
            return activeYears.first['id']?.toString();
          }
          return res.first['id']?.toString();
        }
      } catch (e) {
        debugPrint('[AttendanceService fetchActiveAcademicYearId Warning]: $e');
      }
    }
    return null;
  }

  // Local Mock Store for testing & offline mode
  final List<AttendanceRecordModel> _mockAttendance = [
    AttendanceRecordModel(
      id: 'att_1',
      schoolId: 'mock_school_1',
      academicYearId: 'mock_ay_1',
      studentId: 'mock_s1',
      classId: 'cls_8',
      sectionId: 'sec_8_a',
      attendanceDate: DateTime.now(),
      status: AttendanceStatus.present,
      markedBy: 'auth_teacher_1',
      markedAt: DateTime.now(),
    ),
    AttendanceRecordModel(
      id: 'att_2',
      schoolId: 'mock_school_1',
      academicYearId: 'mock_ay_1',
      studentId: 'mock_s2',
      classId: 'cls_8',
      sectionId: 'sec_8_a',
      attendanceDate: DateTime.now(),
      status: AttendanceStatus.absent,
      markedBy: 'auth_teacher_1',
      markedAt: DateTime.now(),
      remarks: 'Informed sick leave',
    ),
  ];

  // --- FETCH CLASS DAILY ATTENDANCE ---
  Future<List<AttendanceRecordModel>> fetchAttendanceForClass({
    required String schoolId,
    required String classId,
    required String sectionId,
    required DateTime date,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final dateStr = date.toIso8601String().substring(0, 10);

        List<String>? targetStudentIds;
        if (classId.isNotEmpty || sectionId.isNotEmpty) {
          var stuQuery = _client!.from('students').select('id');
          if (schoolId.isNotEmpty) {
            stuQuery = stuQuery.eq('school_id', schoolId);
          }
          if (classId.isNotEmpty) {
            stuQuery = stuQuery.eq('class_name', classId);
          }
          if (sectionId.isNotEmpty) {
            stuQuery = stuQuery.eq('section_name', sectionId);
          }
          final stuRows = await stuQuery;
          targetStudentIds = stuRows.map((r) => r['id'].toString()).toList();
          if (targetStudentIds.isEmpty) {
            return [];
          }
        }

        var query = _client!
            .from('attendance')
            .select()
            .eq('attendance_date', dateStr);

        if (schoolId.isNotEmpty) {
          query = query.eq('school_id', schoolId);
        }
        if (targetStudentIds != null && targetStudentIds.isNotEmpty) {
          query = query.inFilter('student_id', targetStudentIds);
        }

        final data = await query;
        return data.map((a) => _mapSupabaseToAttendanceModel(a)).toList();
      } catch (e) {
        debugPrint('[AttendanceService Supabase Error]: $e');
        rethrow;
      }
    }

    return [];
  }

  // --- SAVE / UPSERT ATTENDANCE RECORDS TO REAL SUPABASE TABLE ---
  Future<void> upsertAttendanceRecords(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) return;

    if (_client != null && SupabaseConfig.isConfigured) {
      final sanitized = records.map((r) => {
        'student_id': r['student_id'],
        'school_id': r['school_id'],
        'academic_year_id': r['academic_year_id'],
        'attendance_date': r['attendance_date'],
        'status': (r['status'] as String).toLowerCase(),
      }).toList();

      bool writeSuccess = false;
      dynamic lastWriteError;

      // 1. Try secure RPC first
      try {
        final rpcRes = await _client!.rpc('record_teacher_attendance', params: {
          'p_records': sanitized,
        });
        if (rpcRes != null && (rpcRes['success'] == true || rpcRes is Map)) {
          writeSuccess = true;
          debugPrint('[AttendanceService] RPC record_teacher_attendance succeeded: $rpcRes');
        }
      } catch (e) {
        debugPrint('[AttendanceService RPC notice]: $e');
        lastWriteError = e;
      }

      // 2. If RPC not available or failed, try direct PostgREST upsert
      if (!writeSuccess) {
        try {
          final res = await _client!.from('attendance').upsert(
            sanitized,
            onConflict: 'student_id,attendance_date',
          ).select('id, student_id, attendance_date, status');

          writeSuccess = true;
          debugPrint('[AttendanceService] Direct upsert to public.attendance succeeded: ${res.length} rows returned.');
        } catch (e) {
          debugPrint('[AttendanceService Direct Upsert Error]: $e');
          lastWriteError = e;
        }
      }

      // 3. MANDATORY POST-WRITE VERIFICATION: Confirm records exist in public.attendance
      final targetDate = sanitized.first['attendance_date'] as String;
      final studentIds = sanitized.map((r) => r['student_id'] as String).toList();

      final verifyRes = await _client!
          .from('attendance')
          .select('student_id, attendance_date, status')
          .eq('attendance_date', targetDate)
          .inFilter('student_id', studentIds);

      if (verifyRes.isEmpty) {
        final errDetails = lastWriteError != null ? ' ($lastWriteError)' : '';
        throw Exception('Attendance write verification failed: No records found in public.attendance for date $targetDate$errDetails');
      }

      debugPrint('[AttendanceService] Database verification confirmed ${verifyRes.length} records in public.attendance.');
      return;
    }

    // Local in-memory fallback ONLY for unconfigured test environments
    for (var r in records) {
      final stuId = r['student_id'] as String;
      final dateStr = r['attendance_date'] as String;
      final statusStr = (r['status'] as String).toLowerCase();
      AttendanceStatus status = AttendanceStatus.present;
      if (statusStr == 'absent') status = AttendanceStatus.absent;
      if (statusStr == 'late') status = AttendanceStatus.late;

      final idx = _mockAttendance.indexWhere((a) =>
          a.studentId == stuId &&
          a.attendanceDate.toIso8601String().substring(0, 10) == dateStr);

      final record = AttendanceRecordModel(
        id: 'att_${stuId}_$dateStr',
        schoolId: r['school_id'] as String,
        academicYearId: (r['academic_year_id'] as String?) ?? '',
        studentId: stuId,
        classId: '',
        sectionId: '',
        attendanceDate: DateTime.parse(dateStr),
        status: status,
        markedBy: 'teacher',
        markedAt: DateTime.now(),
      );

      if (idx != -1) {
        _mockAttendance[idx] = record;
      } else {
        _mockAttendance.add(record);
      }
    }
  }

  // --- FETCH PERSISTED ATTENDANCE RECORDS FROM SUPABASE ---
  Future<Map<String, AttendanceStatus>> fetchAttendanceForDate({
    required String schoolId,
    required String attendanceDate,
    List<String>? studentIds,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('attendance')
            .select('student_id, status')
            .eq('school_id', schoolId)
            .eq('attendance_date', attendanceDate);

        if (studentIds != null && studentIds.isNotEmpty) {
          query = query.inFilter('student_id', studentIds);
        }

        final List<dynamic> rows = await query;
        final map = <String, AttendanceStatus>{};
        for (final row in rows) {
          final sId = row['student_id']?.toString() ?? '';
          final rawStatus = (row['status']?.toString() ?? 'present').toLowerCase();
          if (sId.isNotEmpty) {
            if (rawStatus == 'absent') {
              map[sId] = AttendanceStatus.absent;
            } else if (rawStatus == 'late') {
              map[sId] = AttendanceStatus.late;
            } else {
              map[sId] = AttendanceStatus.present;
            }
          }
        }
        return map;
      } catch (e) {
        debugPrint('[AttendanceService fetchAttendanceForDate Warning]: $e');
      }
    }

    // Fallback for tests / offline
    final map = <String, AttendanceStatus>{};
    for (var a in _mockAttendance) {
      final dStr = a.attendanceDate.toIso8601String().substring(0, 10);
      if (dStr == attendanceDate && (studentIds == null || studentIds.contains(a.studentId))) {
        map[a.studentId] = a.status;
      }
    }
    return map;
  }

  // --- FETCH CLASS DAILY ATTENDANCE SUMMARY (EXACT SERVER-SIDE COUNTS) ---
  Future<ClassAttendanceSummary> getClassDailyAttendanceSummary({
    required String schoolId,
    String? academicYearId,
    required String className,
    required String section,
    required String attendanceDate,
    StudentService? studentService,
  }) async {
    final effectiveStudentService = studentService ?? StudentService();
    final effectiveSchoolId = schoolId.isNotEmpty
        ? schoolId
        : await effectiveStudentService.fetchActiveSchoolId();
    final effectiveAyId = (academicYearId != null && academicYearId.isNotEmpty)
        ? academicYearId
        : await effectiveStudentService.fetchActiveAcademicYearId(effectiveSchoolId);

    // 1. Exact server-side count of active students for this class & section
    final total = await effectiveStudentService.getStudentCount(
      schoolId: effectiveSchoolId,
      academicYearId: effectiveAyId,
      className: className,
      section: section,
      status: AccountStatus.active,
    );

    if (total == 0) {
      return const ClassAttendanceSummary(
        totalStudents: 0,
        presentCount: 0,
        absentCount: 0,
        lateCount: 0,
        attendanceMap: {},
      );
    }

    // 2. Exact set of student IDs belonging to this class & section
    final studentIds = await effectiveStudentService.getStudentIdsForClass(
      schoolId: effectiveSchoolId,
      academicYearId: effectiveAyId,
      className: className,
      section: section,
      status: AccountStatus.active,
    );

    // 3. Exact server-side attendance records for this date & school
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('attendance')
            .select('student_id, status')
            .eq('school_id', effectiveSchoolId)
            .eq('attendance_date', attendanceDate);

        if (effectiveAyId != null && effectiveAyId.isNotEmpty) {
          query = query.eq('academic_year_id', effectiveAyId);
        }

        final List<dynamic> rows = await query;
        int present = 0;
        int absent = 0;
        int late = 0;
        final map = <String, AttendanceStatus>{};

        for (final row in rows) {
          final sId = row['student_id']?.toString() ?? '';
          if (studentIds.contains(sId)) {
            final raw = (row['status']?.toString() ?? '').toLowerCase().trim();
            if (raw == 'present') {
              present++;
              map[sId] = AttendanceStatus.present;
            } else if (raw == 'absent') {
              absent++;
              map[sId] = AttendanceStatus.absent;
            } else if (raw == 'late') {
              late++;
              map[sId] = AttendanceStatus.late;
            }
          }
        }

        return ClassAttendanceSummary(
          totalStudents: total,
          presentCount: present,
          absentCount: absent,
          lateCount: late,
          attendanceMap: map,
        );
      } catch (e) {
        debugPrint('[AttendanceService getClassDailyAttendanceSummary Error]: $e');
      }
    }

    // Fallback for offline / mock test data
    int mockPresent = 0;
    int mockAbsent = 0;
    int mockLate = 0;
    final mockMap = <String, AttendanceStatus>{};

    for (final a in _mockAttendance) {
      final dStr = a.attendanceDate.toIso8601String().substring(0, 10);
      if (dStr == attendanceDate && studentIds.contains(a.studentId)) {
        if (a.status == AttendanceStatus.present) {
          mockPresent++;
          mockMap[a.studentId] = AttendanceStatus.present;
        } else if (a.status == AttendanceStatus.absent) {
          mockAbsent++;
          mockMap[a.studentId] = AttendanceStatus.absent;
        } else if (a.status == AttendanceStatus.late) {
          mockLate++;
          mockMap[a.studentId] = AttendanceStatus.late;
        }
      }
    }

    return ClassAttendanceSummary(
      totalStudents: total,
      presentCount: mockPresent,
      absentCount: mockAbsent,
      lateCount: mockLate,
      attendanceMap: mockMap,
    );
  }

  // --- SAVE / UPSERT DAILY CLASS ATTENDANCE (LEGACY ADAPTER) ---
  Future<void> saveClassAttendanceList(List<AttendanceRecordModel> records) async {
    await Future.delayed(const Duration(milliseconds: 250));

    final payload = records.map((r) => {
      'school_id': r.schoolId,
      'academic_year_id': r.academicYearId,
      'student_id': r.studentId,
      'attendance_date': r.attendanceDate.toIso8601String().substring(0, 10),
      'status': r.status.name.toLowerCase(),
    }).toList();

    await upsertAttendanceRecords(payload);
  }

  // --- GET STUDENT SUMMARY (LIVE SUPABASE QUERY & TEACHER ISOLATION) ---
  Future<AttendanceSummaryModel> getStudentAttendanceSummary({
    required String schoolId,
    required String studentId,
    String studentName = '',
    String? academicYearId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final user = _client!.auth.currentUser;
        String effectiveSchoolId = schoolId;

        // 1. Dynamic context resolution & Security verification
        if (user != null) {
          final profile = await _client!
              .from('profiles')
              .select('school_id, role, assigned_class, assigned_section')
              .eq('auth_user_id', user.id)
              .maybeSingle();

          if (profile != null) {
            final profileSchoolId = profile['school_id']?.toString();
            if (profileSchoolId != null && profileSchoolId.isNotEmpty) {
              effectiveSchoolId = profileSchoolId;
            }

            final role = profile['role']?.toString().toLowerCase();
            // Teacher isolation check
            if (role == 'teacher') {
              final tClass = profile['assigned_class']?.toString();
              final tSection = profile['assigned_section']?.toString();

              if (tClass == null || tClass.isEmpty || tClass == 'Not Assigned') {
                return AttendanceSummaryModel(
                  studentId: studentId,
                  studentName: studentName,
                  totalWorkingDays: 0,
                  presentCount: 0,
                  absentCount: 0,
                  lateCount: 0,
                  leaveCount: 0,
                );
              }

              // Fetch target student to verify assignment
              final studentRow = await _client!
                  .from('students')
                  .select('id, school_id, class_name, section_name')
                  .eq('id', studentId)
                  .maybeSingle();

              if (studentRow == null) {
                return AttendanceSummaryModel(
                  studentId: studentId,
                  studentName: studentName,
                  totalWorkingDays: 0,
                  presentCount: 0,
                  absentCount: 0,
                  lateCount: 0,
                  leaveCount: 0,
                );
              }

              // Cross-school check
              if (effectiveSchoolId.isNotEmpty && studentRow['school_id'] != effectiveSchoolId) {
                return AttendanceSummaryModel(
                  studentId: studentId,
                  studentName: studentName,
                  totalWorkingDays: 0,
                  presentCount: 0,
                  absentCount: 0,
                  lateCount: 0,
                  leaveCount: 0,
                );
              }

              // Cross-class / Cross-section check
              final parser = TeacherAssignmentParser(
                assignedClass: tClass,
                assignedSection: tSection,
              );
              final sClass = studentRow['class_name']?.toString() ?? '';
              final sSection = studentRow['section_name']?.toString() ?? '';
              if (!parser.matchesClassAndSection(sClass, sSection)) {
                return AttendanceSummaryModel(
                  studentId: studentId,
                  studentName: studentName,
                  totalWorkingDays: 0,
                  presentCount: 0,
                  absentCount: 0,
                  lateCount: 0,
                  leaveCount: 0,
                );
              }
            }
          }
        }

        if (effectiveSchoolId.isEmpty) {
          effectiveSchoolId = await fetchActiveSchoolId();
        }

        final effectiveAyId = (academicYearId != null && academicYearId.isNotEmpty)
            ? academicYearId
            : await fetchActiveAcademicYearId(effectiveSchoolId);

        // 2. Exact Supabase query for student attendance records
        var query = _client!
            .from('attendance')
            .select('status')
            .eq('school_id', effectiveSchoolId)
            .eq('student_id', studentId);

        if (effectiveAyId != null && effectiveAyId.isNotEmpty) {
          query = query.eq('academic_year_id', effectiveAyId);
        }

        final List<dynamic> rows = await query;

        int present = 0;
        int absent = 0;
        int late = 0;

        for (final row in rows) {
          final s = (row['status']?.toString() ?? '').toLowerCase().trim();
          if (s == 'present') {
            present++;
          } else if (s == 'absent') {
            absent++;
          } else if (s == 'late') {
            late++;
          }
        }

        return AttendanceSummaryModel(
          studentId: studentId,
          studentName: studentName,
          totalWorkingDays: rows.length,
          presentCount: present,
          absentCount: absent,
          lateCount: late,
          leaveCount: 0,
        );
      } catch (e) {
        debugPrint('[AttendanceService getStudentAttendanceSummary Warning]: $e');
      }
    }

    // Zero/empty summary if no rows or client unconfigured (NO MOCK FALLBACK)
    return AttendanceSummaryModel(
      studentId: studentId,
      studentName: studentName,
      totalWorkingDays: 0,
      presentCount: 0,
      absentCount: 0,
      lateCount: 0,
      leaveCount: 0,
    );
  }

  // --- GET MONTHLY ATTENDANCE LOG (LIVE SUPABASE QUERY & TEACHER ISOLATION) ---
  Future<List<AttendanceRecordModel>> getMonthlyAttendanceForChild({
    required String schoolId,
    required String studentId,
    required int year,
    required int month,
    String? academicYearId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final user = _client!.auth.currentUser;
        String effectiveSchoolId = schoolId;

        // 1. Dynamic context resolution & Security verification
        if (user != null) {
          final profile = await _client!
              .from('profiles')
              .select('school_id, role, assigned_class, assigned_section')
              .eq('auth_user_id', user.id)
              .maybeSingle();

          if (profile != null) {
            final profileSchoolId = profile['school_id']?.toString();
            if (profileSchoolId != null && profileSchoolId.isNotEmpty) {
              effectiveSchoolId = profileSchoolId;
            }

            final role = profile['role']?.toString().toLowerCase();
            // Teacher isolation check
            if (role == 'teacher') {
              final tClass = profile['assigned_class']?.toString();
              final tSection = profile['assigned_section']?.toString();

              if (tClass == null || tClass.isEmpty || tClass == 'Not Assigned') {
                return [];
              }

              // Fetch target student to verify assignment
              final studentRow = await _client!
                  .from('students')
                  .select('id, school_id, class_name, section_name')
                  .eq('id', studentId)
                  .maybeSingle();

              if (studentRow == null) {
                return [];
              }

              // Cross-school check
              if (effectiveSchoolId.isNotEmpty && studentRow['school_id'] != effectiveSchoolId) {
                return [];
              }

              // Cross-class / Cross-section check
              final parser = TeacherAssignmentParser(
                assignedClass: tClass,
                assignedSection: tSection,
              );
              final sClass = studentRow['class_name']?.toString() ?? '';
              final sSection = studentRow['section_name']?.toString() ?? '';
              if (!parser.matchesClassAndSection(sClass, sSection)) {
                return [];
              }
            }
          }
        }

        if (effectiveSchoolId.isEmpty) {
          effectiveSchoolId = await fetchActiveSchoolId();
        }

        final effectiveAyId = (academicYearId != null && academicYearId.isNotEmpty)
            ? academicYearId
            : await fetchActiveAcademicYearId(effectiveSchoolId);

        final startDate = '$year-${month.toString().padLeft(2, '0')}-01';
        final lastDay = DateTime(year, month + 1, 0).day;
        final endDate = '$year-${month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}';

        var filter = _client!
            .from('attendance')
            .select()
            .eq('school_id', effectiveSchoolId)
            .eq('student_id', studentId)
            .gte('attendance_date', startDate)
            .lte('attendance_date', endDate);

        if (effectiveAyId != null && effectiveAyId.isNotEmpty) {
          filter = filter.eq('academic_year_id', effectiveAyId);
        }

        final List<dynamic> rows = await filter.order('attendance_date', ascending: true);
        return rows.map((a) => _mapSupabaseToAttendanceModel(a)).toList();
      } catch (e) {
        debugPrint('[AttendanceService getMonthlyAttendanceForChild Warning]: $e');
      }
    }

    // Return empty list if no rows or client unconfigured (NO MOCK FALLBACK)
    return [];
  }

  AttendanceRecordModel _mapSupabaseToAttendanceModel(Map<String, dynamic> data) {
    return AttendanceRecordModel(
      id: data['id'],
      schoolId: data['school_id'],
      academicYearId: data['academic_year_id'],
      studentId: data['student_id'],
      classId: data['class_id'],
      sectionId: data['section_id'],
      attendanceDate: DateTime.tryParse(data['attendance_date'] ?? '') ?? DateTime.now(),
      status: _parseStatus(data['status']),
      markedBy: data['marked_by'] ?? '',
      markedAt: DateTime.tryParse(data['marked_at'] ?? '') ?? DateTime.now(),
      remarks: data['remarks'],
    );
  }

  AttendanceStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toUpperCase()) {
      case 'ABSENT':
        return AttendanceStatus.absent;
      case 'LATE':
        return AttendanceStatus.late;
      case 'PRESENT':
      default:
        return AttendanceStatus.present;
    }
  }
}
