import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/data/models/school_model.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/models/school_management_app_model.dart';
import 'package:school_app/data/models/school_app_subscription_model.dart';
import 'package:school_app/data/models/school_app_access_state.dart';
import 'package:school_app/data/models/timetable_model.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/services/tenant_access_service.dart';
import 'package:school_app/data/services/timetable_service.dart';
import 'package:school_app/data/services/teacher_service.dart';

void main() {
  group('PART A: Tenant Access & Multi-Tenant Authorization Rules', () {
    const schoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';

    final activeSchool = SchoolModel(
      id: schoolId,
      schoolCode: 'KPS',
      name: 'KPS',
      status: AccountStatus.active,
      createdAt: DateTime(2026, 1, 1),
    );

    final inactiveSchool = SchoolModel(
      id: schoolId,
      schoolCode: 'KPS',
      name: 'KPS',
      status: AccountStatus.inactive,
      createdAt: DateTime(2026, 1, 1),
    );

    test('Multi-tenant web mode: app is null, active school -> access GRANTED', () {
      // In multi-tenant web mode, no single app record is pinned; active school grants access.
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: null,
        subscription: null,
        configuredAppIdentifier: null,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
      expect(result.resolvedSchool?.id, equals(schoolId));
      expect(result.resolvedSchool?.name, equals('KPS'));
    });

    test('Multi-tenant web mode: app is null, inactive school -> access BLOCKED with schoolInactive', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: inactiveSchool,
        app: null,
        subscription: null,
        configuredAppIdentifier: null,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.schoolInactive));
      expect(result.userMessage, contains('inactive'));
    });

    test('School record null -> access BLOCKED with schoolNotFound', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: null,
        app: null,
        subscription: null,
        configuredAppIdentifier: null,
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.schoolNotFound));
      expect(result.userMessage, contains('could not be found'));
    });

    test('Dedicated branded mode: configured app identifier requires matching active app', () {
      final matchingApp = SchoolManagementAppModel(
        id: 'app-kps-1',
        schoolId: schoolId,
        appName: 'KPS App',
        appIdentifier: 'KPS_APP',
        packageName: 'com.school.kps',
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
      );

      final activeSub = SchoolAppSubscriptionModel(
        id: 'sub-kps-1',
        schoolAppId: 'app-kps-1',
        planName: 'Enterprise',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2027, 1, 1),
        status: 'active',
        createdAt: DateTime(2026, 1, 1),
      );

      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: matchingApp,
        subscription: activeSub,
        configuredAppIdentifier: 'KPS_APP',
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isTrue);
      expect(result.status, equals(AppAccessStatus.granted));
    });

    test('Dedicated branded mode: missing app when identifier configured -> appNotFound', () {
      final result = TenantAccessService.evaluateAccessRules(
        school: activeSchool,
        app: null,
        subscription: null,
        configuredAppIdentifier: 'KPS_APP',
        expectedDevSchoolId: null,
      );

      expect(result.isAllowed, isFalse);
      expect(result.status, equals(AppAccessStatus.appNotFound));
    });
  });

  group('PART B: Timetable Collision Engine (All Sections & Teacher Overlaps)', () {
    final timetableService = TimetableService(client: null);
    const schoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const academicYearId = 'ay-2026-2027';
    const classId = 'class-10';
    const sectionA = 'sec-10-a';
    const sectionB = 'sec-10-b';
    const teacher1Id = 't-prof-001';
    const teacher2Id = 't-prof-002';

    final existingSectionAPeriod = TimetableEntryModel(
      id: 'entry-sec-a',
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionA,
      className: 'Class 10',
      sectionName: 'A',
      dayOfWeek: 1, // Monday
      startTime: '08:00',
      endTime: '08:45',
      subjectName: 'Mathematics',
      teacherProfileId: teacher1Id,
      teacherName: 'John Doe',
      status: TimetableStatus.published,
    );

    final cancelledPeriod = TimetableEntryModel(
      id: 'entry-cancelled',
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionA,
      className: 'Class 10',
      sectionName: 'A',
      dayOfWeek: 1, // Monday
      startTime: '08:00',
      endTime: '08:45',
      subjectName: 'Old Math',
      teacherProfileId: teacher1Id,
      teacherName: 'John Doe',
      status: TimetableStatus.cancelled,
    );

    test('Whole-class period (sectionId == null) conflicts with existing Section A period at same time', () {
      final wholeClassCandidate = TimetableEntryModel(
        id: 'candidate-whole-class',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: null, // ALL SECTIONS
        className: 'Class 10',
        sectionName: null,
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'Morning Assembly',
        teacherProfileId: teacher2Id,
        teacherName: 'Principal',
        status: TimetableStatus.draft,
      );

      final conflict = timetableService.detectConflict(
        entry: wholeClassCandidate,
        existingEntries: [existingSectionAPeriod],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, equals(TimetableConflictType.classOverlap));
      expect(conflict.message, contains('already has a period scheduled'));
    });

    test('Section-specific period conflicts with existing whole-class period at same time', () {
      final existingWholeClass = TimetableEntryModel(
        id: 'entry-assembly',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: null, // ALL SECTIONS
        className: 'Class 10',
        sectionName: null,
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'Morning Assembly',
        status: TimetableStatus.draft,
      );

      final sectionCandidate = TimetableEntryModel(
        id: 'candidate-sec-b',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionB,
        className: 'Class 10',
        sectionName: 'B',
        dayOfWeek: 1,
        startTime: '08:15',
        endTime: '09:00', // Overlaps 08:15 - 08:45
        subjectName: 'Physics',
        status: TimetableStatus.draft,
      );

      final conflict = timetableService.detectConflict(
        entry: sectionCandidate,
        existingEntries: [existingWholeClass],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, equals(TimetableConflictType.classOverlap));
      expect(conflict.message, contains('already has a period scheduled'));
    });

    test('Two different sections in same class with different teachers do NOT conflict', () {
      final sectionBCandidate = TimetableEntryModel(
        id: 'candidate-sec-b-diff-teacher',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionB,
        className: 'Class 10',
        sectionName: 'B',
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'Science',
        teacherProfileId: teacher2Id,
        teacherName: 'Jane Smith',
        status: TimetableStatus.draft,
      );

      final conflict = timetableService.detectConflict(
        entry: sectionBCandidate,
        existingEntries: [existingSectionAPeriod],
      );

      expect(conflict, isNull);
    });

    test('Same teacher in two different classes or sections at same time -> teacherDoubleBooking', () {
      final doubleBookedCandidate = TimetableEntryModel(
        id: 'candidate-teacher-overlap',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: 'class-9', // Different class
        sectionId: 'sec-9-a',
        className: 'Class 9',
        sectionName: 'A',
        dayOfWeek: 1,
        startTime: '08:30',
        endTime: '09:15', // Overlaps 08:30 - 08:45 with existingSectionAPeriod
        subjectName: 'Math Remedial',
        teacherProfileId: teacher1Id, // Same teacher John Doe
        teacherName: 'John Doe',
        status: TimetableStatus.draft,
      );

      final conflict = timetableService.detectConflict(
        entry: doubleBookedCandidate,
        existingEntries: [existingSectionAPeriod],
      );

      expect(conflict, isNotNull);
      expect(conflict!.type, equals(TimetableConflictType.teacherOverlap));
      expect(conflict.message, contains('John Doe'));
      expect(conflict.message, contains('already teaching'));
    });

    test('Cancelled periods are ignored and do NOT trigger collision', () {
      final candidateSameSlot = TimetableEntryModel(
        id: 'candidate-replacement',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionA,
        className: 'Class 10',
        sectionName: 'A',
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '08:45',
        subjectName: 'New Math',
        teacherProfileId: teacher1Id,
        teacherName: 'John Doe',
        status: TimetableStatus.draft,
      );

      final conflict = timetableService.detectConflict(
        entry: candidateSameSlot,
        existingEntries: [cancelledPeriod], // Only cancelled period in list
      );

      expect(conflict, isNull);
    });

    test('Non-overlapping consecutive periods do NOT conflict', () {
      final consecutiveCandidate = TimetableEntryModel(
        id: 'candidate-period-2',
        schoolId: schoolId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionA,
        className: 'Class 10',
        sectionName: 'A',
        dayOfWeek: 1,
        startTime: '08:45', // Starts exactly when period 1 ends
        endTime: '09:30',
        subjectName: 'English',
        teacherProfileId: teacher1Id, // Same teacher is fine for consecutive period
        teacherName: 'John Doe',
        status: TimetableStatus.draft,
      );

      final conflict = timetableService.detectConflict(
        entry: consecutiveCandidate,
        existingEntries: [existingSectionAPeriod],
      );

      expect(conflict, isNull);
    });
  });

  group('PART C: Timetable Models & Subject/Section Mapping Integrity', () {
    test('SubjectModel holds canonical id, schoolId, code, and type', () {
      const subject = SubjectModel(
        id: 'sub-uuid-101',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        name: 'Mathematics',
        code: 'MATH101',
        type: 'THEORY',
      );

      expect(subject.id, equals('sub-uuid-101'));
      expect(subject.name, equals('Mathematics'));
      expect(subject.code, equals('MATH101'));
      expect(subject.status, equals(AccountStatus.active));
    });

    test('SectionModel links strictly to classId and schoolId', () {
      final section = SectionModel(
        id: 'sec-uuid-201',
        classId: 'class-uuid-101',
        academicYearId: 'ay-2026-2027',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        name: 'A',
        capacity: 40,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(section.classId, equals('class-uuid-101'));
      expect(section.name, equals('A'));
      expect(section.displayName, equals('Section A'));
    });

    test('TeacherModel parses assigned subjects list correctly', () {
      final teacher = TeacherModel.fromJson({
        'id': 't-uuid-301',
        'school_id': '6254bee9-151d-4332-8a1c-3994af7d2153',
        'full_name': 'Prof. Alan Turing',
        'email': 'alan.turing@school.com',
        'role': 'teacher',
        'subjects': ['Mathematics', 'Computer Science'],
        'status': 'active',
      });

      expect(teacher.name, equals('Prof. Alan Turing'));
      expect(teacher.isTeacher, isTrue);
      expect(teacher.subjects, containsAll(['Mathematics', 'Computer Science']));
      expect(teacher.status, equals(AccountStatus.active));
    });
  });

  group('PART D: Access Failure Categorization & Distinction', () {
    test('D1. Distinguishes school record genuinely missing', () {
      final res = AppAccessResult.blocked(
        status: AppAccessStatus.schoolNotFound,
        userMessage: 'School institution record could not be found.',
        detailedReason: 'public.schools has no row for id: 6254bee9-151d-4332-8a1c-3994af7d2153',
      );

      expect(res.failureCategory, equals(AppAccessFailureCategory.schoolNotFound));
      expect(res.categoryBadgeLabel, equals('School Record Missing'));
      expect(res.isAllowed, isFalse);
      expect(res.detailedReason, contains('6254bee9-151d-4332-8a1c-3994af7d2153'));
    });

    test('D2. Distinguishes school membership and profile missing', () {
      final resProfile = AppAccessResult.blocked(
        status: AppAccessStatus.noProfile,
        userMessage: 'User profile not found.',
      );
      final resSchoolAssigned = AppAccessResult.blocked(
        status: AppAccessStatus.noSchoolAssigned,
        userMessage: 'Your account is not assigned to any school institution.',
      );

      expect(resProfile.failureCategory, equals(AppAccessFailureCategory.profileOrMembershipMissing));
      expect(resProfile.categoryBadgeLabel, equals('Profile / Membership Missing'));

      expect(resSchoolAssigned.failureCategory, equals(AppAccessFailureCategory.profileOrMembershipMissing));
      expect(resSchoolAssigned.categoryBadgeLabel, equals('Profile / Membership Missing'));
    });

    test('D3. Distinguishes RLS and authorization denial', () {
      final resDeactivated = AppAccessResult.schoolDeactivated();
      final resMismatch = AppAccessResult.blocked(
        status: AppAccessStatus.appMismatch,
        userMessage: 'This app is not configured for your school.',
      );
      final resInactiveUser = AppAccessResult.blocked(
        status: AppAccessStatus.profileInactive,
        userMessage: 'Your account is currently inactive.',
      );

      expect(resDeactivated.failureCategory, equals(AppAccessFailureCategory.authorizationOrRlsDenied));
      expect(resMismatch.failureCategory, equals(AppAccessFailureCategory.authorizationOrRlsDenied));
      expect(resInactiveUser.failureCategory, equals(AppAccessFailureCategory.authorizationOrRlsDenied));
      expect(resDeactivated.categoryBadgeLabel, equals('Authorization / Access Denied'));
    });

    test('D4. Distinguishes subscription and entitlement problem', () {
      final resExpired = AppAccessResult.subscriptionExpired();
      final resSuspended = AppAccessResult.blocked(
        status: AppAccessStatus.subscriptionSuspended,
        userMessage: 'Your school subscription is suspended.',
      );
      final resNoSub = AppAccessResult.blocked(
        status: AppAccessStatus.noSubscription,
        userMessage: 'No active subscription found.',
      );

      expect(resExpired.failureCategory, equals(AppAccessFailureCategory.subscriptionOrEntitlementProblem));
      expect(resSuspended.failureCategory, equals(AppAccessFailureCategory.subscriptionOrEntitlementProblem));
      expect(resNoSub.failureCategory, equals(AppAccessFailureCategory.subscriptionOrEntitlementProblem));
      expect(resExpired.categoryBadgeLabel, equals('Subscription / Entitlement Issue'));
    });

    test('D5. Distinguishes temporary network/query failure', () {
      final resNetwork = AppAccessResult.blocked(
        status: AppAccessStatus.networkError,
        userMessage: 'Unable to connect to database service.',
      );

      expect(resNetwork.failureCategory, equals(AppAccessFailureCategory.networkOrConnectionFailure));
      expect(resNetwork.categoryBadgeLabel, equals('Connection Failure'));
    });

    test('D6. Distinguishes expired authentication session', () {
      final resAuth = AppAccessResult.unauthenticated();

      expect(resAuth.failureCategory, equals(AppAccessFailureCategory.sessionExpired));
      expect(resAuth.categoryBadgeLabel, equals('Session Expired'));
    });
  });

  group('PART E: Teacher Persistence, Recovery, and Refresh Survival', () {
    const canonicalSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const otherSchoolId = '11111111-2222-3333-4444-555555555555';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('E1. TeacherService initializes baseline 24 teachers for canonical school on first load', () async {
      final service = TeacherService();
      final teachers = await service.getTeachers(schoolId: canonicalSchoolId);

      expect(teachers.length, equals(24));
      expect(teachers.every((t) => t.schoolId == canonicalSchoolId), isTrue);

      // Verify baseline coverage
      final classNames = teachers.map((t) => t.assignedClass).toSet();
      expect(classNames.contains('Class 1'), isTrue);
      expect(classNames.contains('Class 12'), isTrue);
    });

    test('E2. Adding new teacher persists in service and is retrievable by search query', () async {
      final service = TeacherService();
      // Initialize
      await service.getTeachers(schoolId: canonicalSchoolId);

      final newTeacher = TeacherModel(
        id: '0c4f9640-c110-49d6-be93-4ea69cba78aa',
        schoolId: canonicalSchoolId,
        employeeId: 'EMP-9001',
        name: 'Ram Sharma',
        email: 'ram@gmail.com',
        subjects: ['Mathematics'],
        assignedClass: 'Class 10',
        assignedSection: 'A',
        totalStudents: 35,
        avatarUrl: '',
        phone: '+91 9876543210',
        designation: 'Mathematics Faculty',
        status: AccountStatus.active,
      );

      await service.addTeacher(newTeacher);

      // Search by name
      final searchByName = await service.getTeachers(schoolId: canonicalSchoolId, query: 'Ram');
      expect(searchByName.length, equals(1));
      expect(searchByName.first.name, equals('Ram Sharma'));
      expect(searchByName.first.employeeId, equals('EMP-9001'));

      // Search by empId
      final searchByEmpId = await service.getTeachers(schoolId: canonicalSchoolId, query: '9001');
      expect(searchByEmpId.length, equals(1));
      expect(searchByEmpId.first.name, equals('Ram Sharma'));
    });

    test('E3. Teacher data survives simulated app restart / fresh service instance via cache', () async {
      // Instance 1: Add Ram
      final service1 = TeacherService();
      await service1.getTeachers(schoolId: canonicalSchoolId);

      final newTeacher = TeacherModel(
        id: '0c4f9640-c110-49d6-be93-4ea69cba78aa',
        schoolId: canonicalSchoolId,
        employeeId: 'EMP-9001',
        name: 'Ram Sharma',
        email: 'ram@gmail.com',
        subjects: ['Mathematics'],
        assignedClass: 'Class 10',
        assignedSection: 'A',
        totalStudents: 35,
        avatarUrl: '',
        phone: '+91 9876543210',
        designation: 'Mathematics Faculty',
        status: AccountStatus.active,
      );
      await service1.addTeacher(newTeacher);

      // Instance 2: Brand new instance simulating app reload / page refresh
      final service2 = TeacherService();
      final reloadedTeachers = await service2.getTeachers(schoolId: canonicalSchoolId);

      // Expect baseline 24 + Ram = 25 teachers
      expect(reloadedTeachers.length, equals(25));
      final ramRecord = reloadedTeachers.firstWhere((t) => t.employeeId == 'EMP-9001');
      expect(ramRecord.name, equals('Ram Sharma'));
      expect(ramRecord.email, equals('ram@gmail.com'));
      expect(ramRecord.id, equals('0c4f9640-c110-49d6-be93-4ea69cba78aa'));
    });

    test('E4. Strict multi-tenant isolation: querying School B never returns School A teachers', () async {
      final service = TeacherService();
      await service.getTeachers(schoolId: canonicalSchoolId);

      final otherSchoolTeachers = await service.getTeachers(schoolId: otherSchoolId);
      expect(otherSchoolTeachers.isEmpty, isTrue);
    });

    test('E5. TeacherModel serialization round-trip maintains all fields accurately', () {
      final original = TeacherModel(
        id: '0c4f9640-c110-49d6-be93-4ea69cba78aa',
        schoolId: canonicalSchoolId,
        employeeId: 'EMP-9001',
        name: 'Ram Sharma',
        email: 'ram@gmail.com',
        subjects: ['Mathematics', 'Statistics'],
        assignedClass: 'Class 10',
        assignedSection: 'A',
        totalStudents: 40,
        avatarUrl: 'https://example.com/avatar.jpg',
        phone: '+91 9876543210',
        designation: 'Senior Faculty',
        status: AccountStatus.active,
        authUserId: '0c4f9640-c110-49d6-be93-4ea69cba78aa',
      );

      final json = original.toJson();
      final recovered = TeacherModel.fromJson(json);

      expect(recovered.id, equals(original.id));
      expect(recovered.schoolId, equals(original.schoolId));
      expect(recovered.employeeId, equals(original.employeeId));
      expect(recovered.name, equals(original.name));
      expect(recovered.email, equals(original.email));
      expect(recovered.subjects, equals(original.subjects));
      expect(recovered.assignedClass, equals(original.assignedClass));
      expect(recovered.assignedSection, equals(original.assignedSection));
      expect(recovered.authUserId, equals(original.authUserId));
      expect(recovered.status, equals(original.status));
    });

    test('E6. Duplicate employee ID throws descriptive exception and prevents corruption', () async {
      final service = TeacherService();
      await service.getTeachers(schoolId: canonicalSchoolId);

      // Attempt to add a teacher with EMP-0101 (already assigned to Class 1A Teacher)
      final duplicateTeacher = TeacherModel(
        id: '22222222-3333-4444-5555-666666666666',
        schoolId: canonicalSchoolId,
        employeeId: 'EMP-0101',
        name: 'Duplicate Teacher',
        email: 'duplicate@school.com',
        subjects: ['Art'],
        assignedClass: 'Class 1',
        assignedSection: 'A',
        totalStudents: 20,
        avatarUrl: '',
        phone: '',
        designation: 'Faculty',
        status: AccountStatus.active,
      );

      expect(
        () async => await service.addTeacher(duplicateTeacher),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Employee ID "EMP-0101" is already registered'),
        )),
      );
    });
  });
}
