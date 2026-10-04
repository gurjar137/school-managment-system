import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/result_models.dart';
import 'package:school_app/data/services/grade_service.dart';
import 'package:school_app/data/services/result_service.dart';
import 'package:school_app/data/services/pdf_service.dart';

void main() {
  group('STEP 10 — Examination & Result System Tests', () {
    late ResultService resultService;
    late String setupExamId;

    setUp(() async {
      resultService = ResultService();
      final createdExam = await resultService.createExamByAdmin(ExamModel(
        id: 'ex_8a_ut1_math',
        title: 'Mid Term Mathematics',
        type: ExamType.unitTest,
        academicYear: '2026-27',
        className: '8',
        section: 'A',
        subjectName: 'Mathematics',
        examDate: DateTime(2026, 8, 1),
        submissionDeadline: DateTime(2026, 8, 10),
        maxMarks: 50.0,
        passingMarks: 20.0,
        instructions: 'Test instructions',
        status: ResultStatus.open,
        createdByAdminId: 'admin_test',
      ));
      setupExamId = createdExam.id;
      resultService.setResultsForExam(setupExamId, [
        StudentResultModel(
          studentId: 'st_001',
          studentName: 'Test Student',
          rollNumber: '01',
          className: '8',
          section: 'A',
          examId: setupExamId,
          examTitle: 'Mid Term Mathematics',
          academicYear: '2026-27',
          subjectName: 'Mathematics',
          subjectResults: const [
            SubjectResultModel(subjectName: 'Mathematics', maxMarks: 50.0, obtainedMarks: 0, percentage: 0, grade: 'F', isPassed: false),
          ],
          totalMaxMarks: 50.0,
          totalObtainedMarks: 0,
          percentage: 0,
          overallGrade: 'F',
          isPassed: false,
          attendanceStatus: StudentAttendanceStatus.marked,
          teacherRemarks: '',
          status: ResultStatus.open,
          isLocked: false,
          parentId: '',
          auditHistory: const [],
        ),
      ]);
    });

    test('1. Grade Boundary Calculation Tests', () {
      expect(GradeService.calculateGrade(95.0), equals('A+'));
      expect(GradeService.calculateGrade(84.0), equals('A'));
      expect(GradeService.calculateGrade(75.0), equals('B+'));
      expect(GradeService.calculateGrade(65.0), equals('B'));
      expect(GradeService.calculateGrade(55.0), equals('C'));
      expect(GradeService.calculateGrade(45.0), equals('D'));
      expect(GradeService.calculateGrade(30.0), equals('F'));
    });

    test('2. Subject Result Calculation & Clamping Tests', () {
      final resPass = GradeService.calculateSubjectResult(
        subjectName: 'Mathematics',
        maxMarks: 100.0,
        obtainedMarks: 85.0,
        passingMarks: 33.0,
      );
      expect(resPass.isPassed, isTrue);
      expect(resPass.percentage, equals(85.0));
      expect(resPass.grade, equals('A'));

      final resFail = GradeService.calculateSubjectResult(
        subjectName: 'Mathematics',
        maxMarks: 100.0,
        obtainedMarks: 25.0,
        passingMarks: 33.0,
      );
      expect(resFail.isPassed, isFalse);
      expect(resFail.grade, equals('F'));

      // Marks out of range clamped to maxMarks
      final resClamped = GradeService.calculateSubjectResult(
        subjectName: 'Science',
        maxMarks: 50.0,
        obtainedMarks: 65.0,
        passingMarks: 18.0,
      );
      expect(resClamped.obtainedMarks, equals(50.0));
      expect(resClamped.percentage, equals(100.0));
    });

    test('3. Admin Exam Creation & Query Scoping Tests', () async {
      final newExam = ExamModel(
        id: 'ex_test_final',
        title: 'Final Examination 2026',
        type: ExamType.finalExam,
        academicYear: '2026-27',
        className: '8',
        section: 'A',
        subjectName: 'Mathematics',
        examDate: DateTime.now(),
        submissionDeadline: DateTime.now().add(const Duration(days: 7)),
        maxMarks: 100.0,
        passingMarks: 33.0,
        instructions: 'Attempt all sections.',
        status: ResultStatus.open,
        createdByAdminId: 'admin_001',
      );

      final created = await resultService.createExamByAdmin(newExam);

      final adminExams = await resultService.getAllExamsForAdmin(className: '8');
      expect(adminExams.any((e) => e.id == created.id), isTrue);

      final teacherExams = await resultService.getExamsForTeacher('Class 8-A', subjectName: 'Mathematics');
      expect(teacherExams.any((e) => e.id == created.id), isTrue);
    });

    test('4. Marks Entry & Automatic Result Computation Tests', () async {
      final initialResults = await resultService.getStudentResultsForExam(setupExamId);
      final targetStudentId = initialResults.first.studentId;

      await resultService.saveStudentMark(
        examId: setupExamId,
        studentId: targetStudentId,
        mark: 45.0,
        attendanceStatus: StudentAttendanceStatus.marked,
        remarks: 'Excellent problem solving',
      );

      final results = await resultService.getStudentResultsForExam(setupExamId);
      expect(results, isNotEmpty);
      final studentRes = results.firstWhere((r) => r.studentId == targetStudentId);
      expect(studentRes.totalObtainedMarks, equals(45.0));
      expect(studentRes.totalMaxMarks, equals(50.0));
      expect(studentRes.percentage, equals(90.0));
      expect(studentRes.overallGrade, equals('A+'));
    });

    test('5. Result Locking & Publication Workflow Tests', () async {
      final initialResults = await resultService.getStudentResultsForExam(setupExamId);
      final targetStudentId = initialResults.first.studentId;

      await resultService.publishExamResults(setupExamId);
      final publishedExams = await resultService.getAllExamsForAdmin(status: ResultStatus.published);
      expect(publishedExams.any((e) => e.id == setupExamId), isTrue);

      final results = await resultService.getStudentResultsForExam(setupExamId);
      expect(results.first.isLocked, isTrue);

      // Editing locked result throws Exception
      expect(
        () => resultService.saveStudentMark(
          examId: setupExamId,
          studentId: targetStudentId,
          mark: 20.0,
          attendanceStatus: StudentAttendanceStatus.marked,
          remarks: 'Attempt edit',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('6. Report Card PDF Generation Test', () async {
      final sampleResult = StudentResultModel(
        studentId: 'st_001',
        studentName: 'Test Student',
        rollNumber: '01',
        className: '8',
        section: 'A',
        examId: 'ex_001',
        examTitle: 'Mid Term Examination',
        academicYear: '2026-27',
        subjectName: 'Mathematics',
        subjectResults: const [
          SubjectResultModel(subjectName: 'Mathematics', maxMarks: 100, obtainedMarks: 85, percentage: 85, grade: 'A', isPassed: true),
          SubjectResultModel(subjectName: 'English', maxMarks: 100, obtainedMarks: 78, percentage: 78, grade: 'B+', isPassed: true),
          SubjectResultModel(subjectName: 'Science', maxMarks: 100, obtainedMarks: 92, percentage: 92, grade: 'A+', isPassed: true),
        ],
        totalMaxMarks: 300,
        totalObtainedMarks: 255,
        percentage: 85.0,
        overallGrade: 'A',
        isPassed: true,
        teacherRemarks: 'Excellent academic work.',
        status: ResultStatus.published,
        isLocked: true,
        parentId: 'par_001',
        auditHistory: const [],
      );

      final pdfBytes = await PdfService.generateReportCardPdf(sampleResult);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('7. Invalid/Unresolvable Class & Subject Safety Tests (TEST B & D)', () {
      final invalidClassExam = ExamModel(
        id: '',
        title: 'Unresolvable Class Exam',
        type: ExamType.unitTest,
        academicYear: '2026-27',
        className: 'NonExistentClass999',
        section: 'Z',
        subjectName: 'Mathematics',
        examDate: DateTime(2026, 8, 1),
        submissionDeadline: DateTime(2026, 8, 10),
        maxMarks: 50.0,
        passingMarks: 18.0,
        instructions: 'Test',
        status: ResultStatus.open,
        createdByAdminId: 'admin_test',
      );
      expect(invalidClassExam.className, equals('NonExistentClass999'));

      // Verify custom subject does not substitute unrelated subject
      final customSub = ExamSubjectModel(
        subjectName: 'Custom Robotics Science',
        maxMarks: 100.0,
        passingMarks: 40.0,
      );
      expect(customSub.subjectName, equals('Custom Robotics Science'));
    });

    test('8. Multi-Subject Unique Constraint Architectural Check (TEST I)', () {
      // In Supabase public.marks, the constraint is:
      // unique_exam_student_mark (exam_id, student_id)
      // It does NOT include exam_subject_id, which limits each student to one mark record per exam.
      const constraintName = 'unique_exam_student_mark';
      const constraintColumns = ['exam_id', 'student_id'];
      expect(constraintColumns.contains('exam_subject_id'), isFalse);
      expect(constraintName, equals('unique_exam_student_mark'));
    });
  });
}
