import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/config/app_config.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/models/school_management_app_model.dart';
import 'package:school_app/data/models/school_app_subscription_model.dart';
import 'package:school_app/data/models/school_app_access_state.dart';
import 'package:school_app/data/services/tenant_access_service.dart';

void main() {
  group('TenantAccessService - Access Validation Rules Test Suite', () {
    const defaultAppId = 'ABC_SCHOOL_APP';
    final now = DateTime(2026, 9, 15, 12, 0, 0);

    final activeSchool = SchoolModel(
      id: 'school-101',
      schoolCode: 'ABC-01',
      name: 'ABC Public School',
      status: AccountStatus.active,
      createdAt: DateTime(2025, 1, 1),
    );

    final inactiveSchool = SchoolModel(
      id: 'school-101',
      schoolCode: 'ABC-01',
      name: 'ABC Public School',
      status: AccountStatus.inactive,
      createdAt: DateTime(2025, 1, 1),
    );

    final activeMatchingApp = SchoolManagementAppModel(
      id: 'app-201',
      schoolId: 'school-101',
      appName: 'ABC Public School App',
      appIdentifier: defaultAppId,
      packageName: 'com.abcschool.app',
      status: 'active',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final mismatchedApp = SchoolManagementAppModel(
      id: 'app-202',
      schoolId: 'school-101',
      appName: 'XYZ Academy App',
      appIdentifier: 'XYZ_ACADEMY_APP',
      packageName: 'com.xyzacademy.app',
      status: 'active',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final inactiveApp = SchoolManagementAppModel(
      id: 'app-203',
      schoolId: 'school-101',
      appName: 'ABC Public School App',
      appIdentifier: defaultAppId,
      packageName: 'com.abcschool.app',
      status: 'inactive',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final activeValidSubscription = SchoolAppSubscriptionModel(
      id: 'sub-301',
      schoolAppId: 'app-201',
      planName: 'annual',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      status: 'active',
      notes: 'Standard annual plan',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final suspendedSubscription = SchoolAppSubscriptionModel(
      id: 'sub-302',
      schoolAppId: 'app-201',
      planName: 'annual',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      status: 'suspended',
      notes: 'Suspended for review',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final inactiveSubscription = SchoolAppSubscriptionModel(
      id: 'sub-303',
      schoolAppId: 'app-201',
      planName: 'annual',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      status: 'inactive',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final expiredStatusSubscription = SchoolAppSubscriptionModel(
      id: 'sub-304',
      schoolAppId: 'app-201',
      planName: 'annual',
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 12, 31),
      status: 'expired',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final dateExpiredSubscription = SchoolAppSubscriptionModel(
      id: 'sub-305',
      schoolAppId: 'app-201',
      planName: 'monthly',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 8, 31), // Expired relative to now (Sept 15, 2026)
      status: 'active',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final futureSubscription = SchoolAppSubscriptionModel(
      id: 'sub-306',
      schoolAppId: 'app-201',
      planName: 'annual',
      startDate: DateTime(2026, 10, 1), // Future relative to now (Sept 15, 2026)
      endDate: DateTime(2027, 9, 30),
      status: 'active',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    test('Scenario A: Valid user + matching school/app + active subscription -> Access Allowed', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: activeValidSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.id, equals('school-101'));
      expect(result.resolvedApp?.appIdentifier, equals(defaultAppId));
      expect(result.resolvedSubscription?.id, equals('sub-301'));
    });

    test('Scenario B: Valid user + APP_IDENTIFIER mismatch -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: mismatchedApp,
        subscription: activeValidSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appMismatch));
      expect(result.userMessage, contains('This app is not configured for this school'));
    });

    test('Scenario C: User profile has no school assigned -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: null,
        app: activeMatchingApp,
        subscription: activeValidSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.schoolNotFound));
    });

    test('Scenario D: Inactive school -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: inactiveSchool,
        app: activeMatchingApp,
        subscription: activeValidSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.schoolInactive));
      expect(result.userMessage, contains('School access is currently inactive'));
    });

    test('Scenario E: Inactive app -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: inactiveApp,
        subscription: activeValidSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appInactive));
      expect(result.userMessage, contains('Application access is currently disabled'));
    });

    test('Scenario F1: Subscription status is expired -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: expiredStatusSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.subscriptionExpired));
      expect(result.userMessage, contains('subscription has expired'));
    });

    test('Scenario F2: Subscription end_date has passed -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: dateExpiredSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.subscriptionExpired));
      expect(result.userMessage, contains('subscription has expired'));
    });

    test('Scenario G: Subscription start_date is in the future -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: futureSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.subscriptionNotStarted));
      expect(result.userMessage, contains('subscription has not started yet'));
    });

    test('Scenario H: Subscription suspended -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: suspendedSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.subscriptionSuspended));
      expect(result.userMessage, contains('Application access is currently suspended'));
    });

    test('Scenario I: Subscription inactive -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: inactiveSubscription,
        configuredAppIdentifier: defaultAppId,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.subscriptionInactive));
      expect(result.userMessage, contains('subscription is inactive'));
    });

    test('Scenario J: Missing subscription record -> Access Blocked', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: null,
        configuredAppIdentifier: defaultAppId,
        requireSubscription: true,
        referenceDate: now,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, anyOf(equals(AppAccessStatus.noSubscription), equals(AppAccessStatus.subscriptionMissing)));
      expect(result.userMessage, contains('No subscription configured'));
    });

    test('Scenario K: AppConfig default values and override', () {
      expect(AppConfig.defaultAppIdentifier, equals('SCHOOL_1_APP'));
      expect(AppConfig.debugFallbackDevSchoolId, equals('cf895651-4783-489b-8551-959a70098ca8'));
      expect(AppConfig.appIdentifier.isNotEmpty, isTrue);
    });

    test('Scenario L: AppAccessResult factory helpers', () {
      final unauth = AppAccessResult.unauthenticated();
      expect(unauth.isAllowed, isFalse);
      expect(unauth.status, equals(AppAccessStatus.unauthenticated));

      final granted = AppAccessResult.granted(
        school: activeSchool,
        app: activeMatchingApp,
        subscription: activeValidSubscription,
      );
      expect(granted.isAllowed, isTrue);
      expect(granted.status, equals(AppAccessStatus.granted));
    });
  });

  group('FIRST END-TO-END TENANT CONNECTION TEST (SCHOOL_1_APP & school 1)', () {
    const testAppIdentifier = 'SCHOOL_1_APP';
    const testSchoolId = 'cf895651-4783-489b-8551-959a70098ca8';
    const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';

    final school1 = SchoolModel(
      id: testSchoolId,
      schoolCode: 'SCHOOL-1',
      name: 'school 1',
      status: AccountStatus.active,
      createdAt: DateTime(2026, 9, 12),
    );

    final inactiveSchool1 = SchoolModel(
      id: testSchoolId,
      schoolCode: 'SCHOOL-1',
      name: 'school 1',
      status: AccountStatus.inactive,
      createdAt: DateTime(2026, 9, 12),
    );

    final school1App = SchoolManagementAppModel(
      id: '5d8f6a16-c0e3-41ea-a1cb-ee711d21c4fc',
      schoolId: testSchoolId,
      appName: 'School 1 App',
      appIdentifier: testAppIdentifier,
      packageName: 'com.yourcompany.school1',
      status: 'ACTIVE',
      createdAt: DateTime(2026, 9, 12),
    );

    final inactiveSchool1App = SchoolManagementAppModel(
      id: '5d8f6a16-c0e3-41ea-a1cb-ee711d21c4fc',
      schoolId: testSchoolId,
      appName: 'School 1 App',
      appIdentifier: testAppIdentifier,
      packageName: 'com.yourcompany.school1',
      status: 'INACTIVE',
      createdAt: DateTime(2026, 9, 12),
    );

    final kpsSchool = SchoolModel(
      id: kpsSchoolId,
      schoolCode: 'KPS',
      name: 'KPS',
      status: AccountStatus.active,
      createdAt: DateTime(2026, 8, 31),
    );

    test('TEST A: SCHOOL_1_APP + matching school_id -> allowed', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: school1,
        app: school1App,
        subscription: null,
        configuredAppIdentifier: testAppIdentifier,
        expectedDevSchoolId: testSchoolId,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.id, equals(testSchoolId));
      expect(result.resolvedSchool?.name, equals('school 1'));
      expect(result.resolvedApp?.appIdentifier, equals('SCHOOL_1_APP'));
      expect(result.resolvedApp?.schoolId, equals(testSchoolId));
    });

    test('TEST B: SCHOOL_1_APP + mismatched school -> denied', () {
      // User belongs to KPS, but app is configured for SCHOOL_1_APP
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: school1App, // app is for School 1, but user belongs to KPS
        subscription: null,
        configuredAppIdentifier: testAppIdentifier,
        expectedDevSchoolId: testSchoolId,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appMismatch));
      expect(result.userMessage, contains('This app is not configured for this school'));
    });

    test('TEST C: Missing app record -> denied', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: school1,
        app: null,
        subscription: null,
        configuredAppIdentifier: testAppIdentifier,
        expectedDevSchoolId: testSchoolId,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appNotFound));
      expect(result.userMessage, contains('Dedicated application record not found'));
    });

    test('TEST D: Inactive app -> denied', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: school1,
        app: inactiveSchool1App,
        subscription: null,
        configuredAppIdentifier: testAppIdentifier,
        expectedDevSchoolId: testSchoolId,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appInactive));
      expect(result.userMessage, contains('Application access is currently disabled'));
    });

    test('TEST E: Inactive school -> denied', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: inactiveSchool1,
        app: school1App,
        subscription: null,
        configuredAppIdentifier: testAppIdentifier,
        expectedDevSchoolId: testSchoolId,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.schoolInactive));
      expect(result.userMessage, contains('School access is currently inactive'));
    });

    test('TEST F: Valid active configuration -> app shell opens', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: school1,
        app: school1App,
        subscription: null,
        configuredAppIdentifier: AppConfig.appIdentifier,
        expectedDevSchoolId: AppConfig.debugFallbackDevSchoolId,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.schoolCode, equals('SCHOOL-1'));
      expect(result.resolvedApp?.packageName, equals('com.yourcompany.school1'));
    });
  });

  group('PRODUCTION MODE TENANT ACCESS & SECURITY REGRESSION TESTS', () {
    const prodSchoolId = 'prod-school-uuid-1111';
    const prodAppIdentifier = 'PROD_SCHOOL_APP';

    final prodSchool = SchoolModel(
      id: prodSchoolId,
      schoolCode: 'PROD-1',
      name: 'Production School 1',
      status: AccountStatus.active,
      createdAt: DateTime(2026, 9, 13),
    );

    final prodApp = SchoolManagementAppModel(
      id: 'prod-app-uuid-1111',
      schoolId: prodSchoolId,
      appName: 'Production School App',
      appIdentifier: prodAppIdentifier,
      packageName: 'com.prod.school1',
      status: 'ACTIVE',
      createdAt: DateTime(2026, 9, 13),
    );

    test('A. Production configuration without DEV_SCHOOL_ID', () {
      // Production path: expectedDevSchoolId is null, zero DEV_SCHOOL_ID dependency
      final result = TenantAccessService.evaluateAccessRules(
        school: prodSchool,
        app: prodApp,
        subscription: null,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.id, equals(prodSchoolId));
      expect(result.resolvedApp?.appIdentifier, equals(prodAppIdentifier));
    });

    test('B. Production app with matching profile.school_id + APP_IDENTIFIER', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: prodSchool,
        app: prodApp,
        subscription: null,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.name, equals('Production School 1'));
    });

    test('C. APP_IDENTIFIER mismatch -> denied', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: prodSchool,
        app: prodApp,
        subscription: null,
        configuredAppIdentifier: 'MISMATCHED_APP_ID',
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appMismatch));
      expect(result.userMessage, contains('This app is not configured for this school'));
    });

    test('D. Profile school_id mismatch -> denied', () {
      final wrongSchool = SchoolModel(
        id: 'wrong-school-uuid-2222',
        schoolCode: 'WRONG-2',
        name: 'Wrong School',
        status: AccountStatus.active,
        createdAt: DateTime(2026, 9, 13),
      );

      final result = TenantAccessService.evaluateAccessRules(
        school: wrongSchool, // User's profile resolves to school 2
        app: prodApp,        // Dedicated app belongs to school 1
        subscription: null,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appMismatch));
      expect(result.userMessage, contains('This app is not configured for this school'));
    });

    test('E. Missing school -> denied', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: null,
        app: prodApp,
        subscription: null,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.schoolNotFound));
      expect(result.userMessage, contains('School institution record could not be found'));
    });

    test('F. Missing app record -> denied', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: prodSchool,
        app: null,
        subscription: null,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appNotFound));
      expect(result.userMessage, contains('Dedicated application record not found'));
    });

    test('G. Inactive school -> denied', () {
      final inactiveSchool = SchoolModel(
        id: prodSchoolId,
        schoolCode: 'PROD-1',
        name: 'Production School 1',
        status: AccountStatus.inactive,
        createdAt: DateTime(2026, 9, 13),
      );

      final result = TenantAccessService.evaluateAccessRules(
        school: inactiveSchool,
        app: prodApp,
        subscription: null,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.schoolInactive));
      expect(result.userMessage, contains('School access is currently inactive'));
    });

    test('H. Inactive app -> denied', () {
      final inactiveApp = SchoolManagementAppModel(
        id: 'prod-app-uuid-1111',
        schoolId: prodSchoolId,
        appName: 'Production School App',
        appIdentifier: prodAppIdentifier,
        packageName: 'com.prod.school1',
        status: 'INACTIVE',
        createdAt: DateTime(2026, 9, 13),
      );

      final result = TenantAccessService.evaluateAccessRules(
        school: prodSchool,
        app: inactiveApp,
        subscription: null,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appInactive));
      expect(result.userMessage, contains('Application access is currently disabled'));
    });

    test('I. Expired subscription -> denied', () {
      final expiredSub = SchoolAppSubscriptionModel(
        id: 'sub-uuid-1',
        schoolAppId: 'prod-app-uuid-1111',
        planName: 'Standard',
        status: 'EXPIRED',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
        createdAt: DateTime(2025, 1, 1),
      );

      final result = TenantAccessService.evaluateAccessRules(
        school: prodSchool,
        app: prodApp,
        subscription: expiredSub,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.subscriptionExpired));
      expect(result.userMessage, contains('subscription has expired'));
    });

    test('J. Valid active configuration -> allowed', () {
      final activeSub = SchoolAppSubscriptionModel(
        id: 'sub-uuid-2',
        schoolAppId: 'prod-app-uuid-1111',
        planName: 'Enterprise',
        status: 'ACTIVE',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final result = TenantAccessService.evaluateAccessRules(
        school: prodSchool,
        app: prodApp,
        subscription: activeSub,
        configuredAppIdentifier: prodAppIdentifier,
        expectedDevSchoolId: null,
        referenceDate: DateTime(2026, 6, 1),
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.name, equals('Production School 1'));
      expect(result.resolvedApp?.packageName, equals('com.prod.school1'));
    });
  });

  group('KPS SCHOOL ACCESS VERIFICATION (KPS_APP & school_id: 6254bee9-151d-4332-8a1c-3994af7d2153)', () {
    const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const kpsAppIdentifier = 'KPS_APP';

    final kpsSchool = SchoolModel(
      id: kpsSchoolId,
      schoolCode: 'KPS',
      name: 'KPS',
      status: AccountStatus.active,
      createdAt: DateTime(2026, 8, 31),
    );

    final kpsApp = SchoolManagementAppModel(
      id: 'kps-app-record-uuid',
      schoolId: kpsSchoolId,
      appName: 'KPS School App',
      appIdentifier: kpsAppIdentifier,
      packageName: 'com.school.kps',
      status: 'ACTIVE',
      createdAt: DateTime(2026, 9, 13),
    );

    final kpsSubscription = SchoolAppSubscriptionModel(
      id: 'kps-sub-record-uuid',
      schoolAppId: 'kps-app-record-uuid',
      planName: 'Enterprise',
      status: 'ACTIVE',
      startDate: DateTime(2026, 9, 13),
      endDate: DateTime(2027, 9, 13),
      createdAt: DateTime(2026, 9, 13),
    );

    test('KPS: APP_IDENTIFIER = KPS_APP + school_id: 6254bee9... -> GRANTED', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: kpsSchool,
        app: kpsApp,
        subscription: kpsSubscription,
        configuredAppIdentifier: kpsAppIdentifier,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.id, equals(kpsSchoolId));
      expect(result.resolvedSchool?.name, equals('KPS'));
      expect(result.resolvedApp?.appIdentifier, equals('KPS_APP'));
      expect(result.resolvedApp?.schoolId, equals(kpsSchoolId));
      expect(result.resolvedSubscription?.status, equals('ACTIVE'));
    });
  });
}
