import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:good_news/features/authentication/presentation/screens/login_screen.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  Widget buildLoginScreen() {
    return const MaterialApp(home: LoginScreen());
  }

  group('Login Screen - UI', () {
    testWidgets('Login screen loads correctly', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Joy Scroll'), findsOneWidget);
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('Email and Password fields exist', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('Login Screen - Form Validation', () {
    testWidgets('Login button disabled when fields are empty',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildLoginScreen());
          await tester.pumpAndSettle();

          final loginButton = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Login'),
          );
          expect(loginButton.onPressed, isNull);
        });

    testWidgets('Invalid email shows validation error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildLoginScreen());
          await tester.pumpAndSettle();

          await tester.enterText(
              find.byType(TextFormField).first, 'invalidemail');
          await tester.pump();

          expect(find.text('Please enter a valid email'), findsOneWidget);
        });

    testWidgets('Login button enabled when email and password entered',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildLoginScreen());
          await tester.pumpAndSettle();

          await tester.enterText(
              find.byType(TextFormField).first, 'test@gmail.com');
          await tester.enterText(
              find.byType(TextFormField).last, 'password123');
          await tester.pump();

          final loginButton = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Login'),
          );
          expect(loginButton.onPressed, isNotNull);
        });

    testWidgets('Password visibility toggle works', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).last, 'password123');
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('Login Screen - Navigation', () {
    testWidgets('Sign Up link is visible', (WidgetTester tester) async {
      await tester.pumpWidget(buildLoginScreen());
      await tester.pumpAndSettle();

      expect(find.text('Sign Up'), findsOneWidget);
    });
  });
}