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

  static final SchoolModel _defaultMockSchool = SchoolModel(
    id: 'mock_school_1',
    schoolCode: 'SCH001',
    name: 'St. Xavier International School',
    logoUrl: 'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=150',
    appName: 'School Command OS',
    primaryColor: '#1E293B',
    secondaryColor: '#6366F1',
    status: AccountStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );

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
          return _mapDataToSchoolModel(data);
        }

        if (!schoolIdOrCode.contains('-')) {
          try {
            final rpcData = await _client!.rpc('lookup_school_by_code', params: {'p_code': schoolIdOrCode.toUpperCase().trim()});
            if (rpcData is List && rpcData.isNotEmpty) {
              final row = rpcData.first;
              return _mapDataToSchoolModel(Map<String, dynamic>.from(row as Map));
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[SchoolService Supabase Warning]: $e');
      }
    }

    return _defaultMockSchool;
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

    if (schoolCode.toUpperCase().trim() == 'SCH001') {
      return _defaultMockSchool;
    }
    return null;
  }

  SchoolModel _mapDataToSchoolModel(Map<String, dynamic> data) {
    return SchoolModel(
      id: data['id']?.toString() ?? '',
      schoolCode: data['code']?.toString() ?? data['school_code']?.toString() ?? '—',
      name: data['name']?.toString() ?? 'School',
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
