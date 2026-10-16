import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../../data/models/user_model.dart';
import '../../data/models/academic_models.dart';
import '../../data/models/class_section_models.dart';
import '../../data/models/parent_model.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/role_selection_screen.dart';
import '../../features/auth/admin_login_screen.dart';
import '../../features/auth/staff_login_screen.dart';
import '../../features/auth/school_onboarding_screen.dart';
import '../../features/auth/change_password_screen.dart';
import '../../features/admin/admin_management_screen.dart';
import '../../features/navigation/main_navigation_screen.dart';
import '../../features/teacher/teacher_dashboard_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/admin/admin_teachers_screen.dart';
import '../../features/admin/add_edit_teacher_screen.dart';
import '../../features/admin/add_student_screen.dart';
import '../../features/admin/admin_student_search_screen.dart';
import '../../features/admin/admin_salary_screen.dart';
import '../../features/admin/admin_reports_screen.dart';
import '../../features/students/students_list_screen.dart';
import '../../features/students/class_students_screen.dart';
import '../../features/students/student_profile_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/attendance/attendance_analytics_screen.dart';
import '../../features/timetable/timetable_management_screen.dart';
import '../../features/teacher/teacher_timetable_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/classes/classes_list_screen.dart';
import '../../features/classes/class_sections_screen.dart';
import '../../features/parents/parents_list_screen.dart';
import '../../features/parents/parent_details_screen.dart';
import '../../features/teachers/teacher_assignments_screen.dart';
import '../../features/attendance/mark_attendance_screen.dart';
import '../../features/parents/parent_child_attendance_screen.dart';
import '../../features/fees/admin_fee_management_screen.dart';
import '../../features/parents/parent_child_fee_screen.dart';
import '../../features/parents/parent_child_result_screen.dart';
import '../../features/homework/homework_screen.dart';
import '../../features/homework/create_homework_screen.dart';
import '../../features/notices/notices_screen.dart';
import '../../features/meetings/meetings_screen.dart';
import '../../features/leave_requests/leave_requests_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/transport/transport_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/subjects/subject_catalog_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/results/teacher_results_screen.dart';
import '../../features/admin/admin_create_exam_screen.dart';
import '../../features/results/enter_marks_screen.dart';
import '../../features/results/admin_results_screen.dart';
import '../../features/results/class_analytics_screen.dart';
import '../../features/admin/teacher_access_screen.dart';
import '../../features/admin/parent_codes_screen.dart';
import '../../features/admin/activity_log_screen.dart';
import '../../features/admin/admin_global_search_screen.dart';
import '../../features/admin/teacher_leave_management_screen.dart';
import '../../features/settings/school_settings_screen.dart';
import '../../features/academic_years/academic_years_screen.dart';
import '../../features/auth/update_password_screen.dart';
import '../../features/auth/app_access_blocked_screen.dart';
import '../../data/models/school_app_access_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

