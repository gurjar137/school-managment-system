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
  final String schoolId;
  final String teacherId;
  final String teacherName;
  final String leaveType; // "Casual", "Sick", "Earned", "Medical", "Emergency"
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String status; // "pending", "approved", "rejected", "cancelled"
  final String adminRemarks;
  final DateTime appliedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? attachmentUrl;

  const TeacherLeaveModel({
    required this.id,
    this.schoolId = '',
    required this.teacherId,
    required this.teacherName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.status,
    this.adminRemarks = '',
    required this.appliedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.attachmentUrl,
  });

  TeacherLeaveModel copyWith({
    String? schoolId,
    String? status,
    String? adminRemarks,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? attachmentUrl,
  }) {
    return TeacherLeaveModel(
      id: id,
      schoolId: schoolId ?? this.schoolId,
      teacherId: teacherId,
      teacherName: teacherName,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      reason: reason,
      status: status ?? this.status,
      adminRemarks: adminRemarks ?? this.adminRemarks,
      appliedAt: appliedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }

  factory TeacherLeaveModel.fromJson(Map<String, dynamic> json) {
    return TeacherLeaveModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? json['requester_id']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? json['requester_name']?.toString() ?? 'Faculty Member',
      leaveType: json['leave_type']?.toString() ?? 'Casual',
      fromDate: json['from_date'] != null
          ? DateTime.tryParse(json['from_date'].toString()) ?? DateTime.now()
          : (json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now() : DateTime.now()),
      toDate: json['to_date'] != null
          ? DateTime.tryParse(json['to_date'].toString()) ?? DateTime.now()
          : (json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now() : DateTime.now()),
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString().toLowerCase() ?? 'pending',
      adminRemarks: json['admin_remarks']?.toString() ?? '',
      appliedAt: json['applied_at'] != null
          ? DateTime.tryParse(json['applied_at'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
      reviewedBy: json['reviewed_by']?.toString(),
      attachmentUrl: json['attachment_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (schoolId.isNotEmpty) 'school_id': schoolId,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'leave_type': leaveType,
      'from_date': fromDate.toIso8601String().substring(0, 10),
      'to_date': toDate.toIso8601String().substring(0, 10),
      'reason': reason,
      'status': status,
      'admin_remarks': adminRemarks,
      'applied_at': appliedAt.toIso8601String(),
      if (reviewedAt != null) 'reviewed_at': reviewedAt!.toIso8601String(),
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
    };
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
