import 'package:flutter_test/flutter_test.dart';
import 'package:school_app/data/models/fee_models.dart';

void main() {
  group('Fee Models Unit Tests', () {
    test('FeeComponentModel parses correctly from JSON and serializes to JSON', () {
      final json = {
        'id': 'comp_1',
        'fee_structure_id': 'struct_1',
        'school_id': 'sch_1',
        'name': 'Tuition Fee',
        'amount': 2500.0,
        'frequency': 'monthly',
        'due_day': 10,
        'description': 'Monthly standard tuition',
      };

      final comp = FeeComponentModel.fromJson(json);
      expect(comp.id, 'comp_1');
      expect(comp.name, 'Tuition Fee');
      expect(comp.amount, 2500.0);
      expect(comp.frequency, FeeFrequency.monthly);
      expect(comp.dueDay, 10);

      final outJson = comp.toJson();
      expect(outJson['name'], 'Tuition Fee');
      expect(outJson['amount'], 2500.0);
      expect(outJson['frequency'], 'monthly');
    });

    test('FeeStructureModel calculates totalBaseAmount correctly', () {
      final comps = [
        const FeeComponentModel(
          id: '1', feeStructureId: 's1', schoolId: 'sch1',
          name: 'Tuition', amount: 3000.0, frequency: FeeFrequency.monthly,
        ),
        const FeeComponentModel(
          id: '2', feeStructureId: 's1', schoolId: 'sch1',
          name: 'Lab', amount: 500.0, frequency: FeeFrequency.monthly,
        ),
        const FeeComponentModel(
          id: '3', feeStructureId: 's1', schoolId: 'sch1',
          name: 'Exam', amount: 1200.0, frequency: FeeFrequency.halfYearly,
        ),
      ];

      final structure = FeeStructureModel(
        id: 's1',
        schoolId: 'sch1',
        academicYearId: 'ay1',
        className: 'Class 10',
        name: 'Grade 10 Annual',
        components: comps,
      );

      expect(structure.totalBaseAmount, 4700.0);
      expect(structure.className, 'Class 10');
    });

    test('FeeLedgerModel calculates netAmount, balanceAmount, and status correctly', () {
      final ledger = FeeLedgerModel(
        id: 'l1',
        schoolId: 'sch1',
        academicYearId: 'ay1',
        studentId: 'stu1',
        studentName: 'Aarav Sharma',
        feeComponentId: 'c1',
        componentName: 'Tuition Fee',
        billingPeriod: '2026-04',
        dueDate: DateTime.now().add(const Duration(days: 10)),
        amount: 2500.0,
        discountAmount: 500.0,
        adjustmentAmount: 0.0,
        paidAmount: 1000.0,
        status: FeeLedgerStatus.partial,
      );

      expect(ledger.netAmount, 2000.0);
      expect(ledger.balanceAmount, 1000.0);
      expect(ledger.computedStatus, FeeLedgerStatus.partial);
    });

    test('FeeLedgerModel marks paid when balance is zero', () {
      final ledger = FeeLedgerModel(
        id: 'l2',
        schoolId: 'sch1',
        academicYearId: 'ay1',
        studentId: 'stu1',
        studentName: 'Aarav Sharma',
        feeComponentId: 'c1',
        componentName: 'Tuition Fee',
        billingPeriod: '2026-04',
        dueDate: DateTime.now().add(const Duration(days: 10)),
        amount: 2500.0,
        discountAmount: 0.0,
        paidAmount: 2500.0,
        status: FeeLedgerStatus.paid,
      );

      expect(ledger.balanceAmount, 0.0);
      expect(ledger.computedStatus, FeeLedgerStatus.paid);
    });

    test('PaymentRecordModel parses correctly from database JSON', () {
      final json = {
        'id': 'pay_123',
        'school_id': 'sch_1',
        'student_id': 'stu_1',
        'receipt_number': 'REC-2026-000001',
        'amount': 5000.0,
        'payment_method': 'upi',
        'payment_date': '2026-09-06',
        'transaction_reference': 'UPI-REF-998877',
        'notes': 'Q1 Fee',
        'students': {'name': 'Rohan Gupta'},
      };

      final payment = PaymentRecordModel.fromJson(json);
      expect(payment.receiptNumber, 'REC-2026-000001');
      expect(payment.amount, 5000.0);
      expect(payment.studentName, 'Rohan Gupta');
      expect(payment.paymentMethod, PaymentMethod.upi);
      expect(payment.transactionReference, 'UPI-REF-998877');
    });

    test('FeeReceiptModel instantiates and parses correctly', () {
      final receipt = FeeReceiptModel(
        receiptNo: 'REC-2026-000042',
        studentName: 'Priya Singh',
        admissionNumber: 'ADM-2026-088',
        className: 'Class 9',
        date: DateTime(2026, 9, 6),
        amountPaid: 3500.0,
        paymentMethod: 'CASH',
        transactionRef: 'OFFLINE-001',
        previousBalance: 5000.0,
        remainingBalance: 1500.0,
        description: 'Partial Tuition Fee',
      );

      expect(receipt.receiptNo, 'REC-2026-000042');
      expect(receipt.amountPaid, 3500.0);
      expect(receipt.remainingBalance, 1500.0);
      expect(receipt.className, 'Class 9');
    });

    test('StudentFeeAccountModel calculates netFee, currentDue, and computedStatus correctly', () {
      final account = StudentFeeAccountModel(
        id: 'acc_001',
        schoolId: 'sch_1',
        academicYearId: 'ay_1',
        studentId: 'stu_1',
        grossFee: 20000.0,
        discountAmount: 1500.0,
        waiverAmount: 500.0,
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: 'PENDING',
        createdAt: DateTime.now(),
        studentName: 'Rahul Verma',
        admissionNumber: 'ADM-101',
        className: 'Class 10',
        sectionName: 'A',
        totalPaid: 8000.0,
      );

      // netFee = 20000 - 1500 - 500 = 18000
      expect(account.netFee, equals(18000.0));
      // currentDue = 18000 - 8000 = 10000
      expect(account.currentDue, equals(10000.0));
      // With partial payment, computedStatus is PARTIAL
      expect(account.computedStatus, equals('PARTIALLY PAID'));

      final fullPaidAccount = account.copyWith(totalPaid: 18000.0);
      expect(fullPaidAccount.currentDue, equals(0.0));
      expect(fullPaidAccount.computedStatus, equals('PAID'));

      final zeroPaidAccount = account.copyWith(totalPaid: 0.0);
      expect(zeroPaidAccount.currentDue, equals(18000.0));
      expect(zeroPaidAccount.computedStatus, equals('DUE'));
    });

    test('StudentFeeAccountModel parses database columns faithfully', () {
      final dbRow = {
        'id': 'db_acc_99',
        'school_id': 'sch_live',
        'academic_year_id': 'ay_live',
        'student_id': 'stu_live',
        'gross_fee': 30000,
        'discount_amount': 2000,
        'waiver_amount': 1000,
        'due_date': '2026-11-30',
        'notes': 'Quarterly Plan',
        'status': 'PENDING',
        'created_at': '2026-09-01T10:00:00Z',
        'students': {
          'id': 'stu_live',
          'first_name': 'Karan',
          'middle_name': 'Singh',
          'last_name': 'Rathore',
          'admission_number': 'STU-990',
          'class_name': 'Class 11',
          'section_name': 'B',
        },
      };

      final model = StudentFeeAccountModel.fromJson(dbRow, paidSum: 5000.0);
      expect(model.id, equals('db_acc_99'));
      expect(model.studentName, equals('Karan Singh Rathore'));
      expect(model.admissionNumber, equals('STU-990'));
      expect(model.className, equals('Class 11'));
      expect(model.sectionName, equals('B'));
      expect(model.grossFee, equals(30000.0));
      expect(model.discountAmount, equals(2000.0));
      expect(model.waiverAmount, equals(1000.0));
      expect(model.netFee, equals(27000.0));
      expect(model.currentDue, equals(22000.0));
      expect(model.computedStatus, equals('PARTIALLY PAID'));
      expect(model.dbStatus, equals('partially_paid'));
      expect(model.displayStatus, equals('Partially Paid'));
    });

    test('Exact live scenario: Student Ajay with ₹30,000 fee and ₹3,000 payment yields partially_paid', () {
      // 1. Initial State: ₹30,000 fee, 0 paid -> status: 'due'
      final ajayAccount = StudentFeeAccountModel(
        id: 'acc_ajay_1',
        schoolId: 'sch_1',
        academicYearId: 'ay_1',
        studentId: 'stu_ajay',
        grossFee: 30000.0,
        discountAmount: 0.0,
        waiverAmount: 0.0,
        dueDate: DateTime.now().add(const Duration(days: 30)),
        status: 'due',
        createdAt: DateTime.now(),
        studentName: 'ajay',
        admissionNumber: 'ADM-AJAY-001',
        className: 'Class 10',
        sectionName: 'A',
        totalPaid: 0.0,
      );

      expect(ajayAccount.netFee, equals(30000.0));
      expect(ajayAccount.totalPaid, equals(0.0));
      expect(ajayAccount.currentDue, equals(30000.0));
      expect(ajayAccount.dbStatus, equals('due'));
      expect(ajayAccount.displayStatus, equals('Due'));
      expect(ajayAccount.computedStatus, equals('DUE'));

      // 2. Payment of ₹3,000 recorded: Paid = ₹3,000, Due = ₹27,000 -> status: 'partially_paid'
      final ajayAfterPayment = ajayAccount.copyWith(totalPaid: 3000.0);
      expect(ajayAfterPayment.grossFee, equals(30000.0));
      expect(ajayAfterPayment.netFee, equals(30000.0));
      expect(ajayAfterPayment.totalPaid, equals(3000.0));
      expect(ajayAfterPayment.currentDue, equals(27000.0));
      expect(ajayAfterPayment.dbStatus, equals('partially_paid'));
      expect(ajayAfterPayment.displayStatus, equals('Partially Paid'));
      expect(ajayAfterPayment.computedStatus, equals('PARTIALLY PAID'));

      // 3. Final Settlement of ₹27,000: Paid = ₹30,000, Due = ₹0 -> status: 'paid'
      final ajayFullyPaid = ajayAccount.copyWith(totalPaid: 30000.0);
      expect(ajayFullyPaid.currentDue, equals(0.0));
      expect(ajayFullyPaid.dbStatus, equals('paid'));
      expect(ajayFullyPaid.displayStatus, equals('Paid'));
      expect(ajayFullyPaid.computedStatus, equals('PAID'));
    });

    test('Collection schedule properly groups and categorizes overdue accounts', () {
      final now = DateTime.now();
      final overdueDate = now.subtract(const Duration(days: 5));
      final futureDate = now.add(const Duration(days: 15));

      final overdueAcc = StudentFeeAccountModel(
        id: 'acc_1',
        schoolId: 'sch_1',
        academicYearId: 'ay_1',
        studentId: 'stu_1',
        grossFee: 15000,
        discountAmount: 0,
        waiverAmount: 0,
        dueDate: overdueDate,
        status: 'overdue',
        createdAt: now,
        studentName: 'Student Overdue',
        totalPaid: 0,
      );

      final upcomingAcc = StudentFeeAccountModel(
        id: 'acc_2',
        schoolId: 'sch_1',
        academicYearId: 'ay_1',
        studentId: 'stu_2',
        grossFee: 20000,
        discountAmount: 0,
        waiverAmount: 0,
        dueDate: futureDate,
        status: 'due',
        createdAt: now,
        studentName: 'Student Upcoming',
        totalPaid: 0,
      );

      expect(overdueAcc.computedStatus, equals('OVERDUE'));
      expect(overdueAcc.currentDue, equals(15000.0));

      expect(upcomingAcc.computedStatus, equals('DUE'));
      expect(upcomingAcc.currentDue, equals(20000.0));
    });

    test('Student File Fees & Dues tab calculates live net fee and dues accurately', () {
      const studentId = 'b6d08003-8822-4fe1-bb35-77ad9dbead89';
      final account = StudentFeeAccountModel(
        id: 'acc_001',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        academicYearId: 'ay_2026',
        studentId: studentId,
        grossFee: 45000.0,
        discountAmount: 5000.0,
        waiverAmount: 2000.0,
        dueDate: DateTime.now().add(const Duration(days: 15)),
        status: 'partially_paid',
        createdAt: DateTime.now(),
        totalPaid: 18000.0,
      );

      expect(account.netFee, equals(38000.0));
      expect(account.currentDue, equals(20000.0));
      expect(account.dbStatus, equals('partially_paid'));
      expect(account.computedStatus, equals('PARTIALLY PAID'));
      expect(account.displayStatus, equals('Partially Paid'));
    });

    test('PaymentRecordModel creates FeeReceiptModel faithfully for Student File receipt modal', () {
      final payment = PaymentRecordModel(
        id: 'pay_001',
        schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
        studentId: 'std_001',
        feeAccountId: 'acc_001',
        studentName: 'Rohan Sharma',
        admissionNumber: 'STU-2026-0089',
        className: '10-A',
        receiptNumber: 'REC-2026-00042',
        amount: 15000.0,
        paymentMethod: PaymentMethod.upi,
        paymentStatus: PaymentRecordStatus.success,
        referenceNumber: 'UPI9876543210',
        paidAt: DateTime(2026, 9, 5, 14, 30),
        notes: 'Term 1 Tuition Fee Installment',
      );

      final receipt = FeeReceiptModel(
        receiptNo: payment.receiptNumber,
        studentName: payment.studentName,
        admissionNumber: payment.admissionNumber ?? '',
        className: payment.className ?? '',
        parentName: 'Vikas Sharma',
        date: payment.paidAt,
        amountPaid: payment.amount,
        paymentMethod: payment.paymentMethod.name.toUpperCase(),
        transactionRef: payment.referenceNumber ?? '',
        remainingBalance: 23000.0,
        description: payment.notes ?? 'School Fee Payment',
      );

      expect(receipt.receiptNo, equals('REC-2026-00042'));
      expect(receipt.studentName, equals('Rohan Sharma'));
      expect(receipt.admissionNumber, equals('STU-2026-0089'));
      expect(receipt.className, equals('10-A'));
      expect(receipt.parentName, equals('Vikas Sharma'));
      expect(receipt.amountPaid, equals(15000.0));
      expect(receipt.paymentMethod, equals('UPI'));
      expect(receipt.transactionRef, equals('UPI9876543210'));
      expect(receipt.remainingBalance, equals(23000.0));
      expect(receipt.description, equals('Term 1 Tuition Fee Installment'));
    });
  });
}

