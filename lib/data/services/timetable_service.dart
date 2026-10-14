import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/timetable_model.dart';
import 'class_section_service.dart';
import 'academic_year_service.dart';

class TimetableConflictException implements Exception {
  final TimetableConflict conflict;
  const TimetableConflictException(this.conflict);

  @override
  String toString() => conflict.message;
}

class TimetableValidationException implements Exception {
  final String message;
  const TimetableValidationException(this.message);

  @override
  String toString() => message;
}

class TimetablePublishException implements Exception {
  final String message;
  final List<TimetableConflict> conflicts;
  const TimetablePublishException(this.message, {this.conflicts = const []});

  @override
  String toString() => message;
}

class TimetableService {
  final List<TimetableEntryModel> _cache = [];

  final SupabaseClient? _injectedClient;
  final ClassSectionService _classSectionService;
  final AcademicYearService _academicYearService;

  TimetableService({
    SupabaseClient? client,
    ClassSectionService? classSectionService,
    AcademicYearService? academicYearService,
  })  : _injectedClient = client,
        _classSectionService = classSectionService ?? ClassSectionService(),
        _academicYearService = academicYearService ?? AcademicYearService();

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  List<TimetableEntryModel> get cachedEntries => List.unmodifiable(_cache);

  /// Resolves non-UUID display identifiers (e.g. 'cls_1', 'sec_cls_1_A') to canonical database UUIDs.
  Future<TimetableEntryModel> resolveCanonicalEntry(TimetableEntryModel entry) async {
    String resolvedAcademicYearId = entry.academicYearId.trim();
    String? resolvedClassId = entry.classId?.trim();
    String? resolvedSectionId = entry.sectionId?.trim();
    String? resolvedClassName = entry.className;
    String? resolvedSectionName = entry.sectionName;
    String? resolvedClassCode = entry.classDisplayCode;
    String? resolvedSectionCode = entry.sectionDisplayCode;

    // 1. Resolve Academic Year
    if (resolvedAcademicYearId.isEmpty || !TimetableEntryModel.isValidUuid(resolvedAcademicYearId)) {
      if (entry.schoolId == ClassSectionService.kpsSchoolId) {
        resolvedAcademicYearId = ClassSectionService.kpsAcademicYearId;
      } else {
        try {
          final years = await _academicYearService.fetchAcademicYears(entry.schoolId);
          final current = years.where((y) => y.isCurrent).firstOrNull ?? years.firstOrNull;
          if (current != null && TimetableEntryModel.isValidUuid(current.id)) {
            resolvedAcademicYearId = current.id;
          }
        } catch (_) {}
      }
    }

    // 2. Resolve Class
    if (resolvedClassId != null && resolvedClassId.isNotEmpty) {
      if (!TimetableEntryModel.isValidUuid(resolvedClassId)) {
        try {
          final resolvedClass = await _classSectionService.resolveClass(
            schoolId: entry.schoolId,
            classIdentifier: resolvedClassId,
            academicYearId: resolvedAcademicYearId,
          );
          if (resolvedClass != null) {
            resolvedClassId = resolvedClass.id;
            resolvedClassName = resolvedClass.name;
            resolvedClassCode = resolvedClass.displayCode;
          }
        } catch (_) {}
      }
    }

    // 3. Resolve Section
    if (resolvedSectionId != null && resolvedSectionId.isNotEmpty && resolvedClassId != null) {
      if (!TimetableEntryModel.isValidUuid(resolvedSectionId)) {
        try {
          final resolvedSection = await _classSectionService.resolveSection(
            schoolId: entry.schoolId,
            classId: resolvedClassId,
            sectionIdentifier: resolvedSectionId,
          );
          if (resolvedSection != null) {
            resolvedSectionId = resolvedSection.id;
            resolvedSectionName = resolvedSection.name;
            resolvedSectionCode = resolvedSection.displayCode;
          }
        } catch (_) {}
      }
    }

    return entry.copyWith(
      academicYearId: resolvedAcademicYearId,
      classId: resolvedClassId,
      sectionId: resolvedSectionId,
      className: resolvedClassName,
      sectionName: resolvedSectionName,
      classDisplayCode: resolvedClassCode,
      sectionDisplayCode: resolvedSectionCode,
    );
  }

  // --- CONFLICT DETECTION ENGINE ---

