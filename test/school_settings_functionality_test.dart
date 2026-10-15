import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/academic_year_service.dart';
import 'package:school_app/data/services/attendance_service.dart';
import 'package:school_app/data/services/school_service.dart';
import 'package:school_app/data/services/teacher_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('School Settings, Dynamic Branding & Preferences Test Suite', () {
    const testSchoolId = 'sch-uuid-delhi-campus-001';

    test('1. SchoolService: fetchSchoolProfile returns dynamic model without St. Xavier fallback', () async {
      final service = SchoolService();
      final school = await service.fetchSchoolProfile(testSchoolId);

      expect(school.id, equals(testSchoolId));
      expect(school.name, isNot(contains('St. Xavier')));
      expect(school.name, isNot(contains('Xavier')));
    });

    test('2. SchoolService: updateSchoolProfile persists school details including address, phone, email', () async {
      final service = SchoolService();
      final updated = await service.updateSchoolProfile(
        schoolId: testSchoolId,
        name: 'Delhi Public Command Academy',
        address: 'Sector 14, Ring Road, New Delhi',
        phone: '+91 11 2890 1234',
        email: 'admin@delhicommand.edu',
      );

      expect(updated.id, equals(testSchoolId));
      expect(updated.name, equals('Delhi Public Command Academy'));
      expect(updated.address, equals('Sector 14, Ring Road, New Delhi'));
      expect(updated.phone, equals('+91 11 2890 1234'));
      expect(updated.email, equals('admin@delhicommand.edu'));
    });

    test('3. AcademicYearService: setCurrentAcademicYear activates the selected session for the school', () async {
      final service = AcademicYearService();

      // Create two sessions
      final y1 = await service.createAcademicYear(
        schoolId: testSchoolId,
        name: '2025-2026',
        startDate: DateTime(2025, 4, 1),
        endDate: DateTime(2026, 3, 31),
      );

      final y2 = await service.createAcademicYear(
        schoolId: testSchoolId,
        name: '2026-2027',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
      );

      // Set y2 as current
      final active = await service.setCurrentAcademicYear(id: y2.id, schoolId: testSchoolId);
      expect(active.id, equals(y2.id));
      expect(active.isCurrent, isTrue);

      // Verify active year resolution
      final resolved = await service.getActiveAcademicYear(testSchoolId);
      expect(resolved, isNotNull);
      expect(resolved!.id, equals(y2.id));
      expect(resolved.name, equals('2026-2027'));
    });

    test('4. AttendanceService: Cutoff time get, set, format, and evaluation', () async {
      final service = AttendanceService();

      // Default cutoff is 09:30 AM
      final initialCutoff = await service.getCutoffTime(testSchoolId);
      expect(initialCutoff.hour, equals(9));
      expect(initialCutoff.minute, equals(30));
      expect(service.formatCutoffTime(initialCutoff), equals('09:30 AM'));

      // Update cutoff to 10:15 AM
      await service.setCutoffTime(testSchoolId, const TimeOfDay(hour: 10, minute: 15));
      final updatedCutoff = await service.getCutoffTime(testSchoolId);
      expect(updatedCutoff.hour, equals(10));
      expect(updatedCutoff.minute, equals(15));
      expect(service.formatCutoffTime(updatedCutoff), equals('10:15 AM'));

      // Test cutoff checking
      final beforeTime = DateTime(2026, 10, 15, 9, 45); // 09:45 is before 10:15
      final afterTime = DateTime(2026, 10, 15, 10, 30);  // 10:30 is past 10:15
      expect(await service.isPastCutoff(testSchoolId, beforeTime), isFalse);
      expect(await service.isPastCutoff(testSchoolId, afterTime), isTrue);
    });

    test('5. TeacherService: Subject Catalog CRUD operations', () async {
      final service = TeacherService();

      // Create Subject
      final created = await service.createSubject(
        schoolId: testSchoolId,
        name: 'Advanced Robotics',
        code: 'ROBO101',
        type: 'PRACTICAL',
      );

      expect(created.name, equals('Advanced Robotics'));
      expect(created.code, equals('ROBO101'));
      expect(created.type, equals('PRACTICAL'));

      // List Subjects
      final list = await service.getSubjects(schoolId: testSchoolId);
      expect(list.any((s) => s.id == created.id), isTrue);

      // Update Subject
      final updated = await service.updateSubject(
        id: created.id,
        schoolId: testSchoolId,
        name: 'Advanced Robotics & AI',
        code: 'ROBO102',
        type: 'PRACTICAL',
      );
      expect(updated.name, equals('Advanced Robotics & AI'));
      expect(updated.code, equals('ROBO102'));

      // Delete Subject
      await service.deleteSubject(id: created.id, schoolId: testSchoolId);
      final listAfterDelete = await service.getSubjects(schoolId: testSchoolId);
      expect(listAfterDelete.any((s) => s.id == created.id), isFalse);
    });

    test('6. ThemeNotifier: Toggles Dark/Light mode and persists preference', () async {
      final notifier = ThemeNotifier();
      expect(notifier.state, equals(ThemeMode.light));

      await notifier.toggleTheme();
      expect(notifier.state, equals(ThemeMode.dark));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), equals('dark'));

      await notifier.toggleTheme();
      expect(notifier.state, equals(ThemeMode.light));
      expect(prefs.getString('app_theme_mode'), equals('light'));
    });

    test('7. OfflineSyncNotifier: Toggles auto-sync and persists preference', () async {
      final notifier = OfflineSyncNotifier();
      expect(notifier.state, isTrue);

      await notifier.toggle();
      expect(notifier.state, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('offline_queue_autosync'), isFalse);

      await notifier.setEnabled(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool('offline_queue_autosync'), isTrue);
    });

    test('8. PushNotificationNotifier: Toggles push alerts and persists preference', () async {
      final notifier = PushNotificationNotifier();
      expect(notifier.state, isTrue);

      await notifier.toggle();
      expect(notifier.state, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('push_notifications_enabled'), isFalse);

      await notifier.setEnabled(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool('push_notifications_enabled'), isTrue);
    });
  });
}
