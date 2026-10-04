enum UserRole {
  owner,
  superAdmin,
  schoolAdmin,
  staff,
  teacher;

  bool get isAdministrator =>
      this == UserRole.owner || this == UserRole.superAdmin || this == UserRole.schoolAdmin;

  bool get isStaffOrTeacher =>
      this == UserRole.staff || this == UserRole.teacher;

  String get displayName {
    switch (this) {
      case UserRole.owner:
        return 'School Owner';
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.schoolAdmin:
        return 'School Admin';
      case UserRole.staff:
        return 'School Staff';
      case UserRole.teacher:
        return 'Class Teacher';
    }
  }
}

enum AccountStatus {
  active,
  inactive,
  suspended;

  String get displayName => name.toUpperCase();
}

class UserProfileModel {
  final String id;
  final String authUserId;
  final String schoolId;
  final String schoolName;
  final String name;
  final String email;
  final UserRole role;
  final AccountStatus status;
  final String designation;
  final String? avatarUrl;
  final String? assignedClass;
  final String? assignedSection;
  final String? subject;
  final bool mustChangePassword;
  final DateTime createdAt;

  const UserProfileModel({
    required this.id,
    required this.authUserId,
    required this.schoolId,
    required this.schoolName,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    required this.designation,
    this.avatarUrl,
    this.assignedClass,
    this.assignedSection,
    this.subject,
    this.mustChangePassword = false,
    required this.createdAt,
  });

  UserProfileModel copyWith({
    String? name,
    UserRole? role,
    AccountStatus? status,
    String? designation,
    String? assignedClass,
    String? assignedSection,
    String? subject,
    bool? mustChangePassword,
  }) {
    return UserProfileModel(
      id: id,
      authUserId: authUserId,
      schoolId: schoolId,
      schoolName: schoolName,
      name: name ?? this.name,
      email: email,
      role: role ?? this.role,
      status: status ?? this.status,
      designation: designation ?? this.designation,
      avatarUrl: avatarUrl,
      assignedClass: assignedClass ?? this.assignedClass,
      assignedSection: assignedSection ?? this.assignedSection,
      subject: subject ?? this.subject,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      createdAt: createdAt,
    );
  }
}

class UserModel {
  final String id;
  final String? schoolId;
  final String name;
  final String email;
  final UserRole role;
  final String avatarUrl;
  final String schoolName;
  final String designation;
  final String? assignedClass; // e.g. "12" or "12-F"
  final String? assignedSection; // e.g. "F"
  final String? subject; // e.g. "Mathematics"
  final int? totalStudentsInClass; // e.g. 42
  final AccountStatus status;

  const UserModel({
    required this.id,
    this.schoolId,
    required this.name,
    required this.email,
    required this.role,
    required this.avatarUrl,
    required this.schoolName,
    required this.designation,
    this.assignedClass,
    this.assignedSection,
    this.subject,
    this.totalStudentsInClass,
    this.status = AccountStatus.active,
  });

  String get roleDisplayName {
    switch (role) {
      case UserRole.owner:
        return 'School Owner';
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.schoolAdmin:
        return 'School Admin';
      case UserRole.teacher:
        return 'Class Teacher (${assignedClass ?? "8-A"})';
      case UserRole.staff:
        return 'School Staff';
    }
  }
}
