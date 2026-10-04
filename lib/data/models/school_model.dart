import 'user_model.dart';

class SchoolModel {
  final String id; // UUID primary key
  final String schoolCode; // Human-friendly code, e.g. SCH001, SCH002
  final String name;
  final String? logoUrl;
  final String? appName;
  final String? primaryColor;
  final String? secondaryColor;
  final AccountStatus status;
  final DateTime createdAt;

  const SchoolModel({
    required this.id,
    required this.schoolCode,
    required this.name,
    this.logoUrl,
    this.appName,
    this.primaryColor,
    this.secondaryColor,
    this.status = AccountStatus.active,
    required this.createdAt,
  });

  SchoolModel copyWith({
    String? name,
    String? logoUrl,
    String? appName,
    String? primaryColor,
    String? secondaryColor,
    AccountStatus? status,
  }) {
    return SchoolModel(
      id: id,
      schoolCode: schoolCode,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      appName: appName ?? this.appName,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
