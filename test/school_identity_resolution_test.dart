import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/core/config/app_config.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/school_management_app_model.dart';
import 'package:school_app/data/models/school_app_subscription_model.dart';
import 'package:school_app/data/models/school_app_access_state.dart';
import 'package:school_app/data/services/tenant_access_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('School Identity Resolution & Multi-Tenant Architecture Tests', () {
    const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const kpsAppIdentifier = 'KPS_APP';
    const legacySchoolId = 'cf895651-4783-489b-8551-959a70098ca8';
    const legacyAppIdentifier = 'SCHOOL_1_APP';

    final kpsSchool = SchoolModel(
      id: kpsSchoolId,
      schoolCode: 'KPS',
      name: 'Khalsa Public School',
      status: AccountStatus.active,
      createdAt: DateTime(2026, 8, 31),
    );

    final legacySchool = SchoolModel(
      id: legacySchoolId,
      schoolCode: 'SCHOOL-1',
      name: 'School 1',
      status: AccountStatus.active,
      createdAt: DateTime(2026, 9, 12),
    );

    final kpsApp = SchoolManagementAppModel(
      id: 'app-uuid-kps',
      schoolId: kpsSchoolId,
      appName: 'KPS Management App',
      appIdentifier: kpsAppIdentifier,
      packageName: 'com.kps.schoolapp',
      status: 'ACTIVE',
      createdAt: DateTime(2026, 8, 31),
    );

    final legacyApp = SchoolManagementAppModel(
      id: 'app-uuid-legacy',
      schoolId: legacySchoolId,
      appName: 'School 1 App',
      appIdentifier: legacyAppIdentifier,
      packageName: 'com.school1.app',
      status: 'ACTIVE',
      createdAt: DateTime(2026, 9, 12),
    );

    final kpsSubscription = SchoolAppSubscriptionModel(
      id: 'sub-uuid-kps',
      schoolAppId: 'app-uuid-kps',
      planName: 'Enterprise',
      status: 'ACTIVE',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2027, 1, 1),
      createdAt: DateTime(2026, 1, 1),
    );

    test('1. Dynamic Multi-Tenant Mode: Resolves KPS when no build flags provided', () {
      // In dynamic multi-tenant mode, configuredSchoolId and configuredAppIdentifier are null/empty.
      // Identity is authoritatively driven by the authenticated user's school.
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: kpsApp,
        subscription: kpsSubscription,
        configuredAppIdentifier: null,
        configuredSchoolId: null,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.id, equals(kpsSchoolId));
      expect(result.resolvedSchool?.name, equals('Khalsa Public School'));
      expect(result.resolvedApp?.appIdentifier, equals(kpsAppIdentifier));
      expect(result.resolvedApp?.schoolId, equals(kpsSchoolId));
    });

    test('2. Dedicated Build Mode: Matching SCHOOL_ID allows KPS access', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: kpsApp,
        subscription: kpsSubscription,
        configuredSchoolId: kpsSchoolId,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.id, equals(kpsSchoolId));
    });

    test('3. Dedicated Build Mode: Mismatched SCHOOL_ID blocks access with appMismatch', () {
      // User belongs to KPS, but app binary is built specifically for legacy school
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: kpsApp,
        subscription: kpsSubscription,
        configuredSchoolId: legacySchoolId,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appMismatch));
      expect(result.userMessage, equals('This app is not configured for this school.'));
      expect(result.detailedReason, contains('Configured school ID'));
      expect(result.detailedReason, contains(legacySchoolId));
    });

    test('4. Dedicated Build Mode: Matching APP_IDENTIFIER allows access', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: kpsApp,
        subscription: kpsSubscription,
        configuredAppIdentifier: kpsAppIdentifier,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedApp?.appIdentifier, equals(kpsAppIdentifier));
    });

    test('5. Dedicated Build Mode: Mismatched APP_IDENTIFIER blocks access with appMismatch', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: kpsApp,
        subscription: kpsSubscription,
        configuredAppIdentifier: legacyAppIdentifier, // SCHOOL_1_APP
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appMismatch));
      expect(result.detailedReason, contains('Configured app identifier ("SCHOOL_1_APP") does not match school record ("KPS_APP")'));
    });

    test('6. Cross-School Isolation: App record for School A rejects user from School B', () {
      // User profile is KPS, but app record belongs to legacy school (cross-school injection attempt)
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: legacyApp,
        subscription: kpsSubscription,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appMismatch));
      expect(result.detailedReason, contains('App school ID ("$legacySchoolId") does not match profile school ID ("$kpsSchoolId")'));
    });

    test('7. Stale Cache Clearing: AuthNotifier.clearLocalSchoolCaches erases cached data', () async {
      SharedPreferences.setMockInitialValues({
        'cached_students_data': '[{"id": "st-1"}]',
        'cached_teachers_data': '[{"id": "tc-1"}]',
        'cached_parents_data': '[{"id": "pr-1"}]',
        'cached_links_data': '[{"id": "lk-1"}]',
        'cached_books_data': '[{"id": "bk-1"}]',
        'cached_transport_routes': '[{"id": "tr-1"}]',
        'cached_salary_data': '[{"id": "sl-1"}]',
      });

      final prefsBefore = await SharedPreferences.getInstance();
      expect(prefsBefore.getString('cached_students_data'), isNotNull);
      expect(prefsBefore.getString('cached_teachers_data'), isNotNull);

      await AuthNotifier.clearLocalSchoolCaches();

      final prefsAfter = await SharedPreferences.getInstance();
      expect(prefsAfter.getString('cached_students_data'), isNull);
      expect(prefsAfter.getString('cached_teachers_data'), isNull);
      expect(prefsAfter.getString('cached_parents_data'), isNull);
      expect(prefsAfter.getString('cached_links_data'), isNull);
      expect(prefsAfter.getString('cached_books_data'), isNull);
      expect(prefsAfter.getString('cached_transport_routes'), isNull);
      expect(prefsAfter.getString('cached_salary_data'), isNull);
    });

    test('8. AppConfig: dedicated build flags and backward compatibility', () {
      expect(AppConfig.debugFallbackAppIdentifier, equals('SCHOOL_1_APP'));
      expect(AppConfig.debugFallbackDevSchoolId, equals('cf895651-4783-489b-8551-959a70098ca8'));
      expect(AppConfig.defaultAppIdentifier, equals('SCHOOL_1_APP'));
    });
  });
}
