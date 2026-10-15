enum SalaryStatus {
  paid,
  pending,
  partial,
  notConfigured,
  overdue,
}

class SalaryAllowance {
  final String type; // e.g., HRA, Transport, Dearness, Bonus, Medical, Special, Other
  final double amount;

  const SalaryAllowance({required this.type, required this.amount});

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
  };

  factory SalaryAllowance.fromJson(Map<String, dynamic> json) => SalaryAllowance(
    type: json['type']?.toString() ?? 'Allowance',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  );
}

class SalaryDeduction {
  final String type; // e.g., PF, Tax / TDS, Professional Tax, Leave Deduction, Advance, Other
  final double amount;

  const SalaryDeduction({required this.type, required this.amount});

  Map<String, dynamic> toJson() => {
    'type': type,
    'amount': amount,
  };

  factory SalaryDeduction.fromJson(Map<String, dynamic> json) => SalaryDeduction(
    type: json['type']?.toString() ?? 'Deduction',
    amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
  );
}

class SalaryStructure {
  final String id;
  final String schoolId;
  final String staffProfileId;
  final String staffName;
  final String salaryType; // "Monthly", "Contractual", "Hourly"
  final double basicSalary;
  final List<SalaryAllowance> allowances;
  final List<SalaryDeduction> deductions;
  final DateTime effectiveFrom;
  final String paymentSchedule; // "Monthly (1st)", "Monthly (5th)", etc.
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SalaryStructure({
    this.id = '',
    this.schoolId = '',
    this.staffProfileId = '',
    this.staffName = '',
    this.salaryType = 'Monthly',
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    DateTime? effectiveFrom,
    this.paymentSchedule = 'Monthly (1st)',
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  }) : effectiveFrom = effectiveFrom ?? DateTime(2026, 1, 1);

