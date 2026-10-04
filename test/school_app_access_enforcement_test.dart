import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/models/school_management_app_model.dart';
import 'package:school_app/data/models/school_app_subscription_model.dart';
import 'package:school_app/data/models/school_app_access_state.dart';
import 'package:school_app/data/services/tenant_access_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('School App Access State Enforcement Test Suite', () {
    const testAppId = 'APP_ENFORCE_TEST';
    final now = DateTime(2026, 9, 15, 12, 0, 0);

    final schoolActive = SchoolModel(
      id: 'sch-enforce-01',
      schoolCode: 'SCH-01',
      name: 'Bright Minds Academy',
      status: AccountStatus.active,
      createdAt: DateTime(2025, 1, 1),
    );

    final schoolInactive = SchoolModel(
      id: 'sch-enforce-01',
      schoolCode: 'SCH-01',
      name: 'Bright Minds Academy',
      status: AccountStatus.inactive,
      createdAt: DateTime(2025, 1, 1),
    );

    final appActive = SchoolManagementAppModel(
      id: 'app-01',
      schoolId: 'sch-enforce-01',
      appName: 'Bright Minds App',
      appIdentifier: testAppId,
      packageName: 'com.brightminds.app',
      status: 'active',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final appInactive = SchoolManagementAppModel(
      id: 'app-01',
      schoolId: 'sch-enforce-01',
      appName: 'Bright Minds App',
      appIdentifier: testAppId,
      packageName: 'com.brightminds.app',
      status: 'inactive',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final subActive = SchoolAppSubscriptionModel(
      id: 'sub-01',
      schoolAppId: 'app-01',
      planName: 'annual',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      status: 'active',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final subExpiredDate = SchoolAppSubscriptionModel(
      id: 'sub-expired-date',
      schoolAppId: 'app-01',
      planName: 'annual',
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2026, 8, 31), // passed before now (2026-09-15)
      status: 'active',
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 1, 1),
    );

    final subExpiredStatus = SchoolAppSubscriptionModel(
      id: 'sub-expired-status',
      schoolAppId: 'app-01',
      planName: 'annual',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      status: 'expired',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final subSuspended = SchoolAppSubscriptionModel(
      id: 'sub-suspended',
      schoolAppId: 'app-01',
      planName: 'annual',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      status: 'suspended',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    // -------------------------------------------------------------
    // Test 1: school active -> granted
    // -------------------------------------------------------------
    test('1. school active -> granted', () {
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(res.isAllowed, isTrue);
      expect(res.status, equals(AppAccessStatus.granted));
      expect(res.userMessage, equals('Access Granted'));
    });

    // -------------------------------------------------------------
    // Test 2: school inactive -> schoolDeactivated
    // -------------------------------------------------------------
    test('2. school inactive -> schoolDeactivated', () {
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolInactive,
        app: appActive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(res.isAllowed, isFalse);
      expect(res.isSchoolDeactivated, isTrue);
      expect(res.displayTitle, equals('Access Deactivated'));
      expect(res.displayMessage, equals('This school app has been deactivated by Super Admin.'));
      expect(res.secondaryMessage, equals('Please contact your administrator for more information.'));
    });

    // -------------------------------------------------------------
    // Test 3: subscription active -> granted
    // -------------------------------------------------------------
    test('3. subscription active -> granted', () {
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(res.isAllowed, isTrue);
      expect(res.status, equals(AppAccessStatus.granted));
    });

    // -------------------------------------------------------------
    // Test 4: subscription expired -> subscriptionExpired
    // -------------------------------------------------------------
    test('4. subscription expired (by date & by status) -> subscriptionExpired', () {
      final resDate = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: subExpiredDate,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(resDate.isAllowed, isFalse);
      expect(resDate.isSubscriptionExpired, isTrue);
      expect(resDate.displayTitle, equals('Subscription Expired'));
      expect(resDate.displayMessage, equals('Your school subscription has expired.'));
      expect(resDate.secondaryMessage, equals('Please contact your administrator to renew the subscription.'));

      final resStatus = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: subExpiredStatus,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(resStatus.isAllowed, isFalse);
      expect(resStatus.isSubscriptionExpired, isTrue);
      expect(resStatus.displayTitle, equals('Subscription Expired'));
      expect(resStatus.displayMessage, equals('Your school subscription has expired.'));
    });

    // -------------------------------------------------------------
    // Test 5: subscription suspended -> blocked
    // -------------------------------------------------------------
    test('5. subscription suspended -> blocked', () {
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: subSuspended,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(res.isAllowed, isFalse);
      expect(res.status, equals(AppAccessStatus.subscriptionSuspended));
      expect(res.isSubscriptionBlocked, isTrue);
    });

    // -------------------------------------------------------------
    // Test 6: no subscription -> blocked
    // -------------------------------------------------------------
    test('6. no subscription -> blocked when subscription is required', () {
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: null,
        configuredAppIdentifier: testAppId,
        requireSubscription: true,
        referenceDate: now,
      );

      expect(res.isAllowed, isFalse);
      expect(res.isSubscriptionBlocked, isTrue);
      expect(res.status, equals(AppAccessStatus.subscriptionMissing));
    });

    // -------------------------------------------------------------
    // Test 7: app inactive -> blocked (schoolDeactivated)
    // -------------------------------------------------------------
    test('7. app inactive -> blocked with Access Deactivated', () {
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appInactive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(res.isAllowed, isFalse);
      expect(res.isSchoolDeactivated, isTrue);
      expect(res.displayTitle, equals('Access Deactivated'));
      expect(res.displayMessage, equals('This school app has been deactivated by Super Admin.'));
    });

    // -------------------------------------------------------------
    // Test 8: school inactive + subscription expired -> schoolDeactivated priority
    // -------------------------------------------------------------
    test('8. school inactive + subscription expired -> schoolDeactivated priority', () {
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolInactive,
        app: appActive,
        subscription: subExpiredDate,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      // School deactivation MUST take priority over subscription expired!
      expect(res.isAllowed, isFalse);
      expect(res.isSchoolDeactivated, isTrue);
      expect(res.displayTitle, equals('Access Deactivated'));
      expect(res.displayTitle, isNot(equals('Subscription Expired')));
      expect(res.displayMessage, equals('This school app has been deactivated by Super Admin.'));
    });

    // -------------------------------------------------------------
    // Test 9: blocked route cannot reach dashboard
    // -------------------------------------------------------------
    test('9. blocked route cannot reach dashboard', () {
      final blockedSchool = TenantAccessService.evaluateAccessRules(
        school: schoolInactive,
        app: appActive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
      );
      expect(blockedSchool.isAllowed, isFalse);
      expect(blockedSchool.isBlocked, isTrue);

      final blockedSub = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: subExpiredDate,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );
      expect(blockedSub.isAllowed, isFalse);
      expect(blockedSub.isBlocked, isTrue);
    });

    // -------------------------------------------------------------
    // Test 10: refresh preserves correct blocked state
    // -------------------------------------------------------------
    test('10. refresh preserves correct blocked state without stale cache', () {
      // Re-evaluating rules on reload/refresh returns same authoritative state
      final reloadedResult = TenantAccessService.evaluateAccessRules(
        school: schoolInactive,
        app: appActive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
      );
      expect(reloadedResult.isSchoolDeactivated, isTrue);
      expect(reloadedResult.displayTitle, equals('Access Deactivated'));
    });

    // -------------------------------------------------------------
    // Test 11: logout from blocked screen
    // -------------------------------------------------------------
    test('11. logout from blocked screen returns unauthenticated result', () {
      final unauth = AppAccessResult.unauthenticated();
      expect(unauth.isAllowed, isFalse);
      expect(unauth.status, equals(AppAccessStatus.unauthenticated));
      expect(unauth.userMessage, contains('sign in'));
    });

    // -------------------------------------------------------------
    // Test 12: reactivation restores access
    // -------------------------------------------------------------
    test('12. reactivation restores access immediately', () {
      // Prior state: inactive
      final prior = TenantAccessService.evaluateAccessRules(
        school: schoolInactive,
        app: appActive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
      );
      expect(prior.isAllowed, isFalse);

      // Super Admin reactivates school -> active
      final restoredSchool = schoolInactive.copyWith(status: AccountStatus.active);
      final after = TenantAccessService.evaluateAccessRules(
        school: restoredSchool,
        app: appActive,
        subscription: subActive,
        configuredAppIdentifier: testAppId,
      );
      expect(after.isAllowed, isTrue);
      expect(after.status, equals(AppAccessStatus.granted));
    });

    // -------------------------------------------------------------
    // Test 13: renewal restores access
    // -------------------------------------------------------------
    test('13. renewal restores access immediately', () {
      // Prior state: expired
      final prior = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: subExpiredDate,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );
      expect(prior.isSubscriptionExpired, isTrue);

      // Super Admin renews subscription -> renewed active dates
      final renewedSub = subExpiredDate.copyWith(
        startDate: now,
        endDate: now.add(const Duration(days: 365)),
        status: 'active',
      );
      final after = TenantAccessService.evaluateAccessRules(
        school: schoolActive,
        app: appActive,
        subscription: renewedSub,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );
      expect(after.isAllowed, isTrue);
      expect(after.status, equals(AppAccessStatus.granted));
    });

    // -------------------------------------------------------------
    // Test 14: cross-school isolation
    // -------------------------------------------------------------
    test('14. cross-school isolation rejects School B accessing School A app', () {
      final schoolB = SchoolModel(
        id: 'sch-other-99',
        schoolCode: 'SCH-99',
        name: 'Another School',
        status: AccountStatus.active,
        createdAt: DateTime(2025, 1, 1),
      );

      // User from School B trying to access App A (linked to School A)
      final res = TenantAccessService.evaluateAccessRules(
        school: schoolB,
        app: appActive, // belongs to sch-enforce-01
        subscription: subActive,
        configuredAppIdentifier: testAppId,
        referenceDate: now,
      );

      expect(res.isAllowed, isFalse);
      expect(res.status, equals(AppAccessStatus.appMismatch));
      expect(res.displayTitle, equals('App Mismatch'));
      expect(res.userMessage, equals('This app is not configured for this school.'));
    });
  });
}
