import '../../data/models/student_model.dart';

/// Normalizes and matches teacher assigned class/section against student class_name and section_name.
class TeacherAssignmentParser {
  final String rawClass;
  final String rawSection;
  final String normalizedClass;
  final String normalizedSection;

  TeacherAssignmentParser({
    String? assignedClass,
    String? assignedSection,
  })  : rawClass = _extractClass(assignedClass, assignedSection),
        rawSection = _extractSection(assignedClass, assignedSection),
        normalizedClass = normalize(_extractClass(assignedClass, assignedSection)),
        normalizedSection = normalize(_extractSection(assignedClass, assignedSection));

  bool get hasFilter => normalizedClass.isNotEmpty || normalizedSection.isNotEmpty;

  /// Normalizes a string by converting to lowercase, removing words like 'class' or 'section',
  /// and stripping non-alphanumeric characters.
  /// E.g. "Class 12" -> "12", " 12 " -> "12", "Section F" -> "f", "F" -> "f", "12-F" -> "12f"
  static String normalize(String? input) {
    if (input == null) return '';
    final low = input.toLowerCase().trim();
    if (low == 'not assigned' || low == 'unassigned' || low == 'none' || low == 'null' || low.contains('not assigned') || low.contains('no class')) {
      return '';
    }
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'\bclass\b'), '')
        .replaceAll(RegExp(r'\bsection\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }

  static String _extractClass(String? assignedClass, String? assignedSection) {
    if (assignedClass == null || assignedClass.trim().isEmpty) return '';
    final trimmed = assignedClass.trim();
    final low = trimmed.toLowerCase();
    if (low == 'not assigned' || low == 'unassigned' || low == 'none' || low.contains('not assigned') || low.contains('no class')) {
      return '';
    }
    if (trimmed.contains('-')) {
      return trimmed.split('-').first.trim();
    }
    if (trimmed.contains('/')) {
      return trimmed.split('/').first.trim();
    }
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 2 && words[1].length <= 2 && RegExp(r'^[a-zA-Z]$').hasMatch(words[1])) {
      return words[0].trim();
    }
    return trimmed;
  }

  static String _extractSection(String? assignedClass, String? assignedSection) {
    if (assignedSection != null && assignedSection.trim().isNotEmpty) {
      final sTrim = assignedSection.trim();
      final lowS = sTrim.toLowerCase();
      if (lowS != 'not assigned' && lowS != 'unassigned' && lowS != 'none') {
        return sTrim;
      }
    }
    if (assignedClass == null || assignedClass.trim().isEmpty) return '';
    final trimmed = assignedClass.trim();
    final low = trimmed.toLowerCase();
    if (low == 'not assigned' || low == 'unassigned' || low == 'none' || low.contains('not assigned') || low.contains('no class')) {
      return '';
    }
    if (trimmed.contains('-')) {
      return trimmed.split('-').last.trim();
    }
    if (trimmed.contains('/')) {
      return trimmed.split('/').last.trim();
    }
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 2 && words[1].length <= 2 && RegExp(r'^[a-zA-Z]$').hasMatch(words[1])) {
      return words[1].trim();
    }
    return '';
  }

  /// Evaluates whether a student belongs to the teacher's class and section.
  /// Strictly enforces school_id and academic_year_id scoping.
  bool matchesStudent(
    StudentModel student, {
    String? expectedSchoolId,
    String? expectedAcademicYearId,
  }) {
    // 1. School isolation scope check
    if (expectedSchoolId != null &&
        expectedSchoolId.isNotEmpty &&
        student.schoolId.isNotEmpty) {
      if (student.schoolId.toLowerCase().trim() != expectedSchoolId.toLowerCase().trim()) {
        return false;
      }
    }

    // 2. Academic year scope check
    if (expectedAcademicYearId != null &&
        expectedAcademicYearId.isNotEmpty &&
        student.academicYearId.isNotEmpty) {
      if (student.academicYearId.toLowerCase().trim() != expectedAcademicYearId.toLowerCase().trim()) {
        return false;
      }
    }

    // 3. Normalized class text matching
    final sClassNorm = normalize(student.className);
    if (normalizedClass.isNotEmpty && sClassNorm != normalizedClass) {
      return false;
    }

    // 4. Normalized section text matching
    final sSecNorm = normalize(student.section);
    if (normalizedSection.isNotEmpty && sSecNorm != normalizedSection) {
      return false;
    }

    return true;
  }

  /// Evaluates whether given class and section strings match the teacher's assignment.
  bool matchesClassAndSection(String? className, String? section) {
    if (!hasFilter) return false;
    final sClassNorm = normalize(className);
    if (normalizedClass.isNotEmpty && sClassNorm != normalizedClass) {
      return false;
    }
    final sSecNorm = normalize(section);
    if (normalizedSection.isNotEmpty && sSecNorm != normalizedSection) {
      return false;
    }
    return true;
  }
}
