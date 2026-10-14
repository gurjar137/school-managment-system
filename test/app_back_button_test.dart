import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_app/core/widgets/app_back_button.dart';
import 'package:school_app/core/providers/app_providers.dart';
import 'package:school_app/data/models/user_model.dart';

class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier([UserModel? initialUser]) : super() {
    state = initialUser;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppBackButton Unit & Widget Tests', () {
    testWidgets('1. Renders left arrow icon and Back label with accessibility', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(
                leadingWidth: AppBackButton.leadingWidth,
                leading: const AppBackButton(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.byType(Tooltip), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Back'),
        findsOneWidget,
      );
    });

    testWidgets('2. showLabel: false renders only icon without text', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AppBackButton(showLabel: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('Back'), findsNothing);
    });

    testWidgets('3. Pops Navigator when canPop is true', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => Scaffold(
                        appBar: AppBar(
                          leadingWidth: AppBackButton.leadingWidth,
                          leading: const AppBackButton(),
                        ),
                        body: const Text('Second Page'),
                      ),
                    ),
                  );
                },
                child: const Text('Open Second'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Second'));
      await tester.pumpAndSettle();

      expect(find.text('Second Page'), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Open Second'), findsOneWidget);
      expect(find.text('Second Page'), findsNothing);
    });

    testWidgets('4. onBeforeBack returning false prevents pop', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => Scaffold(
                        appBar: AppBar(
                          leadingWidth: AppBackButton.leadingWidth,
                          leading: AppBackButton(
                            onBeforeBack: () async => false, // Disallow back
                          ),
                        ),
                        body: const Text('Second Page'),
                      ),
                    ),
                  );
                },
                child: const Text('Open Second'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Second'));
      await tester.pumpAndSettle();

      expect(find.text('Second Page'), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Second Page'), findsOneWidget);
    });

    testWidgets('5. Safe fallback navigation when history is empty', (tester) async {
      final adminUser = const UserModel(
        id: 'admin_1',
        schoolId: 'sch_1',
        schoolName: 'Test School',
        name: 'Admin',
        email: 'admin@school.com',
        role: UserRole.schoolAdmin,
        designation: 'Principal',
        avatarUrl: '',
      );

      final router = GoRouter(
        initialLocation: '/initial',
        routes: [
          GoRoute(
            path: '/initial',
            builder: (context, state) => Scaffold(
              appBar: AppBar(
                leadingWidth: AppBackButton.leadingWidth,
                leading: const AppBackButton(fallbackPath: '/students'),
              ),
              body: const Text('Initial'),
            ),
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) => const Scaffold(body: Text('Students List')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _MockAuthNotifier(adminUser)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Initial'), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Students List'), findsOneWidget);
    });

    testWidgets('6. showDiscardChangesDialog presents prompt and handles actions', (tester) async {
      bool? userAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                userAction = await showDiscardChangesDialog(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Discard Unsaved Changes?'), findsOneWidget);
      expect(find.text('Stay & Edit'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Tap Discard
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(userAction, isTrue);
    });
  });
}
