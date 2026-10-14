import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/academic_models.dart';
import '../models/user_model.dart';
import '../models/staff_model.dart';
import '../../core/config/supabase_config.dart';

class TeacherService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  final List<TeacherModel> _teachers = [];
  final List<SubjectModel> _mockSubjects = [];
  final List<TeacherAssignmentModel> _mockAssignments = [];

  String _cacheKey(String? schoolId) {
    if (schoolId != null && schoolId.trim().isNotEmpty) {
      return 'cached_teachers_data_${schoolId.trim()}';
    }
    return 'cached_teachers_data';
  }

  Future<void> _persistTeachersCache([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetSchoolId = schoolId?.trim();
      final toSave = (targetSchoolId != null && targetSchoolId.isNotEmpty)
          ? _teachers.where((t) => t.schoolId == targetSchoolId).toList()
          : _teachers;
      final jsonList = toSave.map((t) => t.toJson()).toList();
      await prefs.setString(_cacheKey(targetSchoolId), jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[TeacherService Cache Save Warning]: $e');
    }
  }

  Future<void> _restoreTeachersCache([String? schoolId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final targetSchoolId = schoolId?.trim();
      final cachedStr = prefs.getString(_cacheKey(targetSchoolId));
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final model = TeacherModel.fromJson(item);
              if (targetSchoolId == null || targetSchoolId.isEmpty || model.schoolId == targetSchoolId) {
                if (!_teachers.any((t) => t.id == model.id || (model.authUserId != null && t.authUserId == model.authUserId) || t.employeeId == model.employeeId)) {
                  _teachers.add(model);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TeacherService Cache Restore Warning]: $e');
    }
  }

  static const String kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';

  static final List<TeacherModel> _kpsBaselineTeachers = [
    // Class 1
    const TeacherModel(
      id: '9e90f5ec-0cf3-4615-b358-75a6357c6424',
      authUserId: 'c0448877-9f37-4c2d-b1f2-3de38a9e63df',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0101',
      name: 'Test Teacher Class 1A',
      email: 'test.teacher.1a@school-test.local',
      subjects: ['English', 'Mathematics'],
      assignedClass: 'Class 1',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990101A',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: '2db09867-1fd8-4027-a56e-82d7c6ca6443',
      authUserId: '2db09867-1fd8-4027-a56e-82d7c6ca6443',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0102',
      name: 'Test Teacher Class 1B',
      email: 'test.teacher.1b@school-test.local',
      subjects: ['Hindi', 'EVS'],
      assignedClass: 'Class 1',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990101B',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 2
    const TeacherModel(
      id: 'f6cc4468-18cc-42a6-b84a-2a82387a0d90',
      authUserId: 'f6cc4468-18cc-42a6-b84a-2a82387a0d90',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0201',
      name: 'Test Teacher Class 2A',
      email: 'test.teacher.2a@school-test.local',
      subjects: ['English', 'Mathematics'],
      assignedClass: 'Class 2',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990201A',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: '44927d31-2095-4a01-9689-c1a15bd9d6a3',
      authUserId: '44927d31-2095-4a01-9689-c1a15bd9d6a3',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0202',
      name: 'Test Teacher Class 2B',
      email: 'test.teacher.2b@school-test.local',
      subjects: ['Hindi', 'Mathematics'],
      assignedClass: 'Class 2',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990201B',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 3
    const TeacherModel(
      id: 'd392ecde-b3ce-4782-bbfc-237985215925',
      authUserId: 'd392ecde-b3ce-4782-bbfc-237985215925',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0301',
      name: 'Test Teacher Class 3A',
      email: 'test.teacher.3a@school-test.local',
      subjects: ['Science', 'English'],
      assignedClass: 'Class 3',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990301A',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: '1d971c34-88ac-40fe-951d-8480847374ef',
      authUserId: '1d971c34-88ac-40fe-951d-8480847374ef',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0302',
      name: 'Test Teacher Class 3B',
      email: 'test.teacher.3b@school-test.local',
      subjects: ['Social Science', 'Hindi'],
      assignedClass: 'Class 3',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990301B',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 4
    const TeacherModel(
      id: 'a88bb137-c58f-4b99-92b5-dea80babae0e',
      authUserId: 'a88bb137-c58f-4b99-92b5-dea80babae0e',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0401',
      name: 'Test Teacher Class 4A',
      email: 'test.teacher.4a@school-test.local',
      subjects: ['Mathematics', 'Science'],
      assignedClass: 'Class 4',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990401A',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'e3ce86ca-e3ab-49d0-8bd9-85a835f98721',
      authUserId: 'e3ce86ca-e3ab-49d0-8bd9-85a835f98721',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0402',
      name: 'Test Teacher Class 4B',
      email: 'test.teacher.4b@school-test.local',
      subjects: ['English', 'Computer Science'],
      assignedClass: 'Class 4',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990401B',
      designation: 'Primary Educator',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 5
    const TeacherModel(
      id: '5534b32c-dd96-46d0-bc57-18320e701d26',
      authUserId: '5534b32c-dd96-46d0-bc57-18320e701d26',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0501',
      name: 'Test Teacher Class 5A',
      email: 'test.teacher.5a@school-test.local',
      subjects: ['Mathematics', 'English'],
      assignedClass: 'Class 5',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990501A',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'dafe8e9b-ae7a-4b9d-a365-3e9e75cd1347',
      authUserId: 'dafe8e9b-ae7a-4b9d-a365-3e9e75cd1347',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0502',
      name: 'Test Teacher Class 5B',
      email: 'test.teacher.5b@school-test.local',
      subjects: ['Science', 'Hindi'],
      assignedClass: 'Class 5',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990501B',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 6
    const TeacherModel(
      id: '9813a8d3-92c4-4f7f-b8d4-2474301d14c3',
      authUserId: '9813a8d3-92c4-4f7f-b8d4-2474301d14c3',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0601',
      name: 'Test Teacher Class 6A',
      email: 'test.teacher.6a@school-test.local',
      subjects: ['Mathematics', 'Science'],
      assignedClass: 'Class 6',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990601A',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: '28f93e31-d12c-4519-8544-4d272454959f',
      authUserId: '28f93e31-d12c-4519-8544-4d272454959f',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0602',
      name: 'Test Teacher Class 6B',
      email: 'test.teacher.6b@school-test.local',
      subjects: ['Social Studies', 'English'],
      assignedClass: 'Class 6',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990601B',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 7
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000013',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0701',
      name: 'Test Teacher Class 7A',
      email: 'test.teacher.7a@school-test.local',
      subjects: ['Science', 'Mathematics'],
      assignedClass: 'Class 7',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990701A',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000014',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0702',
      name: 'Test Teacher Class 7B',
      email: 'test.teacher.7b@school-test.local',
      subjects: ['English', 'Hindi'],
      assignedClass: 'Class 7',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990701B',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 8
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000015',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0801',
      name: 'Test Teacher Class 8A',
      email: 'test.teacher.8a@school-test.local',
      subjects: ['Mathematics', 'Physics'],
      assignedClass: 'Class 8',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990801A',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000016',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0802',
      name: 'Test Teacher Class 8B',
      email: 'test.teacher.8b@school-test.local',
      subjects: ['Biology', 'Chemistry'],
      assignedClass: 'Class 8',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990801B',
      designation: 'Middle School Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 9
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000017',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0901',
      name: 'Test Teacher Class 9A',
      email: 'test.teacher.9a@school-test.local',
      subjects: ['Mathematics', 'Physics'],
      assignedClass: 'Class 9',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990901A',
      designation: 'Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000018',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-0902',
      name: 'Test Teacher Class 9B',
      email: 'test.teacher.9b@school-test.local',
      subjects: ['Social Science', 'English'],
      assignedClass: 'Class 9',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999990901B',
      designation: 'Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 10
    const TeacherModel(
      id: '5f78d2ae-3a97-4073-bb26-fbf4e754065d',
      authUserId: '5f78d2ae-3a97-4073-bb26-fbf4e754065d',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-1001',
      name: 'Test Teacher Class 10A',
      email: 'test.teacher.10a@school-test.local',
      subjects: ['Mathematics'],
      assignedClass: 'Class 10',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999991001A',
      designation: 'Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000020',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-1002',
      name: 'Test Teacher Class 10B',
      email: 'test.teacher.10b@school-test.local',
      subjects: ['Science'],
      assignedClass: 'Class 10',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999991001B',
      designation: 'Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 11
    const TeacherModel(
      id: '4ef789af-ad23-4ced-812d-b3c43538ae1f',
      authUserId: '4ef789af-ad23-4ced-812d-b3c43538ae1f',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-1101',
      name: 'Test Teacher Class 11A',
      email: 'test.teacher.11a@school-test.local',
      subjects: ['Chemistry'],
      assignedClass: 'Class 11',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999991101A',
      designation: 'Senior Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000022',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-1102',
      name: 'Test Teacher Class 11B',
      email: 'test.teacher.11b@school-test.local',
      subjects: ['English Core'],
      assignedClass: 'Class 11',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999991101B',
      designation: 'Senior Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Class 12
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000023',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-1201',
      name: 'Test Teacher Class 12A',
      email: 'test.teacher.12a@school-test.local',
      subjects: ['Physics'],
      assignedClass: 'Class 12',
      assignedSection: 'A',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999991201A',
      designation: 'Senior Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    const TeacherModel(
      id: 'b0000001-0000-0000-0000-000000000024',
      schoolId: kpsSchoolId,
      employeeId: 'EMP-1202',
      name: 'Test Teacher Class 12B',
      email: 'test.teacher.12b@school-test.local',
      subjects: ['Mathematics'],
      assignedClass: 'Class 12',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '999991201B',
      designation: 'Senior Secondary Faculty',
      status: AccountStatus.active,
      role: UserRole.teacher,
    ),
    // Authorized School Administration Staff
    const TeacherModel(
      id: 'b773c510-a0b4-47c7-af58-145adc883ca7',
      authUserId: 'b773c510-a0b4-47c7-af58-145adc883ca7',
      schoolId: kpsSchoolId,
      employeeId: 'ADM-0001',
      name: 'School Administrator',
      email: 'admin@school.com',
      subjects: ['School Management'],
      assignedClass: '',
      assignedSection: '',
      totalStudents: 0,
      avatarUrl: '',
      phone: '9876543210',
      designation: 'School Administrator',
      status: AccountStatus.active,
      role: UserRole.schoolAdmin,
    ),
  ];

  // --- TEACHERS & STAFF ---
  Future<List<TeacherModel>> getTeachers({
    String? schoolId,
    String? query,
    AccountStatus? status,
    bool includeStaff = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final List<TeacherModel> list = [];
    final String effectiveSchoolId = (schoolId != null && schoolId.trim().isNotEmpty)
        ? schoolId.trim()
        : ((_client?.auth.currentUser?.userMetadata?['school_id'] as String?) ?? kpsSchoolId);

    if (_client != null && SupabaseConfig.isConfigured && effectiveSchoolId.isNotEmpty) {
      try {
        final profileRes = await _client!
            .from('profiles')
            .select()
            .eq('school_id', effectiveSchoolId)
            .order('created_at', ascending: true);
        if (profileRes.isNotEmpty) {
          for (final p in profileRes) {
            final roleStr = (p['role']?.toString() ?? '').toLowerCase();
            if (includeStaff || roleStr.contains('teacher') || roleStr.contains('faculty')) {
              list.add(_mapSupabaseToTeacherModel(p, defaultSchoolId: effectiveSchoolId));
            }
          }
        }
      } catch (e) {
        debugPrint('[TeacherService Profiles query warning]: $e');
      }

      // If current authenticated user belongs to this school, guarantee presence
      final curUser = _client?.auth.currentUser;
      if (curUser != null) {
        final meta = curUser.userMetadata ?? {};
        final userSchoolId = (meta['school_id'] as String?)?.trim();
        final userRole = (meta['role'] as String?)?.trim().toLowerCase() ?? '';
        final isMatch = userSchoolId == effectiveSchoolId &&
            (includeStaff || userRole.contains('teacher') || userRole.contains('faculty'));
        if (isMatch) {
          final alreadyIncluded = list.any((t) =>
              t.authUserId == curUser.id ||
              (curUser.email != null && t.email.toLowerCase() == curUser.email!.toLowerCase()));
          if (!alreadyIncluded) {
            final dynamicClass = meta['assigned_class'] ?? meta['class'] ?? '';
            final dynamicSection = meta['assigned_section'] ?? meta['section'] ?? '';
            UserRole userRoleEnum = UserRole.teacher;
            if (userRole.contains('admin') || userRole.contains('principal') || userRole.contains('owner')) {
              userRoleEnum = UserRole.schoolAdmin;
            } else if (userRole.contains('staff') || userRole.contains('clerk') || userRole.contains('accountant')) {
              userRoleEnum = UserRole.staff;
            }

            list.add(TeacherModel(
              id: curUser.id,
              schoolId: effectiveSchoolId,
              employeeId: meta['employee_id']?.toString() ?? 'EMP-${curUser.id.length >= 4 ? curUser.id.substring(0, 4).toUpperCase() : "0000"}',
              name: meta['full_name']?.toString() ?? curUser.email?.split('@').first ?? (userRoleEnum.isAdministrator ? 'School Admin' : 'Teacher'),
              email: curUser.email ?? '',
              subjects: meta['subjects'] is List ? List<String>.from(meta['subjects']) : (meta['subject'] != null ? [meta['subject'].toString()] : const []),
              assignedClass: dynamicClass.toString(),
              assignedSection: dynamicSection.toString(),
              totalStudents: 0,
              avatarUrl: '',
              phone: meta['phone']?.toString() ?? '',
              designation: meta['designation']?.toString() ?? (userRoleEnum.isAdministrator ? 'School Administrator' : 'Teacher'),
              status: AccountStatus.active,
              authUserId: curUser.id,
              role: userRoleEnum,
            ));
          }
        }
      }
    }

    // If database returned 0 rows (e.g. offline, unauthenticated anon cache fallback, or remote RLS filtering for admin)
    if (list.isEmpty) {
      await _restoreTeachersCache(effectiveSchoolId);
      if (_teachers.isNotEmpty) {
        list.addAll(_teachers.where((t) => effectiveSchoolId.isEmpty || t.schoolId == effectiveSchoolId));
      }
    }

    // For KPS, ensure the authentic school teachers exist and match the campus structure
    if (effectiveSchoolId == kpsSchoolId) {
      for (final seeded in _kpsBaselineTeachers) {
        final exists = list.any((t) =>
            t.id == seeded.id ||
            (seeded.authUserId != null && t.authUserId == seeded.authUserId) ||
            t.email.toLowerCase() == seeded.email.toLowerCase() ||
            t.employeeId == seeded.employeeId);
        if (!exists) {
          list.add(seeded);
        }
      }
    }

    // Include locally registered or added teachers from in-memory collection
    for (final local in _teachers) {
      final matchesSchool = effectiveSchoolId.isEmpty || local.schoolId.isEmpty || local.schoolId == effectiveSchoolId;
      if (matchesSchool) {
        final alreadyInList = list.any((t) =>
            (t.id.isNotEmpty && t.id == local.id) ||
            (t.employeeId.isNotEmpty && t.employeeId == local.employeeId) ||
            (local.email.isNotEmpty && t.email.toLowerCase() == local.email.toLowerCase()));
        if (!alreadyInList) {
          list.add(local);
        }
      }
    }

    // Sync in-memory collection and persist to school-scoped cache
    if (list.isNotEmpty && effectiveSchoolId.isNotEmpty) {
      for (final t in list) {
        final idx = _teachers.indexWhere((existing) =>
            (existing.id.isNotEmpty && existing.id == t.id) ||
            (existing.authUserId != null && existing.authUserId == t.authUserId) ||
            existing.employeeId == t.employeeId);
        if (idx != -1) {
          _teachers[idx] = t;
        } else {
          _teachers.add(t);
        }
      }
      await _persistTeachersCache(effectiveSchoolId);
    }

    // Update class/section assignment from in-memory cache if available, but strictly for same school
    for (final t in _teachers) {
      if (effectiveSchoolId.isNotEmpty && t.schoolId != effectiveSchoolId) {
        continue;
      }
      final existingIdx = list.indexWhere((existing) =>
          (existing.id.isNotEmpty && existing.id == t.id) ||
          (existing.authUserId != null && existing.authUserId == t.authUserId) ||
          existing.employeeId == t.employeeId);
      if (existingIdx != -1) {
        if (list[existingIdx].assignedClass.isEmpty && t.assignedClass.isNotEmpty) {
          list[existingIdx] = list[existingIdx].copyWith(
            assignedClass: t.assignedClass,
            assignedSection: t.assignedSection,
          );
        }
      }
    }

    var filtered = list;
    if (!includeStaff) {
      filtered = filtered.where((t) => t.isTeacher).toList();
    }
    if (status != null) {
      filtered = filtered.where((t) => t.status == status).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      filtered = filtered.where((t) {
        return t.name.toLowerCase().contains(q) ||
            t.employeeId.toLowerCase().contains(q) ||
            t.designation.toLowerCase().contains(q) ||
            t.assignedClass.toLowerCase().contains(q) ||
            t.assignedSection.toLowerCase().contains(q) ||
            t.subjects.any((s) => s.toLowerCase().contains(q));
      }).toList();
    }
    return filtered;
  }

  Future<Map<String, TeacherModel>> getTeachersClassWise({String? schoolId}) async {
    final all = await getTeachers(schoolId: schoolId);
    final Map<String, TeacherModel> map = {};
    for (var t in all) {
      if (t.assignedClass.isNotEmpty) {
        map[t.assignedClass] = t;
      }
    }
    return map;
  }

  Future<void> updateTeacherAssignment({
    required String teacherId,
    required String className,
    required String sectionName,
  }) async {
    final cleanClass = className.trim();
    final cleanSection = sectionName.trim();

    if (_client != null && SupabaseConfig.isConfigured) {
      bool rpcSuccess = false;
      try {
        final res = await _client!.rpc('update_teacher_assignment', params: {
          'p_teacher_id': teacherId,
          'p_class': cleanClass,
          'p_section': cleanSection,
        });
        if (res != null) rpcSuccess = true;
      } catch (e) {
        debugPrint('[TeacherService update_teacher_assignment RPC notice]: $e');
      }

      if (!rpcSuccess) {
        try {
          await _client!.from('profiles').update({
            'assigned_class': cleanClass.isEmpty ? null : cleanClass,
            'assigned_section': cleanSection.isEmpty ? null : cleanSection,
            'updated_at': DateTime.now().toIso8601String(),
          }).or('id.eq.$teacherId,auth_user_id.eq.$teacherId');
        } catch (e) {
          debugPrint('[TeacherService profiles update warning]: $e');
        }
      }
    }

    final idx = _teachers.indexWhere((t) => t.id == teacherId || t.authUserId == teacherId || t.employeeId == teacherId);
    if (idx != -1) {
      final schoolId = _teachers[idx].schoolId;
      _teachers[idx] = _teachers[idx].copyWith(
        assignedClass: cleanClass,
        assignedSection: cleanSection,
      );
      await _persistTeachersCache(schoolId);
    }
  }

  Future<TeacherModel?> getTeacherById(String id) async {
    final all = await getTeachers();
    try {
      return all.firstWhere((t) => t.id == id || t.employeeId == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addTeacher(TeacherModel teacher) async {
    // 1. Duplicate Employee ID validation
    final exists = _teachers.any((t) =>
        t.schoolId == teacher.schoolId &&
        t.employeeId.toLowerCase().trim() == teacher.employeeId.toLowerCase().trim());

    if (exists) {
      throw Exception('Employee ID "${teacher.employeeId}" is already registered in this school.');
    }

    // 2. Real Supabase insert into profiles table if authUserId is present
    if (_client != null && SupabaseConfig.isConfigured && teacher.authUserId != null && teacher.authUserId!.isNotEmpty) {
      try {
        await _client!.rpc('create_staff_profile', params: {
          'p_auth_user_id': teacher.authUserId,
          'p_school_id': teacher.schoolId,
          'p_full_name': teacher.name,
          'p_role': 'teacher',
        });
      } catch (_) {
        try {
          await _client!.from('profiles').upsert({
            'auth_user_id': teacher.authUserId,
            'school_id': teacher.schoolId,
            'full_name': teacher.name,
            'role': 'teacher',
            'status': 'active',
          }, onConflict: 'auth_user_id');
        } catch (pErr) {
          debugPrint('[TeacherService profiles upsert warning]: $pErr');
        }
      }
    }

    _teachers.removeWhere((t) => (t.id.isNotEmpty && t.id == teacher.id) || t.employeeId == teacher.employeeId);
    _teachers.insert(0, teacher);
    await _persistTeachersCache(teacher.schoolId);
  }

  Future<void> updateTeacher(TeacherModel updated) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await updateTeacherAssignment(
          teacherId: updated.id,
          className: updated.className,
          sectionName: updated.sectionName,
        );

        final updatePayload = <String, dynamic>{
          'full_name': updated.name,
          'status': updated.status == AccountStatus.inactive ? 'inactive' : 'active',
          'updated_at': DateTime.now().toIso8601String(),
        };

        await _client!.from('profiles').update(updatePayload)
            .or('id.eq.${updated.id},auth_user_id.eq.${updated.authUserId ?? updated.id}');
      } catch (e) {
        debugPrint('[TeacherService updateTeacher warning]: $e');
      }
    }

    final idx = _teachers.indexWhere((t) => t.id == updated.id || t.employeeId == updated.employeeId || (updated.authUserId != null && t.authUserId == updated.authUserId));
    if (idx != -1) {
      _teachers[idx] = updated;
    } else {
      _teachers.insert(0, updated);
    }
    await _persistTeachersCache(updated.schoolId);
  }

  Future<void> deleteTeacher(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _teachers.indexWhere((t) => t.id == id || t.employeeId == id || t.authUserId == id);
    if (idx != -1) {
      final schoolId = _teachers[idx].schoolId;
      _teachers.removeAt(idx);
      await _persistTeachersCache(schoolId);
    }
  }

  // --- UNIFIED STAFF & TEACHER MANAGEMENT ---
  Future<List<StaffMemberModel>> getStaffMembers({
    String? schoolId,
    String? query,
    AccountStatus? status,
    UserRole? role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final List<StaffMemberModel> list = [];
    String? effectiveSchoolId = schoolId;
    if (effectiveSchoolId == null || effectiveSchoolId.isEmpty) {
      final curUser = _client?.auth.currentUser;
      effectiveSchoolId = curUser?.userMetadata?['school_id'] as String?;
    }

    if (_client != null && SupabaseConfig.isConfigured && effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      try {
        var queryBuilder = _client!
            .from('profiles')
            .select()
            .eq('school_id', effectiveSchoolId);

        if (role == UserRole.teacher) {
          queryBuilder = queryBuilder.ilike('role', '%teacher%');
        } else if (role == UserRole.staff) {
          queryBuilder = queryBuilder.ilike('role', '%staff%');
        } else if (role != null) {
          queryBuilder = queryBuilder.ilike('role', '%${role.name}%');
        }

        final profileRes = await queryBuilder.order('created_at', ascending: true);
        if (profileRes.isNotEmpty) {
          for (final p in profileRes) {
            list.add(StaffMemberModel.fromJson(p));
          }
        }
      } catch (e) {
        debugPrint('[TeacherService getStaffMembers warning]: $e');
      }
    }

    // If database returned 0 (mock mode or cache fallback)
    if (list.isEmpty) {
      final allPersonnel = await getTeachers(schoolId: effectiveSchoolId, includeStaff: true);
      for (final t in allPersonnel) {
        if (effectiveSchoolId == null || effectiveSchoolId.isEmpty || t.schoolId == effectiveSchoolId) {
          list.add(StaffMemberModel(
            id: t.id,
            authUserId: t.authUserId,
            schoolId: t.schoolId,
            employeeId: t.employeeId,
            name: t.name,
            email: t.email,
            phone: t.phone,
            role: t.role,
            designation: t.designation,
            subject: t.subjects.isNotEmpty ? t.subjects.first : null,
            assignedClass: t.className,
            assignedSection: t.sectionName,
            status: t.status,
          ));
        }
      }
    }

    var filtered = list;
    if (role != null) {
      filtered = filtered.where((s) => s.role == role).toList();
    }
    if (status != null) {
      filtered = filtered.where((s) => s.status == status).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      filtered = filtered.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.employeeId.toLowerCase().contains(q) ||
            s.email.toLowerCase().contains(q) ||
            s.designation.toLowerCase().contains(q) ||
            (s.subject != null && s.subject!.toLowerCase().contains(q)) ||
            (s.assignedClass != null && s.assignedClass!.toLowerCase().contains(q)) ||
            (s.assignedSection != null && s.assignedSection!.toLowerCase().contains(q));
      }).toList();
    }
    return filtered;
  }

  Future<void> toggleStaffStatus({
    required String id,
    required AccountStatus newStatus,
  }) async {
    final statusStr = newStatus == AccountStatus.inactive ? 'inactive' : 'active';
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('profiles').update({
          'status': statusStr,
          'updated_at': DateTime.now().toIso8601String(),
        }).or('id.eq.$id,auth_user_id.eq.$id');
      } catch (e) {
        debugPrint('[TeacherService toggleStaffStatus warning]: $e');
      }
    }

    final idx = _teachers.indexWhere((t) => t.id == id || t.authUserId == id || t.employeeId == id);
    if (idx != -1) {
      final schoolId = _teachers[idx].schoolId;
      _teachers[idx] = _teachers[idx].copyWith(status: newStatus);
      await _persistTeachersCache(schoolId);
    }
  }

  Future<void> updateStaffMember({
    required String id,
    required String name,
    required String phone,
    required String designation,
    String? subject,
    String? assignedClass,
    String? assignedSection,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final updatePayload = <String, dynamic>{
          'full_name': name.trim(),
          'phone': phone.trim(),
          'designation': designation.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (subject != null) {
          updatePayload['subject'] = subject.trim();
        }
        if (assignedClass != null) {
          updatePayload['assigned_class'] = assignedClass.trim().isEmpty ? null : assignedClass.trim();
        }
        if (assignedSection != null) {
          updatePayload['assigned_section'] = assignedSection.trim().isEmpty ? null : assignedSection.trim();
        }

        await _client!.from('profiles').update(updatePayload)
            .or('id.eq.$id,auth_user_id.eq.$id');
      } catch (e) {
        debugPrint('[TeacherService updateStaffMember warning]: $e');
      }
    }

    final idx = _teachers.indexWhere((t) => t.id == id || t.authUserId == id || t.employeeId == id);
    if (idx != -1) {
      final schoolId = _teachers[idx].schoolId;
      _teachers[idx] = _teachers[idx].copyWith(
        name: name.trim(),
        phone: phone.trim(),
        designation: designation.trim(),
        assignedClass: assignedClass ?? _teachers[idx].assignedClass,
        assignedSection: assignedSection ?? _teachers[idx].assignedSection,
        subjects: subject != null ? [subject.trim()] : _teachers[idx].subjects,
      );
      await _persistTeachersCache(schoolId);
    }
  }

  // --- SUBJECTS ---
  Future<List<SubjectModel>> getSubjects({String? schoolId}) async {
    final effectiveSchoolId = schoolId ?? '';
    if (_client != null && SupabaseConfig.isConfigured && effectiveSchoolId.isNotEmpty) {
      try {
        final res = await _client!.from('subjects').select().eq('school_id', effectiveSchoolId).order('name');
        if (res.isNotEmpty) {
          return res.map((s) => SubjectModel(
            id: s['id']?.toString() ?? '',
            schoolId: s['school_id']?.toString() ?? '',
            name: s['name']?.toString() ?? '',
            code: s['code']?.toString(),
          )).toList();
        }
      } catch (e) {
        debugPrint('[TeacherService getSubjects Warning]: $e');
      }
    }
    return _mockSubjects.where((s) => effectiveSchoolId.isEmpty || s.schoolId == effectiveSchoolId).toList();
  }

  Future<SubjectModel> createSubject({
    required String schoolId,
    required String name,
    String? code,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      final res = await _client!.from('subjects').insert({
        'school_id': schoolId,
        'name': name.trim(),
        'code': code?.trim().toUpperCase(),
      }).select().single();
      return SubjectModel(
        id: res['id']?.toString() ?? '',
        schoolId: res['school_id']?.toString() ?? '',
        name: res['name']?.toString() ?? '',
        code: res['code']?.toString(),
      );
    }

    final exists = _mockSubjects.any((s) => s.schoolId == schoolId && s.name.toLowerCase() == name.trim().toLowerCase());
    if (exists) {
      throw Exception('Subject "$name" already exists.');
    }

    final newSub = SubjectModel(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: schoolId,
      name: name.trim(),
      code: code?.trim().toUpperCase(),
    );
    _mockSubjects.add(newSub);
    return newSub;
  }

  // --- ASSIGNMENTS ---
  Future<List<TeacherAssignmentModel>> getTeacherAssignments({
    required String schoolId,
    String? teacherId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final teachers = await getTeachers(schoolId: schoolId);
    final List<TeacherAssignmentModel> derivedAssignments = [];
    for (final t in teachers) {
      if (t.assignedClass.isNotEmpty) {
        if (teacherId == null || t.id == teacherId || t.authUserId == teacherId || t.employeeId == teacherId) {
          final displayClassName = (t.assignedSection.isNotEmpty && !t.assignedClass.contains('-'))
              ? '${t.assignedClass}-${t.assignedSection}'
              : t.assignedClass;
          derivedAssignments.add(TeacherAssignmentModel(
            id: 'asg_${t.id}',
            schoolId: t.schoolId,
            teacherId: t.id,
            academicYearId: '',
            classId: t.assignedClass,
            sectionId: t.assignedSection,
            subjectId: t.subjects.isNotEmpty ? t.subjects.first : '',
            className: displayClassName,
            subjectName: t.subjects.isNotEmpty ? t.subjects.first : 'General',
            isClassTeacher: true,
          ));
        }
      }
    }
    for (final a in _mockAssignments) {
      if (a.schoolId == schoolId && (teacherId == null || a.teacherId == teacherId)) {
        if (!derivedAssignments.any((d) => d.classId == a.classId && d.sectionId == a.sectionId && d.teacherId == a.teacherId)) {
          derivedAssignments.add(a);
        }
      }
    }
    return derivedAssignments;
  }

  Future<TeacherAssignmentModel> assignTeacher({
    required String schoolId,
    required String teacherId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String subjectId,
    required String className,
    required String subjectName,
    bool isClassTeacher = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final exists = _mockAssignments.any((a) =>
        a.schoolId == schoolId &&
        a.academicYearId == academicYearId &&
        a.classId == classId &&
        a.sectionId == sectionId &&
        a.subjectId == subjectId);

    if (exists) {
      throw Exception('A teacher is already assigned to $className ($subjectName).');
    }

    final newAsg = TeacherAssignmentModel(
      id: 'asg_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: schoolId,
      teacherId: teacherId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      className: className,
      subjectName: subjectName,
      isClassTeacher: isClassTeacher,
    );

    _mockAssignments.add(newAsg);
    final targetClass = className.contains('-') ? className.split('-').first.trim() : className;
    final targetSec = className.contains('-') ? className.split('-').last.trim() : sectionId;
    await updateTeacherAssignment(
      teacherId: teacherId,
      className: targetClass,
      sectionName: targetSec,
    );
    return newAsg;
  }

  TeacherModel _mapSupabaseToTeacherModel(Map<String, dynamic> data, {String? defaultSchoolId}) {
    final subList = data['subjects'] is List
        ? List<String>.from(data['subjects'])
        : (data['subject'] != null ? [data['subject'].toString()] : const <String>[]);
    var rawClass = data['assigned_class']?.toString() ?? data['class']?.toString() ??
        (data['class_name'] != null ? data['class_name'].toString() : '');
    var rawSection = data['assigned_section']?.toString() ?? data['section']?.toString() ?? '';
    if (rawClass.contains(' - ') && rawSection.isEmpty) {
      final parts = rawClass.split(' - ');
      rawClass = parts.first.trim();
      rawSection = parts.last.trim();
    } else if (rawClass.contains('-') && rawSection.isEmpty) {
      final parts = rawClass.split('-');
      rawClass = parts.first.trim();
      rawSection = parts.last.trim();
    }

    final rawName = (data['full_name'] ?? data['name'] ?? '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}').toString().trim();
    final teacherName = rawName.isNotEmpty ? rawName : 'Teacher';
    final statusStr = data['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final accountStatus = (statusStr == 'INACTIVE' || statusStr == 'SUSPENDED')
        ? AccountStatus.inactive
        : AccountStatus.active;
    final idStr = data['id']?.toString() ?? '';
    final empId = data['employee_id']?.toString() ?? data['employee_code']?.toString() ??
        'EMP-${idStr.length >= 4 ? idStr.substring(0, 4).toUpperCase() : "0000"}';

    final rawRole = (data['role']?.toString() ?? 'teacher').toLowerCase();
    UserRole parsedRole;
    if (rawRole.contains('admin') || rawRole.contains('principal') || rawRole.contains('owner')) {
      parsedRole = UserRole.schoolAdmin;
    } else if (rawRole.contains('staff') || rawRole.contains('clerk') || rawRole.contains('accountant')) {
      parsedRole = UserRole.staff;
    } else {
      parsedRole = UserRole.teacher;
    }

    return TeacherModel(
      id: idStr,
      schoolId: data['school_id']?.toString() ?? defaultSchoolId ?? '',
      employeeId: empId,
      name: teacherName,
      email: data['email']?.toString() ?? '',
      subjects: subList,
      assignedClass: rawClass,
      assignedSection: rawSection,
      totalStudents: 0,
      avatarUrl: data['profile_photo_url']?.toString() ?? data['avatar_url']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      designation: data['designation']?.toString() ?? (parsedRole.isAdministrator ? 'School Administrator' : 'Teacher'),
      status: accountStatus,
      joiningDate: data['joining_date']?.toString(),
      authUserId: data['auth_user_id']?.toString(),
      role: parsedRole,
    );
  }
}
