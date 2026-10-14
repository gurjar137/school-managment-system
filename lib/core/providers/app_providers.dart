import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../utils/teacher_assignment_parser.dart';
import '../../data/models/user_model.dart';
import '../../data/models/student_model.dart';
import '../../data/mock/mock_data.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/school_repository.dart';
import '../../data/services/student_service.dart';
import '../../data/services/teacher_service.dart';
import '../../data/services/fee_service.dart';
import '../../data/services/salary_service.dart';
import '../../data/services/report_service.dart';
import '../../data/services/result_service.dart';
import '../../data/services/access_service.dart';
import '../../data/services/school_management_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/models/school_model.dart';
import '../../data/services/school_service.dart';
import '../../data/services/parent_service.dart';
import '../../data/services/class_section_service.dart';

import '../../data/services/attendance_service.dart';
import '../../data/services/library_service.dart';
import '../../data/services/transport_service.dart';
import '../../data/models/school_app_access_state.dart';
import '../../data/services/tenant_access_service.dart';
import '../../data/services/academic_year_service.dart';
export 'timetable_providers.dart';

// Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

final tenantAccessServiceProvider = Provider<TenantAccessService>((ref) {
  return TenantAccessService();
});

final appAccessStateProvider = FutureProvider<AppAccessResult>((ref) async {
  ref.watch(authProvider);
  final service = ref.watch(tenantAccessServiceProvider);
  return await service.validateCurrentSession();
});

final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  return AttendanceService();
});

final parentServiceProvider = Provider<ParentService>((ref) {
  return ParentService();
});

final classSectionServiceProvider = Provider<ClassSectionService>((ref) {
  return ClassSectionService();
});

final schoolServiceProvider = Provider<SchoolService>((ref) {
  return SchoolService();
});

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService();
});

final transportServiceProvider = Provider<TransportService>((ref) {
  return TransportService();
});

final academicYearServiceProvider = Provider<AcademicYearService>((ref) {
  return AcademicYearService();
});

class AdminDashboardMetrics {
  final String schoolName;
  final String schoolCode;
  final int totalStudents;
  final int totalTeachers;
  final int totalClasses;
  final double collectedFees;
  final double pendingFees;
  final int activeTeacherAccess;
  final int disabledTeacherAccess;
  final int activeParentCodes;
  final int revokedParentCodes;
  final String teacherDirectorySubtitle;

  const AdminDashboardMetrics({
    this.schoolName = 'School',
    this.schoolCode = '—',
    this.totalStudents = 0,
    this.totalTeachers = 0,
    this.totalClasses = 0,
    this.collectedFees = 0.0,
    this.pendingFees = 0.0,
    this.activeTeacherAccess = 0,
    this.disabledTeacherAccess = 0,
    this.activeParentCodes = 0,
    this.revokedParentCodes = 0,
    this.teacherDirectorySubtitle = 'No class-teacher assignments yet',
  });
}

