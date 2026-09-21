import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/features/library/owned_book_row.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/import_sources_screen.dart';
import 'package:readendar/core/widgets/rd_reorderable_row.dart';
import 'package:readendar/features/library/library_screen.dart';
import '../../helpers/api_repo_stubs.dart';

Book _book(String id, String title, {String status = BookStatus.pending}) =>
    Book(
      id: id,
      ownerType: 'user',
      ownerId: 'user-1',
      title: title,
      authors: const ['Autor'],
      status: status,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  testWidgets('empty library import action opens the generic source hub', (
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
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar datos'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportSourcesScreen), findsOneWidget);
  });

  testWidgets('book rows are delayed drag targets and persist their order', (
    tester,
  ) async {
    final books = [_book('a', 'Alpha'), _book('b', 'Beta')];
    final repo = _RecordingBookRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => books),
          bookRepoProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme().copyWith(platform: TargetPlatform.android),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableDelayedDragStartListener), findsNWidgets(2));
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    expect(list.proxyDecorator, isNotNull);
    list.onReorderItem!(
      2,
      3,
    ); // search, section, Alpha, Beta -> Beta before Alpha
    await tester.pumpAndSettle();

    expect(repo.savedIDs, ['b', 'a']);
  });

  testWidgets(
    'windowed reorder keeps hidden books and other statuses in place',
    (tester) async {
      final books = [
        _book('r0', 'Reading 0', status: BookStatus.reading),
        _book('p1', 'Pending 1', status: BookStatus.pending),
        for (var i = 1; i <= 100; i++)
          _book('r$i', 'Reading $i', status: BookStatus.reading),
      ];
      final repo = _RecordingBookRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksProvider.overrideWith((ref) async => books),
            bookRepoProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme().copyWith(platform: TargetPlatform.android),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const LibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorderItem!(2, 3);
      await tester.pumpAndSettle();

      expect(repo.savedIDs, isNotNull);
      expect(repo.savedIDs![1], 'p1');
      expect(repo.savedIDs!.last, 'r100');
      expect(repo.savedIDs!.first, 'r1');
      expect(repo.savedIDs![2], 'r0');
    },
  );

  testWidgets('drag proxy elevates the book card without list gap fill', (
    tester,
  ) async {
    const rowSize = Size(280, 72);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return rdReorderableDragProxy(
                  context: context,
                  animation: const AlwaysStoppedAnimation<double>(1),
                  child: SizedBox.fromSize(
                    size: rowSize,
                    child: const ColoredBox(color: Colors.orange),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final elevated = tester
        .widgetList<Material>(find.byType(Material))
        .firstWhere((m) => m.elevation > 0);
    expect(elevated.color, Colors.transparent);
    expect(elevated.elevation, 6);
    expect(tester.getSize(find.byWidget(elevated)), rowSize);
  });

  testWidgets('Apple rows keep delayed whole-row drag', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final books = [_book('a', 'Alpha'), _book('b', 'Beta')];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            booksProvider.overrideWith((ref) async => books),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme().copyWith(platform: TargetPlatform.iOS),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const LibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(ReorderableDelayedDragStartListener),
        findsNWidgets(2),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('status section headers use book state colors', (tester) async {
    final books = [
      _book('r', 'Reading Now', status: BookStatus.reading),
      _book('p', 'Pending Book'),
      _book('w', 'Wanted Book', status: BookStatus.wanted),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => books),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final headers = tester
        .widgetList<SectionHeader>(find.byType(SectionHeader))
        .toList();
    final byText = {for (final h in headers) h.text: h.color};
    const c = ReadendarColors.light;
    expect(byText['Leyendo'], bookStatusColor(BookStatus.reading, c));
    expect(byText['Pendiente'], bookStatusColor(BookStatus.pending, c));
    expect(byText['Deseado'], bookStatusColor(BookStatus.wanted, c));
  });

  testWidgets('quick add keeps the sheet open and reports create failure', (
    tester,
  ) async {
    final search = _MockSearchRepository();
    final books = _MockBookRepository();
    when(() => search.search(any())).thenAnswer(
      (_) async => Ok(
        SearchPage(
          items: [
            SearchHit(title: 'Dune', authors: const ['Frank Herbert']),
          ],
          page: 1,
          limit: 20,
          hasMore: false,
        ),
      ),
    );
    when(
      () => books.create(
        title: any(named: 'title'),
        authors: any(named: 'authors'),
        coverUrl: any(named: 'coverUrl'),
        description: any(named: 'description'),
        isbn: any(named: 'isbn'),
        pageCount: any(named: 'pageCount'),
        publisher: any(named: 'publisher'),
        language: any(named: 'language'),
        categories: any(named: 'categories'),
      ),
    ).thenAnswer((_) async => const Err(UnknownFailure('offline')));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => const <Book>[]),
          searchRepoProvider.overrideWithValue(search),
          bookRepoProvider.overrideWithValue(books),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir libro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir libro').last);
    await tester.pumpAndSettle();

    expect(find.text('Dune'), findsWidgets);
    expect(find.text('Algo ha ido mal. Inténtalo de nuevo.'), findsOneWidget);
    verify(
      () => books.create(
        title: any(named: 'title'),
        authors: any(named: 'authors'),
        coverUrl: any(named: 'coverUrl'),
        description: any(named: 'description'),
        isbn: any(named: 'isbn'),
        pageCount: any(named: 'pageCount'),
        publisher: any(named: 'publisher'),
        language: any(named: 'language'),
        categories: any(named: 'categories'),
      ),
    ).called(1);
  });

  testWidgets('library windows each section and search shows every match', (
    tester,
  ) async {
    final books = [
      for (var i = 0; i < 101; i++)
        _book('r$i', 'Reading $i', status: BookStatus.reading),
      _book('p1', 'Pending one', status: BookStatus.pending),
    ];
    await tester.binding.setSurfaceSize(const Size(400, 20000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => books),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cargar más'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sectionHeaderCount')),
        matching: find.text('101'),
      ),
      findsOneWidget,
    );
    expect(find.text('Reading 100'), findsNothing);

    await tester.tap(find.byTooltip('Buscar en esta página'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(RdSearchField),
        matching: find.byType(EditableText),
      ),
      'Reading 100',
    );
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Cargar más'), findsNothing);
    expect(find.text('Reading 100'), findsWidgets);
  });

  testWidgets('collapsing a status section hides its books', (tester) async {
    final books = [
      _book('r1', 'Reading One', status: BookStatus.reading),
      _book('p1', 'Pending One'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWith((ref) async => books),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OwnedBookRow && widget.book.title == 'Reading One',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OwnedBookRow && widget.book.title == 'Pending One',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('LEYENDO'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OwnedBookRow && widget.book.title == 'Reading One',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is OwnedBookRow && widget.book.title == 'Pending One',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('sectionHeaderChevronDown')), findsOneWidget);
  });
}

class _MockSearchRepository extends Mock implements SearchRepository {}

class _MockBookRepository extends Mock implements BookRepository {}

class _RecordingBookRepository extends ApiBookRepository {
  _RecordingBookRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: SecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  List<String>? savedIDs;

  @override
  Future<Result<void>> reorder(List<String> ids) async {
    savedIDs = List<String>.of(ids);
    return const Ok<void>(null);
  }
}
