import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anonnote/features/notes/screens/create_note_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:anonnote/l10n/app_localizations.dart';

void main() {
  testWidgets('CreateNoteScreen focus scrolls fields into view', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: CreateNoteScreen(),
      ),
    );

    // Ensure the widget tree is built
    await tester.pumpAndSettle();

    // Find the title TextField by the English hint text
    final titleFinder = find.byWidgetPredicate((w) {
      return w is TextField && (w.decoration?.hintText ?? '') == 'Title';
    });

    expect(titleFinder, findsOneWidget);

    // Tap the title field to focus
    await tester.tap(titleFinder);
    await tester.pumpAndSettle();

    // No exceptions should be thrown (notably the ScrollController assert)
    expect(tester.takeException(), isNull);
  });
}