final currentSchoolProvider = FutureProvider<SchoolModel>((ref) async {
  final activeProfile = ref.watch(authProvider.notifier).activeProfile;
  final schoolService = ref.watch(schoolServiceProvider);
  final schoolId = activeProfile?.schoolId;
  if (schoolId != null && schoolId.isNotEmpty) {
    return await schoolService.fetchSchoolProfile(schoolId);
  }
  return SchoolModel(
    id: '',
    schoolCode: '—',
    name: 'School',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
});

final adminDashboardMetricsProvider = FutureProvider<AdminDashboardMetrics>((ref) async {
  final user = ref.watch(authProvider);
  final studentService = ref.watch(studentServiceProvider);
  final teacherService = ref.watch(teacherServiceProvider);
  final feeService = ref.watch(feeServiceProvider);
  final schoolService = ref.watch(schoolServiceProvider);
  final activeProfile = ref.read(authProvider.notifier).activeProfile;

  final schoolId = activeProfile?.schoolId ?? await studentService.fetchActiveSchoolId();

  // 1. Fetch School
  final school = await schoolService.fetchSchoolProfile(schoolId);
  final schoolName = (school.name.isNotEmpty && school.name != 'Greenwood International School')
      ? school.name
      : (user?.schoolName ?? 'School');
  final schoolCode = school.schoolCode.isNotEmpty ? school.schoolCode : '—';

  // 2. Fetch Students (Exact live database count across all 10,000+ students)
  int totalStudents = 0;
  try {
    totalStudents = await studentService.getStudentCount(schoolId: schoolId);
  } catch (e) {
    debugPrint('[adminDashboardMetricsProvider getStudentCount error]: $e');
  }

  // 3. Fetch Classes
  final ayRec = await studentService.fetchActiveAcademicYearRecord(schoolId);
  final ayId = (ayRec?['id'] as String?) ?? '';
  final classes = ayId.isNotEmpty ? await studentService.fetchClasses(schoolId, ayId) : <dynamic>[];
  int totalClasses = classes.length;
  if (totalClasses == 0 && schoolId.isNotEmpty) {
    try {
      final distinct = await studentService.fetchDistinctClassNames(schoolId: schoolId);
      totalClasses = distinct.length;
    } catch (_) {}
  }

  // 4. Fetch Teachers
  final teachers = await teacherService.getTeachers(schoolId: schoolId);
  final totalTeachers = teachers.length;

  // 5. Fetch Fees
  final feeStats = await feeService.getFeeStats(schoolId: schoolId);
  final collectedFees = feeStats['collected'] ?? 0.0;
  final pendingFees = feeStats['pending'] ?? 0.0;

  // 6. Access Control Counts
  final activeTeachers = teachers.where((t) => t.status == AccountStatus.active).length;
  final disabledTeachers = teachers.where((t) => t.status != AccountStatus.active).length;

  final assignments = await teacherService.getTeacherAssignments(schoolId: schoolId);
  final assignedClasses = assignments.map((a) => a.className).toSet().toList();
  assignedClasses.sort((a, b) {
    final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
    final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 999;
    final cmp = numA.compareTo(numB);
    return cmp != 0 ? cmp : a.compareTo(b);
  });
  final teacherDirectorySubtitle = assignments.isNotEmpty
      ? 'View assigned class teachers for ${assignedClasses.join(", ")}'
      : 'No class-teacher assignments yet';

  return AdminDashboardMetrics(
    schoolName: schoolName,
    schoolCode: schoolCode,
    totalStudents: totalStudents,
    totalTeachers: totalTeachers,
    totalClasses: totalClasses,
    collectedFees: collectedFees,
    pendingFees: pendingFees,
    activeTeacherAccess: activeTeachers,
    disabledTeacherAccess: disabledTeachers,
    activeParentCodes: totalStudents,
    revokedParentCodes: 0,
    teacherDirectorySubtitle: teacherDirectorySubtitle,
  );
});

// Repositories & Services
final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  final studentService = ref.watch(studentServiceProvider);
  final teacherService = ref.watch(teacherServiceProvider);
  final libraryService = ref.watch(libraryServiceProvider);
  final transportService = ref.watch(transportServiceProvider);
  return SchoolRepository(
    studentService: studentService,
    teacherService: teacherService,
    libraryService: libraryService,
    transportService: transportService,
  );
});

final attendanceRepositoryProvider = Provider<MockAttendanceRepository>((ref) {
  return MockAttendanceRepository();
});

final studentServiceProvider = Provider<StudentService>((ref) {
  return StudentService();
});

final teacherServiceProvider = Provider<TeacherService>((ref) {
  return TeacherService();
});

final feeServiceProvider = Provider<FeeService>((ref) {
  return FeeService();
});

final salaryServiceProvider = Provider<SalaryService>((ref) {
  return SalaryService();
});

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

final resultServiceProvider = Provider<ResultService>((ref) {
  return ResultService();
});

