enum ExamType {
  unitTest,
  test,
  midTerm,
  halfYearly,
  preBoard,
  finalExam,
  other,
}

extension ExamTypeExtension on ExamType {
  String get displayName {
    switch (this) {
      case ExamType.unitTest:
        return 'Unit Test';
      case ExamType.test:
        return 'Test';
      case ExamType.midTerm:
        return 'Mid Term';
      case ExamType.halfYearly:
        return 'Half Yearly';
      case ExamType.preBoard:
        return 'Pre-Board';
      case ExamType.finalExam:
        return 'Final Exam';
      case ExamType.other:
        return 'Other';
    }
  }
}

enum ResultStatus {
  upcoming,
  open,
  marksInProgress,
  submitted,
  underReview,
  returned,
  approved,
  published,
}

extension ResultStatusExtension on ResultStatus {
  String get displayName {
    switch (this) {
      case ResultStatus.upcoming:
        return 'UPCOMING';
      case ResultStatus.open:
        return 'OPEN';
      case ResultStatus.marksInProgress:
        return 'MARKS IN PROGRESS';
      case ResultStatus.submitted:
        return 'SUBMITTED';
      case ResultStatus.underReview:
        return 'UNDER REVIEW';
      case ResultStatus.returned:
        return 'RETURNED TO TEACHER';
      case ResultStatus.approved:
        return 'APPROVED';
      case ResultStatus.published:
        return 'PUBLISHED';
    }
  }
}

enum StudentAttendanceStatus {
  marked,
  absent,
  exempted,
  notAppeared,
}

extension StudentAttendanceStatusExtension on StudentAttendanceStatus {
  String get displayName {
    switch (this) {
      case StudentAttendanceStatus.marked:
        return 'Marked';
      case StudentAttendanceStatus.absent:
        return 'ABSENT';
      case StudentAttendanceStatus.exempted:
        return 'EXEMPTED';
      case StudentAttendanceStatus.notAppeared:
        return 'NOT APPEARED';
    }
  }
}

class ExamSubjectModel {
  final String subjectName;
  final double maxMarks;
  final double passingMarks;

  const ExamSubjectModel({
    required this.subjectName,
    required this.maxMarks,
    required this.passingMarks,
  });
}

class ExamModel {
  final String id;
  final String title;
  final ExamType type;
  final String academicYear; // e.g. "2026-27"
  final String className; // e.g. "8"
  final String section; // e.g. "A"
  final String subjectName; // e.g. "Mathematics"
  final DateTime examDate;
  final DateTime submissionDeadline;
  final double maxMarks;
  final double passingMarks;
  final String instructions;
  final ResultStatus status;
  final String createdByAdminId;
  final List<ExamSubjectModel> subjects;

  const ExamModel({
    required this.id,
    required this.title,
    required this.type,
    required this.academicYear,
    required this.className,
    required this.section,
    required this.subjectName,
    required this.examDate,
    required this.submissionDeadline,
    required this.maxMarks,
    required this.passingMarks,
    required this.instructions,
    required this.status,
    required this.createdByAdminId,
    this.subjects = const [],
  });

  String get fullClassCode => 'Class $className-$section';

  double get totalMaxMarks => maxMarks > 0 ? maxMarks : subjects.fold(0.0, (sum, sub) => sum + sub.maxMarks);

  ExamModel copyWith({
    String? id,
    String? title,
    ExamType? type,
    String? academicYear,
    String? className,
    String? section,
    String? subjectName,
    DateTime? examDate,
    DateTime? submissionDeadline,
    double? maxMarks,
    double? passingMarks,
    String? instructions,
    ResultStatus? status,
    String? createdByAdminId,
    List<ExamSubjectModel>? subjects,
  }) {
    return ExamModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      academicYear: academicYear ?? this.academicYear,
      className: className ?? this.className,
      section: section ?? this.section,
      subjectName: subjectName ?? this.subjectName,
      examDate: examDate ?? this.examDate,
      submissionDeadline: submissionDeadline ?? this.submissionDeadline,
      maxMarks: maxMarks ?? this.maxMarks,
      passingMarks: passingMarks ?? this.passingMarks,
      instructions: instructions ?? this.instructions,
      status: status ?? this.status,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      subjects: subjects ?? this.subjects,
    );
  }
}

