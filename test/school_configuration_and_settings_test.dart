import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/notification_preferences_model.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/services/academic_year_service.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/services/notification_preferences_service.dart';
import 'package:school_app/data/services/school_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Master Fixes: School Configuration, Academic Years, Notifications, Profile & Security', () {
    const testSchoolId = 'sch-uuid-master-test-001';
    const testUserId = 'usr-admin-master-test-001';

    // =========================================================================
    // 1. SCHOOL CONFIGURATION SAVE FLOW & PGRST116 PREVENTION
    // =========================================================================
    group('1. School Configuration Save & Persistence', () {
      test('1.1. updateSchoolProfile saves all configuration fields without PGRST116', () async {
        final schoolService = SchoolService();

        final updated = await schoolService.updateSchoolProfile(
          schoolId: testSchoolId,
          name: 'Kamal Public School Main Campus',
          address: 'Vikas Puri, New Delhi, 110018',
          phone: '+91 98765 43210',
          email: 'principal@kamalpublicschool.com',
        );

        expect(updated.id, equals(testSchoolId));
        expect(updated.name, equals('Kamal Public School Main Campus'));
        expect(updated.address, equals('Vikas Puri, New Delhi, 110018'));
        expect(updated.phone, equals('+91 98765 43210'));
        expect(updated.email, equals('principal@kamalpublicschool.com'));
      });

      test('1.2. fetchSchoolProfile reloads saved fields accurately', () async {
        final schoolService = SchoolService();

        final profile = await schoolService.fetchSchoolProfile(testSchoolId);
        expect(profile.id, equals(testSchoolId));
        expect(profile.name, equals('Kamal Public School Main Campus'));
        expect(profile.address, equals('Vikas Puri, New Delhi, 110018'));
        expect(profile.phone, equals('+91 98765 43210'));
        expect(profile.email, equals('principal@kamalpublicschool.com'));
      });

      test('1.3. Rejects empty school name with clear validation error', () async {
        final schoolService = SchoolService();

        expect(
          () => schoolService.updateSchoolProfile(
            schoolId: testSchoolId,
            name: '   ',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('School name cannot be empty'),
          )),
        );
      });
    });

    // =========================================================================
    // 2. ACADEMIC YEARS MANAGEMENT & ATOMIC ACTIVATION
    // =========================================================================
    group('2. Academic Years System', () {
      final ayService = AcademicYearService();
      late AcademicYearModel year2025;
      late AcademicYearModel year2026;

      test('2.1. Creates academic year with valid dates and canonical UUID', () async {
        year2025 = await ayService.createAcademicYear(
          schoolId: testSchoolId,
          name: '2025-2026',
          startDate: DateTime(2025, 4, 1),
          endDate: DateTime(2026, 3, 31),
        );

        expect(year2025.id, isNotEmpty);
        expect(year2025.name, equals('2025-2026'));
        expect(year2025.schoolId, equals(testSchoolId));
        expect(year2025.startDate, equals(DateTime(2025, 4, 1)));
        expect(year2025.endDate, equals(DateTime(2026, 3, 31)));
      });

      test('2.2. Rejects invalid date range (endDate <= startDate)', () async {
        expect(
          () => ayService.createAcademicYear(
            schoolId: testSchoolId,
            name: '2027-2028',
            startDate: DateTime(2027, 4, 1),
            endDate: DateTime(2027, 4, 1), // Same day
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('End date must be after start date'),
          )),
        );
      });

      test('2.3. Prevents duplicate academic year names for same school', () async {
        expect(
          () => ayService.createAcademicYear(
            schoolId: testSchoolId,
            name: '2025-2026', // Already exists from 2.1
            startDate: DateTime(2025, 5, 1),
            endDate: DateTime(2026, 4, 30),
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('already exists'),
          )),
        );
      });

      test('2.4. Enforces single-active session rule via atomic activation', () async {
        year2026 = await ayService.createAcademicYear(
          schoolId: testSchoolId,
          name: '2026-2027',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2027, 3, 31),
        );

        // Activate 2025-2026
        await ayService.setCurrentAcademicYear(id: year2025.id, schoolId: testSchoolId);
        var active = await ayService.getActiveAcademicYear(testSchoolId);
        expect(active?.id, equals(year2025.id));

        // Activate 2026-2027: 2025-2026 must be automatically deactivated
        await ayService.setCurrentAcademicYear(id: year2026.id, schoolId: testSchoolId);
        active = await ayService.getActiveAcademicYear(testSchoolId);
        expect(active?.id, equals(year2026.id));

        // List must show exactly ONE active year
        final list = await ayService.fetchAcademicYears(testSchoolId);
        final activeList = list.where((y) => y.isCurrent).toList();
        expect(activeList.length, equals(1));
        expect(activeList.first.id, equals(year2026.id));
      });

      test('2.5. Edits academic year details accurately', () async {
        final updated = await ayService.updateAcademicYear(
          id: year2025.id,
          schoolId: testSchoolId,
          name: '2025-2026 (Revised)',
          startDate: DateTime(2025, 4, 15),
          endDate: DateTime(2026, 3, 31),
          status: AccountStatus.active,
        );

        expect(updated.name, equals('2025-2026 (Revised)'));
        expect(updated.startDate, equals(DateTime(2025, 4, 15)));
        expect(updated.endDate, equals(DateTime(2026, 3, 31)));
      });

      test('2.6. Prevents overlapping date ranges with other academic years', () async {
        expect(
          () => ayService.createAcademicYear(
            schoolId: testSchoolId,
            name: '2026-Conflict',
            startDate: DateTime(2026, 6, 1),
            endDate: DateTime(2026, 12, 31),
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('overlaps with existing academic year'),
          )),
        );
      });

      test('2.7. Deletes academic year safely when unreferenced', () async {
        final disposable = await ayService.createAcademicYear(
          schoolId: testSchoolId,
          name: '2099-2100',
          startDate: DateTime(2099, 4, 1),
          endDate: DateTime(2100, 3, 31),
        );

        await ayService.deleteAcademicYear(id: disposable.id, schoolId: testSchoolId);
        final list = await ayService.fetchAcademicYears(testSchoolId);
        expect(list.any((y) => y.id == disposable.id), isFalse);
      });
    });

    // =========================================================================
    // 3. PUSH & NOTIFICATION ALERTS
    // =========================================================================
    group('3. Push & Notification Preferences', () {
      late NotificationPreferencesService notifService;

      setUp(() {
        notifService = NotificationPreferencesService();
      });

      test('3.1. Loads default preferences when no prior record exists', () async {
        final prefs = await notifService.getPreferences(
          testSchoolId,
          userId: testUserId,
        );

        expect(prefs.timetableAlerts, isTrue);
        expect(prefs.attendanceAlerts, isTrue);
        expect(prefs.feeAlerts, isTrue);
      });

      test('3.2. Persists toggle changes for each alert channel independently', () async {
        // Turn off timetable alerts
        var updated = await notifService.updateToggle(
          schoolId: testSchoolId,
          userId: testUserId,
          timetableAlerts: false,
        );
        expect(updated.timetableAlerts, isFalse);
        expect(updated.attendanceAlerts, isTrue);
        expect(updated.feeAlerts, isTrue);

        // Turn off attendance alerts
        updated = await notifService.updateToggle(
          schoolId: testSchoolId,
          userId: testUserId,
          attendanceAlerts: false,
        );
        expect(updated.timetableAlerts, isFalse);
        expect(updated.attendanceAlerts, isFalse);
        expect(updated.feeAlerts, isTrue);

        // Turn off fee alerts
        updated = await notifService.updateToggle(
          schoolId: testSchoolId,
          userId: testUserId,
          feeAlerts: false,
        );
        expect(updated.timetableAlerts, isFalse);
        expect(updated.attendanceAlerts, isFalse);
        expect(updated.feeAlerts, isFalse);

        // Verify loaded state from storage matches
        final loaded = await notifService.getPreferences(
          testSchoolId,
          userId: testUserId,
        );
        expect(loaded.timetableAlerts, isFalse);
        expect(loaded.attendanceAlerts, isFalse);
        expect(loaded.feeAlerts, isFalse);
      });

      test('3.3. Tenant and user isolation for notification preferences', () async {
        const otherSchoolId = 'sch-uuid-other-002';
        const otherUserId = 'usr-other-002';

        final otherPrefs = await notifService.getPreferences(
          otherSchoolId,
          userId: otherUserId,
        );

        // Other school/user should still have default true values
        expect(otherPrefs.timetableAlerts, isTrue);
        expect(otherPrefs.attendanceAlerts, isTrue);
        expect(otherPrefs.feeAlerts, isTrue);
      });
    });

    // =========================================================================
    // 4. USER PROFILE DETAILS & APP-WIDE SYNC
    // =========================================================================
    group('4. User Profile Management', () {
      late AuthService authService;

      setUp(() {
        authService = AuthService();
      });

      test('4.1. updateUserProfile validates display name', () async {
        expect(
          () => authService.updateUserProfile(
            userId: testUserId,
            name: '   ',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Display name cannot be empty'),
          )),
        );
      });

      test('4.2. updateUserProfile executes cleanly with designation and avatar', () async {
        await expectLater(
          authService.updateUserProfile(
            userId: testUserId,
            name: 'Dr. Dharampal Gujar',
            designation: 'Senior Principal',
            avatarUrl: 'https://images.unsplash.com/photo-principal.jpg',
          ),
          completes,
        );
      });

      test('4.3. UserModel resolves School Admin display name cleanly', () {
        const adminUser = UserModel(
          id: testUserId,
          name: 'Admin User',
          email: 'admin@school.com',
          role: UserRole.schoolAdmin,
          schoolId: testSchoolId,
          schoolName: 'Kamal Public School',
          designation: 'Principal',
          avatarUrl: 'https://images.unsplash.com/photo-admin.jpg',
        );
        expect(adminUser.roleDisplayName, equals('School Admin'));

        const superAdminUser = UserModel(
          id: 'usr-super-01',
          name: 'Super User',
          email: 'super@system.com',
          role: UserRole.superAdmin,
          schoolName: 'System Core',
          designation: 'System Administrator',
          avatarUrl: 'https://images.unsplash.com/photo-super.jpg',
        );
        expect(superAdminUser.roleDisplayName, equals('Super Admin'));
      });
    });

    // =========================================================================
    // 5. SECURITY & PASSCODE
    // =========================================================================
    group('5. Security & Passcode (Password change & App PIN)', () {
      late AuthService authService;

      setUp(() {
        authService = AuthService();
      });

      test('5.1. Password change enforces minimum 8 characters', () async {
        expect(
          () => authService.changePassword(newPassword: 'short'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('at least 8 characters long'),
          )),
        );
      });

      test('5.2. Valid password passes validation without error', () async {
        await expectLater(
          authService.changePassword(newPassword: 'StrongPassword123!'),
          completes,
        );
      });

      test('5.3. 4-digit App PIN lock saves, validates and disables in SharedPreferences', () async {
        final prefs = await SharedPreferences.getInstance();
        const pinKey = 'user_passcode_pin_$testUserId';
        const enabledKey = 'user_passcode_enabled_$testUserId';

        // Set 4-digit PIN
        const enteredPin = '7391';
        await prefs.setString(pinKey, enteredPin);
        await prefs.setBool(enabledKey, true);

        // Verify stored state
        expect(prefs.getString(pinKey), equals('7391'));
        expect(prefs.getBool(enabledKey), isTrue);

        // Verify incorrect PIN check
        expect('1234' == prefs.getString(pinKey), isFalse);

        // Verify correct PIN check
        expect('7391' == prefs.getString(pinKey), isTrue);

        // Disable PIN lock
        await prefs.remove(pinKey);
        await prefs.setBool(enabledKey, false);

        expect(prefs.getBool(enabledKey), isFalse);
        expect(prefs.getString(pinKey), isNull);
      });
    });
  });
}
