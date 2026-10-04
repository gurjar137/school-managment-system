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