final accessServiceProvider = Provider<AccessService>((ref) {
  return AccessService();
});

final schoolManagementServiceProvider = Provider<SchoolManagementService>((ref) {
  return SchoolManagementService();
});

// Theme Mode State
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  void toggleTheme() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Auth State
class AuthNotifier extends StateNotifier<UserModel?> {
  UserProfileModel? _activeProfile;
  StreamSubscription<AuthState>? _authSub;

  AuthNotifier() : super(SupabaseConfig.isConfigured ? null : MockData.currentAdminUser) {
    _listenAuthChanges();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  void _listenAuthChanges() {
    try {
      if (SupabaseConfig.isConfigured) {
        final client = Supabase.instance.client;
        debugPrint('[AuthNotifier] Initial currentUser: ${client.auth.currentUser?.email}');
        if (client.auth.currentUser != null) {
          _restoreUser(client.auth.currentUser);
        }
        _authSub = client.auth.onAuthStateChange.listen((data) {
          if (!mounted) return;
          debugPrint('[AuthNotifier onAuthStateChange]: event=${data.event}, user=${data.session?.user.email}');
          if (data.session?.user != null) {
            _restoreUser(data.session?.user);
          } else {
            final hadProfile = _activeProfile != null || state != null;
            _activeProfile = null;
            if (mounted) {
              state = null;
            }
            if (hadProfile) {
              clearLocalSchoolCaches();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[AuthNotifier Auth Listener Error]: $e');
    }
  }

  void _restoreUser(User? user) async {
    if (user == null) {
      _activeProfile = null;
      if (mounted) state = null;
      return;
    }
    if (!mounted) return;
    debugPrint('[AuthNotifier _restoreUser]: ${user.email}, metadata=${user.userMetadata}');
      
    // Check database public.profiles first as primary source of truth
    try {
      final authService = AuthService();
      final dbProfile = await authService.fetchUserProfile(user.id);
      if (!mounted) return;
      if (SupabaseConfig.isConfigured) {
        final currentId = Supabase.instance.client.auth.currentUser?.id;
        if (currentId == null || currentId != user.id) {
          debugPrint('[AuthNotifier _restoreUser]: User signed out or changed during fetch, skipping update.');
          return;
        }
      }
      if (dbProfile != null) {
        if (dbProfile.status != AccountStatus.active) {
          debugPrint('[AuthNotifier _restoreUser]: User profile status is ${dbProfile.status}, signing out');
          _activeProfile = null;
          if (mounted) state = null;
          if (SupabaseConfig.isConfigured) {
            await Supabase.instance.client.auth.signOut();
          }
          return;
        }
        debugPrint('[AuthNotifier _restoreUser]: Restored profile from DB: ${dbProfile.email}, role: ${dbProfile.role}');

          final meta = user.userMetadata ?? {};
          final metaClass = meta['assigned_class'] ?? meta['class'];
          final metaSection = meta['assigned_section'] ?? meta['section'];

          String? effectiveClass = dbProfile.assignedClass;
          String? effectiveSection = dbProfile.assignedSection;

          if (effectiveClass == null || effectiveClass.trim().isEmpty) {
            effectiveClass = metaClass?.toString();
          }
          if (effectiveSection == null || effectiveSection.trim().isEmpty) {
            effectiveSection = metaSection?.toString();
          }

          if (effectiveClass != null && effectiveClass.contains('-') && (effectiveSection == null || effectiveSection.isEmpty)) {
            final parts = effectiveClass.split('-');
            effectiveClass = parts.first.trim();
            if (parts.length > 1) {
              effectiveSection = parts.sublist(1).join('-').trim();
            }
          }

          final fullProfile = dbProfile.copyWith(
            assignedClass: effectiveClass,
            assignedSection: effectiveSection,
          );

          if (!mounted) return;
          setUserProfile(fullProfile);
          return;
        } else if (SupabaseConfig.isConfigured) {
          debugPrint('[AuthNotifier _restoreUser]: User authenticated but no profile found in database, signing out');
          _activeProfile = null;
          if (mounted) state = null;
          await Supabase.instance.client.auth.signOut();
          return;
        }
      } catch (e) {
        debugPrint('[AuthNotifier _restoreUser DB fetch notice]: $e');
      }

      if (!mounted) return;
      if (SupabaseConfig.isConfigured) {
        final currentId = Supabase.instance.client.auth.currentUser?.id;
        if (currentId == null || currentId != user.id) {
          return;
        }
      }

      final meta = user.userMetadata ?? {};
      final roleMeta = meta['role'];
      final assignedClass = meta['assigned_class'] ?? meta['class'];
      final assignedSection = meta['section'];
      
      final bool isTeacher = roleMeta != null && roleMeta.toString().toLowerCase().contains('teacher');
      final bool isAdmin = (roleMeta != null && roleMeta.toString().toLowerCase().contains('admin')) ||
          (user.email != null && user.email!.toLowerCase().contains('admin'));

      final resolvedRole = isTeacher ? UserRole.teacher : (isAdmin ? UserRole.schoolAdmin : UserRole.schoolAdmin);

      final profile = UserProfileModel(
        id: user.id,
        authUserId: user.id,
        schoolId: meta['school_id']?.toString() ?? '',
        schoolName: meta['school_name']?.toString() ?? 'School',
        name: meta['full_name'] ?? user.email?.split('@').first ?? 'User',
        email: user.email ?? '',
        role: resolvedRole,
        status: AccountStatus.active,
        designation: meta['designation'] ?? (resolvedRole == UserRole.teacher ? 'Class Teacher' : 'School Administrator'),
        assignedClass: assignedClass?.toString(),
        assignedSection: assignedSection?.toString(),
        subject: meta['subject']?.toString(),
        createdAt: DateTime.now(),
      );
      if (mounted) {
        setUserProfile(profile);
      }
  }

  Future<void> refreshProfile() async {
    if (SupabaseConfig.isConfigured) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        _restoreUser(user);
      }
    }
  }

  UserProfileModel? get activeProfile => _activeProfile;

  void setUserProfile(UserProfileModel profile) {
    final oldSchoolId = _activeProfile?.schoolId;
    _activeProfile = profile;
    if (!mounted) return;
    state = UserModel(
      id: profile.id,
      schoolId: profile.schoolId,
      name: profile.name,
      email: profile.email,
      role: profile.role,
      avatarUrl: profile.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      schoolName: profile.schoolName,
      designation: profile.designation,
      assignedClass: profile.assignedClass,
      assignedSection: profile.assignedSection,
      subject: profile.subject,
      totalStudentsInClass: 0,
      status: profile.status,
    );
    if (oldSchoolId != null && oldSchoolId.isNotEmpty && oldSchoolId != profile.schoolId) {
      clearLocalSchoolCaches();
    }
  }

  void login(UserRole role) {
    if (SupabaseConfig.isConfigured) {
      debugPrint('[AuthNotifier]: Mock login ignored because Supabase is configured.');
      return;
    }
    if (!mounted) return;
    if (role.isAdministrator) {
      state = MockData.currentAdminUser;
    } else if (role == UserRole.teacher) {
      state = MockData.currentTeacherUser;
    } else {
      state = const UserModel(
        id: 'usr_003',
        name: 'Staff Member',
        email: 'staff@school.com',
        role: UserRole.staff,
        avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        schoolName: 'Primary School Campus',
        designation: 'Operations & Administrative Staff',
      );
    }
  }

  Future<void> logout() async {
    _activeProfile = null;
    if (mounted) {
      state = null;
    }
    await clearLocalSchoolCaches();
    if (SupabaseConfig.isConfigured) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('[AuthNotifier signOut notice]: $e');
      }
    }
  }

  static Future<void> clearLocalSchoolCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final k in keys) {
        if (k.startsWith('cached_')) {
          await prefs.remove(k);
        }
      }
      await prefs.remove('cached_students_data');
      await prefs.remove('cached_teachers_data');
      await prefs.remove('cached_parents_data');
      await prefs.remove('cached_links_data');
      await prefs.remove('cached_books_data');
      await prefs.remove('cached_transport_routes');
      await prefs.remove('cached_salary_data');
    } catch (e) {
      debugPrint('[clearLocalSchoolCaches warning]: $e');
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  return AuthNotifier();
});

