import "package:flutter_test/flutter_test.dart";
import "package:school_app/core/utils/teacher_assignment_parser.dart";
import "package:school_app/data/models/attendance_model.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/services/attendance_service.dart";

void main() {
  group("Teacher Attendance Summary & Model Tests", () {
    test("A) Zero-attendance student returns real empty/zero summary (0 counts, 0.0%)", () {
      const summary = AttendanceSummaryModel(
        studentId: "stu-zero",
        studentName: "Test Zero Student",
        totalWorkingDays: 0,
        presentCount: 0,
        absentCount: 0,
        lateCount: 0,
        leaveCount: 0,
      );

      expect(summary.totalWorkingDays, equals(0));
      expect(summary.presentCount, equals(0));
      expect(summary.absentCount, equals(0));
      expect(summary.lateCount, equals(0));
      expect(summary.leaveCount, equals(0));
      expect(summary.attendancePercentage, equals(0.0));
    });

    test("B) Existing attendance computes exact counts and percentage", () {
      const summary = AttendanceSummaryModel(
        studentId: "stu-active",
        studentName: "Active Student",
        totalWorkingDays: 20,
        presentCount: 18,
        absentCount: 1,
        lateCount: 1,
        leaveCount: 0,
      );

      expect(summary.totalWorkingDays, equals(20));
      expect(summary.presentCount, equals(18));
      expect(summary.absentCount, equals(1));
      expect(summary.lateCount, equals(1));
      // Effective present: 18 + (1 * 0.5) = 18.5. Percentage = 18.5 / 20 * 100 = 92.5%
      expect(summary.attendancePercentage, equals(92.5));
    });

    test("C) TeacherAssignmentParser matches class and section accurately", () {
      final parser1A = TeacherAssignmentParser(
        assignedClass: "Class 1",
        assignedSection: "A",
      );

      expect(parser1A.matchesClassAndSection("Class 1", "A"), isTrue);
      expect(parser1A.matchesClassAndSection("1", "a"), isTrue);
      expect(parser1A.matchesClassAndSection("Class 1", "B"), isFalse);
      expect(parser1A.matchesClassAndSection("Class 12", "A"), isFalse);
      expect(parser1A.matchesClassAndSection("Class 12", "B"), isFalse);

      final unassigned = TeacherAssignmentParser(
        assignedClass: "Not Assigned",
        assignedSection: "",
      );
      expect(unassigned.matchesClassAndSection("Class 1", "A"), isFalse);
      expect(unassigned.hasFilter, isFalse);
    });

    test("D) Unconfigured or empty client returns legitimate empty summary without mock fallback", () async {
      final service = AttendanceService();

      final summary = await service.getStudentAttendanceSummary(
        schoolId: "6254bee9-151d-4332-8a1c-3994af7d2153",
        studentId: "nonexistent-student-id",
        studentName: "Nonexistent",
      );

      expect(summary.totalWorkingDays, equals(0));
      expect(summary.presentCount, equals(0));
      expect(summary.absentCount, equals(0));
      expect(summary.lateCount, equals(0));
      expect(summary.leaveCount, equals(0));
      expect(summary.attendancePercentage, equals(0.0));
    });

    test("E) Unconfigured or empty client returns empty monthly attendance list without mock fallback", () async {
      final service = AttendanceService();

      final monthly = await service.getMonthlyAttendanceForChild(
        schoolId: "6254bee9-151d-4332-8a1c-3994af7d2153",
        studentId: "nonexistent-student-id",
        year: 2026,
        month: 9,
      );

      expect(monthly, isEmpty);
    });
  });
}
