import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/academic_models.dart';
import '../../core/config/supabase_config.dart';
import '../../core/errors/exceptions.dart';

class TransportService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  static const String _cacheKey = 'cached_transport_routes_data';
  final List<TransportRouteModel> _cachedRoutes = [];
  bool _isCacheLoaded = false;

  Future<void> _loadCache() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          _cachedRoutes.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _cachedRoutes.add(TransportRouteModel.fromJson(item));
            }
          }
        }
      }
      _isCacheLoaded = true;
    } catch (e) {
      debugPrint('[TransportService Cache Load Warning]: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cachedRoutes.map((r) => r.toJson()).toList()));
    } catch (e) {
      debugPrint('[TransportService Cache Save Warning]: $e');
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
      throw const TenantResolutionException('Active school could not be resolved for current user. Please log in again.');
    }
    return '6254bee9-151d-4332-8a1c-3994af7d2153';
  }

  Future<List<TransportRouteModel>> fetchRoutes({String? schoolId}) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('transport_routes')
            .select()
            .eq('school_id', activeSchoolId)
            .order('route_name', ascending: true);

        if (data.isNotEmpty) {
          final liveList = data.map((d) => TransportRouteModel.fromJson(d)).toList();
          _cachedRoutes.clear();
          _cachedRoutes.addAll(liveList);
          await _saveCache();
          return liveList;
        }
      } catch (e) {
        debugPrint('[TransportService Supabase Fetch Warning]: $e');
      }
    }

    if (_cachedRoutes.isEmpty) {
      _seedInitialRoutes();
      await _saveCache();
    }

    return List.unmodifiable(_cachedRoutes);
  }

  Future<TransportRouteModel> addRoute({
    String? schoolId,
    required String routeName,
    required String busNumber,
    required String driverName,
    required String driverPhone,
    int studentCount = 0,
    required List<String> stops,
  }) async {
    await _loadCache();
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    final routeId = 'route_${DateTime.now().millisecondsSinceEpoch}';

    final newRoute = TransportRouteModel(
      id: routeId,
      routeName: routeName.trim(),
      busNumber: busNumber.trim(),
      driverName: driverName.trim(),
      driverPhone: driverPhone.trim(),
      studentCount: studentCount,
      stops: stops,
    );

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final resp = await _client!.from('transport_routes').insert({
          'school_id': activeSchoolId,
          'route_name': newRoute.routeName,
          'bus_number': newRoute.busNumber,
          'driver_name': newRoute.driverName,
          'driver_phone': newRoute.driverPhone,
          'student_count': newRoute.studentCount,
          'stops': newRoute.stops,
        }).select().maybeSingle();

        if (resp != null && resp['id'] != null) {
          final persisted = TransportRouteModel.fromJson(resp);
          _cachedRoutes.add(persisted);
          await _saveCache();
          return persisted;
        }
      } catch (e) {
        debugPrint('[TransportService Supabase Insert Warning]: $e');
      }
    }

    _cachedRoutes.add(newRoute);
    await _saveCache();
    return newRoute;
  }

  Future<void> deleteRoute(String routeId) async {
    await _loadCache();
    _cachedRoutes.removeWhere((r) => r.id == routeId);
    await _saveCache();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!.from('transport_routes').delete().eq('id', routeId);
      } catch (e) {
        debugPrint('[TransportService Supabase Delete Warning]: $e');
      }
    }
  }

  void _seedInitialRoutes() {
    _cachedRoutes.addAll([
      const TransportRouteModel(
        id: 'rt_001',
        routeName: 'Route 1 - North Sector',
        busNumber: 'MH-12-AB-4501',
        driverName: 'Ramesh Pawar',
        driverPhone: '+91 98231 44501',
        studentCount: 34,
        stops: ['Sector 4', 'Central Market', 'Green Park', 'School Main Gate'],
      ),
      const TransportRouteModel(
        id: 'rt_002',
        routeName: 'Route 2 - East Corridor',
        busNumber: 'MH-12-CD-8812',
        driverName: 'Sanjay Deshmukh',
        driverPhone: '+91 98231 44502',
        studentCount: 28,
        stops: ['Railway Colony', 'Shivaji Chowk', 'Model Town', 'School Main Gate'],
      ),
      const TransportRouteModel(
        id: 'rt_003',
        routeName: 'Route 3 - South Hill View',
        busNumber: 'MH-12-EF-1044',
        driverName: 'Mohan Lal',
        driverPhone: '+91 98231 44503',
        studentCount: 42,
        stops: ['Valley View', 'Lake Road', 'Hill Crest', 'School Main Gate'],
      ),
    ]);
  }
}
