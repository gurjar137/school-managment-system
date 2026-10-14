import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/teacher_assignment_parser.dart';
import 'access_service.dart';
import 'tenant_resolver.dart';

class StudentService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  final List<StudentModel> _students = [];

  String _cacheKey(String? schoolId) {
    if (schoolId != null && schoolId.trim().isNotEmpty) {
      return 'cached_students_data_${schoolId.trim()}';
    }
    return 'cached_students_data';
  }

  Future<void> _persistStudentsCache([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetSchoolId = schoolId?.trim();
      final toSave = (targetSchoolId != null && targetSchoolId.isNotEmpty)
          ? _students.where((s) => s.schoolId == targetSchoolId).toList()
          : _students;
      final jsonList = toSave.map((s) => s.toJson()).toList();
      await prefs.setString(_cacheKey(targetSchoolId), jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[StudentService Cache Save Warning]: $e');
    }
  }

  Future<void> _restoreStudentsCache([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetSchoolId = schoolId?.trim();
      final cachedStr = prefs.getString(_cacheKey(targetSchoolId));
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final model = StudentModel.fromJson(item);
              if (targetSchoolId == null || targetSchoolId.isEmpty || model.schoolId == targetSchoolId) {
                if (!_students.any((s) => s.id == model.id || (model.admissionNumber.isNotEmpty && s.admissionNumber == model.admissionNumber))) {
                  _students.add(model);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[StudentService Cache Restore Warning]: $e');
    }
  }

  Future<int> getStudentCount({
    String? schoolId,
    String? academicYearId,
    String? className,
    String? section,
    AccountStatus? status,
  }) async {
    final activeSchoolId = (schoolId != null && schoolId.isNotEmpty)
        ? schoolId
        : await fetchActiveSchoolId();

    final activeAcademicYearId = (academicYearId != null && academicYearId.isNotEmpty)
        ? academicYearId
        : await fetchActiveAcademicYearId(activeSchoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('students')
            .select('id')
            .eq('school_id', activeSchoolId);

        if (activeAcademicYearId != null && activeAcademicYearId.isNotEmpty) {
          query = query.eq('academic_year_id', activeAcademicYearId);
        }

        if (className != null && className.trim().isNotEmpty && className.trim() != 'All') {
          final cleanClass = className.trim();
          final numericOnly = cleanClass.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericOnly.isNotEmpty) {
            query = query.or('class_name.eq.$cleanClass,class_name.eq.Class $numericOnly,class_name.eq.$numericOnly');
          } else {
            query = query.eq('class_name', cleanClass);
          }
        }

        if (section != null && section.trim().isNotEmpty && section.trim() != 'All') {
          query = query.ilike('section_name', section.trim());
        }

        if (status != null) {
          query = query.eq('status', status.name.toUpperCase());
        }

        final res = await query.count(CountOption.exact);
        return res.count;
      } catch (e) {
        debugPrint('[StudentService getStudentCount Error]: $e');
        rethrow;
      }
    }

    // Offline / Mock mode fallback
    var list = _students.where((s) => s.schoolId == activeSchoolId || activeSchoolId.isEmpty);
    if (activeAcademicYearId != null && activeAcademicYearId.isNotEmpty) {
      list = list.where((s) => s.academicYearId == activeAcademicYearId);
    }
    if (className != null && className.trim().isNotEmpty && className.trim() != 'All') {
      list = list.where((s) => s.className.toLowerCase() == className.toLowerCase());
    }
    if (section != null && section.trim().isNotEmpty && section.trim() != 'All') {
      list = list.where((s) => s.section.toLowerCase() == section.toLowerCase());
    }
    if (status != null) {
      list = list.where((s) => s.status == status);
    }
    return list.length;
  }

  Future<Set<String>> getStudentIdsForClass({
    String? schoolId,
    String? academicYearId,
    required String className,
    required String section,
    AccountStatus? status = AccountStatus.active,
  }) async {
    final activeSchoolId = (schoolId != null && schoolId.isNotEmpty)
        ? schoolId
        : await fetchActiveSchoolId();

    final activeAcademicYearId = (academicYearId != null && academicYearId.isNotEmpty)
        ? academicYearId
        : await fetchActiveAcademicYearId(activeSchoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('students')
            .select('id')
            .eq('school_id', activeSchoolId);

        if (activeAcademicYearId != null && activeAcademicYearId.isNotEmpty) {
          query = query.eq('academic_year_id', activeAcademicYearId);
        }

        if (className.trim().isNotEmpty && className.trim() != 'All') {
          final cleanClass = className.trim();
          final numericOnly = cleanClass.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericOnly.isNotEmpty) {
            query = query.or('class_name.eq.$cleanClass,class_name.eq.Class $numericOnly,class_name.eq.$numericOnly');
          } else {
            query = query.eq('class_name', cleanClass);
          }
        }

        if (section.trim().isNotEmpty && section.trim() != 'All') {
          query = query.ilike('section_name', section.trim());
        }

        if (status != null) {
          query = query.eq('status', status.name.toUpperCase());
        }

        final List<dynamic> rows = await query;
        return rows.map((r) => r['id'].toString()).toSet();
      } catch (e) {
        debugPrint('[StudentService getStudentIdsForClass Error]: $e');
        rethrow;
      }
    }

    // Offline / Mock mode fallback
    var list = _students.where((s) => s.schoolId == activeSchoolId || activeSchoolId.isEmpty);
    if (status != null) {
      list = list.where((s) => s.status == status);
    }
    if (className.trim().isNotEmpty && className.trim() != 'All') {
      final parser = TeacherAssignmentParser(assignedClass: className, assignedSection: section);
      list = list.where((s) => parser.matchesClassAndSection(s.className, s.section));
    }
    return list.map((s) => s.id).toSet();
  }

  Future<Map<String, int>> getClassStudentCounts({
    required List<String> classNames,
    String? schoolId,
    String? academicYearId,
    AccountStatus? status = AccountStatus.active,
  }) async {
    final activeSchoolId = (schoolId != null && schoolId.isNotEmpty)
        ? schoolId
        : await fetchActiveSchoolId();

    final activeAcademicYearId = (academicYearId != null && academicYearId.isNotEmpty)
        ? academicYearId
        : await fetchActiveAcademicYearId(activeSchoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final countFutures = classNames.map((className) async {
          try {
            final count = await getStudentCount(
              schoolId: activeSchoolId,
              academicYearId: activeAcademicYearId,
              className: className,
              status: status,
            );
            return MapEntry(className, count);
          } catch (e) {
            debugPrint('[StudentService getClassStudentCounts for $className Error]: $e');
            return MapEntry(className, 0);
          }
        });

        final results = await Future.wait(countFutures);
        return Map.fromEntries(results);
      } catch (e) {
        debugPrint('[StudentService getClassStudentCounts Error]: $e');
      }
    }

    // Offline / Mock fallback
    final Map<String, int> counts = {};
    for (final className in classNames) {
      final clean = className.toLowerCase().replaceAll('class', '').trim();
      final count = _students.where((s) {
        final matchesSchool = activeSchoolId.isEmpty || s.schoolId == activeSchoolId;
        final matchesAy = activeAcademicYearId == null || activeAcademicYearId.isEmpty || s.academicYearId == activeAcademicYearId;
        final sClass = s.className.toLowerCase().replaceAll('class', '').trim();
        final matchesClass = sClass == clean || s.className.toLowerCase().trim() == className.toLowerCase().trim();
        final matchesStatus = status == null || s.status == status;
        return matchesSchool && matchesAy && matchesClass && matchesStatus;
      }).length;
      counts[className] = count;
    }
    return counts;
  }

  Future<List<StudentModel>> getAllStudents({
    String? schoolId,
    String? academicYearId,
    String? query,
    String? className,
    String? section,
    AccountStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    final activeSchoolId = (schoolId != null && schoolId.isNotEmpty)
        ? schoolId
        : await fetchActiveSchoolId();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var supabaseQuery = _client!
            .from('students')
            .select('*')
            .eq('school_id', activeSchoolId);

        if (academicYearId != null && academicYearId.isNotEmpty) {
          supabaseQuery = supabaseQuery.eq('academic_year_id', academicYearId);
        }

        // 1. Server-side Class Filter
        if (className != null && className.trim().isNotEmpty && className.trim() != 'All') {
          final cleanClass = className.trim();
          final numericOnly = cleanClass.replaceAll(RegExp(r'[^0-9]'), '');
          if (numericOnly.isNotEmpty) {
            supabaseQuery = supabaseQuery.or('class_name.eq.$cleanClass,class_name.eq.Class $numericOnly,class_name.eq.$numericOnly');
          } else {
            supabaseQuery = supabaseQuery.eq('class_name', cleanClass);
          }
        }

        // 2. Server-side Section Filter
        if (section != null && section.trim().isNotEmpty && section.trim() != 'All') {
          supabaseQuery = supabaseQuery.ilike('section_name', section.trim());
        }

        // 3. Server-side Status Filter
        if (status != null) {
          supabaseQuery = supabaseQuery.eq('status', status.name.toUpperCase());
        }

        // 4. Server-side Search across ALL 10,000+ students
        if (query != null && query.trim().isNotEmpty) {
          final q = query.trim();
          final words = q.split(RegExp(r'\s+'));
          if (words.length > 1) {
            final lastWord = words.last;
            supabaseQuery = supabaseQuery.or(
              'admission_number.ilike.%$q%,'
              'admission_number.ilike.%$lastWord%,'
              'last_name.ilike.%$lastWord%,'
              'last_name.ilike.%$q%,'
              'first_name.ilike.%$q%,'
              'parent_access_code.ilike.%$q%,'
              'roll_number.ilike.%$q%,'
              'phone.ilike.%$q%'
            );
          } else {
            supabaseQuery = supabaseQuery.or(
              'admission_number.ilike.%$q%,'
              'first_name.ilike.%$q%,'
              'last_name.ilike.%$q%,'
              'middle_name.ilike.%$q%,'
              'parent_access_code.ilike.%$q%,'
              'roll_number.ilike.%$q%,'
              'phone.ilike.%$q%'
            );
          }
        }

        // 5. Ordering and server-side range pagination
        final data = await supabaseQuery
            .order('admission_number', ascending: true)
            .range(offset, offset + limit - 1);

        final List<StudentModel> list = [];
        for (final row in data) {
          final model = _mapSupabaseToStudentModel(row);
            list.add(model);
            final existingIdx = _students.indexWhere((s) => s.id == model.id || (model.admissionNumber.isNotEmpty && s.admissionNumber == model.admissionNumber));
            if (existingIdx != -1) {
              _students[existingIdx] = model;
            } else {
              _students.add(model);
            }
          }
          await _persistStudentsCache();
        return list;
      } catch (e) {
        debugPrint('[StudentService getAllStudents Supabase Error]: $e');
        rethrow;
      }
    }

    // Offline / Mock fallback
    if (_students.isEmpty) {
      await _restoreStudentsCache();
    }
    var list = List<StudentModel>.from(_students);
    final parser = TeacherAssignmentParser(
      assignedClass: (className != null && className != 'All') ? className : null,
      assignedSection: (section != null && section != 'All') ? section : null,
    );
    if (parser.hasFilter) {
      list = list.where((s) => parser.matchesStudent(
        s,
        expectedSchoolId: activeSchoolId,
        expectedAcademicYearId: academicYearId,
      )).toList();
    }
    if (status != null) {
      list = list.where((s) => s.status == status).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.rollNumber.toLowerCase().contains(q) ||
            s.admissionNumber.toLowerCase().contains(q) ||
            s.studentCode.toLowerCase().contains(q) ||
            s.fatherName.toLowerCase().contains(q) ||
            s.fatherMobile.contains(q);
      }).toList();
    }

    if (offset >= list.length) return [];
    final endIndex = (offset + limit) < list.length ? (offset + limit) : list.length;
    return list.sublist(offset, endIndex);
  }

  Future<StudentModel?> getStudentById(String id) async {
    final cached = _students.where((s) => s.id == id || (s.admissionNumber.isNotEmpty && s.admissionNumber == id));
    if (cached.isNotEmpty) return cached.first;

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final cleanId = id.trim();
        final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(cleanId);
        final dynamic query = isUuid
            ? _client!.from('students').select('*').eq('id', cleanId)
            : _client!.from('students').select('*').eq('admission_number', cleanId);
        final data = await query.maybeSingle();
        if (data != null) {
          final model = _mapSupabaseToStudentModel(data);
          _students.add(model);
          return model;
        }
      } catch (e) {
        debugPrint('[StudentService getStudentById Error]: $e');
      }
    }
    return null;
  }

  String generateUniqueStudentNumber({String prefix = 'STU-2026'}) {
    final count = _students.length + 1;
    final timestampSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    return '$prefix-${count.toString().padLeft(4, '0')}$timestampSuffix';
  }

  Future<Map<String, dynamic>?> fetchActiveAcademicYearRecord(String schoolId) async {
    if (_client == null || !SupabaseConfig.isConfigured) {
      return {
        'id': '47d1569b-e032-44a7-891f-b21f5458f55b',
        'name': '2026-2027',
        'school_id': schoolId,
      };
    }

    final nowStr = DateTime.now().toIso8601String().split('T').first;

    try {
      final allYears = await _client!
          .from('academic_years')
          .select('id, name, school_id, start_date, end_date')
          .eq('school_id', schoolId);

      if (allYears.isNotEmpty) {
        final matching = allYears.where((ay) {
          final s = ay['start_date'] as String?;
          final e = ay['end_date'] as String?;
          if (s != null && e != null) {
            return s.compareTo(nowStr) <= 0 && e.compareTo(nowStr) >= 0;
          }
          return false;
        }).toList();

        if (matching.isNotEmpty) {
          return Map<String, dynamic>.from(matching.first);
        }
        return Map<String, dynamic>.from(allYears.first);
      }
    } catch (e) {
      debugPrint('[StudentService fetchActiveAcademicYearRecord Warning]: $e');
    }

    return null;
  }

  Future<String?> fetchActiveAcademicYearId(String schoolId) async {
    final rec = await fetchActiveAcademicYearRecord(schoolId);
    return rec?['id'] as String?;
  }

  Future<String> fetchActiveSchoolId({String? fallback}) async {
    return TenantResolver.resolveActiveSchoolId(
      client: _client,
      requestedSchoolId: fallback,
    );
  }

  Future<List<Map<String, dynamic>>> fetchClasses(String schoolId, String academicYearId, {String academicYearName = ''}) async {
    print("=== CLASS LOAD START ===");
    print("SCHOOL ID = $schoolId");
    print("ACADEMIC YEAR ID = $academicYearId");

    List<Map<String, dynamic>> result = [];

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        // Diagnostic Query 1: Filtered only by school_id
        final schoolOnly = await _client!
            .from('classes')
            .select('id, school_id, academic_year_id, name, display_order, status')
            .eq('school_id', schoolId)
            .order('display_order', ascending: true);

        print("SCHOOL-ONLY CLASS COUNT = ${schoolOnly.length}");
        for (final row in schoolOnly) {
          print("ROW id=${row['id']} school_id=${row['school_id']} academic_year_id=${row['academic_year_id']} name=${row['name']}");
        }

        // Diagnostic Query 2: Filtered by school_id + academic_year_id
        final schoolAy = await _client!
            .from('classes')
            .select('id, school_id, academic_year_id, name, display_order, status')
            .eq('school_id', schoolId)
            .eq('academic_year_id', academicYearId)
            .order('display_order', ascending: true);

        print("SCHOOL+AY CLASS COUNT = ${schoolAy.length}");

        if (schoolAy.isNotEmpty) {
          result = List<Map<String, dynamic>>.from(schoolAy);
        } else if (schoolOnly.isNotEmpty) {
          // If classes exist for school but academic_year_id needs linking
          try {
            await _client!
                .from('classes')
                .update({'academic_year_id': academicYearId})
                .eq('school_id', schoolId);

            final reloaded = await _client!
                .from('classes')
                .select('id, school_id, academic_year_id, name, display_order, status')
                .eq('school_id', schoolId)
                .eq('academic_year_id', academicYearId)
                .order('display_order', ascending: true);
            if (reloaded.isNotEmpty) {
              result = List<Map<String, dynamic>>.from(reloaded);
            }
          } catch (_) {
            result = List<Map<String, dynamic>>.from(schoolOnly);
          }
        }

        print("========== RAW SUPABASE CLASSES ==========");
        print("raw count = ${result.length}");
        for (final row in result) {
          print("RAW DB ROW = $row");
        }
        print("===========================================");

        if (result.isNotEmpty) {
          final firstId = result.first['id'].toString();
          final verification = await _client!
              .from('classes')
              .select('id, name')
              .eq('id', firstId)
              .maybeSingle();

          print("RAW FIRST CLASS ID = $firstId");
          print("RAW FIRST CLASS NAME = ${result.first['name']}");
          print("RAW FIRST CLASS VERIFICATION = $verification");
        }
      } catch (e) {
        debugPrint('[StudentService fetchClasses Error]: $e');
      }
    }

    if (result.isEmpty && !SupabaseConfig.isConfigured) {
      final effectiveAy = academicYearId.isNotEmpty ? academicYearId : 'mock_academic_year_id';
      result = List.generate(12, (i) {
        final num = i + 1;
        return {
          'id': 'mock_class_id_$num',
          'school_id': schoolId.isNotEmpty ? schoolId : 'offline_mock_school',
          'academic_year_id': effectiveAy,
          'name': 'Class $num',
          'display_order': num,
          'status': 'ACTIVE',
        };
      });
    }

    print("FETCH CLASSES SOURCE = Live Supabase public.classes");
    print("RETURNING CLASS COUNT = ${result.length}");

    return result;
  }

  Future<List<String>> fetchDistinctClassNames({required String schoolId}) async {
    final cleanSchoolId = schoolId.trim();
    if (_client != null && SupabaseConfig.isConfigured && cleanSchoolId.isNotEmpty) {
      try {
        final normalized = <String>{};
        int offset = 0;
        while (offset < 10000) {
          final res = await _client!
              .from('students')
              .select('class_name')
              .eq('school_id', cleanSchoolId)
              .range(offset, offset + 999);
          if (res.isNotEmpty) {
            for (final row in res) {
              final raw = row['class_name']?.toString().trim();
              if (raw == null || raw.isEmpty) continue;
              final numOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
              if (numOnly.isNotEmpty) {
                normalized.add('Class $numOnly');
              } else {
                normalized.add(raw);
              }
            }
            if (res.length < 1000) break;
            offset += res.length;
            if (normalized.length >= 12) break;
          } else {
            break;
          }
        }
        if (normalized.isNotEmpty) {
          final list = normalized.toList();
          list.sort((a, b) {
            final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
            final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
            return numA.compareTo(numB);
          });
          return list;
        }
      } catch (e) {
        debugPrint('[StudentService fetchDistinctClassNames Error]: $e');
      }
    }
    final inMemory = _students
        .where((s) => s.schoolId == cleanSchoolId && s.className.isNotEmpty)
        .map((s) {
          final raw = s.className.trim();
          final numOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
          return numOnly.isNotEmpty ? 'Class $numOnly' : raw;
        })
        .toSet()
        .toList();
    inMemory.sort((a, b) {
      final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
      return numA.compareTo(numB);
    });
    return inMemory;
  }

  Future<List<Map<String, dynamic>>> fetchSections(String schoolId, String academicYearId, String classId) async {
    List<Map<String, dynamic>> result = [];
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await _client!
            .from('sections')
            .select('id, school_id, class_id, name')
            .eq('school_id', schoolId)
            .eq('class_id', classId)
            .order('name', ascending: true);

        if (res.isNotEmpty) {
          result = List<Map<String, dynamic>>.from(res);
        } else {
          final List<Map<String, dynamic>> toInsertSecs = [];
          for (final sec in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']) {
            toInsertSecs.add({
              'school_id': schoolId,
              'class_id': classId,
              'name': 'Section $sec',
            });
          }
          final created = await _client!
              .from('sections')
              .insert(toInsertSecs)
              .select('id, school_id, class_id, name')
              .order('name', ascending: true);

          if (created.isNotEmpty) {
            result = List<Map<String, dynamic>>.from(created);
          }
        }

        print("========== RAW SUPABASE SECTIONS ==========");
        print("raw section count = ${result.length}");
        for (final row in result) {
          print("RAW DB SECTION ROW = $row");
        }
        print("===========================================");
      } catch (e) {
        debugPrint('[StudentService fetchSections Error]: $e');
      }
    }

    print("FETCH SECTIONS SOURCE = Live Supabase public.sections");
    print("RETURNING SECTION COUNT = ${result.length}");

    return result;
  }

  String? _normalizeUuid(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  Map<String, dynamic> buildStudentInsertPayload({
    required String schoolId,
    required String? academicYearId,
    required String className,
    required String sectionName,
    required String admissionNumber,
    String? parentAccessCode,
    String? fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    String? rollNumber,
    String? gender,
    String? dateOfBirth,
    String? studentPhoto,
    String? phone,
    String? email,
    String? address,
    String? status,
  }) {
    String finalFirstName = (firstName ?? '').trim();
    String finalMiddleName = (middleName ?? '').trim();
    String finalLastName = (lastName ?? '').trim();

    if (finalFirstName.isEmpty && fullName != null && fullName.trim().isNotEmpty) {
      final names = fullName.trim().split(RegExp(r'\s+'));
      finalFirstName = names.first;
      if (names.length == 2) {
        finalLastName = names[1];
      } else if (names.length > 2) {
        finalMiddleName = names.sublist(1, names.length - 1).join(' ');
        finalLastName = names.last;
      }
    }

    final normSchoolId = _normalizeUuid(schoolId);
    final normAyId = _normalizeUuid(academicYearId);

    if (normSchoolId == null || normSchoolId.isEmpty) {
      throw const TenantResolutionException('Valid school_id is required for student registration.');
    }
    if (normAyId == null || normAyId.isEmpty) {
      throw const AcademicYearResolutionException('A valid active academic year is required for student registration.');
    }

    final payload = <String, dynamic>{
      'school_id': normSchoolId,
      'academic_year_id': normAyId,
      'admission_number': admissionNumber,
      'first_name': finalFirstName,
      'last_name': finalLastName,
      'class_name': className.trim(),
      'section_name': sectionName.trim(),
    };

    if (finalMiddleName.isNotEmpty) {
      payload['middle_name'] = finalMiddleName;
    }
    if (studentPhoto != null && studentPhoto.trim().isNotEmpty) {
      payload['student_photo'] = studentPhoto.trim();
    }

    if (parentAccessCode != null && parentAccessCode.trim().isNotEmpty) {
      payload['parent_access_code'] = parentAccessCode.trim();
    }

    if (rollNumber != null && rollNumber.trim().isNotEmpty) {
      payload['roll_number'] = rollNumber.trim();
    }
    if (gender != null && gender.trim().isNotEmpty) {
      payload['gender'] = gender.trim();
    }
    if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty) {
      payload['date_of_birth'] = dateOfBirth.trim();
    }
    if (phone != null && phone.trim().isNotEmpty) {
      payload['phone'] = phone.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      payload['email'] = email.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      payload['address'] = address.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      payload['status'] = status.toUpperCase().trim();
    }

    return payload;
  }

  Future<String> generateUniqueParentAccessCode() async {
    for (int i = 0; i < 15; i++) {
      final code = AccessService.generateUniqueParentCode();
      if (_client != null && SupabaseConfig.isConfigured) {
        try {
          final existing = await _client!
              .from('students')
              .select('id')
              .eq('parent_access_code', code)
              .maybeSingle();
          if (existing == null) {
            return code;
          }
        } catch (_) {
          return code;
        }
      } else {
        return code;
      }
    }
    return AccessService.generateUniqueParentCode();
  }

  Future<List<String>> checkStudentDependencies(String studentId, String schoolId) async {
    final cleanId = studentId.trim();
    final cleanSchoolId = schoolId.trim();
    final List<String> reasons = [];

    if (_client == null || !SupabaseConfig.isConfigured || cleanId.isEmpty) {
      return reasons;
    }

    try {
      final att = await _client!
          .from('attendance')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('student_id', cleanId);
      if (att.isNotEmpty) {
        reasons.add('${att.length} attendance record(s)');
      }
    } catch (_) {}

    try {
      final fees = await _client!
          .from('student_fee_accounts')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('student_id', cleanId);
      if (fees.isNotEmpty) {
        reasons.add('${fees.length} fee account(s)');
      }
    } catch (_) {}

    try {
      final marks = await _client!
          .from('marks')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('student_id', cleanId);
      if (marks.isNotEmpty) {
        reasons.add('${marks.length} exam mark record(s)');
      }
    } catch (_) {}

    return reasons;
  }

  Future<StudentModel> addStudent(
    StudentModel newStudent, {
    double? grossFee,
    double? discountAmount,
    double? waiverAmount,
    DateTime? dueDate,
    String? feeNotes,
  }) async {
    String activeSchoolId = newStudent.schoolId.isNotEmpty
        ? newStudent.schoolId
        : await fetchActiveSchoolId();

    String? activeAcademicYearId;
    if (newStudent.academicYearId.isNotEmpty) {
      activeAcademicYearId = newStudent.academicYearId;
    } else if (_client != null && SupabaseConfig.isConfigured) {
      activeAcademicYearId = await fetchActiveAcademicYearId(activeSchoolId);
    }

    if (activeAcademicYearId == null || activeAcademicYearId.trim().isEmpty) {
      if (!SupabaseConfig.isConfigured) {
        activeAcademicYearId = 'mock_academic_year_id';
      } else {
        throw AcademicYearResolutionException(
          'No active academic year is configured for school $activeSchoolId.',
          schoolId: activeSchoolId,
        );
      }
    }

    final count = _students.length + 1;
    final timestampSuffix = DateTime.now().millisecondsSinceEpoch.toString().substring(9);
    final autoStudentNumber = 'STU-2026-${count.toString().padLeft(4, '0')}$timestampSuffix';

    final finalAdmissionNumber = (newStudent.admissionNumber.trim().isEmpty || newStudent.admissionNumber.startsWith('ADM-2026-'))
        ? autoStudentNumber
        : newStudent.admissionNumber.trim();

    // Check duplicate admission number in memory strictly scoped to the same school
    final duplicateInMemory = _students.any((s) =>
        s.id != newStudent.id &&
        s.schoolId == activeSchoolId &&
        s.admissionNumber.trim().isNotEmpty &&
        s.admissionNumber.trim().toLowerCase() == finalAdmissionNumber.toLowerCase());
    if (duplicateInMemory) {
      throw Exception('Student with admission number $finalAdmissionNumber already exists in this school.');
    }

    // 1. If student ID already exists in memory, UPDATE existing record
    final existsInMemory = newStudent.id.isNotEmpty && _students.any((s) => s.id == newStudent.id);
    if (existsInMemory) {
      final updatedModel = newStudent.copyWith(
        admissionNumber: finalAdmissionNumber,
        schoolId: activeSchoolId,
        academicYearId: activeAcademicYearId,
      );
      await updateStudent(updatedModel);
      return updatedModel;
    }

    // 2. Check if a student with the same admission number already exists in Supabase for THIS school
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final existingRow = await _client!
            .from('students')
            .select('id, parent_access_code')
            .eq('school_id', activeSchoolId)
            .eq('admission_number', finalAdmissionNumber)
            .maybeSingle();

        if (existingRow != null && existingRow['id'] != null) {
          final existingId = existingRow['id'].toString();
          if (newStudent.id.isNotEmpty && newStudent.id == existingId) {
            // Self-update
          } else {
            throw Exception('Student with admission number $finalAdmissionNumber already exists in this school.');
          }
        }
      } on Exception catch (e) {
        if (e.toString().contains('already exists in this school')) {
          rethrow;
        }
        debugPrint('[StudentService addStudent duplicate check notice]: $e');
      }
    }

    final parentAccessCode = (newStudent.parentAccessCode.trim().isNotEmpty)
        ? newStudent.parentAccessCode.trim()
        : await generateUniqueParentAccessCode();

    final studentWithNumber = newStudent.copyWith(
      admissionNumber: finalAdmissionNumber,
      parentAccessCode: parentAccessCode,
      schoolId: activeSchoolId,
      academicYearId: activeAcademicYearId,
    );

    if (_client != null && SupabaseConfig.isConfigured) {
      String? formattedDob;
      if (newStudent.dateOfBirth.trim().isNotEmpty) {
        final rawDob = newStudent.dateOfBirth.trim();
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDob)) {
          formattedDob = rawDob;
        } else {
          try {
            final parsed = DateTime.tryParse(rawDob);
            if (parsed != null) {
              formattedDob =
                  "${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
            }
          } catch (_) {}
        }
      }

      final payload = buildStudentInsertPayload(
        schoolId: activeSchoolId,
        academicYearId: activeAcademicYearId,
        className: newStudent.className,
        sectionName: newStudent.section,
        admissionNumber: finalAdmissionNumber,
        parentAccessCode: parentAccessCode,
        fullName: newStudent.name.trim(),
        firstName: newStudent.firstName.isNotEmpty ? newStudent.firstName : null,
        middleName: newStudent.middleName.isNotEmpty ? newStudent.middleName : null,
        lastName: newStudent.lastName.isNotEmpty ? newStudent.lastName : null,
        studentPhoto: newStudent.studentPhoto.isNotEmpty ? newStudent.studentPhoto : newStudent.avatarUrl,
        rollNumber: newStudent.rollNumber,
        gender: newStudent.gender,
        dateOfBirth: formattedDob,
        phone: newStudent.fatherMobile,
        email: newStudent.parentEmail,
        address: newStudent.address,
        status: newStudent.status.name,
      );

      try {
        final res = await _client!.from('students').insert(payload).select().maybeSingle();
        if (res == null || res['id'] == null) {
          throw Exception('Failed to insert student into database.');
        }

        final insertedId = res['id'].toString();

        final createdModel = studentWithNumber.copyWith(
          id: insertedId,
          className: newStudent.className.trim(),
          section: newStudent.section.trim(),
          parentAccessCode: parentAccessCode,
        );

        // CREATE FEE ACCOUNT RECORD IF GROSS FEE > 0
        final enteredFee = (grossFee != null && grossFee > 0)
            ? grossFee
            : (newStudent.totalFee > 0 ? newStudent.totalFee : 0.0);

        if (enteredFee > 0) {
          try {
            final double disc = discountAmount ?? 0.0;
            final double waiv = waiverAmount ?? 0.0;
            final double net = (enteredFee - disc - waiv).clamp(0.0, double.infinity);
            final initialStatus = net <= 0 ? 'paid' : 'due';

            final feePayload = {
              'school_id': activeSchoolId,
              'academic_year_id': activeAcademicYearId,
              'student_id': insertedId,
              'gross_fee': enteredFee,
              'discount_amount': disc,
              'waiver_amount': waiv,
              'due_date': dueDate?.toIso8601String().substring(0, 10),
              'notes': feeNotes,
              'status': initialStatus,
            };

            await _client!.from('student_fee_accounts').insert(feePayload);
          } on PostgrestException catch (fe) {
            debugPrint('[StudentService addStudent Fee Account Error]: ${fe.message} (code: ${fe.code})');
            throw Exception('Student created, but fee details could not be saved: ${fe.message}');
          } catch (fe) {
            debugPrint('[StudentService addStudent Fee Account Error]: $fe');
            throw Exception('Student created, but fee details could not be saved: $fe');
          }
        }

        _students.removeWhere((s) => s.admissionNumber == finalAdmissionNumber);
        _students.add(createdModel);
        await _persistStudentsCache();
        return createdModel;
      } on PostgrestException catch (e) {
        throw Exception(e.message);
      } catch (e) {
        rethrow;
      }
    }

    _students.insert(0, studentWithNumber);
    return studentWithNumber;
  }

  Future<void> updateStudent(StudentModel updated) async {
    final idx = _students.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      _students[idx] = updated;
      await _persistStudentsCache();
    }

    if (_client != null && SupabaseConfig.isConfigured && updated.id.isNotEmpty) {
      try {
        String? formattedDob;
        if (updated.dateOfBirth.trim().isNotEmpty) {
          final rawDob = updated.dateOfBirth.trim();
          if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDob)) {
            formattedDob = rawDob;
          } else {
            try {
              final parsed = DateTime.tryParse(rawDob);
              if (parsed != null) {
                formattedDob =
                    "${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
              }
            } catch (_) {}
          }
        }

        final payload = buildStudentInsertPayload(
          schoolId: updated.schoolId,
          academicYearId: updated.academicYearId,
          className: updated.className,
          sectionName: updated.section,
          admissionNumber: updated.admissionNumber,
          parentAccessCode: updated.parentAccessCode,
          fullName: updated.name.trim(),
          firstName: updated.firstName.isNotEmpty ? updated.firstName : null,
          middleName: updated.middleName.isNotEmpty ? updated.middleName : null,
          lastName: updated.lastName.isNotEmpty ? updated.lastName : null,
          studentPhoto: updated.studentPhoto.isNotEmpty ? updated.studentPhoto : updated.avatarUrl,
          rollNumber: updated.rollNumber,
          gender: updated.gender,
          dateOfBirth: formattedDob,
          phone: updated.fatherMobile,
          email: updated.parentEmail,
          address: updated.address,
          status: updated.status.name,
        );

        await _client!.from('students').update(payload).eq('id', updated.id);
      } catch (e) {
        debugPrint('[StudentService updateStudent Error]: $e');
      }
    }
  }

  Future<void> updateStudentStatus(String studentId, AccountStatus newStatus) async {
    final activeSchoolId = await fetchActiveSchoolId();
    final statusStr = newStatus.name.toUpperCase();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!
            .from('students')
            .update({'status': statusStr, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', studentId)
            .eq('school_id', activeSchoolId);
      } catch (e) {
        debugPrint('[StudentService updateStudentStatus DB Note]: $e');
      }
    }

    final idx = _students.indexWhere((s) => s.id == studentId);
    if (idx != -1) {
      _students[idx] = _students[idx].copyWith(status: newStatus);
      await _persistStudentsCache();
    }
  }

  Future<void> deleteStudent(String id) async {
    final activeSchoolId = await fetchActiveSchoolId();

    if (_client != null && SupabaseConfig.isConfigured) {
      // Proactively check if student has fee accounts to protect financial records
      try {
        final fees = await _client!
            .from('student_fee_accounts')
            .select('id')
            .eq('student_id', id)
            .limit(1);
        if (fees.isNotEmpty) {
          throw Exception(
            'Cannot permanently delete student with existing fee accounts, transaction receipts, or academic records. '
            'Please deactivate the student instead to preserve historical records.',
          );
        }
      } on Exception catch (e) {
        if (e.toString().contains('Cannot permanently delete')) rethrow;
      }

      try {
        await _client!
            .from('students')
            .delete()
            .eq('id', id)
            .eq('school_id', activeSchoolId);
      } on PostgrestException catch (e) {
        if (e.code == '23503') {
          throw Exception(
            'Cannot permanently delete student with existing fee accounts, attendance, or academic records. '
            'Please deactivate the student instead to preserve historical records.',
          );
        }
        debugPrint('[StudentService deleteStudent DB Note]: ${e.message}');
      } catch (e) {
        debugPrint('[StudentService deleteStudent Error]: $e');
      }
    }

    _students.removeWhere((s) => s.id == id);
    await _persistStudentsCache();
  }

  StudentModel _mapSupabaseToStudentModel(Map<String, dynamic> data) {
    String resolvedClassName = '';
    if (data['class_name'] != null && data['class_name'].toString().trim().isNotEmpty) {
      resolvedClassName = data['class_name'].toString().trim();
    } else if (data['class'] != null && data['class'].toString().trim().isNotEmpty) {
      resolvedClassName = data['class'].toString().trim();
    } else if (data['classes'] != null && data['classes'] is Map) {
      resolvedClassName = data['classes']['name']?.toString() ?? '';
    }

    String resolvedSectionName = '';
    if (data['section_name'] != null && data['section_name'].toString().trim().isNotEmpty) {
      resolvedSectionName = data['section_name'].toString().trim();
    } else if (data['section'] != null && data['section'].toString().trim().isNotEmpty) {
      resolvedSectionName = data['section'].toString().trim();
    } else if (data['sections'] != null && data['sections'] is Map) {
      resolvedSectionName = data['sections']['name']?.toString() ?? '';
    }

    final rawFirstName = data['first_name']?.toString() ?? '';
    final rawMiddleName = data['middle_name']?.toString() ?? '';
    final rawLastName = data['last_name']?.toString() ?? '';

    String fullName = data['full_name']?.toString() ?? data['name']?.toString() ?? '';
    if (fullName.isEmpty) {
      fullName = [rawFirstName, rawMiddleName, rawLastName].where((s) => s.trim().isNotEmpty).join(' ');
    }

    final photo = data['student_photo']?.toString() ?? data['profile_photo_url']?.toString() ?? data['avatar_url']?.toString() ?? 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=150';
    final admNo = data['admission_number']?.toString() ?? '';

    return StudentModel(
      id: data['id']?.toString() ?? '',
      schoolId: data['school_id']?.toString() ?? '',
      academicYearId: data['academic_year_id']?.toString() ?? '',
      classId: data['class_id']?.toString() ?? '',
      sectionId: data['section_id']?.toString() ?? '',
      studentCode: admNo.isNotEmpty ? admNo : 'STU-2026-0001',
      parentAccessCode: data['parent_access_code']?.toString() ?? '',
      name: fullName.isNotEmpty ? fullName : 'Student',
      firstName: rawFirstName,
      middleName: rawMiddleName,
      lastName: rawLastName,
      rollNumber: data['roll_number']?.toString() ?? '',
      admissionNumber: admNo,
      className: resolvedClassName,
      section: resolvedSectionName,
      avatarUrl: photo,
      studentPhoto: photo,
      attendancePercentage: (data['attendance_pct'] as num?)?.toDouble() ?? 100.0,
      todayAttendance: AttendanceStatus.notMarked,
      dateOfBirth: data['date_of_birth']?.toString() ?? '',
      gender: data['gender']?.toString() ?? 'Male',
      fatherName: data['father_name']?.toString() ?? '',
      fatherMobile: data['phone']?.toString() ?? data['father_mobile']?.toString() ?? '',
      motherName: data['mother_name']?.toString() ?? '',
      motherMobile: data['mother_mobile']?.toString() ?? '',
      guardianName: data['guardian_name']?.toString() ?? data['father_name']?.toString() ?? '',
      emergencyContact: data['emergency_contact']?.toString() ?? data['phone']?.toString() ?? '',
      parentEmail: data['email']?.toString() ?? data['parent_email']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      pinCode: data['postal_code']?.toString() ?? data['pin_code']?.toString() ?? '',
      bloodGroup: data['blood_group']?.toString() ?? 'O+',
      medicalNotes: data['medical_notes']?.toString() ?? '',
      importantNotes: data['important_notes']?.toString() ?? '',
      status: data['status'] == 'INACTIVE' ? AccountStatus.inactive : AccountStatus.active,
      totalFee: (data['total_fee'] as num?)?.toDouble() ?? 0.0,
      paidFee: (data['paid_fee'] as num?)?.toDouble() ?? 0.0,
      pendingFee: (data['pending_fee'] as num?)?.toDouble() ?? 0.0,
      feeStatus: PaymentStatus.paid,
      paymentHistory: const [],
    );
  }
}
