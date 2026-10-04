import '../models/result_models.dart';

class GradeService {
  // Configurable Grade Logic
  static String calculateGrade(double percentage) {
    if (percentage >= 90.0) return 'A+';
    if (percentage >= 80.0) return 'A';
    if (percentage >= 70.0) return 'B+';
    if (percentage >= 60.0) return 'B';
    if (percentage >= 50.0) return 'C';
    if (percentage >= 40.0) return 'D';
    return 'F';
  }

  // Calculate Subject Level Result
  static SubjectResultModel calculateSubjectResult({
    required String subjectName,
    required double maxMarks,
    required double obtainedMarks,
    required double passingMarks,
  }) {
    final clampedObtained = obtainedMarks.clamp(0.0, maxMarks);
    final percentage = maxMarks > 0 ? (clampedObtained / maxMarks) * 100 : 0.0;
    final grade = calculateGrade(percentage);
    final isPassed = clampedObtained >= passingMarks;

    return SubjectResultModel(
      subjectName: subjectName,
      maxMarks: maxMarks,
      obtainedMarks: clampedObtained,
      percentage: percentage,
      grade: grade,
      isPassed: isPassed,
    );
  }

  // Compute Overall Student Result from Subject Results & Attendance Status
  static StudentResultModel computeOverallStudentResult({
    required String studentId,
    required String studentName,
    required String rollNumber,
    required String className,
    required String section,
    required String examId,
    required String examTitle,
    required String academicYear,
    required String subjectName,
    required List<SubjectResultModel> subjectResults,
    required StudentAttendanceStatus attendanceStatus,
    required String teacherRemarks,
    String adminRemarks = '',
    required ResultStatus status,
    required bool isLocked,
    required String parentId,
    List<AuditLogEntry>? auditHistory,
  }) {
    if (attendanceStatus != StudentAttendanceStatus.marked) {
      return StudentResultModel(
        studentId: studentId,
        studentName: studentName,
        rollNumber: rollNumber,
        className: className,
        section: section,
        examId: examId,
        examTitle: examTitle,
        academicYear: academicYear,
        subjectName: subjectName,
        subjectResults: subjectResults,
        totalMaxMarks: subjectResults.isNotEmpty ? subjectResults.first.maxMarks : 50.0,
        totalObtainedMarks: 0.0,
        percentage: 0.0,
        overallGrade: 'N/A',
        isPassed: false,
        attendanceStatus: attendanceStatus,
        teacherRemarks: teacherRemarks.isNotEmpty ? teacherRemarks : attendanceStatus.displayName,
        adminRemarks: adminRemarks,
        status: status,
        isLocked: isLocked,
        parentId: parentId,
        auditHistory: auditHistory ?? [],
      );
    }

    double totalMax = 0.0;
    double totalObtained = 0.0;
    bool allPassed = true;

    for (var s in subjectResults) {
      totalMax += s.maxMarks;
      totalObtained += s.obtainedMarks;
      if (!s.isPassed) allPassed = false;
    }

    final percentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0.0;
    final overallGrade = calculateGrade(percentage);
    final isPassed = allPassed && (percentage >= 40.0);

    return StudentResultModel(
      studentId: studentId,
      studentName: studentName,
      rollNumber: rollNumber,
      className: className,
      section: section,
      examId: examId,
      examTitle: examTitle,
      academicYear: academicYear,
      subjectName: subjectName,
      subjectResults: subjectResults,
      totalMaxMarks: totalMax,
      totalObtainedMarks: totalObtained,
      percentage: percentage,
      overallGrade: overallGrade,
      isPassed: isPassed,
      attendanceStatus: StudentAttendanceStatus.marked,
      teacherRemarks: teacherRemarks,
      adminRemarks: adminRemarks,
      status: status,
      isLocked: isLocked,
      parentId: parentId,
      auditHistory: auditHistory ?? [],
    );
  }
}
