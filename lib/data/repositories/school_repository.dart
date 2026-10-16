import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/student_model.dart';
import '../models/academic_models.dart';
import '../models/user_model.dart';
import '../services/student_service.dart';
import '../services/teacher_service.dart';
import '../services/library_service.dart';
import '../services/transport_service.dart';
import '../services/access_service.dart';
import '../mock/mock_data.dart';
import '../../core/utils/teacher_assignment_parser.dart';
import '../../core/utils/uuid_helper.dart';

class SchoolRepository {
  final StudentService _studentService;
  final TeacherService _teacherService;
  final LibraryService _libraryService;
  final TransportService _transportService;
  final AccessService _accessService = AccessService();
  final List<ClassroomModel> _classrooms = [];
  final List<HomeworkModel> _homework = [];
  final List<ExamModel> _exams = [];
  final List<NoticeModel> _notices = [];
  final List<LeaveRequestModel> _leaveRequests = [];
  final List<FeeRecordModel> _fees = [];
  final List<NotificationModel> _notifications = [];

  SchoolRepository({
    StudentService? studentService,
    TeacherService? teacherService,
    LibraryService? libraryService,
    TransportService? transportService,
  })  : _studentService = studentService ?? StudentService(),
        _teacherService = teacherService ?? TeacherService(),
        _libraryService = libraryService ?? LibraryService(),
        _transportService = transportService ?? TransportService();

  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  // Get Students (Supports Scoping & Filtering from Supabase)
  Future<List<StudentModel>> getStudents({
    String? schoolId,
    String? query,
    String? className,
    String? section,
    String? academicYearId,
    AccountStatus? status,
    bool isTeacher = false,
    String? teacherAssignedClass, // e.g. "12 - f", "12-F", "Class 12"
    String? teacherAssignedSection, // e.g. "F", "f"
    String? gender,
    String? attendanceStatus,
    String? feeStatus,
    int limit = 50,
    int offset = 0,
  }) async {
    final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
        ? schoolId
        : await _studentService.fetchActiveSchoolId();
    String? effectiveAcademicYearId = academicYearId;
    if (effectiveAcademicYearId == null || effectiveAcademicYearId.isEmpty) {
      try {
        effectiveAcademicYearId = await _studentService.fetchActiveAcademicYearId(effectiveSchoolId);
      } catch (_) {}
    }

    final isTeacherQuery = isTeacher || teacherAssignedClass != null || teacherAssignedSection != null;
    // If caller is a teacher or passed teacher assignment, strictly verify assignment
    if (isTeacherQuery) {
      final parser = TeacherAssignmentParser(
        assignedClass: teacherAssignedClass ?? className,
        assignedSection: teacherAssignedSection ?? section,
      );
      if (!parser.hasFilter) {
        // Teacher has no assigned class/section -> do not show all school students!
        return [];
      }

      final list = await _studentService.getAllStudents(
        schoolId: effectiveSchoolId,
        academicYearId: effectiveAcademicYearId,
        query: query,
        className: parser.rawClass.isNotEmpty ? parser.rawClass : null,
        section: parser.rawSection.isNotEmpty ? parser.rawSection : null,
        status: status,
        limit: limit,
        offset: offset,
      );

      return list.where((s) => parser.matchesStudent(
        s,
        expectedSchoolId: effectiveSchoolId,
        expectedAcademicYearId: effectiveAcademicYearId,
      )).toList();
    }

    final parser = TeacherAssignmentParser(
      assignedClass: className,
      assignedSection: section,
    );

    final list = await _studentService.getAllStudents(
      schoolId: effectiveSchoolId,
      academicYearId: effectiveAcademicYearId,
      query: query,
      className: parser.rawClass.isNotEmpty ? parser.rawClass : className,
      section: parser.rawSection.isNotEmpty ? parser.rawSection : section,
      status: status,
      limit: limit,
      offset: offset,
    );

    var filtered = list;
    if (parser.hasFilter) {
      filtered = filtered.where((s) => parser.matchesStudent(
        s,
        expectedSchoolId: effectiveSchoolId,
        expectedAcademicYearId: effectiveAcademicYearId,
      )).toList();
    }

    if (gender != null && gender != 'All') {
      filtered = filtered.where((s) => s.gender.toLowerCase() == gender.toLowerCase()).toList();
    }
    if (feeStatus != null && feeStatus != 'All') {
      filtered = filtered.where((s) => s.feeStatus.name.toLowerCase() == feeStatus.toLowerCase()).toList();
    }

    return filtered;
  }

