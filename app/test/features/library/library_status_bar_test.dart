import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/filters/filters_state.dart';
import 'package:readendar/features/library/library_screen.dart';
import 'package:readendar/features/library/library_status_bar.dart';
import 'package:readendar/features/library/status_books_screen.dart';

Book _book(String id, String title, {String status = BookStatus.pending}) =>
    Book(
      id: id,
      ownerType: 'user',
      ownerId: 'user-1',
      title: title,
      authors: const ['Autor'],
      status: status,
    );

Future<ProviderContainer> _pumpLibrary(
  WidgetTester tester, {
  required List<Book> books,
}) async {
  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        booksProvider.overrideWith((ref) async => books),
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const LibraryScreen(),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('status bar shows an icon cell for every status', (tester) async {
    await _pumpLibrary(tester, books: [_book('a', 'Alpha')]);

    expect(find.byType(LibraryStatusBar), findsOneWidget);
    for (final status in BookStatus.all) {
      expect(find.byKey(Key('library-status-count-$status')), findsOneWidget);
    }
  });

  testWidgets('status bar shows per-status counts from the full library', (
    tester,
  ) async {
    await _pumpLibrary(
      tester,
      books: [
        _book('r1', 'Reading 1', status: BookStatus.reading),
        _book('r2', 'Reading 2', status: BookStatus.reading),
        _book('p1', 'Pending 1'),
        _book('w1', 'Wanted 1', status: BookStatus.wanted),
        _book('d1', 'Done 1', status: BookStatus.read),
        _book('d2', 'Done 2', status: BookStatus.read),
        _book('d3', 'Done 3', status: BookStatus.read),
      ],
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('library-status-count-reading')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-status-count-pending')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-status-count-wanted')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-status-count-read')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('library-status-count-abandoned')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('all status cells sit on one row', (tester) async {
    await _pumpLibrary(tester, books: [_book('a', 'Alpha')]);

    final tops = [
      for (final status in BookStatus.all)
        tester.getTopLeft(find.byKey(Key('library-status-count-$status'))).dy,
    ];
    expect(tops.toSet(), hasLength(1));
  });

  testWidgets('tapping a status cell filters the library to that status', (
    tester,
  ) async {
    final books = [
      _book('r', 'Reading Now', status: BookStatus.reading),
      _book('p', 'Pending Book'),
      _book('w', 'Wanted Book', status: BookStatus.wanted),
    ];
    final container = await _pumpLibrary(tester, books: books);

    await tester.tap(find.byKey(const Key('library-status-count-reading')));
    await tester.pumpAndSettle();

    expect(find.byType(StatusBooksScreen), findsNothing);
    expect(
      container.read(filtersProvider).bookStatuses,
      {BookStatus.reading},
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('library-status-count-reading')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(find.text('Reading Now'), findsWidgets);
    expect(find.text('Pending Book'), findsNothing);
    expect(find.text('Wanted Book'), findsNothing);

    await tester.tap(find.byKey(const Key('library-status-count-wanted')));
    await tester.pumpAndSettle();

    expect(
      container.read(filtersProvider).bookStatuses,
      {BookStatus.wanted},
    );
    expect(find.text('Wanted Book'), findsWidgets);
    expect(find.text('Reading Now'), findsNothing);
  });

  testWidgets('tapping the active status again clears the filter', (
    tester,
  ) async {
    final books = [
      _book('r', 'Reading Now', status: BookStatus.reading),
      _book('p', 'Pending Book'),
    ];
    final container = await _pumpLibrary(tester, books: books);
    container.read(filtersProvider.notifier).value = const FiltersState(
      bookStatuses: {BookStatus.reading},
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending Book'), findsNothing);

    await tester.tap(find.byKey(const Key('library-status-count-reading')));
    await tester.pumpAndSettle();

    expect(container.read(filtersProvider).bookStatuses, isEmpty);
    expect(find.text('Reading Now'), findsWidgets);
    expect(find.text('Pending Book'), findsWidgets);
  });
}
