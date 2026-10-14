import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/academic_year_service.dart';
import 'package:school_app/data/services/timetable_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/features/teacher/teacher_timetable_screen.dart';

class RealHttpOverrides extends HttpOverrides {}

class MockAcademicYearService extends AcademicYearService {
  @override
  Future<List<AcademicYearModel>> fetchAcademicYears(String schoolId) async {
    return [
      AcademicYearModel(
        id: '47d1569b-e032-44a7-891f-b21f5458f55b',
        schoolId: schoolId,
        name: '2025-2026',
        startDate: DateTime(2025, 4, 1),
        endDate: DateTime(2026, 3, 31),
        isCurrent: true,
        createdAt: DateTime(2025, 4, 1),
      ),
    ];
  }
}

class MockTimetableService extends TimetableService {
  final List<TimetableEntryModel> _mockEntries = [];

  MockTimetableService([List<TimetableEntryModel>? initial]) {
    if (initial != null) _mockEntries.addAll(initial);
  }

  @override
  Future<List<TimetableEntryModel>> fetchTeacherPublishedTimetable({
    required String schoolId,
    required String teacherProfileId,
    String? teacherName,
    String? academicYearId,
  }) async {
    return _mockEntries.where((e) => e.isPublished && !e.isCancelled).toList();
  }
}

class MockAuthNotifier extends StateNotifier<UserModel?> implements AuthNotifier {
  UserProfileModel? _profile;

  MockAuthNotifier(UserModel user) : super(user) {
    _profile = UserProfileModel(
      id: user.id,
      authUserId: user.id,
      schoolId: user.schoolId ?? '',
      schoolName: user.schoolName,
      name: user.name,
      email: user.email,
      role: user.role,
      status: AccountStatus.active,
      designation: user.designation,
      createdAt: DateTime.now(),
    );
  }

  @override
  UserProfileModel? get activeProfile => _profile;

  @override
  void setUserProfile(UserProfileModel profile) {
    _profile = profile;
    state = UserModel(
      id: profile.id,
      schoolId: profile.schoolId,
      name: profile.name,
      email: profile.email,
      role: profile.role,
      avatarUrl: profile.avatarUrl ?? '',
      schoolName: profile.schoolName,
      designation: profile.designation,
    );
  }

  @override
  void login(UserRole role) {}

  @override
  Future<void> refreshProfile() async {}

