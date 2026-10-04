/// Model representing a row in `public.school_management_apps`.
/// Every school has exactly one dedicated School Management App record.
class SchoolManagementAppModel {
  final String id;
  final String schoolId;
  final String appName;
  final String? appIdentifier;
  final String? packageName;
  final String currentVersion;
  final String? playStoreUrl;
  final String status; // 'ACTIVE' or 'INACTIVE'
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const SchoolManagementAppModel({
    required this.id,
    required this.schoolId,
    required this.appName,
    this.appIdentifier,
    this.packageName,
    this.currentVersion = '1.0.0',
    this.playStoreUrl,
    this.status = 'ACTIVE',
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status.toUpperCase().trim() == 'ACTIVE';

  factory SchoolManagementAppModel.fromJson(Map<String, dynamic> json) {
    return SchoolManagementAppModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      appName: json['app_name']?.toString() ?? 'School Management App',
      appIdentifier: json['app_identifier']?.toString(),
      packageName: json['package_name']?.toString(),
      currentVersion: json['current_version']?.toString() ?? '1.0.0',
      playStoreUrl: json['play_store_url']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      notes: json['notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'app_name': appName,
      'app_identifier': appIdentifier,
      'package_name': packageName,
      'current_version': currentVersion,
      'play_store_url': playStoreUrl,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
