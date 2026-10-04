import 'user_model.dart';

class ParentModel {
  final String id; // UUID
  final String schoolId; // UUID
  final String parentCode; // Unique Parent ID, e.g. SCH001-PAR-0001
  final String name;
  final String? email;
  final String phone;
  final String? alternatePhone;
  final String? profilePhotoUrl;
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final AccountStatus status;
  final String? authUserId; // Supabase Auth UID mapping
  final int linkedStudentsCount;
  final List<ParentStudentLinkModel> linkedStudents;
  final DateTime createdAt;

  const ParentModel({
    required this.id,
    required this.schoolId,
    required this.parentCode,
    required this.name,
    this.email,
    required this.phone,
    this.alternatePhone,
    this.profilePhotoUrl,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.status = AccountStatus.active,
    this.authUserId,
    this.linkedStudentsCount = 0,
    this.linkedStudents = const [],
    required this.createdAt,
  });

  ParentModel copyWith({
    String? parentCode,
    String? name,
    String? email,
    String? phone,
    String? alternatePhone,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    AccountStatus? status,
    String? authUserId,
    int? linkedStudentsCount,
    List<ParentStudentLinkModel>? linkedStudents,
  }) {
    return ParentModel(
      id: id,
      schoolId: schoolId,
      parentCode: parentCode ?? this.parentCode,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      alternatePhone: alternatePhone ?? this.alternatePhone,
      profilePhotoUrl: profilePhotoUrl,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      status: status ?? this.status,
      authUserId: authUserId ?? this.authUserId,
      linkedStudentsCount: linkedStudentsCount ?? this.linkedStudentsCount,
      linkedStudents: linkedStudents ?? this.linkedStudents,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'parent_code': parentCode,
      'parent_name': name,
      'name': name,
      'email': email,
      'phone': phone,
      'alternate_phone': alternatePhone,
      'profile_photo_url': profilePhotoUrl,
      'address': address,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'status': status.name.toUpperCase(),
      'auth_user_id': authUserId,
      'linked_students_count': linkedStudentsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ParentModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status']?.toString() ?? '').toLowerCase();
    final parsedStatus = (statusStr == 'inactive' || statusStr == 'suspended')
        ? AccountStatus.inactive
        : AccountStatus.active;

    final rawName = json['name']?.toString() ?? json['parent_name']?.toString() ?? '';
    final rawCode = json['parent_code']?.toString() ??
        json['parent_unique_id']?.toString() ??
        json['parentCode']?.toString() ??
        '';

    return ParentModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
      parentCode: rawCode.isNotEmpty ? rawCode : 'SCH001-PAR-0001',
      name: rawName.isNotEmpty ? rawName : 'Parent',
      email: json['email']?.toString(),
      phone: json['phone']?.toString() ?? '',
      alternatePhone: json['alternate_phone']?.toString() ?? json['alternatePhone']?.toString(),
      profilePhotoUrl: json['profile_photo_url']?.toString() ?? json['profilePhotoUrl']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      postalCode: json['postal_code']?.toString() ?? json['postalCode']?.toString(),
      status: parsedStatus,
      authUserId: json['auth_user_id']?.toString() ?? json['authUserId']?.toString(),
      linkedStudentsCount: (json['linked_students_count'] as num?)?.toInt() ??
          (json['linkedStudentsCount'] as num?)?.toInt() ??
          0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ParentStudentLinkModel {
  final String id; // UUID
  final String schoolId; // UUID
  final String parentId; // UUID
  final String studentId; // UUID
  final String relationship; // "FATHER", "MOTHER", "GUARDIAN", "OTHER"
  final bool isPrimary;
  final String studentName;
  final String studentClass; // e.g. "Class 8-A"
  final String admissionNumber; // e.g. "ADM-2026-001"
  final String? avatarUrl;

  const ParentStudentLinkModel({
    required this.id,
    required this.schoolId,
    required this.parentId,
    required this.studentId,
    this.relationship = 'FATHER',
    this.isPrimary = false,
    required this.studentName,
    required this.studentClass,
    required this.admissionNumber,
    this.avatarUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'parent_id': parentId,
      'student_id': studentId,
      'relationship': relationship,
      'is_primary': isPrimary,
      'student_name': studentName,
      'student_class': studentClass,
      'admission_number': admissionNumber,
      'avatar_url': avatarUrl,
    };
  }

  factory ParentStudentLinkModel.fromJson(Map<String, dynamic> json) {
    return ParentStudentLinkModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? json['parentId']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      relationship: json['relationship']?.toString() ?? 'FATHER',
      isPrimary: json['is_primary'] == true || json['isPrimary'] == true,
      studentName: json['student_name']?.toString() ?? json['studentName']?.toString() ?? '',
      studentClass: json['student_class']?.toString() ?? json['studentClass']?.toString() ?? '',
      admissionNumber: json['admission_number']?.toString() ?? json['admissionNumber']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString(),
    );
  }
}

/// Structured summary of parent access state for a specific student.
class StudentParentAccessInfo {
  final String studentId;
  final String studentName;
  final String schoolId;
  final String? parentAccessCode;
  final bool isConfigured;
  final bool isEnabled;
  final AccountStatus status;
  final String? parentAccountId;
  final String? parentAccountName;
  final String? parentCode;
  final String? parentPhone;
  final String? parentEmail;

  const StudentParentAccessInfo({
    required this.studentId,
    required this.studentName,
    required this.schoolId,
    this.parentAccessCode,
    required this.isConfigured,
    required this.isEnabled,
    required this.status,
    this.parentAccountId,
    this.parentAccountName,
    this.parentCode,
    this.parentPhone,
    this.parentEmail,
  });

  StudentParentAccessInfo copyWith({
    String? parentAccessCode,
    bool? isConfigured,
    bool? isEnabled,
    AccountStatus? status,
    String? parentAccountId,
    String? parentAccountName,
    String? parentCode,
    String? parentPhone,
    String? parentEmail,
  }) {
    return StudentParentAccessInfo(
      studentId: studentId,
      studentName: studentName,
      schoolId: schoolId,
      parentAccessCode: parentAccessCode ?? this.parentAccessCode,
      isConfigured: isConfigured ?? this.isConfigured,
      isEnabled: isEnabled ?? this.isEnabled,
      status: status ?? this.status,
      parentAccountId: parentAccountId ?? this.parentAccountId,
      parentAccountName: parentAccountName ?? this.parentAccountName,
      parentCode: parentCode ?? this.parentCode,
      parentPhone: parentPhone ?? this.parentPhone,
      parentEmail: parentEmail ?? this.parentEmail,
    );
  }
}
