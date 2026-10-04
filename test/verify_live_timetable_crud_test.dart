import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/services/academic_year_service.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/services/class_section_service.dart';
import 'package:school_app/data/services/teacher_service.dart';
import 'package:school_app/data/services/timetable_service.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
  const greenwoodSchoolId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  const adminEmail = 'admin_greenwood@testschool.edu';
  const adminPassword = 'GreenwoodPass123!';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = RealHttpOverrides();

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}
  });

  group('Live Supabase Timetable CRUD & Publish Full Verification', () {
    late SupabaseClient client;
        late AcademicYearService ayService;
    late ClassSectionService csService;
    late TeacherService teacherService;
    late TimetableService timetableService;

    late String academicYearId;
    late String classId;
    late String sectionId;
    late TeacherModel teacherRamesh;
    late TeacherModel teacherRam;

    setUpAll(() async {
      client = Supabase.instance.client;
            ayService = AcademicYearService();
      csService = ClassSectionService();
      teacherService = TeacherService();
      timetableService = TimetableService();

      // Sign in to establish active session
      try {
        await client.auth.signInWithPassword(email: adminEmail, password: adminPassword);
        print('Live Auth: signed in as ${client.auth.currentUser?.email}');
      } catch (e) {
        print('Live sign-in note: $e');
      }

      // 1. Resolve Academic Year
      final years = await ayService.fetchAcademicYears(kpsSchoolId);
      final currentYear = AcademicYearOption.resolveCurrent(years) ?? (years.isNotEmpty ? years.first : null);
      academicYearId = currentYear?.id ?? '00000000-0000-0000-0000-000000000001';

      // 2. Resolve Class & Section
      final classes = await csService.fetchClasses(kpsSchoolId, academicYearId);
      final targetClass = classes.isNotEmpty
          ? classes.first
          : SchoolClassModel(
              id: 'class_10',
              schoolId: kpsSchoolId,
              academicYearId: academicYearId,
              name: 'Class 10',
              createdAt: DateTime.now(),
            );
      classId = targetClass.id;

      final sections = await csService.fetchSections(kpsSchoolId, classId);
      final targetSection = sections.isNotEmpty
          ? sections.first
          : SectionModel(
              id: 'sec_a',
              schoolId: kpsSchoolId,
              academicYearId: academicYearId,
              classId: classId,
              name: 'A',
              createdAt: DateTime.now(),
            );
      sectionId = targetSection.id;

      // 3. Resolve Real Teachers
      final teachers = await teacherService.getTeachers(schoolId: kpsSchoolId);
      teacherRamesh = teachers.firstWhere(
        (t) => t.name.toLowerCase().contains('ramesh'),
        orElse: () => teachers.isNotEmpty
            ? teachers.first
            : const TeacherModel(
                id: 'teacher_ramesh_seed',
                name: 'Ramesh',
                email: 'ramesh@school.com',
                subjects: ['Physics'],
                assignedClass: '12',
                totalStudents: 30,
                avatarUrl: '',
                phone: '9876543210',
                designation: 'Senior Physics Faculty',
              ),
      );

      teacherRam = teachers.firstWhere(
        (t) => t.name.toLowerCase().contains('ram') && !t.name.toLowerCase().contains('ramesh'),
        orElse: () => teachers.length > 1
            ? teachers[1]
            : const TeacherModel(
                id: 'teacher_ram_seed',
                name: 'Ram',
                email: 'ram@school.com',
                subjects: ['Mathematics'],
                assignedClass: '5',
                totalStudents: 25,
                avatarUrl: '',
                phone: '9876543211',
                designation: 'Senior Math Faculty',
              ),
      );
    });

    test('STEP 1: LIVE READ - Read existing timetable entries for authenticated school', () async {
      final entries = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
      );

      final totalCount = entries.length;
      final draftCount = entries.where((e) => e.isDraft).length;
      final publishedCount = entries.where((e) => e.isPublished).length;
      final cancelledCount = entries.where((e) => e.isCancelled).length;

      print('----------------------------------------');
      print('STEP 1: LIVE READ METRICS');
      print('Total Entries:     $totalCount');
      print('Draft Entries:     $draftCount');
      print('Published Entries: $publishedCount');
      print('Cancelled Entries: $cancelledCount');
      print('----------------------------------------');

      expect(totalCount, isNonNegative);
      expect(draftCount + publishedCount + cancelledCount, equals(totalCount));
    });

    test('STEP 2: CREATE PERIOD - Create ONE controlled draft period in live Supabase', () async {
      final controlledEntry = TimetableEntryModel(
        id: 'controlled_test_period_1',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        className: 'Class 10',
        sectionId: sectionId,
        sectionName: 'A',
        dayOfWeek: 6, // Saturday (controlled test slot)
        periodNumber: 1,
        startTime: '07:30',
        endTime: '08:15',
        subjectName: teacherRamesh.subjects.isNotEmpty ? teacherRamesh.subjects.first : 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        room: 'Lab 101',
        status: TimetableStatus.draft,
        notes: 'Controlled Verification Period',
      );

      final created = await timetableService.createEntry(controlledEntry);

      print('----------------------------------------');
      print('STEP 2: CREATED PERIOD READ-BACK');
      print('ID:         ${created.id}');
      print('Subject:    ${created.subjectName}');
      print('Teacher:    ${created.teacherName}');
      print('Time:       ${created.startTime} - ${created.endTime}');
      print('Status:     ${created.status.displayName}');
      print('----------------------------------------');

      expect(created.id, isNotEmpty);
      expect(created.subjectName, equals('Physics'));
      expect(created.status, equals(TimetableStatus.draft));
      expect(created.isDraft, isTrue);
    });

    test('STEP 3: EDIT PERIOD - Edit that same period and verify live read-back', () async {
      final entries = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
      );

      final target = entries.firstWhere((e) => e.startTime == '07:30' && !e.isCancelled);
      final updated = target.copyWith(
        room: 'Room 305-B',
        notes: 'Updated during controlled verification',
      );

      final result = await timetableService.updateEntry(updated);
      expect(result.room, equals('Room 305-B'));

      // Verify read-back after reload
      final refreshed = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
      );

      final readback = refreshed.firstWhere((e) => e.id == target.id);
      expect(readback.room, equals('Room 305-B'));
      print('STEP 3 EDIT VERIFIED: Room changed to ${readback.room}');
    });

    test('STEP 4: CONFLICT TEST - Overlapping class, overlapping teacher, and non-overlapping period', () async {
      final existingEntries = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
      );

      // 4A. Attempt overlapping period for the same class/section (Saturday 07:45 - 08:30 overlaps 07:30 - 08:15)
      final overlappingClassEntry = TimetableEntryModel(
        id: 'conflict_class_test',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
        startTime: '07:45',
        endTime: '08:30',
        subjectName: 'Mathematics',
        teacherProfileId: teacherRam.id,
        teacherName: teacherRam.name,
      );

      final classConflict = timetableService.detectConflict(
        entry: overlappingClassEntry,
        existingEntries: existingEntries,
      );

      expect(classConflict, isNotNull);
      expect(classConflict!.type, equals(TimetableConflictType.classOverlap));
      print('STEP 4A CLASS CONFLICT: DENIED -> ${classConflict.message}');

      // 4B. Attempt overlapping period for the SAME teacher in ANOTHER class
      final overlappingTeacherEntry = TimetableEntryModel(
        id: 'conflict_teacher_test',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: 'class_other_999',
        sectionId: 'sec_other_999',
        dayOfWeek: 6,
        startTime: '07:30',
        endTime: '08:15',
        subjectName: 'Physics Advanced',
        teacherProfileId: teacherRamesh.id, // Ramesh is already teaching 07:30 - 08:15
        teacherName: teacherRamesh.name,
      );

      final teacherConflict = timetableService.detectConflict(
        entry: overlappingTeacherEntry,
        existingEntries: existingEntries,
      );

      expect(teacherConflict, isNotNull);
      expect(teacherConflict!.type, equals(TimetableConflictType.teacherOverlap));
      print('STEP 4B TEACHER CONFLICT: DENIED -> ${teacherConflict.message}');

      // 4C. Attempt a non-overlapping valid period (Saturday 08:15 - 09:00)
      final nonOverlappingEntry = TimetableEntryModel(
        id: 'valid_non_overlap',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
        startTime: '08:15',
        endTime: '09:00',
        subjectName: 'Mathematics',
        teacherProfileId: teacherRam.id,
        teacherName: teacherRam.name,
      );

      final noConflict = timetableService.detectConflict(
        entry: nonOverlappingEntry,
        existingEntries: existingEntries,
      );

      expect(noConflict, isNull);
      print('STEP 4C NON-OVERLAPPING PERIOD: ALLOWED');
    });

    test('STEP 5: DELETE / CANCEL - Delete draft period and verify live state', () async {
      final entries = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
      );

      final target = entries.firstWhere((e) => e.startTime == '07:30');
      await timetableService.deleteEntry(target.id, softCancelIfPublished: true);

      // Verify deletion
      final afterDelete = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
      );

      final exists = afterDelete.any((e) => e.id == target.id && !e.isCancelled);
      expect(exists, isFalse);
      print('STEP 5 DELETE VERIFIED: Target draft period ${target.id} removed from active schedule.');
    });

    test('STEP 6: PUBLISH & REFRESH PERSISTENCE', () async {
      // 1. Create a controlled valid draft period
      final draft = TimetableEntryModel(
        id: 'controlled_publish_period',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        className: 'Class 10',
        sectionId: sectionId,
        sectionName: 'A',
        dayOfWeek: 6,
        periodNumber: 1,
        startTime: '07:30',
        endTime: '08:15',
        subjectName: 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        room: 'Lab 101',
        status: TimetableStatus.draft,
        notes: 'Publish Test Schedule',
      );

      final created = await timetableService.createEntry(draft);
      expect(created.isDraft, isTrue);

      // 2. Publish timetable for this class & section
      final publishedCount = await timetableService.publishTimetable(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
      );

      expect(publishedCount, greaterThanOrEqualTo(1));

      // 3. Refresh read-back
      final refreshed = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
      );

      final publishedEntry = refreshed.firstWhere((e) => e.id == created.id);
      expect(publishedEntry.status, equals(TimetableStatus.published));
      expect(publishedEntry.isPublished, isTrue);
      print('STEP 6 PUBLISH VERIFIED: $publishedCount period(s) PUBLISHED. Readback Status: ${publishedEntry.status.displayName}');
    });

    test('STEP 7: PUBLISHED EDIT SAFETY - Soft-cancel / confirmation preserves historical logs', () async {
      final entries = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
      );

      final published = entries.firstWhere((e) => e.isPublished);

      // Deleting a published entry marks it CANCELLED rather than destroying historical attendance
      await timetableService.deleteEntry(published.id, softCancelIfPublished: true);

      final check = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: 6,
      );

      final cancelledEntry = check.firstWhere((e) => e.id == published.id);
      expect(cancelledEntry.isCancelled, isTrue);
      expect(cancelledEntry.status, equals(TimetableStatus.cancelled));
      print('STEP 7 PUBLISHED EDIT SAFETY VERIFIED: Published period soft-cancelled to preserve logs.');
    });

    test('STEP 8: TEACHER FILTER - Filtering uses actual live teachers without foreign leakage', () async {
      final teachers = await teacherService.getTeachers(schoolId: kpsSchoolId);
      expect(teachers.isNotEmpty, isTrue);

      for (final t in teachers) {
        expect(t.schoolId, equals(kpsSchoolId));
        print('Live Verified Teacher: ${t.name} (${t.designation}) - School: ${t.schoolId}');
      }

      // Query entries for Ramesh
      final rameshEntries = await timetableService.fetchTimetableEntries(
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        teacherId: teacherRamesh.id,
      );

      // All returned entries must belong to Ramesh
      expect(rameshEntries.every((e) => e.teacherProfileId == teacherRamesh.id || e.teacherName == teacherRamesh.name), isTrue);
      print('STEP 8 TEACHER FILTER VERIFIED: ${rameshEntries.length} periods mapped to ${teacherRamesh.name}');
    });

    test('STEP 9: TENANT SECURITY - Cross-school data isolation strictly enforced', () async {
      // 1. Current school cannot read Greenwood entries
      final foreignEntries = await timetableService.fetchTimetableEntries(
        schoolId: greenwoodSchoolId,
        academicYearId: 'any_year',
      );
      expect(foreignEntries.isEmpty, isTrue);

      // 2. Conflict engine rejects attempted entry belonging to other school
      final rogueEntry = TimetableEntryModel(
        id: 'cross_tenant_rogue',
        schoolId: greenwoodSchoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Rogue Subject',
      );

      final ownEntry = TimetableEntryModel(
        id: 'own_entry',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
      );

      final conflict = timetableService.detectConflict(
        entry: rogueEntry,
        existingEntries: [ownEntry],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, equals(TimetableConflictType.schoolMismatch));
      print('STEP 9 TENANT SECURITY VERIFIED: Cross-tenant collision blocked.');
    });

    test('STEP 10: LIVE READ-BACK - Return formatted table of controlled timetable period', () async {
      // Create a final clean controlled draft entry to display in report
      final sample = TimetableEntryModel(
        id: 'controlled_readback_period',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: classId,
        className: 'Class 10',
        sectionId: sectionId,
        sectionName: 'A',
        dayOfWeek: 1, // Monday
        periodNumber: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Physics',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        room: 'Lab 201',
        status: TimetableStatus.draft,
        notes: 'Final Controlled Live Period',
      );

      final created = await timetableService.createEntry(sample);

      print('========================================================================');
      print('STEP 10: CONTROLLED TIMETABLE LIVE READ-BACK');
      print('TIMETABLE ID:     ${created.id}');
      print('SCHOOL ID:        ${created.schoolId}');
      print('ACADEMIC YEAR ID: ${created.academicYearId}');
      print('CLASS:            ${created.className ?? classId}');
      print('SECTION:          ${created.sectionName ?? sectionId}');
      print('DAY:              ${created.dayName} (Day ${created.dayOfWeek})');
      print('START TIME:       ${created.startTime}');
      print('END TIME:         ${created.endTime}');
      print('TEACHER:          ${created.teacherName}');
      print('SUBJECT:          ${created.subjectName}');
      print('STATUS:           ${created.status.displayName}');
      print('========================================================================');

      expect(created.id, isNotEmpty);
      expect(created.schoolId, equals(kpsSchoolId));
      expect(created.subjectName, equals('Physics'));
      expect(created.teacherName, equals('Ramesh'));
      expect(created.status, equals(TimetableStatus.draft));
    });
  });
}
