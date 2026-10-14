import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/student_model.dart';
import '../models/academic_models.dart';
import '../models/user_model.dart';
import '../services/student_service.dart';
import '../services/teacher_service.dart';
import '../services/library_service.dart';
import '../services/transport_service.dart';
import '../mock/mock_data.dart';
import '../../core/utils/teacher_assignment_parser.dart';

class SchoolRepository {
  final StudentService _studentService;
  final TeacherService _teacherService;
  final LibraryService _libraryService;
  final TransportService _transportService;
  final List<ClassroomModel> _classrooms = [];
  final List<HomeworkModel> _homework = [];
  final List<ExamModel> _exams = [];
  final List<NoticeModel> _notices = [];
  final List<LeaveRequestModel> _leaveRequests = [];
  final List<FeeRecordModel> _fees = [];

  SchoolRepository({
    StudentService? studentService,
    TeacherService? teacherService,
    LibraryService? libraryService,
    TransportService? transportService,
  })  : _studentService = studentService ?? StudentService(),
        _teacherService = teacherService ?? TeacherService(),
        _libraryService = libraryService ?? LibraryService(),
        _transportService = transportService ?? TransportService();

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
    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
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
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[SchoolRepository getHomework Warning]: $e');
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
    _homework.insert(0, item);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
        final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
            ? schoolId
            : await _studentService.fetchActiveSchoolId();
        final effectiveAyId = (academicYearId != null && academicYearId.isNotEmpty)
            ? academicYearId
            : await _studentService.fetchActiveAcademicYearId(effectiveSchoolId);
        final currentUserId = client.auth.currentUser?.id;

        await client.from('homework').insert(item.toJson(
          schoolId: effectiveSchoolId,
          academicYearId: effectiveAyId,
          createdBy: currentUserId,
        ));
      } catch (e) {
        debugPrint('[SchoolRepository addHomework Warning]: $e');
      }
    }
  }

  Future<List<ExamModel>> getExams() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _exams;
  }

  Future<List<NoticeModel>> getNotices({String? schoolId}) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
        final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
            ? schoolId
            : await _studentService.fetchActiveSchoolId();

        final res = await client
            .from('notices')
            .select('*')
            .eq('school_id', effectiveSchoolId)
            .order('created_at', ascending: false);

        final list = (res as List).map((row) => NoticeModel.fromJson(row)).toList();
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[SchoolRepository getNotices Warning]: $e');
      }
    }
    if (_notices.isEmpty) {
      final now = DateTime.now();
      _notices.addAll([
        NoticeModel(
          id: 'notice_1',
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
    return _notices;
  }

  Future<void> addNotice(NoticeModel item, {String? schoolId, String? academicYearId}) async {
    _notices.insert(0, item);
    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
        final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
            ? schoolId
            : await _studentService.fetchActiveSchoolId();
        final effectiveAyId = (academicYearId != null && academicYearId.isNotEmpty)
            ? academicYearId
            : await _studentService.fetchActiveAcademicYearId(effectiveSchoolId);
        final currentUserId = client.auth.currentUser?.id;

        await client.from('notices').insert(item.toJson(
          schoolId: effectiveSchoolId,
          academicYearId: effectiveAyId,
          createdBy: currentUserId,
        ));
      } catch (e) {
        debugPrint('[SchoolRepository addNotice Supabase Sync Warning]: $e');
      }
    }
  }

  Future<List<LeaveRequestModel>> getLeaveRequests({String? schoolId}) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
        final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
            ? schoolId
            : await _studentService.fetchActiveSchoolId();
        final res = await client
            .from('leave_requests')
            .select('*')
            .eq('school_id', effectiveSchoolId)
            .order('created_at', ascending: false);
        final list = (res as List).map((row) => LeaveRequestModel.fromJson(row)).toList();
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[SchoolRepository getLeaveRequests Warning]: $e');
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
    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
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

  Future<List<NotificationModel>> getNotifications() async {
    if (MockData.notifications.isEmpty) {
      final now = DateTime.now();
      MockData.notifications.addAll([
        NotificationModel(
          id: 'notif_1',
          title: 'Quarterly Fee Due Reminder',
          message: 'First quarter tuition fee installment for 2026-2027 is due next week. Please clear pending dues.',
          timestamp: now.subtract(const Duration(hours: 2)),
          category: 'Fees',
          isUnread: true,
        ),
        NotificationModel(
          id: 'notif_2',
          title: 'Term Examination Schedule Published',
          message: 'The comprehensive datesheet for upcoming term-end assessments is now available on the portal.',
          timestamp: now.subtract(const Duration(days: 1)),
          category: 'Results',
          isUnread: true,
        ),
        NotificationModel(
          id: 'notif_3',
          title: 'Annual Sports Day Registration Open',
          message: 'Sign up for athletic and indoor sports competitions with your assigned physical education teacher.',
          timestamp: now.subtract(const Duration(days: 2)),
          category: 'School',
          isUnread: false,
        ),
        NotificationModel(
          id: 'notif_4',
          title: 'Parent-Teacher Meeting This Saturday',
          message: 'All parents and guardians are requested to attend the upcoming PTM session between 9 AM and 1 PM.',
          timestamp: now.subtract(const Duration(days: 3)),
          category: 'School',
          isUnread: false,
        ),
      ]);
    }
    return MockData.notifications;
  }
}
