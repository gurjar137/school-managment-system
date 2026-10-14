import 'user_model.dart';

class StaffMemberModel {
  final String id;
  final String? authUserId;
  final String schoolId;
  final String employeeId;
  final String name;
  final String email;
  final String phone;
  final UserRole role; // strictly teacher or staff
  final String designation;
  final String? subject;
  final String? assignedClass;
  final String? assignedSection;
  final AccountStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StaffMemberModel({
    required this.id,
    this.authUserId,
    required this.schoolId,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.designation,
    this.subject,
    this.assignedClass,
    this.assignedSection,
    this.status = AccountStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  bool get isTeacher => role == UserRole.teacher;
  bool get isStaff => role == UserRole.staff;
  bool get isAdministrator => role.isAdministrator;
  bool get isActive => status == AccountStatus.active;

  String get displayAssignment {
    if (!isTeacher) return designation.isNotEmpty ? designation : 'N/A (Staff)';
    final cls = assignedClass ?? '';
    final sec = assignedSection ?? '';
    if (cls.isEmpty && sec.isEmpty) return 'Not Assigned';
    if (cls.isNotEmpty && sec.isNotEmpty) return '$cls - $sec';
    return cls.isNotEmpty ? cls : sec;
  }

  StaffMemberModel copyWith({
    String? name,
    String? phone,
    String? designation,
    String? subject,
    String? assignedClass,
    String? assignedSection,
    AccountStatus? status,
    DateTime? updatedAt,
    UserRole? role,
  }) {
    return StaffMemberModel(
      id: id,
      authUserId: authUserId,
      schoolId: schoolId,
      employeeId: employeeId,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      subject: subject ?? this.subject,
      assignedClass: assignedClass ?? this.assignedClass,
      assignedSection: assignedSection ?? this.assignedSection,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory StaffMemberModel.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role']?.toString() ?? 'teacher').toLowerCase();
    UserRole role;
    if (roleStr.contains('admin') || roleStr.contains('principal') || roleStr.contains('owner')) {
      role = UserRole.schoolAdmin;
    } else if (roleStr.contains('staff') || roleStr.contains('clerk') || roleStr.contains('accountant')) {
      role = UserRole.staff;
    } else {
      role = UserRole.teacher;
    }

    final statusStr = (json['status']?.toString() ?? 'active').toLowerCase();
    final status = (statusStr == 'inactive' || statusStr == 'suspended')
        ? AccountStatus.inactive
        : AccountStatus.active;

    return StaffMemberModel(
      id: json['id']?.toString() ?? '',
      authUserId: json['auth_user_id']?.toString(),
      schoolId: json['school_id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['employee_code']?.toString() ?? '',
      name: (json['full_name'] ?? json['name'] ?? '').toString().trim(),
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      role: role,
      designation: json['designation']?.toString() ?? (role == UserRole.staff ? 'Staff Member' : 'Teacher'),
      subject: json['subject']?.toString(),
      assignedClass: json['assigned_class']?.toString() ?? json['class']?.toString(),
      assignedSection: json['assigned_section']?.toString() ?? json['section']?.toString(),
      status: status,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'school_id': schoolId,
      'employee_id': employeeId,
      'full_name': name,
      'email': email,
      'phone': phone,
      'role': role == UserRole.staff ? 'staff' : 'teacher',
      'designation': designation,
      'subject': subject,
      'assigned_class': assignedClass,
      'assigned_section': assignedSection,
      'status': status == AccountStatus.inactive ? 'inactive' : 'active',
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
