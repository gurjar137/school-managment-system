import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/access_models.dart';

class AccessService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  final List<TeacherAccessModel> _teacherAccessRecords = [];
  final Map<String, ParentAccessCodeModel> _parentCodeMap = {};
  final List<ActivityLogModel> _activityLogs = [];

  AccessService();

  // Code Generator: Format SC-XXXX-XXXX, avoiding confusing characters (O, 0, I, 1, L)
  static String generateUniqueParentCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random();
    String part1 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    String part2 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
    return 'SC-$part1-$part2';
  }

  // --- TEACHER ACCESS METHODS ---
  Future<List<TeacherAccessModel>> getTeacherAccessAccounts() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_teacherAccessRecords);
  }

  Future<void> addTeacherAccess(TeacherAccessModel record) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _teacherAccessRecords.insert(0, record);
    _logActivity('Teacher Access Added', 'Authorized email ${record.email} added for ${record.teacherName}', 'Teacher Access');
  }

  Future<void> updateTeacherAccess(TeacherAccessModel updated) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _teacherAccessRecords.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      _teacherAccessRecords[idx] = updated;
      _logActivity('Teacher Access Updated', 'Updated credentials for ${updated.teacherName} (${updated.email})', 'Teacher Access');
    }
  }

  Future<void> toggleTeacherAccessStatus(String id, bool enable) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _teacherAccessRecords.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final current = _teacherAccessRecords[idx];
      _teacherAccessRecords[idx] = current.copyWith(isEnabled: enable);
      _logActivity(
        enable ? 'Teacher Access Enabled' : 'Teacher Access Disabled',
        'Login permissions for ${current.teacherName} (${current.email}) set to ${enable ? "ENABLED" : "DISABLED"}',
        'Teacher Access',
      );
    }
  }

  // --- PARENT ACCESS CODE METHODS ---
  Future<ParentAccessCodeModel?> getParentCodeForStudent(String studentId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final row = await _client!
            .from('students')
            .select()
            .eq('id', studentId)
            .maybeSingle();

        if (row != null) {
          String code = row['parent_access_code']?.toString().trim() ?? '';
          if (code.isEmpty) {
            code = generateUniqueParentCode();
            try {
              await _client!
                  .from('students')
                  .update({'parent_access_code': code})
                  .eq('id', studentId);
            } catch (e) {
              debugPrint('[AccessService Update Error]: $e');
            }
          }

          final studentName = row['name'] ?? '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
          final admNo = row['admission_number']?.toString() ?? '';
          final cls = row['class_name']?.toString() ?? '';
          final sec = row['section_name']?.toString() ?? row['section']?.toString() ?? '';
          final father = row['father_name']?.toString() ?? '';
          final phone = row['phone']?.toString() ?? row['father_mobile']?.toString() ?? '';
          final isRevoked = row['status'] == 'INACTIVE';

          final model = ParentAccessCodeModel(
            id: 'pac_$studentId',
            studentId: studentId,
            studentName: studentName.isNotEmpty ? studentName : 'Student',
            admissionNo: admNo,
            className: '$cls-$sec',
            parentName: father.isNotEmpty ? father : 'Parent',
            parentMobile: phone,
            code: code,
            isRevoked: isRevoked,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _parentCodeMap[studentId] = model;
          return model;
        }
      } catch (e) {
        debugPrint('[AccessService getParentCodeForStudent Warning]: $e');
      }
    }

    return _parentCodeMap[studentId];
  }

  Future<String> generateUniqueDatabaseParentCode() async {
    for (int i = 0; i < 15; i++) {
      final code = generateUniqueParentCode();
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
    return generateUniqueParentCode();
  }

  Future<ParentAccessCodeModel> regenerateParentCode(String studentId) async {
    final newCodeStr = await generateUniqueDatabaseParentCode();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!
            .from('students')
            .update({'parent_access_code': newCodeStr})
            .eq('id', studentId);
      } catch (e) {
        debugPrint('[AccessService regenerateParentCode Warning]: $e');
      }
    }

    final current = await getParentCodeForStudent(studentId);
    if (current == null) {
      throw Exception('Student record not found.');
    }
    final updated = current.copyWith(
      code: newCodeStr,
      isRevoked: false,
      regeneratedAt: DateTime.now(),
    );

    _parentCodeMap[studentId] = updated;
    _logActivity(
      'Parent Code Regenerated',
      'New Parent Access Code ($newCodeStr) issued for ${updated.studentName}',
      'Parent Access',
    );
    return updated;
  }

  Future<void> revokeParentAccess(String studentId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!
            .from('students')
            .update({'parent_access_code': null, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', studentId);
      } catch (e) {
        debugPrint('[AccessService revokeParentAccess Warning]: $e');
      }
    }
    final current = await getParentCodeForStudent(studentId);
    if (current != null) {
      final updated = current.copyWith(isRevoked: true);
      _parentCodeMap[studentId] = updated;
      _logActivity(
        'Parent Access Revoked',
        'Parent Access Code revoked for ${updated.studentName}',
        'Parent Access',
      );
    }
  }

  Future<List<ParentAccessCodeModel>> getAllParentCodes({
    String? query,
    String? className,
    bool? onlyRevoked,
  }) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final rows = await _client!.from('students').select();
        if (rows is List && rows.isNotEmpty) {
          final List<ParentAccessCodeModel> list = [];
          for (final row in rows) {
            final studentId = row['id']?.toString() ?? '';
            String code = row['parent_access_code']?.toString().trim() ?? '';
            if (code.isEmpty) {
              code = generateUniqueParentCode();
              _client!.from('students').update({'parent_access_code': code}).eq('id', studentId).catchError((_) {});
            }
            final studentName = row['name'] ?? '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim();
            final admNo = row['admission_number']?.toString() ?? '';
            final cls = row['class_name']?.toString() ?? '';
            final sec = row['section_name']?.toString() ?? row['section']?.toString() ?? '';
            final father = row['father_name']?.toString() ?? '';
            final phone = row['phone']?.toString() ?? row['father_mobile']?.toString() ?? '';
            final isRevoked = row['status'] == 'INACTIVE';

            list.add(ParentAccessCodeModel(
              id: 'pac_$studentId',
              studentId: studentId,
              studentName: studentName.isNotEmpty ? studentName : 'Student',
              admissionNo: admNo,
              className: '$cls-$sec',
              parentName: father.isNotEmpty ? father : 'Parent',
              parentMobile: phone,
              code: code,
              isRevoked: isRevoked,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
          }

          var filtered = list;
          if (className != null && className != 'All') {
            filtered = filtered.where((p) => p.className.contains(className)).toList();
          }
          if (onlyRevoked == true) {
            filtered = filtered.where((p) => p.isRevoked).toList();
          }
          if (query != null && query.trim().isNotEmpty) {
            final q = query.toLowerCase().trim();
            filtered = filtered.where((p) {
              return p.studentName.toLowerCase().contains(q) ||
                  p.admissionNo.toLowerCase().contains(q) ||
                  p.code.toLowerCase().contains(q) ||
                  p.parentName.toLowerCase().contains(q) ||
                  p.parentMobile.contains(q);
            }).toList();
          }
          return filtered;
        }
      } catch (e) {
        debugPrint('[AccessService getAllParentCodes Warning]: $e');
      }
    }

    var list = _parentCodeMap.values.toList();

    if (className != null && className != 'All') {
      list = list.where((p) => p.className.contains(className)).toList();
    }

    if (onlyRevoked == true) {
      list = list.where((p) => p.isRevoked).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      list = list.where((p) {
        return p.studentName.toLowerCase().contains(q) ||
            p.admissionNo.toLowerCase().contains(q) ||
            p.code.toLowerCase().contains(q) ||
            p.parentName.toLowerCase().contains(q) ||
            p.parentMobile.contains(q);
      }).toList();
    }

    return list;
  }

  // Telemetry Metrics
  Future<Map<String, int>> getAccessTelemetry() async {
    await Future.delayed(const Duration(milliseconds: 100));
    final totalTeachers = _teacherAccessRecords.length;
    final activeTeachers = _teacherAccessRecords.where((t) => t.isEnabled).length;
    final disabledTeachers = totalTeachers - activeTeachers;

    final totalStudents = _parentCodeMap.length;
    final activeCodes = _parentCodeMap.values.where((p) => p.isActive).length;
    final revokedCodes = _parentCodeMap.values.where((p) => p.isRevoked).length;

    return {
      'totalTeachers': totalTeachers,
      'activeTeachers': activeTeachers,
      'disabledTeachers': disabledTeachers,
      'totalStudents': totalStudents,
      'activeCodes': activeCodes,
      'revokedCodes': revokedCodes,
    };
  }

  // --- ACTIVITY LOG METHODS ---
  Future<List<ActivityLogModel>> getActivityLogs() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_activityLogs);
  }

  void _logActivity(String title, String details, String category) {
    _activityLogs.insert(
      0,
      ActivityLogModel(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        actionTitle: title,
        details: details,
        adminName: 'School Administrator',
        timestamp: DateTime.now(),
        category: category,
      ),
    );
  }
}
