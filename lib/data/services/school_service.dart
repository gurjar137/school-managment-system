import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/school_model.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';

class SchoolService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  static final Map<String, SchoolModel> _localCache = {};

  // --- FETCH SCHOOL PROFILE BY ID OR CODE ---
  Future<SchoolModel> fetchSchoolProfile(String schoolIdOrCode) async {
    await Future.delayed(const Duration(milliseconds: 150));

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final query = _client!.from('schools').select();
        
        final isUuid = schoolIdOrCode.contains('-');
        final data = isUuid
            ? await query.eq('id', schoolIdOrCode).maybeSingle()
            : (await query.eq('code', schoolIdOrCode).maybeSingle() ??
               await query.eq('school_code', schoolIdOrCode).maybeSingle());

        if (data != null) {
          final model = _mapDataToSchoolModel(data);
          _localCache[schoolIdOrCode] = model;
          return model;
        }

        if (schoolIdOrCode.contains('-')) {
          try {
            final rpcData = await _client!.rpc('lookup_school_by_id', params: {'p_school_id': schoolIdOrCode});
            if (rpcData is List && rpcData.isNotEmpty) {
              final row = rpcData.first;
              final model = _mapDataToSchoolModel(Map<String, dynamic>.from(row as Map));
              _localCache[schoolIdOrCode] = model;
              return model;
            } else if (rpcData is Map) {
              final model = _mapDataToSchoolModel(Map<String, dynamic>.from(rpcData));
              _localCache[schoolIdOrCode] = model;
              return model;
            }
          } catch (_) {}
        } else {
          try {
            final rpcData = await _client!.rpc('lookup_school_by_code', params: {'p_code': schoolIdOrCode.toUpperCase().trim()});
            if (rpcData is List && rpcData.isNotEmpty) {
              final row = rpcData.first;
              final model = _mapDataToSchoolModel(Map<String, dynamic>.from(row as Map));
              _localCache[schoolIdOrCode] = model;
              return model;
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[SchoolService Supabase Warning]: $e');
      }
    }

    if (_localCache.containsKey(schoolIdOrCode)) {
      return _localCache[schoolIdOrCode]!;
    }

    return SchoolModel(
      id: schoolIdOrCode,
      schoolCode: '—',
      name: 'School',
      createdAt: DateTime.now(),
    );
  }

  // --- FETCH SCHOOL BY HUMAN-FRIENDLY CODE (SCH001) ---
  Future<SchoolModel?> fetchSchoolByCode(String schoolCode) async {
    await Future.delayed(const Duration(milliseconds: 150));

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = (await _client!
            .from('schools')
            .select()
            .eq('code', schoolCode.toUpperCase().trim())
            .maybeSingle()) ??
            (await _client!
            .from('schools')
            .select()
            .eq('school_code', schoolCode.toUpperCase().trim())
            .maybeSingle());

        if (data != null) {
          return _mapDataToSchoolModel(data);
        }
      } catch (e) {
        debugPrint('[SchoolService FetchByCode Warning]: $e');
      }
    }

    return null;
  }

  // --- UPDATE SCHOOL CONFIGURATION / PROFILE ---
  Future<SchoolModel> updateSchoolProfile({
    required String schoolId,
    required String name,
    String? address,
    String? phone,
    String? email,
    String? logoUrl,
  }) async {
    final cleanId = schoolId.trim();
    if (cleanId.isEmpty) {
      throw Exception('School ID is required to update school configuration.');
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('School name cannot be empty.');
    }

    if (_client != null && SupabaseConfig.isConfigured) {
      final updateData = <String, dynamic>{
        'name': cleanName,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (address != null) updateData['address'] = address.trim();
      if (phone != null) updateData['phone'] = phone.trim();
      if (email != null) updateData['email'] = email.trim();
      if (logoUrl != null) updateData['logo_url'] = logoUrl.trim();

      // 1. Check whether a matching school record already exists
      final isUuid = cleanId.contains('-');
      Map<String, dynamic>? existingRow;
      try {
        existingRow = isUuid
            ? await _client!.from('schools').select().eq('id', cleanId).maybeSingle()
            : (await _client!.from('schools').select().eq('code', cleanId).maybeSingle() ??
               await _client!.from('schools').select().eq('school_code', cleanId).maybeSingle());
      } catch (e) {
        debugPrint('[SchoolService check existing error]: $e');
      }

      if (existingRow != null) {
        // Record exists -> UPDATE
        final targetId = existingRow['id']?.toString() ?? cleanId;
        try {
          final res = await _client!
              .from('schools')
              .update(updateData)
              .eq('id', targetId)
              .select()
              .maybeSingle();

          if (res != null) {
            final model = _mapDataToSchoolModel(Map<String, dynamic>.from(res));
            _localCache[cleanId] = model;
            return model;
          }

          // Fallback query if update select didn't return row
          final fetched = await _client!.from('schools').select().eq('id', targetId).maybeSingle();
          if (fetched != null) {
            final model = _mapDataToSchoolModel(Map<String, dynamic>.from(fetched));
            _localCache[cleanId] = model;
            return model;
          }
        } on PostgrestException catch (e) {
          debugPrint('[SchoolService update error]: ${e.code} ${e.message}');
          throw Exception('Failed to update school configuration: ${e.message}');
        }
      } else {
        // Record does NOT exist -> Safely INSERT/UPSERT for the authorized school
        final insertData = <String, dynamic>{
          'name': cleanName,
          'status': 'ACTIVE',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        if (isUuid) {
          insertData['id'] = cleanId;
          insertData['code'] = 'SCH-${cleanId.substring(0, 6).toUpperCase()}';
        } else {
          insertData['code'] = cleanId.toUpperCase();
        }
        if (address != null) insertData['address'] = address.trim();
        if (phone != null) insertData['phone'] = phone.trim();
        if (email != null) insertData['email'] = email.trim();
        if (logoUrl != null) insertData['logo_url'] = logoUrl.trim();

        try {
          final insertRes = await _client!
              .from('schools')
              .upsert(insertData, onConflict: isUuid ? 'id' : 'code')
              .select()
              .maybeSingle();

          if (insertRes != null) {
            final model = _mapDataToSchoolModel(Map<String, dynamic>.from(insertRes));
            _localCache[cleanId] = model;
            return model;
          }
        } on PostgrestException catch (e) {
          debugPrint('[SchoolService insert error]: ${e.code} ${e.message}');
          throw Exception('Failed to save new school configuration: ${e.message}');
        }
      }
    }

    // Local / offline fallback
    final model = SchoolModel(
      id: cleanId,
      schoolCode: cleanId.contains('-') ? 'SCH-${cleanId.substring(0, 6).toUpperCase()}' : cleanId.toUpperCase(),
      name: cleanName,
      address: address?.trim(),
      phone: phone?.trim(),
      email: email?.trim(),
      logoUrl: logoUrl,
      createdAt: DateTime.now(),
    );
    _localCache[cleanId] = model;
    return model;
  }

  SchoolModel _mapDataToSchoolModel(Map<String, dynamic> data) {
    return SchoolModel(
      id: data['id']?.toString() ?? '',
      schoolCode: data['code']?.toString() ?? data['school_code']?.toString() ?? '—',
      name: data['name']?.toString() ?? 'School',
      address: data['address']?.toString(),
      phone: data['phone']?.toString(),
      email: data['email']?.toString(),
      logoUrl: data['logo_url']?.toString(),
      appName: data['app_name']?.toString(),
      primaryColor: data['primary_color']?.toString(),
      secondaryColor: data['secondary_color']?.toString(),
      status: _parseStatus(data['status']?.toString()),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  AccountStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toUpperCase()) {
      case 'INACTIVE':
        return AccountStatus.inactive;
      case 'SUSPENDED':
        return AccountStatus.suspended;
      case 'ACTIVE':
      default:
        return AccountStatus.active;
    }
  }
}
