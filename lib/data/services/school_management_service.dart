import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/school_management_models.dart';
import '../models/student_model.dart';
import '../models/academic_models.dart' hide TimetableSlotModel;
import '../models/fee_models.dart';
import '../models/user_model.dart';
import 'student_service.dart';
import 'teacher_service.dart';
import 'access_service.dart';
import '../repositories/school_repository.dart';
import 'tenant_resolver.dart';

class SchoolManagementService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> resolveActiveSchoolId([String? schoolId]) async {
    return TenantResolver.resolveActiveSchoolId(
      client: _client,
      requestedSchoolId: schoolId,
    );
  }

  StudentModel _mapSupabaseToStudentModel(Map<String, dynamic> data) {
    String resolvedClassName = '';
    if (data['class_name'] != null && data['class_name'].toString().trim().isNotEmpty) {
      resolvedClassName = data['class_name'].toString().trim();
    } else if (data['class'] != null && data['class'].toString().trim().isNotEmpty) {
      resolvedClassName = data['class'].toString().trim();
    }

    String resolvedSectionName = '';
    if (data['section_name'] != null && data['section_name'].toString().trim().isNotEmpty) {
      resolvedSectionName = data['section_name'].toString().trim();
    } else if (data['section'] != null && data['section'].toString().trim().isNotEmpty) {
      resolvedSectionName = data['section'].toString().trim();
    }

    final fullName = data['full_name'] ?? '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
    final admNo = data['admission_number']?.toString() ?? '';

    return StudentModel(
      id: data['id']?.toString() ?? '',
      schoolId: data['school_id']?.toString() ?? '',
      academicYearId: data['academic_year_id']?.toString() ?? '',
      classId: data['class_id']?.toString() ?? '',
      sectionId: data['section_id']?.toString() ?? '',
      studentCode: admNo.isNotEmpty ? admNo : 'STU',
      parentAccessCode: data['parent_access_code']?.toString() ?? '',
      name: fullName.isNotEmpty ? fullName : 'Student',
      rollNumber: data['roll_number']?.toString() ?? '',
      admissionNumber: admNo,
      className: resolvedClassName,
      section: resolvedSectionName,
      avatarUrl: data['profile_photo_url']?.toString() ?? 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=150',
      attendancePercentage: (data['attendance_pct'] as num?)?.toDouble() ?? 100.0,
      todayAttendance: AttendanceStatus.present,
      dateOfBirth: data['date_of_birth']?.toString() ?? '',
      gender: data['gender']?.toString() ?? 'Male',
      fatherName: data['father_name']?.toString() ?? '',
      fatherMobile: data['phone']?.toString() ?? data['father_mobile']?.toString() ?? '',
      motherName: data['mother_name']?.toString() ?? '',
      motherMobile: data['mother_mobile']?.toString() ?? '',
      guardianName: data['guardian_name']?.toString() ?? data['father_name']?.toString() ?? '',
      emergencyContact: data['emergency_contact']?.toString() ?? data['phone']?.toString() ?? '',
      parentEmail: data['email']?.toString() ?? data['parent_email']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      pinCode: data['postal_code']?.toString() ?? data['pin_code']?.toString() ?? '',
      bloodGroup: data['blood_group']?.toString() ?? 'O+',
      medicalNotes: data['medical_notes']?.toString() ?? '',
      importantNotes: data['important_notes']?.toString() ?? '',
      status: (data['status']?.toString().toUpperCase() == 'INACTIVE' || data['status']?.toString().toUpperCase() == 'DEACTIVATED')
          ? AccountStatus.inactive
          : AccountStatus.active,
      totalFee: (data['total_fee'] as num?)?.toDouble() ?? 0.0,
      paidFee: (data['paid_fee'] as num?)?.toDouble() ?? 0.0,
      pendingFee: (data['pending_fee'] as num?)?.toDouble() ?? 0.0,
      feeStatus: PaymentStatus.paid,
      paymentHistory: const [],
    );
  }

  TeacherModel _mapSupabaseToTeacherModel(Map<String, dynamic> data, {String? defaultSchoolId}) {
    final subList = data['subjects'] is List
        ? List<String>.from(data['subjects'])
        : (data['subject'] != null ? [data['subject'].toString()] : const <String>[]);
    final rawClass = data['assigned_class']?.toString() ?? data['class']?.toString() ??
        (data['class_name'] != null ? data['class_name'].toString() : '');
    final rawSection = data['assigned_section']?.toString() ?? data['section']?.toString() ?? '';
    final rawName = (data['full_name'] ?? data['name'] ?? '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}').toString().trim();
    final teacherName = rawName.isNotEmpty ? rawName : 'Teacher';
    final statusStr = data['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final accountStatus = (statusStr == 'INACTIVE' || statusStr == 'SUSPENDED')
        ? AccountStatus.inactive
        : AccountStatus.active;
    final idStr = data['id']?.toString() ?? '';
    final empId = data['employee_id']?.toString() ?? data['employee_code']?.toString() ??
        'EMP-${idStr.length >= 4 ? idStr.substring(0, 4).toUpperCase() : "0000"}';

    return TeacherModel(
      id: idStr,
      schoolId: data['school_id']?.toString() ?? defaultSchoolId ?? '',
      employeeId: empId,
      name: teacherName,
      email: data['email']?.toString() ?? '',
      subjects: subList,
      assignedClass: rawClass,
      assignedSection: rawSection,
      totalStudents: 0,
      avatarUrl: data['profile_photo_url']?.toString() ?? data['avatar_url']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      designation: data['designation']?.toString() ?? 'Teacher',
      status: accountStatus,
      joiningDate: data['joining_date']?.toString(),
      authUserId: data['auth_user_id']?.toString(),
    );
  }

  final AccessService _accessService = AccessService();
  final List<AttendanceCorrectionModel> _corrections = [];
  final List<TeacherLeaveModel> _teacherLeaves = [];
  final List<SchoolMeetingModel> _meetings = [];
  final Map<String, List<StudentDocumentModel>> _studentDocs = {};

  String _leavesCacheKey([String? schoolId]) => 'cached_teacher_leaves_${schoolId?.trim() ?? "default"}';
  String _meetingsCacheKey([String? schoolId]) => 'cached_school_meetings_${schoolId?.trim() ?? "default"}';

  Future<void> _persistLeaves([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _leavesCacheKey(schoolId);
      final jsonList = _teacherLeaves.map((l) => l.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[SchoolManagementService Persist Leaves Warning]: $e');
    }
  }

  Future<void> _restoreLeaves([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _leavesCacheKey(schoolId);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final model = TeacherLeaveModel.fromJson(item);
              if (!_teacherLeaves.any((l) => l.id == model.id)) {
                _teacherLeaves.add(model);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SchoolManagementService Restore Leaves Warning]: $e');
    }
  }

  Future<void> _persistMeetings([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _meetingsCacheKey(schoolId);
      final jsonList = _meetings.map((m) => m.toJson(schoolId: schoolId)).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[SchoolManagementService Persist Meetings Warning]: $e');
    }
  }

  Future<void> _restoreMeetings([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _meetingsCacheKey(schoolId);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final model = SchoolMeetingModel.fromJson(item);
              if (!_meetings.any((m) => m.id == model.id)) {
                _meetings.add(model);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SchoolManagementService Restore Meetings Warning]: $e');
    }
  }

  SchoolSettingsModel _schoolSettings = const SchoolSettingsModel(
    schoolId: '',
    name: 'School',
    logoUrl: 'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=150',
    address: 'Campus Address',
    phone: '',
    email: '',
    academicYear: '2026-27',
    activeClasses: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
    activeSubjects: ['Mathematics', 'Science', 'English', 'Hindi', 'Computer', 'Social Studies'],
  );

  SchoolManagementService();

  // --- CATEGORIZED GLOBAL SEARCH ---
  Future<CategorizedSearchResult> performCategorizedSearch(String query) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const CategorizedSearchResult(students: [], teachers: [], feePayments: [], receipts: [], results: []);
    }

    final q = trimmed.toLowerCase();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final schoolId = await resolveActiveSchoolId();
        if (schoolId == null || schoolId.isEmpty) {
          return const CategorizedSearchResult(students: [], teachers: [], feePayments: [], receipts: [], results: []);
        }

        // 1. Live Students Search
        List<StudentModel> matchedStudents = [];
        try {
          final sData = await _client!
              .from('students')
              .select()
              .eq('school_id', schoolId)
              .or('first_name.ilike.%$q%,last_name.ilike.%$q%,admission_number.ilike.%$q%')
              .limit(20);
          matchedStudents = sData.map((row) => _mapSupabaseToStudentModel(row)).toList();
        } catch (e) {
          debugPrint('[SchoolManagementService Student Search Warning]: $e');
        }
        if (matchedStudents.isEmpty) {
          try {
            final fallbackStudents = await StudentService().getAllStudents(
              schoolId: schoolId,
              query: q,
              limit: 20,
            );
            matchedStudents = fallbackStudents;
          } catch (_) {}
        }

        // 2. Live Teachers Search (profiles with role=teacher)
        List<TeacherModel> matchedTeachers = [];
        try {
          final tData = await _client!
              .from('profiles')
              .select()
              .eq('school_id', schoolId)
              .ilike('role', '%teacher%')
              .or('full_name.ilike.%$q%,email.ilike.%$q%')
              .limit(20);
          matchedTeachers = tData.map((row) => _mapSupabaseToTeacherModel(row, defaultSchoolId: schoolId)).toList();
        } catch (e) {
          debugPrint('[SchoolManagementService Teacher Search Warning]: $e');
        }
        if (matchedTeachers.isEmpty) {
          try {
            final fallbackTeachers = await TeacherService().getTeachers(
              schoolId: schoolId,
              query: q,
            );
            matchedTeachers = fallbackTeachers;
          } catch (_) {}
        }

        // 3. Live Fee Payments Search
        List<FeePayment> matchedPayments = [];
        List<FeeReceiptModel> receipts = [];
        try {
          final fData = await _client!
              .from('fee_payments')
              .select()
              .eq('school_id', schoolId)
              .or('receipt_number.ilike.%$q%,notes.ilike.%$q%,payment_method.ilike.%$q%')
              .limit(20);
          matchedPayments = fData.map((row) => FeePayment.fromJson(row)).toList();
          receipts = fData
              .where((r) => r['receipt_number'] != null && r['receipt_number'].toString().isNotEmpty)
              .map((row) => FeeReceiptModel.fromJson(row))
              .toList();
        } catch (e) {
          debugPrint('[SchoolManagementService Fee Search Warning]: $e');
        }

        return CategorizedSearchResult(
          students: matchedStudents,
          teachers: matchedTeachers,
          feePayments: matchedPayments,
          receipts: receipts,
          results: const [],
        );
      } catch (e) {
        debugPrint('[SchoolManagementService Global Search Error]: $e');
      }
    }

    return const CategorizedSearchResult(students: [], teachers: [], feePayments: [], receipts: [], results: []);
  }

  // --- ATTENDANCE CORRECTION ---
  Future<List<AttendanceCorrectionModel>> getPendingCorrectionRequests() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _corrections.where((c) => c.status == 'pending').toList();
  }

  Future<void> submitCorrectionRequest(AttendanceCorrectionModel req) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _corrections.insert(0, req);
  }

  Future<void> approveCorrection(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _corrections.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _corrections[idx] = _corrections[idx].copyWith(status: 'approved');
    }
  }

  Future<void> rejectCorrection(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _corrections.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _corrections[idx] = _corrections[idx].copyWith(status: 'rejected');
    }
  }

  // --- TEACHER LEAVE MANAGEMENT ---
  Future<List<TeacherLeaveModel>> getAllLeaveRequests({
    String? schoolId,
    String? teacherId,
    String? statusFilter,
  }) async {
    await _restoreLeaves(schoolId);

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        var query = client.from('leave_requests').select('*');
        if (schoolId != null && schoolId.isNotEmpty) {
          query = query.eq('school_id', schoolId);
        }
        if (teacherId != null && teacherId.isNotEmpty) {
          query = query.or('teacher_id.eq.$teacherId,requester_id.eq.$teacherId');
        }
        final res = await query.order('created_at', ascending: false);
        if (res is List) {
          final dbList = res.map((row) => TeacherLeaveModel.fromJson(row)).toList();
          for (final item in dbList) {
            final idx = _teacherLeaves.indexWhere((l) => l.id == item.id);
            if (idx != -1) {
              _teacherLeaves[idx] = item;
            } else {
              _teacherLeaves.add(item);
            }
          }
          await _persistLeaves(schoolId);
        }
      } catch (e) {
        debugPrint('[SchoolManagementService getAllLeaveRequests Warning]: $e');
      }
    }

    if (_teacherLeaves.isEmpty) {
      final now = DateTime.now();
      _teacherLeaves.addAll([
        TeacherLeaveModel(
          id: 'leave_init_1',
          schoolId: schoolId ?? '',
          teacherId: 'tch_init_01',
          teacherName: 'Sunita Sharma',
          leaveType: 'Casual',
          fromDate: now.add(const Duration(days: 2)),
          toDate: now.add(const Duration(days: 4)),
          reason: 'Attending family medical appointment out of station.',
          status: 'pending',
          appliedAt: now.subtract(const Duration(hours: 4)),
        ),
        TeacherLeaveModel(
          id: 'leave_init_2',
          schoolId: schoolId ?? '',
          teacherId: 'tch_init_02',
          teacherName: 'Rajesh Khanna',
          leaveType: 'Sick',
          fromDate: now.subtract(const Duration(days: 5)),
          toDate: now.subtract(const Duration(days: 3)),
          reason: 'Severe viral throat infection and vocal rest.',
          status: 'approved',
          adminRemarks: 'Approved. Reliever assigned to Class 9.',
          appliedAt: now.subtract(const Duration(days: 6)),
          reviewedAt: now.subtract(const Duration(days: 5)),
          reviewedBy: 'Lead Administrator',
        ),
      ]);
      await _persistLeaves(schoolId);
    }

    return _teacherLeaves.where((l) {
      if (schoolId != null && schoolId.isNotEmpty && l.schoolId.isNotEmpty && l.schoolId != schoolId) {
        return false;
      }
      if (teacherId != null && teacherId.isNotEmpty && l.teacherId != teacherId) {
        return false;
      }
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        if (l.status.toLowerCase() != statusFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  Future<List<TeacherLeaveModel>> getPendingLeaveRequests({String? schoolId}) async {
    return getAllLeaveRequests(schoolId: schoolId, statusFilter: 'pending');
  }

  Future<void> applyTeacherLeave(TeacherLeaveModel req, {SchoolRepository? repo}) async {
    if (req.reason.trim().isEmpty) {
      throw Exception('Please provide a reason for the leave request.');
    }
    if (req.fromDate.isAfter(req.toDate)) {
      throw Exception('Leave start date must be before or equal to the end date.');
    }

    final effectiveSchoolId = req.schoolId.isNotEmpty
        ? req.schoolId
        : (await resolveActiveSchoolId() ?? '');

    final enriched = req.copyWith(schoolId: effectiveSchoolId);
    final existingIdx = _teacherLeaves.indexWhere((l) => l.id == enriched.id);
    if (existingIdx != -1) {
      _teacherLeaves[existingIdx] = enriched;
    } else {
      _teacherLeaves.insert(0, enriched);
    }
    await _persistLeaves(effectiveSchoolId);

    // 1. Notify School Administrators of new request
    final notif = NotificationModel(
      id: 'notif_leave_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: effectiveSchoolId,
      recipientRole: 'school_admin',
      title: 'New Leave Application: ${enriched.teacherName}',
      message: '${enriched.teacherName} applied for ${enriched.leaveType} Leave (${enriched.fromDate.day}/${enriched.fromDate.month} - ${enriched.toDate.day}/${enriched.toDate.month}). Reason: ${enriched.reason}',
      timestamp: DateTime.now(),
      category: 'Leaves',
      isUnread: true,
      relatedRecordId: enriched.id,
      relatedRecordType: 'leave',
    );
    if (repo != null) {
      await repo.addNotification(notif);
    }

    // 2. Log Activity
    _accessService.logActivity(
      'Leave Application Submitted',
      '${enriched.teacherName} applied for ${enriched.leaveType} Leave',
      'Leaves',
      adminName: enriched.teacherName,
    );

    // 3. Supabase Sync
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('leave_requests').insert(enriched.toJson());
      } catch (e) {
        debugPrint('[SchoolManagementService applyTeacherLeave Supabase Warning]: $e');
      }
    }
  }

  Future<void> approveLeave(
    String id,
    String remarks, {
    String? adminName,
    SchoolRepository? repo,
  }) async {
    final idx = _teacherLeaves.indexWhere((l) => l.id == id);
    if (idx != -1) {
      final updated = _teacherLeaves[idx].copyWith(
        status: 'approved',
        adminRemarks: remarks.isNotEmpty ? remarks : 'Approved by Administration',
        reviewedAt: DateTime.now(),
        reviewedBy: adminName ?? 'Lead Administrator',
      );
      _teacherLeaves[idx] = updated;
      await _persistLeaves(updated.schoolId);

      // Notify Requester
      final notif = NotificationModel(
        id: 'notif_leave_app_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: updated.schoolId,
        recipientId: updated.teacherId,
        title: 'Leave Application Approved',
        message: 'Your ${updated.leaveType} leave request has been approved by ${adminName ?? "Administration"}.${remarks.isNotEmpty ? " Remarks: $remarks" : ""}',
        timestamp: DateTime.now(),
        category: 'Leaves',
        isUnread: true,
        relatedRecordId: updated.id,
        relatedRecordType: 'leave',
      );
      if (repo != null) {
        await repo.addNotification(notif);
      }

      _accessService.logActivity(
        'Leave Application Approved',
        'Approved leave for ${updated.teacherName}. ${remarks.isNotEmpty ? "Remarks: $remarks" : ""}',
        'Leaves',
        adminName: adminName ?? 'School Administrator',
      );

      final client = _client;
      if (client != null && SupabaseConfig.isConfigured) {
        try {
          await client.from('leave_requests').update({
            'status': 'APPROVED',
            'admin_remarks': remarks,
            'reviewed_by': adminName ?? 'Lead Administrator',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', id);
        } catch (e) {
          debugPrint('[SchoolManagementService approveLeave Warning]: $e');
        }
      }
    }
  }

  Future<void> rejectLeave(
    String id,
    String remarks, {
    String? adminName,
    SchoolRepository? repo,
  }) async {
    final idx = _teacherLeaves.indexWhere((l) => l.id == id);
    if (idx != -1) {
      final updated = _teacherLeaves[idx].copyWith(
        status: 'rejected',
        adminRemarks: remarks.isNotEmpty ? remarks : 'Rejected due to administrative scheduling',
        reviewedAt: DateTime.now(),
        reviewedBy: adminName ?? 'Lead Administrator',
      );
      _teacherLeaves[idx] = updated;
      await _persistLeaves(updated.schoolId);

      // Notify Requester
      final notif = NotificationModel(
        id: 'notif_leave_rej_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: updated.schoolId,
        recipientId: updated.teacherId,
        title: 'Leave Application Rejected',
        message: 'Your ${updated.leaveType} leave request was rejected.${remarks.isNotEmpty ? " Reason: $remarks" : ""}',
        timestamp: DateTime.now(),
        category: 'Leaves',
        isUnread: true,
        relatedRecordId: updated.id,
        relatedRecordType: 'leave',
      );
      if (repo != null) {
        await repo.addNotification(notif);
      }

      _accessService.logActivity(
        'Leave Application Rejected',
        'Rejected leave for ${updated.teacherName}. Reason: $remarks',
        'Leaves',
        adminName: adminName ?? 'School Administrator',
      );

      final client = _client;
      if (client != null && SupabaseConfig.isConfigured) {
        try {
          await client.from('leave_requests').update({
            'status': 'REJECTED',
            'admin_remarks': remarks,
            'reviewed_by': adminName ?? 'Lead Administrator',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', id);
        } catch (e) {
          debugPrint('[SchoolManagementService rejectLeave Warning]: $e');
        }
      }
    }
  }

  Future<void> cancelLeave(
    String id,
    String teacherId, {
    SchoolRepository? repo,
  }) async {
    final idx = _teacherLeaves.indexWhere((l) => l.id == id && l.teacherId == teacherId);
    if (idx != -1 && _teacherLeaves[idx].status == 'pending') {
      final updated = _teacherLeaves[idx].copyWith(status: 'cancelled');
      _teacherLeaves[idx] = updated;
      await _persistLeaves(updated.schoolId);

      _accessService.logActivity(
        'Leave Application Cancelled',
        '${updated.teacherName} cancelled their pending leave request',
        'Leaves',
        adminName: updated.teacherName,
      );

      final client = _client;
      if (client != null && SupabaseConfig.isConfigured) {
        try {
          await client.from('leave_requests').update({
            'status': 'CANCELLED',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', id);
        } catch (e) {
          debugPrint('[SchoolManagementService cancelLeave Warning]: $e');
        }
      }
    }
  }

  // --- MEETINGS & CAMPUS EVENTS ---
  Future<List<SchoolMeetingModel>> getMeetings({
    String? schoolId,
    UserRole? userRole,
    String? statusFilter,
  }) async {
    await _restoreMeetings(schoolId);

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        var query = client.from('events').select('*');
        if (schoolId != null && schoolId.isNotEmpty) {
          query = query.eq('school_id', schoolId);
        }
        final res = await query.order('meeting_date', ascending: true);
        if (res is List) {
          final dbList = res.map((row) => SchoolMeetingModel.fromJson(row)).toList();
          for (final item in dbList) {
            final idx = _meetings.indexWhere((m) => m.id == item.id);
            if (idx != -1) {
              _meetings[idx] = item;
            } else {
              _meetings.add(item);
            }
          }
          await _persistMeetings(schoolId);
        }
      } catch (e) {
        debugPrint('[SchoolManagementService getMeetings Warning]: $e');
      }
    }

    if (_meetings.isEmpty) {
      final now = DateTime.now();
      _meetings.addAll([
        SchoolMeetingModel(
          id: 'meeting_1',
          schoolId: schoolId ?? '',
          title: 'All-Faculty Academic Review Meeting',
          agenda: 'Review term-end curriculum pacing, student assessments, and attendance records.',
          meetingDate: now.add(const Duration(days: 1)),
          startTime: '02:30 PM',
          endTime: '04:00 PM',
          locationOrLink: 'Conference Room Alpha',
          organizerId: 'admin_principal',
          organizerName: 'Principal Office',
          targetAudience: 'All Staff',
          status: 'Scheduled',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        SchoolMeetingModel(
          id: 'meeting_2',
          schoolId: schoolId ?? '',
          title: 'Department Heads Coordination Call',
          agenda: 'Discuss lab requirements, sports day logistics, and annual festival budget.',
          meetingDate: now.add(const Duration(days: 4)),
          startTime: '11:00 AM',
          endTime: '12:00 PM',
          locationOrLink: 'https://meet.google.com/school-hod-sync',
          organizerId: 'admin_principal',
          organizerName: 'Academic Director',
          targetAudience: 'Department Heads',
          status: 'Scheduled',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ]);
      await _persistMeetings(schoolId);
    }

    return _meetings.where((m) {
      if (schoolId != null && schoolId.isNotEmpty && m.schoolId.isNotEmpty && m.schoolId != schoolId) {
        return false;
      }
      if (statusFilter != null && statusFilter.isNotEmpty && statusFilter != 'all') {
        if (m.status.toLowerCase() != statusFilter.toLowerCase()) return false;
      }
      return true;
    }).toList();
  }

  Future<void> createMeeting(
    SchoolMeetingModel meeting, {
    SchoolRepository? repo,
  }) async {
    if (meeting.title.trim().isEmpty) {
      throw Exception('Please provide a title for the meeting.');
    }

    final effectiveSchoolId = meeting.schoolId.isNotEmpty
        ? meeting.schoolId
        : (await resolveActiveSchoolId() ?? '');

    final enriched = meeting.copyWith(schoolId: effectiveSchoolId);
    final existingIdx = _meetings.indexWhere((m) => m.id == enriched.id);
    if (existingIdx != -1) {
      _meetings[existingIdx] = enriched;
    } else {
      _meetings.insert(0, enriched);
    }
    await _persistMeetings(effectiveSchoolId);

    // Notify Participants
    final notif = NotificationModel(
      id: 'notif_meeting_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: effectiveSchoolId,
      recipientRole: enriched.targetAudience,
      title: 'Meeting Scheduled: ${enriched.title}',
      message: 'Date: ${enriched.meetingDate.day}/${enriched.meetingDate.month}/${enriched.meetingDate.year} at ${enriched.startTime} (${enriched.locationOrLink}). Agenda: ${enriched.agenda}',
      timestamp: DateTime.now(),
      category: 'Meetings',
      isUnread: true,
      relatedRecordId: enriched.id,
      relatedRecordType: 'meeting',
    );
    if (repo != null) {
      await repo.addNotification(notif);
    }

    _accessService.logActivity(
      'Scheduled Campus Meeting',
      'Scheduled "${enriched.title}" for ${enriched.targetAudience}',
      'Meetings',
      adminName: enriched.organizerName,
    );

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('events').insert(enriched.toJson(schoolId: effectiveSchoolId));
      } catch (e) {
        debugPrint('[SchoolManagementService createMeeting Warning]: $e');
      }
    }
  }

  Future<void> updateMeeting(
    SchoolMeetingModel meeting, {
    SchoolRepository? repo,
  }) async {
    final idx = _meetings.indexWhere((m) => m.id == meeting.id);
    if (idx != -1) {
      _meetings[idx] = meeting;
      await _persistMeetings(meeting.schoolId);

      final notif = NotificationModel(
        id: 'notif_meet_upd_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: meeting.schoolId,
        recipientRole: meeting.targetAudience,
        title: 'Meeting Rescheduled: ${meeting.title}',
        message: 'Updated to ${meeting.meetingDate.day}/${meeting.meetingDate.month}/${meeting.meetingDate.year} at ${meeting.startTime} (${meeting.locationOrLink}).',
        timestamp: DateTime.now(),
        category: 'Meetings',
        isUnread: true,
        relatedRecordId: meeting.id,
        relatedRecordType: 'meeting',
      );
      if (repo != null) {
        await repo.addNotification(notif);
      }

      _accessService.logActivity(
        'Rescheduled Campus Meeting',
        'Updated "${meeting.title}" to ${meeting.meetingDate.day}/${meeting.meetingDate.month}',
        'Meetings',
        adminName: meeting.organizerName,
      );

      final client = _client;
      if (client != null && SupabaseConfig.isConfigured) {
        try {
          await client.from('events').update(meeting.toJson()).eq('id', meeting.id);
        } catch (e) {
          debugPrint('[SchoolManagementService updateMeeting Warning]: $e');
        }
      }
    }
  }

  Future<void> cancelMeeting(
    String id,
    String reason, {
    String? adminName,
    SchoolRepository? repo,
  }) async {
    final idx = _meetings.indexWhere((m) => m.id == id);
    if (idx != -1) {
      final updated = _meetings[idx].copyWith(
        status: 'Cancelled',
        cancelReason: reason,
      );
      _meetings[idx] = updated;
      await _persistMeetings(updated.schoolId);

      final notif = NotificationModel(
        id: 'notif_meet_canc_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: updated.schoolId,
        recipientRole: updated.targetAudience,
        title: 'Meeting Cancelled: ${updated.title}',
        message: 'The meeting scheduled for ${updated.meetingDate.day}/${updated.meetingDate.month} has been cancelled.${reason.isNotEmpty ? " Reason: $reason" : ""}',
        timestamp: DateTime.now(),
        category: 'Meetings',
        isUnread: true,
        relatedRecordId: updated.id,
        relatedRecordType: 'meeting',
      );
      if (repo != null) {
        await repo.addNotification(notif);
      }

      _accessService.logActivity(
        'Cancelled Campus Meeting',
        'Cancelled "${updated.title}". Reason: $reason',
        'Meetings',
        adminName: adminName ?? 'School Administrator',
      );

      final client = _client;
      if (client != null && SupabaseConfig.isConfigured) {
        try {
          await client.from('events').update({
            'status': 'Cancelled',
            'cancel_reason': reason,
          }).eq('id', id);
        } catch (e) {
          debugPrint('[SchoolManagementService cancelMeeting Warning]: $e');
        }
      }
    }
  }

  // --- TIMETABLE ---
  Future<List<TimetableSlotModel>> getTimetableForClass(String className) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [];
  }

  // --- STUDENT DOCUMENTS ---
  Future<List<StudentDocumentModel>> getStudentDocuments(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _studentDocs[studentId] ?? [];
  }

  Future<void> uploadStudentDocument(StudentDocumentModel doc) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_studentDocs.containsKey(doc.studentId)) {
      _studentDocs[doc.studentId] = [];
    }
    _studentDocs[doc.studentId]!.insert(0, doc);
  }

  // --- SCHOOL SETTINGS ---
  Future<SchoolSettingsModel> getSchoolSettings() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _schoolSettings;
  }

  Future<void> updateSchoolSettings(SchoolSettingsModel updated) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _schoolSettings = updated;
  }
}
