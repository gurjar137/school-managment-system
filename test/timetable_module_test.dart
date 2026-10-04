import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/services/timetable_service.dart';

void main() {
  group('Timetable Module Comprehensive Test Suite', () {
    const testSchoolA = 'school-aaa-111';
    const testSchoolB = 'school-bbb-222';
    const testAcademicYear = 'ay-2026-2027';

    late TimetableService service;

    setUp(() {
      service = TimetableService();
    });

    // 1. Timetable model creation & properties
    test('1. Timetable model creation & computed properties', () {
      final entry = TimetableEntryModel(
        id: 'tt-1',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-10',
        className: 'Grade 10',
        sectionId: 'sec-a',
        sectionName: 'A',
        dayOfWeek: 1, // Monday
        periodNumber: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectId: 'sub-math',
        subjectName: 'Mathematics',
        teacherProfileId: 'tch-smith',
        teacherName: 'John Smith',
        room: 'Room 101',
        status: TimetableStatus.draft,
      );

      expect(entry.id, 'tt-1');
      expect(entry.dayName, 'Monday');
      expect(entry.startMinutes, 8 * 60 + 30);
      expect(entry.endMinutes, 9 * 60 + 15);
      expect(entry.durationMinutes, 45);
      expect(entry.timeRangeFormatted, '08:30 - 09:15');
      expect(entry.isDraft, isTrue);
      expect(entry.isPublished, isFalse);
      expect(entry.isCancelled, isFalse);
    });

    // 2. Serialization (toJson, fromJson, toSupabaseMap)
    test('2. Serialization round-trip and Supabase payload generation', () {
      final original = TimetableEntryModel(
        id: 'tt-2',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-10',
        className: 'Grade 10',
        sectionId: 'sec-b',
        sectionName: 'B',
        dayOfWeek: 3, // Wednesday
        periodNumber: 2,
        startTime: '09:20',
        endTime: '10:05',
        subjectId: 'sub-sci',
        subjectName: 'Science',
        teacherProfileId: 'tch-doe',
        teacherName: 'Jane Doe',
        room: 'Lab 2',
        notes: 'Bring lab coats',
        status: TimetableStatus.published,
      );

      // toSupabaseMap
      final dbMap = original.toSupabaseMap();
      expect(dbMap['school_id'], testSchoolA);
      expect(dbMap['academic_year_id'], testAcademicYear);
      expect(dbMap['class_id'], 'cls-10');
      expect(dbMap['section_id'], 'sec-b');
      expect(dbMap['day_of_week'], 3);
      expect(dbMap['period_number'], 2);
      expect(dbMap['start_time'], '09:20:00');
      expect(dbMap['end_time'], '10:05:00');
      expect(dbMap['subject_id'], 'sub-sci');
      expect(dbMap['subject_name'], 'Science');
      expect(dbMap['teacher_profile_id'], 'tch-doe');
      expect(dbMap['teacher_name'], 'Jane Doe');
      expect(dbMap['room'], 'Lab 2');
      expect(dbMap['notes'], 'Bring lab coats');
      expect(dbMap['status'], 'PUBLISHED');

      // fromJson
      final restored = TimetableEntryModel.fromJson(dbMap);
      expect(restored.schoolId, original.schoolId);
      expect(restored.academicYearId, original.academicYearId);
      expect(restored.dayOfWeek, original.dayOfWeek);
      expect(restored.periodNumber, original.periodNumber);
      expect(restored.subjectName, original.subjectName);
      expect(restored.teacherName, original.teacherName);
      expect(restored.status, TimetableStatus.published);
      expect(restored.room, original.room);
    });

    // 3. Create entry
    test('3. Create entry with validated fields', () async {
      final toCreate = TimetableEntryModel(
        id: 'tt-create-1',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-9',
        className: 'Grade 9',
        sectionId: 'sec-a',
        sectionName: 'A',
        dayOfWeek: 2,
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectId: 'sub-eng',
        subjectName: 'English Literature',
        teacherProfileId: 'tch-williams',
        teacherName: 'Mr. Williams',
        room: 'Room 201',
      );

      final created = await service.createEntry(toCreate);

      expect(created.id, isNotEmpty);
      expect(created.schoolId, testSchoolA);
      expect(created.subjectName, 'English Literature');
      expect(created.status, TimetableStatus.draft);

      final entries = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-9',
      );
      expect(entries.any((e) => e.id == created.id), isTrue);
    });

    // 4. Edit entry
    test('4. Edit entry updates fields correctly', () async {
      final initial = await service.createEntry(
        TimetableEntryModel(
          id: 'tt-edit-init',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-9',
          sectionId: 'sec-a',
          dayOfWeek: 2,
          periodNumber: 2,
          startTime: '09:00',
          endTime: '09:45',
          subjectId: 'sub-hist',
          subjectName: 'History',
          teacherProfileId: 'tch-jones',
          teacherName: 'Ms. Jones',
        ),
      );

      final updated = await service.updateEntry(
        initial.copyWith(
          subjectName: 'World History',
          room: 'Hall B',
          notes: 'Chapter 4 presentation',
        ),
      );

      expect(updated.subjectName, 'World History');
      expect(updated.room, 'Hall B');
      expect(updated.notes, 'Chapter 4 presentation');
    });

    // 5. Delete / Cancel entry (draft hard delete vs published soft cancel)
    test('5. Delete draft purges entry; deleting published soft-cancels', () async {
      // Draft delete
      final draft = await service.createEntry(
        TimetableEntryModel(
          id: 'tt-draft-del',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-8',
          dayOfWeek: 1,
          startTime: '10:00',
          endTime: '10:45',
          subjectName: 'Art',
          status: TimetableStatus.draft,
        ),
      );

      await service.deleteEntry(draft.id, softCancelIfPublished: true);
      final activeDrafts = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-8',
      );
      expect(activeDrafts.any((e) => e.id == draft.id), isFalse);

      // Published soft cancel
      final publishedEntry = await service.createEntry(
        TimetableEntryModel(
          id: 'tt-pub-del',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-8',
          dayOfWeek: 1,
          startTime: '11:00',
          endTime: '11:45',
          subjectName: 'Music',
          status: TimetableStatus.published,
        ),
      );

      await service.deleteEntry(publishedEntry.id, softCancelIfPublished: true);
      final entriesAfterCancel = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-8',
      );
      final found = entriesAfterCancel.firstWhere((e) => e.id == publishedEntry.id);
      expect(found.status, TimetableStatus.cancelled);
      expect(found.isCancelled, isTrue);
    });

    // 6. Academic year filtering
    test('6. Academic year filtering isolates entries across sessions', () async {
      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-ay-old',
          schoolId: testSchoolA,
          academicYearId: 'ay-2025-2026',
          classId: 'cls-7',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '08:45',
          subjectName: 'Old Year Class',
        ),
      );

      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-ay-cur',
          schoolId: testSchoolA,
          academicYearId: 'ay-2026-2027',
          classId: 'cls-7',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '08:45',
          subjectName: 'Current Year Class',
        ),
      );

      final oldList = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: 'ay-2025-2026',
      );
      final currentList = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: 'ay-2026-2027',
      );

      expect(oldList.every((e) => e.academicYearId == 'ay-2025-2026'), isTrue);
      expect(currentList.every((e) => e.academicYearId == 'ay-2026-2027'), isTrue);
    });

    // 7. Class / Section filtering
    test('7. Class and Section filtering returns only scoped records', () async {
      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-sec-9a',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-grade9',
          sectionId: 'sec-9a',
          dayOfWeek: 3,
          startTime: '09:00',
          endTime: '09:45',
          subjectName: 'Physics 9A',
        ),
      );

      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-sec-9b',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-grade9',
          sectionId: 'sec-9b',
          dayOfWeek: 3,
          startTime: '09:00',
          endTime: '09:45',
          subjectName: 'Chemistry 9B',
        ),
      );

      final sectionAResults = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-grade9',
        sectionId: 'sec-9a',
      );
      expect(sectionAResults.length, 1);
      expect(sectionAResults.first.subjectName, 'Physics 9A');
    });

    // 8. Teacher assignment validation
    test('8. Teacher assignment correctly tracks teacherProfileId and name', () async {
      final entry = await service.createEntry(
        TimetableEntryModel(
          id: 'tt-tch-val',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-11',
          dayOfWeek: 4,
          startTime: '10:00',
          endTime: '11:00',
          subjectName: 'Computer Science',
          teacherProfileId: 'tch-alan-turing',
          teacherName: 'Alan Turing',
        ),
      );

      expect(entry.teacherProfileId, 'tch-alan-turing');
      expect(entry.teacherName, 'Alan Turing');

      final teacherEntries = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        teacherId: 'tch-alan-turing',
      );
      expect(teacherEntries.any((e) => e.id == entry.id), isTrue);
    });

    // 9. Class conflict rejection (same class, section, day, overlapping time)
    test('9. Class conflict rejection prevents double booking class in same slot', () {
      final existing = TimetableEntryModel(
        id: 'tt-cls-exist',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-10',
        className: 'Grade 10',
        sectionId: 'sec-a',
        sectionName: 'A',
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '10:00',
        subjectName: 'Biology',
      );

      final candidate = TimetableEntryModel(
        id: 'tt-candidate-1',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-10',
        className: 'Grade 10',
        sectionId: 'sec-a',
        sectionName: 'A',
        dayOfWeek: 1,
        startTime: '09:30', // Overlaps 09:00 - 10:00
        endTime: '10:30',
        subjectName: 'Chemistry',
      );

      final conflict = service.detectConflict(
        entry: candidate,
        existingEntries: [existing],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, TimetableConflictType.classOverlap);
      expect(conflict.message, contains('Class Grade 10'));
    });

    // 10. Teacher conflict rejection (same teacher, day, overlapping time across different classes)
    test('10. Teacher conflict rejection stops teacher double-booking across classes', () {
      final existing = TimetableEntryModel(
        id: 'tt-tch-exist',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-10',
        className: 'Grade 10',
        sectionId: 'sec-a',
        dayOfWeek: 2,
        startTime: '10:00',
        endTime: '11:00',
        subjectName: 'Advanced Math',
        teacherProfileId: 'tch-einstein',
        teacherName: 'Prof. Einstein',
      );

      final candidate = TimetableEntryModel(
        id: 'tt-candidate-2',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-11', // Different class!
        sectionId: 'sec-b',
        dayOfWeek: 2,
        startTime: '10:30', // Overlaps 10:00 - 11:00
        endTime: '11:30',
        subjectName: 'Physics',
        teacherProfileId: 'tch-einstein',
        teacherName: 'Prof. Einstein',
      );

      final conflict = service.detectConflict(
        entry: candidate,
        existingEntries: [existing],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, TimetableConflictType.teacherOverlap);
      expect(conflict.message, contains('Prof. Einstein is already teaching'));
    });

    // 11. Room conflict rejection (same room, day, overlapping time)
    test('11. Room conflict rejection stops room double booking', () {
      final existing = TimetableEntryModel(
        id: 'tt-room-exist',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-6',
        dayOfWeek: 3,
        startTime: '12:00',
        endTime: '13:00',
        subjectName: 'Physical Education',
        room: 'Gymnasium A',
      );

      final candidate = TimetableEntryModel(
        id: 'tt-candidate-3',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-7',
        dayOfWeek: 3,
        startTime: '12:15',
        endTime: '13:15',
        subjectName: 'Yoga',
        room: 'Gymnasium A',
      );

      final conflict = service.detectConflict(
        entry: candidate,
        existingEntries: [existing],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, TimetableConflictType.roomOverlap);
      expect(conflict.message, contains('Gymnasium A'));
      expect(conflict.message, contains('is already occupied'));
    });

    // 12. Invalid time range rejection (endTime <= startTime)
    test('12. Invalid time range rejection rejects end_time <= start_time', () {
      final invalidCandidate = TimetableEntryModel(
        id: 'tt-invalid-time',
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-1',
        dayOfWeek: 1,
        startTime: '11:00',
        endTime: '10:30', // Earlier than start
        subjectName: 'Reading',
      );

      final conflict = service.detectConflict(
        entry: invalidCandidate,
        existingEntries: [],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, TimetableConflictType.invalidTimeRange);
      expect(conflict.message, contains('End time (10:30) must be strictly after start time (11:00)'));

      // Also verify equal start and end time
      final zeroDurationCandidate = invalidCandidate.copyWith(endTime: '11:00');
      final zeroConflict = service.detectConflict(
        entry: zeroDurationCandidate,
        existingEntries: [],
      );
      expect(zeroConflict, isNotNull);
      expect(zeroConflict!.type, TimetableConflictType.invalidTimeRange);
    });

    // 13. Publish timetable with zero conflicts
    test('13. Publish timetable succeeds when 0 conflicts exist', () async {
      final entry = await service.createEntry(
        TimetableEntryModel(
          id: 'tt-pub-zero',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-publish-1',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '08:45',
          subjectName: 'Art & Design',
          status: TimetableStatus.draft,
        ),
      );

      expect(entry.isDraft, isTrue);

      final publishedCount = await service.publishTimetable(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-publish-1',
      );

      expect(publishedCount, greaterThanOrEqualTo(1));

      final refreshed = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-publish-1',
      );
      final publishedEntry = refreshed.firstWhere((e) => e.id == entry.id);
      expect(publishedEntry.isPublished, isTrue);
    });

    // 14. Draft vs Published state handling
    test('14. Draft vs Published transitions and unpublish revert', () async {
      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-pub-toggle',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-toggle',
          dayOfWeek: 2,
          startTime: '14:00',
          endTime: '15:00',
          subjectName: 'Robotics',
          status: TimetableStatus.draft,
        ),
      );

      // Publish
      await service.publishTimetable(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-toggle',
      );
      var entries = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-toggle',
      );
      expect(entries.first.isPublished, isTrue);

      // Unpublish back to draft
      final unpublishedCount = await service.unpublishTimetable(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-toggle',
      );
      expect(unpublishedCount, greaterThanOrEqualTo(1));

      entries = await service.fetchTimetableEntries(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-toggle',
      );
      expect(entries.first.isDraft, isTrue);
    });

    // 15. Multi-tenant cross-school isolation
    test('15. Multi-tenant cross-school isolation strictly isolates data', () async {
      // School A creates entry
      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-iso-a',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-isolated',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '09:00',
          subjectName: 'School A Proprietary Subject',
        ),
      );

      // School B creates entry
      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-iso-b',
          schoolId: testSchoolB,
          academicYearId: testAcademicYear,
          classId: 'cls-isolated',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '09:00',
          subjectName: 'School B Proprietary Subject',
        ),
      );

      final schoolAEntries = await service.fetchTimetableEntries(schoolId: testSchoolA);
      final schoolBEntries = await service.fetchTimetableEntries(schoolId: testSchoolB);

      expect(schoolAEntries.any((e) => e.subjectName == 'School B Proprietary Subject'), isFalse);
      expect(schoolBEntries.any((e) => e.subjectName == 'School A Proprietary Subject'), isFalse);

      // Cross-school mismatch detection
      final crossMismatchConflict = service.detectConflict(
        entry: TimetableEntryModel(
          id: 'tt-cross',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'c1',
          dayOfWeek: 1,
          startTime: '08:00',
          endTime: '09:00',
          subjectName: 'Mismatch',
        ),
        existingEntries: [
          TimetableEntryModel(
            id: 'tt-cross-b',
            schoolId: testSchoolB,
            academicYearId: testAcademicYear,
            classId: 'c1',
            dayOfWeek: 1,
            startTime: '08:00',
            endTime: '09:00',
            subjectName: 'Mismatch',
          ),
        ],
      );
      expect(crossMismatchConflict, isNotNull);
      expect(crossMismatchConflict!.type, TimetableConflictType.schoolMismatch);
    });

    // 16. Duplicate day collision protection
    test('16. Duplicate day copies periods and rejects collisions on target day', () async {
      // Set up Monday periods
      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-dup-mon-1',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-dup',
          sectionId: 'sec-1',
          dayOfWeek: 1, // Monday
          startTime: '08:00',
          endTime: '08:50',
          subjectName: 'English',
        ),
      );
      await service.createEntry(
        TimetableEntryModel(
          id: 'tt-dup-mon-2',
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-dup',
          sectionId: 'sec-1',
          dayOfWeek: 1, // Monday
          startTime: '09:00',
          endTime: '09:50',
          subjectName: 'Math',
        ),
      );

      // Duplicate Monday -> Tuesday (Target Tuesday is currently empty)
      final copied = await service.duplicateDay(
        schoolId: testSchoolA,
        academicYearId: testAcademicYear,
        classId: 'cls-dup',
        sectionId: 'sec-1',
        sourceDay: 1,
        targetDay: 2,
      );
      expect(copied.length, 2);
      expect(copied.every((e) => e.dayOfWeek == 2), isTrue);

      // Attempting to duplicate to Tuesday again MUST throw due to collision
      expect(
        () async => await service.duplicateDay(
          schoolId: testSchoolA,
          academicYearId: testAcademicYear,
          classId: 'cls-dup',
          sectionId: 'sec-1',
          sourceDay: 1,
          targetDay: 2,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
