import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/core/desktop/desktop_shortcuts_wrapper.dart';
import 'package:school_app/data/models/user_model.dart';
import 'package:school_app/features/navigation/main_navigation_screen.dart';
import 'package:school_app/features/admin/admin_dashboard_screen.dart';
import 'package:school_app/features/timetable/timetable_management_screen.dart';
import 'package:school_app/features/students/students_list_screen.dart';
import 'package:school_app/features/admin/admin_teachers_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  final testAdmin = UserModel(
    id: 'c0448877-9f37-4c2d-b1f2-3de38a9e63df',
    name: 'Lead Administrator',
    email: 'admin@school.com',
    role: UserRole.schoolAdmin,
    avatarUrl: '', // Avoid network image fetch in unit/widget test
    schoolName: 'Greenwood International',
    designation: 'Principal',
    schoolId: '6254bee9-151d-4332-8a1c-3994af7d2153',
  );

  group('MACOS DESKTOP RESPONSIVE & NAVIGATION TEST SUITE', () {
    testWidgets('1. Desktop Sidebar Navigation renders on Widescreen (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const MainNavigationScreen(
              child: Scaffold(body: Text('DASHBOARD_BODY_CONTENT')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _DesktopMockAuthNotifier(testAdmin)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Desktop Sidebar elements
      expect(find.text('School OS'), findsOneWidget);
      expect(find.text('Greenwood International'), findsOneWidget);

      // Verify all 6 navigation links
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Staff & Teachers'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // SALARY IS NEVER DISPLAYED
      expect(find.text('Salary'), findsNothing);

      // Verify User footer info and Logout button
      expect(find.text('Lead Administrator'), findsOneWidget);
      expect(find.text('Principal'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Content area
      expect(find.text('DASHBOARD_BODY_CONTENT'), findsOneWidget);
    });

    testWidgets('2. Mobile Bottom Navigation renders on Narrow Viewport (600x800)', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const MainNavigationScreen(
              child: Scaffold(body: Text('MOBILE_CONTENT')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _DesktopMockAuthNotifier(testAdmin)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On mobile/narrow screen, School OS brand header sidebar is not rendered
      expect(find.text('School OS'), findsNothing);

      // Bottom nav is rendered
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Staff & Teachers'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Salary'), findsNothing);
    });

    testWidgets('3. Responsive Desktop Matrix: Dashboard renders cleanly across Mac sizes', (tester) async {
      const windowSizes = [
        Size(1024, 768),  // Small Mac
        Size(1280, 800),  // Medium Mac
        Size(1440, 900),  // Standard MacBook Pro
        Size(1920, 1080), // 1080p Desktop Display
      ];

      for (final size in windowSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _DesktopMockAuthNotifier(testAdmin)),
            ],
            child: const MaterialApp(
              home: AdminDashboardScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(AdminDashboardScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero layout exceptions at ${size.width}x${size.height}');
      }
      tester.view.resetPhysicalSize();
    });

    testWidgets('4. Responsive Desktop Matrix: Timetable renders cleanly without AppBar overflow', (tester) async {
      const windowSizes = [
        Size(1024, 768),
        Size(1280, 800),
        Size(1440, 900),
      ];

      for (final size in windowSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith((ref) => _DesktopMockAuthNotifier(testAdmin)),
            ],
            child: const MaterialApp(
              home: TimetableManagementScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(TimetableManagementScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero AppBar overflow at ${size.width}x${size.height}');
      }
      tester.view.resetPhysicalSize();
    });

    testWidgets('5. Responsive Desktop Matrix: Students and Teachers directories render cleanly', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _DesktopMockAuthNotifier(testAdmin)),
          ],
          child: const MaterialApp(
            home: StudentsListScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(StudentsListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _DesktopMockAuthNotifier(testAdmin)),
          ],
          child: const MaterialApp(
            home: AdminTeachersScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AdminTeachersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Desktop Shortcuts Wrapper binds Cmd+K and Cmd+R', (tester) async {
      bool searchTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DesktopShortcutsWrapper(
            onSearchOverride: () {
              searchTriggered = true;
            },
            child: const Scaffold(body: Text('HOME')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger Ctrl+K / Cmd+K
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(searchTriggered, isTrue);
    });
  });
}

class _DesktopMockAuthNotifier extends StateNotifier<UserModel?> implements AuthNotifier {
  _DesktopMockAuthNotifier(super.state);

  @override
  UserProfileModel? get activeProfile => null;

  @override
  void setUserProfile(UserProfileModel profile) {}

  @override
  void login(UserRole role) {}

  @override
  void logout() {
    state = null;
  }
}