  Future<StudentModel?> getStudentById(String id) async {
    return await _studentService.getStudentById(id);
  }

  Future<StudentModel> addStudent(StudentModel newStudent) async {
    return await _studentService.addStudent(newStudent);
  }

  Future<void> updateStudentStatus(String studentId, AccountStatus newStatus) async {
    await _studentService.updateStudentStatus(studentId, newStatus);
  }

  Future<void> deleteStudent(String id) async {
    await _studentService.deleteStudent(id);
  }

  Future<Map<String, int>> getClassStudentCounts({
    required List<String> classNames,
    String? schoolId,
    String? academicYearId,
  }) async {
    return await _studentService.getClassStudentCounts(
      classNames: classNames,
      schoolId: schoolId,
      academicYearId: academicYearId,
    );
  }

  Future<int> getStudentCount({
    String? schoolId,
    String? academicYearId,
    String? className,
    String? section,
    AccountStatus? status = AccountStatus.active,
  }) async {
    return await _studentService.getStudentCount(
      schoolId: schoolId,
      academicYearId: academicYearId,
      className: className,
      section: section,
      status: status,
    );
  }

  Future<List<TeacherModel>> getTeachers({String? schoolId, bool includeStaff = false}) async {
    final effectiveSchoolId = schoolId ?? await _studentService.fetchActiveSchoolId();
    return await _teacherService.getTeachers(schoolId: effectiveSchoolId, includeStaff: includeStaff);
  }

  Future<List<TeacherModel>> getStaffAndFaculty({String? schoolId}) async {
    return await getTeachers(schoolId: schoolId, includeStaff: true);
  }

  Future<Map<String, TeacherModel>> getTeachersClassWise() async {
    return await _teacherService.getTeachersClassWise();
  }

