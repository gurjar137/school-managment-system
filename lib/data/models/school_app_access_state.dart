import 'school_model.dart';
import 'school_management_app_model.dart';
import 'school_app_subscription_model.dart';

/// All possible outcomes of startup and session tenant access validation.
enum AppAccessStatus {
  checking,
  granted,
  unauthenticated,
  noProfile,
  profileInactive,
  noSchoolAssigned,
  schoolNotFound,
  schoolInactive,
  schoolDeactivated,
  appNotFound,
  appMismatch,
  appInactive,
  appDeactivated,
  noSubscription,
  subscriptionMissing,
  subscriptionSuspended,
  subscriptionInactive,
  subscriptionNotStarted,
  subscriptionExpired,
  networkError,
}

/// Comprehensive outcome of evaluating tenant identity, app configuration match,
/// and subscription access standing.
class AppAccessResult {
  final bool isAllowed;
  final AppAccessStatus status;
  final String userMessage;
  final String? detailedReason;
  final SchoolModel? resolvedSchool;
  final SchoolManagementAppModel? resolvedApp;
  final SchoolAppSubscriptionModel? resolvedSubscription;

  const AppAccessResult({
    required this.isAllowed,
    required this.status,
    required this.userMessage,
    this.detailedReason,
    this.resolvedSchool,
    this.resolvedApp,
    this.resolvedSubscription,
  });

  bool get isBlocked => !isAllowed;

  bool get isSchoolDeactivated =>
      status == AppAccessStatus.schoolDeactivated ||
      status == AppAccessStatus.schoolInactive ||
      status == AppAccessStatus.appDeactivated ||
      status == AppAccessStatus.appInactive;

  bool get isSubscriptionExpired =>
      status == AppAccessStatus.subscriptionExpired;

  bool get isSubscriptionBlocked =>
      status == AppAccessStatus.subscriptionExpired ||
      status == AppAccessStatus.subscriptionSuspended ||
      status == AppAccessStatus.subscriptionInactive ||
      status == AppAccessStatus.noSubscription ||
      status == AppAccessStatus.subscriptionMissing ||
      status == AppAccessStatus.subscriptionNotStarted;

  String get displayTitle {
    if (isSchoolDeactivated) return 'Access Deactivated';
    if (isSubscriptionExpired) return 'Subscription Expired';
    if (status == AppAccessStatus.subscriptionSuspended) return 'Subscription Suspended';
    if (status == AppAccessStatus.appMismatch) return 'App Mismatch';
    return 'Access Restricted';
  }

  String get displayMessage {
    if (isSchoolDeactivated) return 'This school app has been deactivated by Super Admin.';
    if (isSubscriptionExpired) return 'Your school subscription has expired.';
    return userMessage;
  }

  String get secondaryMessage {
    if (isSchoolDeactivated) return 'Please contact your administrator for more information.';
    if (isSubscriptionExpired) return 'Please contact your administrator to renew the subscription.';
    if (status == AppAccessStatus.subscriptionSuspended) {
      return 'Please contact your administrator to resolve your account status.';
    }
    return detailedReason ?? 'Please contact your administrator for assistance.';
  }

  factory AppAccessResult.granted({
    required SchoolModel school,
    required SchoolManagementAppModel app,
    required SchoolAppSubscriptionModel subscription,
  }) {
    return AppAccessResult(
      isAllowed: true,
      status: AppAccessStatus.granted,
      userMessage: 'Access Granted',
      detailedReason: 'Tenant school, dedicated app, and subscription standing verified.',
      resolvedSchool: school,
      resolvedApp: app,
      resolvedSubscription: subscription,
    );
  }

  factory AppAccessResult.schoolDeactivated({
    SchoolModel? school,
    SchoolManagementAppModel? app,
    String? detailedReason,
  }) {
    return AppAccessResult(
      isAllowed: false,
      status: AppAccessStatus.schoolDeactivated,
      userMessage: 'This school app has been deactivated by Super Admin.',
      detailedReason: detailedReason ?? 'School status is inactive.',
      resolvedSchool: school,
      resolvedApp: app,
    );
  }

  factory AppAccessResult.subscriptionExpired({
    SchoolModel? school,
    SchoolManagementAppModel? app,
    SchoolAppSubscriptionModel? subscription,
    String? detailedReason,
  }) {
    return AppAccessResult(
      isAllowed: false,
      status: AppAccessStatus.subscriptionExpired,
      userMessage: 'Your school subscription has expired.',
      detailedReason: detailedReason ?? 'Subscription validity has ended.',
      resolvedSchool: school,
      resolvedApp: app,
      resolvedSubscription: subscription,
    );
  }

  factory AppAccessResult.unauthenticated() {
    return const AppAccessResult(
      isAllowed: false,
      status: AppAccessStatus.unauthenticated,
      userMessage: 'Please sign in to access your school workspace.',
    );
  }

  factory AppAccessResult.blocked({
    required AppAccessStatus status,
    required String userMessage,
    String? detailedReason,
    SchoolModel? school,
    SchoolManagementAppModel? app,
    SchoolAppSubscriptionModel? subscription,
  }) {
    return AppAccessResult(
      isAllowed: false,
      status: status,
      userMessage: userMessage,
      detailedReason: detailedReason,
      resolvedSchool: school,
      resolvedApp: app,
      resolvedSubscription: subscription,
    );
  }
}
