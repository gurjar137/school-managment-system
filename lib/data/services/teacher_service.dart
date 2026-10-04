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

  final List<TeacherModel> _teachers = [
    const TeacherModel(
      id: 'teacher_ramesh_seed',
      schoolId: 'mock_school_1',
      employeeId: 'EMP-0101',
      name: 'Ramesh',
      email: 'ramesh137@gmail.com',
      subjects: ['Physics'],
      assignedClass: '12',
      assignedSection: 'F',
      totalStudents: 1,
      avatarUrl: '',
      phone: '9876543210',
      designation: 'Senior Physics Faculty',
      status: AccountStatus.active,
    ),
    const TeacherModel(
      id: 'teacher_ram_seed',
      schoolId: 'mock_school_1',
      employeeId: 'EMP-0102',
      name: 'Ram',
      email: 'ram@gmail.com',
      subjects: ['Mathematics'],
      assignedClass: '5',
      assignedSection: 'A',
      totalStudents: 1,
      avatarUrl: '',
      phone: '9876543211',
      designation: 'Senior Math Faculty',
      status: AccountStatus.active,
    ),
  ];
  final List<SubjectModel> _mockSubjects = [];
  final List<TeacherAssignmentModel> _mockAssignments = [];

  Future<void> _persistTeachersCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _teachers.map((t) => t.toJson()).toList();
      await prefs.setString('cached_teachers_data', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[TeacherService Cache Save Warning]: $e');
    }
  }

  Future<void> _restoreTeachersCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_teachers_data');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final decoded = jsonDecode(cachedStr);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final model = TeacherModel.fromJson(item);
              if (!_teachers.any((t) => t.id == model.id || (model.authUserId != null && t.authUserId == model.authUserId) || t.employeeId == model.employeeId)) {
                _teachers.add(model);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TeacherService Cache Restore Warning]: $e');
    }
  }

  // --- TEACHERS ---
  Future<List<TeacherModel>> getTeachers({
    String? schoolId,
    String? query,
    AccountStatus? status,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final List<TeacherModel> list = [];
    String? effectiveSchoolId = schoolId;
    if (effectiveSchoolId == null || effectiveSchoolId.isEmpty) {
      final curUser = _client?.auth.currentUser;
      effectiveSchoolId = curUser?.userMetadata?['school_id'] as String?;
    }

    if (_client != null && SupabaseConfig.isConfigured && effectiveSchoolId != null && effectiveSchoolId.isNotEmpty) {
      try {
        final profileRes = await _client!
            .from('profiles')
            .select()
            .eq('school_id', effectiveSchoolId)
            .ilike('role', '%teacher%')
            .order('created_at', ascending: true);
        if (profileRes.isNotEmpty) {
          for (final p in profileRes) {
            list.add(_mapSupabaseToTeacherModel(p, defaultSchoolId: effectiveSchoolId));
          }

          if (list.isNotEmpty) {
            for (final t in list) {
              final idx = _teachers.indexWhere((existing) => (existing.id.isNotEmpty && existing.id == t.id) || (existing.authUserId != null && existing.authUserId == t.authUserId) || existing.employeeId == t.employeeId);
              if (idx != -1) {
                _teachers[idx] = t;
              } else {
                _teachers.add(t);
              }
            }
            await _persistTeachersCache();
          }
        }
      } catch (e) {
        debugPrint('[TeacherService Profiles query warning]: $e');
      }
    }

    // If database returned 0 rows (e.g. unauthenticated anon client where RLS restricts profiles or offline), restore from cache or verified database records
    if (list.isEmpty) {
      if (_teachers.isEmpty) {
        await _restoreTeachersCache();
      }
      if (_teachers.isNotEmpty) {
        list.addAll(_teachers.where((t) => t.schoolId == effectiveSchoolId || effectiveSchoolId == null || effectiveSchoolId.isEmpty));
      }
    }


    for (final t in _teachers) {
      final existingIdx = list.indexWhere((existing) => (existing.id.isNotEmpty && existing.id == t.id) || (existing.authUserId != null && existing.authUserId == t.authUserId) || existing.employeeId == t.employeeId);
      if (existingIdx != -1) {
        if (list[existingIdx].assignedClass.isEmpty && t.assignedClass.isNotEmpty) {
          list[existingIdx] = list[existingIdx].copyWith(
            assignedClass: t.assignedClass,
            assignedSection: t.assignedSection,
          );
        }
      } else {
        list.add(t);
      }
    }

    var filtered = list;
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

  Future<Map<String, TeacherModel>> getTeachersClassWise() async {
    final all = await getTeachers();
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

    final idx = _teachers.indexWhere((t) => t.id == teacherId || t.authUserId == teacherId);
    if (idx != -1) {
      _teachers[idx] = _teachers[idx].copyWith(
        assignedClass: cleanClass,
        assignedSection: cleanSection,
      );
      await _persistTeachersCache();
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

    _teachers.removeWhere((t) => t.id == teacher.id || t.employeeId == teacher.employeeId);
    _teachers.insert(0, teacher);
    await _persistTeachersCache();
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

    final idx = _teachers.indexWhere((t) => t.id == updated.id || t.employeeId == updated.employeeId);
    if (idx != -1) {
      _teachers[idx] = updated;
    } else {
      _teachers.insert(0, updated);
    }
    await _persistTeachersCache();
  }

  Future<void> deleteTeacher(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _teachers.removeWhere((t) => t.id == id);
    await _persistTeachersCache();
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
        } else {
          queryBuilder = queryBuilder.or('role.ilike.%teacher%,role.ilike.%staff%');
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
      for (final t in _teachers) {
        if (effectiveSchoolId == null || effectiveSchoolId.isEmpty || t.schoolId == effectiveSchoolId) {
          list.add(StaffMemberModel(
            id: t.id,
            authUserId: t.authUserId,
            schoolId: t.schoolId,
            employeeId: t.employeeId,
            name: t.name,
            email: t.email,
            phone: t.phone,
            role: UserRole.teacher,
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

    final idx = _teachers.indexWhere((t) => t.id == id || t.authUserId == id);
    if (idx != -1) {
      _teachers[idx] = _teachers[idx].copyWith(status: newStatus);
      await _persistTeachersCache();
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

    final idx = _teachers.indexWhere((t) => t.id == id || t.authUserId == id);
    if (idx != -1) {
      _teachers[idx] = _teachers[idx].copyWith(
        name: name.trim(),
        phone: phone.trim(),
        designation: designation.trim(),
        assignedClass: assignedClass ?? _teachers[idx].assignedClass,
        assignedSection: assignedSection ?? _teachers[idx].assignedSection,
        subjects: subject != null ? [subject.trim()] : _teachers[idx].subjects,
      );
      await _persistTeachersCache();
    }
  }

  // --- SUBJECTS ---
  Future<List<SubjectModel>> getSubjects({String? schoolId}) async {
    final effectiveSchoolId = schoolId ?? '';
    if (_client != null && SupabaseConfig.isConfigured && effectiveSchoolId.isNotEmpty) {
      try {
        final res = await _client!.from('subjects').select().eq('school_id', effectiveSchoolId).order('name');
        if (res is List && res.isNotEmpty) {
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
    if (teacherId != null) {
      return _mockAssignments.where((a) => a.schoolId == schoolId && a.teacherId == teacherId).toList();
    }
    return _mockAssignments.where((a) => a.schoolId == schoolId).toList();
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
    return newAsg;
  }

  TeacherModel _mapSupabaseToTeacherModel(Map<String, dynamic> data, {String? defaultSchoolId}) {
    final subList = data['subjects'] is List
        ? List<String>.from(data['subjects'])
        : (data['subject'] != null ? [data['subject'].toString()] : const <String>[]);
    final rawClass = data['assigned_class']?.toString() ?? data['class']?.toString() ??
        (data['class_name'] != null ? data['class_name'].toString() : '');
    final rawSection = data['assigned_section']?.toString() ?? data['section']?.toString() ?? '';
    final rawName = (data['full_name'] ?? data['name'] ?? '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}').toString().trim();
    final teacherName = rawName.isNotEmpty ? rawName : 'Teacher';
    final statusStr = data['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final accountStatus = (statusStr == 'INACTIVE' || statusStr == 'SUSPENDED')
        ? AccountStatus.inactive
        : AccountStatus.active;
    final idStr = data['id']?.toString() ?? '';
    final empId = data['employee_id']?.toString() ?? data['employee_code']?.toString() ??
        'EMP-${idStr.length >= 4 ? idStr.substring(0, 4).toUpperCase() : "0000"}';

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
      designation: data['designation']?.toString() ?? 'Teacher',
      status: accountStatus,
      joiningDate: data['joining_date']?.toString(),
      authUserId: data['auth_user_id']?.toString(),
    );
  }
}
