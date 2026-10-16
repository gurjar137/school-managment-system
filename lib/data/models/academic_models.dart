import 'user_model.dart';

class PaymentReceiptModel {
  final String receiptNo;
  final String date;
  final double amountPaid;
  final String paymentMode;
  final String description;

  const PaymentReceiptModel({
    required this.receiptNo,
    required this.date,
    required this.amountPaid,
    required this.paymentMode,
    required this.description,
  });
}

class TeacherModel {
  final String id;
  final String schoolId;
  final String employeeId;
  final String name;
  final String email;
  final List<String> subjects;
  final String assignedClass;
  final String assignedSection;
  final int totalStudents;
  final String avatarUrl;
  final String phone;
  final String designation;
  final AccountStatus status;
  final String? joiningDate;
  final String? authUserId;

  final UserRole role;

  const TeacherModel({
    required this.id,
    this.schoolId = '',
    this.employeeId = 'EMP-0042',
    required this.name,
    required this.email,
    required this.subjects,
    required this.assignedClass,
    this.assignedSection = '',
    required this.totalStudents,
    required this.avatarUrl,
    required this.phone,
    required this.designation,
    this.status = AccountStatus.active,
    this.joiningDate,
    this.authUserId,
    this.role = UserRole.teacher,
  });

  bool get isAdministrator => role.isAdministrator;
  bool get isTeacher => role == UserRole.teacher;
  bool get isStaff => role == UserRole.staff;

  String get roleDisplayName {
    switch (role) {
      case UserRole.owner:
      case UserRole.superAdmin:
      case UserRole.schoolAdmin:
        return 'Administrator';
      case UserRole.staff:
        return 'School Staff';
      case UserRole.teacher:
        return 'Teacher';
    }
  }

  String get className {
    if (assignedClass.trim().isNotEmpty) {
      if (assignedClass.contains('-')) {
        return assignedClass.split('-').first.trim();
      }
      return assignedClass.trim();
    }
    return '';
  }

  String get sectionName {
    if (assignedSection.trim().isNotEmpty) {
      return assignedSection.trim();
    }
    if (assignedClass.contains('-')) {
      final parts = assignedClass.split('-');
      if (parts.length > 1) {
        return parts.sublist(1).join('-').trim();
      }
    }
    return '';
  }

  bool get hasAssignment => className.isNotEmpty || sectionName.isNotEmpty;

  TeacherModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? designation,
    String? assignedClass,
    String? assignedSection,
    AccountStatus? status,
    List<String>? subjects,
    UserRole? role,
  }) {
    return TeacherModel(
      id: id,
      schoolId: schoolId,
      employeeId: employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      subjects: subjects ?? this.subjects,
      assignedClass: assignedClass ?? this.assignedClass,
      assignedSection: assignedSection ?? this.assignedSection,
      totalStudents: totalStudents,
      avatarUrl: avatarUrl,
      phone: phone ?? this.phone,
      designation: designation ?? this.designation,
      status: status ?? this.status,
      joiningDate: joiningDate,
      authUserId: authUserId,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'subjects': subjects,
      'assignedClass': assignedClass,
      'assignedSection': assignedSection,
      'totalStudents': totalStudents,
      'avatarUrl': avatarUrl,
      'phone': phone,
      'designation': designation,
      'status': status.name,
      'joiningDate': joiningDate,
      'authUserId': authUserId,
      'role': role.name,
    };
  }

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    AccountStatus parsedStatus = AccountStatus.active;
    final statusStr = json['status']?.toString().toLowerCase();
    if (statusStr == 'inactive' || statusStr == 'suspended') {
      parsedStatus = AccountStatus.inactive;
    }

    UserRole parsedRole = UserRole.teacher;
    final roleRaw = (json['role']?.toString() ?? 'teacher').toLowerCase();
    if (roleRaw.contains('admin') || roleRaw.contains('principal') || roleRaw.contains('owner')) {
      parsedRole = UserRole.schoolAdmin;
    } else if (roleRaw.contains('staff') || roleRaw.contains('clerk') || roleRaw.contains('accountant')) {
      parsedRole = UserRole.staff;
    }

    return TeacherModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['schoolId']?.toString() ?? json['school_id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? json['employee_id']?.toString() ?? 'EMP-0042',
      name: (json['name'] ?? json['full_name'] ?? 'Teacher').toString().trim(),
      email: json['email']?.toString() ?? '',
      subjects: json['subjects'] != null ? List<String>.from(json['subjects']) : const [],
      assignedClass: json['assignedClass']?.toString() ?? json['assigned_class']?.toString() ?? '',
      assignedSection: json['assignedSection']?.toString() ?? json['assigned_section']?.toString() ?? '',
      totalStudents: (json['totalStudents'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      designation: json['designation']?.toString() ?? (parsedRole.isAdministrator ? 'Administrator' : 'Teacher'),
      status: parsedStatus,
      joiningDate: json['joiningDate']?.toString(),
      authUserId: json['authUserId']?.toString() ?? json['auth_user_id']?.toString(),
      role: parsedRole,
    );
  }
}