  @override
  Future<void> logout() async {
    _profile = null;
    state = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
  const academicYearId = '47d1569b-e032-44a7-891f-b21f5458f55b';
  const teacherAProfileId = '9e90f5ec-0cf3-4615-b358-75a6357c6424'; // Test Teacher Class 1A
  const teacherBProfileId = '435a339e-4cd7-4963-9add-616d4f60b255'; // Ramesh (same school)

  late SupabaseClient adminClient;
  late SupabaseClient teacherAClient;
  late TimetableService adminService;
  late TimetableService teacherAService;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(),
        ),
      );
    } catch (_) {}

    // 1. Authenticate Admin session
    adminClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
    );
    try {
      await adminClient.auth.signInWithPassword(
        email: 'admin@school.com',
        password: 'password123',
      );
    } catch (e) {
      print('Admin sign-in note: $e');
    }
    adminService = TimetableService(client: adminClient);

    // 2. Authenticate as Teacher A
    teacherAClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
    );
    await teacherAClient.auth.signInWithPassword(
      email: 'test.teacher.1a@school-test.local',
      password: 'TestPass123!',
    );
    teacherAService = TimetableService(client: teacherAClient);
  });

  group('Teacher App Live E2E Verification Tests (1 through 6)', () {
    String? test1EntryId;
    String? teacherBEntryId;

    tearDownAll(() async {
      // Clean up test entries once all tests complete
      if (test1EntryId != null) {
        try {
          await adminClient.from('timetable_entries').delete().eq('id', test1EntryId!);
        } catch (_) {}
      }
      if (teacherBEntryId != null) {
        try {
          await adminClient.from('timetable_entries').delete().eq('id', teacherBEntryId!);
        } catch (_) {}
      }
    });

    test('TEST 1: Admin creates DRAFT timetable for Teacher A -> NOT visible to Teacher A', () async {
      final draft = TimetableEntryModel(
        id: '',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        teacherProfileId: teacherAProfileId,
        teacherName: 'Test Teacher Class 1A',
        subjectName: 'Test Draft Biology',
        dayOfWeek: 2, // Tuesday
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
        room: 'Lab 1',
        status: TimetableStatus.draft,
        notes: 'Live Test 1 Draft',
      );

      final created = await adminService.createEntry(draft);
      test1EntryId = created.id;
      expect(test1EntryId, isNotEmpty);
      expect(created.isDraft, isTrue);

      // Teacher A fetches published timetable
      final teacherEntries = await teacherAService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherAProfileId,
        academicYearId: academicYearId,
      );

      final matches = teacherEntries.where((e) => e.id == test1EntryId).toList();
      expect(matches, isEmpty, reason: 'DRAFT period must NOT be visible to Teacher A');

      // Also verify via raw query with Teacher A token
      final rawResp = await teacherAClient
          .from('timetable_entries')
          .select()
          .eq('id', test1EntryId!);
      expect((rawResp as List), isEmpty, reason: 'Teacher RLS must block SELECT on DRAFT rows');
    });

    test('TEST 2: Admin publishes that same entry -> becomes visible to Teacher A', () async {
      expect(test1EntryId, isNotNull);

      // Admin publishes entry
      final updateRes = await adminClient
          .from('timetable_entries')
          .update({'status': 'PUBLISHED', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', test1EntryId!)
          .select()
          .single();
      expect(updateRes['status'], 'PUBLISHED');

      // Teacher A refreshes timetable
      final teacherEntries = await teacherAService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherAProfileId,
        academicYearId: academicYearId,
      );

      final match = teacherEntries.firstWhere((e) => e.id == test1EntryId);
      expect(match.isPublished, isTrue);
      expect(match.subjectName, 'Test Draft Biology');
      expect(match.periodNumber, 1);
      expect(match.room, 'Lab 1');
    });

    test('TEST 3: Change entry to CANCELLED -> disappears from Teacher A', () async {
      expect(test1EntryId, isNotNull);

      // Soft cancel entry
      await adminService.deleteEntry(test1EntryId!, softCancelIfPublished: true);

      // Verify in DB that it is CANCELLED
      final dbCheck = await adminClient.from('timetable_entries').select('status').eq('id', test1EntryId!).single();
      expect(dbCheck['status'], 'CANCELLED');

      // Teacher A refreshes
      final teacherEntries = await teacherAService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherAProfileId,
        academicYearId: academicYearId,
      );

      final matches = teacherEntries.where((e) => e.id == test1EntryId).toList();
      expect(matches, isEmpty, reason: 'CANCELLED entry must NOT appear in Teacher A timetable');

      // Clean up Test 1 entry now that it's verified
      await adminClient.from('timetable_entries').delete().eq('id', test1EntryId!);
      test1EntryId = null;
    });

    test('TEST 4: Create a PUBLISHED entry for Teacher B -> NOT visible to Teacher A', () async {
      final bEntry = TimetableEntryModel(
        id: '',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        teacherProfileId: teacherBProfileId,
        teacherName: 'Ramesh',
        subjectName: 'Teacher B Chemistry',
        dayOfWeek: 3,
        periodNumber: 4,
        startTime: '11:00',
        endTime: '11:45',
        room: 'Lab B',
        status: TimetableStatus.published,
      );

      final createdB = await adminService.createEntry(bEntry);
      teacherBEntryId = createdB.id;
      expect(teacherBEntryId, isNotEmpty);

      // Ensure published in DB
      await adminClient.from('timetable_entries').update({'status': 'PUBLISHED'}).eq('id', teacherBEntryId!);

      // Teacher A fetches timetable
      final teacherAEntries = await teacherAService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherAProfileId,
        academicYearId: academicYearId,
      );

      final matches = teacherAEntries.where((e) => e.id == teacherBEntryId).toList();
      expect(matches, isEmpty, reason: 'Teacher B entry must NEVER appear in Teacher A timetable');

      // Also verify direct RLS filter
      final rawResp = await teacherAClient
          .from('timetable_entries')
          .select()
          .eq('id', teacherBEntryId!);
      expect((rawResp as List), isEmpty, reason: 'Teacher A RLS must block viewing Teacher B records');

      // Clean up Teacher B entry
      await adminClient.from('timetable_entries').delete().eq('id', teacherBEntryId!);
      teacherBEntryId = null;
    });

    test('TEST 5: Cross-school published entry cannot appear in Teacher A timetable', () async {
      const otherSchoolId = 'cf895651-4783-489b-8551-959a70098ca8';

      // Attempt querying with other school ID as Teacher A
      final crossSchoolEntries = await teacherAService.fetchTeacherPublishedTimetable(
        schoolId: otherSchoolId,
        teacherProfileId: teacherAProfileId,
      );
      expect(crossSchoolEntries, isEmpty, reason: 'Teacher A cannot view another school timetable');

      final rawCrossSchool = await teacherAClient
          .from('timetable_entries')
          .select()
          .eq('school_id', otherSchoolId);
      expect((rawCrossSchool as List), isEmpty, reason: 'RLS must block cross-school records');
    });

    test('TEST 6: Force app refresh/reload -> data loaded from Supabase and remains correct', () async {
      // 1. Create a published entry for Teacher A
      final entry = TimetableEntryModel(
        id: '',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        teacherProfileId: teacherAProfileId,
        teacherName: 'Test Teacher Class 1A',
        subjectName: 'Live Reload Physics',
        dayOfWeek: 4, // Thursday
        periodNumber: 2,
        startTime: '09:15',
        endTime: '10:00',
        room: 'Room 404',
        status: TimetableStatus.published,
      );

      final created = await adminService.createEntry(entry);
      final entryId = created.id;
      await adminClient.from('timetable_entries').update({'status': 'PUBLISHED'}).eq('id', entryId);

      try {
        // Initial fetch
        final initialFetch = await teacherAService.fetchTeacherPublishedTimetable(
          schoolId: kpsSchoolId,
          teacherProfileId: teacherAProfileId,
          academicYearId: academicYearId,
        );
        expect(initialFetch.any((e) => e.id == entryId), isTrue);

        // Force a second distinct reload from Supabase
        final freshTeacherService = TimetableService(client: teacherAClient);
        final reloaded = await freshTeacherService.fetchTeacherPublishedTimetable(
          schoolId: kpsSchoolId,
          teacherProfileId: teacherAProfileId,
          academicYearId: academicYearId,
        );
        final match = reloaded.firstWhere((e) => e.id == entryId);
        expect(match.subjectName, 'Live Reload Physics');
        expect(match.startTime, '09:15');
        expect(match.endTime, '10:00');
        expect(match.room, 'Room 404');
        expect(match.isPublished, isTrue);
      } finally {
        await adminClient.from('timetable_entries').delete().eq('id', entryId);
      }
    });

    test('TEST 7: Security Smoke Test - Inactive teacher cannot read published entries via App query or RLS', () async {
      // 1. Create a published test entry for Teacher A
      final testEntry = TimetableEntryModel(
        id: '',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        teacherProfileId: teacherAProfileId,
        teacherName: 'Test Teacher Class 1A',
        subjectName: 'Security Inactive Physics',
        dayOfWeek: 2, // Tuesday
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
        room: 'Lab 200',
        status: TimetableStatus.published,
      );

      final created = await adminService.createEntry(testEntry);
      final entryId = created.id;
      await adminClient.from('timetable_entries').update({'status': 'PUBLISHED'}).eq('id', entryId);

      // 2. Active Teacher A queries -> MUST see their own published entry
      final activeEntries = await teacherAService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherAProfileId,
        academicYearId: academicYearId,
      );
      expect(activeEntries.any((e) => e.id == entryId), isTrue,
          reason: 'Active Teacher A must read own published timetable');
      expect(activeEntries.every((e) => e.isPublished && !e.isCancelled), isTrue,
          reason: 'Active Teacher A must not receive draft or cancelled entries');

      try {
        // 3. Temporarily simulate an INACTIVE teacher profile in public.profiles
        await adminClient.from('profiles').update({'status': 'INACTIVE'}).eq('id', teacherAProfileId);

        // 4. Query via Teacher App service as inactive teacher -> MUST return empty
        final inactiveEntries = await teacherAService.fetchTeacherPublishedTimetable(
          schoolId: kpsSchoolId,
          teacherProfileId: teacherAProfileId,
          academicYearId: academicYearId,
        );
        expect(inactiveEntries, isEmpty,
            reason: 'Inactive teacher profile must not receive any published entries');

        // 5. Direct Supabase RLS query as Teacher A -> MUST be blocked by RLS
        final rawRlsResp = await teacherAClient
            .from('timetable_entries')
            .select()
            .eq('id', entryId);
        expect((rawRlsResp as List), isEmpty,
            reason: 'Inactive teacher auth session must be blocked by Supabase RLS');
      } finally {
        // 6. Restore Teacher A profile back to ACTIVE status
        await adminClient.from('profiles').update({'status': 'ACTIVE'}).eq('id', teacherAProfileId);

        // 7. Clean up temporary test entry
        await adminClient.from('timetable_entries').delete().eq('id', entryId);
      }

      // 8. Confirm restoration: Active Teacher A can query without residual test data
      final restoredEntries = await teacherAService.fetchTeacherPublishedTimetable(
        schoolId: kpsSchoolId,
        teacherProfileId: teacherAProfileId,
        academicYearId: academicYearId,
      );
      expect(restoredEntries.any((e) => e.id == entryId), isFalse,
          reason: 'Cleaned-up test entry must no longer exist');
    });
  });

  group('TeacherTimetableScreen Widget UI States & Data Mapping', () {
    testWidgets('UI State: renders empty state when teacher has 0 published entries', (tester) async {
      final emptyService = MockTimetableService([]);

      final teacherUser = UserModel(
        id: teacherAProfileId,
        schoolId: kpsSchoolId,
        name: 'Test Teacher Class 1A',
        email: 'test.teacher.1a@school-test.local',
        role: UserRole.teacher,
        avatarUrl: '',
        schoolName: 'KPS',
        designation: 'Teacher',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(teacherUser)),
            academicYearServiceProvider.overrideWithValue(MockAcademicYearService()),
            timetableServiceProvider.overrideWithValue(emptyService),
          ],
          child: const MaterialApp(
            home: TeacherTimetableScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('My Timetable'), findsOneWidget);
      expect(find.text('PUBLISHED'), findsOneWidget);
      expect(find.text('No published timetable yet'), findsOneWidget);
      expect(find.text('Check for Updates'), findsOneWidget);
    });

    testWidgets('UI State & Data Mapping: populated timetable renders all fields correctly', (tester) async {
      final sampleEntry = TimetableEntryModel(
        id: '9f3b5b57-ee0d-4064-bba6-9550dba6b431',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        teacherProfileId: teacherAProfileId,
        teacherName: 'Test Teacher Class 1A',
        className: 'Class 10',
        sectionName: 'A',
        dayOfWeek: DateTime.now().weekday <= 6 ? DateTime.now().weekday : 1,
        periodNumber: 3,
        startTime: '10:00',
        endTime: '10:45',
        subjectName: 'Mathematics',
        room: 'Lab 101',
        status: TimetableStatus.published,
      );

      final mockService = MockTimetableService([sampleEntry]);

      final teacherUser = UserModel(
        id: teacherAProfileId,
        schoolId: kpsSchoolId,
        name: 'Test Teacher Class 1A',
        email: 'test.teacher.1a@school-test.local',
        role: UserRole.teacher,
        avatarUrl: '',
        schoolName: 'KPS',
        designation: 'Teacher',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(teacherUser)),
            academicYearServiceProvider.overrideWithValue(MockAcademicYearService()),
            timetableServiceProvider.overrideWithValue(mockService),
          ],
          child: const MaterialApp(
            home: TeacherTimetableScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // 1. Data mapping verification
      expect(find.text('My Timetable'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Week View'), findsOneWidget);

      // Subject name displayed
      expect(find.text('Mathematics'), findsWidgets);

      // Class and Section displayed
      expect(find.text('Class 10 A'), findsWidgets);

      // Time format displayed
      expect(find.textContaining('10:00 – 10:45'), findsWidgets);

      // Room displayed
      expect(find.textContaining('Lab 101'), findsWidgets);

      // Duration displayed
      expect(find.textContaining('45 min'), findsWidgets);

      // 2. Day switching to Week View
      await tester.tap(find.text('Week View'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Monday'), findsOneWidget);
      expect(find.textContaining('Tuesday'), findsOneWidget);
      expect(find.textContaining('Wednesday'), findsOneWidget);
      expect(find.textContaining('Thursday'), findsOneWidget);
      expect(find.textContaining('Friday'), findsOneWidget);
      expect(find.textContaining('Saturday'), findsOneWidget);

      // 3. Test refresh button in AppBar
      expect(find.byTooltip('Refresh Schedule'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh Schedule'));
      await tester.pumpAndSettle();
    });

    testWidgets('Security Smoke Test: Inactive teacher profile displays inactive error banner and blocks timetable view', (tester) async {
      final sampleEntry = TimetableEntryModel(
        id: '9f3b5b57-ee0d-4064-bba6-9550dba6b431',
        schoolId: kpsSchoolId,
        academicYearId: academicYearId,
        teacherProfileId: teacherAProfileId,
        teacherName: 'Inactive Teacher',
        className: 'Class 10',
        sectionName: 'A',
        dayOfWeek: 1,
        periodNumber: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'Mathematics',
        status: TimetableStatus.published,
      );

      final mockService = MockTimetableService([sampleEntry]);

      final inactiveTeacherUser = UserModel(
        id: teacherAProfileId,
        schoolId: kpsSchoolId,
        name: 'Inactive Teacher',
        email: 'test.teacher.1a@school-test.local',
        role: UserRole.teacher,
        avatarUrl: '',
        schoolName: 'KPS',
        designation: 'Teacher',
        status: AccountStatus.inactive,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => MockAuthNotifier(inactiveTeacherUser)),
            academicYearServiceProvider.overrideWithValue(MockAcademicYearService()),
            timetableServiceProvider.overrideWithValue(mockService),
          ],
          child: const MaterialApp(
            home: TeacherTimetableScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Teacher profile is inactive. Please contact your school administrator.'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
      expect(find.text('Week View'), findsNothing);
    });
  });
}
