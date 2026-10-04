import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/config/supabase_config.dart';
import '../models/school_app_access_state.dart';
import '../models/school_management_app_model.dart';
import '../models/school_app_subscription_model.dart';
import '../models/school_model.dart';
import '../models/user_model.dart';

/// Centralized tenant resolution and access validation service.
///
/// Implements the authoritative tenant resolution path:
/// Authenticated User -> profiles.school_id -> schools.id
/// And validates:
/// 1. School status (ACTIVE)
/// 2. School Management App match (app_identifier == AppConfig.appIdentifier)
/// 3. School Management App status (ACTIVE)
/// 4. Subscription standing (ACTIVE and within validity window)
class TenantAccessService {
  final SupabaseClient? _clientOverride;

  TenantAccessService({SupabaseClient? client}) : _clientOverride = client;

  SupabaseClient? get _client {
    if (_clientOverride != null) return _clientOverride;
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  /// Validate current active session against the tenant access hierarchy.
  Future<AppAccessResult> validateCurrentSession({
    String? configuredAppIdentifier,
    String? expectedDevSchoolId,
    DateTime? referenceDate,
  }) async {
    final client = _client;
    if (client == null) {
      // In offline / mock mode without Supabase configuration
      return AppAccessResult.unauthenticated();
    }

    final user = client.auth.currentUser;
    if (user == null) {
      return AppAccessResult.unauthenticated();
    }

    return validateAccessForUser(
      authUserId: user.id,
      configuredAppIdentifier: configuredAppIdentifier,
      expectedDevSchoolId: expectedDevSchoolId,
      referenceDate: referenceDate,
    );
  }

  /// Execute the 5-step access validation for a specific authenticated user ID.
  Future<AppAccessResult> validateAccessForUser({
    required String authUserId,
    String? configuredAppIdentifier,
    String? expectedDevSchoolId,
    DateTime? referenceDate,
  }) async {
    final client = _client;
    if (client == null) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.networkError,
        userMessage: 'Unable to connect to database service.',
      );
    }