final teacherRosterProvider = FutureProvider<List<StudentModel>>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null || user.role != UserRole.teacher) return [];
  final repo = ref.watch(schoolRepositoryProvider);
  return await repo.getStudents(
    isTeacher: true,
    teacherAssignedClass: user.assignedClass,
    teacherAssignedSection: user.assignedSection,
  );
});

final teacherStudentCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(authProvider);
  if (user == null || user.role != UserRole.teacher) return 0;
  final assignedClass = user.assignedClass;
  final assignedSection = user.assignedSection;
  if (assignedClass == null || assignedClass.trim().isEmpty || assignedClass == 'Not Assigned') {
    return 0;
  }
  final studentService = ref.watch(studentServiceProvider);
  final userSchoolId = user.schoolId;
  final schoolId = (userSchoolId != null && userSchoolId.isNotEmpty)
      ? userSchoolId
      : await studentService.fetchActiveSchoolId();
  String? academicYearId;
  try {
    academicYearId = await studentService.fetchActiveAcademicYearId(schoolId);
  } catch (_) {}
  return await studentService.getStudentCount(
    schoolId: schoolId,
    academicYearId: academicYearId,
    className: assignedClass,
    section: assignedSection,
    status: AccountStatus.active,
  );
});

// Attendance Board State
class AttendanceBoardState {
  final String selectedClass;
  final String selectedSection;
  final DateTime selectedDate;
  final int totalClassStudents;
  final Map<String, AttendanceStatus> attendanceMap;
  final List<Map<String, AttendanceStatus>> historyStack;
  final String searchQuery;
  final String filterStatus; // 'All', 'Present', 'Absent', 'Late'
  final bool isSaving;
  final bool isOffline;
  final bool isLoadingSummary;

