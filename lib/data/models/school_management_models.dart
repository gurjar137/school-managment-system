import 'student_model.dart';
import 'academic_models.dart' hide TimetableSlotModel;
import 'fee_models.dart';
import 'result_models.dart';

class AttendanceCorrectionModel {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final DateTime date;
  final String currentStatus; // e.g. "Absent"
  final String requestedStatus; // e.g. "Present"
  final String reason;
  final String status; // "pending", "approved", "rejected"
  final String requestedByTeacher;
  final DateTime requestedAt;

  const AttendanceCorrectionModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.date,
    required this.currentStatus,
    required this.requestedStatus,
    required this.reason,
    required this.status,
    required this.requestedByTeacher,
    required this.requestedAt,
  });

  AttendanceCorrectionModel copyWith({
    String? status,
  }) {
    return AttendanceCorrectionModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      className: className,
      date: date,
      currentStatus: currentStatus,
      requestedStatus: requestedStatus,
      reason: reason,
      status: status ?? this.status,
      requestedByTeacher: requestedByTeacher,
      requestedAt: requestedAt,
    );
  }
}

class TeacherLeaveModel {
  final String id;
  final String teacherId;
  final String teacherName;
  final String leaveType; // "Casual", "Sick", "Earned"
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status; // "pending", "approved", "rejected"
  final String adminRemarks;
  final DateTime appliedAt;

  const TeacherLeaveModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    this.adminRemarks = '',
    required this.appliedAt,
  });

  TeacherLeaveModel copyWith({
    String? status,
    String? adminRemarks,
  }) {
    return TeacherLeaveModel(
      id: id,
      teacherId: teacherId,
      teacherName: teacherName,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      status: status ?? this.status,
      adminRemarks: adminRemarks ?? this.adminRemarks,
      appliedAt: appliedAt,
    );
  }
}

class TimetableSlotModel {
  final String id;
  final String className;
  final String section;
  final String subjectName;
  final String teacherName;
  final String roomNo;
  final String dayOfWeek; // "Monday", "Tuesday", etc.
  final String startTime;
  final String endTime;
  final bool isNextClass;

  const TimetableSlotModel({
    required this.id,
    required this.className,
    required this.section,
    required this.subjectName,
    required this.teacherName,
    required this.roomNo,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isNextClass = false,
  });
}

class StudentDocumentModel {
  final String id;
  final String studentId;
  final String documentType; // "Birth Certificate", "Transfer Certificate", "ID Proof", "Photo"
  final String fileName;
  final String fileUrl;
  final DateTime uploadedAt;

  const StudentDocumentModel({
    required this.id,
    required this.studentId,
    required this.documentType,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
  });
}

class SchoolSettingsModel {
  final String schoolId;
  final String name;
  final String logoUrl;
  final String address;
  final String phone;
  final String email;
  final String academicYear;
  final List<String> activeClasses;
  final List<String> activeSubjects;

  const SchoolSettingsModel({
    required this.schoolId,
    required this.name,
    required this.logoUrl,
    required this.address,
    required this.phone,
    required this.email,
    required this.academicYear,
    required this.activeClasses,
    required this.activeSubjects,
  });
}

class CategorizedSearchResult {
  final List<StudentModel> students;
  final List<TeacherModel> teachers;
  final List<FeePayment> feePayments;
  final List<FeeReceiptModel> receipts;
  final List<StudentResultModel> results;

  const CategorizedSearchResult({
    required this.students,
    required this.teachers,
    required this.feePayments,
    required this.receipts,
    required this.results,
  });

  bool get isEmpty =>
      students.isEmpty && teachers.isEmpty && feePayments.isEmpty && receipts.isEmpty && results.isEmpty;
}
