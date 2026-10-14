import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/services/academic_year_service.dart';
import 'package:school_app/data/services/teacher_service.dart';
import 'package:school_app/data/services/timetable_service.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
  const greenwoodSchoolId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';
  const adminEmail = 'test.teacher.1a@school-test.local';
  const adminPassword = 'TestPass123!';

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

  group('Live Teacher App Published Timetable Verification', () {
    late SupabaseClient client;
    late AcademicYearService ayService;
    late TeacherService teacherService;
    late TimetableService timetableService;

    late String academicYearId;
    late TeacherModel teacherRamesh;
    late TeacherModel teacherRam;

    setUpAll(() async {
      client = Supabase.instance.client;
      ayService = AcademicYearService();
      teacherService = TeacherService();
      timetableService = TimetableService();

      try {
        await client.auth.signInWithPassword(email: adminEmail, password: adminPassword);
      } catch (e) {
        print('Live sign-in note: $e');
      }

      // Resolve current academic year
      final years = await ayService.fetchAcademicYears(kpsSchoolId);
      final currentYear = AcademicYearOption.resolveCurrent(years) ?? (years.isNotEmpty ? years.first : null);
      academicYearId = currentYear?.id ?? '00000000-0000-0000-0000-000000000001';

      // Load existing real teachers
      final teachers = await teacherService.getTeachers(schoolId: kpsSchoolId);
      teacherRamesh = teachers.firstWhere(
        (t) => t.name.toLowerCase().contains('ramesh'),
        orElse: () => teachers.first,
      );
      teacherRam = teachers.firstWhere(
        (t) => t.name.toLowerCase().contains('ram') && !t.name.toLowerCase().contains('ramesh'),
        orElse: () => teachers.length > 1 ? teachers[1] : teachers.first,
      );
    });

    test('LIVE: Admin sets up controlled published & draft periods for real teachers', () async {
      // 1. Published period for Ramesh
      final rameshPub = TimetableEntryModel(
        id: 'live_ramesh_pub_period',
        schoolId: kpsSchoolId,
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
        room: 'Lab 201',
        status: TimetableStatus.published,
      );
      await timetableService.createEntry(rameshPub);

      // 2. Draft period for Ramesh (Must be HIDDEN in teacher app)
      final rameshDraft = TimetableEntryModel(
        id: 'live_ramesh_draft_period',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: 'class_10',
        className: 'Class 10',
        sectionId: 'sec_a',
        sectionName: 'A',
        dayOfWeek: 1, // Monday
        periodNumber: 2,
        startTime: '09:15',
        endTime: '10:00',
        subjectName: 'Physics Advanced',
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        room: 'Lab 201',
        status: TimetableStatus.draft,
      );
      await timetableService.createEntry(rameshDraft);

      // 3. Published period for Ram (Must be HIDDEN from Ramesh)
      final ramPub = TimetableEntryModel(
        id: 'live_ram_pub_period',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        classId: 'class_5',
        className: 'Class 5',
        sectionId: 'sec_a',
        sectionName: 'A',
        dayOfWeek: 1, // Monday
        periodNumber: 3,
        startTime: '10:15',
        endTime: '11:00',
        subjectName: 'Mathematics',
        teacherProfileId: teacherRam.id,
        teacherName: teacherRam.name,
        room: 'Room 101',
        status: TimetableStatus.published,
      );
      await timetableService.createEntry(ramPub);

      // 4. Published period in Greenwood (Must be HIDDEN from KPS teacher)
      final greenwoodPub = TimetableEntryModel(
        id: 'live_greenwood_pub_period',
        schoolId: greenwoodSchoolId,
        academicYearId: academicYearId,
        classId: 'class_gw',
        className: 'Class 8',
        sectionId: 'sec_gw',
        sectionName: 'A',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:30',
        endTime: '09:15',
        subjectName: 'Chemistry',
        teacherProfileId: 'foreign_teacher',
        teacherName: 'Greenwood Faculty',
        status: TimetableStatus.published,
      );
      await timetableService.createEntry(greenwoodPub);

      expect(timetableService.cachedEntries.length, greaterThanOrEqualTo(4));
    });

    test('LIVE: Teacher Ramesh views timetable - Verify all 10 criteria', () async {
      // Fetch timetable strictly for authenticated teacher Ramesh
      final rameshTimetable = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherRamesh.id,
        teacherName: teacherRamesh.name,
        academicYearId: academicYearId,
      );

      print('========================================================================');
      print('TEACHER RAMESH PUBLISHED TIMETABLE VIEW READ-BACK:');
      for (final p in rameshTimetable) {
        print('  - [P${p.periodNumber}] ${p.startTime} - ${p.endTime} | ${p.subjectName} | ${p.className} (${p.sectionName}) | Room: ${p.room} | Status: ${p.status.displayName}');
      }
      print('========================================================================');

      // 1. Published period appears
      expect(rameshTimetable.any((e) => e.id == 'live_ramesh_pub_period'), isTrue);

      final period = rameshTimetable.firstWhere((e) => e.id == 'live_ramesh_pub_period');

      // 2. Correct subject
      expect(period.subjectName, equals('Physics'));

      // 3. Correct class
      expect(period.className, equals('Class 10'));

      // 4. Correct section
      expect(period.sectionName, equals('A'));

      // 5. Correct time
      expect(period.startTime, equals('08:30'));
      expect(period.endTime, equals('09:15'));

      // 6. Draft periods are hidden
      expect(rameshTimetable.any((e) => e.id == 'live_ramesh_draft_period'), isFalse);
      expect(rameshTimetable.any((e) => e.isDraft), isFalse);

      // 7. Other teacher (Ram) periods are hidden
      expect(rameshTimetable.any((e) => e.id == 'live_ram_pub_period'), isFalse);
      expect(rameshTimetable.any((e) => e.teacherName == 'Ram'), isFalse);

      // 8. Cross-school periods (Greenwood) are hidden
      expect(rameshTimetable.any((e) => e.schoolId == greenwoodSchoolId), isFalse);

      // 9. Status is strictly published
      expect(rameshTimetable.every((e) => e.isPublished), isTrue);

      // 10. Teacher profile ID matches authenticated teacher
      expect(rameshTimetable.every((e) => e.teacherProfileId == teacherRamesh.id || e.teacherName == teacherRamesh.name), isTrue);
    });

    test('LIVE: Teacher Ram views timetable - Cross-teacher verification', () async {
      // Fetch timetable strictly for authenticated teacher Ram
      final ramTimetable = await timetableService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherRam.id,
        teacherName: teacherRam.name,
        academicYearId: academicYearId,
      );

      print('========================================================================');
      print('TEACHER RAM PUBLISHED TIMETABLE VIEW READ-BACK:');
      for (final p in ramTimetable) {
        print('  - [P${p.periodNumber}] ${p.startTime} - ${p.endTime} | ${p.subjectName} | ${p.className} (${p.sectionName}) | Room: ${p.room} | Status: ${p.status.displayName}');
      }
      print('========================================================================');

      // Ram sees only his period
      expect(ramTimetable.any((e) => e.id == 'live_ram_pub_period'), isTrue);
      expect(ramTimetable.any((e) => e.teacherName == 'Ramesh'), isFalse);
      expect(ramTimetable.every((e) => e.teacherProfileId == teacherRam.id || e.teacherName == teacherRam.name), isTrue);
    });
  });
}