class SubjectModel {
  final String id;
  final String schoolId;
  final String name;
  final String? code;
  final String? type; // "THEORY", "PRACTICAL", "ELECTIVE"
  final AccountStatus status;

  const SubjectModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.code,
    this.type = 'THEORY',
    this.status = AccountStatus.active,
  });

  SubjectModel copyWith({
    String? name,
    String? code,
    String? type,
    AccountStatus? status,
  }) {
    return SubjectModel(
      id: id,
      schoolId: schoolId,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      status: status ?? this.status,
    );
  }
}

class TeacherAssignmentModel {
  final String id;
  final String schoolId;
  final String teacherId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final String subjectId;
  final String className;
  final String subjectName;
  final bool isClassTeacher;
  final AccountStatus status;

  const TeacherAssignmentModel({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.academicYearId,
    required this.classId,
    required this.sectionId,
    required this.subjectId,
    required this.className,
    required this.subjectName,
    this.isClassTeacher = false,
    this.status = AccountStatus.active,
  });
}

class ClassroomModel {
  final String id;
  final String className;
  final String section;
  final String classTeacherName;
  final int totalStudents;
  final String currentSubject;
  final double todayAttendancePct;

  const ClassroomModel({
    required this.id,
    required this.className,
    required this.section,
    required this.classTeacherName,
    required this.totalStudents,
    required this.currentSubject,
    required this.todayAttendancePct,
  });

  String get fullCode => '$className-$section';
}

enum HomeworkStatus { active, dueSoon, completed }

class HomeworkModel {
  final String id;
  final String subject;
  final String className;
  final String section;
  final String title;
  final String description;
  final DateTime assignedDate;
  final DateTime dueDate;
  final String? attachmentName;
  final HomeworkStatus status;

  const HomeworkModel({
    required this.id,
    required this.subject,
    required this.className,
    required this.section,
    required this.title,
    required this.description,
    required this.assignedDate,
    required this.dueDate,
    this.attachmentName,
    required this.status,
  });

  factory HomeworkModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toLowerCase() ?? 'active';
    HomeworkStatus status = HomeworkStatus.active;
    if (statusStr == 'completed') {
      status = HomeworkStatus.completed;
    } else if (statusStr == 'duesoon' || statusStr == 'due_soon') {
      status = HomeworkStatus.dueSoon;
    }

