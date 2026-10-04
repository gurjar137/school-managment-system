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
    final effectiveAcademicYearId = (academicYearId != null && academicYearId.isNotEmpty)
        ? academicYearId
        : await _studentService.fetchActiveAcademicYearId(effectiveSchoolId);

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

  Future<List<TeacherModel>> getTeachers({String? schoolId}) async {
    final effectiveSchoolId = schoolId ?? await _studentService.fetchActiveSchoolId();
    return await _teacherService.getTeachers(schoolId: effectiveSchoolId);
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
        return (res as List).map((row) => HomeworkModel.fromJson(row)).toList();
      } catch (e) {
        debugPrint('[SchoolRepository getHomework Error]: $e');
        rethrow;
      }
    }
    return _homework;
  }

  Future<void> addHomework(HomeworkModel item, {String? schoolId, String? academicYearId}) async {
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
        return;
      } catch (e) {
        debugPrint('[SchoolRepository addHomework Error]: $e');
        rethrow;
      }
    }
    _homework.insert(0, item);
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

        return (res as List).map((row) => NoticeModel.fromJson(row)).toList();
      } catch (e) {
        debugPrint('[SchoolRepository getNotices Error]: $e');
        rethrow;
      }
    }
    return _notices;
  }

  Future<void> addNotice(NoticeModel item, {String? schoolId, String? academicYearId}) async {
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
        return;
      } catch (e) {
        debugPrint('[SchoolRepository addNotice Error]: $e');
        rethrow;
      }
    }
    _notices.insert(0, item);
  }

  Future<List<LeaveRequestModel>> getLeaveRequests() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _leaveRequests;
  }

  Future<void> updateLeaveStatus(String id, LeaveStatus status) async {
    final idx = _leaveRequests.indexWhere((l) => l.id == id);
    if (idx != -1) {
      _leaveRequests[idx] = _leaveRequests[idx].copyWith(status: status);
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
    await Future.delayed(const Duration(milliseconds: 150));
    return MockData.notifications;
  }
}
