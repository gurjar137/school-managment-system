enum SalaryStatus { paid, pending, partial }

class SalaryAllowance {
  final String type; // e.g., HRA, Transport, Bonus, Other
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
  final String type; // e.g., Leave Deduction, Advance, Other
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
  final double basicSalary;
  final List<SalaryAllowance> allowances;
  final List<SalaryDeduction> deductions;

  const SalaryStructure({
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
  });

  // Dynamic Calculation: Total Allowances
  double get totalAllowances {
    return allowances.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Dynamic Calculation: Total Deductions
  double get totalDeductions {
    return deductions.fold(0.0, (sum, item) => sum + item.amount);
  }

  // Dynamic Calculation: Net Salary = Basic + Allowances - Deductions
  double get netSalary => basicSalary + totalAllowances - totalDeductions;

  Map<String, dynamic> toJson() => {
    'basicSalary': basicSalary,
    'allowances': allowances.map((a) => a.toJson()).toList(),
    'deductions': deductions.map((d) => d.toJson()).toList(),
  };

  factory SalaryStructure.fromJson(Map<String, dynamic> json) => SalaryStructure(
    basicSalary: (json['basicSalary'] as num?)?.toDouble() ?? 24000.0,
    allowances: (json['allowances'] as List?)
        ?.map((a) => SalaryAllowance.fromJson(a as Map<String, dynamic>))
        .toList() ??
        const [
          SalaryAllowance(type: 'HRA', amount: 4000.0),
          SalaryAllowance(type: 'Transport', amount: 1000.0),
        ],
    deductions: (json['deductions'] as List?)
        ?.map((d) => SalaryDeduction.fromJson(d as Map<String, dynamic>))
        .toList() ??
        const [
          SalaryDeduction(type: 'PF', amount: 1000.0),
        ],
  );
}

class SalaryPaymentRecord {
  final String paymentId;
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

  const SalaryPaymentRecord({
    required this.paymentId,
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
  });

  double get remainingBalance => (netSalary - amountPaid).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() => {
    'paymentId': paymentId,
    'teacherId': teacherId,
    'staffName': staffName,
    'month': month,
    'netSalary': netSalary,
    'amountPaid': amountPaid,
    'paymentDate': paymentDate?.toIso8601String(),
    'paymentMethod': paymentMethod,
    'referenceNo': referenceNo,
    'status': status.name,
    'notes': notes,
  };

  factory SalaryPaymentRecord.fromJson(Map<String, dynamic> json) => SalaryPaymentRecord(
    paymentId: json['paymentId']?.toString() ?? json['id']?.toString() ?? '',
    teacherId: json['teacherId']?.toString() ?? json['staff_profile_id']?.toString(),
    staffName: json['staffName']?.toString() ?? json['staff_name']?.toString(),
    month: json['month']?.toString() ?? '',
    netSalary: (json['netSalary'] as num?)?.toDouble() ?? (json['net_salary'] as num?)?.toDouble() ?? 0.0,
    amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
    paymentDate: json['paymentDate'] != null
        ? DateTime.tryParse(json['paymentDate'].toString())
        : (json['payment_date'] != null ? DateTime.tryParse(json['payment_date'].toString()) : null),
    paymentMethod: json['paymentMethod']?.toString() ?? json['payment_method']?.toString() ?? 'Bank Transfer',
    referenceNo: json['referenceNo']?.toString() ?? json['reference_no']?.toString() ?? '',
    status: _parseSalaryStatus(json['status']?.toString()),
    notes: json['notes']?.toString() ?? '',
  );

  static SalaryStatus _parseSalaryStatus(String? status) {
    if (status == null) return SalaryStatus.paid;
    final lower = status.toLowerCase();
    if (lower == 'partial') return SalaryStatus.partial;
    if (lower == 'pending') return SalaryStatus.pending;
    return SalaryStatus.paid;
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
  final SalaryStatus status;
  final DateTime? paymentDate;

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
    required this.status,
    this.paymentDate,
  });

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
    'status': status.name,
    'paymentDate': paymentDate?.toIso8601String(),
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
    status: SalaryPaymentRecord._parseSalaryStatus(json['status']?.toString()),
    paymentDate: json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) : null,
  );
}