    return HomeworkModel(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'General',
      className: json['class_name']?.toString() ?? '',
      section: json['section_name']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      assignedDate: json['assigned_date'] != null
          ? DateTime.tryParse(json['assigned_date'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      attachmentName: json['attachment_name']?.toString(),
      status: status,
    );
  }

  Map<String, dynamic> toJson({String? schoolId, String? academicYearId, String? createdBy}) {
    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
    return {
      if (id.isNotEmpty && isUuid) 'id': id,
      if (schoolId != null) 'school_id': schoolId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      'class_name': className,
      'section_name': section,
      'subject': subject,
      'title': title,
      'description': description,
      'due_date': dueDate.toIso8601String().substring(0, 10),
      'assigned_date': assignedDate.toIso8601String().substring(0, 10),
      'status': status.name,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}

class ExamModel {
  final String id;
  final String title;
  final String className;
  final DateTime date;
  final String subject;
  final int totalMarks;
  final int passingMarks;
  final String room;

  const ExamModel({
    required this.id,
    required this.title,
    required this.className,
    required this.date,
    required this.subject,
    required this.totalMarks,
    required this.passingMarks,
    required this.room,
  });
}

class TimetableSlotModel {
  final String id;
  final String day; // MON, TUE, WED, THU, FRI
  final String startTime;
  final String endTime;
  final String subject;
  final String teacherName;
  final String roomNumber;
  final String className;
  final bool isCurrent;

  const TimetableSlotModel({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.teacherName,
    required this.roomNumber,
    required this.className,
    this.isCurrent = false,
  });
}

class NoticeModel {
  final String id;
  final String schoolId;
  final String title;
  final String content;
  final String category;
  final DateTime date;
  final String author;
  final String targetAudience; // 'All Staff', 'Teachers Only', 'Parents', 'Everyone'
  final String status; // 'Published', 'Draft', 'Archived'
  final bool isPinned;
  final bool isUnread;
  final DateTime? expiresAt;
  final String? attachmentUrl;

  const NoticeModel({
    required this.id,
    this.schoolId = '',
    required this.title,
    required this.content,
    required this.category,
    required this.date,
    required this.author,
    this.targetAudience = 'All Staff',
    this.status = 'Published',
    this.isPinned = false,
    this.isUnread = false,
    this.expiresAt,
    this.attachmentUrl,
  });

  NoticeModel copyWith({
    String? id,
    String? schoolId,
    String? title,
    String? content,
    String? category,
    DateTime? date,
    String? author,
    String? targetAudience,
    String? status,
    bool? isPinned,
    bool? isUnread,
    DateTime? expiresAt,
    String? attachmentUrl,
  }) {
    return NoticeModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      date: date ?? this.date,
      author: author ?? this.author,
      targetAudience: targetAudience ?? this.targetAudience,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      isUnread: isUnread ?? this.isUnread,
      expiresAt: expiresAt ?? this.expiresAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      date: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['date'] != null ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now() : DateTime.now()),
      author: json['author']?.toString() ?? json['author_name']?.toString() ?? 'Administration',
      targetAudience: json['target_audience']?.toString() ?? 'All Staff',
      status: json['status']?.toString() ?? 'Published',
      isPinned: json['is_pinned'] == true,
      isUnread: json['is_unread'] == true,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      attachmentUrl: json['attachment_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson({String? schoolId, String? academicYearId, String? createdBy}) {
    return {
      if (id.isNotEmpty) 'id': id,
      if (schoolId != null || this.schoolId.isNotEmpty) 'school_id': schoolId ?? this.schoolId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      'title': title,
      'content': content,
      'category': category,
      'author': author,
      'target_audience': targetAudience,
      'status': status,
      'is_pinned': isPinned,
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}

class SchoolMeetingModel {
  final String id;
  final String schoolId;
  final String title;
  final String agenda;
  final DateTime meetingDate;
  final String startTime;
  final String endTime;
  final String locationOrLink;
  final String organizerId;
  final String organizerName;
  final String targetAudience; // 'All Staff', 'Teachers', 'Department Heads'
  final String status; // 'Scheduled', 'Rescheduled', 'Completed', 'Cancelled'
  final String cancelReason;
  final DateTime createdAt;

  const SchoolMeetingModel({
    required this.id,
    this.schoolId = '',
    required this.title,
    required this.agenda,
    required this.meetingDate,
    required this.startTime,
    required this.endTime,
    required this.locationOrLink,
    required this.organizerId,
    required this.organizerName,
    this.targetAudience = 'All Staff',
    this.status = 'Scheduled',
    this.cancelReason = '',
    required this.createdAt,
  });

  SchoolMeetingModel copyWith({
    String? id,
    String? schoolId,
    String? title,
    String? agenda,
    DateTime? meetingDate,
    String? startTime,
    String? endTime,
    String? locationOrLink,
    String? organizerId,
    String? organizerName,
    String? targetAudience,
    String? status,
    String? cancelReason,
    DateTime? createdAt,
  }) {
    return SchoolMeetingModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      title: title ?? this.title,
      agenda: agenda ?? this.agenda,
      meetingDate: meetingDate ?? this.meetingDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      locationOrLink: locationOrLink ?? this.locationOrLink,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      targetAudience: targetAudience ?? this.targetAudience,
      status: status ?? this.status,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory SchoolMeetingModel.fromJson(Map<String, dynamic> json) {
    return SchoolMeetingModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      agenda: json['agenda']?.toString() ?? json['description']?.toString() ?? '',
      meetingDate: json['meeting_date'] != null
          ? DateTime.tryParse(json['meeting_date'].toString()) ?? DateTime.now()
          : (json['start_datetime'] != null ? DateTime.tryParse(json['start_datetime'].toString()) ?? DateTime.now() : DateTime.now()),
      startTime: json['start_time']?.toString() ?? '10:00 AM',
      endTime: json['end_time']?.toString() ?? '11:00 AM',
      locationOrLink: json['location_or_link']?.toString() ?? json['location']?.toString() ?? 'Main Conference Hall',
      organizerId: json['organizer_id']?.toString() ?? json['created_by']?.toString() ?? '',
      organizerName: json['organizer_name']?.toString() ?? 'School Administration',
      targetAudience: json['target_audience']?.toString() ?? 'All Staff',
      status: json['status']?.toString() ?? 'Scheduled',
      cancelReason: json['cancel_reason']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson({String? schoolId}) {
    return {
      'id': id,
      if (schoolId != null || this.schoolId.isNotEmpty) 'school_id': schoolId ?? this.schoolId,
      'title': title,
      'agenda': agenda,
      'meeting_date': meetingDate.toIso8601String().substring(0, 10),
      'start_time': startTime,
      'end_time': endTime,
      'location_or_link': locationOrLink,
      'organizer_id': organizerId,
      'organizer_name': organizerName,
      'target_audience': targetAudience,
      'status': status,
      'cancel_reason': cancelReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

enum LeaveStatus { pending, approved, rejected }

class LeaveRequestModel {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;

  const LeaveRequestModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
  });

  LeaveRequestModel copyWith({LeaveStatus? status}) {
    return LeaveRequestModel(
      id: id,
      studentId: studentId,
      studentName: studentName,
      className: className,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: status ?? this.status,
    );
  }

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString().toLowerCase() ?? 'pending';
    LeaveStatus status = LeaveStatus.pending;
    if (statusStr == 'approved') {
      status = LeaveStatus.approved;
    } else if (statusStr == 'rejected') {
      status = LeaveStatus.rejected;
    }
    return LeaveRequestModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      className: json['class_name']?.toString() ?? '',
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      reason: json['reason']?.toString() ?? '',
      status: status,
    );
  }

  Map<String, dynamic> toJson({String? schoolId, String? academicYearId}) {
    return {
      if (id.isNotEmpty) 'id': id,
      if (schoolId != null) 'school_id': schoolId,
      if (academicYearId != null) 'academic_year_id': academicYearId,
      'student_id': studentId,
      'student_name': studentName,
      'class_name': className,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'reason': reason,
      'status': status.name.toUpperCase(),
    };
  }
}

enum FeeStatus { paid, partial, pending, overdue }

class FeeRecordModel {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String feeType;
  final double amount;
  final double paidAmount;
  final DateTime dueDate;
  final FeeStatus status;

  const FeeRecordModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.feeType,
    required this.amount,
    required this.paidAmount,
    required this.dueDate,
    required this.status,
  });

  double get pendingAmount => amount - paidAmount;
}

enum BookStatus { available, issued, overdue }

class LibraryBookModel {
  final String id;
  final String title;
  final String author;
  final String isbn;
  final String? issuedToStudent;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final BookStatus status;

  const LibraryBookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    this.issuedToStudent,
    this.issueDate,
    this.dueDate,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'isbn': isbn,
      'issued_to_student': issuedToStudent,
      'issue_date': issueDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'status': status.name,
    };
  }

  factory LibraryBookModel.fromJson(Map<String, dynamic> json) {
    BookStatus parsedStatus = BookStatus.available;
    final s = json['status']?.toString().toLowerCase();
    if (s == 'issued') parsedStatus = BookStatus.issued;
    if (s == 'overdue') parsedStatus = BookStatus.overdue;

    return LibraryBookModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      isbn: json['isbn']?.toString() ?? '',
      issuedToStudent: json['issued_to_student']?.toString() ?? json['issuedToStudent']?.toString(),
      issueDate: DateTime.tryParse(json['issue_date']?.toString() ?? json['issueDate']?.toString() ?? ''),
      dueDate: DateTime.tryParse(json['due_date']?.toString() ?? json['dueDate']?.toString() ?? ''),
      status: parsedStatus,
    );
  }
}

class TransportRouteModel {
  final String id;
  final String routeName;
  final String busNumber;
  final String driverName;
  final String driverPhone;
  final int studentCount;
  final List<String> stops;

