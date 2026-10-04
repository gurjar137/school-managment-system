import 'student_model.dart';

class AttendanceRecordModel {
  final String id; // UUID
  final String schoolId; // UUID
  final String academicYearId; // UUID
  final String studentId; // UUID
  final String classId; // UUID
  final String sectionId; // UUID
  final DateTime attendanceDate;
  final AttendanceStatus status;
  final String markedBy;
  final DateTime markedAt;
  final String? remarks;

  const AttendanceRecordModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.studentId,
    required this.classId,
    required this.sectionId,
    required this.attendanceDate,
    required this.status,
    required this.markedBy,
    required this.markedAt,
    this.remarks,
  });

  AttendanceRecordModel copyWith({
    AttendanceStatus? status,
    String? remarks,
  }) {
    return AttendanceRecordModel(
      id: id,
      schoolId: schoolId,
      academicYearId: academicYearId,
      studentId: studentId,
      classId: classId,
      sectionId: sectionId,
      attendanceDate: attendanceDate,
      status: status ?? this.status,
      markedBy: markedBy,
      markedAt: DateTime.now(),
      remarks: remarks ?? this.remarks,
    );
  }
}

class AttendanceSummaryModel {
  final String studentId;
  final String studentName;
  final int totalWorkingDays;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int leaveCount;

  const AttendanceSummaryModel({
    required this.studentId,
    required this.studentName,
    required this.totalWorkingDays,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.leaveCount,
  });

  double get attendancePercentage {
    if (totalWorkingDays <= 0) return 0.0;
    final effectivePresent = presentCount + (lateCount * 0.5);
    return (effectivePresent / totalWorkingDays * 100).clamp(0.0, 100.0);
  }
}