  Future<List<ClassroomModel>> getClassrooms() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _classrooms;
  }

  Future<List<TimetableSlotModel>> getTimetable() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return MockData.timetable;
  }

  Future<List<HomeworkModel>> getHomework({String? schoolId, String? className, String? section}) async {
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
            ? schoolId
            : await _studentService.fetchActiveSchoolId();

        var query = client.from('homework').select('*').eq('school_id', effectiveSchoolId);
        if (className != null && className.isNotEmpty && className != 'All') {
          query = query.eq('class_name', className);
        }
        if (section != null && section.isNotEmpty && section != 'All') {
          query = query.eq('section_name', section);
        }
        final res = await query.order('due_date', ascending: true);
        final list = (res as List).map((row) => HomeworkModel.fromJson(row)).toList();
        return list;
      } catch (e) {
        debugPrint('[SchoolRepository getHomework Warning]: $e');
        return [];
      }
    }
    if (_homework.isEmpty) {
      final now = DateTime.now();
      _homework.addAll([
        HomeworkModel(
          id: 'hw_1',
          subject: 'Mathematics',
          className: 'Class 10',
          section: 'A',
          title: 'Quadratic Equations Exercise 4.2',
          description: 'Solve questions 1 through 15 from the textbook and show complete factorization steps.',
          assignedDate: now.subtract(const Duration(days: 1)),
          dueDate: now.add(const Duration(days: 3)),
          attachmentName: 'Quadratic_Formula_Sheet.pdf',
          status: HomeworkStatus.active,
        ),
        HomeworkModel(
          id: 'hw_2',
          subject: 'Physics',
          className: 'Class 10',
          section: 'A',
          title: 'Light Reflection and Refraction Notes',
          description: 'Draw ray diagrams for concave and convex mirrors with object positions.',
          assignedDate: now.subtract(const Duration(days: 2)),
          dueDate: now.add(const Duration(days: 1)),
          attachmentName: 'Ray_Diagrams_Reference.pdf',
          status: HomeworkStatus.dueSoon,
        ),
        HomeworkModel(
          id: 'hw_3',
          subject: 'English',
          className: 'Class 8',
          section: 'A',
          title: 'Poetry Analysis & Summary Writing',
          description: 'Read Chapter 3 poem and write a 200-word critical evaluation and vocabulary list.',
          assignedDate: now.subtract(const Duration(days: 3)),
          dueDate: now.add(const Duration(days: 4)),
          status: HomeworkStatus.active,
        ),
      ]);
    }
    var result = List<HomeworkModel>.from(_homework);
    if (className != null && className.isNotEmpty && className != 'All') {
      final clean = className.replaceAll(RegExp(r'[^0-9]'), '');
      result = result.where((h) {
        final hClean = h.className.replaceAll(RegExp(r'[^0-9]'), '');
        return hClean == clean || h.className.toLowerCase() == className.toLowerCase();
      }).toList();
    }
    if (section != null && section.isNotEmpty && section != 'All') {
      result = result.where((h) => h.section.toLowerCase() == section.toLowerCase()).toList();
    }
    return result;
  }

  Future<void> addHomework(HomeworkModel item, {String? schoolId, String? academicYearId}) async {
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
          ? schoolId
          : await _studentService.fetchActiveSchoolId();
      final effectiveAyId = (academicYearId != null && academicYearId.isNotEmpty)
          ? academicYearId
          : await _studentService.fetchActiveAcademicYearId(effectiveSchoolId);
      final currentUserId = client.auth.currentUser?.id;

      final payload = item.toJson(
        schoolId: effectiveSchoolId,
        academicYearId: effectiveAyId,
        createdBy: currentUserId,
      );

      final inserted = await client.from('homework').insert(payload).select().maybeSingle();
      if (inserted != null) {
        final persisted = HomeworkModel.fromJson(inserted);
        _homework.removeWhere((h) => h.id == item.id || h.id == persisted.id);
        _homework.insert(0, persisted);
        return;
      }
    }
    _homework.removeWhere((h) => h.id == item.id);
    _homework.insert(0, item);
  }

  Future<List<ExamModel>> getExams() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _exams;
  }

  String _noticesCacheKey([String? schoolId]) => 'cached_school_notices_${schoolId?.trim() ?? "default"}';
  String _notificationsCacheKey([String? schoolId]) => 'cached_school_notifications_${schoolId?.trim() ?? "default"}';

  Future<void> _persistNotices([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _noticesCacheKey(schoolId);
      final jsonList = _notices.map((n) => n.toJson(schoolId: schoolId)).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[SchoolRepository Persist Notices Warning]: $e');
    }
  }

  Future<void> _restoreNotices([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _noticesCacheKey(schoolId);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final model = NoticeModel.fromJson(item);
              if (!_notices.any((n) => n.id == model.id)) {
                _notices.add(model);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SchoolRepository Restore Notices Warning]: $e');
    }
  }

  Future<void> _persistNotifications([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notificationsCacheKey(schoolId);
      final jsonList = _notifications.map((n) => n.toJson(schoolId: schoolId)).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[SchoolRepository Persist Notifications Warning]: $e');
    }
  }

  Future<void> _restoreNotifications([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _notificationsCacheKey(schoolId);
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final model = NotificationModel.fromJson(item);
              if (!_notifications.any((n) => n.id == model.id)) {
                _notifications.add(model);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SchoolRepository Restore Notifications Warning]: $e');
    }
  }

  Future<List<NoticeModel>> getNotices({
    String? schoolId,
    UserRole? userRole,
    bool includeDrafts = false,
  }) async {
    final client = _client;
    String? effectiveSchoolId = schoolId;
    if (effectiveSchoolId == null || effectiveSchoolId.isEmpty) {
      try {
        effectiveSchoolId = await _studentService.fetchActiveSchoolId();
      } catch (_) {}
    }

    await _restoreNotices(effectiveSchoolId);

    if (client != null && SupabaseConfig.isConfigured && effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      try {
        final res = await client
            .from('notices')
            .select('*')
            .eq('school_id', effectiveSchoolId)
            .order('created_at', ascending: false);

        final dbList = res.map((row) => NoticeModel.fromJson(row)).toList();
        for (final item in dbList) {
          final idx = _notices.indexWhere((n) => n.id == item.id);
          if (idx != -1) {
            _notices[idx] = item;
          } else {
            _notices.add(item);
          }
        }
        await _persistNotices(effectiveSchoolId);
      } catch (e) {
        debugPrint('[SchoolRepository getNotices Warning]: $e');
      }
    }

    if (_notices.isEmpty) {
      final now = DateTime.now();
      _notices.addAll([
        NoticeModel(
          id: 'notice_1',
          schoolId: effectiveSchoolId ?? '',
          title: 'Annual Sports Day & Athletics Meet 2026-27',
          content: 'We are pleased to announce our annual inter-house sports meet. All students from Class 1 to 12 are encouraged to register with their respective sports teachers.',
          category: 'Sports',
          date: now.subtract(const Duration(days: 1)),
          author: 'Principal Office',
          isPinned: true,
          isUnread: false,
        ),
        NoticeModel(
          id: 'notice_2',
          schoolId: effectiveSchoolId ?? '',
          title: 'First Term Examination Schedule & Guidelines',
          content: 'The first term examination date-sheets have been released. Please review your subject syllabus and ensure timely arrival in school uniform.',
          category: 'Academic',
          date: now.subtract(const Duration(days: 3)),
          author: 'Examination Cell',
          isPinned: true,
          isUnread: false,
        ),
        NoticeModel(
          id: 'notice_3',
          schoolId: effectiveSchoolId ?? '',
          title: 'Parent-Teacher Meeting (PTM) Scheduled',
          content: 'Quarterly Parent-Teacher Meeting will be held this Saturday between 9:00 AM and 1:00 PM. Parents are cordially invited to review progress.',
          category: 'General',
          date: now.subtract(const Duration(days: 5)),
          author: 'Administration',
          isPinned: false,
          isUnread: false,
        ),
      ]);
    }

    // Role-based Audience and Status filtering
    return _notices.where((n) {
      // School Isolation
      if (effectiveSchoolId != null && effectiveSchoolId.isNotEmpty && n.schoolId.isNotEmpty && n.schoolId != effectiveSchoolId) {
        return false;
      }
      // Drafts: only admins see drafts
      if (n.status.toLowerCase() == 'draft' && !includeDrafts && userRole != UserRole.schoolAdmin && userRole != UserRole.superAdmin) {
        return false;
      }
      // Audience scoping: teachers only see All Staff, Teachers Only, or Everyone
      if (userRole == UserRole.teacher) {
        final aud = n.targetAudience.toLowerCase().trim();
        if (aud == 'admin only' || aud == 'admin' || aud == 'parents' || aud == 'students') return false;
      }
      return true;
    }).toList();
  }

  Future<void> addNotice(NoticeModel item, {String? schoolId, String? academicYearId}) async {
    final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
        ? schoolId
        : await _studentService.fetchActiveSchoolId();

    final canonicalNoticeId = item.id.isNotEmpty
        ? item.id
        : UuidHelper.generate();

    final enriched = item.copyWith(
      id: canonicalNoticeId,
      schoolId: effectiveSchoolId,
    );

    final existingIdx = _notices.indexWhere((n) => n.id == enriched.id);
    if (existingIdx != -1) {
      _notices[existingIdx] = enriched;
    } else {
      _notices.insert(0, enriched);
    }
    await _persistNotices(effectiveSchoolId);

    // If published, trigger in-app notification for the target audience!
    if (enriched.status.toLowerCase() == 'published') {
      final notifId = UuidHelper.generate();
      final existingNotifIdx = _notifications.indexWhere(
        (notif) => notif.relatedRecordId == enriched.id,
      );
      if (existingNotifIdx == -1) {
        final notif = NotificationModel(
          id: notifId,
          schoolId: effectiveSchoolId,
          recipientRole: enriched.targetAudience,
          title: 'New Notice: ${enriched.title}',
          message: enriched.content.length > 90 ? '${enriched.content.substring(0, 90)}...' : enriched.content,
          timestamp: enriched.date,
          category: 'Notices',
          isUnread: true,
          relatedRecordId: enriched.id,
          relatedRecordType: 'notice',
        );
        await addNotification(notif);
      }

      _accessService.logActivity(
        'Published School Notice',
        'Published "${enriched.title}" for ${enriched.targetAudience}',
        'Notice Board',
        adminName: enriched.author,
      );
    }

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final effectiveAyId = (academicYearId != null && academicYearId.isNotEmpty)
            ? academicYearId
            : await _studentService.fetchActiveAcademicYearId(effectiveSchoolId);
        final currentUserId = client.auth.currentUser?.id;

        final payload = enriched.toJson(
          schoolId: effectiveSchoolId,
          academicYearId: (effectiveAyId != null && effectiveAyId.isNotEmpty && UuidHelper.isValidUuid(effectiveAyId)) ? effectiveAyId : null,
          createdBy: currentUserId,
        );
        if (!UuidHelper.isValidUuid(enriched.id)) {
          payload.remove('id');
        }

        await client.from('notices').insert(payload);
      } catch (e) {
        debugPrint('[SchoolRepository addNotice Supabase Sync Warning]: $e');
      }
    }
  }

  Future<void> updateNotice(NoticeModel item, {String? schoolId}) async {
    final idx = _notices.indexWhere((n) => n.id == item.id);
    if (idx != -1) {
      _notices[idx] = item;
      await _persistNotices(schoolId ?? item.schoolId);
    }

    // If notice was updated to Published, ensure notification is dispatched to audience
    if (item.status.toLowerCase() == 'published') {
      final existingNotifIdx = _notifications.indexWhere(
        (notif) => notif.relatedRecordId == item.id,
      );
      if (existingNotifIdx == -1) {
        final notif = NotificationModel(
          id: UuidHelper.generate(),
          schoolId: item.schoolId.isNotEmpty ? item.schoolId : (schoolId ?? ''),
          recipientRole: item.targetAudience,
          title: 'Notice: ${item.title}',
          message: item.content.length > 90 ? '${item.content.substring(0, 90)}...' : item.content,
          timestamp: item.date,
          category: 'Notices',
          isUnread: true,
          relatedRecordId: item.id,
          relatedRecordType: 'notice',
        );
        await addNotification(notif);
      }
    }

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('notices').update({
          'title': item.title,
          'content': item.content,
          'category': item.category,
          'target_audience': item.targetAudience,
          'status': item.status,
          'is_pinned': item.isPinned,
        }).eq('id', item.id);
      } catch (e) {
        debugPrint('[SchoolRepository updateNotice Warning]: $e');
      }
    }
  }

  Future<void> deleteNotice(String id, {String? schoolId}) async {
    _notices.removeWhere((n) => n.id == id);
    await _persistNotices(schoolId);

    // Clean up notifications linked to this notice
    _notifications.removeWhere((n) => n.relatedRecordId == id || n.id == id);
    await _persistNotifications(schoolId);

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('notices').delete().eq('id', id);
      } catch (e) {
        debugPrint('[SchoolRepository deleteNotice Warning]: $e');
      }
      try {
        await client.from('notifications').delete().eq('related_record_id', id);
      } catch (e) {
        debugPrint('[SchoolRepository deleteNotice notification cleanup Warning]: $e');
      }
    }
  }

  Future<List<LeaveRequestModel>> getLeaveRequests({String? schoolId}) async {
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
            ? schoolId
            : await _studentService.fetchActiveSchoolId();
        final res = await client
            .from('leave_requests')
            .select('*')
            .eq('school_id', effectiveSchoolId)
            .order('created_at', ascending: false);
        final list = (res as List).map((row) => LeaveRequestModel.fromJson(row)).toList();
        return list;
      } catch (e) {
        debugPrint('[SchoolRepository getLeaveRequests Warning]: $e');
        return [];
      }
    }
    if (_leaveRequests.isEmpty) {
      final now = DateTime.now();
      _leaveRequests.addAll([
        LeaveRequestModel(
          id: 'leave_1',
          studentId: '6254bee9-0001-0000-0000-000000000001',
          studentName: 'Aarav Sharma',
          className: 'Class 10-A',
          startDate: now.add(const Duration(days: 1)),
          endDate: now.add(const Duration(days: 3)),
          reason: 'Family wedding event in hometown.',
          status: LeaveStatus.pending,
        ),
        LeaveRequestModel(
          id: 'leave_2',
          studentId: '6254bee9-0001-0000-0000-000000000002',
          studentName: 'Ananya Verma',
          className: 'Class 9-B',
          startDate: now.subtract(const Duration(days: 4)),
          endDate: now.subtract(const Duration(days: 2)),
          reason: 'Severe viral fever and medical rest advised.',
          status: LeaveStatus.approved,
        ),
        LeaveRequestModel(
          id: 'leave_3',
          studentId: '6254bee9-0001-0000-0000-000000000003',
          studentName: 'Rohan Patel',
          className: 'Class 8-A',
          startDate: now.subtract(const Duration(days: 10)),
          endDate: now.subtract(const Duration(days: 8)),
          reason: 'Personal absence without prior intimating.',
          status: LeaveStatus.rejected,
        ),
      ]);
    }
    return _leaveRequests;
  }

  Future<void> updateLeaveStatus(String id, LeaveStatus status) async {
    final idx = _leaveRequests.indexWhere((l) => l.id == id);
    if (idx != -1) {
      _leaveRequests[idx] = _leaveRequests[idx].copyWith(status: status);
    }
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client
            .from('leave_requests')
            .update({'status': status.name.toUpperCase()})
            .eq('id', id);
      } catch (e) {
        debugPrint('[SchoolRepository updateLeaveStatus Warning]: $e');
      }
    }
  }

  Future<List<FeeRecordModel>> getFeeRecords({String? statusFilter}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (statusFilter == null || statusFilter == 'All') return _fees;
    return _fees.where((f) => f.status.name.toLowerCase() == statusFilter.toLowerCase()).toList();
  }

  Future<List<LibraryBookModel>> getLibraryBooks() async {
    return _libraryService.fetchBooks();
  }

  Future<List<TransportRouteModel>> getTransportRoutes() async {
    return _transportService.fetchRoutes();
  }

  Future<List<NotificationModel>> getNotifications({
    String? schoolId,
    String? userId,
    UserRole? role,
  }) async {
    await _restoreNotifications(schoolId);

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final query = client.from('notifications').select('*');
        if (schoolId != null && schoolId.isNotEmpty) {
          query.eq('school_id', schoolId);
        }
        final res = await query.order('created_at', ascending: false).limit(50);
        final dbList = res.map((row) => NotificationModel.fromJson(row)).toList();
        for (final item in dbList) {
          final idx = _notifications.indexWhere((n) => n.id == item.id);
          if (idx != -1) {
            _notifications[idx] = item;
          } else {
            _notifications.add(item);
          }
        }
        await _persistNotifications(schoolId);
      } catch (e) {
        debugPrint('[SchoolRepository getNotifications Warning]: $e');
      }
    }

    return _notifications.where((n) {
      // School Isolation
      if (schoolId != null && schoolId.isNotEmpty && n.schoolId.isNotEmpty && n.schoolId != schoolId) {
        return false;
      }
      // User ID Scoping
      if (userId != null && n.recipientId != null && n.recipientId!.isNotEmpty && n.recipientId != userId) {
        return false;
      }
      // Role & Audience Scoping
      if (role != null && n.recipientRole != null && n.recipientRole!.trim().isNotEmpty) {
        final targetAudience = n.recipientRole!.trim().toLowerCase();
        if (targetAudience == 'everyone' || targetAudience == 'all') {
          return true;
        } else if (targetAudience == 'all staff' || targetAudience == 'staff') {
          if (role != UserRole.teacher && role != UserRole.staff && role != UserRole.schoolAdmin && role != UserRole.superAdmin && role != UserRole.owner) {
            return false;
          }
        } else if (targetAudience == 'teachers only' || targetAudience == 'teachers' || targetAudience == 'teacher') {
          if (role != UserRole.teacher && role != UserRole.schoolAdmin && role != UserRole.superAdmin && role != UserRole.owner) {
            return false;
          }
        } else if (targetAudience == 'parents' || targetAudience == 'parent') {
          // If staff/admin, they can monitor parent notifications
          if (role == UserRole.teacher) {
            return false;
          }
        } else if (targetAudience == 'students' || targetAudience == 'student') {
          // If teacher, they can view student notifications; staff/admin can monitor
        } else if (targetAudience == 'admin only' || targetAudience == 'admin') {
          if (role != UserRole.schoolAdmin && role != UserRole.superAdmin && role != UserRole.owner) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  Future<void> addNotification(NotificationModel item) async {
    final canonicalId = item.id.isNotEmpty
        ? item.id
        : UuidHelper.generate();
    final enriched = item.copyWith(id: canonicalId);

    final existingIdx = _notifications.indexWhere((n) => n.id == enriched.id);
    if (existingIdx != -1) {
      _notifications[existingIdx] = enriched;
    } else {
      _notifications.insert(0, enriched);
    }
    await _persistNotifications(enriched.schoolId);

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        final payload = enriched.toJson();
        if (!UuidHelper.isValidUuid(enriched.id)) {
          payload.remove('id');
        }
        await client.from('notifications').insert(payload);
      } catch (e) {
        debugPrint('[SchoolRepository addNotification Warning]: $e');
      }
    }
  }

  Future<void> markNotificationRead(String id, {String? schoolId}) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isUnread: false);
      await _persistNotifications(schoolId ?? _notifications[idx].schoolId);
    }
    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        await client.from('notifications').update({'is_unread': false}).eq('id', id);
      } catch (e) {
        debugPrint('[SchoolRepository markNotificationRead Warning]: $e');
      }
    }
  }

  Future<void> markAllNotificationsRead({String? schoolId, String? userId}) async {
    for (int i = 0; i < _notifications.length; i++) {
      if ((schoolId == null || _notifications[i].schoolId.isEmpty || _notifications[i].schoolId == schoolId) &&
          (userId == null || _notifications[i].recipientId == null || _notifications[i].recipientId == userId)) {
        _notifications[i] = _notifications[i].copyWith(isUnread: false);
      }
    }
    await _persistNotifications(schoolId);

    final client = _client;
    if (client != null && SupabaseConfig.isConfigured) {
      try {
        var query = client.from('notifications').update({'is_unread': false});
        if (schoolId != null && schoolId.isNotEmpty) {
          query = query.eq('school_id', schoolId);
        }
        await query;
      } catch (e) {
        debugPrint('[SchoolRepository markAllNotificationsRead Warning]: $e');
      }
    }
  }

  Future<int> getUnreadNotificationCount({String? schoolId, String? userId, UserRole? role}) async {
    final list = await getNotifications(schoolId: schoolId, userId: userId, role: role);
    return list.where((n) => n.isUnread).length;
  }
}
