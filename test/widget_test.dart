import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:good_news/main.dart'; // matches pubspec.yaml name

void main() {
  testWidgets('GoodNewsApp loads without crashing', (WidgetTester tester) async {
    // Pump the main app widget
    await tester.pumpWidget(const GoodNewsApp());

    // Wait for splash wrapper to settle
    await tester.pumpAndSettle();

    // Check that at least some widget is found
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}