  AttendanceBoardState({
    required this.selectedClass,
    required this.selectedSection,
    required this.selectedDate,
    required this.totalClassStudents,
    required this.attendanceMap,
    required this.historyStack,
    required this.searchQuery,
    required this.filterStatus,
    required this.isSaving,
    required this.isOffline,
    this.isLoadingSummary = false,
  });

  int get presentCount =>
      attendanceMap.values.where((s) => s == AttendanceStatus.present).length;

  int get absentCount =>
      attendanceMap.values.where((s) => s == AttendanceStatus.absent).length;

  int get lateCount =>
      attendanceMap.values.where((s) => s == AttendanceStatus.late).length;

  int get unmarkedCount =>
      (totalClassStudents - presentCount - absentCount - lateCount).clamp(0, totalClassStudents);

  double get attendancePercentage =>
      totalClassStudents > 0 ? (presentCount / totalClassStudents * 100) : 0.0;

  AttendanceBoardState copyWith({
    String? selectedClass,
    String? selectedSection,
    DateTime? selectedDate,
    int? totalClassStudents,
    Map<String, AttendanceStatus>? attendanceMap,
    List<Map<String, AttendanceStatus>>? historyStack,
    String? searchQuery,
    String? filterStatus,
    bool? isSaving,
    bool? isOffline,
    bool? isLoadingSummary,
  }) {
    return AttendanceBoardState(
      selectedClass: selectedClass ?? this.selectedClass,
      selectedSection: selectedSection ?? this.selectedSection,
      selectedDate: selectedDate ?? this.selectedDate,
      totalClassStudents: totalClassStudents ?? this.totalClassStudents,
      attendanceMap: attendanceMap ?? this.attendanceMap,
      historyStack: historyStack ?? this.historyStack,
      searchQuery: searchQuery ?? this.searchQuery,
      filterStatus: filterStatus ?? this.filterStatus,
      isSaving: isSaving ?? this.isSaving,
      isOffline: isOffline ?? this.isOffline,
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
    );
  }
}

