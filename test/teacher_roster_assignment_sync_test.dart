import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/core/utils/teacher_assignment_parser.dart';

void main() {
  group('Teacher Assignment Sync & Scoping Tests', () {
    final students = [
      StudentModel.fromJson({
        'id': 'stu_1',
        'schoolId': '6254bee9-151d-4332-8a1c-3994af7d2153',
        'academicYearId': '47d1569b-e032-44a7-891f-b21f5458f55b',
        'admissionNumber': 'STU-001',
        'rollNumber': '1',
        'name': 'Ram Kumar',
        'className': '5',
        'section': 'A',
      }),
      StudentModel.fromJson({
        'id': 'stu_2',
        'schoolId': '6254bee9-151d-4332-8a1c-3994af7d2153',
        'academicYearId': '47d1569b-e032-44a7-891f-b21f5458f55b',
        'admissionNumber': 'STU-002',
        'rollNumber': '2',
        'name': 'Shyam Singh',
        'className': '5',
        'section': 'B',
      }),
      StudentModel.fromJson({
        'id': 'stu_3',
        'schoolId': '6254bee9-151d-4332-8a1c-3994af7d2153',
        'academicYearId': '47d1569b-e032-44a7-891f-b21f5458f55b',
        'admissionNumber': 'STU-003',
        'rollNumber': '3',
        'name': 'Gita Sharma',
        'className': '10',
        'section': 'A',
      }),
    ];

    test('Unassigned teacher receives strictly 0 students (EMPTY roster)', () {
      final parser = TeacherAssignmentParser(assignedClass: '', assignedSection: '');
      expect(parser.hasFilter, isFalse);

      final filtered = students.where((s) {
        if (!parser.hasFilter) return false;
        return parser.matchesStudent(s);
      }).toList();

      expect(filtered, isEmpty);
    });

    test('Unassigned teacher with "Not Assigned" receives strictly 0 students', () {
      final parser = TeacherAssignmentParser(assignedClass: 'Not Assigned', assignedSection: '');
      expect(parser.hasFilter, isFalse);

      final filtered = students.where((s) {
        if (!parser.hasFilter) return false;
        return parser.matchesStudent(s);
      }).toList();

      expect(filtered, isEmpty);
    });

    test('Teacher assigned Class 5, Section A receives ONLY Class 5-A students', () {
      final parser = TeacherAssignmentParser(assignedClass: '5', assignedSection: 'A');
      expect(parser.hasFilter, isTrue);

      final filtered = students.where((s) => parser.matchesStudent(s)).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.name, equals('Ram Kumar'));
      expect(filtered.first.className, equals('5'));
      expect(filtered.first.section, equals('A'));
    });

    test('Teacher assigned "5 - A" combined string receives ONLY Class 5-A students', () {
      final parser = TeacherAssignmentParser(assignedClass: '5 - A');
      expect(parser.hasFilter, isTrue);
      expect(parser.rawClass, equals('5'));
      expect(parser.rawSection, equals('A'));

      final filtered = students.where((s) => parser.matchesStudent(s)).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.name, equals('Ram Kumar'));
    });

    test('Teacher assignment display formatting', () {
      String formatAssignedClass(String? assignedClass, String? assignedSection) {
        return (assignedClass != null && assignedClass.isNotEmpty && assignedClass != 'Not Assigned')
            ? (assignedSection != null && assignedSection.isNotEmpty && !assignedClass.toLowerCase().contains(assignedSection.toLowerCase()))
                ? '$assignedClass - $assignedSection'
                : assignedClass
            : 'Not Assigned';
      }

      expect(formatAssignedClass('5', 'A'), equals('5 - A'));
      expect(formatAssignedClass('5 - A', null), equals('5 - A'));
      expect(formatAssignedClass('5 - A', 'A'), equals('5 - A'));
      expect(formatAssignedClass(null, null), equals('Not Assigned'));
      expect(formatAssignedClass('', ''), equals('Not Assigned'));
      expect(formatAssignedClass('Not Assigned', ''), equals('Not Assigned'));
    });
  });
}
