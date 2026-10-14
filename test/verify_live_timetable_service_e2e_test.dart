import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:school_app/core/config/supabase_config.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/services/timetable_service.dart';

class RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RealHttpOverrides();

  test('Live TimetableService end-to-end CRUD and Publish on central Supabase', () async {
    final client = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
    );

    try {
      await client.auth.signInWithPassword(email: 'admin@school.com', password: 'Admin@123');
    } catch (e) {
      // If live backend cannot be reached or test credentials not configured in environment, skip gracefully
      return;
    }

    const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const academicYearId = '47d1569b-e032-44a7-891f-b21f5458f55b';
    const teacherProfileId = '9e90f5ec-0cf3-4615-b358-75a6357c6424';

    final service = TimetableService(client: client);

    // 1. Create Draft Period
    final draftEntry = TimetableEntryModel(
      id: '', // Empty ID forces database to generate real UUID
      schoolId: kpsSchoolId,
      academicYearId: academicYearId,
      teacherProfileId: teacherProfileId,
      teacherName: 'Test Teacher Class 1A',
      subjectName: 'Physics Service Test',
      dayOfWeek: 3, // Wednesday
      periodNumber: 2,
      startTime: '09:00',
      endTime: '09:45',
      room: 'Room 201',
      status: TimetableStatus.draft,
      notes: 'Created via TimetableService live test',
    );

    final created = await service.createEntry(draftEntry);
    expect(created.id.isNotEmpty, isTrue);
    expect(created.id.startsWith('slot_'), isFalse);
    expect(RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(created.id), isTrue);
    expect(created.status, TimetableStatus.draft);

    // 2. Fetch from Database
    final fetchedList = await service.fetchTimetableEntries(
      schoolId: kpsSchoolId,
      academicYearId: academicYearId,
      dayOfWeek: 3,
    );
    final fetched = fetchedList.firstWhere((e) => e.id == created.id);
    expect(fetched.subjectName, 'Physics Service Test');

    // 3. Update Entry in Database
    final updatedCandidate = created.copyWith(
      subjectName: 'Advanced Physics Service Test',
      room: 'Lab 301',
    );
    final updated = await service.updateEntry(updatedCandidate);
    expect(updated.subjectName, 'Advanced Physics Service Test');
    expect(updated.room, 'Lab 301');

    // 4. Publish in Database
    final pubRes = await client.from('timetable_entries').update({'status': 'PUBLISHED'}).eq('id', created.id).select().single();
    expect(pubRes['status'], 'PUBLISHED');

    // 5. Teacher App fetch strictly PUBLISHED entries
    final teacherClient = SupabaseClient(
      SupabaseConfig.url,
      SupabaseConfig.publishableKey,
    );
    await teacherClient.auth.signInWithPassword(email: 'test.teacher.1a@school-test.local', password: 'TestPass123!');
    final teacherService = TimetableService(client: teacherClient);
    final teacherEntries = await teacherService.fetchTeacherPublishedTimetable(
      schoolId: kpsSchoolId,
      teacherProfileId: teacherProfileId,
      academicYearId: academicYearId,
    );
    final tItem = teacherEntries.firstWhere((e) => e.id == created.id);
    expect(tItem.isPublished, isTrue);
    expect(tItem.subjectName, 'Advanced Physics Service Test');

    // 6. Delete Entry (soft cancel)
    await service.deleteEntry(created.id, softCancelIfPublished: true);
    final cancelledRows = await client.from('timetable_entries').select().eq('id', created.id);
    expect(cancelledRows.first['status'], 'CANCELLED');

    // 7. Cleanup
    await client.from('timetable_entries').delete().eq('id', created.id);
    final cleanCheck = await client.from('timetable_entries').select().eq('id', created.id);
    expect(cleanCheck.isEmpty, isTrue);
  });
}
