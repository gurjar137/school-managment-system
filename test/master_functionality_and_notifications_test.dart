import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/core/utils/uuid_helper.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/class_section_models.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/class_section_service.dart';
import 'package:school_app/data/services/teacher_service.dart';
import 'package:school_app/data/services/student_service.dart';
import 'package:school_app/data/services/library_service.dart';
import 'package:school_app/data/services/transport_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UuidHelper Tests', () {
    test('generate produces valid RFC 4122 v4 UUIDs', () {
      final uuid1 = UuidHelper.generate();
      final uuid2 = UuidHelper.generate();
      expect(uuid1, isNot(equals(uuid2)));
      expect(UuidHelper.isValidUuid(uuid1), isTrue);
      expect(UuidHelper.isValidUuid(uuid2), isTrue);
      expect(uuid1.length, equals(36));
      expect(uuid1[14], equals('4')); // version 4
    });

    test('isValidUuid returns false for invalid non-UUID strings', () {
      expect(UuidHelper.isValidUuid(null), isFalse);
      expect(UuidHelper.isValidUuid(''), isFalse);
      expect(UuidHelper.isValidUuid('notice_12345'), isFalse);
      expect(UuidHelper.isValidUuid('notif_12345'), isFalse);
      expect(UuidHelper.isValidUuid('cls_1'), isFalse);
    });
  });

  group('Subject Catalog Service & Validation Tests', () {
    late TeacherService teacherService;
    const testSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';

    setUp(() {
      teacherService = TeacherService();
    });

    test('Subject creation rejects empty or whitespace names', () async {
      expect(
        () => teacherService.createSubject(
          schoolId: testSchoolId,
          name: '   ',
          code: 'MATH101',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Subject name cannot be empty'),
        )),
      );
    });

    test('Subject creation validates tenant school ID', () async {
      expect(
        () => teacherService.createSubject(
          schoolId: '',
          name: 'Mathematics',
          code: 'MATH101',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Campus Notices & Notification Delivery Workflow Tests', () {
    late SchoolRepository repository;
    const schoolA = '11111111-1111-4111-8111-111111111111';
    const schoolB = '22222222-2222-4222-8222-222222222222';

    setUp(() {
      repository = SchoolRepository(
        studentService: StudentService(),
        teacherService: TeacherService(),
        libraryService: LibraryService(),
        transportService: TransportService(),
      );
    });

    test('Initial notices list is empty with zero fake seeds', () async {
      final notices = await repository.getNotices(
        schoolId: schoolA,
        userRole: UserRole.schoolAdmin,
      );
      expect(notices, isEmpty);
    });

    test('Initial notifications list is empty with zero fake seeds', () async {
      final notifs = await repository.getNotifications(
        schoolId: schoolA,
        role: UserRole.teacher,
      );
      expect(notifs, isEmpty);
    });

    test('Publishing a notice targeting Teachers generates notification for Teachers Only', () async {
      final notice = NoticeModel(
        id: UuidHelper.generate(),
        schoolId: schoolA,
        title: 'Faculty Meeting on Curriculum Revision',
        content: 'All faculty members must attend tomorrow at 3 PM in the conference hall.',
        category: 'Academic',
        date: DateTime.now(),
        author: 'Principal Office',
        targetAudience: 'Teachers Only',
        status: 'Published',
      );

      await repository.addNotice(notice, schoolId: schoolA);

      // Verify notice is retrieved for schoolA
      final schoolANotices = await repository.getNotices(
        schoolId: schoolA,
        userRole: UserRole.schoolAdmin,
      );
      expect(schoolANotices.length, equals(1));
      expect(schoolANotices.first.title, equals(notice.title));

      // Verify notification was generated for teachers
      final teacherNotifs = await repository.getNotifications(
        schoolId: schoolA,
        role: UserRole.teacher,
      );
      expect(teacherNotifs.length, equals(1));
      expect(teacherNotifs.first.title, contains(notice.title));
      expect(teacherNotifs.first.relatedRecordId, equals(notice.id));
      expect(teacherNotifs.first.isUnread, isTrue);

      // Verify unread notification count
      final unreadCount = await repository.getUnreadNotificationCount(
        schoolId: schoolA,
        role: UserRole.teacher,
      );
      expect(unreadCount, equals(1));

      // Mark notification as read
      await repository.markNotificationRead(teacherNotifs.first.id, schoolId: schoolA);
      final updatedUnreadCount = await repository.getUnreadNotificationCount(
        schoolId: schoolA,
        role: UserRole.teacher,
      );
      expect(updatedUnreadCount, equals(0));
    });

    test('Strict tenant isolation: School B cannot see School A notices or notifications', () async {
      final noticeA = NoticeModel(
        id: UuidHelper.generate(),
        schoolId: schoolA,
        title: 'School A Confidential Notice',
        content: 'Internal announcement for School A only.',
        category: 'General',
        date: DateTime.now(),
        author: 'School A Admin',
        targetAudience: 'Everyone',
        status: 'Published',
      );

      await repository.addNotice(noticeA, schoolId: schoolA);

      // School B query must return empty
      final schoolBNotices = await repository.getNotices(
        schoolId: schoolB,
        userRole: UserRole.schoolAdmin,
      );
      expect(schoolBNotices, isEmpty);

      final schoolBNotifs = await repository.getNotifications(
        schoolId: schoolB,
        role: UserRole.teacher,
      );
      expect(schoolBNotifs, isEmpty);
    });

    test('Deleting a notice cascades removal to linked notifications', () async {
      final notice = NoticeModel(
        id: UuidHelper.generate(),
        schoolId: schoolA,
        title: 'Temporary Notice',
        content: 'This will be deleted shortly.',
        category: 'General',
        date: DateTime.now(),
        author: 'Admin',
        targetAudience: 'Everyone',
        status: 'Published',
      );

      await repository.addNotice(notice, schoolId: schoolA);

      var teacherNotifs = await repository.getNotifications(schoolId: schoolA, role: UserRole.teacher);
      expect(teacherNotifs.any((n) => n.relatedRecordId == notice.id), isTrue);

      // Delete notice
      await repository.deleteNotice(notice.id, schoolId: schoolA);

      final remainingNotices = await repository.getNotices(schoolId: schoolA, userRole: UserRole.schoolAdmin);
      expect(remainingNotices.any((n) => n.id == notice.id), isFalse);

      teacherNotifs = await repository.getNotifications(schoolId: schoolA, role: UserRole.teacher);
      expect(teacherNotifs.any((n) => n.relatedRecordId == notice.id), isFalse);
    });

    test('Draft notices are only visible to administrators', () async {
      final draftNotice = NoticeModel(
        id: UuidHelper.generate(),
        schoolId: schoolA,
        title: 'Draft Exam Guidelines',
        content: 'Unpublished draft guidelines.',
        category: 'Exam',
        date: DateTime.now(),
        author: 'Admin',
        targetAudience: 'All Staff',
        status: 'Draft',
      );

      await repository.addNotice(draftNotice, schoolId: schoolA);

      // Teachers must NOT see drafts
      final teacherNotices = await repository.getNotices(
        schoolId: schoolA,
        userRole: UserRole.teacher,
        includeDrafts: false,
      );
      expect(teacherNotices.any((n) => n.id == draftNotice.id), isFalse);

      // Admins CAN see drafts
      final adminNotices = await repository.getNotices(
        schoolId: schoolA,
        userRole: UserRole.schoolAdmin,
        includeDrafts: true,
      );
      expect(adminNotices.any((n) => n.id == draftNotice.id), isTrue);
    });
  });

  group('Classes & Sections Management Tests', () {
    late ClassSectionService service;
    const testSchoolId = '6254bee9-151d-4332-8a1c-3994af7d2153';
    const testAcademicYearId = '99999999-9999-4999-8999-999999999999';

    setUp(() {
      service = ClassSectionService();
    });

    test('Class creation rejects empty name or invalid school', () async {
      expect(
        () => service.createClass(
          schoolId: testSchoolId,
          academicYearId: testAcademicYearId,
          name: '',
        ),
        throwsA(isA<Exception>()),
      );

      expect(
        () => service.createClass(
          schoolId: '',
          academicYearId: testAcademicYearId,
          name: 'Class 10',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Section creation rejects empty name or invalid school', () async {
      expect(
        () => service.createSection(
          schoolId: testSchoolId,
          academicYearId: testAcademicYearId,
          classId: 'class-1',
          name: '   ',
        ),
        throwsA(isA<Exception>()),
      );

      expect(
        () => service.createSection(
          schoolId: '',
          academicYearId: testAcademicYearId,
          classId: 'class-1',
          name: 'Section A',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('resolveClass matches by standard code, order, and normalized name', () async {
      // In offline mode, default classes 1-12 are generated
      final resolvedByCode = await service.resolveClass(
        schoolId: testSchoolId,
        classIdentifier: 'cls_5',
      );
      expect(resolvedByCode, isNotNull);
      expect(resolvedByCode?.displayOrder, equals(5));

      final resolvedByName = await service.resolveClass(
        schoolId: testSchoolId,
        classIdentifier: 'Class 10',
      );
      expect(resolvedByName, isNotNull);
      expect(resolvedByName?.displayOrder, equals(10));
    });

    test('resolveSection matches by letter and display code', () async {
      final resolved = await service.resolveSection(
        schoolId: testSchoolId,
        classId: 'mock_cls_1',
        sectionIdentifier: 'A',
      );
      expect(resolved, isNotNull);
      expect(resolved?.name, contains('A'));
    });
  });
}
