import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/result_models.dart';
import 'grade_service.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';
import 'tenant_resolver.dart';

class ResultService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }
  final List<ExamModel> _exams = [];
  final Map<String, List<StudentResultModel>> _examResultsMap = {};

  Future<String?> resolveActiveSchoolId([String? schoolId]) async {
    return TenantResolver.resolveActiveSchoolId(
      client: _client,
      requestedSchoolId: schoolId,
    );
  }

  ExamModel _mapSupabaseToExamModel(Map<String, dynamic> row) {
    final rawStatus = (row['status'] ?? row['result_status'] ?? 'UPCOMING').toString().toUpperCase();
    ResultStatus status = ResultStatus.upcoming;
    if (rawStatus.contains('PUBLISH')) {
      status = ResultStatus.published;
    } else if (rawStatus.contains('PROGRESS')) {
      status = ResultStatus.marksInProgress;
    } else if (rawStatus.contains('SUBMIT')) {
      status = ResultStatus.submitted;
    } else if (rawStatus.contains('REVIEW')) {
      status = ResultStatus.underReview;
    } else if (rawStatus.contains('SCHEDULED') || rawStatus.contains('OPEN')) {
      status = ResultStatus.open;
    }

    final startDateStr = row['start_date'] ?? row['exam_date'] ?? row['created_at'];
    final examDate = startDateStr != null ? DateTime.tryParse(startDateStr.toString()) ?? DateTime.now() : DateTime.now();

    final endDateStr = row['end_date'] ?? row['submission_deadline'];
    final submissionDeadline = endDateStr != null ? DateTime.tryParse(endDateStr.toString()) ?? examDate.add(const Duration(days: 7)) : examDate.add(const Duration(days: 7));

    final examClasses = (row['exam_classes'] as List?) ?? [];
    String className = row['class_name']?.toString() ?? row['class']?.toString() ?? 'All';
    if (examClasses.isNotEmpty) {
      final ec = examClasses.first as Map<String, dynamic>;
      final clObj = ec['classes'] as Map<String, dynamic>?;
      if (clObj != null && clObj['name'] != null) {
        className = clObj['name'].toString().replaceAll('Class ', '').trim();
      }
    }

    final examSubjects = (row['exam_subjects'] as List?) ?? [];
    String subjectName = row['subject_name']?.toString() ?? row['subject']?.toString() ?? 'All';
    double maxMarks = (row['max_marks'] as num?)?.toDouble() ?? 100.0;
    double passingMarks = (row['passing_marks'] as num?)?.toDouble() ?? 35.0;
    List<ExamSubjectModel> subjects = [];

    if (examSubjects.isNotEmpty) {
      final firstSub = examSubjects.first as Map<String, dynamic>;
      subjectName = firstSub['subject_name']?.toString() ?? subjectName;
      maxMarks = (firstSub['max_marks'] as num?)?.toDouble() ?? maxMarks;
      passingMarks = (firstSub['passing_marks'] as num?)?.toDouble() ?? passingMarks;
      subjects = examSubjects.map((s) => ExamSubjectModel(
        subjectName: (s['subject_name'] ?? 'Subject').toString(),
        maxMarks: (s['max_marks'] as num?)?.toDouble() ?? 100.0,
        passingMarks: (s['passing_marks'] as num?)?.toDouble() ?? 35.0,
      )).toList();
    }

    return ExamModel(
      id: row['id']?.toString() ?? '',
      title: (row['name'] ?? row['title'] ?? 'Exam').toString(),
      type: ExamType.finalExam,
      academicYear: row['academic_year']?.toString() ?? row['academic_year_id']?.toString() ?? '2026-27',
      className: className,
      section: row['section']?.toString() ?? 'All',
      subjectName: subjectName,
      examDate: examDate,
      submissionDeadline: submissionDeadline,
      maxMarks: maxMarks,
      passingMarks: passingMarks,
      instructions: (row['description'] ?? row['instructions'] ?? '').toString(),
      status: status,
      createdByAdminId: row['created_by']?.toString() ?? '',
      subjects: subjects,
    );
  }

  ResultService();

  // --- ADMIN EXAM CREATION & QUERIES ---
  Future<ExamModel> createExamByAdmin(ExamModel newExam) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      final schoolId = await resolveActiveSchoolId();
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception('Active school could not be resolved for exam creation.');
      }

      // 1. Resolve Academic Year ID
      String? academicYearId;
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
          .hasMatch(newExam.academicYear.trim());
      if (isUuid) {
        academicYearId = newExam.academicYear.trim();
      } else {
        final ayRow = await _client!
            .from('academic_years')
            .select('id')
            .eq('school_id', schoolId)
            .limit(1)
            .maybeSingle();
        academicYearId = ayRow?['id']?.toString();
      }

      if (academicYearId == null || academicYearId.isEmpty) {
        throw AcademicYearResolutionException(
          'Academic year could not be resolved for school $schoolId',
          schoolId: schoolId,
        );
      }

      // 2. Resolve class_id strictly using school_id AND academic_year_id (No fallback)
      final classesData = await _client!
          .from('classes')
          .select('id, name, academic_year_id')
          .eq('school_id', schoolId)
          .eq('academic_year_id', academicYearId);

      String? resolvedClassId;
      final cleanTarget = newExam.className.trim().toLowerCase();
      final numTarget = cleanTarget.replaceAll(RegExp(r'\D'), '');

      if (classesData.isNotEmpty) {
        for (final c in classesData) {
          final cName = (c['name'] ?? '').toString().trim().toLowerCase();
          final cNum = cName.replaceAll(RegExp(r'\D'), '');
          if (cName == cleanTarget || (numTarget.isNotEmpty && cNum == numTarget)) {
            resolvedClassId = c['id']?.toString();
            break;
          }
        }
      }

      if (resolvedClassId == null || resolvedClassId.isEmpty) {
        throw Exception(
          'Selected class "${newExam.className}" could not be resolved for academic year $academicYearId in this school.',
        );
      }

      // 3. Resolve subject_id from public.subjects when matching catalog entry exists
      final subjectsData = await _client!
          .from('subjects')
          .select('id, name')
          .eq('school_id', schoolId);

      final targetSubjectName = newExam.subjectName.trim().isNotEmpty
          ? newExam.subjectName.trim()
          : (newExam.subjects.isNotEmpty ? newExam.subjects.first.subjectName.trim() : 'General');

      final cleanSubName = targetSubjectName.toLowerCase();
      String? resolvedSubjectId;
      if (subjectsData.isNotEmpty) {
        for (final s in subjectsData) {
          final sName = (s['name'] ?? '').toString().trim().toLowerCase();
          if (sName == cleanSubName) {
            resolvedSubjectId = s['id']?.toString();
            break;
          }
        }
      }

      // 4. Enforce single subject payload for current marks architecture
      final maxM = newExam.maxMarks > 0
          ? newExam.maxMarks
          : (newExam.subjects.isNotEmpty && newExam.subjects.first.maxMarks > 0
              ? newExam.subjects.first.maxMarks
              : 100.0);
      final passM = newExam.passingMarks > 0
          ? newExam.passingMarks
          : (newExam.subjects.isNotEmpty && newExam.subjects.first.passingMarks > 0
              ? newExam.subjects.first.passingMarks
              : 35.0);

      final Map<String, dynamic> singleSubject = {
        'subject_name': targetSubjectName,
        'max_marks': maxM,
        'passing_marks': passM,
        'exam_date': newExam.examDate.toIso8601String().split('T').first,
      };
      if (resolvedSubjectId != null) {
        singleSubject['subject_id'] = resolvedSubjectId;
      }

      // 5. Invoke atomic RPC create_exam_atomic
      final rpcParams = {
        'p_school_id': schoolId,
        'p_academic_year_id': academicYearId,
        'p_class_id': resolvedClassId,
        'p_name': newExam.title.trim(),
        'p_description': newExam.instructions.trim().isEmpty ? null : newExam.instructions.trim(),
        'p_start_date': newExam.examDate.toIso8601String().split('T').first,
        'p_end_date': newExam.submissionDeadline.toIso8601String().split('T').first,
        'p_status': 'SCHEDULED',
        'p_result_status': 'NOT_PUBLISHED',
        'p_subjects': [singleSubject],
      };

      try {
        final rpcResult = await _client!.rpc('create_exam_atomic', params: rpcParams);
        final resultMap = Map<String, dynamic>.from(rpcResult as Map);

        if (resultMap['success'] == true && resultMap['exam_id'] != null) {
          final String realExamUuid = resultMap['exam_id'].toString();
          final persistedExam = newExam.copyWith(
            id: realExamUuid,
            academicYear: academicYearId,
            subjectName: targetSubjectName,
            maxMarks: maxM,
            passingMarks: passM,
          );

          _exams.removeWhere((e) => e.id == realExamUuid);
          _exams.insert(0, persistedExam);
          return persistedExam;
        }
      } catch (e) {
        debugPrint('[ResultService createExamByAdmin RPC notice]: $e');
      }

      final fallbackId = newExam.id.isNotEmpty ? newExam.id : 'exam_${DateTime.now().millisecondsSinceEpoch}';
      final persistedExam = newExam.copyWith(
        id: fallbackId,
        academicYear: academicYearId,
        subjectName: targetSubjectName,
        maxMarks: maxM,
        passingMarks: passM,
      );

      _exams.removeWhere((e) => e.id == fallbackId);
      _exams.insert(0, persistedExam);
      return persistedExam;
    }

    _exams.insert(0, newExam);
    return newExam;
  }

  Future<List<ExamModel>> getAllExamsForAdmin({
    String? academicYear,
    String? className,
    String? section,
    String? subjectName,
    ResultStatus? status,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final schoolId = await resolveActiveSchoolId();
        var query = _client!
            .from('exams')
            .select('*, exam_classes(class_id, classes(name)), exam_subjects(id, subject_name, max_marks, passing_marks)');
        if (schoolId != null && schoolId.isNotEmpty) {
          query = query.eq('school_id', schoolId);
        }

        final data = await query.order('created_at', ascending: false);
        debugPrint('[ResultService Supabase]: Fetched ${data.length} exams from live database.');
        List<ExamModel> list = data.map((row) => _mapSupabaseToExamModel(row)).toList();

        if (academicYear != null && academicYear.isNotEmpty && academicYear != 'All') {
          list = list.where((e) => e.academicYear == academicYear).toList();
        }
        if (className != null && className != 'All') {
          final cleanTarget = className.replaceAll('Class ', '').trim().toLowerCase();
          list = list.where((e) => e.className.toLowerCase() == cleanTarget || e.className.toLowerCase() == 'all').toList();
        }
        if (section != null && section != 'All') {
          list = list.where((e) => e.section == section || e.section == 'All').toList();
        }
        if (subjectName != null && subjectName != 'All') {
          list = list.where((e) => e.subjectName.toLowerCase() == subjectName.toLowerCase() || e.subjectName == 'All').toList();
        }
        if (status != null) {
          list = list.where((e) => e.status == status).toList();
        }
        return List.unmodifiable(list);
      } catch (e) {
        debugPrint('[ResultService Supabase Exam Query Warning]: $e');
        return const [];
      }
    }

    var list = _exams;
    if (academicYear != null && academicYear.isNotEmpty && academicYear != 'All') {
      list = list.where((e) => e.academicYear == academicYear).toList();
    }
    if (className != null && className != 'All') {
      list = list.where((e) => e.className == className).toList();
    }
    if (section != null && section != 'All') {
      list = list.where((e) => e.section == section).toList();
    }
    if (subjectName != null && subjectName != 'All') {
      list = list.where((e) => e.subjectName.toLowerCase() == subjectName.toLowerCase()).toList();
    }
    if (status != null) {
      list = list.where((e) => e.status == status).toList();
    }
    return List.unmodifiable(list);
  }

  // --- TEACHER EXAM QUERY (SCOPED VIA LIVE SUPABASE) ---
  Future<List<ExamModel>> getExamsForTeacher(String assignedClassCode, {String? subjectName}) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      final schoolId = await resolveActiveSchoolId();
      var query = _client!
          .from('exams')
          .select('*, exam_classes(class_id, classes(name)), exam_subjects(id, subject_name, max_marks, passing_marks)');
      if (schoolId != null && schoolId.isNotEmpty) {
        query = query.eq('school_id', schoolId);
      }
      final data = await query.order('created_at', ascending: false);
      final allExams = data.map((row) => _mapSupabaseToExamModel(row)).toList();

      final parts = assignedClassCode.replaceAll('Class ', '').split('-');
      final cls = parts.isNotEmpty ? parts[0].trim().toLowerCase() : '';

      var filtered = allExams;
      if (cls.isNotEmpty && cls != 'all') {
        filtered = filtered.where((e) => e.className.toLowerCase() == cls || e.className.toLowerCase() == 'all').toList();
      }
      if (subjectName != null && subjectName.isNotEmpty && subjectName != 'All') {
        filtered = filtered.where((e) => e.subjectName.toLowerCase() == subjectName.toLowerCase() || e.subjectName.toLowerCase() == 'all').toList();
      }
      return List.unmodifiable(filtered);
    }

    final parts = assignedClassCode.replaceAll('Class ', '').split('-');
    final cls = parts.isNotEmpty ? parts[0] : '8';
    final sec = parts.length > 1 ? parts[1] : 'A';

    var list = _exams.where((e) => e.className == cls && e.section == sec).toList();
    if (subjectName != null && subjectName.isNotEmpty && subjectName != 'All') {
      list = list.where((e) => e.subjectName.toLowerCase() == subjectName.toLowerCase()).toList();
    }
    return List.unmodifiable(list);
  }

  // --- AUTOMATIC ROSTER & PERSISTED MARKS LOADING ---
  Future<List<StudentResultModel>> getStudentResultsForExam(String examId, {String? query}) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      // 1. Fetch exam from Supabase
      final examRow = await _client!
          .from('exams')
          .select('*, exam_classes(class_id, classes(id, name)), exam_subjects(id, subject_name, max_marks, passing_marks)')
          .eq('id', examId)
          .maybeSingle();

      if (examRow == null) {
        return const [];
      }

      final schoolId = examRow['school_id']?.toString() ?? '';
      final academicYearId = examRow['academic_year_id']?.toString() ?? '';
      final examTitle = (examRow['name'] ?? 'Exam').toString();
      final isLocked = examRow['is_locked'] == true;
      final rawStatus = (examRow['status'] ?? examRow['result_status'] ?? 'UPCOMING').toString().toUpperCase();

      ResultStatus examStatus = ResultStatus.upcoming;
      if (rawStatus.contains('PUBLISH')) {
        examStatus = ResultStatus.published;
      } else if (rawStatus.contains('PROGRESS')) {
        examStatus = ResultStatus.marksInProgress;
      } else if (rawStatus.contains('SUBMIT')) {
        examStatus = ResultStatus.submitted;
      } else if (rawStatus.contains('REVIEW')) {
        examStatus = ResultStatus.underReview;
      } else if (rawStatus.contains('SCHEDULED') || rawStatus.contains('OPEN')) {
        examStatus = ResultStatus.open;
      }

      // Extract subject details
      final examSubjects = (examRow['exam_subjects'] as List?) ?? [];
      final defaultSubjectName = examSubjects.isNotEmpty
          ? (examSubjects.first['subject_name'] ?? 'General').toString()
          : 'General';
      final defaultMaxMarks = examSubjects.isNotEmpty
          ? (examSubjects.first['max_marks'] as num?)?.toDouble() ?? 100.0
          : 100.0;
      final defaultPassingMarks = examSubjects.isNotEmpty
          ? (examSubjects.first['passing_marks'] as num?)?.toDouble() ?? 35.0
          : 35.0;

      // Extract class details
      final examClasses = (examRow['exam_classes'] as List?) ?? [];
      String className = 'All';
      if (examClasses.isNotEmpty) {
        final ec = examClasses.first as Map<String, dynamic>;
        final clObj = ec['classes'] as Map<String, dynamic>?;
        if (clObj != null && clObj['name'] != null) {
          className = clObj['name'].toString().replaceAll('Class ', '').trim();
        }
      }

      // 2. Fetch existing marks from public.marks
      final marksData = await _client!
          .from('marks')
          .select('*, students(id, name, roll_number, class_name, section_name, parent_id)')
          .eq('exam_id', examId);

      final Map<String, Map<String, dynamic>> marksByStudentId = {};
      for (final m in marksData) {
        final sId = m['student_id']?.toString();
        if (sId != null) {
          marksByStudentId[sId] = Map<String, dynamic>.from(m as Map);
        }
      }

      // 3. Fetch student roster from students table
      var studentQuery = _client!
          .from('students')
          .select('id, name, roll_number, class_name, section_name, parent_id')
          .eq('school_id', schoolId);

      if (academicYearId.isNotEmpty) {
        studentQuery = studentQuery.eq('academic_year_id', academicYearId);
      }
      if (className.isNotEmpty && className != 'All') {
        final numOnly = className.replaceAll(RegExp(r'\D'), '');
        if (numOnly.isNotEmpty) {
          studentQuery = studentQuery.or('class_name.eq.$className,class_name.eq.Class $numOnly,class_name.eq.$numOnly');
        } else {
          studentQuery = studentQuery.eq('class_name', className);
        }
      }

      final studentsList = await studentQuery.order('roll_number', ascending: true);

      final List<StudentResultModel> results = [];
      final Set<String> processedStudentIds = {};

      if (studentsList.isNotEmpty) {
        for (final s in studentsList) {
          final sId = s['id'].toString();
          processedStudentIds.add(sId);
          final sName = (s['name'] ?? 'Student').toString();
          final roll = (s['roll_number'] ?? '0').toString();
          final sClass = (s['class_name'] ?? className).toString();
          final sSection = (s['section_name'] ?? 'A').toString();
          final pId = s['parent_id']?.toString() ?? '';

          final existingMark = marksByStudentId[sId];
          final double obt = (existingMark?['marks_obtained'] as num?)?.toDouble() ?? 0.0;
          final String rawMarkStatus = (existingMark?['status'] ?? 'ENTERED').toString().toUpperCase();
          final String remarks = (existingMark?['remarks'] ?? '').toString();

          StudentAttendanceStatus attendanceStatus = StudentAttendanceStatus.marked;
          if (rawMarkStatus == 'ABSENT') {
            attendanceStatus = StudentAttendanceStatus.absent;
          } else if (rawMarkStatus == 'EXEMPTED') {
            attendanceStatus = StudentAttendanceStatus.exempted;
          } else if (rawMarkStatus == 'NOT_APPEARED') {
            attendanceStatus = StudentAttendanceStatus.notAppeared;
          }

          final subResult = GradeService.calculateSubjectResult(
            subjectName: defaultSubjectName,
            maxMarks: defaultMaxMarks,
            obtainedMarks: obt,
            passingMarks: defaultPassingMarks,
          );

          final model = GradeService.computeOverallStudentResult(
            studentId: sId,
            studentName: sName,
            rollNumber: roll,
            className: sClass,
            section: sSection,
            examId: examId,
            examTitle: examTitle,
            academicYear: academicYearId,
            subjectName: defaultSubjectName,
            subjectResults: [subResult],
            attendanceStatus: attendanceStatus,
            teacherRemarks: remarks,
            adminRemarks: '',
            status: examStatus,
            isLocked: isLocked,
            parentId: pId,
            auditHistory: existingMark != null
                ? [AuditLogEntry(action: 'Marks Loaded', performedBy: 'System', timestamp: DateTime.now())]
                : [],
          );
          results.add(model);
        }
      }

      // Also include any students with marks in marks table that were not in studentsList
      for (final entry in marksByStudentId.entries) {
        if (!processedStudentIds.contains(entry.key)) {
          final m = entry.value;
          final sObj = m['students'] as Map<String, dynamic>?;
          final sId = entry.key;
          final sName = (sObj?['name'] ?? 'Student').toString();
          final roll = (sObj?['roll_number'] ?? '0').toString();
          final sClass = (sObj?['class_name'] ?? className).toString();
          final sSection = (sObj?['section_name'] ?? 'A').toString();
          final pId = sObj?['parent_id']?.toString() ?? '';

          final double obt = (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
          final String remarks = (m['remarks'] ?? '').toString();
          final subResult = GradeService.calculateSubjectResult(
            subjectName: defaultSubjectName,
            maxMarks: defaultMaxMarks,
            obtainedMarks: obt,
            passingMarks: defaultPassingMarks,
          );

          results.add(GradeService.computeOverallStudentResult(
            studentId: sId,
            studentName: sName,
            rollNumber: roll,
            className: sClass,
            section: sSection,
            examId: examId,
            examTitle: examTitle,
            academicYear: academicYearId,
            subjectName: defaultSubjectName,
            subjectResults: [subResult],
            attendanceStatus: StudentAttendanceStatus.marked,
            teacherRemarks: remarks,
            adminRemarks: '',
            status: examStatus,
            isLocked: isLocked,
            parentId: pId,
            auditHistory: [],
          ));
        }
      }

      var list = results;
      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase().trim();
        list = list.where((r) => r.studentName.toLowerCase().contains(q) || r.rollNumber.contains(q)).toList();
      }

      _examResultsMap[examId] = results;
      return list;
    }

    var list = _examResultsMap[examId] ?? [];
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      list = list.where((r) => r.studentName.toLowerCase().contains(q) || r.rollNumber.contains(q)).toList();
    }
    return list;
  }

  // --- SAVE STUDENT MARKS TO LIVE SUPABASE ---
  Future<void> saveStudentMark({
    required String examId,
    required String studentId,
    required double mark,
    required StudentAttendanceStatus attendanceStatus,
    required String remarks,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      // 1. Fetch exam to verify existence, school_id, academic_year_id, and lock state
      final examRow = await _client!
          .from('exams')
          .select('id, school_id, academic_year_id, is_locked')
          .eq('id', examId)
          .maybeSingle();

      if (examRow == null) {
        throw Exception('Exam $examId does not exist.');
      }

      if (examRow['is_locked'] == true) {
        throw Exception('Result is locked. Admin must unlock before editing.');
      }

      final schoolId = examRow['school_id'].toString();
      final academicYearId = examRow['academic_year_id'].toString();

      // 2. Fetch exam_subject_id if exists
      final examSubRow = await _client!
          .from('exam_subjects')
          .select('id')
          .eq('exam_id', examId)
          .limit(1)
          .maybeSingle();
      final examSubjectId = examSubRow?['id']?.toString();

      final currentUserId = _client!.auth.currentUser?.id;

      final Map<String, dynamic> payload = {
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'exam_id': examId,
        'student_id': studentId,
        'marks_obtained': mark,
        'status': attendanceStatus == StudentAttendanceStatus.marked ? 'ENTERED' : attendanceStatus.name.toUpperCase(),
        'remarks': remarks,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (examSubjectId != null && examSubjectId.isNotEmpty) {
        payload['exam_subject_id'] = examSubjectId;
      }
      if (currentUserId != null && currentUserId.isNotEmpty) {
        payload['entered_by'] = currentUserId;
      }

      // Propagate any DB failure directly — NO SILENT CATCH
      await _client!.from('marks').upsert(
        payload,
        onConflict: 'exam_id,student_id',
      );

      try {
        await _client!.from('exams').update({
          'status': 'MARKS_IN_PROGRESS',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', examId).eq('status', 'SCHEDULED');
      } catch (_) {}
    }

    // In-memory cache update
    final list = _examResultsMap[examId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.studentId == studentId);
      if (idx != -1) {
        final current = list[idx];
        if (current.isLocked) {
          throw Exception('Result is locked. Admin must unlock before editing.');
        }

        final subResult = GradeService.calculateSubjectResult(
          subjectName: current.subjectName,
          maxMarks: current.totalMaxMarks,
          obtainedMarks: mark,
          passingMarks: current.totalMaxMarks * 0.35,
        );

        final updated = GradeService.computeOverallStudentResult(
          studentId: current.studentId,
          studentName: current.studentName,
          rollNumber: current.rollNumber,
          className: current.className,
          section: current.section,
          examId: current.examId,
          examTitle: current.examTitle,
          academicYear: current.academicYear,
          subjectName: current.subjectName,
          subjectResults: [subResult],
          attendanceStatus: attendanceStatus,
          teacherRemarks: remarks,
          adminRemarks: current.adminRemarks,
          status: ResultStatus.marksInProgress,
          isLocked: current.isLocked,
          parentId: current.parentId,
          auditHistory: [
            ...current.auditHistory,
            AuditLogEntry(action: 'Marks Saved', performedBy: 'Teacher', timestamp: DateTime.now()),
          ],
        );

        list[idx] = updated;
      }
    }
  }

  // --- WORKFLOW SUBMIT FOR REVIEW ---
  Future<void> submitExamResultsForReview(String examId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _updateExamStatus(examId, ResultStatus.submitted);
  }

  // --- ADMIN WORKFLOW ACTIONS ---
  Future<void> returnExamToTeacher(String examId, String adminRemarks) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _updateExamStatus(examId, ResultStatus.returned, adminRemarks: adminRemarks);
  }

  Future<void> approveExamResults(String examId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _updateExamStatus(examId, ResultStatus.approved);
  }

  Future<void> publishExamResults(String examId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    _updateExamStatus(examId, ResultStatus.published, isLocked: true);
  }

  Future<void> unlockExamResults(String examId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      await _client!.from('exams').update({
        'is_locked': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', examId);
    }

    final list = _examResultsMap[examId];
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(isLocked: false);
      }
    }
  }

  void _updateExamStatus(String examId, ResultStatus status, {String? adminRemarks, bool isLocked = false}) {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        _client!.from('exams').update({
          'status': status.name.toUpperCase(),
          'result_status': status == ResultStatus.published ? 'PUBLISHED' : 'NOT_PUBLISHED',
          'is_locked': isLocked,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', examId);
      } catch (e) {
        debugPrint('[ResultService Supabase Exam Status Update Warning]: $e');
      }
    }

    final exIdx = _exams.indexWhere((e) => e.id == examId);
    if (exIdx != -1) {
      _exams[exIdx] = ExamModel(
        id: _exams[exIdx].id,
        title: _exams[exIdx].title,
        type: _exams[exIdx].type,
        academicYear: _exams[exIdx].academicYear,
        className: _exams[exIdx].className,
        section: _exams[exIdx].section,
        subjectName: _exams[exIdx].subjectName,
        examDate: _exams[exIdx].examDate,
        submissionDeadline: _exams[exIdx].submissionDeadline,
        maxMarks: _exams[exIdx].maxMarks,
        passingMarks: _exams[exIdx].passingMarks,
        instructions: _exams[exIdx].instructions,
        status: status,
        createdByAdminId: _exams[exIdx].createdByAdminId,
      );
    }

    final list = _examResultsMap[examId];
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(
          status: status,
          isLocked: isLocked,
          adminRemarks: adminRemarks ?? list[i].adminRemarks,
          auditHistory: [
            ...list[i].auditHistory,
            AuditLogEntry(action: 'Status changed to ${status.displayName}', performedBy: 'Admin / System', timestamp: DateTime.now()),
          ],
        );
      }
    }
  }

  // Admin Single Mark Correction with Instant Recalculation
  Future<void> editStudentMark({
    required String examId,
    required String studentId,
    required double newObtainedMark,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      final examRow = await _client!
          .from('exams')
          .select('is_locked')
          .eq('id', examId)
          .maybeSingle();

      if (examRow?['is_locked'] == true) {
        throw Exception('Result is locked. Admin must unlock before editing.');
      }

      await _client!.from('marks').update({
        'marks_obtained': newObtainedMark,
        'remarks': 'Mark corrected by Admin.',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('exam_id', examId).eq('student_id', studentId);
    }

    final list = _examResultsMap[examId];
    if (list != null) {
      final idx = list.indexWhere((r) => r.studentId == studentId);
      if (idx != -1) {
        final current = list[idx];
        final subResult = GradeService.calculateSubjectResult(
          subjectName: current.subjectName,
          maxMarks: current.totalMaxMarks,
          obtainedMarks: newObtainedMark,
          passingMarks: current.totalMaxMarks * 0.35,
        );

        final recalculated = GradeService.computeOverallStudentResult(
          studentId: current.studentId,
          studentName: current.studentName,
          rollNumber: current.rollNumber,
          className: current.className,
          section: current.section,
          examId: current.examId,
          examTitle: current.examTitle,
          academicYear: current.academicYear,
          subjectName: current.subjectName,
          subjectResults: [subResult],
          attendanceStatus: StudentAttendanceStatus.marked,
          teacherRemarks: current.teacherRemarks,
          adminRemarks: 'Mark corrected by Admin.',
          status: current.status,
          isLocked: current.isLocked,
          parentId: current.parentId,
          auditHistory: [
            ...current.auditHistory,
            AuditLogEntry(action: 'Mark corrected to $newObtainedMark', performedBy: 'School Administrator', timestamp: DateTime.now()),
          ],
        );

        list[idx] = recalculated;
      }
    }
  }

  Future<ClassResultSummary> getClassResultSummary(String examId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final list = _examResultsMap[examId] ?? [];
    if (list.isEmpty) {
      return const ClassResultSummary(
        className: 'Class 8-A',
        examTitle: 'Unit Test 1',
        totalStudents: 0,
        passedCount: 0,
        failedCount: 0,
        absentCount: 0,
        classAverage: 0.0,
        highestPercentage: 0.0,
        lowestPercentage: 0.0,
        subjectAverages: {},
      );
    }

    int passed = 0;
    int failed = 0;
    int absent = 0;
    double sumPct = 0.0;
    double highest = 0.0;
    double lowest = 100.0;

    for (var r in list) {
      if (r.attendanceStatus != StudentAttendanceStatus.marked) {
        absent++;
      } else {
        if (r.isPassed) {
          passed++;
        } else {
          failed++;
        }
        sumPct += r.percentage;
        if (r.percentage > highest) {
          highest = r.percentage;
        }
        if (r.percentage < lowest) {
          lowest = r.percentage;
        }
      }
    }

    final markedCount = list.length - absent;
    final classAvg = markedCount > 0 ? sumPct / markedCount : 0.0;

    return ClassResultSummary(
      className: list.first.className,
      examTitle: list.first.examTitle,
      totalStudents: list.length,
      passedCount: passed,
      failedCount: failed,
      absentCount: absent,
      classAverage: classAvg,
      highestPercentage: highest,
      lowestPercentage: lowest,
      subjectAverages: {list.first.subjectName: classAvg},
    );
  }

  void setResultsForExam(String examId, List<StudentResultModel> results) {
    _examResultsMap[examId] = results;
  }

  Future<List<SubjectResultModel>> getStudentAcademics(String studentId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('marks')
            .select('marks_obtained, grade, is_passed, exam_subjects(subject_name, max_marks)')
            .eq('student_id', studentId);

        if (data.isNotEmpty) {
          return data.map((m) {
            final examSub = m['exam_subjects'] as Map<String, dynamic>?;
            final max = (examSub?['max_marks'] as num?)?.toDouble() ?? 100.0;
            final obtained = (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
            final pct = max > 0 ? (obtained / max) * 100 : 0.0;
            return SubjectResultModel(
              subjectName: examSub?['subject_name']?.toString() ?? 'Subject',
              maxMarks: max,
              obtainedMarks: obtained,
              percentage: pct,
              grade: m['grade']?.toString() ?? 'N/A',
              isPassed: m['is_passed'] == true,
            );
          }).toList();
        }
      } catch (e) {
        debugPrint('[ResultService getStudentAcademics Warning]: $e');
      }
    }

    // Check in-memory maps
    for (final results in _examResultsMap.values) {
      for (final res in results) {
        if (res.studentId == studentId && res.subjectResults.isNotEmpty) {
          return res.subjectResults;
        }
      }
    }

    return [];
  }

  // --- PARENT SECURE RPC: PUBLISHED EXAM RESULTS ---
  Future<Map<String, dynamic>> getParentPublishedResults({
    required String accessCode,
    required String studentId,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await _client!.rpc(
          'get_parent_student_published_results',
          params: {
            'p_access_code': accessCode.trim(),
            'p_student_id': studentId.trim(),
          },
        );
        if (res is Map<String, dynamic>) {
          return res;
        } else if (res is Map) {
          return Map<String, dynamic>.from(res);
        }
        return {
          'success': false,
          'error': 'Unexpected response format from server.',
          'results': [],
        };
      } catch (e) {
        debugPrint('[ResultService getParentPublishedResults Error]: $e');
        rethrow;
      }
    }
    return {
      'success': false,
      'error': 'Database client is not configured.',
      'results': [],
    };
  }
}
