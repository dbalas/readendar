import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/l10n/gen/app_localizations_es.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/home_hero.dart';
import 'package:readendar/features/library/personal_book_delete.dart';
import 'package:readendar/features/library/status_books_screen.dart';
import 'package:readendar/features/search/search_screen.dart';

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  testWidgets('home hero shows Wanted metric and opens that status list', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: HomeHero(
            greeting: 'Hi',
            date: 'July 25',
            readingCount: 1,
            pendingCount: 2,
            wantedCount: 3,
            loading: false,
            banner: const BannerStyle.preset('periwinkle'),
            onStatusTap: (status) => tapped = status,
          ),
        ),
      ),
    );

    expect(find.text('Deseados'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Deseados'));
    await tester.pump();
    expect(tapped, BookStatus.wanted);
  });

  testWidgets('status empty state for wanted uses shared label and copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const StatusBooksScreen(status: BookStatus.wanted),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deseado'), findsOneWidget);
    expect(find.textContaining('Tu lista de deseados está vacía'), findsOneWidget);
    expect(find.byTooltip('Añadir libro'), findsOneWidget);
    expect(find.text('Añadir libro'), findsOneWidget);
    expect(find.text('Ir a la biblioteca'), findsOneWidget);
  });

  testWidgets(
    'status list scopes cover heroes away from the retained library',
    (
      tester,
    ) async {
      final book = Book(
        id: 'wanted-1',
        ownerType: OwnerType.user,
        ownerId: 'u1',
        title: 'Wanted book',
        authors: const ['Autor'],
        status: BookStatus.wanted,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksProvider.overrideWith((ref) async => [book]),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const StatusBooksScreen(status: BookStatus.wanted),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'status-wanted-book-cover-wanted-1');
    },
  );

  testWidgets('status list add button opens search with that status', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const StatusBooksScreen(status: BookStatus.reading),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir libro'));
    await tester.pumpAndSettle();

    final search = tester.widget<SearchScreen>(find.byType(SearchScreen));
    expect(search.initialStatus, BookStatus.reading);
  });

  testWidgets('empty-state add book opens search with wanted status', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const StatusBooksScreen(status: BookStatus.wanted),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(RdButton, 'Añadir libro'));
    await tester.pumpAndSettle();

    final search = tester.widget<SearchScreen>(find.byType(SearchScreen));
    expect(search.initialStatus, BookStatus.wanted);
  });

  test('bookStatusLabel covers wanted', () {
    expect(bookStatusLabel(AppL10nEs(), BookStatus.wanted), 'Deseado');
  });

  test('excludeRemovedPersonalBooks drops tombstoned ids', () {
    final kept = Book(
      id: 'keep',
      ownerType: OwnerType.user,
      ownerId: 'u1',
      title: 'Conservar',
      authors: const ['A'],
      status: BookStatus.wanted,
    );
    final gone = Book(
      id: 'gone',
      ownerType: OwnerType.user,
      ownerId: 'u1',
      title: 'Gone',
      authors: const ['A'],
      status: BookStatus.wanted,
    );
    expect(
      excludeRemovedPersonalBooks([kept, gone], {'gone'}).map((b) => b.id),
      ['keep'],
    );
  });

  testWidgets(
    'deleting from Wanted removes the row even if the list cache is stale',
    (tester) async {
      final book = Book(
        id: 'wanted-1',
        ownerType: OwnerType.user,
        ownerId: 'u1',
        title: 'Wanted book',
        authors: const ['Autor'],
        status: BookStatus.wanted,
      );
      final repo = _MockBookRepository();
      when(() => repo.delete(any())).thenAnswer((_) async => const Ok(null));

      await tester.pumpWidget(
        _wantedList(book: book, repo: repo, showTestDelete: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wanted book'), findsWidgets);

      await tester.tap(find.text('test-delete'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar este libro de la biblioteca?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      verify(() => repo.delete('wanted-1')).called(1);
      expect(find.text('Libro eliminado de tu biblioteca'), findsOneWidget);
      expect(find.text('Wanted book'), findsNothing);
      expect(find.text('Algo ha ido mal. Inténtalo de nuevo.'), findsNothing);
      expect(find.byType(StatusBooksScreen), findsOneWidget);
    },
  );

  testWidgets('failed Wanted delete keeps the book and surfaces the error', (
    tester,
  ) async {
    final book = Book(
      id: 'wanted-1',
      ownerType: OwnerType.user,
      ownerId: 'u1',
      title: 'Wanted book',
      authors: const ['Autor'],
      status: BookStatus.wanted,
    );
    final repo = _MockBookRepository();
    when(
      () => repo.delete(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));

    await tester.pumpWidget(
      _wantedList(book: book, repo: repo, showTestDelete: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('test-delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Wanted book'), findsWidgets);
    expect(find.text('Libro eliminado de tu biblioteca'), findsNothing);
    expect(find.text('Sin conexión. Revisa la red.'), findsOneWidget);
  });
}

class _MockBookRepository extends Mock implements BookRepository {}

Widget _wantedList({
  required Book book,
  required BookRepository repo,
  bool showTestDelete = false,
}) {
  return ProviderScope(
    overrides: [
      bookRepoProvider.overrideWithValue(repo),
      booksProvider.overrideWith((ref) async => [book]),
      upcomingEventsProvider.overrideWith((ref) async => const []),
      calendarEventsProvider.overrideWith((ref, _) async => const []),
      sessionProvider.overrideWith(SessionNotifier.new),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      theme: buildLightTheme(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: showTestDelete
          ? _WantedDeleteHarness(book: book)
          : const StatusBooksScreen(status: BookStatus.wanted),
    ),
  );
}

class _WantedDeleteHarness extends ConsumerWidget {
  const _WantedDeleteHarness({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const StatusBooksScreen(status: BookStatus.wanted),
        Align(
          alignment: Alignment.topCenter,
          child: TextButton(
            onPressed: () {
              unawaited(
                deletePersonalBook(context: context, ref: ref, book: book),
              );
            },
            child: const Text('test-delete'),
          ),
        ),
      ],
    );
  }
}
