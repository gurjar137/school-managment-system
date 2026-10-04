import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/parent_model.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';

class ParentService {
  String _generateUuid() {
    final rnd = math.Random();
    String hex(int len) => List.generate(len, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-8${hex(3)}-${hex(12)}';
  }
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  static const String _parentsCacheKey = 'cached_parents_data';
  static const String _linksCacheKey = 'cached_parent_links_data';

  final List<ParentModel> _cachedParents = [];
  final List<ParentStudentLinkModel> _cachedLinks = [];
  bool _isCacheLoaded = false;

  Future<void> _loadCache() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final pStr = prefs.getString(_parentsCacheKey);
      if (pStr != null && pStr.isNotEmpty) {
        final decoded = jsonDecode(pStr);
        if (decoded is List) {
          _cachedParents.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _cachedParents.add(ParentModel.fromJson(item));
            }
          }
        }
      }

      final lStr = prefs.getString(_linksCacheKey);
      if (lStr != null && lStr.isNotEmpty) {
        final decoded = jsonDecode(lStr);
        if (decoded is List) {
          _cachedLinks.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _cachedLinks.add(ParentStudentLinkModel.fromJson(item));
            }
          }
        }
      }
      _isCacheLoaded = true;
    } catch (e) {
      debugPrint('[ParentService Cache Load Warning]: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_parentsCacheKey, jsonEncode(_cachedParents.map((p) => p.toJson()).toList()));
      await prefs.setString(_linksCacheKey, jsonEncode(_cachedLinks.map((l) => l.toJson()).toList()));
    } catch (e) {
      debugPrint('[ParentService Cache Save Warning]: $e');
    }
  }

  Future<String> resolveActiveSchoolId([String? schoolId]) async {
    if (schoolId != null && schoolId.isNotEmpty) return schoolId;
    final client = _client;
    if (client != null && client.auth.currentUser != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('school_id')
            .eq('auth_user_id', client.auth.currentUser!.id)
            .maybeSingle();
        if (profile != null && profile['school_id'] != null && profile['school_id'].toString().isNotEmpty) {
          return profile['school_id'].toString();
        }
      } catch (_) {}
    }
    if (SupabaseConfig.isConfigured) {
      throw const TenantResolutionException('Active school could not be resolved for current user. Please log in again.');
    }
    return 'offline_mock_school';
  }

  // --- FETCH PARENTS ---
  Future<List<ParentModel>> fetchParents({
    String? schoolId,
    String? query,
    AccountStatus? status,
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var supabaseQuery = _client!
            .from('parents')
            .select()
            .eq('school_id', activeSchoolId);

        if (status != null) {
          supabaseQuery = supabaseQuery.eq('status', status.name.toUpperCase());
        }

        final data = await supabaseQuery.order('created_at', ascending: false);
        if (data is List) {
          // Fetch linked students from parent_students
          Map<String, List<ParentStudentLinkModel>> linksMap = {};
          try {
            final linksData = await _client!
                .from('parent_students')
                .select()
                .eq('school_id', activeSchoolId);
            if (linksData is List) {
              for (final row in linksData) {
                final linkModel = ParentStudentLinkModel.fromJson(row);
                linksMap.putIfAbsent(linkModel.parentId, () => []).add(linkModel);
              }
            }
          } catch (_) {}

          final liveParents = data.map((p) {
            final model = ParentModel.fromJson(p);
            final children = linksMap[model.id] ?? [];
            return model.copyWith(
              linkedStudentsCount: children.isNotEmpty ? children.length : model.linkedStudentsCount,
              linkedStudents: children,
            );
          }).toList();

          // Sync into memory cache
          for (final lp in liveParents) {
            final idx = _cachedParents.indexWhere((cp) => cp.id == lp.id);
            if (idx >= 0) {
              _cachedParents[idx] = lp;
            } else {
              _cachedParents.add(lp);
            }
          }
          await _saveCache();
        }
      } catch (e) {
        debugPrint('[ParentService Supabase Fetch Warning]: $e');
      }
    }

    var list = _cachedParents.where((p) => p.schoolId == activeSchoolId).toList();
    if (status != null) {
      list = list.where((p) => p.status == status).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      list = list.where((p) {
        final matchesParent = p.name.toLowerCase().contains(q) ||
            p.parentCode.toLowerCase().contains(q) ||
            p.phone.contains(q) ||
            (p.email != null && p.email!.toLowerCase().contains(q));
        if (matchesParent) return true;

        // Also search within linked children
        final matchesChild = p.linkedStudents.any((c) =>
            c.studentName.toLowerCase().contains(q) ||
            c.admissionNumber.toLowerCase().contains(q) ||
            c.studentClass.toLowerCase().contains(q));
        return matchesChild;
      }).toList();
    }
    return list;
  }

  // --- GET PARENT BY ID ---
  Future<ParentModel?> getParentById(String id) async {
    await _loadCache();
    final cached = _cachedParents.where((p) => p.id == id).toList();
    if (cached.isNotEmpty) return cached.first;

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('parents')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (data != null) {
          final model = ParentModel.fromJson(data);
          _cachedParents.add(model);
          await _saveCache();
          return model;
        }
      } catch (_) {}
    }
    return null;
  }

  // --- CREATE PARENT ---
  Future<ParentModel> createParent({
    required String schoolId,
    required String name,
    required String phone,
    String? email,
    String? alternatePhone,
    String? address,
    String? city,
    String? state,
    String? postalCode,
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    final nextSeq = _cachedParents.where((p) => p.schoolId == activeSchoolId).length + 1;
    final parentCode = 'SCH001-PAR-${nextSeq.toString().padLeft(4, '0')}';
    final generatedId = _generateUuid();

    final newParent = ParentModel(
      id: generatedId,
      schoolId: activeSchoolId,
      parentCode: parentCode,
      name: name.trim(),
      phone: phone.trim(),
      email: email?.trim().isNotEmpty == true ? email!.trim() : null,
      alternatePhone: alternatePhone?.trim().isNotEmpty == true ? alternatePhone!.trim() : null,
      address: address?.trim().isNotEmpty == true ? address!.trim() : null,
      city: city?.trim().isNotEmpty == true ? city!.trim() : null,
      state: state?.trim().isNotEmpty == true ? state!.trim() : null,
      postalCode: postalCode?.trim().isNotEmpty == true ? postalCode!.trim() : null,
      status: AccountStatus.active,
      linkedStudentsCount: 0,
      createdAt: DateTime.now(),
    );

    // Persist to Supabase
    if (_client != null && SupabaseConfig.isConfigured) {
      bool inserted = false;
      try {
        // Attempt with parent_code and parent_unique_id
        final resp = await _client!.from('parents').insert({
          'school_id': activeSchoolId,
          'parent_name': newParent.name,
          'phone': newParent.phone,
          'email': newParent.email,
          'address': newParent.address,
          'parent_code': newParent.parentCode,
          'parent_unique_id': newParent.parentCode,
          'status': 'ACTIVE',
        }).select().maybeSingle();

        if (resp != null && resp['id'] != null) {
          final persistedParent = ParentModel.fromJson(resp).copyWith(
            parentCode: newParent.parentCode,
            linkedStudentsCount: 0,
          );
          _cachedParents.insert(0, persistedParent);
          await _saveCache();
          return persistedParent;
        }
        inserted = true;
      } catch (e) {
        debugPrint('[ParentService Create with parent_code failed, attempting fallback]: $e');
      }

      if (!inserted) {
        try {
          // Attempt without parent_code column in case migration not yet run
          final resp = await _client!.from('parents').insert({
            'school_id': activeSchoolId,
            'parent_name': newParent.name,
            'phone': newParent.phone,
            'email': newParent.email,
            'address': newParent.address,
            'parent_unique_id': newParent.parentCode,
            'status': 'ACTIVE',
          }).select().maybeSingle();

          if (resp != null && resp['id'] != null) {
            final persistedParent = ParentModel.fromJson(resp).copyWith(
              parentCode: newParent.parentCode,
              linkedStudentsCount: 0,
            );
            _cachedParents.insert(0, persistedParent);
            await _saveCache();
            return persistedParent;
          }
        } catch (e) {
          debugPrint('[ParentService Create Supabase Final Error]: $e');
        }
      }
    }

    _cachedParents.insert(0, newParent);
    await _saveCache();
    return newParent;
  }

  // --- LINK STUDENT TO PARENT ---
  Future<ParentStudentLinkModel> linkStudentToParent({
    required String schoolId,
    required String parentId,
    required String studentId,
    required String studentName,
    required String studentClass,
    required String admissionNumber,
    String relationship = 'FATHER',
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    // Duplicate check
    final exists = _cachedLinks.any((l) => l.parentId == parentId && l.studentId == studentId);
    if (exists) {
      throw Exception('This student is already linked to this parent.');
    }

    final newLink = ParentStudentLinkModel(
      id: _generateUuid(),
      schoolId: activeSchoolId,
      parentId: parentId,
      studentId: studentId,
      relationship: relationship,
      isPrimary: false,
      studentName: studentName,
      studentClass: studentClass,
      admissionNumber: admissionNumber,
    );

    // Try persisting to Supabase parent_students
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final resp = await _client!.from('parent_students').insert({
          'school_id': activeSchoolId,
          'parent_id': parentId,
          'student_id': studentId,
          'relationship': relationship,
          'is_primary': false,
          'student_name': studentName,
          'student_class': studentClass,
          'admission_number': admissionNumber,
        }).select().maybeSingle();

        if (resp != null && resp['id'] != null) {
          final liveLink = ParentStudentLinkModel.fromJson(resp);
          _cachedLinks.add(liveLink);
          _updateParentLinkedCount(parentId, 1);
          await _saveCache();
          return liveLink;
        }
      } catch (e) {
        debugPrint('[ParentService linkStudent Supabase Warning]: $e');
      }
    }

    _cachedLinks.add(newLink);
    _updateParentLinkedCount(parentId, 1);
    await _saveCache();
    return newLink;
  }

  // --- UNLINK STUDENT ---
  Future<void> unlinkStudentFromParent(String linkId) async {
    await _loadCache();
    final idx = _cachedLinks.indexWhere((l) => l.id == linkId);
    String? parentId;
    if (idx != -1) {
      parentId = _cachedLinks[idx].parentId;
      _cachedLinks.removeAt(idx);
      if (parentId.isNotEmpty) {
        _updateParentLinkedCount(parentId, -1);
      }
      await _saveCache();
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('parent_students').delete().eq('id', linkId);
      } catch (e) {
        debugPrint('[ParentService unlink Supabase Warning]: $e');
      }
    }
  }

  // --- GET LINKED STUDENTS FOR PARENT ---
  Future<List<ParentStudentLinkModel>> getLinkedStudentsForParent(String parentId) async {
    await _loadCache();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('parent_students')
            .select()
            .eq('parent_id', parentId);
        if (data is List && data.isNotEmpty) {
          final liveList = data.map((d) => ParentStudentLinkModel.fromJson(d)).toList();
          for (final item in liveList) {
            if (!_cachedLinks.any((l) => l.id == item.id)) {
              _cachedLinks.add(item);
            }
          }
          await _saveCache();
          return liveList;
        }
      } catch (e) {
        debugPrint('[ParentService getLinkedStudents Supabase Warning]: $e');
      }
    }

    return _cachedLinks.where((l) => l.parentId == parentId).toList();
  }

  // --- PARENT APP LOGIN VERIFICATION API ---
  Future<Map<String, dynamic>> verifyParentCode(String parentCode) async {
    await _loadCache();
    final cleanCode = parentCode.trim().toUpperCase();

    ParentModel? foundParent;

    // 1. Check in cache
    try {
      foundParent = _cachedParents.firstWhere(
        (p) => p.parentCode.toUpperCase() == cleanCode || p.phone.trim() == cleanCode,
      );
    } catch (_) {}

    // 2. Query Supabase
    if (foundParent == null && _client != null && SupabaseConfig.isConfigured) {
      try {
        // Try by parent_code
        var row = await _client!
            .from('parents')
            .select()
            .eq('parent_code', cleanCode)
            .maybeSingle();

        // If not found, try by parent_unique_id
        row ??= await _client!
            .from('parents')
            .select()
            .eq('parent_unique_id', cleanCode)
            .maybeSingle();

        // If not found, try by phone
        row ??= await _client!
            .from('parents')
            .select()
            .eq('phone', cleanCode)
            .maybeSingle();

        if (row != null) {
          foundParent = ParentModel.fromJson(row);
          _cachedParents.add(foundParent);
          await _saveCache();
        }
      } catch (_) {}
    }

    if (foundParent == null) {
      throw Exception('Parent ID could not be verified. Please check your Parent Code or registered Phone number.');
    }

    if (foundParent.status != AccountStatus.active) {
      throw Exception('Your parent account is currently inactive. Please contact your school admin.');
    }

    final children = await getLinkedStudentsForParent(foundParent.id);
    return {
      'success': true,
      'parent': foundParent,
      'children': children,
    };
  }

  void _updateParentLinkedCount(String parentId, int delta) {
    final pIdx = _cachedParents.indexWhere((p) => p.id == parentId);
    if (pIdx != -1) {
      final curCount = _cachedParents[pIdx].linkedStudentsCount;
      final newCount = (curCount + delta) < 0 ? 0 : (curCount + delta);
      _cachedParents[pIdx] = _cachedParents[pIdx].copyWith(linkedStudentsCount: newCount);
    }
  }

  // --- PARENT ACCESS MANAGEMENT API (STUDENT DETAILS & ADMIN) ---

  String _generateParentCode() {
    final rnd = math.Random();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String part1 = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    String part2 = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    return 'PRT-$part1-$part2';
  }

  /// Retrieves the parent access state for a given student.
  Future<StudentParentAccessInfo> getParentAccessForStudent(
    String studentId, {
    required String schoolId,
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    String? code;
    String studentName = 'Student';
    AccountStatus studentStatus = AccountStatus.active;
    String? fatherName;
    String? phone;
    String? email;

    // 1. Fetch student from Supabase or cache
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final row = await _client!
            .from('students')
            .select()
            .eq('id', studentId)
            .eq('school_id', activeSchoolId)
            .maybeSingle();

        if (row != null) {
          code = row['parent_access_code']?.toString().trim();
          if (code != null && code.isEmpty) code = null;

          final first = row['first_name']?.toString() ?? '';
          final last = row['last_name']?.toString() ?? '';
          final fullName = '$first $last'.trim();
          studentName = fullName.isNotEmpty ? fullName : (row['name']?.toString() ?? 'Student');

          final rawStatus = row['status']?.toString().toLowerCase().trim() ?? '';
          studentStatus = (rawStatus == 'inactive') ? AccountStatus.inactive : AccountStatus.active;

          fatherName = row['father_name']?.toString();
          phone = row['phone']?.toString();
          email = row['email']?.toString();
        }
      } catch (e) {
        debugPrint('[ParentService getParentAccessForStudent Warning]: $e');
      }
    }

    // 2. Fetch linked parent from parent_students
    ParentStudentLinkModel? link;
    ParentModel? parent;

    final cachedLinks = _cachedLinks.where((l) => l.studentId == studentId && l.schoolId == activeSchoolId).toList();
    if (cachedLinks.isNotEmpty) {
      link = cachedLinks.first;
      parent = _cachedParents.where((p) => p.id == link!.parentId).firstOrNull;
    }

    if (link == null && _client != null && SupabaseConfig.isConfigured) {
      try {
        final lRow = await _client!
            .from('parent_students')
            .select()
            .eq('student_id', studentId)
            .eq('school_id', activeSchoolId)
            .maybeSingle();

        if (lRow != null) {
          link = ParentStudentLinkModel.fromJson(lRow);
          final pRow = await _client!
              .from('parents')
              .select()
              .eq('id', link.parentId)
              .maybeSingle();
          if (pRow != null) {
            parent = ParentModel.fromJson(pRow);
            if (!_cachedParents.any((p) => p.id == parent!.id)) {
              _cachedParents.add(parent);
            }
          }
        }
      } catch (_) {}
    }

    final isConfigured = code != null && code.isNotEmpty;
    final isParentActive = parent == null || parent.status == AccountStatus.active;
    final isEnabled = isConfigured && isParentActive && studentStatus == AccountStatus.active;

    return StudentParentAccessInfo(
      studentId: studentId,
      studentName: studentName,
      schoolId: activeSchoolId,
      parentAccessCode: code,
      isConfigured: isConfigured,
      isEnabled: isEnabled,
      status: isEnabled ? AccountStatus.active : AccountStatus.inactive,
      parentAccountId: parent?.id,
      parentAccountName: parent?.name ?? fatherName,
      parentCode: parent?.parentCode ?? code,
      parentPhone: parent?.phone ?? phone,
      parentEmail: parent?.email ?? email,
    );
  }

  /// Enables parent access for a student, generating a unique parent_access_code and linking parent.
  Future<StudentParentAccessInfo> enableParentAccessForStudent({
    required String studentId,
    required String schoolId,
    String? customCode,
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    final code = (customCode != null && customCode.trim().isNotEmpty)
        ? customCode.trim().toUpperCase()
        : _generateParentCode();

    String studentName = 'Student';
    String studentClass = 'Class 1-A';
    String admissionNumber = '';
    String? fatherName;
    String? phone;
    String? email;

    if (_client != null && SupabaseConfig.isConfigured) {
      // 1. Resolve student info
      try {
        final sRow = await _client!
            .from('students')
            .select()
            .eq('id', studentId)
            .eq('school_id', activeSchoolId)
            .single();

        final first = sRow['first_name']?.toString() ?? '';
        final last = sRow['last_name']?.toString() ?? '';
        final fullName = '$first $last'.trim();
        studentName = fullName.isNotEmpty ? fullName : (sRow['name']?.toString() ?? 'Student');

        final cls = sRow['class_name']?.toString() ?? '1';
        final sec = sRow['section_name']?.toString() ?? 'A';
        studentClass = '$cls-$sec';
        admissionNumber = sRow['admission_number']?.toString() ?? '';
        fatherName = sRow['father_name']?.toString();
        phone = sRow['phone']?.toString();
        email = sRow['email']?.toString();

        // 2. Set parent_access_code on students table
        await _client!
            .from('students')
            .update({
              'parent_access_code': code,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', studentId)
            .eq('school_id', activeSchoolId);

        // 3. Find or create parent record
        final pLinkRow = await _client!
            .from('parent_students')
            .select('id, parent_id')
            .eq('student_id', studentId)
            .eq('school_id', activeSchoolId)
            .maybeSingle();

        String parentId;
        if (pLinkRow != null) {
          parentId = pLinkRow['parent_id'].toString();
          await _client!
              .from('parents')
              .update({
                'status': 'ACTIVE',
                'parent_code': code,
                'parent_unique_id': code,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', parentId)
              .eq('school_id', activeSchoolId);
        } else {
          final parentName = fatherName?.isNotEmpty == true ? fatherName! : '$studentName Parent';
          final parentPhone = (phone != null && phone.isNotEmpty) ? phone : '9999988888';

          final pInsert = await _client!
              .from('parents')
              .insert({
                'school_id': activeSchoolId,
                'parent_name': parentName,
                'parent_unique_id': code,
                'parent_code': code,
                'phone': parentPhone,
                'email': email,
                'status': 'ACTIVE',
              })
              .select()
              .single();

          parentId = pInsert['id'].toString();

          await _client!
              .from('parent_students')
              .insert({
                'school_id': activeSchoolId,
                'parent_id': parentId,
                'student_id': studentId,
                'relationship': 'PARENT',
                'is_primary': true,
                'student_name': studentName,
                'student_class': studentClass,
                'admission_number': admissionNumber,
              });
        }
      } catch (e) {
        debugPrint('[ParentService enableParentAccess Error]: $e');
      }
    }

    return getParentAccessForStudent(studentId, schoolId: activeSchoolId);
  }

  /// Disables parent access for a student, setting parent_access_code to null and deactivating parent account.
  Future<StudentParentAccessInfo> disableParentAccessForStudent({
    required String studentId,
    required String schoolId,
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        // 1. Clear parent_access_code on students table
        await _client!
            .from('students')
            .update({
              'parent_access_code': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', studentId)
            .eq('school_id', activeSchoolId);

        // 2. Set linked parent status to INACTIVE
        final pLinkRow = await _client!
            .from('parent_students')
            .select('parent_id')
            .eq('student_id', studentId)
            .eq('school_id', activeSchoolId)
            .maybeSingle();

        if (pLinkRow != null) {
          final parentId = pLinkRow['parent_id'].toString();
          await _client!
              .from('parents')
              .update({
                'status': 'INACTIVE',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', parentId)
              .eq('school_id', activeSchoolId);
        }
      } catch (e) {
        debugPrint('[ParentService disableParentAccess Error]: $e');
      }
    }

    // Update in-memory cache if present
    for (int i = 0; i < _cachedParents.length; i++) {
      if (_cachedParents[i].schoolId == activeSchoolId) {
        final links = _cachedParents[i].linkedStudents;
        if (links.any((l) => l.studentId == studentId)) {
          _cachedParents[i] = _cachedParents[i].copyWith(status: AccountStatus.inactive);
        }
      }
    }
    await _saveCache();

    return getParentAccessForStudent(studentId, schoolId: activeSchoolId);
  }

  /// Regenerates parent access code for a student.
  Future<StudentParentAccessInfo> regenerateParentAccessCode({
    required String studentId,
    required String schoolId,
  }) async {
    final newCode = _generateParentCode();
    return enableParentAccessForStudent(
      studentId: studentId,
      schoolId: schoolId,
      customCode: newCode,
    );
  }

  /// Toggles status of a parent account (ACTIVE <-> INACTIVE).
  Future<ParentModel> toggleParentStatus(
    String parentId, {
    required String schoolId,
    required AccountStatus newStatus,
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!
            .from('parents')
            .update({
              'status': newStatus.name.toUpperCase(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', parentId)
            .eq('school_id', activeSchoolId);
      } catch (e) {
        debugPrint('[ParentService toggleParentStatus Warning]: $e');
      }
    }

    final pIdx = _cachedParents.indexWhere((p) => p.id == parentId);
    if (pIdx != -1) {
      _cachedParents[pIdx] = _cachedParents[pIdx].copyWith(status: newStatus);
      await _saveCache();
      return _cachedParents[pIdx];
    }

    final fetched = await getParentById(parentId);
    if (fetched != null) {
      return fetched.copyWith(status: newStatus);
    }
    throw Exception('Parent account $parentId not found.');
  }
}
