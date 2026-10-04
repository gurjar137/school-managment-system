import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_section_models.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';

class ClassSectionService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  Future<String> fetchActiveSchoolId({String? fallback}) async {
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    if (_client != null && SupabaseConfig.isConfigured) {
      final user = _client!.auth.currentUser;
      if (user != null) {
        try {
          final prof = await _client!.from('profiles').select('school_id').eq('auth_user_id', user.id).maybeSingle();
          if (prof != null && prof['school_id'] != null && prof['school_id'].toString().isNotEmpty) {
            return prof['school_id'].toString();
          }
          final metaSchoolId = user.userMetadata?['school_id'];
          if (metaSchoolId != null && metaSchoolId is String && metaSchoolId.isNotEmpty) {
            return metaSchoolId;
          }
        } catch (e) {
          debugPrint('[ClassSectionService fetchActiveSchoolId Warning]: $e');
        }
      }
      throw const TenantResolutionException('Active school could not be resolved for current user. Please log in again.');
    }
    return 'offline_mock_school';
  }

  // --- ACADEMIC YEARS ---
  Future<List<AcademicYearModel>> fetchAcademicYears(String schoolId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!.from('academic_years').select();
        if (schoolId.isNotEmpty) {
          query = query.eq('school_id', schoolId);
        }
        final data = await query.order('start_date', ascending: false);
        if (data is List && data.isNotEmpty) {
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

  // --- CLASSES ---
  Future<List<SchoolClassModel>> fetchClasses(String schoolId, String academicYearId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('classes')
            .select()
            .eq('school_id', schoolId)
            .order('display_order', ascending: true);

        List<Map<String, dynamic>> rawList = [];
        if (data is List && data.isNotEmpty) {
          rawList = List<Map<String, dynamic>>.from(data);
        }

        // If no classes configured yet, discover distinct standards from students table
        if (rawList.isEmpty) {
          try {
            final studentsData = await _client!
                .from('students')
                .select('standard, section')
                .eq('school_id', schoolId);

            if (studentsData is List && studentsData.isNotEmpty) {
              final distinctStandards = <String>{};
              for (final s in studentsData) {
                final std = (s['standard'] ?? '').toString().trim();
                if (std.isNotEmpty) distinctStandards.add(std);
              }

              int order = 1;
              for (final std in distinctStandards) {
                try {
                  final className = std.toLowerCase().startsWith('class') || std.toLowerCase().startsWith('grade')
                      ? std
                      : 'Class $std';
                  final inserted = await _client!.from('classes').insert({
                    'school_id': schoolId,
                    'academic_year_id': academicYearId,
                    'name': className,
                    'display_order': int.tryParse(std.replaceAll(RegExp(r'\D'), '')) ?? order,
                    'status': 'ACTIVE',
                  }).select().single();
                  rawList.add(inserted);
                } catch (insertErr) {
                  debugPrint('[ClassSectionService auto-seed error]: $insertErr');
                }
                order++;
              }
            }
          } catch (e) {
            debugPrint('[ClassSectionService discover student classes error]: $e');
          }
        }

        if (rawList.isNotEmpty) {
          final classes = <SchoolClassModel>[];
          for (final c in rawList) {
            final classId = c['id'].toString();
            int secCount = 0;
            try {
              final secRes = await _client!.from('sections').select('id').eq('class_id', classId);
              if (secRes is List) secCount = secRes.length;
            } catch (_) {}
            classes.add(_mapClass(c, sectionsCount: secCount));
          }
          return classes;
        }
      } catch (e) {
        debugPrint('[ClassSectionService fetchClasses Warning]: $e');
      }
    }

    return List.generate(12, (i) {
      final num = i + 1;
      return SchoolClassModel(
        id: 'cls_$num',
        schoolId: schoolId,
        academicYearId: academicYearId,
        name: 'Class $num',
        displayOrder: num,
        sectionsCount: 3,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );
    });
  }

  Future<SchoolClassModel> createClass({
    required String schoolId,
    required String academicYearId,
    required String name,
    int displayOrder = 1,
  }) async {
    final trimmedName = name.trim();
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

  Future<void> deactivateClass(String classId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      await _client!.from('classes').update({'status': 'INACTIVE'}).eq('id', classId);
    }
  }

  Future<void> deleteClass(String classId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('sections').delete().eq('class_id', classId);
      } catch (_) {}
      await _client!.from('classes').delete().eq('id', classId);
    }
  }

  // --- SECTIONS ---
  Future<List<SectionModel>> fetchSections(String schoolId, String classId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('sections')
            .select()
            .eq('school_id', schoolId)
            .eq('class_id', classId)
            .order('display_order', ascending: true);

        if (data is List && data.isNotEmpty) {
          return data.map((s) => _mapSection(s)).toList();
        }
      } catch (e) {
        debugPrint('[ClassSectionService fetchSections Warning]: $e');
      }
    }

    return ['A', 'B', 'C'].map((sec) {
      return SectionModel(
        id: 'sec_${classId}_$sec',
        schoolId: schoolId,
        academicYearId: '',
        classId: classId,
        name: 'Section $sec',
        displayOrder: sec.codeUnitAt(0),
        status: AccountStatus.active,
        createdAt: DateTime.now(),
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

  Future<void> deleteSection(String sectionId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      await _client!.from('sections').delete().eq('id', sectionId);
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
    return SchoolClassModel(
      id: data['id']?.toString() ?? '',
      schoolId: data['school_id']?.toString() ?? '',
      academicYearId: data['academic_year_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      displayOrder: data['display_order'] is int
          ? data['display_order']
          : (int.tryParse(data['display_order']?.toString() ?? '') ?? 1),
      sectionsCount: sectionsCount > 0 ? sectionsCount : (data['sections_count'] ?? 0),
      status: (data['status']?.toString().toUpperCase() == 'INACTIVE') ? AccountStatus.inactive : AccountStatus.active,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  SectionModel _mapSection(Map<String, dynamic> data) {
    return SectionModel(
      id: data['id']?.toString() ?? '',
      schoolId: data['school_id']?.toString() ?? '',
      academicYearId: data['academic_year_id']?.toString() ?? '',
      classId: data['class_id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      displayOrder: data['display_order'] is int
          ? data['display_order']
          : (int.tryParse(data['display_order']?.toString() ?? '') ?? 1),
      capacity: data['capacity'] is int ? data['capacity'] : int.tryParse(data['capacity']?.toString() ?? ''),
      status: (data['status']?.toString().toUpperCase() == 'INACTIVE') ? AccountStatus.inactive : AccountStatus.active,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
