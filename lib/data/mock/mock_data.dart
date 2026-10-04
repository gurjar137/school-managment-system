import '../models/user_model.dart';
import '../models/student_model.dart';
import '../models/academic_models.dart';

class MockData {
  static const UserModel currentAdminUser = UserModel(
    id: 'usr_admin',
    name: 'School Administrator',
    email: 'admin@school.com',
    role: UserRole.schoolAdmin,
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
    schoolName: 'Primary School Campus',
    designation: 'Principal & School Administrator',
  );

  static const UserModel currentTeacherUser = UserModel(
    id: 'usr_teacher',
    name: 'Faculty Educator',
    email: 'teacher@school.com',
    role: UserRole.teacher,
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
    schoolName: 'Primary School Campus',
    designation: 'Senior Faculty & Class Educator',
    assignedClass: '',
    subject: '',
    totalStudentsInClass: 0,
  );

  static final List<TeacherModel> teachers = [];
  static final List<StudentModel> students = [];
  static final List<ClassroomModel> classrooms = [];
  static final List<TimetableSlotModel> timetable = [];
  static final List<NoticeModel> notices = [];
  static final List<HomeworkModel> homeworkList = [];
  static final List<ExamModel> exams = [];
  static final List<FeeRecordModel> feeRecords = [];
  static final List<LeaveRequestModel> leaveRequests = [];
  static final List<LibraryBookModel> libraryBooks = [];
  static final List<TransportRouteModel> transportRoutes = [];
  static final List<NotificationModel> notifications = [];
}