  /// Validates an attempted [entry] against [existingEntries].
  /// Returns null if valid, or a [TimetableConflict] if collision detected.
  TimetableConflict? detectConflict({
    required TimetableEntryModel entry,
    required List<TimetableEntryModel> existingEntries,
    String? excludeEntryId,
  }) {
    // 0. Cross-tenant isolation check
    for (final e in existingEntries) {
      if (e.schoolId.isNotEmpty && entry.schoolId.isNotEmpty && e.schoolId != entry.schoolId) {
        return TimetableConflict(
          type: TimetableConflictType.schoolMismatch,
          message: 'Cross-tenant violation: attempted entry belongs to school ${entry.schoolId} but comparison entry belongs to school ${e.schoolId}.',
          attemptedEntry: entry,
          conflictingEntry: e,
        );
      }
    }

    // 1. Time range validation: start required, end required, end > start
    if (entry.startTime.trim().isEmpty || entry.endTime.trim().isEmpty) {
      return TimetableConflict(
        type: TimetableConflictType.invalidTimeRange,
        message: 'Start time and end time are required.',
        attemptedEntry: entry,
      );
    }

    if (entry.endMinutes <= entry.startMinutes) {
      return TimetableConflict(
        type: TimetableConflictType.invalidTimeRange,
        message: 'End time (${entry.endTime}) must be strictly after start time (${entry.startTime}).',
        attemptedEntry: entry,
      );
    }

    // 2. Candidate pool for collision checks
    final activeExisting = existingEntries.where((e) {
      if (excludeEntryId != null && e.id == excludeEntryId) return false;
      if (e.id == entry.id && entry.id.isNotEmpty) return false;
      if (e.isCancelled) return false; // Cancelled entries do not cause conflict
      if (e.schoolId != entry.schoolId) return false; // Multi-tenant isolation
      if (e.dayOfWeek != entry.dayOfWeek) return false; // Same day only
      return true;
    }).toList();

    for (final existing in activeExisting) {
      if (!entry.overlapsWith(existing)) continue;

      // A. CLASS CONFLICT: Same class & section overlapping time
      final isSameClass = (entry.classId != null && existing.classId != null && entry.classId == existing.classId) ||
          (entry.classDisplayCode != null && existing.classDisplayCode != null && entry.classDisplayCode == existing.classDisplayCode) ||
          (entry.classId != null && existing.classDisplayCode != null && entry.classId!.replaceAll('_', '') == existing.classDisplayCode!.replaceAll('_', '')) ||
          (entry.classDisplayCode != null && existing.classId != null && entry.classDisplayCode!.replaceAll('_', '') == existing.classId!.replaceAll('_', ''));

      final isSameSection = (entry.sectionId == null && existing.sectionId == null) ||
          (entry.sectionId != null && existing.sectionId != null && entry.sectionId == existing.sectionId) ||
          (entry.sectionDisplayCode != null && existing.sectionDisplayCode != null && entry.sectionDisplayCode == existing.sectionDisplayCode) ||
          (entry.sectionId != null && existing.sectionDisplayCode != null && entry.sectionId!.replaceAll('_', '') == existing.sectionDisplayCode!.replaceAll('_', ''));

      // Also compare normalized class/section names
      final cleanEntryClassName = entry.className?.trim().toLowerCase() ??
          (entry.classId != null ? 'class ${entry.classId!.replaceAll(RegExp(r'\D'), '')}' : '');
      final cleanExistingClassName = existing.className?.trim().toLowerCase() ??
          (existing.classId != null ? 'class ${existing.classId!.replaceAll(RegExp(r'\D'), '')}' : '');

      final cleanEntrySec = entry.sectionName?.trim().toUpperCase() ??
          (entry.sectionId != null ? entry.sectionId!.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '') : '');
      final cleanExistingSec = existing.sectionName?.trim().toUpperCase() ??
          (existing.sectionId != null ? existing.sectionId!.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '') : '');

      final lastSecEntry = cleanEntrySec.isNotEmpty ? cleanEntrySec.substring(cleanEntrySec.length - 1) : '';
      final lastSecExisting = cleanExistingSec.isNotEmpty ? cleanExistingSec.substring(cleanExistingSec.length - 1) : '';

      final isClassNameMatch = cleanEntryClassName.isNotEmpty && cleanExistingClassName.isNotEmpty && cleanEntryClassName == cleanExistingClassName;
      final isSectionMatch = (lastSecEntry.isEmpty && lastSecExisting.isEmpty) ||
          (lastSecEntry.isNotEmpty && lastSecExisting.isNotEmpty && lastSecEntry == lastSecExisting);

