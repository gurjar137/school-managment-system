import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:school_app/data/models/salary_models.dart";
import "package:school_app/data/models/academic_models.dart";
import "package:school_app/data/models/user_model.dart";
import "package:school_app/data/models/student_model.dart";
import "package:school_app/data/services/salary_service.dart";
import "package:school_app/data/services/student_service.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("P1-1: Salary Service & Persistence Tests", () {
    late SalaryService salaryService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      salaryService = SalaryService();
    });

    test("SalaryStructure JSON serialization round-trip", () {
      const original = SalaryStructure(
        basicSalary: 35000,
        allowances: [
          SalaryAllowance(type: "HRA", amount: 8000),
          SalaryAllowance(type: "DA", amount: 4000),
        ],
        deductions: [
          SalaryDeduction(type: "PF", amount: 2500),
          SalaryDeduction(type: "TDS", amount: 1500),
        ],
      );

      final json = original.toJson();
      final reconstructed = SalaryStructure.fromJson(json);

      expect(reconstructed.basicSalary, equals(35000));
      expect(reconstructed.totalAllowances, equals(12000));
      expect(reconstructed.totalDeductions, equals(4000));
      expect(reconstructed.netSalary, equals(43000));
    });

    test("SalaryPaymentRecord JSON serialization round-trip", () {
      final payment = SalaryPaymentRecord(
        paymentId: "pay_999",
        teacherId: "teacher_001",
        staffName: "Ramesh Sharma",
        month: "September 2026",
        netSalary: 43000,
        amountPaid: 43000,
        paymentDate: DateTime(2026, 9, 7),
        paymentMethod: "bank_transfer",
        referenceNo: "TXN-SEP-001",
        status: SalaryStatus.paid,
        notes: "Monthly salary",
      );

      final json = payment.toJson();
      final restored = SalaryPaymentRecord.fromJson(json);

      expect(restored.paymentId, equals("pay_999"));
      expect(restored.staffName, equals("Ramesh Sharma"));
      expect(restored.amountPaid, equals(43000));
      expect(restored.paymentMethod, equals("bank_transfer"));
      expect(restored.referenceNo, equals("TXN-SEP-001"));
      expect(restored.status, equals(SalaryStatus.paid));
    });

    test("Save salary structure and verify persistent storage across service re-instantiation", () async {
      const updatedStructure = SalaryStructure(
        basicSalary: 42000,
        allowances: [
          SalaryAllowance(type: "HRA", amount: 9000),
        ],
        deductions: [
          SalaryDeduction(type: "PF", amount: 3000),
        ],
      );

      await salaryService.updateSalaryStructure("t1", updatedStructure);

      final retrieved = await salaryService.getSalaryStructure("t1");
      expect(retrieved.basicSalary, equals(42000));
      expect(retrieved.netSalary, equals(48000));

      // Re-instantiate service (simulating app reload)
      final newSalaryService = SalaryService();
      final reloaded = await newSalaryService.getSalaryStructure("t1");
      expect(reloaded.basicSalary, equals(42000));
      expect(reloaded.netSalary, equals(48000));
    });

    test("Record salary payment, retrieve history, and verify slip generation", () async {
      const teacher = TeacherModel(
        id: "t1",
        name: "Ramesh Sharma",
        email: "ramesh@school.com",
        subjects: ["Mathematics"],
        assignedClass: "Class 10-A",
        totalStudents: 35,
        avatarUrl: "",
        phone: "9876543210",
        designation: "Senior Mathematics Teacher",
      );

      const struct = SalaryStructure(
        basicSalary: 42000,
        allowances: [SalaryAllowance(type: "HRA", amount: 9000)],
        deductions: [SalaryDeduction(type: "PF", amount: 3000)],
      );
      await salaryService.updateSalaryStructure("t1", struct);

      final slip = await salaryService.recordSalaryPayment(
        teacher: teacher,
        monthYear: "September 2026",
        amountPaid: 48000,
        paymentMethod: "Bank Transfer",
        referenceNo: "NEFT998811",
        notes: "September disbursement",
      );

      expect(slip.teacherName, equals("Ramesh Sharma"));
      expect(slip.month, equals("September 2026"));
      expect(slip.netSalary, equals(48000));
      expect(slip.status, equals(SalaryStatus.paid));

      // Verify payment appears in history
      final history = await salaryService.getSalaryHistory();
      expect(history.any((p) => p.teacherId == "t1" && p.referenceNo == "NEFT998811"), isTrue);

      // Verify persistent retention across fresh service instantiation
      final reloadService = SalaryService();
      final reloadedHistory = await reloadService.getSalaryHistory();
      expect(reloadedHistory.any((p) => p.teacherId == "t1" && p.referenceNo == "NEFT998811"), isTrue);
    });
  });

  group("P1-2: Student Status & Deletion Service Tests", () {
    late StudentService studentService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      studentService = StudentService();
    });

    StudentModel createSampleStudent(String id, String name) {
      return StudentModel(
        id: id,
        name: name,
        rollNumber: "15",
        admissionNumber: "ADM-$id",
        className: "8",
        section: "A",
        avatarUrl: "https://example.com/avatar.jpg",
        attendancePercentage: 100.0,
        todayAttendance: AttendanceStatus.present,
        dateOfBirth: "2012-05-15",
        gender: "Male",
        fatherName: "Test Father",
        fatherMobile: "+91 98765 43210",
        motherName: "Test Mother",
        motherMobile: "+91 98765 43211",
        guardianName: "Test Father",
        emergencyContact: "+91 98765 43210",
        parentEmail: "parent@gmail.com",
        address: "14 Park Street",
        city: "New Delhi",
        state: "Delhi",
        pinCode: "110016",
        bloodGroup: "O+",
        medicalNotes: "None",
        importantNotes: "None",
        totalFee: 45000.0,
        paidFee: 15000.0,
        pendingFee: 30000.0,
        feeStatus: PaymentStatus.partial,
        status: AccountStatus.active,
        paymentHistory: const [],
      );
    }

    test("Update student status updates memory and persistent storage", () async {
      final sample = createSampleStudent("std_stat_001", "Status Test Student");
      await studentService.addStudent(sample);

      // Update status to inactive
      await studentService.updateStudentStatus(sample.id, AccountStatus.inactive);
      final updated = await studentService.getStudentById(sample.id);
      expect(updated, isNotNull);
      expect(updated!.status, equals(AccountStatus.inactive));

      // Re-activate student
      await studentService.updateStudentStatus(sample.id, AccountStatus.active);
      final reactivated = await studentService.getStudentById(sample.id);
      expect(reactivated, isNotNull);
      expect(reactivated!.status, equals(AccountStatus.active));
    });

    test("Delete student removes student from cache when permissible", () async {
      final sample = createSampleStudent("test_student_del_123", "Temporary Test Student");
      await studentService.addStudent(sample);

      final fetched = await studentService.getStudentById("test_student_del_123");
      expect(fetched, isNotNull);

      await studentService.deleteStudent("test_student_del_123");
      final afterDelete = await studentService.getStudentById("test_student_del_123");
      expect(afterDelete, isNull);
    });
  });
}
