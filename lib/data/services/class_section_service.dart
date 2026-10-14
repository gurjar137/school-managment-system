import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_section_models.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';
import 'tenant_resolver.dart';

class ClassSectionService {
  final SupabaseClient? _clientOverride;

  ClassSectionService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  /// Authoritatively resolves the active school ID for current user session.
  Future<String> fetchActiveSchoolId({String? fallback}) async {
    return TenantResolver.resolveActiveSchoolId(
      client: _client,
      requestedSchoolId: fallback,
    );
  }

  // --- ACADEMIC YEARS ---
  Future<List<AcademicYearModel>> fetchAcademicYears(String schoolId) async {
    final cleanSchoolId = schoolId.trim();
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!.from('academic_years').select();
        if (cleanSchoolId.isNotEmpty) {
          query = query.eq('school_id', cleanSchoolId);
        }
        final data = await query.order('start_date', ascending: false);
        if (data.isNotEmpty) {
          return data.map((y) => _mapAcademicYear(y)).toList();
        }
        return [];
      } catch (e) {
        debugPrint('[ClassSectionService fetchAcademicYears Warning]: $e');
        return [];
      }
    }

    return [];
  }

  Future<AcademicYearModel> createAcademicYear({
    required String schoolId,
    required String name,
    bool isCurrent = false,
  }) async {
    final trimmedName = name.trim();
    if (_client != null && SupabaseConfig.isConfigured) {
      final res = await _client!.from('academic_years').insert({
        'school_id': schoolId,
        'name': trimmedName,
        'status': 'ACTIVE',
      }).select().single();
      return _mapAcademicYear(res);
    }
    throw Exception('Database not connected. Cannot create academic year.');
  }

  static bool isUuid(String? val) {
    if (val == null || val.trim().isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(val.trim());
  }

  // --- CLASSES ---
  Future<List<SchoolClassModel>> fetchClasses(String schoolId, String academicYearId) async {
    final cleanSchoolId = schoolId.trim();
    final cleanAyId = academicYearId.trim();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('classes')
            .select()
            .eq('school_id', cleanSchoolId);

        if (cleanAyId.isNotEmpty && isUuid(cleanAyId)) {
          query = query.eq('academic_year_id', cleanAyId);
        }

        final data = await query.order('display_order', ascending: true);

        if (data.isNotEmpty) {
          final rawList = List<Map<String, dynamic>>.from(data);
          final classes = <SchoolClassModel>[];
          for (final c in rawList) {
            final classId = c['id'].toString();
            int secCount = 0;
            try {
              final secRes = await _client!.from('sections').select('id').eq('class_id', classId);
              secCount = secRes.length;
            } catch (_) {}
            classes.add(_mapClass(c, sectionsCount: secCount));
          }
          return classes;
        }

        // Configured Supabase production mode: return real persisted classes (empty if none exist)
        return [];
      } catch (e) {
        debugPrint('[ClassSectionService fetchClasses Warning]: $e');
        return [];
      }
    }

    // Pure offline / unconfigured mock mode ONLY
    return List.generate(12, (i) {
      final num = i + 1;
      return SchoolClassModel(
        id: 'mock_cls_$num',
        code: 'cls_$num',
        schoolId: cleanSchoolId,
        academicYearId: cleanAyId,
        name: 'Class $num',
        displayOrder: num,
        sectionsCount: 3,
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 1),
      );
    });
  }

  /// Resolves an identifier (UUID, display code 'cls_1', or name 'Class 1', 'class_10')
  /// to the canonical SchoolClassModel with a real database UUID.
  Future<SchoolClassModel?> resolveClass({
    required String schoolId,
    required String classIdentifier,
    String? academicYearId,
  }) async {
    final cleanId = classIdentifier.trim();
    if (cleanId.isEmpty) return null;

    final classes = await fetchClasses(schoolId, academicYearId ?? '');

    // 1. Direct match by UUID
    if (isUuid(cleanId)) {
      final match = classes.where((c) => c.id.toLowerCase() == cleanId.toLowerCase()).firstOrNull;
      if (match != null) return match;
    }

    // 2. Match by display code (e.g. 'cls_1', 'cls_10')
    final matchByCode = classes.where((c) => c.displayCode.toLowerCase() == cleanId.toLowerCase()).firstOrNull;
    if (matchByCode != null) return matchByCode;

    // 3. Match by numeric display order (handles 'class_10', 'Grade 10', '10', 'cls-10')
    final cleanDigits = cleanId.replaceAll(RegExp(r'\D'), '');
    final numOrder = int.tryParse(cleanDigits);
    if (numOrder != null) {
      final matchByOrder = classes.where((c) => c.displayOrder == numOrder).firstOrNull;
      if (matchByOrder != null) return matchByOrder;
    }

    // 4. Match by normalized name
    final cleanName = cleanId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final c in classes) {
      if (c.name.toLowerCase() == cleanId.toLowerCase()) return c;
      final cClean = c.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cClean == cleanName) return c;
    }

    return null;
  }

  /// Resolves a section identifier (UUID, display code 'sec_cls_1_A', or name 'A', 'sec_a')
  /// to the canonical SectionModel with a real database UUID.
  Future<SectionModel?> resolveSection({
    required String schoolId,
    required String classId,
    required String sectionIdentifier,
  }) async {
    final cleanId = sectionIdentifier.trim();
    if (cleanId.isEmpty) return null;

    final sections = await fetchSections(schoolId, classId);

    // 1. Direct match by UUID
    if (isUuid(cleanId)) {
      final match = sections.where((s) => s.id.toLowerCase() == cleanId.toLowerCase()).firstOrNull;
      if (match != null) return match;
    }

    // 2. Match by display code (e.g. 'sec_cls_1_A')
    final matchByCode = sections.where((s) => s.displayCode.toLowerCase() == cleanId.toLowerCase()).firstOrNull;
    if (matchByCode != null) return matchByCode;

    // 3. Match by letter (e.g. 'sec_a', 'Section A', 'A')
    final secLetters = cleanId.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final lastLetter = secLetters.isNotEmpty ? secLetters.substring(secLetters.length - 1) : '';
    if (lastLetter.isNotEmpty) {
      final matchByLetter = sections.where((s) => s.name.toUpperCase().contains(lastLetter)).firstOrNull;
      if (matchByLetter != null) return matchByLetter;
    }

    // 4. Match by normalized name
    for (final s in sections) {
      if (s.name.toLowerCase() == cleanId.toLowerCase()) return s;
      final sClean = s.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final cleanName = cleanId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (sClean == cleanName) return s;
    }

    return null;
  }

  Future<SchoolClassModel> createClass({
    required String schoolId,
    required String academicYearId,
    required String name,
    int displayOrder = 1,
  }) async {
    final trimmedName = name.trim();
    if (schoolId.trim().isEmpty) {
      throw const TenantResolutionException('Cannot create class without a valid school ID.');
    }
    if (_client != null && SupabaseConfig.isConfigured) {
      final res = await _client!.from('classes').insert({
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'name': trimmedName,
        'display_order': displayOrder,
        'status': 'ACTIVE',
      }).select().single();
      return _mapClass(res);
    }
    throw Exception('Database not connected. Cannot create class.');
  }

  Future<void> deactivateClass(String classId, {String? schoolId}) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      var query = _client!.from('classes').update({'status': 'INACTIVE'}).eq('id', classId);
      if (schoolId != null && schoolId.isNotEmpty) {
        query = query.eq('school_id', schoolId);
      }
      await query;
    }
  }

  Future<void> deleteClass(String classId, {String? schoolId}) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var secDelete = _client!.from('sections').delete().eq('class_id', classId);
        if (schoolId != null && schoolId.isNotEmpty) {
          secDelete = secDelete.eq('school_id', schoolId);
        }
        await secDelete;
      } catch (_) {}
      var classDelete = _client!.from('classes').delete().eq('id', classId);
      if (schoolId != null && schoolId.isNotEmpty) {
        classDelete = classDelete.eq('school_id', schoolId);
      }
      await classDelete;
    }
  }

  // --- SECTIONS ---
  Future<List<SectionModel>> fetchSections(String schoolId, String classId) async {
    final cleanSchoolId = schoolId.trim();
    final cleanClassId = classId.trim();

    if (_client != null && SupabaseConfig.isConfigured) {
      if (isUuid(cleanClassId)) {
        try {
          var query = _client!
              .from('sections')
              .select()
              .eq('class_id', cleanClassId);
          if (cleanSchoolId.isNotEmpty) {
            query = query.eq('school_id', cleanSchoolId);
          }
          final data = await query.order('name', ascending: true);

          if (data.isNotEmpty) {
            return data.map((s) {
              final map = Map<String, dynamic>.from(s);
              if (map['school_id'] == null || map['school_id'].toString().isEmpty) {
                map['school_id'] = cleanSchoolId;
              }
              return _mapSection(map);
            }).toList();
          }
          // Configured Supabase production mode: return real persisted sections (empty if none exist)
          return [];
        } catch (e) {
          debugPrint('[ClassSectionService fetchSections Warning]: $e');
          return [];
        }
      }
      return [];
    }

    // Pure offline / unconfigured mock mode ONLY
    final classNum = int.tryParse(cleanClassId.replaceAll(RegExp(r'\D'), '')) ?? 1;
    return ['A', 'B', 'C'].map((sec) {
      return SectionModel(
        id: 'mock_sec_${classNum}_$sec',
        code: 'sec_cls_${classNum}_$sec',
        schoolId: cleanSchoolId,
        academicYearId: '',
        classId: cleanClassId,
        name: 'Section $sec',
        displayOrder: sec.codeUnitAt(0),
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 1),
      );
    }).toList();
  }

  Future<SectionModel> createSection({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String name,
    int? capacity,
  }) async {
    final trimmedName = name.trim();
    if (schoolId.trim().isEmpty) {
      throw const TenantResolutionException('Cannot create section without a valid school ID.');
    }
    if (_client != null && SupabaseConfig.isConfigured) {
      final res = await _client!.from('sections').insert({
        'school_id': schoolId,
        'academic_year_id': academicYearId,
        'class_id': classId,
        'name': trimmedName,
        'capacity': capacity,
        'display_order': 1,
        'status': 'ACTIVE',
      }).select().single();
      return _mapSection(res);
    }
    throw Exception('Database not connected. Cannot create section.');
  }

  Future<void> deleteSection(String sectionId, {String? schoolId}) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      var query = _client!.from('sections').delete().eq('id', sectionId);
      if (schoolId != null && schoolId.isNotEmpty) {
        query = query.eq('school_id', schoolId);
      }
      await query;
    }
  }

  // --- MAPPERS ---
  AcademicYearModel _mapAcademicYear(Map<String, dynamic> data) {
    return AcademicYearModel(
      id: data['id']?.toString() ?? '',
      schoolId: data['school_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      isCurrent: data['is_current'] == true,
      status: (data['status']?.toString().toUpperCase() == 'INACTIVE') ? AccountStatus.inactive : AccountStatus.active,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  SchoolClassModel _mapClass(Map<String, dynamic> data, {int sectionsCount = 0}) {
    final order = data['display_order'] is int
        ? data['display_order'] as int
        : (int.tryParse(data['display_order']?.toString() ?? '') ?? 1);
    final rawCode = data['code']?.toString();
    final code = (rawCode != null && rawCode.isNotEmpty) ? rawCode : 'cls_$order';

    return SchoolClassModel(
      id: data['id']?.toString() ?? '',
      code: code,
      schoolId: data['school_id']?.toString() ?? '',
      academicYearId: data['academic_year_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      displayOrder: order,
      sectionsCount: sectionsCount > 0 ? sectionsCount : (data['sections_count'] ?? 0),
      status: (data['status']?.toString().toUpperCase() == 'INACTIVE') ? AccountStatus.inactive : AccountStatus.active,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  SectionModel _mapSection(Map<String, dynamic> data) {
    final rawCode = data['code']?.toString();
    final code = (rawCode != null && rawCode.isNotEmpty) ? rawCode : 'sec_${data['class_id']}_${data['name']}';

    return SectionModel(
      id: data['id']?.toString() ?? '',
      code: code,
      schoolId: data['school_id']?.toString() ?? '',
      academicYearId: data['academic_year_id']?.toString() ?? '',
      classId: data['class_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      displayOrder: data['display_order'] is int
          ? data['display_order'] as int
          : (int.tryParse(data['display_order']?.toString() ?? '') ?? 1),
      capacity: data['capacity'] is int ? data['capacity'] : int.tryParse(data['capacity']?.toString() ?? ''),
      status: (data['status']?.toString().toUpperCase() == 'INACTIVE') ? AccountStatus.inactive : AccountStatus.active,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