      if ((isSameClass && isSameSection) || (isClassNameMatch && isSectionMatch)) {
        final rawClassName = entry.className ?? existing.className ?? '';
        final classPrefix = rawClassName.toLowerCase().startsWith('class') ? '' : 'Class ';
        final displayClassName = '$classPrefix$rawClassName'.trim();
        final displaySecName = entry.sectionName ?? existing.sectionName ?? '';
        return TimetableConflict(
          type: TimetableConflictType.classOverlap,
          message: '$displayClassName $displaySecName already has a period scheduled on ${entry.dayName} from ${existing.timeRangeFormatted} (${existing.subjectName}).',
          attemptedEntry: entry,
          conflictingEntry: existing,
        );
      }

      // B. TEACHER CONFLICT: Same teacher overlapping time, EVEN IF DIFFERENT CLASSES
      final hasTeacherId = entry.teacherProfileId != null &&
          entry.teacherProfileId!.isNotEmpty &&
          existing.teacherProfileId != null &&
          existing.teacherProfileId!.isNotEmpty;
      final isSameTeacherId = hasTeacherId && entry.teacherProfileId == existing.teacherProfileId;

      final hasTeacherName = entry.teacherName != null &&
          entry.teacherName!.trim().isNotEmpty &&
          existing.teacherName != null &&
          existing.teacherName!.trim().isNotEmpty;
      final isSameTeacherName = hasTeacherName &&
          entry.teacherName!.trim().toLowerCase() == existing.teacherName!.trim().toLowerCase();

      if (isSameTeacherId || isSameTeacherName) {
        final tName = entry.teacherName ?? existing.teacherName ?? 'Teacher';
        return TimetableConflict(
          type: TimetableConflictType.teacherOverlap,
          message: '$tName is already teaching ${existing.subjectName} in Class ${existing.className ?? ''} on ${entry.dayName} from ${existing.timeRangeFormatted}.',
          attemptedEntry: entry,
          conflictingEntry: existing,
        );
      }

      // C. ROOM CONFLICT: If room provided, same room overlapping time
      final hasRoomA = entry.room != null && entry.room!.trim().isNotEmpty;
      final hasRoomB = existing.room != null && existing.room!.trim().isNotEmpty;

