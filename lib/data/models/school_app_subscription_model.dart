/// Model representing a subscription in `public.school_app_subscriptions`.
class SchoolAppSubscriptionModel {
  final String id;
  final String schoolAppId;
  final String planName;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'ACTIVE', 'EXPIRED', 'SUSPENDED', 'INACTIVE'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SchoolAppSubscriptionModel({
    required this.id,
    required this.schoolAppId,
    this.planName = 'Annual School License',
    required this.startDate,
    required this.endDate,
    this.status = 'ACTIVE',
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  SchoolAppSubscriptionModel copyWith({
    String? id,
    String? schoolAppId,
    String? planName,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SchoolAppSubscriptionModel(
      id: id ?? this.id,
      schoolAppId: schoolAppId ?? this.schoolAppId,
      planName: planName ?? this.planName,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isStatusActive => status.toUpperCase().trim() == 'ACTIVE';
  bool get isStatusSuspended => status.toUpperCase().trim() == 'SUSPENDED';
  bool get isStatusInactive => status.toUpperCase().trim() == 'INACTIVE';
  bool get isStatusExpired => status.toUpperCase().trim() == 'EXPIRED';

  bool isDateActive([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  bool isDateExpired([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return today.isAfter(end);
  }

  bool isDateNotStarted([DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return today.isBefore(start);
  }

  factory SchoolAppSubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SchoolAppSubscriptionModel(
      id: json['id']?.toString() ?? '',
      schoolAppId: json['school_app_id']?.toString() ?? '',
      planName: json['plan_name']?.toString() ?? 'Annual School License',
      startDate: DateTime.tryParse(json['start_date']?.toString() ?? '') ?? DateTime.now(),
      endDate: DateTime.tryParse(json['end_date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 365)),
      status: json['status']?.toString() ?? 'ACTIVE',
      notes: json['notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_app_id': schoolAppId,
      'plan_name': planName,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