  // Dynamic Calculation: Total Allowances
  double get totalAllowances {
    return allowances.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Dynamic Calculation: Total Deductions
  double get totalDeductions {
    return deductions.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Dynamic Calculation: Net Salary = Basic + Allowances - Deductions
  double get netSalary => (basicSalary + totalAllowances - totalDeductions).clamp(0.0, double.infinity);

  // Gross Salary = Basic + Allowances
  double get grossSalary => basicSalary + totalAllowances;

  SalaryStructure copyWith({
    String? id,
    String? schoolId,
    String? staffProfileId,
    String? staffName,
    String? salaryType,
    double? basicSalary,
    List<SalaryAllowance>? allowances,
    List<SalaryDeduction>? deductions,
    DateTime? effectiveFrom,
    String? paymentSchedule,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SalaryStructure(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      staffProfileId: staffProfileId ?? this.staffProfileId,
      staffName: staffName ?? this.staffName,
      salaryType: salaryType ?? this.salaryType,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      paymentSchedule: paymentSchedule ?? this.paymentSchedule,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson({String? schoolId}) => {
    'id': id.isNotEmpty ? id : 'struct_${staffProfileId}_${effectiveFrom.millisecondsSinceEpoch}',
    'school_id': schoolId ?? this.schoolId,
    'staff_profile_id': staffProfileId,
    'staff_name': staffName,
    'salary_type': salaryType,
    'basic_salary': basicSalary,
    'basicSalary': basicSalary, // compatibility
    'allowances': allowances.map((a) => a.toJson()).toList(),
    'deductions': deductions.map((d) => d.toJson()).toList(),
    'net_salary': netSalary,
    'effective_from': effectiveFrom.toIso8601String().substring(0, 10),
    'payment_schedule': paymentSchedule,
    'is_active': isActive,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
  };

  factory SalaryStructure.fromJson(Map<String, dynamic> json) => SalaryStructure(
    id: json['id']?.toString() ?? '',
    schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
    staffProfileId: json['staff_profile_id']?.toString() ?? json['staffProfileId']?.toString() ?? '',
    staffName: json['staff_name']?.toString() ?? json['staffName']?.toString() ?? '',
    salaryType: json['salary_type']?.toString() ?? json['salaryType']?.toString() ?? 'Monthly',
    basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
    allowances: (json['allowances'] as List?)
        ?.map((a) => SalaryAllowance.fromJson(a as Map<String, dynamic>))
        .toList() ??
        const [],
    deductions: (json['deductions'] as List?)
        ?.map((d) => SalaryDeduction.fromJson(d as Map<String, dynamic>))
        .toList() ??
        const [],
    effectiveFrom: json['effective_from'] != null
        ? DateTime.tryParse(json['effective_from'].toString())
        : (json['effectiveFrom'] != null ? DateTime.tryParse(json['effectiveFrom'].toString()) : null),
    paymentSchedule: json['payment_schedule']?.toString() ?? json['paymentSchedule']?.toString() ?? 'Monthly (1st)',
    isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
  );
}

class MonthlyPayrollModel {
  final String id;
  final String schoolId;
  final String staffProfileId;
  final String staffName;
  final String employeeId;
  final String designation;
  final String department;
  final String monthYear; // e.g. "August 2026"
  final double basicSalary;
  final List<SalaryAllowance> allowances;
  final List<SalaryDeduction> deductions;
  final double grossSalary;
  final double netPayable;
  final double amountPaid;
  final double remainingBalance;
  final SalaryStatus status;
  final DateTime generatedAt;
  final DateTime? finalizedAt;
  final List<SalaryPaymentRecord> payments;

  const MonthlyPayrollModel({
    required this.id,
    required this.schoolId,
    required this.staffProfileId,
    required this.staffName,
    required this.employeeId,
    required this.designation,
    this.department = 'Academic',
    required this.monthYear,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.grossSalary,
    required this.netPayable,
    this.amountPaid = 0.0,
    double? remainingBalance,
    this.status = SalaryStatus.pending,
    required this.generatedAt,
    this.finalizedAt,
    this.payments = const [],
  }) : remainingBalance = remainingBalance ?? ((netPayable - amountPaid > 0) ? (netPayable - amountPaid) : 0.0);

  MonthlyPayrollModel copyWith({
    String? id,
    String? schoolId,
    String? staffProfileId,
    String? staffName,
    String? employeeId,
    String? designation,
    String? department,
    String? monthYear,
    double? basicSalary,
    List<SalaryAllowance>? allowances,
    List<SalaryDeduction>? deductions,
    double? grossSalary,
    double? netPayable,
    double? amountPaid,
    double? remainingBalance,
    SalaryStatus? status,
    DateTime? generatedAt,
    DateTime? finalizedAt,
    List<SalaryPaymentRecord>? payments,
  }) {
    return MonthlyPayrollModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      staffProfileId: staffProfileId ?? this.staffProfileId,
      staffName: staffName ?? this.staffName,
      employeeId: employeeId ?? this.employeeId,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      monthYear: monthYear ?? this.monthYear,
      basicSalary: basicSalary ?? this.basicSalary,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      grossSalary: grossSalary ?? this.grossSalary,
      netPayable: netPayable ?? this.netPayable,
      amountPaid: amountPaid ?? this.amountPaid,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      status: status ?? this.status,
      generatedAt: generatedAt ?? this.generatedAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toJson({String? schoolId}) => {
    'id': id,
    'school_id': schoolId ?? this.schoolId,
    'staff_profile_id': staffProfileId,
    'staff_name': staffName,
    'employee_id': employeeId,
    'designation': designation,
    'department': department,
    'month_year': monthYear,
    'basic_salary': basicSalary,
    'allowances': allowances.map((a) => a.toJson()).toList(),
    'deductions': deductions.map((d) => d.toJson()).toList(),
    'gross_salary': grossSalary,
    'net_payable': netPayable,
    'amount_paid': amountPaid,
    'remaining_balance': remainingBalance,
    'status': status.name,
    'generated_at': generatedAt.toIso8601String(),
    'finalized_at': finalizedAt?.toIso8601String(),
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  factory MonthlyPayrollModel.fromJson(Map<String, dynamic> json) {
    final net = (json['net_payable'] as num?)?.toDouble() ?? (json['netPayable'] as num?)?.toDouble() ?? 0.0;
    final paid = (json['amount_paid'] as num?)?.toDouble() ?? (json['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final remaining = (net - paid).clamp(0.0, double.infinity);

    return MonthlyPayrollModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
      staffProfileId: json['staff_profile_id']?.toString() ?? json['staffProfileId']?.toString() ?? '',
      staffName: json['staff_name']?.toString() ?? json['staffName']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString() ?? '',
      designation: json['designation']?.toString() ?? 'Faculty Member',
      department: json['department']?.toString() ?? 'Academic',
      monthYear: json['month_year']?.toString() ?? json['monthYear']?.toString() ?? '',
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
      allowances: (json['allowances'] as List?)
          ?.map((a) => SalaryAllowance.fromJson(a as Map<String, dynamic>))
          .toList() ??
          const [],
      deductions: (json['deductions'] as List?)
          ?.map((d) => SalaryDeduction.fromJson(d as Map<String, dynamic>))
          .toList() ??
          const [],
      grossSalary: (json['gross_salary'] as num?)?.toDouble() ?? (json['grossSalary'] as num?)?.toDouble() ?? 0.0,
      netPayable: net,
      amountPaid: paid,
      remainingBalance: remaining,
      status: SalaryPaymentRecord.parseSalaryStatus(json['status']?.toString()),
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      finalizedAt: json['finalized_at'] != null ? DateTime.tryParse(json['finalized_at'].toString()) : null,
      payments: (json['payments'] as List?)
          ?.map((p) => SalaryPaymentRecord.fromJson(p as Map<String, dynamic>))
          .toList() ??
          const [],
    );
  }
}

class SalaryPaymentRecord {
  final String paymentId;
  final String? payrollId;
  final String schoolId;
  final String? teacherId;
  final String? staffName;
  final String month; // e.g. "August 2026"
  final double netSalary;
  final double amountPaid;
  final DateTime? paymentDate;
  final String paymentMethod;
  final String referenceNo;
  final SalaryStatus status;
  final String notes;
  final String recordedBy;
  final DateTime? createdAt;

  const SalaryPaymentRecord({
    required this.paymentId,
    this.payrollId,
    this.schoolId = '',
    this.teacherId,
    this.staffName,
    required this.month,
    required this.netSalary,
    required this.amountPaid,
    this.paymentDate,
    required this.paymentMethod,
    required this.referenceNo,
    required this.status,
    required this.notes,
    this.recordedBy = 'Administrator',
    this.createdAt,
  });

  double get remainingBalance => (netSalary - amountPaid).clamp(0.0, double.infinity);

  SalaryPaymentRecord copyWith({
    String? paymentId,
    String? payrollId,
    String? schoolId,
    String? teacherId,
    String? staffName,
    String? month,
    double? netSalary,
    double? amountPaid,
    DateTime? paymentDate,
    String? paymentMethod,
    String? referenceNo,
    SalaryStatus? status,
    String? notes,
    String? recordedBy,
    DateTime? createdAt,
  }) {
    return SalaryPaymentRecord(
      paymentId: paymentId ?? this.paymentId,
      payrollId: payrollId ?? this.payrollId,
      schoolId: schoolId ?? this.schoolId,
      teacherId: teacherId ?? this.teacherId,
      staffName: staffName ?? this.staffName,
      month: month ?? this.month,
      netSalary: netSalary ?? this.netSalary,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNo: referenceNo ?? this.referenceNo,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      recordedBy: recordedBy ?? this.recordedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson({String? schoolId}) => {
    'id': paymentId,
    'paymentId': paymentId,
    'payroll_id': payrollId,
    'payrollId': payrollId,
    'school_id': schoolId ?? this.schoolId,
    'staff_profile_id': teacherId,
    'teacherId': teacherId,
    'staff_name': staffName,
    'staffName': staffName,
    'month': month,
    'net_salary': netSalary,
    'netSalary': netSalary,
    'amount_paid': amountPaid,
    'amountPaid': amountPaid,
    'payment_date': paymentDate?.toIso8601String().substring(0, 10),
    'paymentDate': paymentDate?.toIso8601String(),
    'payment_method': paymentMethod,
    'paymentMethod': paymentMethod,
    'reference_no': referenceNo,
    'referenceNo': referenceNo,
    'status': status.name,
    'notes': notes,
    'recorded_by': recordedBy,
    'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
  };

  factory SalaryPaymentRecord.fromJson(Map<String, dynamic> json) => SalaryPaymentRecord(
    paymentId: json['id']?.toString() ?? json['paymentId']?.toString() ?? '',
    payrollId: json['payroll_id']?.toString() ?? json['payrollId']?.toString(),
    schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
    teacherId: json['staff_profile_id']?.toString() ?? json['teacherId']?.toString(),
    staffName: json['staff_name']?.toString() ?? json['staffName']?.toString(),
    month: json['month']?.toString() ?? '',
    netSalary: (json['net_salary'] as num?)?.toDouble() ?? (json['netSalary'] as num?)?.toDouble() ?? 0.0,
    amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
    paymentDate: json['payment_date'] != null
        ? DateTime.tryParse(json['payment_date'].toString())
        : (json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) : null),
    paymentMethod: json['payment_method']?.toString() ?? json['paymentMethod']?.toString() ?? 'Bank Transfer',
    referenceNo: json['reference_no']?.toString() ?? json['referenceNo']?.toString() ?? '',
    status: parseSalaryStatus(json['status']?.toString()),
    notes: json['notes']?.toString() ?? '',
    recordedBy: json['recorded_by']?.toString() ?? 'Administrator',
    createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
  );

  static SalaryStatus parseSalaryStatus(String? status) {
    if (status == null) return SalaryStatus.pending;
    final lower = status.toLowerCase();
    if (lower == 'paid') return SalaryStatus.paid;
    if (lower == 'partial' || lower == 'partially paid' || lower == 'partially_paid') return SalaryStatus.partial;
    if (lower == 'notconfigured' || lower == 'not_configured' || lower == 'unconfigured') return SalaryStatus.notConfigured;
    if (lower == 'overdue') return SalaryStatus.overdue;
    return SalaryStatus.pending;
  }
}

class SalarySlipModel {
  final String slipNo;
  final String month;
  final String teacherName;
  final String employeeId;
  final String designation;
  final double basicSalary;
  final List<SalaryAllowance> allowances;
  final List<SalaryDeduction> deductions;
  final double netSalary;
  final double amountPaid;
  final double remainingBalance;
  final SalaryStatus status;
  final DateTime? paymentDate;
  final String paymentMethod;
  final String referenceNo;
  final String schoolName;

  const SalarySlipModel({
    required this.slipNo,
    required this.month,
    required this.teacherName,
    required this.employeeId,
    required this.designation,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    required this.netSalary,
    this.amountPaid = 0.0,
    double? remainingBalance,
    required this.status,
    this.paymentDate,
    this.paymentMethod = 'Bank Transfer',
    this.referenceNo = '',
    this.schoolName = '',
  }) : remainingBalance = remainingBalance ?? ((netSalary - amountPaid > 0) ? (netSalary - amountPaid) : 0.0);

  Map<String, dynamic> toJson() => {
    'slipNo': slipNo,
    'month': month,
    'teacherName': teacherName,
    'employeeId': employeeId,
    'designation': designation,
    'basicSalary': basicSalary,
    'allowances': allowances.map((a) => a.toJson()).toList(),
    'deductions': deductions.map((d) => d.toJson()).toList(),
    'netSalary': netSalary,
    'amountPaid': amountPaid,
    'remainingBalance': remainingBalance,
    'status': status.name,
    'paymentDate': paymentDate?.toIso8601String(),
    'paymentMethod': paymentMethod,
    'referenceNo': referenceNo,
    'schoolName': schoolName,
  };

  factory SalarySlipModel.fromJson(Map<String, dynamic> json) => SalarySlipModel(
    slipNo: json['slipNo']?.toString() ?? '',
    month: json['month']?.toString() ?? '',
    teacherName: json['teacherName']?.toString() ?? '',
    employeeId: json['employeeId']?.toString() ?? '',
    designation: json['designation']?.toString() ?? '',
    basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 0.0,
    allowances: (json['allowances'] as List?)
        ?.map((a) => SalaryAllowance.fromJson(a as Map<String, dynamic>))
        .toList() ??
        const [],
    deductions: (json['deductions'] as List?)
        ?.map((d) => SalaryDeduction.fromJson(d as Map<String, dynamic>))
        .toList() ??
        const [],
    netSalary: (json['netSalary'] as num?)?.toDouble() ?? 0.0,
    amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
    remainingBalance: (json['remainingBalance'] as num?)?.toDouble() ?? 0.0,
    status: SalaryPaymentRecord.parseSalaryStatus(json['status']?.toString()),
    paymentDate: json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) : null,
    paymentMethod: json['paymentMethod']?.toString() ?? 'Bank Transfer',
    referenceNo: json['referenceNo']?.toString() ?? '',
    schoolName: json['schoolName']?.toString() ?? '',
  );
}