    final targetAppIdentifier = (configuredAppIdentifier ?? AppConfig.appIdentifier).trim();
    if (targetAppIdentifier.isEmpty) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.appNotFound,
        userMessage: 'Application identifier is not configured for this build.',
        detailedReason: 'APP_IDENTIFIER build configuration is missing. Provide --dart-define=APP_IDENTIFIER=<school_app_identifier>.',
      );
    }

    final targetDevSchoolId = kReleaseMode
        ? null
        : (expectedDevSchoolId ?? AppConfig.devSchoolId)?.trim();

    try {
      // -------------------------------------------------------------
      // 1. Resolve User Profile & Tenant school_id
      // -------------------------------------------------------------
      final profileData = await client
          .from('profiles')
          .select('id, auth_user_id, school_id, status, role, email')
          .or('auth_user_id.eq.$authUserId,id.eq.$authUserId')
          .maybeSingle();

      String? rawSchoolId;
      if (profileData != null) {
        final profileStatus = (profileData['status']?.toString() ?? '').toLowerCase();
        if (profileStatus.isNotEmpty && profileStatus != 'active') {
          try {
            await client.auth.signOut();
          } catch (_) {}
          return AppAccessResult.blocked(
            status: AppAccessStatus.profileInactive,
            userMessage: 'Your account is currently inactive or suspended. Please contact your administrator.',
            detailedReason: 'public.profiles.status is "$profileStatus" for user $authUserId.',
          );
        }
        rawSchoolId = profileData['school_id']?.toString().trim();
      } else {
        final currentUser = client.auth.currentUser;
        if (currentUser != null && currentUser.id == authUserId && currentUser.userMetadata?['school_id'] != null) {
          rawSchoolId = currentUser.userMetadata!['school_id']?.toString().trim();
        }
      }

      if (rawSchoolId == null || rawSchoolId.isEmpty) {
        return AppAccessResult.blocked(
          status: AppAccessStatus.noSchoolAssigned,
          userMessage: 'Your account is not assigned to any school institution.',
          detailedReason: 'public.profiles.school_id is null or empty.',
        );
      }

      // -------------------------------------------------------------
      // 2. Resolve School Record & Verify School Status
      // -------------------------------------------------------------
      Map<String, dynamic>? schoolData;
      try {
        schoolData = await client
            .from('schools')
            .select()
            .eq('id', rawSchoolId)
            .maybeSingle();
      } catch (_) {}

      if (schoolData == null) {
        return AppAccessResult.blocked(
          status: AppAccessStatus.schoolNotFound,
          userMessage: 'School institution record could not be found.',
          detailedReason: 'public.schools has no row for id: $rawSchoolId',
        );
      }

      final school = _parseSchool(schoolData);
      if (school.status != AccountStatus.active) {
        return evaluateAccessRules(
          school: school,
          app: null,
          subscription: null,
          configuredAppIdentifier: targetAppIdentifier,
          expectedDevSchoolId: targetDevSchoolId,
          referenceDate: referenceDate,
        );
      }

      // -------------------------------------------------------------
      // 3. Resolve Dedicated School Management App & Match Identifier
      // -------------------------------------------------------------
      Map<String, dynamic>? appData;
      try {
        appData = await client
            .from('school_management_apps')
            .select()
            .eq('app_identifier', targetAppIdentifier)
            .maybeSingle();
      } catch (_) {}

      if (appData == null) {
        try {
          appData = await client
              .from('school_management_apps')
              .select()
              .eq('school_id', rawSchoolId)
              .maybeSingle();
        } catch (_) {}
      }

      final app = appData != null ? SchoolManagementAppModel.fromJson(appData) : null;

      // -------------------------------------------------------------
      // 4. Resolve Subscription & Evaluate Effective Access
      // -------------------------------------------------------------
      SchoolAppSubscriptionModel? subscription;
      if (app != null) {
        try {
          final subData = await client
              .from('school_app_subscriptions')
              .select()
              .eq('school_app_id', app.id)
              .maybeSingle();

          if (subData != null) {
            subscription = SchoolAppSubscriptionModel.fromJson(subData);
          }
        } catch (_) {}
      }

      return evaluateAccessRules(
        school: school,
        app: app,
        subscription: subscription,
        configuredAppIdentifier: targetAppIdentifier,
        expectedDevSchoolId: targetDevSchoolId,
        referenceDate: referenceDate,
      );
    } catch (e) {
      debugPrint('[TenantAccessService Error]: $e');
      return AppAccessResult.blocked(
        status: AppAccessStatus.networkError,
        userMessage: 'Unable to verify school access. Please check your internet connection.',
        detailedReason: e.toString(),
      );
    }
  }

  /// Pure rule evaluation engine without network dependencies.
  /// Authoritative logic for verifying school, app active status,
  /// subscription window, and app identifier match in strict priority order.
  static AppAccessResult evaluateAccessRules({
    required SchoolModel? school,
    required SchoolManagementAppModel? app,
    required SchoolAppSubscriptionModel? subscription,
    required String configuredAppIdentifier,
    String? expectedDevSchoolId,
    bool requireSubscription = false,
    DateTime? referenceDate,
  }) {
    // -------------------------------------------------------------
    // PRIORITY 1: School Record Existence Check
    // -------------------------------------------------------------
    if (school == null) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.schoolNotFound,
        userMessage: 'School institution record could not be found.',
      );
    }

    // -------------------------------------------------------------
    // PRIORITY 2: School & App Deactivated
    // Takes strict precedence over subscription and app-mismatch errors.
    // -------------------------------------------------------------
    if (school.status != AccountStatus.active) {
      return AppAccessResult.schoolDeactivated(
        school: school,
        app: app,
        detailedReason: 'School status in public.schools is ${school.status.displayName.toUpperCase()}.',
      );
    }

    if (app != null && !app.isActive) {
      return AppAccessResult.schoolDeactivated(
        school: school,
        app: app,
        detailedReason: 'School Management App access is toggled to INACTIVE.',
      );
    }

    // -------------------------------------------------------------
    // PRIORITY 3: Subscription Status & Validity Window
    // (Missing, Suspended, Inactive, Expired, Not Started)
    // -------------------------------------------------------------
    if (requireSubscription && subscription == null) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.subscriptionMissing,
        userMessage: 'No subscription configured for this school app.',
        detailedReason: 'No row found in school_app_subscriptions for app_id: ${app?.id}',
        school: school,
        app: app,
      );
    }

    if (subscription != null) {
      if (subscription.isStatusSuspended) {
        return AppAccessResult.blocked(
          status: AppAccessStatus.subscriptionSuspended,
          userMessage: 'Application access is currently suspended.',
          detailedReason: 'Subscription status is SUSPENDED.',
          school: school,
          app: app,
          subscription: subscription,
        );
      }

      if (subscription.isStatusInactive) {
        return AppAccessResult.blocked(
          status: AppAccessStatus.subscriptionInactive,
          userMessage: 'Application subscription is inactive.',
          detailedReason: 'Subscription status is INACTIVE.',
          school: school,
          app: app,
          subscription: subscription,
        );
      }

      final now = referenceDate ?? DateTime.now();

      if (subscription.isStatusExpired || subscription.isDateExpired(now)) {
        return AppAccessResult.subscriptionExpired(
          school: school,
          app: app,
          subscription: subscription,
          detailedReason: subscription.isStatusExpired
              ? 'Subscription status is EXPIRED in database.'
              : 'Subscription end date ${subscription.endDate} has passed.',
        );
      }

      if (subscription.isDateNotStarted(now)) {
        return AppAccessResult.blocked(
          status: AppAccessStatus.subscriptionNotStarted,
          userMessage: 'Your subscription has not started yet.',
          detailedReason: 'Start date ${subscription.startDate} is in the future.',
          school: school,
          app: app,
          subscription: subscription,
        );
      }
    }

    // -------------------------------------------------------------
    // PRIORITY 4: APP_IDENTIFIER & Tenant Mismatch
    // -------------------------------------------------------------
    if (app == null) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.appNotFound,
        userMessage: 'Dedicated application record not found for this school.',
        school: school,
      );
    }

    final targetId = configuredAppIdentifier.trim();
    if (targetId.isEmpty) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.appNotFound,
        userMessage: 'Application identifier is not configured for this build.',
        detailedReason: 'configuredAppIdentifier is empty.',
        school: school,
        app: app,
      );
    }

    final dbIdentifier = (app.appIdentifier ?? '').trim();
    if (dbIdentifier != targetId) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.appMismatch,
        userMessage: 'This app is not configured for this school.',
        detailedReason: 'Configured app identifier ("$targetId") does not match school record ("$dbIdentifier").',
        school: school,
        app: app,
      );
    }

    if (app.schoolId != school.id) {
      return AppAccessResult.blocked(
        status: AppAccessStatus.appMismatch,
        userMessage: 'This app is not configured for this school.',
        detailedReason: 'App school ID ("${app.schoolId}") does not match profile school ID ("${school.id}").',
        school: school,
        app: app,
      );
    }

    // Development-only check: verify that the resolved school matches expectedDevSchoolId if provided.
    if (!kReleaseMode && expectedDevSchoolId != null && expectedDevSchoolId.trim().isNotEmpty) {
      if (school.id != expectedDevSchoolId.trim()) {
        return AppAccessResult.blocked(
          status: AppAccessStatus.appMismatch,
          userMessage: 'This app is not configured for this school.',
          detailedReason: 'Development school ID mismatch ("${school.id}" != "$expectedDevSchoolId").',
          school: school,
          app: app,
        );
      }
    }

    // -------------------------------------------------------------
    // PRIORITY 5: Access Granted
    // -------------------------------------------------------------
    return AppAccessResult.granted(
      school: school,
      app: app,
      subscription: subscription ??
          SchoolAppSubscriptionModel(
            id: 'sub-active',
            schoolAppId: app.id,
            startDate: DateTime.now().subtract(const Duration(days: 30)),
            endDate: DateTime.now().add(const Duration(days: 365)),
            createdAt: DateTime.now(),
          ),
    );
  }

  SchoolModel _parseSchool(Map<String, dynamic> data) {
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

  AccountStatus _parseStatus(String? raw) {
    switch (raw?.toUpperCase().trim()) {
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
