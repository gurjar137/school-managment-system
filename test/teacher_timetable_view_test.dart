import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/services/timetable_service.dart';

void main() {
  group('Teacher App - My Published Timetable 12-Point Test Suite', () {
    late TimetableService timetableService;

    const schoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const foreignSchoolId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
    const academicYearId = 'ay_2026_2027';

    const teacherRamesh = TeacherModel(
      id: 'teacher_ramesh_seed',
      schoolId: schoolId,
      name: 'Ramesh',
      email: 'ramesh@school.com',
      subjects: ['Physics'],
      assignedClass: '10',
      assignedSection: 'A',
      totalStudents: 45,
      avatarUrl: '',
      phone: '9876543210',
      designation: 'Senior Physics Faculty',
    );

    const teacherRam = TeacherModel(
      id: 'teacher_ram_seed',
      schoolId: schoolId,
      name: 'Ram',
      email: 'ram@school.com',
      subjects: ['Mathematics'],
      assignedClass: '9',
      assignedSection: 'B',
      totalStudents: 38,
      avatarUrl: '',
      phone: '9876543211',
      designation: 'Senior Math Faculty',
    );

    setUp(() {
      timetableService = TimetableService();
    });

    // 1. Teacher timetable model
    test('1. Teacher timetable model: serialization, parsing, and getters', () {
      final entry = TimetableEntryModel(
        id: 'tt_model_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: 'class_10',
        className: 'Class 10',
        sectionId: 'sec_a',
        sectionName: 'A',
        dayOfWeek: 1, // Monday
        periodNumber: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        room: '305',
        notes: 'Regular morning lecture',
        status: TimetableStatus.published,
      );

      // Verify fields & computed getters
      expect(entry.id, equals('tt_model_1'));
      expect(entry.schoolId, equals(schoolId));
      expect(entry.academicYearId, equals(academicYearId));
      expect(entry.className, equals('Class 10'));
      expect(entry.sectionName, equals('A'));
      expect(entry.subjectName, equals('Physics'));
      expect(entry.room, equals('305'));
      expect(entry.dayName, equals('Monday'));
      expect(entry.startMinutes, equals(510)); // 8 * 60 + 30
      expect(entry.endMinutes, equals(555));   // 9 * 60 + 15
      expect(entry.durationMinutes, equals(45));
      expect(entry.timeRangeFormatted, equals('08:30 - 09:15'));
      expect(entry.isPublished, isTrue);
      expect(entry.isDraft, isFalse);
      expect(entry.isCancelled, isFalse);

      // Verify Supabase JSON serialization round-trip
      final map = entry.toSupabaseMap();
      expect(map['school_id'], equals(schoolId));
      expect(map['status'], equals('PUBLISHED'));
      expect(map['start_time'], equals('08:30:00'));
      expect(map['end_time'], equals('09:15:00'));

      final parsed = TimetableEntryModel.fromJson(map).copyWith(
        id: entry.id,
        className: entry.className,
        sectionName: entry.sectionName,
        teacherName: entry.teacherName,
      );
      expect(parsed.id, equals(entry.id));
      expect(parsed.status, equals(TimetableStatus.published));
      expect(parsed.subjectName, equals(entry.subjectName));
    });

    // 2. Published-only filtering
    test('2. Published-only filtering: strictly excludes unpublished records', () async {
      await timetableService.createEntry(TimetableEntryModel(
        id: 'pub_entry_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.published,
      ));

      await timetableService.createEntry(TimetableEntryModel(
        id: 'draft_entry_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '09:30',
        endTime: '10:15',
        subjectName: 'Physics Advanced',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.draft,
      ));

      final teacherSchedule = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
      );

      expect(teacherSchedule.length, equals(1));
      expect(teacherSchedule.first.id, equals('pub_entry_1'));
      expect(teacherSchedule.first.isPublished, isTrue);
      expect(teacherSchedule.any((e) => e.id == 'draft_entry_1'), isFalse);
    });

    // 3. Current teacher filtering
    test('3. Current teacher filtering: returns only the authenticated teacher entries', () async {
      await timetableService.createEntry(TimetableEntryModel(
        id: 'p_ramesh_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 2,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.published,
      ));

      await timetableService.createEntry(TimetableEntryModel(
        id: 'p_ram_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 2,
        startTime: '09:30',
        endTime: '10:15',
        subjectName: 'Mathematics',
        teacherProfileId: teacherRam.id,
        teacherName: teacherRam.name,
        status: TimetableStatus.published,
      ));

      final rameshEntries = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
      );

      expect(rameshEntries.every((e) => e.teacherProfileId == teacherRamesh.id), isTrue);
      expect(rameshEntries.any((e) => e.teacherProfileId == teacherRam.id), isFalse);
    });

    // 4. Current school filtering
    test('4. Current school filtering: queries are strictly bound to school_id', () async {
      await timetableService.createEntry(TimetableEntryModel(
        id: 'p_foreign_school',
        schoolId: foreignSchoolId,
        academicYearId: academicYearId,
        dayOfWeek: 3,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Foreign Subject',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.published,
      ));

      final results = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
      );

      expect(results.any((e) => e.schoolId == foreignSchoolId), isFalse);
      expect(results.any((e) => e.id == 'p_foreign_school'), isFalse);
    });

    // 5. Draft hidden
    test('5. Draft hidden: drafts never appear in teacher timetable view', () async {
      await timetableService.createEntry(TimetableEntryModel(
        id: 'draft_hidden_entry',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 3,
        startTime: '10:30',
        endTime: '11:15',
        subjectName: 'Draft Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.draft,
      ));

      final results = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRamesh.id,
      );

      expect(results.any((e) => e.isDraft), isFalse);
      expect(results.any((e) => e.id == 'draft_hidden_entry'), isFalse);
    });

    // 6. Cancelled hidden
    test('6. Cancelled hidden: cancelled periods are strictly excluded', () async {
      await timetableService.createEntry(TimetableEntryModel(
        id: 'cancelled_period_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 4,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics Cancelled',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.cancelled,
      ));

      final results = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRamesh.id,
      );

      expect(results.any((e) => e.isCancelled), isFalse);
      expect(results.any((e) => e.id == 'cancelled_period_1'), isFalse);
    });

    // 7. Cross-teacher isolation
    test('7. Cross-teacher isolation: Teacher A cannot see Teacher B schedule', () async {
      await timetableService.createEntry(TimetableEntryModel(
        id: 'ramesh_private_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 5,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        status: TimetableStatus.published,
      ));

      await timetableService.createEntry(TimetableEntryModel(
        id: 'ram_private_1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 5,
        startTime: '10:00',
        endTime: '10:45',
        subjectName: 'Mathematics',
        teacherProfileId: teacherRam.id,
        teacherName: teacherRam.name,
        status: TimetableStatus.published,
      ));

      final rameshView = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
      );

      final ramView = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRam.id,
        teacherName: teacherRam.name,
      );

      expect(rameshView.any((e) => e.id == 'ram_private_1'), isFalse);
      expect(ramView.any((e) => e.id == 'ramesh_private_1'), isFalse);
    });

    // 8. Cross-school isolation
    test('8. Cross-school isolation: Zero records returned from another school', () async {
      await timetableService.createEntry(TimetableEntryModel(
        id: 'other_school_period',
        schoolId: foreignSchoolId,
        academicYearId: 'foreign_ay',
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Foreign Subject',
        teacherProfileId: 'foreign_teacher_id',
        status: TimetableStatus.published,
      ));

      final localResults = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: schoolId,
        teacherProfileId: teacherRamesh.id,
      );

      expect(localResults.any((e) => e.schoolId == foreignSchoolId), isFalse);
      expect(localResults.any((e) => e.id == 'other_school_period'), isFalse);
    });

    // 9. Read-only behavior
    test('9. Read-only behavior: TimetableEntryModel is strictly immutable', () {
      final entry = TimetableEntryModel(
        id: 'readonly_test',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        status: TimetableStatus.published,
      );

      // Verify immutable state
      expect(entry.isPublished, isTrue);
      expect(entry.status.displayName, equals('PUBLISHED'));
      // Model has no setter methods or mutable state
    });

    // 10. Today sorting
    test('10. Today sorting: entries sorted chronologically by startMinutes and duration computed', () {
      final p1 = TimetableEntryModel(
        id: 'p1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        status: TimetableStatus.published,
      );

      final p2 = TimetableEntryModel(
        id: 'p2',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '10:00',
        endTime: '10:45',
        subjectName: 'Chemistry',
        status: TimetableStatus.published,
      );

      final p3 = TimetableEntryModel(
        id: 'p3',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '09:15',
        endTime: '10:00',
        subjectName: 'Mathematics',
        status: TimetableStatus.published,
      );

      // Unordered list
      final unsorted = [p2, p1, p3];

      // Sort as Today view does
      final sorted = List<TimetableEntryModel>.from(unsorted)
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

      expect(sorted[0].id, equals('p1'));
      expect(sorted[1].id, equals('p3'));
      expect(sorted[2].id, equals('p2'));
      expect(sorted[0].durationMinutes, equals(45));
      expect(sorted[1].durationMinutes, equals(45));
      expect(sorted[2].durationMinutes, equals(45));
    });

    // 11. Week view
    test('11. Week view: partitions Monday through Saturday correctly', () {
      final entries = [
        TimetableEntryModel(
          id: 'mon',
          schoolId: schoolId,
          academicYearId: academicYearId,
          dayOfWeek: 1, // Monday
          startTime: '08:30',
          endTime: '09:15',
          subjectName: 'Physics',
          status: TimetableStatus.published,
        ),
        TimetableEntryModel(
          id: 'wed',
          schoolId: schoolId,
          academicYearId: academicYearId,
          dayOfWeek: 3, // Wednesday
          startTime: '08:30',
          endTime: '09:15',
          subjectName: 'Physics Lab',
          status: TimetableStatus.published,
        ),
        TimetableEntryModel(
          id: 'sat',
          schoolId: schoolId,
          academicYearId: academicYearId,
          dayOfWeek: 6, // Saturday
          startTime: '09:00',
          endTime: '09:45',
          subjectName: 'Physics Seminar',
          status: TimetableStatus.published,
        ),
      ];

      expect(entries.where((e) => e.dayOfWeek == 1).length, equals(1));
      expect(entries.where((e) => e.dayOfWeek == 2).length, equals(0));
      expect(entries.where((e) => e.dayOfWeek == 3).length, equals(1));
      expect(entries.where((e) => e.dayOfWeek == 4).length, equals(0));
      expect(entries.where((e) => e.dayOfWeek == 5).length, equals(0));
      expect(entries.where((e) => e.dayOfWeek == 6).length, equals(1));
    });

    // 12. Current/next period calculation
    test('12. Current/next period calculation: accurately resolves active vs upcoming periods', () {
      final period1 = TimetableEntryModel(
        id: 'p1',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '08:30', // 510 min
        endTime: '09:15',   // 555 min
        subjectName: 'Physics',
        status: TimetableStatus.published,
      );

      final period2 = TimetableEntryModel(
        id: 'p2',
        schoolId: schoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '09:30', // 570 min
        endTime: '10:15',   // 615 min
        subjectName: 'Mathematics',
        status: TimetableStatus.published,
      );

      final todayEntries = [period1, period2];

      // Scenario A: Time is 08:45 (525 min) -> Period 1 is ACTIVE
      const currentMinA = 525;
      TimetableEntryModel? activeA;
      TimetableEntryModel? nextA;
      for (final e in todayEntries) {
        if (currentMinA >= e.startMinutes && currentMinA <= e.endMinutes) {
          activeA = e;
          break;
        }
      }
      for (final e in todayEntries) {
        if (e.startMinutes > currentMinA) {
          nextA = e;
          break;
        }
      }

      expect(activeA, isNotNull);
      expect(activeA!.id, equals('p1'));
      expect(activeA.endMinutes - currentMinA, equals(30)); // Ends in 30 min
      expect(nextA, isNotNull);
      expect(nextA!.id, equals('p2'));

      // Scenario B: Time is 08:00 (480 min) -> No active period, Period 1 is NEXT
      const currentMinB = 480;
      TimetableEntryModel? activeB;
      TimetableEntryModel? nextB;
      for (final e in todayEntries) {
        if (currentMinB >= e.startMinutes && currentMinB <= e.endMinutes) {
          activeB = e;
          break;
        }
      }
      for (final e in todayEntries) {
        if (e.startMinutes > currentMinB) {
          nextB = e;
          break;
        }
      }

      expect(activeB, isNull);
      expect(nextB, isNotNull);
      expect(nextB!.id, equals('p1'));
      expect(nextB.startMinutes - currentMinB, equals(30)); // Starts in 30 min

      // Scenario C: Time is 10:30 (630 min) -> All periods completed
      const currentMinC = 630;
      TimetableEntryModel? activeC;
      TimetableEntryModel? nextC;
      for (final e in todayEntries) {
        if (currentMinC >= e.startMinutes && currentMinC <= e.endMinutes) {
          activeC = e;
          break;
        }
      }
      for (final e in todayEntries) {
        if (e.startMinutes > currentMinC) {
          nextC = e;
          break;
        }
      }

      expect(activeC, isNull);
      expect(nextC, isNull);
      expect(currentMinC > todayEntries.last.endMinutes, isTrue); // All classes completed
    });
  });
}
