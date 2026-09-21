import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_row.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/catalog_import.dart';
import 'package:readendar/features/import/import_complete_screen.dart';
import 'package:readendar/features/import/import_confirm_screen.dart';
import 'package:readendar/features/import/import_models.dart';
import 'package:readendar/features/import/import_progress_screen.dart';

import 'catalog_import_fakes.dart';

ImportParseResult _parsed(
  List<ImportedBook> books, {
  int ratingsRounded = 0,
}) => ImportParseResult(
  books: books,
  skippedNoTitle: 0,
  duplicatesDropped: 0,
  truncated: false,
  ratingsRounded: ratingsRounded,
);

ImportedBook _book(String title, String status, {String isbn = ''}) =>
    ImportedBook(
      title: title,
      authors: const ['Autor'],
      isbn: isbn,
      status: status,
    );

Widget _wrap(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: home,
      ),
    );

void main() {
  testWidgets('confirm screen shows counts and toggles shelves', (
    tester,
  ) async {
    final parsed = _parsed([
      _book('A', BookStatus.read, isbn: '9780439023481'),
      _book('B', BookStatus.read, isbn: '9780441013593'),
      _book('C', BookStatus.pending),
    ]);

    await tester.pumpWidget(
      _wrap(
        ImportConfirmScreen(parsed: parsed),
        overrides: [booksProvider.overrideWith((ref) async => const <Book>[])],
      ),
    );
    await tester.pumpAndSettle();

    // 3 books found, button imports all 3.
    expect(find.text('Hemos encontrado 3 libros'), findsOneWidget);
    expect(find.text('Importar 3 libros'), findsOneWidget);

    // Each parsed book renders as a library-style row in the list below. (Title
    // shows twice per row: once in the cover fallback, once as the row title.)
    expect(find.text('A'), findsWidgets);
    expect(find.text('B'), findsWidgets);
    expect(find.text('C'), findsWidgets);

    // Untick the "Read" shelf (2 books, identified by its 2/2 counter) → button
    // drops to 1. ("Read" alone is ambiguous now that rows show a status pill.)
    final readShelf = find.ancestor(
      of: find.text('2/2'),
      matching: find.byType(CheckboxListTile),
    );
    await tester.tap(readShelf);
    await tester.pumpAndSettle();
    expect(find.text('Importar 1 libro'), findsOneWidget);
  });

  testWidgets('confirm screen scrolls on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const statuses = [
      BookStatus.read,
      BookStatus.reading,
      BookStatus.pending,
      BookStatus.wanted,
      BookStatus.abandoned,
    ];
    final parsed = ImportParseResult(
      books: [
        for (var i = 0; i < 11; i++)
          _book('Book $i', statuses[i % statuses.length]),
      ],
      skippedNoTitle: 1,
      skippedNoAuthor: 1,
      duplicatesDropped: 1,
      truncated: true,
      unmatchedNoteSheets: 1,
    );

    await tester.pumpWidget(
      _wrap(
        ImportConfirmScreen(parsed: parsed),
        overrides: [booksProvider.overrideWith((ref) async => const <Book>[])],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Importar 11 libros'), findsOneWidget);
    expect(find.text('Se ha omitido 1 fila sin autor'), findsOneWidget);
  });

  testWidgets('books already in the library are flagged and unticked', (
    tester,
  ) async {
    final parsed = _parsed([
      _book('Owned', BookStatus.read, isbn: '0439023483'),
      _book('New', BookStatus.read, isbn: '9780441013593'),
    ]);
    final owned = Book(
      id: 'x',
      ownerType: 'user',
      ownerId: 'u',
      title: 'Owned',
      authors: const ['Autor'],
      status: BookStatus.read,
      isbn13: '9780439023481',
    );

    await tester.pumpWidget(
      _wrap(
        ImportConfirmScreen(parsed: parsed),
        overrides: [
          booksProvider.overrideWith((ref) async => [owned]),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The owned book is flagged and dropped from the default selection, so only
    // the new book imports.
    expect(find.text('Ya la tienes'), findsOneWidget);
    expect(find.text('Importar 1 libro'), findsOneWidget);

    // Re-ticking the duplicate's checkbox brings the count back up to 2.
    final dupRow = find.ancestor(
      of: find.text('Ya la tienes'),
      matching: find.byType(BookRow),
    );
    await tester.tap(
      find.descendant(of: dupRow, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Importar 2 libros'), findsOneWidget);
  });

  testWidgets('confirm screen discloses rounded source ratings', (
    tester,
  ) async {
    final parsed = _parsed(
      [_book('Quarter star', BookStatus.read)],
      ratingsRounded: 1,
    );

    await tester.pumpWidget(
      _wrap(
        ImportConfirmScreen(parsed: parsed),
        overrides: [booksProvider.overrideWith((ref) async => const <Book>[])],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Se redondeó 1 valoración de StoryGraph a la media estrella más '
        'cercana porque Readendar usa medias estrellas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('search box filters the list for large imports', (tester) async {
    // 12 books (> the search threshold) so the search box appears.
    final parsed = _parsed([
      for (var i = 0; i < 11; i++) _book('Filler $i', BookStatus.pending),
      _book('Needle', BookStatus.read),
    ]);

    await tester.pumpWidget(
      _wrap(
        ImportConfirmScreen(parsed: parsed),
        overrides: [booksProvider.overrideWith((ref) async => const <Book>[])],
      ),
    );
    await tester.pumpAndSettle();

    // Type a query that only the "Needle" row matches.
    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pumpAndSettle();

    expect(find.byType(BookRow), findsOneWidget);
    expect(find.text('Needle'), findsWidgets);
    expect(find.text('Filler 0'), findsNothing);
  });

  testWidgets('progress enriches locally and lands on the completion screen', (
    tester,
  ) async {
    final search = FakeCatalogSearch(
      hits: {
        '9780439023481': SearchHit(
          title: 'Has Cover',
          authors: const ['Autor'],
          isbn: '9780439023481',
          coverUrl: 'https://covers.example/a.jpg',
        ),
        '9780451524935': SearchHit(
          title: 'Dup',
          authors: const ['Autor'],
          isbn: '9780451524935',
          coverUrl: 'https://covers.example/c.jpg',
        ),
      },
    );
    final booksRepo = FakeCatalogBooks();
    final books = [
      _book('Has Cover', BookStatus.read, isbn: '9780439023481'),
      _book('No Cover', BookStatus.pending, isbn: '9780441013593'),
      _book('Dup', BookStatus.read, isbn: '9780451524935'),
    ];

    await tester.pumpWidget(
      _wrap(
        ImportProgressScreen(books: books),
        overrides: [
          catalogImportProvider.overrideWithValue(
            CatalogImport(search: search, books: booksRepo),
          ),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
      ),
    );
    // Drive the run by hand — the completion screen's confetti animates
    // forever, so pumpAndSettle would never return.
    await tester.pump(); // mount + schedule the post-frame _run
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.byType(ImportCompleteScreen), findsOneWidget);
    expect(find.text('¡Importación completada!'), findsOneWidget);
    expect(find.text('Se añadieron 3 libros a tu biblioteca'), findsOneWidget);
    expect(find.text('Añadir 1 portada'), findsOneWidget);
    expect(search.enrichCalls, 3);
    expect(booksRepo.creates, hasLength(3));
  });

  testWidgets(
    'a failed row is retried, then offered for retry on completion',
    (tester) async {
      final search = FakeCatalogSearch(fail: true);
      final booksRepo = FakeCatalogBooks();
      final books = [
        _book('One', BookStatus.read, isbn: '9780439023481'),
        _book('Two', BookStatus.read, isbn: '9780441013593'),
      ];

      await tester.pumpWidget(
        _wrap(
          ImportProgressScreen(books: books),
          overrides: [
            catalogImportProvider.overrideWithValue(
              CatalogImport(search: search, books: booksRepo),
            ),
            booksProvider.overrideWith((ref) async => const <Book>[]),
          ],
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(search.enrichCalls, 2 * (1 + importRowRetries));
      expect(find.byType(ImportCompleteScreen), findsOneWidget);
      expect(find.text('Reintentar 2 libros'), findsOneWidget);
    },
  );

  testWidgets('dedupAgainstLibrary skips books already in the library', (
    tester,
  ) async {
    final search = FakeCatalogSearch(
      hits: {
        '9780441013593': SearchHit(
          title: 'New',
          authors: const ['Autor'],
          isbn: '9780441013593',
          coverUrl: 'https://covers.example/n.jpg',
        ),
      },
    );
    final booksRepo = FakeCatalogBooks();
    final owned = Book(
      id: 'x',
      ownerType: 'user',
      ownerId: 'u',
      title: 'Owned',
      authors: const ['Autor'],
      status: BookStatus.read,
      isbn13: '9780439023481',
    );
    final books = [
      _book('Owned', BookStatus.read, isbn: '0439023483'),
      _book('New', BookStatus.read, isbn: '9780441013593'),
    ];

    await tester.pumpWidget(
      _wrap(
        ImportProgressScreen(books: books, dedupAgainstLibrary: true),
        overrides: [
          catalogImportProvider.overrideWithValue(
            CatalogImport(search: search, books: booksRepo),
          ),
          booksProvider.overrideWith((ref) async => [owned]),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(booksRepo.creates.map((c) => c['isbn']), ['9780441013593']);
    expect(find.text('Se añadió 1 libro a tu biblioteca'), findsOneWidget);
  });

  testWidgets('runs rows concurrently and tallies them all', (tester) async {
    const count = 8;
    final search = FakeCatalogSearch();
    final booksRepo = FakeCatalogBooks(
      createDelay: const Duration(milliseconds: 20),
    );
    final books = [
      for (var i = 0; i < count; i++)
        _book('Book $i', BookStatus.read, isbn: '9780439023481'),
    ];

    await tester.pumpWidget(
      _wrap(
        ImportProgressScreen(books: books),
        overrides: [
          catalogImportProvider.overrideWithValue(
            CatalogImport(search: search, books: booksRepo),
          ),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(find.byType(ImportCompleteScreen), findsOneWidget);
    expect(
      find.text('Se añadieron $count libros a tu biblioteca'),
      findsOneWidget,
    );
    expect(booksRepo.creates, hasLength(count));
    expect(booksRepo.maxInFlight, lessThanOrEqualTo(importMaxInFlight));
    expect(booksRepo.maxInFlight, greaterThan(1));
  });
}
