import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/core/utils/teacher_assignment_parser.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/teacher_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Teacher Model & Assignment Tests', () {
    test('TeacherModel parsed className and sectionName correctly from separate fields', () {
      final t = TeacherModel(
        id: 't_1',
        name: 'Ram',
        email: 'ram@gmail.com',
        subjects: const ['Mathematics'],
        assignedClass: '5',
        assignedSection: 'A',
        totalStudents: 1,
        avatarUrl: '',
        phone: '134567887',
        designation: 'Senior Math Faculty',
      );

      expect(t.className, '5');
      expect(t.sectionName, 'A');
      expect(t.hasAssignment, true);
    });

    test('TeacherModel parsed className and sectionName from hyphenated assignedClass', () {
      final t = TeacherModel(
        id: 't_2',
        name: 'Ramesh',
        email: 'ramesh137@gmail.com',
        subjects: const ['Physics'],
        assignedClass: '12 - F',
        totalStudents: 1,
        avatarUrl: '',
        phone: '9876543210',
        designation: 'Senior Science Faculty',
      );

      expect(t.className, '12');
      expect(t.sectionName, 'F');
      expect(t.hasAssignment, true);
    });

    test('TeacherModel unassigned returns empty strings and hasAssignment = false', () {
      final t = TeacherModel(
        id: 't_3',
        name: 'Unassigned Teacher',
        email: 'unassigned@school.com',
        subjects: const [],
        assignedClass: '',
        assignedSection: '',
        totalStudents: 0,
        avatarUrl: '',
        phone: '',
        designation: 'Faculty Member',
      );

      expect(t.className, '');
      expect(t.sectionName, '');
      expect(t.hasAssignment, false);
    });
  });

  group('Teacher Roster Isolation Tests', () {
    final mockStudents = [
      StudentModel.fromJson({
        'id': 'stu_1',
        'schoolId': '6254bee9-151d-4332-8a1c-3994af7d2153',
        'academicYearId': '47d1569b-e032-44a7-891f-b21f5458f55b',
        'admissionNumber': 'STU-001',
        'rollNumber': '1',
        'name': 'Bholaram',
        'className': '5',
        'section': 'a',
      }),
      StudentModel.fromJson({
        'id': 'stu_2',
        'schoolId': '6254bee9-151d-4332-8a1c-3994af7d2153',
        'academicYearId': '47d1569b-e032-44a7-891f-b21f5458f55b',
        'admissionNumber': 'STU-002',
        'rollNumber': '2',
        'name': 'Dharampal Class 12-F',
        'className': '12',
        'section': 'f',
      }),
      StudentModel.fromJson({
        'id': 'stu_3',
        'schoolId': '6254bee9-151d-4332-8a1c-3994af7d2153',
        'academicYearId': '47d1569b-e032-44a7-891f-b21f5458f55b',
        'admissionNumber': 'STU-003',
        'rollNumber': '3',
        'name': 'Student Class 3-A',
        'className': '3',
        'section': 'a',
      }),
    ];

    test('Teacher parser accurately matches student 5-A', () {
      final parser = TeacherAssignmentParser(assignedClass: '5', assignedSection: 'A');
      expect(parser.hasFilter, true);
      expect(parser.matchesStudent(mockStudents[0]), true);
      expect(parser.matchesStudent(mockStudents[1]), false);
      expect(parser.matchesStudent(mockStudents[2]), false);
    });

    test('Teacher parser accurately matches student 12-F', () {
      final parser = TeacherAssignmentParser(assignedClass: 'Class 12 - Section F');
      expect(parser.hasFilter, true);
      expect(parser.matchesStudent(mockStudents[0]), false);
      expect(parser.matchesStudent(mockStudents[1]), true);
      expect(parser.matchesStudent(mockStudents[2]), false);
    });

    test('Unassigned teacher hasFilter is false', () {
      final parser = TeacherAssignmentParser(assignedClass: '', assignedSection: '');
      expect(parser.hasFilter, false);
    });
  });

  group('Teacher Directory Inclusion Tests', () {
    test('getTeachersClassWise drops unassigned teachers whereas getTeachers includes all', () async {
      final teacherService = TeacherService();
      
      final unassignedTeacher = TeacherModel(
        id: 't_unassigned',
        employeeId: 'EMP-999',
        name: 'Unassigned Teacher',
        email: 'unassigned@test.com',
        subjects: const [],
        assignedClass: '',
        assignedSection: '',
        totalStudents: 0,
        avatarUrl: '',
        phone: '',
        designation: 'Faculty',
      );

      final assignedTeacher = TeacherModel(
        id: 't_assigned',
        employeeId: 'EMP-100',
        name: 'Ram',
        email: 'ram@test.com',
        subjects: const [],
        assignedClass: '5',
        assignedSection: 'A',
        totalStudents: 1,
        avatarUrl: '',
        phone: '',
        designation: 'Teacher',
      );

      await teacherService.addTeacher(unassignedTeacher);
      await teacherService.addTeacher(assignedTeacher);

      final allTeachers = await teacherService.getTeachers();
      expect(allTeachers.any((t) => t.id == 't_unassigned'), true, reason: 'Unassigned teacher must appear in all teachers directory');
      expect(allTeachers.any((t) => t.id == 't_assigned'), true);

      final classWiseMap = await teacherService.getTeachersClassWise();
      expect(classWiseMap.containsKey(''), false, reason: 'getTeachersClassWise drops unassigned faculty');
    });

    test('getTeachers returns at least 2 real teachers (Ramesh in 12-F, Ram in 5-A)', () async {
      final teacherService = TeacherService();
      final list = await teacherService.getTeachers(schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153');
      expect(list.length, greaterThanOrEqualTo(2));
      final ramesh = list.firstWhere((t) => t.name.toLowerCase().contains('ramesh'));
      expect(ramesh.assignedClass.toLowerCase(), '12');
      expect(ramesh.assignedSection.toLowerCase(), 'f');
      expect(ramesh.status, AccountStatus.active);

      final ram = list.firstWhere((t) => t.name.toLowerCase() == 'ram');
      expect(ram.assignedClass.toLowerCase(), '5');
      expect(ram.assignedSection.toLowerCase(), 'a');
      expect(ram.status, AccountStatus.active);
    });

    test('SchoolRepository getTeachers with activeSchoolId forwards and returns teachers', () async {
      final repo = SchoolRepository(
        studentService: StudentService(),
        teacherService: TeacherService(),
      );
      final list = await repo.getTeachers(schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153');
      expect(list.length, greaterThanOrEqualTo(2));
    });
  });
}