class AttendanceBoardNotifier extends StateNotifier<AttendanceBoardState> {
  final AttendanceService _attendanceService;
  final StudentService _studentService;
  final MockAttendanceRepository? _repo;
  final bool _isLocked;
  String _lastErrorMessage = '';

  String get lastErrorMessage => _lastErrorMessage;

  AttendanceBoardNotifier({
    required AttendanceService attendanceService,
    required StudentService studentService,
    MockAttendanceRepository? repo,
    required String assignedClass,
    required String assignedSection,
    int initialTotalCount = 0,
    bool? isLocked,
  })  : _attendanceService = attendanceService,
        _studentService = studentService,
        _repo = repo,
        _isLocked = isLocked ?? (assignedClass == '12' && assignedSection == 'F'),
        super(AttendanceBoardState(
          selectedClass: assignedClass,
          selectedSection: assignedSection,
          selectedDate: DateTime.now(),
          totalClassStudents: initialTotalCount,
          attendanceMap: {},
          historyStack: [],
          searchQuery: '',
          filterStatus: 'All',
          isSaving: false,
          isOffline: false,
        ));

  void setClassAndSection(String className, String section) {
    if (_isLocked) return;
    state = state.copyWith(
      selectedClass: className,
      selectedSection: section,
      attendanceMap: {},
      historyStack: [],
    );
    loadClassAttendanceSummary();
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date, attendanceMap: {}, historyStack: []);
    loadClassAttendanceSummary();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterStatus(String filter) {
    state = state.copyWith(filterStatus: filter);
  }

  void markStudent(String studentId, AttendanceStatus status) {
    final currentMap = Map<String, AttendanceStatus>.from(state.attendanceMap);
    final history = List<Map<String, AttendanceStatus>>.from(state.historyStack)..add(currentMap);
    
    // Toggle: tapping already-selected status sets back to notMarked
    if (currentMap[studentId] == status) {
      currentMap[studentId] = AttendanceStatus.notMarked;
    } else {
      currentMap[studentId] = status;
    }
    state = state.copyWith(attendanceMap: currentMap, historyStack: history);
  }

  void markAllPresent([List<StudentModel> students = const []]) {
    final currentMap = Map<String, AttendanceStatus>.from(state.attendanceMap);
    final history = List<Map<String, AttendanceStatus>>.from(state.historyStack)..add(currentMap);

    final updated = <String, AttendanceStatus>{};
    for (var key in currentMap.keys) {
      updated[key] = AttendanceStatus.present;
    }
    for (var s in students) {
      updated[s.id] = AttendanceStatus.present;
    }
    state = state.copyWith(attendanceMap: updated, historyStack: history);
  }

  void resetAll([List<StudentModel> students = const []]) {
    final currentMap = Map<String, AttendanceStatus>.from(state.attendanceMap);
    final history = List<Map<String, AttendanceStatus>>.from(state.historyStack)..add(currentMap);

    final updated = <String, AttendanceStatus>{};
    for (var key in currentMap.keys) {
      updated[key] = AttendanceStatus.notMarked;
    }
    for (var s in students) {
      updated[s.id] = AttendanceStatus.notMarked;
    }
    state = state.copyWith(attendanceMap: updated, historyStack: history);
  }

  void undo() {
    if (state.historyStack.isNotEmpty) {
      final history = List<Map<String, AttendanceStatus>>.from(state.historyStack);
      final previous = history.removeLast();
      state = state.copyWith(attendanceMap: previous, historyStack: history);
    }
  }

  void toggleOfflineMode() {
    final newMode = !state.isOffline;
    if (_repo != null) {
      _repo.isOfflineMode = newMode;
    }
    state = state.copyWith(isOffline: newMode);
  }

