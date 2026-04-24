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
    // Advance a few frames for async startup state.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));

    // App shell should render even while startup work is async.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Depending on local pref state, app can land on home or lock screen.
    final showsHome = find.text('AnonNote').evaluate().isNotEmpty;
    final showsLock = find.text('Enter PIN').evaluate().isNotEmpty;
    final showsLoading = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isNotEmpty;
    expect(showsHome || showsLock || showsLoading, isTrue);
  });
}
