import 'user_model.dart';

class AcademicYearModel {
  final String id; // UUID
  final String schoolId; // UUID
  final String name; // e.g. "2026-2027"
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final AccountStatus status;
  final DateTime createdAt;

  const AcademicYearModel({
    required this.id,
    required this.schoolId,
    required this.name,
    this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.status = AccountStatus.active,
    required this.createdAt,
  });

  bool get isActive => status == AccountStatus.active;

  String get dateRangeFormatted {
    if (startDate == null && endDate == null) return 'Dates Not Configured';
    final s = startDate != null ? _formatDate(startDate!) : 'Open';
    final e = endDate != null ? _formatDate(endDate!) : 'Open';
    return '$s → $e';
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year.toString();
    return '$day $month $year';
  }

  AcademicYearModel copyWith({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
    AccountStatus? status,
  }) {
    return AcademicYearModel(
      id: id,
      schoolId: schoolId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isCurrent: isCurrent ?? this.isCurrent,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  factory AcademicYearModel.fromJson(Map<String, dynamic> json) {
    final statusRaw = (json['status']?.toString() ?? 'ACTIVE').toUpperCase();
    final status = (statusRaw == 'INACTIVE') ? AccountStatus.inactive : AccountStatus.active;

    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      return DateTime.tryParse(val.toString());
    }

    return AcademicYearModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      isCurrent: json['is_current'] == true,
      status: status,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    String? formatDateStr(DateTime? dt) {
      if (dt == null) return null;
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    return {
      'id': id,
      'school_id': schoolId,
      'name': name,
      'start_date': formatDateStr(startDate),
      'end_date': formatDateStr(endDate),
      'is_current': isCurrent,
      'status': status == AccountStatus.inactive ? 'INACTIVE' : 'ACTIVE',
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Helper & Resolution Engine for Academic Year Selection and Billing Integration.
class AcademicYearOption {
  final String id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final AccountStatus status;

  const AcademicYearOption({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.status = AccountStatus.active,
  });

  factory AcademicYearOption.fromModel(AcademicYearModel model, {bool isCurrent = false}) {
    return AcademicYearOption(
      id: model.id,
      name: model.name,
      startDate: model.startDate,
      endDate: model.endDate,
      isCurrent: isCurrent || model.isCurrent,
      status: model.status,
    );
  }

  /// Authoritative Current Academic Year Resolution:
  /// Evaluates: school_id, status (ACTIVE only), start_date, end_date, and current date.
  /// Preserves billing integration logic without mutating database flags.
  static AcademicYearModel? resolveCurrent(List<AcademicYearModel> years, {DateTime? referenceDate}) {
    if (years.isEmpty) return null;
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Strict filter: only ACTIVE academic years can be current
    final activeYears = years.where((y) => y.status == AccountStatus.active).toList();
    if (activeYears.isEmpty) return null;

    // 2. Primary check: if explicit is_current flag is set on an active year
    final markedCurrent = activeYears.where((y) => y.isCurrent).toList();
    if (markedCurrent.isNotEmpty) {
      return markedCurrent.first;
    }

    // 3. Secondary check: today falls within [startDate, endDate]
    for (final y in activeYears) {
      if (y.startDate != null && y.endDate != null) {
        final start = DateTime(y.startDate!.year, y.startDate!.month, y.startDate!.day);
        final end = DateTime(y.endDate!.year, y.endDate!.month, y.endDate!.day);
        if (!today.isBefore(start) && !today.isAfter(end)) {
          return y;
        }
      }
    }

    // 4. Fallback: most recent active year by startDate or name
    final sorted = List<AcademicYearModel>.from(activeYears);
    sorted.sort((a, b) {
      if (a.startDate != null && b.startDate != null) {
        return b.startDate!.compareTo(a.startDate!);
      }
      return b.name.compareTo(a.name);
    });
    return sorted.first;
  }
}

class SchoolClassModel {
  final String id; // UUID
  final String? code; // Display code, e.g. "cls_1", "CLS-01"
  final String schoolId; // UUID
  final String academicYearId; // UUID
  final String name; // e.g. "Class 8", "Grade 10"
  final int displayOrder;
  final int sectionsCount;
  final AccountStatus status;
  final DateTime createdAt;

  const SchoolClassModel({
    required this.id,
    this.code,
    required this.schoolId,
    required this.academicYearId,
    required this.name,
    this.displayOrder = 1,
    this.sectionsCount = 0,
    this.status = AccountStatus.active,
    required this.createdAt,
  });

  bool get hasCanonicalUuid => RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
  String get displayCode => code ?? (displayOrder > 0 ? 'cls_$displayOrder' : id);

  SchoolClassModel copyWith({
    String? id,
    String? code,
    String? schoolId,
    String? academicYearId,
    String? name,
    int? displayOrder,
    int? sectionsCount,
    AccountStatus? status,
  }) {
    return SchoolClassModel(
      id: id ?? this.id,
      code: code ?? this.code,
      schoolId: schoolId ?? this.schoolId,
      academicYearId: academicYearId ?? this.academicYearId,
      name: name ?? this.name,
      displayOrder: displayOrder ?? this.displayOrder,
      sectionsCount: sectionsCount ?? this.sectionsCount,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class SectionModel {
  final String id; // UUID
  final String? code; // Display code, e.g. "sec_cls_1_A"
  final String schoolId; // UUID
  final String academicYearId; // UUID
  final String classId; // UUID
  final String name; // e.g. "A", "B", "Science"
  final int displayOrder;
  final int? capacity; // e.g. 40
  final AccountStatus status;
  final DateTime createdAt;

  const SectionModel({
    required this.id,
    this.code,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    required this.name,
    this.displayOrder = 1,
    this.capacity,
    this.status = AccountStatus.active,
    required this.createdAt,
  });

  bool get hasCanonicalUuid => RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
  String get displayCode => code ?? 'sec_${classId}_$name';
  String get displayName => 'Section $name';

  SectionModel copyWith({
    String? id,
    String? code,
    String? schoolId,
    String? academicYearId,
    String? classId,
    String? name,
    int? displayOrder,
    int? capacity,
    AccountStatus? status,
  }) {
    return SectionModel(
      id: id ?? this.id,
      code: code ?? this.code,
      schoolId: schoolId ?? this.schoolId,
      academicYearId: academicYearId ?? this.academicYearId,
      classId: classId ?? this.classId,
      name: name ?? this.name,
      displayOrder: displayOrder ?? this.displayOrder,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
