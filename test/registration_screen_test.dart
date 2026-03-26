import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:good_news/features/authentication/presentation/screens/registration_screen.dart';

void main() {
  Widget buildRegistrationScreen() {
    return const MaterialApp(home: RegistrationScreen());
  }

  // ─── UI Tests ───────────────────────────────────────────────────────────────
  group('Registration Screen - UI', () {
    testWidgets('Registration screen loads correctly',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          expect(find.text('Joy Scroll'), findsOneWidget);
          expect(find.text('Create your account'), findsOneWidget);
          expect(find.text('Register'), findsOneWidget);
        });

    testWidgets('All 5 input fields exist', (WidgetTester tester) async {
      await tester.pumpWidget(buildRegistrationScreen());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(5));
    });

    testWidgets('Terms checkbox exists', (WidgetTester tester) async {
      await tester.pumpWidget(buildRegistrationScreen());
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
    });
  });

  // ─── Form Validation Tests ──────────────────────────────────────────────────
  group('Registration Screen - Form Validation', () {
    testWidgets('Register button disabled when fields are empty',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final registerButton = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Register'),
          );
          expect(registerButton.onPressed, isNull);
        });

    testWidgets('Invalid phone number shows validation error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(1), '12345');
          await tester.pump();

          expect(
            find.text('Phone must start with 6-9 and be 10 digits'),
            findsOneWidget,
          );
        });

    testWidgets('Invalid email shows validation error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(2), 'test@yahoo.com');
          await tester.pump();

          expect(
            find.text('Only @gmail.com emails are allowed'),
            findsOneWidget,
          );
        });

    testWidgets('Password less than 6 characters shows error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(3), '123');
          await tester.pump();

          expect(
            find.text('Password must be at least 6 characters'),
            findsOneWidget,
          );
        });

    testWidgets('Confirm password mismatch shows error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(3), 'password123');
          await tester.enterText(fields.at(4), 'password456');
          await tester.pump();

          expect(find.text('Passwords do not match'), findsOneWidget);
        });

    testWidgets('Register button disabled when terms not accepted',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(0), 'Test User');
          await tester.enterText(fields.at(1), '9876543210');
          await tester.enterText(fields.at(2), 'test@gmail.com');
          await tester.enterText(fields.at(3), 'password123');
          await tester.enterText(fields.at(4), 'password123');
          await tester.pump();

          final registerButton = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Register'),
          );
          expect(registerButton.onPressed, isNull);
        });
  });

  // ─── Edge Case Tests ────────────────────────────────────────────────────────
  group('Registration Screen - Edge Cases', () {
    testWidgets('Display name with only spaces shows error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(0), '   ');
          await tester.pump();

          expect(find.text('Display name is required'), findsOneWidget);
        });

    testWidgets('Display name with 1 character shows error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(0), 'A');
          await tester.pump();

          expect(
            find.text('Display name must be at least 2 characters'),
            findsOneWidget,
          );
        });

    testWidgets('Display name with numbers shows error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(0), 'Test123');
          await tester.pump();

          expect(
            find.text('Only letters and spaces are allowed'),
            findsOneWidget,
          );
        });

    testWidgets('Phone number with all zeros is invalid',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(1), '0000000000');
          await tester.pump();

          expect(
            find.text('Phone must start with 6-9 and be 10 digits'),
            findsOneWidget,
          );
        });

    testWidgets('Phone number with less than 10 digits is invalid',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(1), '987654321');
          await tester.pump();

          expect(
            find.text('Phone must start with 6-9 and be 10 digits'),
            findsOneWidget,
          );
        });

    testWidgets('Uppercase email is invalid',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(2), 'TEST@YAHOO.COM');
          await tester.pump();

          expect(
            find.text('Only @gmail.com emails are allowed'),
            findsOneWidget,
          );
        });

    testWidgets('Password with only spaces shows error',
            (WidgetTester tester) async {
          await tester.pumpWidget(buildRegistrationScreen());
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(3), '     ');
          await tester.pump();

          expect(
            find.text('Password must be at least 6 characters'),
            findsOneWidget,
          );
        });
  });

  // ─── Navigation Tests ───────────────────────────────────────────────────────
  group('Registration Screen - Navigation', () {
    testWidgets('Login link is visible', (WidgetTester tester) async {
      await tester.pumpWidget(buildRegistrationScreen());
      await tester.pumpAndSettle();

      expect(find.text('Login'), findsOneWidget);
    });
  });
}