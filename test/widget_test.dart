// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anonnote/main.dart';

void main() {
  testWidgets('App shows title and settings', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    // Allow localization delegates and frames to settle.
    await tester.pumpAndSettle();

    // The localized app title should be visible in one or more places.
    expect(find.text('AnonNote'), findsWidgets);

    // Settings icon should be present in the AppBar area.
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
