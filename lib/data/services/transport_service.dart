import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/academic_models.dart';
import '../../core/config/supabase_config.dart';
import 'tenant_resolver.dart';

class TransportService {
  final SupabaseClient? _clientOverride;

  TransportService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  String _cacheKey(String schoolId) => 'cached_transport_routes_${schoolId.trim()}';
  final Map<String, List<TransportRouteModel>> _cachedRoutesBySchool = {};

  Future<void> _loadCache(String schoolId) async {
    if (schoolId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey(schoolId));
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final list = <TransportRouteModel>[];
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              list.add(TransportRouteModel.fromJson(item));
            }
          }
          _cachedRoutesBySchool[schoolId] = list;
        }
      }
    } catch (e) {
      debugPrint('[TransportService Cache Load Warning]: $e');
    }
  }

  Future<void> _saveCache(String schoolId) async {
    if (schoolId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final routes = _cachedRoutesBySchool[schoolId] ?? [];
      await prefs.setString(_cacheKey(schoolId), jsonEncode(routes.map((r) => r.toJson()).toList()));
    } catch (e) {
      debugPrint('[TransportService Cache Save Warning]: $e');
    }
  }

  Future<String> resolveActiveSchoolId([String? schoolId]) async {
    return TenantResolver.resolveActiveSchoolId(
      client: _client,
      requestedSchoolId: schoolId,
    );
  }

  Future<List<TransportRouteModel>> fetchRoutes({String? schoolId}) async {
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    await _loadCache(activeSchoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('transport_routes')
            .select()
            .eq('school_id', activeSchoolId)
            .order('route_name', ascending: true);

        if (data.isNotEmpty) {
          final liveList = data.map((d) => TransportRouteModel.fromJson(d)).toList();
          _cachedRoutesBySchool[activeSchoolId] = liveList;
          await _saveCache(activeSchoolId);
          return liveList;
        }

        // Real Supabase mode: return real rows (empty if none exist)
        _cachedRoutesBySchool[activeSchoolId] = [];
        await _saveCache(activeSchoolId);
        return [];
      } catch (e) {
        debugPrint('[TransportService Supabase Fetch Warning]: $e');
        return List.unmodifiable(_cachedRoutesBySchool[activeSchoolId] ?? []);
      }
    }

    // Pure offline / unconfigured mock mode ONLY
    final currentCached = _cachedRoutesBySchool[activeSchoolId] ?? [];
    if (currentCached.isEmpty) {
      final seeded = _generateSeedRoutes();
      _cachedRoutesBySchool[activeSchoolId] = seeded;
      await _saveCache(activeSchoolId);
      return seeded;
    }

    return List.unmodifiable(currentCached);
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
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    await _loadCache(activeSchoolId);
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
          _cachedRoutesBySchool.putIfAbsent(activeSchoolId, () => []).add(persisted);
          await _saveCache(activeSchoolId);
          return persisted;
        }
      } catch (e) {
        debugPrint('[TransportService Supabase Insert Warning]: $e');
      }
    }

    _cachedRoutesBySchool.putIfAbsent(activeSchoolId, () => []).add(newRoute);
    await _saveCache(activeSchoolId);
    return newRoute;
  }

  Future<void> deleteRoute(String routeId, {String? schoolId}) async {
    final activeSchoolId = await resolveActiveSchoolId(schoolId);
    await _loadCache(activeSchoolId);
    final routes = _cachedRoutesBySchool[activeSchoolId] ?? [];
    routes.removeWhere((r) => r.id == routeId);
    await _saveCache(activeSchoolId);

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        await _client!
            .from('transport_routes')
            .delete()
            .eq('id', routeId)
            .eq('school_id', activeSchoolId);
      } catch (e) {
        debugPrint('[TransportService Supabase Delete Warning]: $e');
      }
    }
  }

  List<TransportRouteModel> _generateSeedRoutes() {
    return const [
      TransportRouteModel(
        id: 'rt_001',
        routeName: 'Route 1 - North Sector',
        busNumber: 'MH-12-AB-4501',
        driverName: 'Ramesh Pawar',
        driverPhone: '+91 98231 44501',
        studentCount: 34,
        stops: ['Sector 4', 'Central Market', 'Green Park', 'School Main Gate'],
      ),
      TransportRouteModel(
        id: 'rt_002',
        routeName: 'Route 2 - East Corridor',
        busNumber: 'MH-12-CD-8812',
        driverName: 'Sanjay Deshmukh',
        driverPhone: '+91 98231 44502',
        studentCount: 28,
        stops: ['Railway Colony', 'Shivaji Chowk', 'Model Town', 'School Main Gate'],
      ),
      TransportRouteModel(
        id: 'rt_003',
        routeName: 'Route 3 - South Hill View',
        busNumber: 'MH-12-EF-1044',
        driverName: 'Mohan Lal',
        driverPhone: '+91 98231 44503',
        studentCount: 42,
        stops: ['Valley View', 'Lake Road', 'Hill Crest', 'School Main Gate'],
      ),
    ];
  }
}
