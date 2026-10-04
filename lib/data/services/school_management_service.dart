import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/school_management_models.dart';
import '../models/student_model.dart';
import '../models/academic_models.dart' hide TimetableSlotModel;
import '../models/fee_models.dart';
import '../models/user_model.dart';

class SchoolManagementService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> resolveActiveSchoolId([String? schoolId]) async {
    if (schoolId != null && schoolId.isNotEmpty) return schoolId;
    final client = _client;
    if (client != null && client.auth.currentUser != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('school_id')
            .eq('auth_user_id', client.auth.currentUser!.id)
            .maybeSingle();
        if (profile != null && profile['school_id'] != null) {
          return profile['school_id'].toString();
        }
      } catch (_) {}
    }
    return null;
  }

  StudentModel _mapSupabaseToStudentModel(Map<String, dynamic> data) {
    String resolvedClassName = '';
    if (data['class_name'] != null && data['class_name'].toString().trim().isNotEmpty) {
      resolvedClassName = data['class_name'].toString().trim();
    } else if (data['class'] != null && data['class'].toString().trim().isNotEmpty) {
      resolvedClassName = data['class'].toString().trim();
    }

    String resolvedSectionName = '';
    if (data['section_name'] != null && data['section_name'].toString().trim().isNotEmpty) {
      resolvedSectionName = data['section_name'].toString().trim();
    } else if (data['section'] != null && data['section'].toString().trim().isNotEmpty) {
      resolvedSectionName = data['section'].toString().trim();
    }

    final fullName = data['full_name'] ?? '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim();
    final admNo = data['admission_number']?.toString() ?? '';

    return StudentModel(
      id: data['id']?.toString() ?? '',
      schoolId: data['school_id']?.toString() ?? '',
      academicYearId: data['academic_year_id']?.toString() ?? '',
      classId: data['class_id']?.toString() ?? '',
      sectionId: data['section_id']?.toString() ?? '',
      studentCode: admNo.isNotEmpty ? admNo : 'STU',
      parentAccessCode: data['parent_access_code']?.toString() ?? '',
      name: fullName.isNotEmpty ? fullName : 'Student',
      rollNumber: data['roll_number']?.toString() ?? '',
      admissionNumber: admNo,
      className: resolvedClassName,
      section: resolvedSectionName,
      avatarUrl: data['profile_photo_url']?.toString() ?? 'https://images.unsplash.com/photo-1544717305-2782549b5136?w=150',
      attendancePercentage: (data['attendance_pct'] as num?)?.toDouble() ?? 100.0,
      todayAttendance: AttendanceStatus.present,
      dateOfBirth: data['date_of_birth']?.toString() ?? '',
      gender: data['gender']?.toString() ?? 'Male',
      fatherName: data['father_name']?.toString() ?? '',
      fatherMobile: data['phone']?.toString() ?? data['father_mobile']?.toString() ?? '',
      motherName: data['mother_name']?.toString() ?? '',
      motherMobile: data['mother_mobile']?.toString() ?? '',
      guardianName: data['guardian_name']?.toString() ?? data['father_name']?.toString() ?? '',
      emergencyContact: data['emergency_contact']?.toString() ?? data['phone']?.toString() ?? '',
      parentEmail: data['email']?.toString() ?? data['parent_email']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      state: data['state']?.toString() ?? '',
      pinCode: data['postal_code']?.toString() ?? data['pin_code']?.toString() ?? '',
      bloodGroup: data['blood_group']?.toString() ?? 'O+',
      medicalNotes: data['medical_notes']?.toString() ?? '',
      importantNotes: data['important_notes']?.toString() ?? '',
      status: (data['status']?.toString().toUpperCase() == 'INACTIVE' || data['status']?.toString().toUpperCase() == 'DEACTIVATED')
          ? AccountStatus.inactive
          : AccountStatus.active,
      totalFee: (data['total_fee'] as num?)?.toDouble() ?? 0.0,
      paidFee: (data['paid_fee'] as num?)?.toDouble() ?? 0.0,
      pendingFee: (data['pending_fee'] as num?)?.toDouble() ?? 0.0,
      feeStatus: PaymentStatus.paid,
      paymentHistory: const [],
    );
  }

  TeacherModel _mapSupabaseToTeacherModel(Map<String, dynamic> data, {String? defaultSchoolId}) {
    final subList = data['subjects'] is List
        ? List<String>.from(data['subjects'])
        : (data['subject'] != null ? [data['subject'].toString()] : const <String>[]);
    final rawClass = data['assigned_class']?.toString() ?? data['class']?.toString() ??
        (data['class_name'] != null ? data['class_name'].toString() : '');
    final rawSection = data['assigned_section']?.toString() ?? data['section']?.toString() ?? '';
    final rawName = (data['full_name'] ?? data['name'] ?? '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}').toString().trim();
    final teacherName = rawName.isNotEmpty ? rawName : 'Teacher';
    final statusStr = data['status']?.toString().toUpperCase() ?? 'ACTIVE';
    final accountStatus = (statusStr == 'INACTIVE' || statusStr == 'SUSPENDED')
        ? AccountStatus.inactive
        : AccountStatus.active;
    final idStr = data['id']?.toString() ?? '';
    final empId = data['employee_id']?.toString() ?? data['employee_code']?.toString() ??
        'EMP-${idStr.length >= 4 ? idStr.substring(0, 4).toUpperCase() : "0000"}';

    return TeacherModel(
      id: idStr,
      schoolId: data['school_id']?.toString() ?? defaultSchoolId ?? '',
      employeeId: empId,
      name: teacherName,
      email: data['email']?.toString() ?? '',
      subjects: subList,
      assignedClass: rawClass,
      assignedSection: rawSection,
      totalStudents: 0,
      avatarUrl: data['profile_photo_url']?.toString() ?? data['avatar_url']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      designation: data['designation']?.toString() ?? 'Teacher',
      status: accountStatus,
      joiningDate: data['joining_date']?.toString(),
      authUserId: data['auth_user_id']?.toString(),
    );
  }

  final List<AttendanceCorrectionModel> _corrections = [];
  final List<TeacherLeaveModel> _teacherLeaves = [];
  final Map<String, List<StudentDocumentModel>> _studentDocs = {};

  SchoolSettingsModel _schoolSettings = const SchoolSettingsModel(
    schoolId: '',
    name: 'School',
    logoUrl: 'https://images.unsplash.com/photo-1580582932707-520aed937b7b?w=150',
    address: 'Campus Address',
    phone: '',
    email: '',
    academicYear: '2026-27',
    activeClasses: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
    activeSubjects: ['Mathematics', 'Science', 'English', 'Hindi', 'Computer', 'Social Studies'],
  );

  SchoolManagementService();

  // --- CATEGORIZED GLOBAL SEARCH ---
  Future<CategorizedSearchResult> performCategorizedSearch(String query) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const CategorizedSearchResult(students: [], teachers: [], feePayments: [], receipts: [], results: []);
    }

    final q = trimmed.toLowerCase();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final schoolId = await resolveActiveSchoolId();
        if (schoolId == null || schoolId.isEmpty) {
          return const CategorizedSearchResult(students: [], teachers: [], feePayments: [], receipts: [], results: []);
        }

        // 1. Live Students Search
        List<StudentModel> matchedStudents = [];
        try {
          final sData = await _client!
              .from('students')
              .select()
              .eq('school_id', schoolId)
              .or('first_name.ilike.%$q%,last_name.ilike.%$q%,admission_number.ilike.%$q%')
              .limit(20);
          matchedStudents = sData.map((row) => _mapSupabaseToStudentModel(row)).toList();
        } catch (e) {
          debugPrint('[SchoolManagementService Student Search Warning]: $e');
        }

        // 2. Live Teachers Search (profiles with role=teacher)
        List<TeacherModel> matchedTeachers = [];
        try {
          final tData = await _client!
              .from('profiles')
              .select()
              .eq('school_id', schoolId)
              .ilike('role', '%teacher%')
              .or('full_name.ilike.%$q%,email.ilike.%$q%')
              .limit(20);
          matchedTeachers = tData.map((row) => _mapSupabaseToTeacherModel(row, defaultSchoolId: schoolId)).toList();
        } catch (e) {
          debugPrint('[SchoolManagementService Teacher Search Warning]: $e');
        }

        // 3. Live Fee Payments Search
        List<FeePayment> matchedPayments = [];
        List<FeeReceiptModel> receipts = [];
        try {
          final fData = await _client!
              .from('fee_payments')
              .select()
              .eq('school_id', schoolId)
              .or('receipt_number.ilike.%$q%,notes.ilike.%$q%,payment_method.ilike.%$q%')
              .limit(20);
          matchedPayments = fData.map((row) => FeePayment.fromJson(row)).toList();
          receipts = fData
              .where((r) => r['receipt_number'] != null && r['receipt_number'].toString().isNotEmpty)
              .map((row) => FeeReceiptModel.fromJson(row))
              .toList();
        } catch (e) {
          debugPrint('[SchoolManagementService Fee Search Warning]: $e');
        }

        return CategorizedSearchResult(
          students: matchedStudents,
          teachers: matchedTeachers,
          feePayments: matchedPayments,
          receipts: receipts,
          results: const [],
        );
      } catch (e) {
        debugPrint('[SchoolManagementService Global Search Error]: $e');
      }
    }

    return const CategorizedSearchResult(students: [], teachers: [], feePayments: [], receipts: [], results: []);
  }

  // --- ATTENDANCE CORRECTION ---
  Future<List<AttendanceCorrectionModel>> getPendingCorrectionRequests() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _corrections.where((c) => c.status == 'pending').toList();
  }

  Future<void> submitCorrectionRequest(AttendanceCorrectionModel req) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _corrections.insert(0, req);
  }

  Future<void> approveCorrection(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _corrections.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _corrections[idx] = _corrections[idx].copyWith(status: 'approved');
    }
  }

  Future<void> rejectCorrection(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _corrections.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _corrections[idx] = _corrections[idx].copyWith(status: 'rejected');
    }
  }

  // --- TEACHER LEAVE MANAGEMENT ---
  Future<List<TeacherLeaveModel>> getPendingLeaveRequests() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _teacherLeaves.where((l) => l.status == 'pending').toList();
  }

  Future<List<TeacherLeaveModel>> getAllLeaveRequests() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_teacherLeaves);
  }

  Future<void> applyTeacherLeave(TeacherLeaveModel req) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _teacherLeaves.insert(0, req);
  }

  Future<void> approveLeave(String id, String remarks) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _teacherLeaves.indexWhere((l) => l.id == id);
    if (idx != -1) {
      _teacherLeaves[idx] = _teacherLeaves[idx].copyWith(status: 'approved', adminRemarks: remarks);
    }
  }

  Future<void> rejectLeave(String id, String remarks) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final idx = _teacherLeaves.indexWhere((l) => l.id == id);
    if (idx != -1) {
      _teacherLeaves[idx] = _teacherLeaves[idx].copyWith(status: 'rejected', adminRemarks: remarks);
    }
  }

  // --- TIMETABLE ---
  Future<List<TimetableSlotModel>> getTimetableForClass(String className) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return const [];
  }

  // --- STUDENT DOCUMENTS ---
  Future<List<StudentDocumentModel>> getStudentDocuments(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _studentDocs[studentId] ?? [];
  }

  Future<void> uploadStudentDocument(StudentDocumentModel doc) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_studentDocs.containsKey(doc.studentId)) {
      _studentDocs[doc.studentId] = [];
    }
    _studentDocs[doc.studentId]!.insert(0, doc);
  }

  // --- SCHOOL SETTINGS ---
  Future<SchoolSettingsModel> getSchoolSettings() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _schoolSettings;
  }

  Future<void> updateSchoolSettings(SchoolSettingsModel updated) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _schoolSettings = updated;
  }
}
