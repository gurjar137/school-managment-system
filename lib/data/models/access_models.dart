class TeacherAccessModel {
  final String id;
  final String teacherId;
  final String teacherName;
  final String email;
  final String employeeId;
  final String assignedClass; // e.g. "Class 8-A"
  final String subject;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeacherAccessModel({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.email,
    required this.employeeId,
    required this.assignedClass,
    required this.subject,
    required this.isEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  TeacherAccessModel copyWith({
    String? teacherName,
    String? email,
    String? employeeId,
    String? assignedClass,
    String? subject,
    bool? isEnabled,
    DateTime? updatedAt,
  }) {
    return TeacherAccessModel(
      id: id,
      teacherId: teacherId,
      teacherName: teacherName ?? this.teacherName,
      email: email ?? this.email,
      employeeId: employeeId ?? this.employeeId,
      assignedClass: assignedClass ?? this.assignedClass,
      subject: subject ?? this.subject,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

class ParentAccessCodeModel {
  final String id;
  final String studentId;
  final String studentName;
  final String admissionNo;
  final String className; // e.g. "8-A"
  final String parentName;
  final String parentMobile;
  final String code; // Format: SC-XXXX-XXXX
  final bool isRevoked; // true = REVOKED, false = ACTIVE
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? regeneratedAt;

  const ParentAccessCodeModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.admissionNo,
    required this.className,
    required this.parentName,
    required this.parentMobile,
    required this.code,
    required this.isRevoked,
    required this.createdAt,
    required this.updatedAt,
    this.regeneratedAt,
  });

  bool get isActive => !isRevoked;

  ParentAccessCodeModel copyWith({
    String? code,
    bool? isRevoked,
    DateTime? updatedAt,
    DateTime? regeneratedAt,
  }) {
    return ParentAccessCodeModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      admissionNo: admissionNo,
      className: className,
      parentName: parentName,
      parentMobile: parentMobile,
      code: code ?? this.code,
      isRevoked: isRevoked ?? this.isRevoked,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      regeneratedAt: regeneratedAt ?? this.regeneratedAt,
    );
  }
}

class ActivityLogModel {
  final String id;
  final String actionTitle;
  final String details;
  final String adminName;
  final DateTime timestamp;
  final String category; // e.g. "Teacher Access", "Parent Access", "Student"

  const ActivityLogModel({
    required this.id,
    required this.actionTitle,
    required this.details,
    required this.adminName,
    required this.timestamp,
    required this.category,
  });
}
