import 'academic_models.dart';
import 'user_model.dart';

enum AttendanceStatus { present, absent, late, notMarked }
enum PaymentStatus { paid, pending, partial, overdue }

class StudentModel {
  final String id;
  final String name;
  final String firstName;
  final String middleName;
  final String lastName;
  final String rollNumber;
  final String admissionNumber;
  final String className;
  final String section;
  final String avatarUrl;
  final String studentPhoto;
  final double attendancePercentage;
  final AttendanceStatus todayAttendance;
  
  // Personal Info
  final String dateOfBirth;
  final String gender;

  // Parent & Contact Info
  final String fatherName;
  final String fatherMobile;
  final String motherName;
  final String motherMobile;
  final String guardianName;
  final String emergencyContact;
  final String parentEmail;

  // Address
  final String address;
  final String city;
  final String state;
  final String pinCode;

  // Medical & Important Notes
  final String bloodGroup;
  final String medicalNotes;
  final String importantNotes;

  // Multi-tenant & Academic Hierarchy Mapping
  final String schoolId;
  final String academicYearId;
  final String classId;
  final String sectionId;
  final String studentCode;
  final String parentAccessCode;
  final AccountStatus status;

  // Fee Details
  final double totalFee;
  final double paidFee;
  final double pendingFee;
  final PaymentStatus feeStatus;
  final List<PaymentReceiptModel> paymentHistory;

  factory StudentModel({
    required String id,
    required String name,
    String firstName = '',
    String middleName = '',
    String lastName = '',
    String rollNumber = '',
    required String admissionNumber,
    String className = '',
    String section = '',
    String avatarUrl = '',
    String studentPhoto = '',
    double attendancePercentage = 0.0,
    AttendanceStatus todayAttendance = AttendanceStatus.present,
    String dateOfBirth = '',
    String gender = '',
    String fatherName = '',
    String fatherMobile = '',
    String motherName = '',
    String motherMobile = '',
    String guardianName = '',
    String emergencyContact = '',
    String parentEmail = '',
    String address = '',
    String city = '',
    String state = '',
    String pinCode = '',
    String bloodGroup = '',
    String medicalNotes = '',
    String importantNotes = '',
    String schoolId = '',
    String academicYearId = '',
    String classId = 'cls_8',
    String sectionId = 'sec_8_a',
    String studentCode = 'SCH001-STU-0001',
    String parentAccessCode = '',
    AccountStatus status = AccountStatus.active,
    double totalFee = 0.0,
    double paidFee = 0.0,
    double pendingFee = 0.0,
    PaymentStatus feeStatus = PaymentStatus.pending,
    List<PaymentReceiptModel> paymentHistory = const [],
  }) {
    String fName = firstName;
    String mName = middleName;
    String lName = lastName;
    String resolvedName = name;

    if (resolvedName.isNotEmpty && fName.isEmpty && lName.isEmpty) {
      final parts = resolvedName.trim().split(RegExp(r'\s+'));
      if (parts.length == 1) {
        fName = parts[0];
      } else if (parts.length == 2) {
        fName = parts[0];
        lName = parts[1];
      } else if (parts.length > 2) {
        fName = parts[0];
        mName = parts.sublist(1, parts.length - 1).join(' ');
        lName = parts.last;
      }
    } else if (resolvedName.isEmpty) {
      resolvedName = [fName, mName, lName].where((s) => s.trim().isNotEmpty).join(' ');
    }

    return StudentModel._raw(
      id: id,
      name: resolvedName.isNotEmpty ? resolvedName : 'Student',
      firstName: fName,
      middleName: mName,
      lastName: lName,
      rollNumber: rollNumber,
      admissionNumber: admissionNumber,
      className: className,
      section: section,
      avatarUrl: avatarUrl,
      studentPhoto: studentPhoto.isNotEmpty ? studentPhoto : avatarUrl,
      attendancePercentage: attendancePercentage,
      todayAttendance: todayAttendance,
      dateOfBirth: dateOfBirth,
      gender: gender,
      fatherName: fatherName,
      fatherMobile: fatherMobile,
      motherName: motherName,
      motherMobile: motherMobile,
      guardianName: guardianName,
      emergencyContact: emergencyContact,
      parentEmail: parentEmail,
      address: address,
      city: city,
      state: state,
      pinCode: pinCode,
      bloodGroup: bloodGroup,
      medicalNotes: medicalNotes,
      importantNotes: importantNotes,
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      studentCode: studentCode,
      parentAccessCode: parentAccessCode,
      status: status,
      totalFee: totalFee,
      paidFee: paidFee,
      pendingFee: pendingFee,
      feeStatus: feeStatus,
      paymentHistory: paymentHistory,
    );
  }

