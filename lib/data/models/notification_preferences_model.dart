class NotificationPreferencesModel {
  final String schoolId;
  final String? userId;
  final bool timetableAlerts;
  final bool attendanceAlerts;
  final bool feeAlerts;
  final bool pushEnabled;
  final DateTime updatedAt;

  const NotificationPreferencesModel({
    required this.schoolId,
    this.userId,
    this.timetableAlerts = true,
    this.attendanceAlerts = true,
    this.feeAlerts = true,
    this.pushEnabled = true,
    required this.updatedAt,
  });

  NotificationPreferencesModel copyWith({
    String? schoolId,
    String? userId,
    bool? timetableAlerts,
    bool? attendanceAlerts,
    bool? feeAlerts,
    bool? pushEnabled,
    DateTime? updatedAt,
  }) {
    return NotificationPreferencesModel(
      schoolId: schoolId ?? this.schoolId,
      userId: userId ?? this.userId,
      timetableAlerts: timetableAlerts ?? this.timetableAlerts,
      attendanceAlerts: attendanceAlerts ?? this.attendanceAlerts,
      feeAlerts: feeAlerts ?? this.feeAlerts,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory NotificationPreferencesModel.defaults(String schoolId, {String? userId}) {
    return NotificationPreferencesModel(
      schoolId: schoolId,
      userId: userId,
      timetableAlerts: true,
      attendanceAlerts: true,
      feeAlerts: true,
      pushEnabled: true,
      updatedAt: DateTime.now(),
    );
  }

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      schoolId: json['school_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      timetableAlerts: json['timetable_alerts'] != false,
      attendanceAlerts: json['attendance_alerts'] != false,
      feeAlerts: json['fee_alerts'] != false,
      pushEnabled: json['push_enabled'] != false,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'school_id': schoolId,
      if (userId != null) 'user_id': userId,
      'timetable_alerts': timetableAlerts,
      'attendance_alerts': attendanceAlerts,
      'fee_alerts': feeAlerts,
      'push_enabled': pushEnabled,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
