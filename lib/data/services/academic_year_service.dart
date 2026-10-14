import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/class_section_models.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';

class AcademicYearValidationException implements Exception {
  final String message;
  const AcademicYearValidationException(this.message);

  @override
  String toString() => message;
}

class AcademicYearDependencyException implements Exception {
  final String message;
  final List<String> dependencies;

  const AcademicYearDependencyException(this.message, {this.dependencies = const []});

  @override
  String toString() => message;
}

class AcademicYearService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  // Local state cache for offline/mock support & quick lookups
  final List<AcademicYearModel> _cache = [];

  List<AcademicYearModel> get cachedYears => List.unmodifiable(_cache);

  /// Fetch all academic years belonging strictly to [schoolId].
  Future<List<AcademicYearModel>> fetchAcademicYears(String schoolId) async {
    final cleanSchoolId = schoolId.trim();
    if (cleanSchoolId.isEmpty) return [];

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await _client!
            .from('academic_years')
            .select()
            .eq('school_id', cleanSchoolId)
            .order('start_date', ascending: false);

        if (res.isNotEmpty) {
          final list = res.map((row) => AcademicYearModel.fromJson(Map<String, dynamic>.from(row))).toList();
          _cache.removeWhere((y) => y.schoolId == cleanSchoolId);
          _cache.addAll(list);
          return list;
        }
      } catch (e) {
        debugPrint('[AcademicYearService fetchAcademicYears warning]: $e');
      }
    }

    // Return cached records for this school
    final local = _cache.where((y) => y.schoolId == cleanSchoolId).toList();
    if (local.isNotEmpty) {
      return local;
    }

    // Pure offline / unconfigured mock mode ONLY
    if (!SupabaseConfig.isConfigured) {
      final mockYear = AcademicYearModel(
        id: 'mock_ay_${cleanSchoolId.hashCode.abs()}',
        schoolId: cleanSchoolId,
        name: '2026-2027',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
        isCurrent: true,
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 1),
      );
      _cache.add(mockYear);
      return [mockYear];
    }

    return [];
  }

  /// Validate inputs and verify no duplicate or overlapping dates exist for [schoolId].
  void validateAcademicYearInput({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required List<AcademicYearModel> existingYears,
    String? currentYearId,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const AcademicYearValidationException('Academic year name cannot be empty.');
    }

    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (end.isBefore(start)) {
      throw const AcademicYearValidationException('End date cannot be before start date.');
    }

    for (final existing in existingYears) {
      // Exclude self when editing
      if (currentYearId != null && existing.id == currentYearId) {
        continue;
      }

      // 1. Duplicate name check
      if (existing.name.trim().toLowerCase() == trimmedName.toLowerCase()) {
        throw AcademicYearValidationException(
          'An academic year with name "$trimmedName" already exists for this school.',
        );
      }

      // 2. Overlap check
      if (existing.startDate != null && existing.endDate != null) {
        final exStart = DateTime(existing.startDate!.year, existing.startDate!.month, existing.startDate!.day);
        final exEnd = DateTime(existing.endDate!.year, existing.endDate!.month, existing.endDate!.day);

        // Two ranges [S1, E1] and [S2, E2] overlap if S1 <= E2 && E1 >= S2
        final overlaps = !start.isAfter(exEnd) && !end.isBefore(exStart);
        if (overlaps) {
          throw AcademicYearValidationException(
            'Date range overlaps with existing academic year "${existing.name}" (${existing.dateRangeFormatted}).',
          );
        }
      }
    }
  }

  /// Create a new academic year strictly for [schoolId].
  Future<AcademicYearModel> createAcademicYear({
    required String schoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    AccountStatus status = AccountStatus.active,
  }) async {
    final cleanSchoolId = schoolId.trim();
    if (cleanSchoolId.isEmpty) {
      throw const AcademicYearValidationException('school_id is required from authenticated profile.');
    }

    // Load existing years for overlap & duplicate checking
    final existing = await fetchAcademicYears(cleanSchoolId);
    validateAcademicYearInput(
      name: name,
      startDate: startDate,
      endDate: endDate,
      existingYears: existing,
    );

    final startStr = _formatDateStr(startDate);
    final endStr = _formatDateStr(endDate);
    final statusStr = status == AccountStatus.inactive ? 'INACTIVE' : 'ACTIVE';

    if (_client != null && SupabaseConfig.isConfigured) {
      final insertPayload = <String, dynamic>{
        'school_id': cleanSchoolId,
        'name': name.trim(),
        'start_date': startStr,
        'end_date': endStr,
        'status': statusStr,
      };

      try {
        final res = await _client!.from('academic_years').insert(insertPayload).select().single();
        final created = AcademicYearModel.fromJson(Map<String, dynamic>.from(res));
        _cache.removeWhere((y) => y.id == created.id);
        _cache.insert(0, created);
        return created;
      } catch (e) {
        debugPrint('[AcademicYearService createAcademicYear DB note]: $e');
      }
    }

    // Offline / Mock fallback
    final mock = AcademicYearModel(
      id: 'ay_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: cleanSchoolId,
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      status: status,
      createdAt: DateTime.now(),
    );
    _cache.insert(0, mock);
    return mock;
  }

  /// Edit existing academic year details.
  Future<AcademicYearModel> updateAcademicYear({
    required String id,
    required String schoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required AccountStatus status,
  }) async {
    final cleanSchoolId = schoolId.trim();
    final cleanId = id.trim();

    final existing = await fetchAcademicYears(cleanSchoolId);
    validateAcademicYearInput(
      name: name,
      startDate: startDate,
      endDate: endDate,
      existingYears: existing,
      currentYearId: cleanId,
    );

    final startStr = _formatDateStr(startDate);
    final endStr = _formatDateStr(endDate);
    final statusStr = status == AccountStatus.inactive ? 'INACTIVE' : 'ACTIVE';

    if (_client != null && SupabaseConfig.isConfigured) {
      final updatePayload = <String, dynamic>{
        'name': name.trim(),
        'start_date': startStr,
        'end_date': endStr,
        'status': statusStr,
      };

      try {
        final res = await _client!
            .from('academic_years')
            .update(updatePayload)
            .eq('id', cleanId)
            .eq('school_id', cleanSchoolId)
            .select()
            .single();

        final updated = AcademicYearModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _cache.indexWhere((y) => y.id == cleanId);
        if (idx != -1) {
          _cache[idx] = updated;
        } else {
          _cache.insert(0, updated);
        }
        return updated;
      } catch (e) {
        debugPrint('[AcademicYearService updateAcademicYear DB note]: $e');
      }
    }

    // Local / fallback update
    final idx = _cache.indexWhere((y) => y.id == cleanId);
    final updated = AcademicYearModel(
      id: cleanId,
      schoolId: cleanSchoolId,
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      status: status,
      createdAt: idx != -1 ? _cache[idx].createdAt : DateTime.now(),
    );
    if (idx != -1) {
      _cache[idx] = updated;
    } else {
      _cache.insert(0, updated);
    }
    return updated;
  }

  /// Toggle status between ACTIVE and INACTIVE.
  Future<AcademicYearModel> toggleStatus({
    required String id,
    required String schoolId,
    required AccountStatus newStatus,
  }) async {
    final cleanSchoolId = schoolId.trim();
    final cleanId = id.trim();
    final statusStr = newStatus == AccountStatus.inactive ? 'INACTIVE' : 'ACTIVE';

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final res = await _client!
            .from('academic_years')
            .update({'status': statusStr})
            .eq('id', cleanId)
            .eq('school_id', cleanSchoolId)
            .select()
            .single();

        final updated = AcademicYearModel.fromJson(Map<String, dynamic>.from(res));
        final idx = _cache.indexWhere((y) => y.id == cleanId);
        if (idx != -1) _cache[idx] = updated;
        return updated;
      } catch (e) {
        debugPrint('[AcademicYearService toggleStatus DB note]: $e');
      }
    }

    final idx = _cache.indexWhere((y) => y.id == cleanId);
    if (idx != -1) {
      _cache[idx] = _cache[idx].copyWith(status: newStatus);
      return _cache[idx];
    }
    throw const AcademicYearValidationException('Academic year not found in cache.');
  }

  /// Inspect dependent database records referencing this academic year.
  Future<List<String>> checkDependentRecords({
    required String id,
    required String schoolId,
  }) async {
    final cleanId = id.trim();
    final cleanSchoolId = schoolId.trim();
    final List<String> reasons = [];

    if (_client == null || !SupabaseConfig.isConfigured) {
      return reasons;
    }

    try {
      // 1. Students
      final studentCount = await _client!
          .from('students')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('academic_year_id', cleanId);
      if (studentCount.isNotEmpty) {
        reasons.add('${studentCount.length} enrolled student(s)');
      }
    } catch (_) {}

    try {
      // 2. Classes
      final classCount = await _client!
          .from('classes')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('academic_year_id', cleanId);
      if (classCount.isNotEmpty) {
        reasons.add('${classCount.length} class(es)');
      }
    } catch (_) {}

    try {
      // 3. Attendance
      final attCount = await _client!
          .from('attendance')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('academic_year_id', cleanId);
      if (attCount.isNotEmpty) {
        reasons.add('${attCount.length} attendance record(s)');
      }
    } catch (_) {}

    try {
      // 4. Fee Structures
      final feeCount = await _client!
          .from('fee_structures')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('academic_year_id', cleanId);
      if (feeCount.isNotEmpty) {
        reasons.add('${feeCount.length} fee structure(s)');
      }
    } catch (_) {}

    try {
      // 5. Exams
      final examCount = await _client!
          .from('exams')
          .select('id')
          .eq('school_id', cleanSchoolId)
          .eq('academic_year_id', cleanId);
      if (examCount.isNotEmpty) {
        reasons.add('${examCount.length} exam(s)');
      }
    } catch (_) {}

    return reasons;
  }

  /// Delete an academic year only if it has NO dependent records.
  Future<void> deleteAcademicYear({
    required String id,
    required String schoolId,
  }) async {
    final cleanId = id.trim();
    final cleanSchoolId = schoolId.trim();

    final dependencies = await checkDependentRecords(id: cleanId, schoolId: cleanSchoolId);
    if (dependencies.isNotEmpty) {
      throw AcademicYearDependencyException(
        'Cannot delete academic year: It is referenced by ${dependencies.join(', ')}. '
        'Please mark the academic year as INACTIVE instead of deleting.',
        dependencies: dependencies,
      );
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!
            .from('academic_years')
            .delete()
            .eq('id', cleanId)
            .eq('school_id', cleanSchoolId);
      } catch (e) {
        debugPrint('[AcademicYearService deleteAcademicYear DB note]: $e');
      }
    }

    _cache.removeWhere((y) => y.id == cleanId);
  }

  static String _formatDateStr(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