  const StudentModel._raw({
    required this.id,
    required this.name,
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.rollNumber = '',
    required this.admissionNumber,
    this.className = '',
    this.section = '',
    this.avatarUrl = '',
    this.studentPhoto = '',
    this.attendancePercentage = 0.0,
    this.todayAttendance = AttendanceStatus.present,
    this.dateOfBirth = '',
    this.gender = '',
    this.fatherName = '',
    this.fatherMobile = '',
    this.motherName = '',
    this.motherMobile = '',
    this.guardianName = '',
    this.emergencyContact = '',
    this.parentEmail = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.pinCode = '',
    this.bloodGroup = '',
    this.medicalNotes = '',
    this.importantNotes = '',
    this.schoolId = '',
    this.academicYearId = '',
    this.classId = 'cls_8',
    this.sectionId = 'sec_8_a',
    this.studentCode = 'SCH001-STU-0001',
    this.parentAccessCode = '',
    this.status = AccountStatus.active,
    this.totalFee = 0.0,
    this.paidFee = 0.0,
    this.pendingFee = 0.0,
    this.feeStatus = PaymentStatus.pending,
    this.paymentHistory = const [],
  });

  String get fullClassCode => '$className-$section';

  String get displayName {
    if (name.trim().isNotEmpty && name.trim() != 'Student') return name.trim();
    final combined = [firstName, middleName, lastName].where((s) => s.trim().isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;
    return 'Student';
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? firstName,
    String? middleName,
    String? lastName,
    String? rollNumber,
    String? admissionNumber,
    String? className,
    String? section,
    String? avatarUrl,
    String? studentPhoto,
    double? attendancePercentage,
    AttendanceStatus? todayAttendance,
    String? dateOfBirth,
    String? gender,
    String? fatherName,
    String? fatherMobile,
    String? motherName,
    String? motherMobile,
    String? guardianName,
    String? emergencyContact,
    String? parentEmail,
    String? address,
    String? city,
    String? state,
    String? pinCode,
    String? bloodGroup,
    String? medicalNotes,
    String? importantNotes,
    String? schoolId,
    String? academicYearId,
    String? classId,
    String? sectionId,
    String? studentCode,
    String? parentAccessCode,
    AccountStatus? status,
    double? totalFee,
    double? paidFee,
    double? pendingFee,
    PaymentStatus? feeStatus,
    List<PaymentReceiptModel>? paymentHistory,
  }) {
    final effectiveFirstName = firstName ?? this.firstName;
    final effectiveMiddleName = middleName ?? this.middleName;
    final effectiveLastName = lastName ?? this.lastName;
    String effectiveName = name ?? this.name;
    if (name == null && (firstName != null || middleName != null || lastName != null)) {
      final combined = [effectiveFirstName, effectiveMiddleName, effectiveLastName].where((s) => s.trim().isNotEmpty).join(' ');
      if (combined.isNotEmpty) effectiveName = combined;
    }

    final effectivePhoto = studentPhoto ?? (avatarUrl ?? this.studentPhoto);
    final effectiveAvatar = avatarUrl ?? (studentPhoto ?? this.avatarUrl);

    return StudentModel(
      id: id ?? this.id,
      name: effectiveName,
      firstName: effectiveFirstName,
      middleName: effectiveMiddleName,
      lastName: effectiveLastName,
      rollNumber: rollNumber ?? this.rollNumber,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      className: className ?? this.className,
      section: section ?? this.section,
      avatarUrl: effectiveAvatar,
      studentPhoto: effectivePhoto,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      fatherName: fatherName ?? this.fatherName,
      fatherMobile: fatherMobile ?? this.fatherMobile,
      motherName: motherName ?? this.motherName,
      motherMobile: motherMobile ?? this.motherMobile,
      guardianName: guardianName ?? this.guardianName,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      parentEmail: parentEmail ?? this.parentEmail,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pinCode: pinCode ?? this.pinCode,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      importantNotes: importantNotes ?? this.importantNotes,
      schoolId: schoolId ?? this.schoolId,
      academicYearId: academicYearId ?? this.academicYearId,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      studentCode: studentCode ?? this.studentCode,
      parentAccessCode: parentAccessCode ?? this.parentAccessCode,
      status: status ?? this.status,
      totalFee: totalFee ?? this.totalFee,
      paidFee: paidFee ?? this.paidFee,
      pendingFee: pendingFee ?? this.pendingFee,
      feeStatus: feeStatus ?? this.feeStatus,
      paymentHistory: paymentHistory ?? this.paymentHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'firstName': firstName,
    'middleName': middleName,
    'lastName': lastName,
    'first_name': firstName,
    'middle_name': middleName,
    'last_name': lastName,
    'rollNumber': rollNumber,
    'roll_number': rollNumber,
    'admissionNumber': admissionNumber,
    'admission_number': admissionNumber,
    'className': className,
    'class_name': className,
    'section': section,
    'section_name': section,
    'avatarUrl': avatarUrl,
    'student_photo': studentPhoto.isNotEmpty ? studentPhoto : avatarUrl,
    'attendancePercentage': attendancePercentage,
    'todayAttendance': todayAttendance.name,
    'dateOfBirth': dateOfBirth,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'fatherName': fatherName,
    'fatherMobile': fatherMobile,
    'motherName': motherName,
    'motherMobile': motherMobile,
    'guardianName': guardianName,
    'emergencyContact': emergencyContact,
    'parentEmail': parentEmail,
    'address': address,
    'city': city,
    'state': state,
    'pinCode': pinCode,
    'bloodGroup': bloodGroup,
    'medicalNotes': medicalNotes,
    'importantNotes': importantNotes,
    'schoolId': schoolId,
    'school_id': schoolId,
    'academicYearId': academicYearId,
    'academic_year_id': academicYearId,
    'classId': classId,
    'sectionId': sectionId,
    'studentCode': studentCode,
    'parentAccessCode': parentAccessCode,
    'parent_access_code': parentAccessCode,
    'status': status.name.toUpperCase(),
    'totalFee': totalFee,
    'paidFee': paidFee,
    'pendingFee': pendingFee,
    'feeStatus': feeStatus.name,
  };

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    String fName = json['first_name']?.toString() ?? json['firstName']?.toString() ?? '';
    String mName = json['middle_name']?.toString() ?? json['middleName']?.toString() ?? '';
    String lName = json['last_name']?.toString() ?? json['lastName']?.toString() ?? '';
    String resolvedName = json['name']?.toString() ?? json['full_name']?.toString() ?? '';

    if (resolvedName.isEmpty) {
      resolvedName = [fName, mName, lName].where((s) => s.trim().isNotEmpty).join(' ');
    } else if (fName.isEmpty && lName.isEmpty) {
      final parts = resolvedName.trim().split(RegExp(r'\s+'));
      if (parts.length == 1) {
        fName = parts[0];
      } else if (parts.length == 2) {
        fName = parts[0];
        lName = parts[1];
      } else if (parts.length > 2) {
        fName = parts[0];
        mName = parts.sublist(1, parts.length - 1).join(' ');
        lName = parts.last;
      }
    }

    final photo = json['student_photo']?.toString() ?? json['avatarUrl']?.toString() ?? json['profile_photo_url']?.toString() ?? 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=150';

    return StudentModel(
      id: json['id']?.toString() ?? '',
      name: resolvedName.isNotEmpty ? resolvedName : 'Student',
      firstName: fName,
      middleName: mName,
      lastName: lName,
      rollNumber: json['rollNumber']?.toString() ?? json['roll_number']?.toString() ?? '',
      admissionNumber: json['admissionNumber']?.toString() ?? json['admission_number']?.toString() ?? '',
      className: json['className']?.toString() ?? json['class_name']?.toString() ?? json['class']?.toString() ?? '',
      section: json['section']?.toString() ?? json['section_name']?.toString() ?? '',
      avatarUrl: photo,
      studentPhoto: photo,
      attendancePercentage: (json['attendancePercentage'] as num?)?.toDouble() ?? 100.0,
      todayAttendance: AttendanceStatus.values.firstWhere(
        (e) => e.name == json['todayAttendance'],
        orElse: () => AttendanceStatus.present,
      ),
      dateOfBirth: json['dateOfBirth']?.toString() ?? json['date_of_birth']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'Male',
      fatherName: json['fatherName']?.toString() ?? json['father_name']?.toString() ?? '',
      fatherMobile: json['fatherMobile']?.toString() ?? json['father_mobile']?.toString() ?? json['phone']?.toString() ?? '',
      motherName: json['motherName']?.toString() ?? json['mother_name']?.toString() ?? '',
      motherMobile: json['motherMobile']?.toString() ?? json['mother_mobile']?.toString() ?? '',
      guardianName: json['guardianName']?.toString() ?? json['guardian_name']?.toString() ?? '',
      emergencyContact: json['emergencyContact']?.toString() ?? json['emergency_contact']?.toString() ?? '',
      parentEmail: json['parentEmail']?.toString() ?? json['parent_email']?.toString() ?? json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pinCode: json['pinCode']?.toString() ?? json['pin_code']?.toString() ?? json['postal_code']?.toString() ?? '',
      bloodGroup: json['bloodGroup']?.toString() ?? json['blood_group']?.toString() ?? 'O+',
      medicalNotes: json['medicalNotes']?.toString() ?? json['medical_notes']?.toString() ?? '',
      importantNotes: json['importantNotes']?.toString() ?? json['important_notes']?.toString() ?? '',
      schoolId: json['schoolId']?.toString() ?? json['school_id']?.toString() ?? '',
      academicYearId: json['academicYearId']?.toString() ?? json['academic_year_id']?.toString() ?? '',
      classId: json['classId']?.toString() ?? json['class_id']?.toString() ?? '',
      sectionId: json['sectionId']?.toString() ?? json['section_id']?.toString() ?? '',
      studentCode: json['studentCode']?.toString() ?? json['student_code']?.toString() ?? '',
      parentAccessCode: json['parentAccessCode']?.toString() ?? json['parent_access_code']?.toString() ?? '',
      status: (json['status']?.toString().toUpperCase() == 'INACTIVE')
          ? AccountStatus.inactive
          : AccountStatus.active,
      totalFee: (json['totalFee'] as num?)?.toDouble() ?? (json['total_fee'] as num?)?.toDouble() ?? 0.0,
      paidFee: (json['paidFee'] as num?)?.toDouble() ?? (json['paid_fee'] as num?)?.toDouble() ?? 0.0,
      pendingFee: (json['pendingFee'] as num?)?.toDouble() ?? (json['pending_fee'] as num?)?.toDouble() ?? 0.0,
      feeStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == json['feeStatus'],
        orElse: () => PaymentStatus.paid,
      ),
      paymentHistory: const [],
    );
  }
}
