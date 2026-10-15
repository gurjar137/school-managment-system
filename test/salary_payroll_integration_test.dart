import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/data/models/academic_models.dart';
import 'package:school_app/data/models/salary_models.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/data/repositories/school_repository.dart';
import 'package:school_app/data/services/salary_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Staff Salary & Monthly Payroll Integration Tests', () {
    const schoolA = 'sch_greenwood_101';
    const schoolB = 'sch_stxaviers_202';

    final teacher1 = TeacherModel(
      id: 'emp_001',
      schoolId: schoolA,
      employeeId: 'EMP-001',
      name: 'Dr. Rajesh Kumar',
      email: 'rajesh@greenwood.edu',
      phone: '+91 98765 00001',
      designation: 'Senior Mathematics Faculty',
      assignedClass: 'Class 10 - A',
      subjects: ['Mathematics'],
      totalStudents: 35,
      avatarUrl: '',
    );

    final teacher2 = TeacherModel(
      id: 'emp_002',
      schoolId: schoolA,
      employeeId: 'EMP-002',
      name: 'Anita Sharma',
      email: 'anita@greenwood.edu',
      phone: '+91 98765 00002',
      designation: 'Physics Lecturer',
      assignedClass: 'Class 12 - Science',
      subjects: ['Physics'],
      totalStudents: 40,
      avatarUrl: '',
    );

    final teacherSchoolB = TeacherModel(
      id: 'emp_b01',
      schoolId: schoolB,
      employeeId: 'EMP-B01',
      name: 'Michael D’Souza',
      email: 'michael@stxaviers.edu',
      phone: '+91 98765 99999',
      designation: 'Headmaster',
      assignedClass: 'Class 10 - B',
      subjects: ['English'],
      totalStudents: 30,
      avatarUrl: '',
    );

    Future<void> setupTeacher1Salary(SalaryService service) async {
      final struct1 = SalaryStructure(
        id: 'sal_${schoolA}_${teacher1.id}',
        schoolId: schoolA,
        staffProfileId: teacher1.id,
        staffName: teacher1.name,
        basicSalary: 45000.0,
        allowances: const [
          SalaryAllowance(type: 'HRA', amount: 8000.0),
          SalaryAllowance(type: 'Transport', amount: 3000.0),
        ],
        deductions: const [
          SalaryDeduction(type: 'PF', amount: 2500.0),
          SalaryDeduction(type: 'Tax', amount: 1500.0),
        ],
        effectiveFrom: DateTime(2026, 1, 1),
        paymentSchedule: 'Monthly',
        isActive: true,
        createdAt: DateTime.now(),
      );
      await service.updateSalaryStructure(teacher1.id, struct1);
    }

    test('1. Unconfigured teacher returns null and hasSalaryConfigured returns false (Zero fake numbers)', () async {
      final salaryService = SalaryService();
      final struct = await salaryService.getSalaryStructure(teacher1.id, schoolId: schoolA);
      expect(struct, isNull, reason: 'Unconfigured teacher must return null and not fake default INR');

      final hasConfigured = await salaryService.hasSalaryConfigured(teacher1.id, schoolId: schoolA);
      expect(hasConfigured, isFalse);
    });

    test('2. Teacher salary configuration saves valid structure with net salary calculation', () async {
      final salaryService = SalaryService();

      final newStruct = SalaryStructure(
        id: 'sal_${schoolA}_${teacher1.id}',
        schoolId: schoolA,
        staffProfileId: teacher1.id,
        staffName: teacher1.name,
        salaryType: 'Monthly',
        basicSalary: 45000.0,
        allowances: const [
          SalaryAllowance(type: 'HRA', amount: 8000.0),
          SalaryAllowance(type: 'Transport', amount: 3000.0),
        ],
        deductions: const [
          SalaryDeduction(type: 'PF', amount: 2500.0),
          SalaryDeduction(type: 'Tax', amount: 1500.0),
        ],
        effectiveFrom: DateTime(2026, 1, 1),
        paymentSchedule: 'Monthly',
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Verify mathematical calculation
      expect(newStruct.basicSalary, 45000.0);
      expect(newStruct.totalAllowances, 11000.0);
      expect(newStruct.totalDeductions, 4000.0);
      expect(newStruct.grossSalary, 56000.0);
      expect(newStruct.netSalary, 52000.0); // 45000 + 11000 - 4000

      await salaryService.updateSalaryStructure(teacher1.id, newStruct);

      final retrieved = await salaryService.getSalaryStructure(teacher1.id, schoolId: schoolA);
      expect(retrieved, isNotNull);
      expect(retrieved!.basicSalary, 45000.0);
      expect(retrieved.netSalary, 52000.0);

      final isConfigured = await salaryService.hasSalaryConfigured(teacher1.id, schoolId: schoolA);
      expect(isConfigured, isTrue);
    });

    test('3. Salary structure updates correctly recalculate net salary and update timestamps', () async {
      final salaryService = SalaryService();

      // Configure initial structure
      final initial = SalaryStructure(
        id: 'sal_${schoolA}_${teacher2.id}',
        schoolId: schoolA,
        staffProfileId: teacher2.id,
        staffName: teacher2.name,
        basicSalary: 30000.0,
        allowances: const [SalaryAllowance(type: 'HRA', amount: 4000.0)],
        deductions: const [SalaryDeduction(type: 'PF', amount: 1000.0)],
        effectiveFrom: DateTime(2026, 1, 1),
      );
      await salaryService.updateSalaryStructure(teacher2.id, initial);

      // Update basic salary and allowances
      final updated = initial.copyWith(
        basicSalary: 35000.0,
        allowances: const [
          SalaryAllowance(type: 'HRA', amount: 5000.0),
          SalaryAllowance(type: 'Transport', amount: 2000.0),
        ],
        updatedAt: DateTime.now(),
      );
      await salaryService.updateSalaryStructure(teacher2.id, updated);

      final result = await salaryService.getSalaryStructure(teacher2.id, schoolId: schoolA);
      expect(result, isNotNull);
      expect(result!.basicSalary, 35000.0);
      expect(result.totalAllowances, 7000.0);
      expect(result.netSalary, 41000.0); // 35000 + 7000 - 1000
    });

    test('4. Batch monthly payroll generation produces accurate records for configured staff', () async {
      final salaryService = SalaryService();
      await setupTeacher1Salary(salaryService);

      // teacher2 is left unconfigured!
      const month = 'October 2026';
      final payrolls = await salaryService.generateMonthlyPayroll(
        schoolId: schoolA,
        monthYear: month,
        teachers: [teacher1, teacher2],
        adminName: 'Principal Johnson',
      );

      expect(payrolls.length, 2);

      // Teacher 1 (Configured)
      final p1 = payrolls.firstWhere((p) => p.staffProfileId == teacher1.id);
      expect(p1.basicSalary, 45000.0);
      expect(p1.netPayable, 52000.0);
      expect(p1.amountPaid, 0.0);
      expect(p1.remainingBalance, 52000.0);
      expect(p1.status, SalaryStatus.pending);

      // Teacher 2 (Unconfigured)
      final p2 = payrolls.firstWhere((p) => p.staffProfileId == teacher2.id);
      expect(p2.basicSalary, 0.0);
      expect(p2.netPayable, 0.0);
      expect(p2.status, SalaryStatus.notConfigured);
    });

    test('5. Idempotent monthly payroll generation preserves existing paid amounts', () async {
      final salaryService = SalaryService();
      await setupTeacher1Salary(salaryService);
      const month = 'October 2026';

      // 1. Initial payroll generated
      await salaryService.generateMonthlyPayroll(
        schoolId: schoolA,
        monthYear: month,
        teachers: [teacher1],
      );

      // 2. Disburse partial payment of 20000
      await salaryService.recordSalaryPayment(
        teacher: teacher1,
        monthYear: month,
        amountPaid: 20000.0,
        paymentMethod: 'Bank Transfer',
        referenceNo: 'TXN-OCT-PARTIAL',
        notes: 'Advance installment',
      );

      // 3. Re-run monthly payroll generation (e.g. at end of month)
      final reloaded = await salaryService.generateMonthlyPayroll(
        schoolId: schoolA,
        monthYear: month,
        teachers: [teacher1],
      );

      final p = reloaded.firstWhere((item) => item.staffProfileId == teacher1.id);
      expect(p.netPayable, 52000.0);
      expect(p.amountPaid, 20000.0, reason: 'Already disbursed payments must not be wiped on re-generation');
      expect(p.remainingBalance, 32000.0);
      expect(p.status, SalaryStatus.partial);
    });

    test('6. Full salary payment marks payroll as Paid and reduces remaining balance to zero', () async {
      final salaryService = SalaryService();
      await setupTeacher1Salary(salaryService);
      const month = 'October 2026';

      // Generate payroll
      await salaryService.generateMonthlyPayroll(
        schoolId: schoolA,
        monthYear: month,
        teachers: [teacher1],
      );

      // Pay first installment 20000
      await salaryService.recordSalaryPayment(
        teacher: teacher1,
        monthYear: month,
        amountPaid: 20000.0,
        paymentMethod: 'Bank Transfer',
        referenceNo: 'TXN-P1',
        notes: 'Part 1',
      );

      // Pay remaining 32000
      final slip = await salaryService.recordSalaryPayment(
        teacher: teacher1,
        monthYear: month,
        amountPaid: 32000.0,
        paymentMethod: 'UPI',
        referenceNo: 'UPI-OCT-FINAL',
        notes: 'Final settlement',
      );

      expect(slip.amountPaid, 52000.0);
      expect(slip.remainingBalance, 0.0);
      expect(slip.status, SalaryStatus.paid);

      // Verify in payroll model
      final payrolls = await salaryService.getMonthlyPayrollsForSchool(month, schoolId: schoolA);
      final p = payrolls.firstWhere((item) => item.staffProfileId == teacher1.id);
      expect(p.amountPaid, 52000.0);
      expect(p.remainingBalance, 0.0);
      expect(p.status, SalaryStatus.paid);
      expect(p.finalizedAt, isNotNull);
    });

    test('7. Payment history returns all transactions accurately with audit details', () async {
      final salaryService = SalaryService();
      await setupTeacher1Salary(salaryService);
      const month = 'October 2026';

      await salaryService.generateMonthlyPayroll(
        schoolId: schoolA,
        monthYear: month,
        teachers: [teacher1],
      );

      await salaryService.recordSalaryPayment(
        teacher: teacher1,
        monthYear: month,
        amountPaid: 20000.0,
        paymentMethod: 'Bank Transfer',
        referenceNo: 'TXN-OCT-PARTIAL',
        notes: 'Advance installment',
      );

      await salaryService.recordSalaryPayment(
        teacher: teacher1,
        monthYear: month,
        amountPaid: 32000.0,
        paymentMethod: 'UPI',
        referenceNo: 'UPI-OCT-FINAL',
        notes: 'Final settlement',
      );

      final history = await salaryService.getSalaryHistory(teacher1.id, schoolA);

      expect(history.length, 2, reason: 'Must contain both partial and final payment records');
      expect(history[0].referenceNo, 'UPI-OCT-FINAL');
      expect(history[0].amountPaid, 32000.0);
      expect(history[1].referenceNo, 'TXN-OCT-PARTIAL');
      expect(history[1].amountPaid, 20000.0);
    });

    test('8. Dashboard metrics accurately reflect live payroll expenses, paid and pending totals', () async {
      final salaryService = SalaryService();
      await setupTeacher1Salary(salaryService);
      const month = 'October 2026';

      await salaryService.generateMonthlyPayroll(
        schoolId: schoolA,
        monthYear: month,
        teachers: [teacher1, teacher2],
      );

      // Disburse 20000 for teacher1
      await salaryService.recordSalaryPayment(
        teacher: teacher1,
        monthYear: month,
        amountPaid: 20000.0,
        paymentMethod: 'Bank Transfer',
        referenceNo: 'TXN-METRICS-01',
        notes: 'Payment test',
      );

      final metrics = await salaryService.getSalaryDashboardMetrics(
        schoolId: schoolA,
        monthYear: month,
        teachers: [teacher1, teacher2],
      );

      expect(metrics.totalStaff, 2);
      expect(metrics.configuredStaff, 1);
      expect(metrics.unconfiguredStaff, 1);
      expect(metrics.monthlyPayrollExpense, 52000.0);
      expect(metrics.paidSalariesTotal, 20000.0);
      expect(metrics.pendingSalariesTotal, 32000.0);
    });

    test('9. Multi-tenant isolation: School A salary records do not leak into School B', () async {
      final salaryService = SalaryService();

      // Configure School B teacher
      final structB = SalaryStructure(
        id: 'sal_${schoolB}_${teacherSchoolB.id}',
        schoolId: schoolB,
        staffProfileId: teacherSchoolB.id,
        staffName: teacherSchoolB.name,
        basicSalary: 60000.0,
        allowances: const [],
        deductions: const [],
      );
      await salaryService.updateSalaryStructure(teacherSchoolB.id, structB);

      // Query School A payrolls: School B teacher must not appear
      final payrollsA = await salaryService.getMonthlyPayrollsForSchool('October 2026', schoolId: schoolA);
      final hasSchoolBInA = payrollsA.any((p) => p.staffProfileId == teacherSchoolB.id);
      expect(hasSchoolBInA, isFalse, reason: 'Tenant isolation violated: School B employee found in School A');

      // Query School A history: School B history must be empty
      final historyA = await salaryService.getSalaryHistory(teacherSchoolB.id, schoolA);
      expect(historyA, isEmpty);
    });

    test('10. Dual-tier offline durability survives service reloading via SharedPreferences', () async {
      // 1. Create first service instance and write structure
      final serviceInstance1 = SalaryService();
      final struct = SalaryStructure(
        id: 'sal_${schoolA}_durable_01',
        schoolId: schoolA,
        staffProfileId: 'durable_01',
        staffName: 'Persistent Faculty',
        basicSalary: 55000.0,
        allowances: const [SalaryAllowance(type: 'HRA', amount: 5000.0)],
        deductions: const [],
      );
      await serviceInstance1.updateSalaryStructure('durable_01', struct);

      // 2. Create brand-new service instance (simulating app restart / new session)
      final serviceInstance2 = SalaryService();
      final loaded = await serviceInstance2.getSalaryStructure('durable_01', schoolId: schoolA);

      expect(loaded, isNotNull);
      expect(loaded!.basicSalary, 55000.0);
      expect(loaded.totalAllowances, 5000.0);
      expect(loaded.netSalary, 60000.0);
    });

    test('11. Salary payment emits in-app notification to employee', () async {
      final salaryService = SalaryService();
      await setupTeacher1Salary(salaryService);
      final repo = SchoolRepository();

      await salaryService.recordSalaryPayment(
        teacher: teacher1,
        monthYear: 'November 2026',
        amountPaid: 15000.0,
        paymentMethod: 'Bank Transfer',
        referenceNo: 'NOTIF-TEST-001',
        notes: 'Monthly advance',
        repo: repo,
      );

      final unreadCount = await repo.getUnreadNotificationCount(
        schoolId: schoolA,
        userId: teacher1.id,
        role: UserRole.teacher,
      );
      expect(unreadCount, greaterThanOrEqualTo(1));
    });
  });
}