class SubjectResultModel {
  final String subjectName;
  final double maxMarks;
  final double obtainedMarks;
  final double percentage;
  final String grade;
  final bool isPassed;

  const SubjectResultModel({
    required this.subjectName,
    required this.maxMarks,
    required this.obtainedMarks,
    required this.percentage,
    required this.grade,
    required this.isPassed,
  });
}

class AuditLogEntry {
  final String action;
  final String performedBy;
  final DateTime timestamp;

  const AuditLogEntry({
    required this.action,
    required this.performedBy,
    required this.timestamp,
  });
}

class StudentResultModel {
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String className;
  final String section;
  final String examId;
  final String examTitle;
  final String academicYear;
  final String subjectName;
  final List<SubjectResultModel> subjectResults;
  final double totalMaxMarks;
  final double totalObtainedMarks;
  final double percentage;
  final String overallGrade;
  final bool isPassed;
  final StudentAttendanceStatus attendanceStatus;
  final String teacherRemarks;
  final String adminRemarks;
  final ResultStatus status;
  final bool isLocked;
  final String parentId;
  final List<AuditLogEntry> auditHistory;

  const StudentResultModel({
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.className,
    required this.section,
    required this.examId,
    required this.examTitle,
    required this.academicYear,
    required this.subjectName,
    required this.subjectResults,
    required this.totalMaxMarks,
    required this.totalObtainedMarks,
    required this.percentage,
    required this.overallGrade,
    required this.isPassed,
    this.attendanceStatus = StudentAttendanceStatus.marked,
    required this.teacherRemarks,
    this.adminRemarks = '',
    required this.status,
    required this.isLocked,
    required this.parentId,
    required this.auditHistory,
  });

  bool get isComplete => attendanceStatus != StudentAttendanceStatus.marked || totalObtainedMarks >= 0;

  StudentResultModel copyWith({
    List<SubjectResultModel>? subjectResults,
    double? totalMaxMarks,
    double? totalObtainedMarks,
    double? percentage,
    String? overallGrade,
    bool? isPassed,
    StudentAttendanceStatus? attendanceStatus,
    String? teacherRemarks,
    String? adminRemarks,
    ResultStatus? status,
    bool? isLocked,
    List<AuditLogEntry>? auditHistory,
  }) {
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
      subjectResults: subjectResults ?? this.subjectResults,
      totalMaxMarks: totalMaxMarks ?? this.totalMaxMarks,
      totalObtainedMarks: totalObtainedMarks ?? this.totalObtainedMarks,
      percentage: percentage ?? this.percentage,
      overallGrade: overallGrade ?? this.overallGrade,
      isPassed: isPassed ?? this.isPassed,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      teacherRemarks: teacherRemarks ?? this.teacherRemarks,
      adminRemarks: adminRemarks ?? this.adminRemarks,
      status: status ?? this.status,
      isLocked: isLocked ?? this.isLocked,
      parentId: parentId,
      auditHistory: auditHistory ?? this.auditHistory,
    );
  }
}

class ClassResultSummary {
  final String className;
  final String examTitle;
  final int totalStudents;
  final int passedCount;
  final int failedCount;
  final int absentCount;
  final double classAverage;
  final double highestPercentage;
  final double lowestPercentage;
  final Map<String, double> subjectAverages;

  const ClassResultSummary({
    required this.className,
    required this.examTitle,
    required this.totalStudents,
    required this.passedCount,
    required this.failedCount,
    required this.absentCount,
    required this.classAverage,
    required this.highestPercentage,
    required this.lowestPercentage,
    required this.subjectAverages,
  });
}
