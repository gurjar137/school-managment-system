import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_app/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SchoolApp()));
    expect(find.byType(SchoolApp), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
