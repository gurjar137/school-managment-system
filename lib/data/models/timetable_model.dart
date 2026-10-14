import 'package:flutter/foundation.dart';

enum TimetableStatus {
  draft,
  published,
  cancelled;

  String get displayName {
    switch (this) {
      case TimetableStatus.draft:
        return 'DRAFT';
      case TimetableStatus.published:
        return 'PUBLISHED';
      case TimetableStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static TimetableStatus fromString(String? value) {
    if (value == null) return TimetableStatus.draft;
    final normalized = value.toUpperCase().trim();
    switch (normalized) {
      case 'PUBLISHED':
        return TimetableStatus.published;
      case 'CANCELLED':
        return TimetableStatus.cancelled;
      case 'DRAFT':
      default:
        return TimetableStatus.draft;
    }
  }
}

enum TimetableConflictType {
  classOverlap,
  teacherOverlap,
  roomOverlap,
  invalidTimeRange,
  schoolMismatch;

  String get label {
    switch (this) {
      case TimetableConflictType.classOverlap:
        return 'Class Overlap Conflict';
      case TimetableConflictType.teacherOverlap:
        return 'Teacher Overlap Conflict';
      case TimetableConflictType.roomOverlap:
        return 'Room Overlap Conflict';
      case TimetableConflictType.invalidTimeRange:
        return 'Invalid Time Range';
      case TimetableConflictType.schoolMismatch:
        return 'Tenant Mismatch';
    }
  }
}

class TimetableConflict {
  final TimetableConflictType type;
  final String message;
  final TimetableEntryModel? conflictingEntry;
  final TimetableEntryModel attemptedEntry;

  const TimetableConflict({
    required this.type,
    required this.message,
    required this.attemptedEntry,
    this.conflictingEntry,
  });

  @override
  String toString() => '${type.label}: $message';
}

@immutable
class TimetableEntryModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String? classId;
  final String? sectionId;
  final String? classDisplayCode;
  final String? sectionDisplayCode;
  final String? className;
  final String? sectionName;
  final int dayOfWeek; // 1 = Monday, ..., 6 = Saturday, 7 = Sunday
  final int? periodNumber;
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String? subjectId;
  final String subjectName;
  final String? teacherProfileId;
  final String? teacherName;
  final String? room;
  final String? notes;
  final TimetableStatus status;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TimetableEntryModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    this.classId,
    this.sectionId,
    this.classDisplayCode,
    this.sectionDisplayCode,
    this.className,
    this.sectionName,
    required this.dayOfWeek,
    this.periodNumber,
    required this.startTime,
    required this.endTime,
    this.subjectId,
    required this.subjectName,
    this.teacherProfileId,
    this.teacherName,
    this.room,
    this.notes,
    this.status = TimetableStatus.draft,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  static bool isValidUuid(String? val) {
    if (val == null || val.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(val.trim());
  }

  bool get hasCanonicalClassUuid => isValidUuid(classId);
  bool get hasCanonicalSectionUuid => isValidUuid(sectionId);
  bool get hasCanonicalTeacherUuid => isValidUuid(teacherProfileId);
  bool get hasCanonicalAcademicYearUuid => isValidUuid(academicYearId);

  bool get isDraft => status == TimetableStatus.draft;
  bool get isPublished => status == TimetableStatus.published;
  bool get isCancelled => status == TimetableStatus.cancelled;

  String get dayName {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  String get shortDayName {
    switch (dayOfWeek) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return 'Day $dayOfWeek';
    }
  }

  String get timeRangeFormatted => '$startTime - $endTime';

  int get startMinutes => _parseMinutes(startTime);
  int get endMinutes => _parseMinutes(endTime);

  int get durationMinutes {
    final diff = endMinutes - startMinutes;
    return diff > 0 ? diff : 0;
  }

  static int _parseMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        return hours * 60 + minutes;
      }
    } catch (_) {}
    return 0;
  }

  /// Returns true if this period overlaps with [other] period on the same day.
  /// Overlap condition: start < other.end && other.start < end
  bool overlapsWith(TimetableEntryModel other) {
    if (dayOfWeek != other.dayOfWeek) return false;
    final aStart = startMinutes;
    final aEnd = endMinutes;
    final bStart = other.startMinutes;
    final bEnd = other.endMinutes;
    return aStart < bEnd && bStart < aEnd;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'class_id': classId,
      'section_id': sectionId,
      'class_display_code': classDisplayCode,
      'section_display_code': sectionDisplayCode,
      'class_name': className,
      'section_name': sectionName,
      'day_of_week': dayOfWeek,
      'period_number': periodNumber,
      'start_time': startTime,
      'end_time': endTime,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'teacher_profile_id': teacherProfileId,
      'teacher_name': teacherName,
      'room': room,
      'notes': notes,
      'status': status.displayName,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseMap({bool requireValidUuid = false}) {
    final map = <String, dynamic>{
      'school_id': schoolId,
      'day_of_week': dayOfWeek,
      'start_time': startTime.length == 5 ? '$startTime:00' : startTime,
      'end_time': endTime.length == 5 ? '$endTime:00' : endTime,
      'subject_name': subjectName,
      'status': status.displayName,
    };

    if (id.isNotEmpty && (!requireValidUuid || isValidUuid(id))) {
      map['id'] = id;
    }
    if (academicYearId.isNotEmpty && (!requireValidUuid || isValidUuid(academicYearId))) {
      map['academic_year_id'] = academicYearId;
    }
    if (classId != null && classId!.isNotEmpty && (!requireValidUuid || isValidUuid(classId))) {
      map['class_id'] = classId;
    }
    if (sectionId != null && sectionId!.isNotEmpty && (!requireValidUuid || isValidUuid(sectionId))) {
      map['section_id'] = sectionId;
    }
    if (periodNumber != null) {
      map['period_number'] = periodNumber;
    }
    if (subjectId != null && subjectId!.isNotEmpty && (!requireValidUuid || isValidUuid(subjectId))) {
      map['subject_id'] = subjectId;
    }
    if (teacherProfileId != null && teacherProfileId!.isNotEmpty && (!requireValidUuid || isValidUuid(teacherProfileId))) {
      map['teacher_profile_id'] = teacherProfileId;
    }
    if (teacherName != null && teacherName!.isNotEmpty) {
      map['teacher_name'] = teacherName;
    }
    if (room != null && room!.isNotEmpty) {
      map['room'] = room;
    }
    if (notes != null && notes!.isNotEmpty) {
      map['notes'] = notes;
    }
    if (createdBy != null && createdBy!.isNotEmpty && (!requireValidUuid || isValidUuid(createdBy))) {
      map['created_by'] = createdBy;
    }
    return map;
  }

  factory TimetableEntryModel.fromJson(Map<String, dynamic> json) {
    String formatTime(dynamic val) {
      if (val == null) return '00:00';
      final str = val.toString().trim();
      if (str.length >= 5) {
        return str.substring(0, 5); // Take "HH:mm" from "HH:mm:ss"
      }
      return str;
    }

    return TimetableEntryModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      academicYearId: json['academic_year_id']?.toString() ?? '',
      classId: json['class_id']?.toString(),
      sectionId: json['section_id']?.toString(),
      classDisplayCode: json['class_display_code']?.toString(),
      sectionDisplayCode: json['section_display_code']?.toString(),
      className: json['class_name']?.toString() ??
          (json['classes'] is Map ? json['classes']['name']?.toString() : null),
      sectionName: json['section_name']?.toString() ??
          (json['sections'] is Map ? json['sections']['name']?.toString() : null),
      dayOfWeek: int.tryParse(json['day_of_week']?.toString() ?? '1') ?? 1,
      periodNumber: json['period_number'] != null
          ? int.tryParse(json['period_number'].toString())
          : null,
      startTime: formatTime(json['start_time']),
      endTime: formatTime(json['end_time']),
      subjectId: json['subject_id']?.toString(),
      subjectName: json['subject_name']?.toString() ??
          (json['subjects'] is Map ? json['subjects']['name']?.toString() : null) ??
          'General Period',
      teacherProfileId: json['teacher_profile_id']?.toString(),
      teacherName: json['teacher_name']?.toString() ??
          (json['profiles'] is Map ? json['profiles']['name']?.toString() ?? json['profiles']['full_name']?.toString() : null),
      room: json['room']?.toString(),
      notes: json['notes']?.toString(),
      status: TimetableStatus.fromString(json['status']?.toString()),
      createdBy: json['created_by']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }

  TimetableEntryModel copyWith({
    String? id,
    String? schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? classDisplayCode,
    String? sectionDisplayCode,
    String? className,
    String? sectionName,
    int? dayOfWeek,
    int? periodNumber,
    String? startTime,
    String? endTime,
    String? subjectId,
    String? subjectName,
    String? teacherProfileId,
    String? teacherName,
    String? room,
    String? notes,
    TimetableStatus? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimetableEntryModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      academicYearId: academicYearId ?? this.academicYearId,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      classDisplayCode: classDisplayCode ?? this.classDisplayCode,
      sectionDisplayCode: sectionDisplayCode ?? this.sectionDisplayCode,
      className: className ?? this.className,
      sectionName: sectionName ?? this.sectionName,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      periodNumber: periodNumber ?? this.periodNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      teacherProfileId: teacherProfileId ?? this.teacherProfileId,
      teacherName: teacherName ?? this.teacherName,
      room: room ?? this.room,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimetableEntryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
