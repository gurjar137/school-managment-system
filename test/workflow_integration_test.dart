import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/school_management_models.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/school_management_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Connected School Workflows - Leave Requests Lifecycle', () {
    test('Teacher applies for leave, appears in admin queue, admin approves with remarks', () async {
      final service = SchoolManagementService();
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_001';

      // 1. Teacher applies for leave
      final leaveReq = TeacherLeaveModel(
        id: 'leave_t1',
        schoolId: testSchoolId,
        teacherId: 'teacher_101',
        teacherName: 'Mrs. Sharma',
        leaveType: 'Medical',
        fromDate: DateTime.now().add(const Duration(days: 1)),
        toDate: DateTime.now().add(const Duration(days: 3)),
        reason: 'Undergoing dental surgery and recovery',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await service.applyTeacherLeave(leaveReq, repo: repo);

      // 2. Verified in pending requests queue
      final pendingLeaves = await service.getPendingLeaveRequests(schoolId: testSchoolId);
      expect(pendingLeaves.any((l) => l.id == 'leave_t1'), isTrue);
      expect(pendingLeaves.firstWhere((l) => l.id == 'leave_t1').status, 'pending');

      // 3. Admin receives notification of new leave application
      final notifications = await repo.getNotifications(schoolId: testSchoolId);
      expect(notifications.any((n) => n.relatedRecordId == 'leave_t1' && n.relatedRecordType == 'leave'), isTrue);

      // 4. Admin approves leave with remark
      await service.approveLeave(
        'leave_t1',
        'Approved by Principal. Please coordinate with substitute teacher.',
        adminName: 'Principal Dr. Roy',
        repo: repo,
      );

      // 5. Status updated to approved
      final allLeaves = await service.getAllLeaveRequests(schoolId: testSchoolId);
      final approvedLeave = allLeaves.firstWhere((l) => l.id == 'leave_t1');
      expect(approvedLeave.status, 'approved');
      expect(approvedLeave.reviewedBy, 'Principal Dr. Roy');
      expect(approvedLeave.adminRemarks, contains('Approved by Principal'));
      expect(approvedLeave.reviewedAt, isNotNull);

      // 6. Teacher receives notification of approval
      final teacherNotifs = await repo.getNotifications(schoolId: testSchoolId, userId: 'teacher_101');
      expect(teacherNotifs.any((n) => n.title.contains('Approved')), isTrue);
    });

    test('Admin rejects leave with reason, teacher is notified', () async {
      final service = SchoolManagementService();
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_002';

      final leaveReq = TeacherLeaveModel(
        id: 'leave_t2',
        schoolId: testSchoolId,
        teacherId: 'teacher_102',
        teacherName: 'Mr. Verma',
        leaveType: 'Casual',
        fromDate: DateTime.now().add(const Duration(days: 5)),
        toDate: DateTime.now().add(const Duration(days: 6)),
        reason: 'Personal trip out of station',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await service.applyTeacherLeave(leaveReq, repo: repo);

      await service.rejectLeave(
        'leave_t2',
        'Cannot approve due to scheduled annual sports day evaluations',
        adminName: 'Admin Desk',
        repo: repo,
      );

      final leaves = await service.getAllLeaveRequests(schoolId: testSchoolId);
      final rejected = leaves.firstWhere((l) => l.id == 'leave_t2');
      expect(rejected.status, 'rejected');
      expect(rejected.adminRemarks, contains('annual sports day'));

      final teacherNotifs = await repo.getNotifications(schoolId: testSchoolId, userId: 'teacher_102');
      expect(teacherNotifs.any((n) => n.title.contains('Rejected')), isTrue);
    });

    test('Teacher cancels pending leave request', () async {
      final service = SchoolManagementService();
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_003';

      final leaveReq = TeacherLeaveModel(
        id: 'leave_t3',
        schoolId: testSchoolId,
        teacherId: 'teacher_103',
        teacherName: 'Ms. Kapoor',
        leaveType: 'Earned',
        fromDate: DateTime.now().add(const Duration(days: 10)),
        toDate: DateTime.now().add(const Duration(days: 12)),
        reason: 'Personal errand',
        status: 'pending',
        appliedAt: DateTime.now(),
      );

      await service.applyTeacherLeave(leaveReq, repo: repo);

      await service.cancelLeave('leave_t3', 'teacher_103', repo: repo);

      final leaves = await service.getAllLeaveRequests(schoolId: testSchoolId);
      final cancelled = leaves.firstWhere((l) => l.id == 'leave_t3');
      expect(cancelled.status, 'cancelled');
    });
  });

  group('Connected School Workflows - Notices & Bulletins', () {
    test('Admin publishes notice with audience targeting and generates notification', () async {
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_004';

      final notice = NoticeModel(
        id: 'notice_101',
        schoolId: testSchoolId,
        title: 'Emergency Staff Briefing',
        content: 'All faculty members are required to attend a 15-minute briefing in the main auditorium.',
        category: 'General',
        targetAudience: 'All Staff',
        status: 'Published',
        date: DateTime.now(),
        author: 'Principal Office',
        isPinned: true,
        isUnread: true,
      );

      await repo.addNotice(notice, schoolId: testSchoolId);

      // Verify notice retrieval
      final notices = await repo.getNotices(schoolId: testSchoolId, userRole: UserRole.teacher);
      expect(notices.any((n) => n.id == 'notice_101'), isTrue);

      // Verify automatic in-app notification creation
      final notifications = await repo.getNotifications(schoolId: testSchoolId);
      expect(notifications.any((n) => n.relatedRecordId == 'notice_101' && n.title.contains('Emergency Staff Briefing')), isTrue);
    });

    test('Draft notice is hidden from teachers and only visible to admin until published', () async {
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_005';

      final draftNotice = NoticeModel(
        id: 'notice_draft_1',
        schoolId: testSchoolId,
        title: 'Draft - Upcoming Science Fair',
        content: 'Guidelines and criteria are being finalized.',
        category: 'Academic',
        targetAudience: 'All Staff',
        status: 'Draft',
        date: DateTime.now(),
        author: 'Science Dept',
      );

      await repo.addNotice(draftNotice, schoolId: testSchoolId);

      // Teacher role should NOT see draft
      final teacherNotices = await repo.getNotices(schoolId: testSchoolId, userRole: UserRole.teacher);
      expect(teacherNotices.any((n) => n.id == 'notice_draft_1'), isFalse);

      // School Admin role CAN see draft
      final adminNotices = await repo.getNotices(schoolId: testSchoolId, userRole: UserRole.schoolAdmin);
      expect(adminNotices.any((n) => n.id == 'notice_draft_1'), isTrue);

      // Admin publishes draft
      await repo.updateNotice(
        draftNotice.copyWith(status: 'Published'),
        schoolId: testSchoolId,
      );

      // Now teacher sees it!
      final publishedToTeacher = await repo.getNotices(schoolId: testSchoolId, userRole: UserRole.teacher);
      expect(publishedToTeacher.any((n) => n.id == 'notice_draft_1'), isTrue);
    });

    test('Delete notice removes from bulletin board', () async {
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_006';

      final notice = NoticeModel(
        id: 'notice_del_1',
        schoolId: testSchoolId,
        title: 'Temporary Notice',
        content: 'Content to be removed.',
        category: 'General',
        targetAudience: 'Everyone',
        status: 'Published',
        date: DateTime.now(),
        author: 'Admin',
      );

      await repo.addNotice(notice, schoolId: testSchoolId);
      expect((await repo.getNotices(schoolId: testSchoolId)).any((n) => n.id == 'notice_del_1'), isTrue);

      await repo.deleteNotice('notice_del_1', schoolId: testSchoolId);
      expect((await repo.getNotices(schoolId: testSchoolId)).any((n) => n.id == 'notice_del_1'), isFalse);
    });
  });

  group('Connected School Workflows - Meetings Scheduling & Cancellation', () {
    test('Admin schedules meeting, notification dispatched, attendees can fetch meeting', () async {
      final service = SchoolManagementService();
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_007';

      final meeting = SchoolMeetingModel(
        id: 'meet_001',
        schoolId: testSchoolId,
        title: 'Term-End Academic Review',
        agenda: 'Review class syllabus completion and term mark assessments.',
        meetingDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '10:00 AM',
        endTime: '11:30 AM',
        locationOrLink: 'Conference Room 2 & Google Meet',
        organizerId: 'admin_1',
        organizerName: 'Academic Director',
        targetAudience: 'All Staff',
        status: 'Scheduled',
        createdAt: DateTime.now(),
      );

      await service.createMeeting(meeting, repo: repo);

      final meetings = await service.getMeetings(schoolId: testSchoolId, userRole: UserRole.teacher);
      expect(meetings.any((m) => m.id == 'meet_001'), isTrue);

      final notifs = await repo.getNotifications(schoolId: testSchoolId);
      expect(notifs.any((n) => n.relatedRecordId == 'meet_001' && n.title.contains('Term-End Academic Review')), isTrue);
    });

    test('Admin cancels meeting with reason, cancellation notification is dispatched', () async {
      final service = SchoolManagementService();
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_008';

      final meeting = SchoolMeetingModel(
        id: 'meet_002',
        schoolId: testSchoolId,
        title: 'PTA Coordination Session',
        agenda: 'Discuss annual day celebration planning.',
        meetingDate: DateTime.now().add(const Duration(days: 3)),
        startTime: '02:00 PM',
        endTime: '03:00 PM',
        locationOrLink: 'Auditorium Hall',
        organizerId: 'admin_1',
        organizerName: 'Principal',
        targetAudience: 'All Staff',
        status: 'Scheduled',
        createdAt: DateTime.now(),
      );

      await service.createMeeting(meeting, repo: repo);

      await service.cancelMeeting(
        'meet_002',
        'Postponed due to state board training session',
        repo: repo,
      );

      final meetings = await service.getMeetings(schoolId: testSchoolId, statusFilter: 'Cancelled');
      final cancelled = meetings.firstWhere((m) => m.id == 'meet_002');
      expect(cancelled.status, 'Cancelled');
      expect(cancelled.cancelReason, contains('state board training'));

      final cancelNotifs = await repo.getNotifications(schoolId: testSchoolId);
      expect(cancelNotifs.any((n) => n.relatedRecordId == 'meet_002' && n.title.contains('Meeting Cancelled')), isTrue);
    });
  });

  group('Connected School Workflows - Notifications Hub', () {
    test('Mark single and mark all notifications read updates counters', () async {
      final repo = SchoolRepository();
      const testSchoolId = 'school_test_009';
      const testUser = 'user_99';

      final n1 = NotificationModel(
        id: 'n_1',
        schoolId: testSchoolId,
        recipientId: testUser,
        title: 'First Alert',
        message: 'Message 1',
        timestamp: DateTime.now(),
        category: 'General',
        isUnread: true,
      );
      final n2 = NotificationModel(
        id: 'n_2',
        schoolId: testSchoolId,
        recipientId: testUser,
        title: 'Second Alert',
        message: 'Message 2',
        timestamp: DateTime.now(),
        category: 'General',
        isUnread: true,
      );

      await repo.addNotification(n1);
      await repo.addNotification(n2);

      int count = await repo.getUnreadNotificationCount(schoolId: testSchoolId, userId: testUser);
      expect(count, equals(2));

      // Mark single notification read
      await repo.markNotificationRead('n_1', schoolId: testSchoolId);
      count = await repo.getUnreadNotificationCount(schoolId: testSchoolId, userId: testUser);
      expect(count, equals(1));

      // Mark all read
      await repo.markAllNotificationsRead(schoolId: testSchoolId, userId: testUser);
      count = await repo.getUnreadNotificationCount(schoolId: testSchoolId, userId: testUser);
      expect(count, equals(0));
    });
  });

  group('Connected School Workflows - Local Storage Persistence', () {
    test('Leaves, notices, meetings and notifications survive service recreation', () async {
      const testSchoolId = 'school_persist_001';

      // Phase 1: create with first instance
      final service1 = SchoolManagementService();
      final repo1 = SchoolRepository();

      await service1.applyTeacherLeave(
        TeacherLeaveModel(
          id: 'leave_persist_1',
          schoolId: testSchoolId,
          teacherId: 'teacher_p1',
          teacherName: 'Persist Teacher',
          leaveType: 'Sick',
          fromDate: DateTime.now(),
          toDate: DateTime.now().add(const Duration(days: 1)),
          reason: 'Fever',
          status: 'pending',
          appliedAt: DateTime.now(),
        ),
      );

      await service1.createMeeting(
        SchoolMeetingModel(
          id: 'meet_persist_1',
          schoolId: testSchoolId,
          title: 'Persisted Meeting',
          agenda: 'Agenda',
          meetingDate: DateTime.now().add(const Duration(days: 1)),
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          locationOrLink: 'Online',
          organizerId: 'admin',
          organizerName: 'Admin',
          targetAudience: 'All Staff',
          status: 'Scheduled',
          createdAt: DateTime.now(),
        ),
      );

      await repo1.addNotice(
        NoticeModel(
          id: 'notice_persist_1',
          schoolId: testSchoolId,
          title: 'Persisted Notice',
          content: 'Important info',
          category: 'General',
          targetAudience: 'All Staff',
          status: 'Published',
          date: DateTime.now(),
          author: 'Admin',
        ),
        schoolId: testSchoolId,
      );

      // Phase 2: Create completely brand new service and repository instances
      final service2 = SchoolManagementService();
      final repo2 = SchoolRepository();

      final leaves = await service2.getAllLeaveRequests(schoolId: testSchoolId);
      expect(leaves.any((l) => l.id == 'leave_persist_1'), isTrue);

      final meetings = await service2.getMeetings(schoolId: testSchoolId);
      expect(meetings.any((m) => m.id == 'meet_persist_1'), isTrue);

      final notices = await repo2.getNotices(schoolId: testSchoolId);
      expect(notices.any((n) => n.id == 'notice_persist_1'), isTrue);
    });
  });
}