import '../auth/recovery_session_state.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final isRecoveryFlow = RecoverySessionState.codeDetected ||
      RecoverySessionState.exchangeAttempted ||
      RecoverySessionState.recoveryEventReceived;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: isRecoveryFlow ? '/update-password' : '/splash',
    redirect: (BuildContext context, GoRouterState state) async {
      final loc = state.uri.path;
      final isPublic = loc == '/splash' ||
          loc == '/role-selection' ||
          loc == '/login' ||
          loc == '/login/admin' ||
          loc == '/login/staff' ||
          loc == '/staff' ||
          loc == '/update-password' ||
          loc == '/change-password' ||
          loc == '/onboarding/school-setup';

      final isBlockedPage = loc == '/access-blocked' ||
          loc == '/access-deactivated' ||
          loc == '/subscription-expired';

      if (!SupabaseConfig.isConfigured) return null;

      try {
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;

        if (user == null) {
          // If trying to access a protected route without session, redirect to login
          if (!isPublic && !isBlockedPage) {
            return '/login/admin';
          }
          return null;
        }

        // If user is accessing protected routes, ensure access is not blocked
        if (!isPublic && !isBlockedPage) {
          final cached = ref.read(appAccessStateProvider).asData?.value;
          final access = cached ??
              await ref.read(tenantAccessServiceProvider).validateCurrentSession();
          if (access.isBlocked) {
            if (access.isSchoolDeactivated) return '/access-deactivated';
            if (access.isSubscriptionExpired) return '/subscription-expired';
            return '/access-blocked';
          }
        }
      } catch (_) {}

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/login',
        redirect: (context, state) => '/role-selection',
      ),
      GoRoute(
        path: '/login/admin',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/login/staff',
        builder: (context, state) => const StaffLoginScreen(),
      ),
      GoRoute(
        path: '/staff',
        redirect: (context, state) => '/teachers',
      ),
      GoRoute(
        path: '/update-password',
        builder: (context, state) => const UpdatePasswordScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) {
          final isFirst = state.uri.queryParameters['firstLogin'] == 'true';
          return ChangePasswordScreen(isFirstLogin: isFirst);
        },
      ),
      GoRoute(
        path: '/onboarding/school-setup',
        builder: (context, state) => const SchoolOnboardingScreen(),
      ),
      GoRoute(
        path: '/manage-admins',
        builder: (context, state) => const AdminManagementScreen(),
      ),
      GoRoute(
        path: '/access-deactivated',
        builder: (context, state) {
          final result = state.extra as AppAccessResult? ??
              AppAccessResult.schoolDeactivated();
          return AppAccessBlockedScreen(initialAccessResult: result);
        },
      ),
      GoRoute(
        path: '/subscription-expired',
        builder: (context, state) {
          final result = state.extra as AppAccessResult? ??
              AppAccessResult.subscriptionExpired();
          return AppAccessBlockedScreen(initialAccessResult: result);
        },
      ),
      GoRoute(
        path: '/access-blocked',
        builder: (context, state) {
          final result = state.extra as AppAccessResult?;
          return AppAccessBlockedScreen(initialAccessResult: result);
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainNavigationScreen(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) {
              return NoTransitionPage(
                child: Consumer(
                  builder: (context, ref, child) {
                    final user = ref.watch(authProvider);
                    if (user?.role == UserRole.teacher) {
                      return const TeacherDashboardScreen();
                    }
                    return const AdminDashboardScreen();
                  },
                ),
              );
            },
          ),
          GoRoute(
            path: '/students',
            pageBuilder: (context, state) => const NoTransitionPage(child: StudentsListScreen()),
          ),
          GoRoute(
            path: '/attendance',
            pageBuilder: (context, state) => const NoTransitionPage(child: AttendanceScreen()),
          ),
          GoRoute(
            path: '/schedule',
            pageBuilder: (context, state) => NoTransitionPage(
              child: Consumer(
                builder: (context, ref, child) {
                  final user = ref.watch(authProvider);
                  if (user?.role == UserRole.teacher) {
                    return const TeacherTimetableScreen();
                  }
                  return const TimetableManagementScreen();
                },
              ),
            ),
          ),
          GoRoute(
            path: '/teachers',
            pageBuilder: (context, state) => const NoTransitionPage(child: AdminTeachersScreen()),
          ),
          GoRoute(
            path: '/fees',
            pageBuilder: (context, state) => const NoTransitionPage(child: AdminFeeManagementScreen()),
          ),
          GoRoute(
            path: '/salary',
            pageBuilder: (context, state) => const NoTransitionPage(child: AdminSalaryScreen()),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => const NoTransitionPage(child: AdminReportsScreen()),
          ),
          GoRoute(
            path: '/results',
            pageBuilder: (context, state) => NoTransitionPage(
              child: Consumer(
                builder: (context, ref, child) {
                  final user = ref.watch(authProvider);
                  if (user?.role == UserRole.teacher) {
                    return const TeacherResultsScreen();
                  }
                  return const AdminResultsScreen();
                },
              ),
            ),
          ),
          GoRoute(
            path: '/inventory',
            pageBuilder: (context, state) => const NoTransitionPage(child: InventoryScreen()),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (context, state) => const NoTransitionPage(child: MoreScreen()),
          ),
        ],
      ),
      // Detail routes outside bottom bar shell
      GoRoute(
        path: '/create-exam',
        builder: (context, state) => const AdminCreateExamScreen(),
      ),
      GoRoute(
        path: '/enter-marks/:examId',
        builder: (context, state) {
          final examId = state.pathParameters['examId'] ?? '';
          return EnterMarksScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/class-analytics/:examId',
        builder: (context, state) {
          final examId = state.pathParameters['examId'] ?? '';
          return ClassAnalyticsScreen(examId: examId);
        },
      ),
      GoRoute(
        path: '/teacher-access',
        builder: (context, state) => const TeacherAccessScreen(),
      ),
      GoRoute(
        path: '/parent-codes',
        builder: (context, state) => const ParentCodesScreen(),
      ),
      GoRoute(
        path: '/activity-log',
        builder: (context, state) => const ActivityLogScreen(),
      ),
      GoRoute(
        path: '/global-search',
        builder: (context, state) => const AdminGlobalSearchScreen(),
      ),
      GoRoute(
        path: '/teacher-leaves',
        builder: (context, state) => const TeacherLeaveManagementScreen(),
      ),
      GoRoute(
        path: '/timetable',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            final user = ref.watch(authProvider);
            if (user?.role == UserRole.teacher) {
              return const TeacherTimetableScreen();
            }
            return const TimetableManagementScreen();
          },
        ),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/school-settings',
        builder: (context, state) => const SchoolSettingsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/academic-years',
        builder: (context, state) => const AcademicYearsScreen(),
      ),
      GoRoute(
        path: '/subjects',
        builder: (context, state) => const SubjectCatalogScreen(),
      ),
      GoRoute(
        path: '/subject-catalog',
        builder: (context, state) => const SubjectCatalogScreen(),
      ),
      GoRoute(
        path: '/parents',
        builder: (context, state) => const ParentsListScreen(),
      ),
      GoRoute(
        path: '/parents/:parentId',
        builder: (context, state) {
          final parent = state.extra as ParentModel?;
          return ParentDetailsScreen(targetParent: parent);
        },
      ),
      GoRoute(
        path: '/admin-fees',
        builder: (context, state) => const AdminFeeManagementScreen(),
      ),
      GoRoute(
        path: '/child-fees/:studentId',
        builder: (context, state) {
          final studentId = state.pathParameters['studentId'];
          return ParentChildFeeScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: '/mark-attendance',
        builder: (context, state) => const MarkAttendanceScreen(),
      ),
      GoRoute(
        path: '/child-attendance/:studentId',
        builder: (context, state) {
          final studentId = state.pathParameters['studentId'];
          return ParentChildAttendanceScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: '/child-results/:studentId',
        builder: (context, state) {
          final studentId = state.pathParameters['studentId'];
          return ParentChildResultScreen(studentId: studentId);
        },
      ),
      GoRoute(
        path: '/teacher-assignments/:teacherId',
        builder: (context, state) {
          final teacher = state.extra as TeacherModel?;
          return TeacherAssignmentsScreen(teacher: teacher);
        },
      ),
      GoRoute(
        path: '/class-sections/:classId',
        builder: (context, state) {
          final targetClass = state.extra as SchoolClassModel?;
          final classId = state.pathParameters['classId'];
          return ClassSectionsScreen(targetClass: targetClass, classId: classId);
        },
      ),
      GoRoute(
        path: '/add-teacher',
        builder: (context, state) => const AddEditTeacherScreen(),
      ),
      GoRoute(
        path: '/edit-teacher',
        builder: (context, state) {
          final teacher = state.extra as TeacherModel?;
          return AddEditTeacherScreen(teacherToEdit: teacher);
        },
      ),
      GoRoute(
        path: '/class-students',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final classId = extra?['classId'] as String? ?? state.uri.queryParameters['classId'] ?? '';
          final className = extra?['className'] as String? ?? state.uri.queryParameters['className'] ?? 'Class';
          return ClassStudentsScreen(classId: classId, className: className);
        },
      ),
      GoRoute(
        path: '/add-student',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final classId = extra?['classId'] as String? ?? state.uri.queryParameters['classId'];
          final className = extra?['className'] as String? ?? state.uri.queryParameters['className'];
          return AddStudentScreen(classId: classId, className: className);
        },
      ),
      GoRoute(
        path: '/admin-student-search',
        builder: (context, state) => const AdminStudentSearchScreen(),
      ),
      GoRoute(
        path: '/student/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return StudentProfileScreen(studentId: id);
        },
      ),
      GoRoute(
        path: '/students/:id',
        redirect: (context, state) => '/student/${state.pathParameters['id']}',
      ),
      GoRoute(
        path: '/attendance-analytics',
        builder: (context, state) => const AttendanceAnalyticsScreen(),
      ),
      GoRoute(
        path: '/classes',
        builder: (context, state) => const ClassesListScreen(),
      ),
      GoRoute(
        path: '/homework',
        builder: (context, state) => const HomeworkScreen(),
      ),
      GoRoute(
        path: '/homework-create',
        builder: (context, state) => const CreateHomeworkScreen(),
      ),
      GoRoute(
        path: '/exams',
        redirect: (context, state) => '/results',
      ),
      GoRoute(
        path: '/notices',
        builder: (context, state) => const NoticesScreen(),
      ),
      GoRoute(
        path: '/meetings',
        builder: (context, state) => const MeetingsScreen(),
      ),
      GoRoute(
        path: '/leave-requests',
        builder: (context, state) => const LeaveRequestsScreen(),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/transport',
        builder: (context, state) => const TransportScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );

  if (SupabaseConfig.isConfigured) {
    try {
      final client = Supabase.instance.client;
      client.auth.onAuthStateChange.listen((data) {
        final AuthChangeEvent event = data.event;
        debugPrint('[AppRouter] Supabase AuthChangeEvent: $event');
        if (event == AuthChangeEvent.passwordRecovery) {
          RecoverySessionState.recoveryEventReceived = true;
          debugPrint('[AppRouter] PASSWORD_RECOVERY detected -> navigating to /update-password');
          router.go('/update-password');
        }
      });
    } catch (_) {
      // Ignored if Supabase.instance is not initialized yet (e.g. in tests)
    }
  }

  return router;
});
