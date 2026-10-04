enum FeeFrequency { monthly, quarterly, halfYearly, yearly, oneTime }
enum FeeLedgerStatus { pending, partial, paid, overdue, waived, cancelled }
enum PaymentMethod { online, cash, bankTransfer, upi, cheque, other }
enum PaymentRecordStatus { pending, success, failed, refunded, cancelled }

FeeFrequency parseFeeFrequency(dynamic val) {
  if (val == null) return FeeFrequency.yearly;
  final s = val.toString().toLowerCase().replaceAll('_', '');
  if (s == 'monthly') return FeeFrequency.monthly;
  if (s == 'quarterly') return FeeFrequency.quarterly;
  if (s == 'halfyearly') return FeeFrequency.halfYearly;
  if (s == 'onetime') return FeeFrequency.oneTime;
  return FeeFrequency.yearly;
}

String feeFrequencyToDb(FeeFrequency freq) {
  switch (freq) {
    case FeeFrequency.monthly:
      return 'monthly';
    case FeeFrequency.quarterly:
      return 'quarterly';
    case FeeFrequency.halfYearly:
      return 'half_yearly';
    case FeeFrequency.oneTime:
      return 'one_time';
    case FeeFrequency.yearly:
      return 'yearly';
  }
}

FeeLedgerStatus parseFeeLedgerStatus(dynamic val) {
  if (val == null) return FeeLedgerStatus.pending;
  final s = val.toString().toLowerCase();
  if (s == 'paid') return FeeLedgerStatus.paid;
  if (s == 'partial') return FeeLedgerStatus.partial;
  if (s == 'overdue') return FeeLedgerStatus.overdue;
  if (s == 'waived') return FeeLedgerStatus.waived;
  if (s == 'cancelled') return FeeLedgerStatus.cancelled;
  return FeeLedgerStatus.pending;
}

PaymentMethod parsePaymentMethod(dynamic val) {
  if (val == null) return PaymentMethod.cash;
  final s = val.toString().toLowerCase().replaceAll('_', '');
  if (s == 'cash') return PaymentMethod.cash;
  if (s == 'upi') return PaymentMethod.upi;
  if (s == 'banktransfer') return PaymentMethod.bankTransfer;
  if (s == 'cheque') return PaymentMethod.cheque;
  if (s == 'online' || s == 'card') return PaymentMethod.online;
  return PaymentMethod.other;
}

String paymentMethodToDb(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.cash:
      return 'cash';
    case PaymentMethod.upi:
      return 'upi';
    case PaymentMethod.bankTransfer:
      return 'bank_transfer';
    case PaymentMethod.cheque:
      return 'cheque';
    case PaymentMethod.online:
      return 'card';
    case PaymentMethod.other:
      return 'other';
  }
}

class FeeComponentModel {
  final String id;
  final String feeStructureId;
  final String schoolId;
  final String name;
  final double amount;
  final FeeFrequency frequency;
  final int? dueDay;
  final String? description;

  const FeeComponentModel({
    required this.id,
    required this.feeStructureId,
    required this.schoolId,
    required this.name,
    required this.amount,
    required this.frequency,
    this.dueDay = 10,
    this.description,
  });

  factory FeeComponentModel.fromJson(Map<String, dynamic> json) {
    return FeeComponentModel(
      id: (json['id'] ?? '').toString(),
      feeStructureId: (json['fee_structure_id'] ?? json['feeStructureId'] ?? '').toString(),
      schoolId: (json['school_id'] ?? json['schoolId'] ?? '').toString(),
      name: (json['name'] ?? 'Fee Component').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      frequency: parseFeeFrequency(json['frequency']),
      dueDay: (json['due_day'] as num?)?.toInt() ?? 10,
      description: json['description']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fee_structure_id': feeStructureId,
      'school_id': schoolId,
      'name': name,
      'amount': amount,
      'frequency': feeFrequencyToDb(frequency),
      'due_day': dueDay,
      if (description != null) 'description': description,
    };
  }
}

class FeeStructureModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String className;
  final String name;
  final String? description;
  final List<FeeComponentModel> components;

  const FeeStructureModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    this.classId = '',
    this.className = '',
    required this.name,
    this.description,
    required this.components,
  });

  double get totalBaseAmount {
    return components.fold(0.0, (sum, c) => sum + c.amount);
  }

  factory FeeStructureModel.fromJson(Map<String, dynamic> json, [List<FeeComponentModel>? components]) {
    final comps = components ??
        ((json['fee_components'] as List?)
            ?.map((c) => FeeComponentModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
            []);
    return FeeStructureModel(
      id: (json['id'] ?? '').toString(),
      schoolId: (json['school_id'] ?? json['schoolId'] ?? '').toString(),
      academicYearId: (json['academic_year_id'] ?? json['academicYearId'] ?? '').toString(),
      classId: (json['class_id'] ?? json['classId'] ?? '').toString(),
      className: (json['class_name'] ?? json['className'] ?? '').toString(),
      name: (json['name'] ?? 'Fee Structure').toString(),
      description: json['description']?.toString(),
      components: comps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'class_name': className,
      'name': name,
      if (description != null) 'description': description,
    };
  }
}

class StudentFeeAssignmentModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String studentId;
  final String feeStructureId;
  final double discountAmount;
  final double scholarshipAmount;
  final double adjustmentAmount;
  final String? discountReason;

  const StudentFeeAssignmentModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.studentId,
    required this.feeStructureId,
    this.discountAmount = 0.0,
    this.scholarshipAmount = 0.0,
    this.adjustmentAmount = 0.0,
    this.discountReason,
  });

  factory StudentFeeAssignmentModel.fromJson(Map<String, dynamic> json) {
    return StudentFeeAssignmentModel(
      id: (json['id'] ?? '').toString(),
      schoolId: (json['school_id'] ?? json['schoolId'] ?? '').toString(),
      academicYearId: (json['academic_year_id'] ?? json['academicYearId'] ?? '').toString(),
      studentId: (json['student_id'] ?? json['studentId'] ?? '').toString(),
      feeStructureId: (json['fee_structure_id'] ?? json['feeStructureId'] ?? '').toString(),
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      scholarshipAmount: (json['scholarship_amount'] as num?)?.toDouble() ?? 0.0,
      adjustmentAmount: (json['adjustment_amount'] as num?)?.toDouble() ?? 0.0,
      discountReason: json['discount_reason']?.toString(),
    );
  }
}

class FeeLedgerModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String studentId;
  final String studentName;
  final String feeComponentId;
  final String componentName;
  final String billingPeriod; // e.g. '2026-04'
  final DateTime dueDate;
  final double amount;
  final double discountAmount;
  final double adjustmentAmount;
  final double paidAmount;
  final FeeLedgerStatus status;

  const FeeLedgerModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.studentId,
    required this.studentName,
    required this.feeComponentId,
    required this.componentName,
    required this.billingPeriod,
    required this.dueDate,
    required this.amount,
    this.discountAmount = 0.0,
    this.adjustmentAmount = 0.0,
    this.paidAmount = 0.0,
    required this.status,
  });

  double get netAmount => (amount - discountAmount + adjustmentAmount).clamp(0.0, double.infinity);
  double get balanceAmount => (netAmount - paidAmount).clamp(0.0, double.infinity);

  FeeLedgerStatus get computedStatus {
    if (balanceAmount == 0 && netAmount > 0) return FeeLedgerStatus.paid;
    if (paidAmount > 0) return FeeLedgerStatus.partial;
    if (DateTime.now().isAfter(dueDate)) return FeeLedgerStatus.overdue;
    return FeeLedgerStatus.pending;
  }

  factory FeeLedgerModel.fromJson(Map<String, dynamic> json, {String defaultStudentName = ''}) {
    DateTime due = DateTime.now();
    if (json['due_date'] != null) {
      due = DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now();
    }
    return FeeLedgerModel(
      id: (json['id'] ?? '').toString(),
      schoolId: (json['school_id'] ?? json['schoolId'] ?? '').toString(),
      academicYearId: (json['academic_year_id'] ?? json['academicYearId'] ?? '').toString(),
      studentId: (json['student_id'] ?? json['studentId'] ?? '').toString(),
      studentName: (json['student_name'] ?? json['students']?['name'] ?? defaultStudentName).toString(),
      feeComponentId: (json['fee_component_id'] ?? json['feeComponentId'] ?? '').toString(),
      componentName: (json['component_name'] ?? json['componentName'] ?? 'Fee').toString(),
      billingPeriod: (json['billing_period'] ?? json['billingPeriod'] ?? '').toString(),
      dueDate: due,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      adjustmentAmount: (json['adjustment_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: parseFeeLedgerStatus(json['status']),
    );
  }
}

class StudentFeeAccountModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String studentId;
  final double grossFee;
  final double discountAmount;
  final double waiverAmount;
  final DateTime? dueDate;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Correlated student and payment details
  final String studentName;
  final String admissionNumber;
  final String className;
  final String sectionName;
  final double totalPaid;

  const StudentFeeAccountModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.studentId,
    required this.grossFee,
    this.discountAmount = 0.0,
    this.waiverAmount = 0.0,
    this.dueDate,
    this.notes,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.studentName = '',
    this.admissionNumber = '',
    this.className = '',
    this.sectionName = '',
    this.totalPaid = 0.0,
  });

  double get netFee => (grossFee - discountAmount - waiverAmount).clamp(0.0, double.infinity);
  double get currentDue => (netFee - totalPaid).clamp(0.0, double.infinity);

  /// Exact database status: 'paid', 'partially_paid', 'due', 'overdue'
  String get dbStatus {
    if (currentDue <= 0) return 'paid';
    if (totalPaid > 0) return 'partially_paid';
    if (dueDate != null && DateTime.now().isAfter(dueDate!)) return 'overdue';
    return 'due';
  }

  /// User-facing display status: 'Paid', 'Partially Paid', 'Due', 'Overdue'
  String get displayStatus {
    switch (dbStatus) {
      case 'paid':
        return 'Paid';
      case 'partially_paid':
        return 'Partially Paid';
      case 'overdue':
        return 'Overdue';
      case 'due':
      default:
        return 'Due';
    }
  }

  /// UI Badge label: 'PAID', 'PARTIALLY PAID', 'OVERDUE', 'DUE'
  String get computedStatus {
    switch (dbStatus) {
      case 'paid':
        return 'PAID';
      case 'partially_paid':
        return 'PARTIALLY PAID';
      case 'overdue':
        return 'OVERDUE';
      case 'due':
      default:
        return 'DUE';
    }
  }

  factory StudentFeeAccountModel.fromJson(
    Map<String, dynamic> json, {
    double paidSum = 0.0,
    Map<String, dynamic>? student,
  }) {
    DateTime created = DateTime.now();
    if (json['created_at'] != null) {
      created = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }
    DateTime? due;
    if (json['due_date'] != null) {
      due = DateTime.tryParse(json['due_date'].toString());
    }
    DateTime? updated;
    if (json['updated_at'] != null) {
      updated = DateTime.tryParse(json['updated_at'].toString());
    }

    final rawStatus = (json['status'] ?? 'due').toString().trim().toLowerCase();
    String normalizedDbStatus = 'due';
    if (rawStatus == 'paid') {
      normalizedDbStatus = 'paid';
    } else if (rawStatus == 'partially_paid' || rawStatus == 'partial' || rawStatus == 'partially paid') {
      normalizedDbStatus = 'partially_paid';
    } else if (rawStatus == 'overdue') {
      normalizedDbStatus = 'overdue';
    } else {
      normalizedDbStatus = 'due';
    }

    String sName = '';
    String adm = '';
    String cName = '';
    String sec = '';

    final stuObj = student ?? (json['students'] is Map ? json['students'] as Map<String, dynamic> : null);
    if (stuObj != null) {
      final fName = stuObj['first_name']?.toString() ?? '';
      final mName = stuObj['middle_name']?.toString() ?? '';
      final lName = stuObj['last_name']?.toString() ?? '';
      final parts = [fName, mName, lName].where((p) => p.trim().isNotEmpty).toList();
      sName = parts.isNotEmpty ? parts.join(' ') : (stuObj['name']?.toString() ?? '');
      adm = (stuObj['admission_number'] ?? '').toString();
      cName = (stuObj['class_name'] ?? '').toString();
      sec = (stuObj['section_name'] ?? '').toString();
    }

    return StudentFeeAccountModel(
      id: (json['id'] ?? '').toString(),
      schoolId: (json['school_id'] ?? '').toString(),
      academicYearId: (json['academic_year_id'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      grossFee: (json['gross_fee'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      waiverAmount: (json['waiver_amount'] as num?)?.toDouble() ?? 0.0,
      dueDate: due,
      notes: json['notes']?.toString(),
      status: normalizedDbStatus,
      createdAt: created,
      updatedAt: updated,
      studentName: sName,
      admissionNumber: adm,
      className: cName,
      sectionName: sec,
      totalPaid: paidSum,
    );
  }

  StudentFeeAccountModel copyWith({
    double? totalPaid,
    String? status,
  }) {
    return StudentFeeAccountModel(
      id: id,
      schoolId: schoolId,
      academicYearId: academicYearId,
      studentId: studentId,
      grossFee: grossFee,
      discountAmount: discountAmount,
      waiverAmount: waiverAmount,
      dueDate: dueDate,
      notes: notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      studentName: studentName,
      admissionNumber: admissionNumber,
      className: className,
      sectionName: sectionName,
      totalPaid: totalPaid ?? this.totalPaid,
    );
  }
}

class PaymentRecordModel {
  final String id;
  final String schoolId;
  final String? academicYearId;
  final String studentId;
  final String? feeAccountId;
  final String studentName;
  final String? admissionNumber;
  final String? className;
  final String? parentId;
  final String receiptNumber; // e.g. REC-2026-000001
  final double amount;
  final PaymentMethod paymentMethod;
  final PaymentRecordStatus paymentStatus;
  final String? referenceNumber;
  final String? transactionReference;
  final DateTime paidAt;
  final String? recordedBy;
  final String? notes;

  const PaymentRecordModel({
    required this.id,
    required this.schoolId,
    this.academicYearId,
    required this.studentId,
    this.feeAccountId,
    required this.studentName,
    this.admissionNumber,
    this.className,
    this.parentId,
    required this.receiptNumber,
    required this.amount,
    required this.paymentMethod,
    required this.paymentStatus,
    this.referenceNumber,
    this.transactionReference,
    required this.paidAt,
    this.recordedBy,
    this.notes,
  });

  factory PaymentRecordModel.fromJson(Map<String, dynamic> json, {String defaultStudentName = ''}) {
    DateTime date = DateTime.now();
    final dStr = json['payment_date'] ?? json['paid_at'] ?? json['created_at'];
    if (dStr != null) {
      date = DateTime.tryParse(dStr.toString()) ?? DateTime.now();
    }

    String sName = defaultStudentName;
    String? adm;
    String? cName;

    if (json['students'] is Map) {
      final stu = json['students'] as Map<String, dynamic>;
      final fName = stu['first_name']?.toString() ?? '';
      final mName = stu['middle_name']?.toString() ?? '';
      final lName = stu['last_name']?.toString() ?? '';
      final parts = [fName, mName, lName].where((p) => p.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        sName = parts.join(' ');
      } else if (stu['name'] != null) {
        sName = stu['name'].toString();
      }
      adm = stu['admission_number']?.toString();
      cName = stu['class_name']?.toString();
    } else if (json['student_name'] != null) {
      sName = json['student_name'].toString();
    }

    final refNo = (json['reference_number'] ?? json['transaction_reference'] ?? json['referenceNumber'])?.toString();

    return PaymentRecordModel(
      id: (json['id'] ?? '').toString(),
      schoolId: (json['school_id'] ?? json['schoolId'] ?? '').toString(),
      academicYearId: json['academic_year_id']?.toString(),
      studentId: (json['student_id'] ?? json['studentId'] ?? '').toString(),
      feeAccountId: json['fee_account_id']?.toString(),
      studentName: sName,
      admissionNumber: adm ?? json['admission_number']?.toString(),
      className: cName ?? json['class_name']?.toString(),
      parentId: json['parent_id']?.toString(),
      receiptNumber: (json['receipt_number'] ?? json['receiptNumber'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: parsePaymentMethod(json['payment_method'] ?? json['paymentMethod']),
      paymentStatus: PaymentRecordStatus.success,
      referenceNumber: refNo,
      transactionReference: refNo,
      paidAt: date,
      recordedBy: json['created_by']?.toString() ?? json['recordedBy']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class FeeSummaryModel {
  final String studentId;
  final String studentName;
  final double totalDue;
  final double totalPaid;
  final double totalOutstanding;
  final double overdueAmount;

  const FeeSummaryModel({
    required this.studentId,
    required this.studentName,
    required this.totalDue,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.overdueAmount,
  });

  factory FeeSummaryModel.fromJson(Map<String, dynamic> json) {
    return FeeSummaryModel(
      studentId: (json['student_id'] ?? json['studentId'] ?? '').toString(),
      studentName: (json['student_name'] ?? json['studentName'] ?? '').toString(),
      totalDue: (json['total_due'] as num?)?.toDouble() ?? (json['totalDue'] as num?)?.toDouble() ?? 0.0,
      totalPaid: (json['total_paid'] as num?)?.toDouble() ?? (json['totalPaid'] as num?)?.toDouble() ?? 0.0,
      totalOutstanding: (json['total_outstanding'] as num?)?.toDouble() ?? (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
      overdueAmount: (json['overdue_amount'] as num?)?.toDouble() ?? (json['overdueAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FeeReceiptModel {
  final String receiptNo;
  final String studentName;
  final String admissionNumber;
  final String className;
  final String parentName;
  final DateTime date;
  final double amountPaid;
  final String paymentMethod;
  final String transactionRef;
  final double previousBalance;
  final double remainingBalance;
  final String description;

  const FeeReceiptModel({
    required this.receiptNo,
    required this.studentName,
    this.admissionNumber = '',
    required this.className,
    this.parentName = '',
    required this.date,
    required this.amountPaid,
    required this.paymentMethod,
    this.transactionRef = '',
    this.previousBalance = 0.0,
    this.remainingBalance = 0.0,
    required this.description,
  });

  factory FeeReceiptModel.fromJson(Map<String, dynamic> json) {
    DateTime d = DateTime.now();
    if (json['payment_date'] != null || json['date'] != null) {
      d = DateTime.tryParse((json['payment_date'] ?? json['date']).toString()) ?? DateTime.now();
    }
    return FeeReceiptModel(
      receiptNo: (json['receipt_number'] ?? json['receiptNo'] ?? '').toString(),
      studentName: (json['student_name'] ?? json['studentName'] ?? '').toString(),
      admissionNumber: (json['admission_number'] ?? json['admissionNumber'] ?? '').toString(),
      className: (json['class_name'] ?? json['className'] ?? '').toString(),
      parentName: (json['parent_name'] ?? json['parentName'] ?? '').toString(),
      date: d,
      amountPaid: (json['amount'] as num?)?.toDouble() ?? (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (json['payment_method'] ?? json['paymentMethod'] ?? 'Cash').toString(),
      transactionRef: (json['transaction_reference'] ?? json['transactionRef'] ?? '').toString(),
      previousBalance: (json['previous_balance'] as num?)?.toDouble() ?? 0.0,
      remainingBalance: (json['pending_fee'] as num?)?.toDouble() ?? (json['remainingBalance'] as num?)?.toDouble() ?? 0.0,
      description: (json['notes'] ?? json['description'] ?? 'School Fee Payment').toString(),
    );
  }
}

typedef FeePayment = PaymentRecordModel;

