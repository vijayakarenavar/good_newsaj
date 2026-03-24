import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:good_news/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Launch app and check home screen', (WidgetTester tester) async {
    // App start करा
    app.main();
    await tester.pumpAndSettle();

    // Example: Check if "JoyScroll" title exists
    expect(find.text('JoyScroll'), findsOneWidget);

    // Example: Tap login button if exists
    // await tester.tap(find.byKey(ValueKey('loginButton')));
    // await tester.pumpAndSettle();

    // Example: Navigate to another screen
    // await tester.tap(find.byIcon(Icons.article));
    // await tester.pumpAndSettle();

    // Final check
    // expect(find.text('Article List'), findsOneWidget);
  });
}