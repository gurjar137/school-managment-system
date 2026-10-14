/// Core exceptions for the School Management Application.
library;

/// Thrown when tenant/school resolution fails for an authenticated session
/// or an operation cannot determine the authoritative school context.
class TenantResolutionException implements Exception {
  final String message;
  final String? details;

  const TenantResolutionException(this.message, {this.details});

  @override
  String toString() => details != null ? 'TenantResolutionException: $message ($details)' : 'TenantResolutionException: $message';
}

/// Thrown when active academic year resolution fails for a specific school.
class AcademicYearResolutionException implements Exception {
  final String message;
  final String? schoolId;

  const AcademicYearResolutionException(this.message, {this.schoolId});

  @override
  String toString() => schoolId != null
      ? 'AcademicYearResolutionException: $message (School ID: $schoolId)'
      : 'AcademicYearResolutionException: $message';
}

/// Thrown when a caller attempts to access or specify a school ID that differs
/// from their authorized membership, or when dedicated school build configuration
/// conflicts with the authenticated user's authorized school membership.
class UnauthorizedTenantAccessException implements Exception {
  final String message;
  final String? requestedSchoolId;
  final String? authorizedSchoolId;

  const UnauthorizedTenantAccessException(
    this.message, {
    this.requestedSchoolId,
    this.authorizedSchoolId,
  });

  @override
  String toString() {
    if (requestedSchoolId != null && authorizedSchoolId != null) {
      return 'UnauthorizedTenantAccessException: $message (Requested: $requestedSchoolId, Authorized: $authorizedSchoolId)';
    }
    return 'UnauthorizedTenantAccessException: $message';
  }
}