  const TransportRouteModel({
    required this.id,
    required this.routeName,
    required this.busNumber,
    required this.driverName,
    required this.driverPhone,
    required this.studentCount,
    required this.stops,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'route_name': routeName,
      'bus_number': busNumber,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'student_count': studentCount,
      'stops': stops,
    };
  }

  factory TransportRouteModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedStops = [];
    if (json['stops'] is List) {
      parsedStops = (json['stops'] as List).map((e) => e.toString()).toList();
    }
    return TransportRouteModel(
      id: json['id']?.toString() ?? '',
      routeName: json['route_name']?.toString() ?? json['routeName']?.toString() ?? '',
      busNumber: json['bus_number']?.toString() ?? json['busNumber']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? json['driverName']?.toString() ?? '',
      driverPhone: json['driver_phone']?.toString() ?? json['driverPhone']?.toString() ?? '',
      studentCount: (json['student_count'] as num?)?.toInt() ?? (json['studentCount'] as num?)?.toInt() ?? 0,
      stops: parsedStops,
    );
  }
}

class NotificationModel {
  final String id;
  final String schoolId;
  final String? recipientId;
  final String? recipientRole;
  final String title;
  final String message;
  final DateTime timestamp;
  final String category;
  final bool isUnread;
  final String? relatedRecordId;
  final String? relatedRecordType; // 'leave', 'notice', 'meeting'

