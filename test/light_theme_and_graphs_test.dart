import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/core/theme/app_colors.dart';
import 'package:school_app/core/theme/app_theme.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/core/widgets/school_os_widgets.dart';
import 'package:school_app/features/navigation/main_navigation_screen.dart';
import 'package:school_app/features/dashboard/widgets/dashboard_charts.dart';
import 'package:school_app/features/admin/admin_dashboard_screen.dart';
import 'package:school_app/features/teacher/teacher_dashboard_screen.dart';
import 'package:school_app/data/models/user_model.dart';

class _MockAuthNotifier extends StateNotifier<UserModel?> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  UserProfileModel? get activeProfile => null;

  @override
  void setUserProfile(UserProfileModel profile) {}

  @override
  Future<void> refreshProfile() async {}

  @override
  void login(UserRole role) {}

  @override
  Future<void> logout() async {
    state = null;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testAdmin = const UserModel(
    id: 'admin_test_1',
    schoolId: 'school_test_1',
    name: 'Sarah Connor',
    email: 'admin@school.com',
    role: UserRole.schoolAdmin,
    avatarUrl: '',
    designation: 'Principal',
    schoolName: 'Greenwood Academy',
  );

  final testTeacher = const UserModel(
    id: 'teacher_test_1',
    schoolId: 'school_test_1',
    name: 'John Keating',
    email: 'keating@school.com',
    role: UserRole.teacher,
    avatarUrl: '',
    designation: 'Senior Faculty',
    schoolName: 'Greenwood Academy',
    assignedClass: '10',
    assignedSection: 'A',
    subject: 'Literature',
  );

  group('1. Light Theme System Tokens & Styles', () {
    test('AppColors verifies light-mode primary tokens', () {
      expect(AppColors.mainBackground, const Color(0xFFF7F9FC));
      expect(AppColors.cardBackground, const Color(0xFFFFFFFF));
      expect(AppColors.primaryAccent, const Color(0xFF4F46E5));
      expect(AppColors.softBlue, const Color(0xFFEAF2FF));
      expect(AppColors.softLavender, const Color(0xFFF0ECFF));
      expect(AppColors.softMint, const Color(0xFFE9F9F1));
      expect(AppColors.softAmber, const Color(0xFFFFF5DF));
      expect(AppColors.primaryText, const Color(0xFF243047));
      expect(AppColors.secondaryText, const Color(0xFF738096));
      expect(AppColors.border, const Color(0xFFE7ECF3));
      expect(AppColors.success, const Color(0xFF16A765));
      expect(AppColors.warning, const Color(0xFFE9A23B));
      expect(AppColors.error, const Color(0xFFE45454));
    });

    testWidgets('AppTheme.lightTheme configures clean light scaffold and cards', (tester) async {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.mainBackground);
      expect(theme.cardTheme.color, AppColors.cardBackground);
      expect(theme.colorScheme.primary, AppColors.primaryAccent);
      expect(theme.colorScheme.surface, AppColors.cardBackground);
    });
  });

  group('2. Interactive Dashboard Charts Rendering & Edge Cases', () {
    testWidgets('DashboardAttendanceTrendChart renders with telemetry points and tooltips', (tester) async {
      const points = [
        DailyAttendancePoint(dayName: 'Mon', presentPercent: 95.5, absentPercent: 4.5, presentCount: 191, absentCount: 9),
        DailyAttendancePoint(dayName: 'Tue', presentPercent: 97.0, absentPercent: 3.0, presentCount: 194, absentCount: 6),
        DailyAttendancePoint(dayName: 'Wed', presentPercent: 94.0, absentPercent: 6.0, presentCount: 188, absentCount: 12),
        DailyAttendancePoint(dayName: 'Thu', presentPercent: 98.0, absentPercent: 2.0, presentCount: 196, absentCount: 4),
        DailyAttendancePoint(dayName: 'Fri', presentPercent: 96.0, absentPercent: 4.0, presentCount: 192, absentCount: 8),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: DashboardAttendanceTrendChart(points: points),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DashboardAttendanceTrendChart), findsOneWidget);
      expect(find.textContaining('Present ('), findsOneWidget);
      expect(find.text('Healthy Attendance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DashboardAttendanceTrendChart handles empty telemetry points gracefully', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardAttendanceTrendChart(points: []),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No attendance telemetry records recorded this week'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DashboardFeeDonutChart renders currency breakdown and percentages', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: DashboardFeeDonutChart(
                collectedFees: 850000,
                pendingFees: 150000,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DashboardFeeDonutChart), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Collected'), findsOneWidget);
      expect(find.text('Collected (85.0%)'), findsOneWidget);
      expect(find.text('Outstanding (15.0%)'), findsOneWidget);
      expect(find.text('₹8,50,000'), findsOneWidget);
      expect(find.text('₹1,50,000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DashboardClassEnrollmentBarChart renders class distribution bars', (tester) async {
      const points = [
        ClassEnrollmentPoint(className: 'Class 1', studentCount: 25),
        ClassEnrollmentPoint(className: 'Class 2', studentCount: 30),
        ClassEnrollmentPoint(className: 'Class 3', studentCount: 28),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: DashboardClassEnrollmentBarChart(points: points),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DashboardClassEnrollmentBarChart), findsOneWidget);
      expect(find.text('Students per Grade Level'), findsOneWidget);
      expect(find.text('3 Classes Tracked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('3. MainNavigationScreen Light-First Desktop & Mobile Shell', () {
    testWidgets('Desktop layout renders light sidebar and header with soft accents', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const MainNavigationScreen(
              child: Center(child: Text('DASHBOARD_CONTENT')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(testAdmin)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.lightTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('School OS'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Staff & Teachers'), findsOneWidget);
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('Sarah Connor'), findsNWidgets(2));
      expect(find.text('DASHBOARD_CONTENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('4. Admin and Teacher Dashboard Complete Light-Mode Layouts', () {
    testWidgets('AdminDashboardScreen renders clean cards and charts without overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(testAdmin)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AdminDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.text('Total Students'), findsOneWidget);
      expect(find.text('Faculty & Staff'), findsOneWidget);
      expect(find.text('Academic Classes'), findsOneWidget);
      expect(find.text('Fee Collections'), findsOneWidget);
      expect(find.text('Student Enrollment'), findsOneWidget);
      expect(find.text('Attendance Overview'), findsOneWidget);
      expect(find.text('Fee Collection'), findsOneWidget);
      expect(find.text('Students by Class'), findsOneWidget);
      expect(find.text('Upcoming Events'), findsOneWidget);
      expect(find.text('Recent Activities'), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TeacherDashboardScreen renders light faculty card and control center', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(testTeacher)),
            teacherStudentCountProvider.overrideWith((ref) => 28),
            dashboardAttendanceTrendProvider.overrideWith((ref) => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TeacherDashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TeacherDashboardScreen), findsOneWidget);
      expect(find.text('John Keating'), findsOneWidget);
      expect(find.text('FACULTY'), findsOneWidget);
      expect(find.text('Teacher Control Center'), findsOneWidget);
      expect(find.text('Take Attendance'), findsOneWidget);
      expect(find.text('Homework & Tasks'), findsOneWidget);
      expect(find.text('Weekly Class Attendance Trends'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