  /// Loads exact server-side class summary (total active students + present/absent/late counts)
  Future<void> loadClassAttendanceSummary({
    String? schoolId,
    String? academicYearId,
  }) async {
    if (!mounted) return;
    state = state.copyWith(isLoadingSummary: true);
    final dateStr = '${state.selectedDate.year.toString().padLeft(4, '0')}-${state.selectedDate.month.toString().padLeft(2, '0')}-${state.selectedDate.day.toString().padLeft(2, '0')}';

    final effectiveSchoolId = (schoolId != null && schoolId.isNotEmpty)
        ? schoolId
        : await _studentService.fetchActiveSchoolId();
    String? effectiveAyId = academicYearId;
    if (effectiveAyId == null || effectiveAyId.isEmpty) {
      try {
        effectiveAyId = await _studentService.fetchActiveAcademicYearId(effectiveSchoolId);
      } catch (_) {}
    }

    if (effectiveAyId == null || effectiveAyId.isEmpty) {
      debugPrint('[AttendanceBoardNotifier] No active academic year for school $effectiveSchoolId; attendance summary deferred.');
      state = state.copyWith(isLoadingSummary: false);
      return;
    }

    try {
      final summary = await _attendanceService.getClassDailyAttendanceSummary(
        schoolId: effectiveSchoolId,
        academicYearId: effectiveAyId,
        className: state.selectedClass,
        section: state.selectedSection,
        attendanceDate: dateStr,
        studentService: _studentService,
      );

      int total = summary.totalStudents;
      if (total == 0 && state.totalClassStudents > 0) {
        total = state.totalClassStudents;
      }

      if (!mounted) return;
      state = state.copyWith(
        totalClassStudents: total,
        attendanceMap: Map<String, AttendanceStatus>.from(summary.attendanceMap),
        historyStack: [],
        isLoadingSummary: false,
      );
    } catch (e) {
      debugPrint('[AttendanceBoardNotifier loadClassAttendanceSummary Error]: $e');
      if (!mounted) return;
      state = state.copyWith(isLoadingSummary: false);
    }
  }

  /// Refreshes attendance state directly from public.attendance table
  Future<void> loadAttendanceFromDatabase([List<StudentModel> students = const []]) async {
    await loadClassAttendanceSummary();
    if (students.isNotEmpty) {
      final dateStr = '${state.selectedDate.year.toString().padLeft(4, '0')}-${state.selectedDate.month.toString().padLeft(2, '0')}-${state.selectedDate.day.toString().padLeft(2, '0')}';
      final studentIds = students.map((s) => s.id).where((id) => id.isNotEmpty).toList();
      final schoolId = students.first.schoolId.isNotEmpty
          ? students.first.schoolId
          : await _studentService.fetchActiveSchoolId();

      final dbRecords = await _attendanceService.fetchAttendanceForDate(
        schoolId: schoolId,
        attendanceDate: dateStr,
        studentIds: studentIds,
      );

      final currentMap = Map<String, AttendanceStatus>.from(state.attendanceMap);
      for (final s in students) {
        currentMap[s.id] = currentMap[s.id] ?? dbRecords[s.id] ?? AttendanceStatus.notMarked;
      }

      int total = state.totalClassStudents;
      if (total == 0) {
        total = students.length;
      }
      if (!mounted) return;
      state = state.copyWith(totalClassStudents: total, attendanceMap: currentMap);
    }
  }