      if (hasRoomA && hasRoomB) {
        final isSameRoom = entry.room!.trim().toLowerCase() == existing.room!.trim().toLowerCase();
        if (isSameRoom) {
          return TimetableConflict(
            type: TimetableConflictType.roomOverlap,
            message: 'Room "${entry.room!.trim()}" is already occupied on ${entry.dayName} from ${existing.timeRangeFormatted} by Class ${existing.className ?? ''} (${existing.subjectName}).',
            attemptedEntry: entry,
            conflictingEntry: existing,
          );
        }
      }
    }

    return null;
  }

  // --- CRUD OPERATIONS ---

  /// Fetch timetable entries with optional filtering directly from Supabase.
  Future<List<TimetableEntryModel>> fetchTimetableEntries({
    required String schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? teacherId,
    int? dayOfWeek,
    TimetableStatus? status,
  }) async {
    final cleanSchoolId = schoolId.trim();
    if (cleanSchoolId.isEmpty) return [];

    String? effectiveAy = academicYearId?.trim();
    if (effectiveAy != null && effectiveAy.isNotEmpty && !TimetableEntryModel.isValidUuid(effectiveAy)) {
      if (cleanSchoolId == ClassSectionService.kpsSchoolId) {
        effectiveAy = ClassSectionService.kpsAcademicYearId;
      }
    }

    String? effectiveClassId = classId?.trim();
    if (effectiveClassId != null && effectiveClassId.isNotEmpty && !TimetableEntryModel.isValidUuid(effectiveClassId)) {
      try {
        final resolved = await _classSectionService.resolveClass(
          schoolId: cleanSchoolId,
          classIdentifier: effectiveClassId,
          academicYearId: effectiveAy,
        );
        if (resolved != null && TimetableEntryModel.isValidUuid(resolved.id)) {
          effectiveClassId = resolved.id;
        }
      } catch (_) {}
    }

    String? effectiveSectionId = sectionId?.trim();
    if (effectiveSectionId != null && effectiveSectionId.isNotEmpty && !TimetableEntryModel.isValidUuid(effectiveSectionId)) {
      if (effectiveClassId != null) {
        try {
          final resolved = await _classSectionService.resolveSection(
            schoolId: cleanSchoolId,
            classId: effectiveClassId,
            sectionIdentifier: effectiveSectionId,
          );
          if (resolved != null && TimetableEntryModel.isValidUuid(resolved.id)) {
            effectiveSectionId = resolved.id;
          }
        } catch (_) {}
      }
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      var query = _client!
          .from('timetable_entries')
          .select()
          .eq('school_id', cleanSchoolId);

      if (effectiveAy != null && effectiveAy.isNotEmpty && TimetableEntryModel.isValidUuid(effectiveAy)) {
        query = query.eq('academic_year_id', effectiveAy);
      }
      if (effectiveClassId != null && effectiveClassId.isNotEmpty && TimetableEntryModel.isValidUuid(effectiveClassId)) {
        query = query.eq('class_id', effectiveClassId);
      }
      if (effectiveSectionId != null && effectiveSectionId.isNotEmpty && TimetableEntryModel.isValidUuid(effectiveSectionId)) {
        query = query.eq('section_id', effectiveSectionId);
      }
      if (teacherId != null && teacherId.isNotEmpty && TimetableEntryModel.isValidUuid(teacherId)) {
        query = query.eq('teacher_profile_id', teacherId);
      }
      if (dayOfWeek != null) {
        query = query.eq('day_of_week', dayOfWeek);
      }
      if (status != null) {
        query = query.eq('status', status.displayName);
      }

      final res = await query
          .order('day_of_week', ascending: true)
          .order('start_time', ascending: true);

      final list = (res as List)
          .map((r) => TimetableEntryModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      // Update cache for this scope
      _cache.removeWhere((e) =>
          e.schoolId == cleanSchoolId &&
          (effectiveAy == null || e.academicYearId == effectiveAy) &&
          (effectiveClassId == null || e.classId == effectiveClassId) &&
          (effectiveSectionId == null || e.sectionId == effectiveSectionId));
      _cache.addAll(list);

      return list;
    }

    // Only in non-Supabase offline testing environments
    return _cache.where((e) {
      if (e.schoolId != cleanSchoolId) return false;
      if (effectiveAy != null && effectiveAy.isNotEmpty && e.academicYearId != effectiveAy && e.academicYearId != academicYearId) return false;
      if (effectiveClassId != null && effectiveClassId.isNotEmpty && e.classId != effectiveClassId && e.classId != classId) return false;
      if (effectiveSectionId != null && effectiveSectionId.isNotEmpty && e.sectionId != effectiveSectionId && e.sectionId != sectionId) return false;
      if (teacherId != null && teacherId.isNotEmpty && e.teacherProfileId != teacherId) return false;
      if (dayOfWeek != null && e.dayOfWeek != dayOfWeek) return false;
      if (status != null && e.status != status) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayCmp != 0) return dayCmp;
        return a.startMinutes.compareTo(b.startMinutes);
      });
  }

  /// Read-only method for Teacher App to fetch strictly PUBLISHED timetable entries
  /// for the authenticated teacher within their authorized school.
  Future<List<TimetableEntryModel>> fetchTeacherPublishedTimetable({
    required String schoolId,
    required String teacherProfileId,
    String? teacherName,
    String? academicYearId,
  }) async {
    final cleanSchoolId = schoolId.trim();
    final cleanTeacherId = teacherProfileId.trim();
    if (cleanSchoolId.isEmpty || cleanTeacherId.isEmpty) return [];

    if (_client != null && SupabaseConfig.isConfigured && TimetableEntryModel.isValidUuid(cleanTeacherId)) {
      var query = _client!
          .from('timetable_entries')
          .select()
          .eq('school_id', cleanSchoolId)
          .eq('teacher_profile_id', cleanTeacherId)
          .eq('status', TimetableStatus.published.displayName);

      if (academicYearId != null && academicYearId.isNotEmpty && TimetableEntryModel.isValidUuid(academicYearId)) {
        query = query.eq('academic_year_id', academicYearId);
      }

      final res = await query
          .order('day_of_week', ascending: true)
          .order('start_time', ascending: true);

      final list = (res as List)
          .map((r) => TimetableEntryModel.fromJson(Map<String, dynamic>.from(r)))
          .where((e) => e.isPublished && !e.isCancelled)
          .toList();

      return list;
    }

    // Only in non-Supabase offline testing environments
    return _cache.where((e) {
      if (e.schoolId != cleanSchoolId) return false;
      if (!e.isPublished || e.isCancelled) return false;
      final isTeacherMatch = (e.teacherProfileId == cleanTeacherId) ||
          (teacherName != null && teacherName.isNotEmpty && e.teacherName?.toLowerCase() == teacherName.toLowerCase());
      if (!isTeacherMatch) return false;
      if (academicYearId != null && academicYearId.isNotEmpty && e.academicYearId != academicYearId) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (dayCmp != 0) return dayCmp;
        return a.startMinutes.compareTo(b.startMinutes);
      });
  }

  /// Create a new timetable entry with pre-insert conflict validation.
  Future<TimetableEntryModel> createEntry(TimetableEntryModel entry) async {
    if (entry.schoolId.trim().isEmpty) {
      throw const TimetableValidationException('School ID is required.');
    }
    if (entry.subjectName.trim().isEmpty) {
      throw const TimetableValidationException('Subject name cannot be empty.');
    }

    // Resolve class, section, and academic year to canonical database UUIDs
    final resolved = await resolveCanonicalEntry(entry);

    if (resolved.academicYearId.trim().isEmpty) {
      throw const TimetableValidationException('Academic Year ID is required.');
    }

    // 1. Fetch existing entries for collision checks (all entries of the school/academic year)
    final existing = await fetchTimetableEntries(
      schoolId: resolved.schoolId,
      academicYearId: resolved.academicYearId,
    );

    // 2. Validate conflicts
    final conflict = detectConflict(entry: resolved, existingEntries: existing);
    if (conflict != null) {
      throw TimetableConflictException(conflict);
    }

    // 3. Persist to Supabase if connected
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        if (resolved.classId != null && resolved.classId!.isNotEmpty && !TimetableEntryModel.isValidUuid(resolved.classId)) {
          throw TimetableValidationException('Cannot save period: Class identifier "${resolved.classId}" is not a valid UUID.');
        }
        if (resolved.sectionId != null && resolved.sectionId!.isNotEmpty && !TimetableEntryModel.isValidUuid(resolved.sectionId)) {
          throw TimetableValidationException('Cannot save period: Section identifier "${resolved.sectionId}" is not a valid UUID.');
        }

        final payload = resolved.toSupabaseMap(requireValidUuid: true);
        final res = await _client!.from('timetable_entries').insert(payload).select().single();
        final created = TimetableEntryModel.fromJson(Map<String, dynamic>.from(res)).copyWith(
          className: resolved.className,
          sectionName: resolved.sectionName,
          teacherName: resolved.teacherName,
          classDisplayCode: resolved.classDisplayCode,
          sectionDisplayCode: resolved.sectionDisplayCode,
        );
        _cache.add(created);
        return created;
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('violates') && msg.contains('policy')) {
          throw const TimetableValidationException('Permission denied by database security policies.');
        }
        if (msg.contains('chk_timetable_time_range')) {
          throw const TimetableValidationException('End time must be strictly after start time.');
        }
        if (msg.contains('integrity violation')) {
          throw TimetableValidationException(e.message);
        }
        rethrow;
      }
    }

    // Only in non-Supabase offline testing environments
    final fallbackId = resolved.id.isNotEmpty ? resolved.id : 'slot_${DateTime.now().millisecondsSinceEpoch}';
    final created = resolved.copyWith(
      id: fallbackId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _cache.add(created);
    return created;
  }

  /// Edit an existing timetable entry.
  Future<TimetableEntryModel> updateEntry(
    TimetableEntryModel entry, {
    bool forcePublishedUpdate = false,
  }) async {
    if (entry.id.trim().isEmpty) {
      throw const TimetableValidationException('Entry ID is required for update.');
    }

    // Resolve class, section, and academic year to canonical database UUIDs
    final resolved = await resolveCanonicalEntry(entry);

    // 1. Fetch existing entries for collision detection
    final existing = await fetchTimetableEntries(
      schoolId: resolved.schoolId,
      academicYearId: resolved.academicYearId,
    );

    // 2. Validate conflicts (excluding this entry ID)
    final conflict = detectConflict(
      entry: resolved,
      existingEntries: existing,
      excludeEntryId: resolved.id,
    );
    if (conflict != null) {
      throw TimetableConflictException(conflict);
    }

    // 3. Persist to Supabase
    if (_client != null && SupabaseConfig.isConfigured && TimetableEntryModel.isValidUuid(resolved.id)) {
      try {
        final payload = resolved.toSupabaseMap(requireValidUuid: true);
        payload['updated_at'] = DateTime.now().toIso8601String();
        final res = await _client!
            .from('timetable_entries')
            .update(payload)
            .eq('id', resolved.id)
            .select()
            .single();

        final updated = TimetableEntryModel.fromJson(Map<String, dynamic>.from(res)).copyWith(
          className: resolved.className,
          sectionName: resolved.sectionName,
          teacherName: resolved.teacherName,
          classDisplayCode: resolved.classDisplayCode,
          sectionDisplayCode: resolved.sectionDisplayCode,
        );

        final idx = _cache.indexWhere((e) => e.id == resolved.id);
        if (idx != -1) {
          _cache[idx] = updated;
        } else {
          _cache.add(updated);
        }
        return updated;
      } on PostgrestException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('violates') && msg.contains('policy')) {
          throw const TimetableValidationException('Permission denied by database security policies.');
        }
        if (msg.contains('chk_timetable_time_range')) {
          throw const TimetableValidationException('End time must be strictly after start time.');
        }
        if (msg.contains('integrity violation')) {
          throw TimetableValidationException(e.message);
        }
        rethrow;
      }
    }

    // Only in non-Supabase offline testing environments
    final updated = resolved.copyWith(updatedAt: DateTime.now());
    final idx = _cache.indexWhere((e) => e.id == resolved.id);
    if (idx != -1) {
      _cache[idx] = updated;
    } else {
      _cache.add(updated);
    }
    return updated;
  }

  /// Delete or cancel an existing timetable entry.
  /// If [softCancelIfPublished] is true and status is PUBLISHED, transitions to CANCELLED.
  Future<void> deleteEntry(
    String entryId, {
    bool softCancelIfPublished = true,
  }) async {
    final cleanId = entryId.trim();
    if (cleanId.isEmpty) return;

    if (_client != null && SupabaseConfig.isConfigured && TimetableEntryModel.isValidUuid(cleanId)) {
      // 1. Fetch current status from Supabase
      final currentRes = await _client!
          .from('timetable_entries')
          .select('status')
          .eq('id', cleanId)
          .maybeSingle();

      final currentStatus = currentRes?['status']?.toString();
      final isPublished = currentStatus == 'PUBLISHED';
      final shouldSoftCancel = softCancelIfPublished && isPublished;

      if (shouldSoftCancel) {
        await _client!
            .from('timetable_entries')
            .update({'status': 'CANCELLED', 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', cleanId);
      } else {
        await _client!.from('timetable_entries').delete().eq('id', cleanId);
      }

      if (shouldSoftCancel) {
        final idx = _cache.indexWhere((e) => e.id == cleanId);
        if (idx != -1) {
          _cache[idx] = _cache[idx].copyWith(
            status: TimetableStatus.cancelled,
            updatedAt: DateTime.now(),
          );
        }
      } else {
        _cache.removeWhere((e) => e.id == cleanId);
      }
      return;
    }

    // Only in non-Supabase offline testing environments
    final target = _cache.firstWhere(
      (e) => e.id == cleanId,
      orElse: () => TimetableEntryModel(
        id: cleanId,
        schoolId: '',
        academicYearId: '',
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: '',
      ),
    );

    final shouldSoftCancel = softCancelIfPublished && target.isPublished;
    if (shouldSoftCancel) {
      final idx = _cache.indexWhere((e) => e.id == cleanId);
      if (idx != -1) {
        _cache[idx] = _cache[idx].copyWith(
          status: TimetableStatus.cancelled,
          updatedAt: DateTime.now(),
        );
      }
    } else {
      _cache.removeWhere((e) => e.id == cleanId);
    }
  }

  // --- PUBLISH / UNPUBLISH LIFECYCLE ---

  /// Validates all entries for a class/section and publishes if 0 conflicts exist.
  Future<int> publishTimetable({
    required String schoolId,
    required String academicYearId,
    required String classId,
    String? sectionId,
  }) async {
    String effectiveAy = academicYearId.trim();
    if (!TimetableEntryModel.isValidUuid(effectiveAy) && schoolId == ClassSectionService.kpsSchoolId) {
      effectiveAy = ClassSectionService.kpsAcademicYearId;
    }

    String effectiveClassId = classId.trim();
    if (!TimetableEntryModel.isValidUuid(effectiveClassId)) {
      final resolved = await _classSectionService.resolveClass(
        schoolId: schoolId,
        classIdentifier: effectiveClassId,
        academicYearId: effectiveAy,
      );
      if (resolved != null) effectiveClassId = resolved.id;
    }

    String? effectiveSectionId = sectionId?.trim();
    if (effectiveSectionId != null && effectiveSectionId.isNotEmpty && !TimetableEntryModel.isValidUuid(effectiveSectionId)) {
      final resolved = await _classSectionService.resolveSection(
        schoolId: schoolId,
        classId: effectiveClassId,
        sectionIdentifier: effectiveSectionId,
      );
      if (resolved != null) effectiveSectionId = resolved.id;
    }

    // 1. Fetch all entries for this class/section
    final classEntries = await fetchTimetableEntries(
      schoolId: schoolId,
      academicYearId: effectiveAy,
      classId: effectiveClassId,
      sectionId: effectiveSectionId,
    );

    final nonCancelled = classEntries.where((e) => !e.isCancelled).toList();
    if (nonCancelled.isEmpty) {
      throw const TimetableValidationException('Cannot publish an empty timetable. Please add periods first.');
    }

    // 2. Fetch all school entries for complete cross-class conflict check
    final allSchoolEntries = await fetchTimetableEntries(
      schoolId: schoolId,
      academicYearId: effectiveAy,
    );

    // 3. Detect any conflicts across every entry
    final conflicts = <TimetableConflict>[];
    for (final entry in nonCancelled) {
      final c = detectConflict(
        entry: entry,
        existingEntries: allSchoolEntries,
        excludeEntryId: entry.id,
      );
      if (c != null) {
        conflicts.add(c);
      }
    }

    if (conflicts.isNotEmpty) {
      throw TimetablePublishException(
        'Publishing failed: ${conflicts.length} conflict(s) detected.',
        conflicts: conflicts,
      );
    }

    // 4. Update status to PUBLISHED in DB
    if (_client != null && SupabaseConfig.isConfigured) {
      var updateQuery = _client!
          .from('timetable_entries')
          .update({
            'status': 'PUBLISHED',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('school_id', schoolId)
          .neq('status', 'CANCELLED');

      if (TimetableEntryModel.isValidUuid(effectiveAy)) {
        updateQuery = updateQuery.eq('academic_year_id', effectiveAy);
      }
      if (TimetableEntryModel.isValidUuid(effectiveClassId)) {
        updateQuery = updateQuery.eq('class_id', effectiveClassId);
      }
      if (effectiveSectionId != null && effectiveSectionId.isNotEmpty && TimetableEntryModel.isValidUuid(effectiveSectionId)) {
        updateQuery = updateQuery.eq('section_id', effectiveSectionId);
      }

      final res = await updateQuery.select();
      final publishedCount = (res as List).length;

      // Update in cache
      for (int i = 0; i < _cache.length; i++) {
        final e = _cache[i];
        if (e.schoolId == schoolId &&
            (e.academicYearId == effectiveAy || e.academicYearId == academicYearId) &&
            (e.classId == effectiveClassId || e.classId == classId) &&
            (effectiveSectionId == null || effectiveSectionId.isEmpty || e.sectionId == effectiveSectionId || e.sectionId == sectionId) &&
            !e.isCancelled) {
          _cache[i] = e.copyWith(status: TimetableStatus.published, updatedAt: DateTime.now());
        }
      }

      return publishedCount;
    }

    // Only in non-Supabase offline testing environments
    int count = 0;
    for (int i = 0; i < _cache.length; i++) {
      final e = _cache[i];
      if (e.schoolId == schoolId &&
          (e.academicYearId == effectiveAy || e.academicYearId == academicYearId) &&
          (e.classId == effectiveClassId || e.classId == classId) &&
          (effectiveSectionId == null || effectiveSectionId.isEmpty || e.sectionId == effectiveSectionId || e.sectionId == sectionId) &&
          !e.isCancelled) {
        _cache[i] = e.copyWith(status: TimetableStatus.published, updatedAt: DateTime.now());
        count++;
      }
    }

    return count;
  }

  /// Revert a published timetable back to DRAFT.
  Future<int> unpublishTimetable({
    required String schoolId,
    required String academicYearId,
    required String classId,
    String? sectionId,
  }) async {
    String effectiveAy = academicYearId.trim();
    if (!TimetableEntryModel.isValidUuid(effectiveAy) && schoolId == ClassSectionService.kpsSchoolId) {
      effectiveAy = ClassSectionService.kpsAcademicYearId;
    }

    String effectiveClassId = classId.trim();
    if (!TimetableEntryModel.isValidUuid(effectiveClassId)) {
      final resolved = await _classSectionService.resolveClass(
        schoolId: schoolId,
        classIdentifier: effectiveClassId,
        academicYearId: effectiveAy,
      );
      if (resolved != null) effectiveClassId = resolved.id;
    }

    String? effectiveSectionId = sectionId?.trim();
    if (effectiveSectionId != null && effectiveSectionId.isNotEmpty && !TimetableEntryModel.isValidUuid(effectiveSectionId)) {
      final resolved = await _classSectionService.resolveSection(
        schoolId: schoolId,
        classId: effectiveClassId,
        sectionIdentifier: effectiveSectionId,
      );
      if (resolved != null) effectiveSectionId = resolved.id;
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      var updateQuery = _client!
          .from('timetable_entries')
          .update({
            'status': 'DRAFT',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('school_id', schoolId)
          .eq('status', 'PUBLISHED');

      if (TimetableEntryModel.isValidUuid(effectiveAy)) {
        updateQuery = updateQuery.eq('academic_year_id', effectiveAy);
      }
      if (TimetableEntryModel.isValidUuid(effectiveClassId)) {
        updateQuery = updateQuery.eq('class_id', effectiveClassId);
      }
      if (effectiveSectionId != null && effectiveSectionId.isNotEmpty && TimetableEntryModel.isValidUuid(effectiveSectionId)) {
        updateQuery = updateQuery.eq('section_id', effectiveSectionId);
      }

      final res = await updateQuery.select();
      final revertedCount = (res as List).length;

      for (int i = 0; i < _cache.length; i++) {
        final e = _cache[i];
        if (e.schoolId == schoolId &&
            (e.academicYearId == effectiveAy || e.academicYearId == academicYearId) &&
            (e.classId == effectiveClassId || e.classId == classId) &&
            (effectiveSectionId == null || effectiveSectionId.isEmpty || e.sectionId == effectiveSectionId || e.sectionId == sectionId) &&
            e.isPublished) {
          _cache[i] = e.copyWith(status: TimetableStatus.draft, updatedAt: DateTime.now());
        }
      }

      return revertedCount;
    }

    // Only in non-Supabase offline testing environments
    int revertedCount = 0;
    for (int i = 0; i < _cache.length; i++) {
      final e = _cache[i];
      if (e.schoolId == schoolId &&
          (e.academicYearId == effectiveAy || e.academicYearId == academicYearId) &&
          (e.classId == effectiveClassId || e.classId == classId) &&
          (effectiveSectionId == null || effectiveSectionId.isEmpty || e.sectionId == effectiveSectionId || e.sectionId == sectionId) &&
          e.isPublished) {
        _cache[i] = e.copyWith(status: TimetableStatus.draft, updatedAt: DateTime.now());
        revertedCount++;
      }
    }

    return revertedCount;
  }

  // --- DUPLICATE / COPY TOOLS ---

  /// Duplicates all periods from [sourceDay] to [targetDay] for a class/section.
  Future<List<TimetableEntryModel>> duplicateDay({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required int sourceDay,
    required int targetDay,
    String? className,
    String? sectionName,
  }) async {
    if (sourceDay == targetDay) {
      throw const TimetableValidationException('Source and target day cannot be the same.');
    }

    // 1. Fetch source periods
    final sourceEntries = await fetchTimetableEntries(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      dayOfWeek: sourceDay,
      status: TimetableStatus.draft,
    );

    final allClassEntries = await fetchTimetableEntries(
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      dayOfWeek: sourceDay,
    );
    final activeSource = (sourceEntries.isNotEmpty ? sourceEntries : allClassEntries)
        .where((e) => !e.isCancelled)
        .toList();

    if (activeSource.isEmpty) {
      throw const TimetableValidationException('No active periods found on the source day to duplicate.');
    }

    // 2. Fetch all school entries on the target day for conflict verification
    final allSchoolTargetEntries = await fetchTimetableEntries(
      schoolId: schoolId,
      academicYearId: academicYearId,
      dayOfWeek: targetDay,
    );

    // 3. Prepare candidate entries and check conflicts
    final candidates = <TimetableEntryModel>[];
    for (final src in activeSource) {
      final candidate = src.copyWith(
        id: '', // Will be generated
        dayOfWeek: targetDay,
        status: TimetableStatus.draft,
        className: className ?? src.className,
        sectionName: sectionName ?? src.sectionName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final conflict = detectConflict(
        entry: candidate,
        existingEntries: allSchoolTargetEntries,
      );

      if (conflict != null) {
        throw TimetableConflictException(conflict);
      }
      candidates.add(candidate);
    }

    // 4. Save candidates
    final createdList = <TimetableEntryModel>[];
    for (final cand in candidates) {
      final created = await createEntry(cand);
      createdList.add(created);
    }

    return createdList;
  }
}
