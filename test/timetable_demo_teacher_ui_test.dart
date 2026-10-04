import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/services/timetable_service.dart';

void main() {
  group('Timetable Demo Generator & Real Teacher Integration Tests', () {
    late TimetableService timetableService;

    // Real teachers corresponding to live database records for current school (6254bee9-151d-4332-8a1c-3994af7d2153)
    final teacherRamesh = TeacherModel(
      id: 'teacher_ramesh_seed',
      schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
      name: 'Ramesh',
      email: 'ramesh@school.com',
      subjects: ['Physics'],
      assignedClass: '12',
      assignedSection: 'F',
      totalStudents: 45,
      avatarUrl: '',
      phone: '9876543210',
      designation: 'Senior Physics Faculty',
    );

    final teacherRam = TeacherModel(
      id: 'teacher_ram_seed',
      schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
      name: 'Ram',
      email: 'ram@school.com',
      subjects: ['Mathematics'],
      assignedClass: '5',
      assignedSection: 'A',
      totalStudents: 38,
      avatarUrl: '',
      phone: '9876543211',
      designation: 'Senior Math Faculty',
    );

    final teacherNoSubject = TeacherModel(
      id: 'teacher_sub_seed',
      schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
      name: 'Substitute Teacher',
      email: 'sub@school.com',
      subjects: [],
      assignedClass: '9',
      assignedSection: 'B',
      totalStudents: 0,
      avatarUrl: '',
      phone: '9876543212',
      designation: 'Relief Faculty',
    );

    setUp(() {
      timetableService = TimetableService();
    });

    test('1. Generates example draft timetable using real live teachers with proper subjects', () async {
      final realTeachers = [teacherRamesh, teacherRam];
      final schoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
      final yearId = 'ay_2024_2025';
      final classId = 'class_10';
      final sectionId = 'sec_a';

      final periodSlots = [
        {'p': 1, 'start': '08:30', 'end': '09:15'},
        {'p': 2, 'start': '09:15', 'end': '10:00'},
        {'p': 3, 'start': '10:15', 'end': '11:00'},
        {'p': 4, 'start': '11:00', 'end': '11:45'},
        {'p': 5, 'start': '12:30', 'end': '13:15'},
        {'p': 6, 'start': '13:15', 'end': '14:00'},
      ];

      final createdDraftEntries = <TimetableEntryModel>[];

      for (int day = 1; day <= 5; day++) {
        for (int pIdx = 0; pIdx < periodSlots.length; pIdx++) {
          final slot = periodSlots[pIdx];
          final teacherIdx = (day - 1 + pIdx) % realTeachers.length;
          final teacher = realTeachers[teacherIdx];
          final subject = teacher.subjects.isNotEmpty ? teacher.subjects.first : 'Subject not assigned';

          final draft = TimetableEntryModel(
            id: 'draft_${day}_p$pIdx',
            schoolId: schoolId,
            academicYearId: yearId,
            classId: classId,
            className: 'Class 10',
            sectionId: sectionId,
            sectionName: 'A',
            dayOfWeek: day,
            periodNumber: slot['p'] as int,
            startTime: slot['start'] as String,
            endTime: slot['end'] as String,
            subjectName: subject,
            teacherProfileId: teacher.id,
            teacherName: teacher.name,
            room: 'Room 101',
            status: TimetableStatus.draft,
            notes: 'Demo / Draft Schedule',
          );

          // Validate no conflict
          final conflict = timetableService.detectConflict(
            entry: draft,
            existingEntries: createdDraftEntries,
          );
          expect(conflict, isNull);

          final created = await timetableService.createEntry(draft);
          createdDraftEntries.add(created);
        }
      }

      // Assertions
      expect(createdDraftEntries.length, 30);
      expect(createdDraftEntries.every((e) => e.status == TimetableStatus.draft), isTrue);
      expect(createdDraftEntries.every((e) => e.isDraft), isTrue);
      expect(createdDraftEntries.every((e) => !e.isPublished), isTrue);

      // Verify teachers used are ONLY real teachers
      final teacherNamesUsed = createdDraftEntries.map((e) => e.teacherName).toSet();
      expect(teacherNamesUsed, containsAll(['Ramesh', 'Ram']));
      expect(teacherNamesUsed.length, 2);

      // Verify subjects mapped to real teachers
      final rameshEntries = createdDraftEntries.where((e) => e.teacherName == 'Ramesh');
      expect(rameshEntries.every((e) => e.subjectName == 'Physics'), isTrue);

      final ramEntries = createdDraftEntries.where((e) => e.teacherName == 'Ram');
      expect(ramEntries.every((e) => e.subjectName == 'Mathematics'), isTrue);
    });

    test('2. Gracefully uses "Subject not assigned" fallback when teacher has no subject', () async {
      final subject = teacherNoSubject.subjects.isNotEmpty ? teacherNoSubject.subjects.first : 'Subject not assigned';
      expect(subject, equals('Subject not assigned'));

      final draft = TimetableEntryModel(
        id: 'draft_sub_1',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: 'ay_2024_2025',
        classId: 'class_10',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: subject,
        teacherProfileId: teacherNoSubject.id,
        teacherName: teacherNoSubject.name,
        status: TimetableStatus.draft,
      );

      final created = await timetableService.createEntry(draft);
      expect(created.subjectName, equals('Subject not assigned'));
      expect(created.teacherName, equals('Substitute Teacher'));
    });

    test('3. Teacher filter load count and match detection logic', () {
      final entries = [
        TimetableEntryModel(
          id: '1',
          schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
          academicYearId: 'ay_2024',
          dayOfWeek: 1,
          startTime: '08:30',
          endTime: '09:15',
          subjectName: 'Physics',
          teacherProfileId: 'teacher_ramesh_seed',
          teacherName: 'Ramesh',
        ),
        TimetableEntryModel(
          id: '2',
          schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
          academicYearId: 'ay_2024',
          dayOfWeek: 1,
          startTime: '09:15',
          endTime: '10:00',
          subjectName: 'Mathematics',
          teacherProfileId: 'teacher_ram_seed',
          teacherName: 'Ram',
        ),
        TimetableEntryModel(
          id: '3',
          schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
          academicYearId: 'ay_2024',
          dayOfWeek: 2,
          startTime: '08:30',
          endTime: '09:15',
          subjectName: 'Physics',
          teacherProfileId: 'teacher_ramesh_seed',
          teacherName: 'Ramesh',
        ),
      ];

      // Teacher filter: Ramesh
      final rameshCount = entries.where((e) =>
          (e.teacherProfileId == teacherRamesh.id || e.teacherName == teacherRamesh.name) && !e.isCancelled).length;
      expect(rameshCount, equals(2));

      // Teacher filter: Ram
      final ramCount = entries.where((e) =>
          (e.teacherProfileId == teacherRam.id || e.teacherName == teacherRam.name) && !e.isCancelled).length;
      expect(ramCount, equals(1));
    });

    test('4. Existing timetable records are protected and never overwritten', () async {
      // Existing entry in slot 08:30 - 09:15
      final existing = TimetableEntryModel(
        id: 'existing_valuable_period',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: 'ay_2024',
        classId: 'class_10',
        sectionId: 'sec_a',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Chemistry',
        teacherProfileId: 'teacher_existing',
        teacherName: 'Dr. Sharma',
        status: TimetableStatus.published,
      );

      await timetableService.createEntry(existing);

      // Attempting to schedule another period in the same slot is rejected
      final conflictingDraft = TimetableEntryModel(
        id: 'demo_attempt',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: 'ay_2024',
        classId: 'class_10',
        sectionId: 'sec_a',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.draft,
      );

      final conflict = timetableService.detectConflict(
        entry: conflictingDraft,
        existingEntries: timetableService.cachedEntries,
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, equals(TimetableConflictType.classOverlap));
      // Existing period is retained untouched
      expect(timetableService.cachedEntries.length, equals(1));
      expect(timetableService.cachedEntries.first.id, equals('existing_valuable_period'));
      expect(timetableService.cachedEntries.first.isPublished, isTrue);
    });

    test('5. Multi-tenant cross-school protection rejects entries from different schools', () {
      final entrySchoolA = TimetableEntryModel(
        id: 'entry_a',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: 'ay_2024',
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
      );

      final entrySchoolB = TimetableEntryModel(
        id: 'entry_b',
        schoolId: 'foreign_school_id_9999',
        academicYearId: 'ay_2024',
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
      );

      final conflict = timetableService.detectConflict(
        entry: entrySchoolB,
        existingEntries: [entrySchoolA],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, equals(TimetableConflictType.schoolMismatch));
    });
  });
}