  /// Saves / Upserts attendance records directly to public.attendance in Supabase
  Future<bool> saveAttendance({List<StudentModel> assignedStudents = const []}) async {
    _lastErrorMessage = '';
    state = state.copyWith(isSaving: true);

    try {
      final dateStr = '${state.selectedDate.year.toString().padLeft(4, '0')}-${state.selectedDate.month.toString().padLeft(2, '0')}-${state.selectedDate.day.toString().padLeft(2, '0')}';
      final defaultSchoolId = await _studentService.fetchActiveSchoolId();
      String? defaultAyId;
      try {
        defaultAyId = await _studentService.fetchActiveAcademicYearId(defaultSchoolId);
      } catch (_) {}

      if (defaultAyId == null || defaultAyId.isEmpty) {
        _lastErrorMessage = 'No active academic year is configured for this school. Please configure an academic year in School Settings before recording attendance.';
        state = state.copyWith(isSaving: false);
        return false;
      }

      final studentMap = {for (var s in assignedStudents) s.id: s};
      final upsertPayloads = <Map<String, dynamic>>[];
      final committedMap = Map<String, AttendanceStatus>.from(state.attendanceMap);

      if (assignedStudents.isNotEmpty) {
        committedMap.removeWhere((sId, _) => !studentMap.containsKey(sId));
      }

      // Save all explicitly marked students in attendanceMap
      for (final entry in committedMap.entries) {
        final sId = entry.key;
        final statusEnum = entry.value;

        // Skip unmarked students - NEVER create attendance rows for them!
        if (statusEnum == AttendanceStatus.notMarked) continue;

        final statusStr = statusEnum == AttendanceStatus.absent
            ? 'absent'
            : (statusEnum == AttendanceStatus.late ? 'late' : 'present');

        final studentModel = studentMap[sId];
        final schoolId = (studentModel != null && studentModel.schoolId.isNotEmpty)
            ? studentModel.schoolId
            : defaultSchoolId;
        final ayId = (studentModel != null && studentModel.academicYearId.isNotEmpty)
            ? studentModel.academicYearId
            : defaultAyId;

        upsertPayloads.add({
          'student_id': sId,
          'school_id': schoolId,
          'academic_year_id': ayId,
          'attendance_date': dateStr,
          'status': statusStr,
        });

        committedMap[sId] = statusEnum;
      }

      if (upsertPayloads.isNotEmpty) {
        // 1. SUPABASE UPSERT (Awaited BEFORE showing success)
        await _attendanceService.upsertAttendanceRecords(upsertPayloads);

        // 2. Update local student models only for explicitly marked students
        for (final s in assignedStudents) {
          final status = committedMap[s.id];
          if (status != null && status != AttendanceStatus.notMarked) {
            await _studentService.updateStudent(s.copyWith(todayAttendance: status));
          }
        }

        // Also notify legacy repo if present
        if (_repo != null) {
          await _repo.saveClassAttendance(
            className: state.selectedClass,
            section: state.selectedSection,
            attendanceMap: committedMap,
          );
        }
      }

      state = state.copyWith(isSaving: false, attendanceMap: committedMap);
      return true;
    } catch (e) {
      debugPrint('[AttendanceBoardNotifier Save Error]: $e');
      _lastErrorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('PostgrestException: ', '');
      state = state.copyWith(isSaving: false);
      return false;
    }
  }
}

final attendanceBoardProvider =
    StateNotifierProvider<AttendanceBoardNotifier, AttendanceBoardState>((ref) {
  final attendanceService = ref.watch(attendanceServiceProvider);
  final studentService = ref.watch(studentServiceProvider);
  final repo = ref.watch(attendanceRepositoryProvider);
  final user = ref.watch(authProvider);

  final parser = TeacherAssignmentParser(
    assignedClass: user?.assignedClass,
    assignedSection: user?.assignedSection,
  );

  final assignedClass = parser.rawClass.isNotEmpty ? parser.rawClass : (user?.assignedClass ?? '');
  final assignedSection = parser.rawSection.isNotEmpty ? parser.rawSection : (user?.assignedSection ?? '');
  final initialCount = ref.watch(teacherStudentCountProvider).value ?? 0;

  return AttendanceBoardNotifier(
    attendanceService: attendanceService,
    studentService: studentService,
    repo: repo,
    assignedClass: assignedClass,
    assignedSection: assignedSection,
    initialTotalCount: initialCount,
  );
});
