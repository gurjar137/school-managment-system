import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_preferences_model.dart';
import '../../core/config/supabase_config.dart';

class NotificationPreferencesService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  static const String _prefPrefix = 'notif_prefs_';

  String _cacheKey(String schoolId, String? userId) {
    final cleanSchool = schoolId.trim();
    if (userId != null && userId.trim().isNotEmpty) {
      return '$_prefPrefix${cleanSchool}_${userId.trim()}';
    }
    return '$_prefPrefix$cleanSchool';
  }

  /// Fetch preferences for the verified school and optional user.
  Future<NotificationPreferencesModel> getPreferences(String schoolId, {String? userId}) async {
    final cleanSchoolId = schoolId.trim();
    if (cleanSchoolId.isEmpty) {
      return NotificationPreferencesModel.defaults('default');
    }

    // 1. Try reading from Supabase
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        var query = _client!
            .from('notification_preferences')
            .select()
            .eq('school_id', cleanSchoolId);

        if (userId != null && userId.trim().isNotEmpty) {
          query = query.eq('user_id', userId.trim());
        }

        final res = await query.maybeSingle();
        if (res != null) {
          final model = NotificationPreferencesModel.fromJson(Map<String, dynamic>.from(res));
          await _saveToCache(model);
          return model;
        }
      } catch (e) {
        debugPrint('[NotificationPreferencesService getPreferences warning]: $e');
      }
    }

    // 2. Read from local cache
    final cached = await _readFromCache(cleanSchoolId, userId);
    if (cached != null) {
      return cached;
    }

    // 3. Return defaults and persist locally
    final defaults = NotificationPreferencesModel.defaults(cleanSchoolId, userId: userId);
    await _saveToCache(defaults);
    return defaults;
  }

  /// Save or update preferences to local cache and Supabase.
  Future<NotificationPreferencesModel> savePreferences(NotificationPreferencesModel prefs) async {
    final updated = prefs.copyWith(updatedAt: DateTime.now());

    // 1. Save to local cache first
    await _saveToCache(updated);

    // 2. Sync to Supabase
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final payload = updated.toJson();
        await _client!
            .from('notification_preferences')
            .upsert(payload)
            .select()
            .maybeSingle();
      } catch (e) {
        debugPrint('[NotificationPreferencesService savePreferences DB warning]: $e');
      }
    }

    return updated;
  }

  /// Update individual alert toggle.
  Future<NotificationPreferencesModel> updateToggle({
    required String schoolId,
    String? userId,
    bool? timetableAlerts,
    bool? attendanceAlerts,
    bool? feeAlerts,
    bool? pushEnabled,
  }) async {
    final current = await getPreferences(schoolId, userId: userId);
    final updated = current.copyWith(
      timetableAlerts: timetableAlerts ?? current.timetableAlerts,
      attendanceAlerts: attendanceAlerts ?? current.attendanceAlerts,
      feeAlerts: feeAlerts ?? current.feeAlerts,
      pushEnabled: pushEnabled ?? current.pushEnabled,
    );
    return await savePreferences(updated);
  }

  /// Workflow check helpers
  Future<bool> isTimetableAlertEnabled(String schoolId, {String? userId}) async {
    final p = await getPreferences(schoolId, userId: userId);
    return p.timetableAlerts;
  }

  Future<bool> isAttendanceWarningEnabled(String schoolId, {String? userId}) async {
    final p = await getPreferences(schoolId, userId: userId);
    return p.attendanceAlerts;
  }

  Future<bool> isFeeReminderEnabled(String schoolId, {String? userId}) async {
    final p = await getPreferences(schoolId, userId: userId);
    return p.feeAlerts;
  }

  // --- Local Cache Helpers ---
  Future<void> _saveToCache(NotificationPreferencesModel prefs) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = _cacheKey(prefs.schoolId, prefs.userId);
      await sp.setString(key, jsonEncode(prefs.toJson()));
    } catch (e) {
      debugPrint('[NotificationPreferencesService _saveToCache error]: $e');
    }
  }

  Future<NotificationPreferencesModel?> _readFromCache(String schoolId, String? userId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = _cacheKey(schoolId, userId);
      final raw = sp.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return NotificationPreferencesModel.fromJson(data);
      }
    } catch (e) {
      debugPrint('[NotificationPreferencesService _readFromCache error]: $e');
    }
    return null;
  }
}