  const NotificationModel({
    required this.id,
    this.schoolId = '',
    this.recipientId,
    this.recipientRole,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isUnread = true,
    this.relatedRecordId,
    this.relatedRecordType,
  });

  NotificationModel copyWith({
    String? id,
    String? schoolId,
    String? recipientId,
    String? recipientRole,
    String? title,
    String? message,
    DateTime? timestamp,
    String? category,
    bool? isUnread,
    String? relatedRecordId,
    String? relatedRecordType,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      recipientId: recipientId ?? this.recipientId,
      recipientRole: recipientRole ?? this.recipientRole,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isUnread: isUnread ?? this.isUnread,
      relatedRecordId: relatedRecordId ?? this.relatedRecordId,
      relatedRecordType: relatedRecordType ?? this.relatedRecordType,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      recipientId: json['user_id']?.toString() ?? json['recipient_id']?.toString(),
      recipientRole: json['recipient_role']?.toString(),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['timestamp'] != null ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now() : DateTime.now()),
      category: json['category']?.toString() ?? 'General',
      isUnread: json['is_unread'] != false,
      relatedRecordId: json['related_record_id']?.toString(),
      relatedRecordType: json['related_record_type']?.toString(),
    );
  }

  Map<String, dynamic> toJson({String? schoolId}) {
    return {
      'id': id,
      if (schoolId != null || this.schoolId.isNotEmpty) 'school_id': schoolId ?? this.schoolId,
      if (recipientId != null) 'user_id': recipientId,
      if (recipientRole != null) 'recipient_role': recipientRole,
      'title': title,
      'message': message,
      'category': category,
      'is_unread': isUnread,
      if (relatedRecordId != null) 'related_record_id': relatedRecordId,
      if (relatedRecordType != null) 'related_record_type': relatedRecordType,
      'created_at': timestamp.toIso8601String(),
    };
  }
}
