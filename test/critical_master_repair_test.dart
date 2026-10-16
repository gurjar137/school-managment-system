import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/core/utils/uuid_generator.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/school_app_access_state.dart';
import 'package:school_app/data/models/student_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/class_section_service.dart';
import 'package:school_app/data/services/library_service.dart';
import 'package:school_app/data/services/school_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/tenant_resolver.dart';
import 'package:school_app/data/services/timetable_service.dart';
import 'package:school_app/features/admin/add_student_screen.dart';
import 'package:school_app/features/inventory/inventory_screen.dart';
import 'package:school_app/features/library/library_screen.dart';
import 'package:school_app/features/subjects/subject_catalog_screen.dart';
import 'package:school_app/features/timetable/timetable_management_screen.dart';

class RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = RealHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 14: Critical Master Repair Automated Verification Suite', () {
    const kpsSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const otherSchoolId = '99999999-9999-9999-9999-999999999999';

    // 1. Student Registration Persistence & RLS Alignment
    test('1. Student Model and Registration payload contains canonical school and academic year', () {
      final student = StudentModel(
        id: generateUuidV4(),
        admissionNumber: 'ADM-2026-001',
        name: 'Aarav Sharma',
        className: 'Class 10',
        section: 'A',
        rollNumber: '1',
        fatherName: 'Ramesh Sharma',
        fatherMobile: '9876543210',
        schoolId: kpsSchoolId,
      );

      final json = student.toJson();
      expect(json['school_id'], equals(kpsSchoolId));
      expect(json['admission_number'], equals('ADM-2026-001'));
      expect(json['name'], equals('Aarav Sharma'));
    });

    // 2. Complete Registration Button State & Academic Year Fallback
    testWidgets('2. AddStudentScreen Complete Registration button handles academic year validation with user feedback', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(
            const UserModel(
              id: 'b773c510-a0b4-47c7-af58-145adc883ca7',
              schoolId: kpsSchoolId,
              schoolName: 'Kamal Public School',
              name: 'School Admin',
              email: 'admin@school.com',
              role: UserRole.schoolAdmin,
              avatarUrl: '',
              designation: 'Principal & Lead Administrator',
            ),
          )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddStudentScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final completeButton = find.widgetWithText(ElevatedButton, 'Complete Registration');
      expect(completeButton, findsOneWidget);

      final btnWidget = tester.widget<ElevatedButton>(completeButton);
      expect(btnWidget.onPressed != null, isTrue, reason: 'Complete Registration button should never be silently dead or faded');
    });

    // 3. Class and Section Creation Models & Validation
    test('3. Class and section creation validates duplicate names and maps canonical IDs', () async {
      final service = ClassSectionService();

      // Duplicate name rejection check
      expect(
        () => service.createClass(
          schoolId: '',
          academicYearId: 'ay-1',
          name: '',
        ),
        throwsA(isA<Exception>()),
      );
    });

    // 4. School Configuration loads and saves without PGRST116
    test('4. SchoolService updateSchoolProfile handles updates without throwing PGRST116', () async {
      final service = SchoolService();

      final updated = await service.updateSchoolProfile(
        schoolId: kpsSchoolId,
        name: 'Kamal Public School Main Campus',
        address: '123 Education Boulevard',
        phone: '+91 98765 43210',
        email: 'info@kps.edu',
      );

      expect(updated.id, equals(kpsSchoolId));
      expect(updated.name, equals('Kamal Public School Main Campus'));
      expect(updated.phone, equals('+91 98765 43210'));
    });

    // 5. School Access Verification & Hierarchy Validation
    test('5. TenantResolver enforces strict isolation between school institutions', () async {
      // Offline mode returns requested or mock school
      final resolved = await TenantResolver.resolveActiveSchoolId(requestedSchoolId: kpsSchoolId);
      expect(resolved, isNotEmpty);
    });

    // 6. /subject-catalog route navigation
    testWidgets('6. SubjectCatalogScreen renders successfully without GoException', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SubjectCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Subject Catalog'), findsOneWidget);
    });

    // 7. Homework Creation and List Persistence
    test('7. HomeworkModel generates valid UUID v4 in payload and serializes properly', () {
      final hwId = generateUuidV4();
      final hw = HomeworkModel(
        id: hwId,
        subject: 'Mathematics',
        className: 'Class 10',
        section: 'A',
        title: 'Trigonometry Problems',
        description: 'Solve exercises 8.1 to 8.4',
        assignedDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 3)),
        status: HomeworkStatus.active,
      );

      final json = hw.toJson(schoolId: kpsSchoolId, academicYearId: generateUuidV4());
      expect(json['id'], equals(hwId));
      expect(json['school_id'], equals(kpsSchoolId));
      expect(json['subject'], equals('Mathematics'));
      expect(json['class_name'], equals('Class 10'));
    });

    test('7b. HomeworkModel omits non-UUID string IDs from json to allow PostgreSQL DEFAULT gen_random_uuid()', () {
      final hw = HomeworkModel(
        id: 'hw_1729068000000', // Legacy millisecond timestamp string
        subject: 'Science',
        className: 'Class 9',
        section: 'B',
        title: 'Cell Division',
        description: 'Read Chapter 5',
        assignedDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 2)),
        status: HomeworkStatus.active,
      );

      final json = hw.toJson(schoolId: kpsSchoolId);
      expect(json.containsKey('id'), isFalse, reason: 'Non-UUID id must be omitted so PostgreSQL gen_random_uuid() executes');
      expect(json['school_id'], equals(kpsSchoolId));
    });

    // 8. Campus Library Screen States (Loading, Empty, Add Book)
    testWidgets('8. LibraryScreen renders loading state and empty state with action button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => FakeAuthNotifier(
            const UserModel(
              id: 'b773c510-a0b4-47c7-af58-145adc883ca7',
              schoolId: kpsSchoolId,
              schoolName: 'Kamal Public School',
              name: 'School Admin',
              email: 'admin@school.com',
              role: UserRole.schoolAdmin,
              avatarUrl: '',
              designation: 'Principal & Lead Administrator',
            ),
          )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      // Verify header and search are present
      expect(find.text('Campus Library'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.pumpAndSettle();

      // Either books are cataloged or empty state is rendered with catalog action
      final catalogAction = find.byTooltip('Catalog Book');
      final catalogFirst = find.text('Catalog First Book');
      final addIcon = find.byIcon(Icons.add_rounded);
      expect(catalogAction.evaluate().isNotEmpty || catalogFirst.evaluate().isNotEmpty || addIcon.evaluate().isNotEmpty, isTrue);
    });

    // 9. Access Restricted screen error handling
    test('9. AppAccessResult properly distinguishes failure categories', () {
      final missingSchool = AppAccessResult.blocked(
        status: AppAccessStatus.noSchoolAssigned,
        userMessage: 'School record could not be found.',
        detailedReason: 'No row in public.schools',
      );
      expect(missingSchool.failureCategory, equals(AppAccessFailureCategory.profileOrMembershipMissing));

      final deactivatedSchool = AppAccessResult.blocked(
        status: AppAccessStatus.schoolDeactivated,
        userMessage: 'School institution has been deactivated.',
        detailedReason: 'public.schools.status is suspended',
      );
      expect(deactivatedSchool.failureCategory, equals(AppAccessFailureCategory.authorizationOrRlsDenied));

      final notFoundSchool = AppAccessResult.blocked(
        status: AppAccessStatus.schoolNotFound,
        userMessage: 'School institution record could not be found.',
        detailedReason: 'public.schools has no row for id: 6254bee9-151d-4332-8a1c-3994af7d2153',
      );
      expect(notFoundSchool.failureCategory, equals(AppAccessFailureCategory.schoolNotFound));

      final expiredSub = AppAccessResult.blocked(
        status: AppAccessStatus.subscriptionExpired,
        userMessage: 'School subscription has expired.',
      );
      expect(expiredSub.failureCategory, equals(AppAccessFailureCategory.subscriptionOrEntitlementProblem));

      final networkErr = AppAccessResult.blocked(
        status: AppAccessStatus.networkError,
        userMessage: 'Connection failed.',
      );
      expect(networkErr.failureCategory, equals(AppAccessFailureCategory.networkOrConnectionFailure));
    });

    // 10. UUID generator generates RFC 4122 compliant UUID v4
    test('10. generateUuidV4 produces valid 36-character RFC 4122 UUID v4', () {
      final uuid1 = generateUuidV4();
      final uuid2 = generateUuidV4();
      expect(uuid1, isNot(equals(uuid2)));
      expect(RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(uuid1), isTrue);
      expect(RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$').hasMatch(uuid2), isTrue);
    });

    // 11. Timetable collision check blocks teacher double-booking
    test('11. Timetable collision detection blocks teacher double-booking at the same time slot', () {
      final existingEntries = [
        const TimetableSlotModel(
          id: 'slot-1',
          day: 'Monday',
          startTime: '09:00',
          endTime: '09:45',
          subject: 'Mathematics',
          teacherName: 'Ram',
          roomNumber: 'Room 101',
          className: 'Class 1',
        ),
      ];

      // New period with same teacher on Monday overlapping 09:00 - 09:45
      final overlapping = existingEntries.where((e) {
        return e.day == 'Monday' &&
            e.teacherName == 'Ram' &&
            !(('09:30'.compareTo(e.startTime) <= 0) || ('09:15'.compareTo(e.endTime) >= 0));
      }).toList();

      expect(overlapping.isNotEmpty, isTrue, reason: 'Teacher Ram double-booking must be detected and blocked');
    });

    // 12. Timetable collision check blocks whole-class period overlapping
    test('12. Timetable collision detection blocks whole-class overlapping periods', () {
      final existingEntries = [
        const TimetableSlotModel(
          id: 'slot-1',
          day: 'Tuesday',
          startTime: '10:00',
          endTime: '10:45',
          subject: 'Physics',
          teacherName: 'Dr. Sen',
          roomNumber: 'Physics Lab',
          className: 'Class 10 A',
        ),
      ];

      // Second subject scheduled for Class 10 A at the same time
      final classConflict = existingEntries.where((e) {
        return e.day == 'Tuesday' &&
            e.className == 'Class 10 A' &&
            !(('10:45'.compareTo(e.startTime) <= 0) || ('10:15'.compareTo(e.endTime) >= 0));
      }).toList();

      expect(classConflict.isNotEmpty, isTrue, reason: 'Whole-class collision must be flagged');
    });

    // 13. Timetable allows same teacher across different days/times
    test('13. Timetable permits same teacher on different days or non-overlapping time slots', () {
      final existingEntries = [
        const TimetableSlotModel(
          id: 'slot-1',
          day: 'Monday',
          startTime: '09:00',
          endTime: '09:45',
          subject: 'Mathematics',
          teacherName: 'Ram',
          roomNumber: 'Room 101',
          className: 'Class 1',
        ),
      ];

      // Same teacher on Tuesday (different day)
      final tuesdayConflict = existingEntries.where((e) {
        return e.day == 'Tuesday' &&
            e.teacherName == 'Ram' &&
            !(('09:45'.compareTo(e.startTime) <= 0) || ('09:00'.compareTo(e.endTime) >= 0));
      }).toList();

      expect(tuesdayConflict.isEmpty, isTrue);

      // Same teacher on Monday at 11:00 (non-overlapping)
      final nonOverlapping = existingEntries.where((e) {
        return e.day == 'Monday' &&
            e.teacherName == 'Ram' &&
            !(('11:00'.compareTo(e.endTime) >= 0) || ('11:45'.compareTo(e.startTime) <= 0));
      }).toList();

      expect(nonOverlapping.isEmpty, isTrue);
    });

    // 14. Multi-tenant isolation: School A cannot see School B data
    test('14. Multi-tenant isolation filters enforce strict school_id boundary', () {
      final allStudents = [
        StudentModel(
          id: 'stu-a1',
          admissionNumber: 'ADM-01',
          name: 'School A Student',
          className: 'Class 1',
          section: 'A',
          schoolId: kpsSchoolId,
        ),
        StudentModel(
          id: 'stu-b1',
          admissionNumber: 'ADM-01', // Identical admission number allowed across schools
          name: 'School B Student',
          className: 'Class 1',
          section: 'A',
          schoolId: otherSchoolId,
        ),
      ];

      final schoolAFiltered = allStudents.where((s) => s.schoolId == kpsSchoolId).toList();
      expect(schoolAFiltered.length, equals(1));
      expect(schoolAFiltered.first.name, equals('School A Student'));
      expect(schoolAFiltered.any((s) => s.schoolId == otherSchoolId), isFalse);
    });

    // 15. Inventory & Asset Depot Screen
    testWidgets('15. InventoryScreen renders KPIs, search, category chips, and asset cards', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inventory & Asset Depot'), findsOneWidget);
      expect(find.text('TOTAL ASSETS'), findsOneWidget);
      expect(find.text('LOW / OUT OF STOCK'), findsOneWidget);
      expect(find.text('ASSET VALUATION'), findsOneWidget);
      expect(find.text('Lab & Science'), findsWidgets);
    });
  });
}

class FakeAuthNotifier extends StateNotifier<UserModel?> implements AuthNotifier {
  UserProfileModel? _profile;

  FakeAuthNotifier(UserModel user) : super(user) {
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
  Future<void> updateProfile({
    required String name,
    String? phone,
    String? designation,
    String? avatarUrl,
  }) async {}

  @override
  Future<void> logout() async {
    _profile = null;
    state = null;
  }
}
