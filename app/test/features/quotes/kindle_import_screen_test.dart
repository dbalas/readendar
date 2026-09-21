import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/kindle/kindle_clippings.dart';
import 'package:readendar/features/quotes/kindle/kindle_import_screen.dart';

import 'quotes_test_utils.dart';

KindleClipping _clip(String title, String text, {String? author, int? page}) =>
    KindleClipping(title: title, author: author, text: text, page: page);

Widget _host(
  List<Book> books,
  KindleParseResult result, {
  bool asyncBooks = false,
}) {
  return ProviderScope(
    overrides: [
      quoteRepoProvider.overrideWithValue(FakeQuoteRepository([])),
      if (asyncBooks)
        // Async override: the library resolves a frame later, exercising the
        // deferred-match path (the screen must wait, not mark all unmatched).
        booksProvider.overrideWith((ref) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return books;
        })
      else
        booksProvider.overrideWith((ref) => books),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: KindleImportScreen(initialResult: result),
    ),
  );
}

void main() {
  final books = [testBook(title: 'Dune')];

  KindleParseResult resultWith() => KindleParseResult(
    clippings: [
      _clip('Dune', 'Fear is the mind-killer', author: 'Frank Herbert', page: 45),
      _clip('Dune', 'The spice must flow', author: 'Frank Herbert'),
      _clip('An Unknown Book', 'orphan highlight'),
    ],
    skippedNotes: 0,
    skippedBookmarks: 0,
    duplicatesDropped: 0,
  );

  testWidgets('assign step: matched on top, checkbox state, Continue gating', (
    tester,
  ) async {
    await tester.pumpWidget(_host(books, resultWith()));
    await tester.pump();

    // Both source books are listed; the matched one (Dune) sorts first.
    expect(find.text('Dune'), findsWidgets);
    expect(find.text('An Unknown Book'), findsOneWidget);
    // The unmatched hint lives inside the joined subtitle string.
    expect(find.textContaining('Sin libro en tu biblioteca'), findsOneWidget);

    // Two checkboxes: matched Dune is checked+enabled, unmatched is disabled.
    final checkboxes = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .toList();
    expect(checkboxes, hasLength(2));
    final dune = checkboxes.firstWhere((c) => c.onChanged != null);
    expect(dune.value, isTrue);
    expect(checkboxes.any((c) => c.onChanged == null), isTrue);

    // Continue is enabled because there is a matched, included group.
    final continueBtn = tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Continuar'),
    );
    expect(continueBtn.onPressed, isNotNull);
  });

  testWidgets('waits for the library to load before matching (no all-unmatched)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(books, resultWith(), asyncBooks: true));
    // First frame: library still loading → a spinner, matching deferred.
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Sin libro en tu biblioteca'), findsNothing);

    // Library resolves → Dune matches (checkbox enabled), only the orphan is
    // unmatched. Had we matched against the empty library, Dune would show
    // unmatched too.
    await tester.pumpAndSettle();
    expect(find.textContaining('Sin libro en tu biblioteca'), findsOneWidget);
    final checkboxes = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .toList();
    expect(
      checkboxes.where((c) => c.onChanged != null && (c.value ?? false)),
      hasLength(1),
    );
  });

  testWidgets('review step: per-quote checkboxes drive the import count', (
    tester,
  ) async {
    await tester.pumpWidget(_host(books, resultWith()));
    await tester.pump();

    await tester.tap(find.widgetWithText(RdButton, 'Continuar'));
    await tester.pumpAndSettle();

    // Only the matched book's two quotes are reviewable; the orphan is gone.
    expect(find.text('«Fear is the mind-killer»'), findsOneWidget);
    expect(find.text('«The spice must flow»'), findsOneWidget);
    expect(find.text('orphan highlight'), findsNothing);

    // All selected by default → the "select all" checkbox is checked and the
    // import button counts both.
    expect(find.text('Importar 2 citas'), findsOneWidget);
    expect(find.text('Seleccionar todas'), findsOneWidget);

    // Tapping a quote row deselects it → count drops to 1.
    await tester.tap(find.text('«Fear is the mind-killer»'));
    await tester.pump();
    expect(find.text('Importar 1 cita'), findsOneWidget);

    // The "select all" checkbox is now indeterminate (some, not all, selected).
    final selectAll = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(selectAll.value, isNull);

    // Tapping it re-selects everything.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('Importar 2 citas'), findsOneWidget);
  });
}
