import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/quote_spoiler_refresh.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/library/book_field_cards.dart';
import 'package:readendar/features/library/rating_sheet.dart';
import 'package:readendar/features/search/search_empty_art.dart';
import 'package:readendar/features/search/search_screen.dart';
import '../../helpers/api_repo_stubs.dart';

class _FakeSearchRepo extends Fake implements SearchRepository {
  String? lastQuery;
  String? lastColumn;
  String? lastLookupIsbn;
  int? lastPage;
  bool? lastAllLanguages;
  int searchCalls = 0;
  int lookupCalls = 0;
  SearchHit? lookupHit;
  List<SearchHit> hits = const [];
  bool hasMore = false;

  /// Optional page factory for pagination tests. When null, [hits]/[hasMore]
  /// are returned for every request.
  SearchPage Function(int page, bool allLanguages)? pageFor;

  @override
  Future<Result<SearchHit?>> lookupByIsbn(String isbn) async {
    lookupCalls++;
    lastLookupIsbn = isbn;
    return Ok(lookupHit);
  }

  @override
  Future<Result<SearchPage>> search(
    String query, {
    String? column,
    int page = 1,
    int limit = 20,
    bool allLanguages = false,
  }) async {
    searchCalls++;
    lastQuery = query;
    lastColumn = column;
    lastPage = page;
    lastAllLanguages = allLanguages;
    final built = pageFor?.call(page, allLanguages);
    return Ok(
      built ??
          SearchPage(
            items: hits,
            page: page,
            limit: limit,
            hasMore: hasMore,
          ),
    );
  }
}

/// Captures the personal-field patches the consolidated book form fires on save.
class _FakeBookRepo extends Fake implements BookRepository {
  _FakeBookRepo(this.book) : createFailure = null, updateFailure = null;
  Book book;

  bool updateCalled = false;
  String? statusChangedTo;
  String? initialStatusCreated;
  int changeStatusCalls = 0;
  bool personalCalled = false;
  bool ratingReviewCalled = false;
  double? ratingSaved;
  String? reviewSaved;
  String? lastCreateCoverUrl;
  String? lastUpdateCoverUrl;
  String? lastUpdateTitle;
  List<String>? lastUpdateAuthors;
  int? lastUpdatePageCount;
  DateTime? lastUpdatePublicationDate;
  String? lastUpdatePublicationDatePrecision;
  List<CustomFieldChange>? lastCustomFieldChanges;
  int updateCalls = 0;
  Failure? updateFailure;
  Failure? createFailure;
  final createdBooks = <Book>[];

  @override
  Future<Result<Book>> update(
    String id, {
    String? title,
    List<String>? authors,
    String? coverUrl,
    String? description,
    int? pageCount,
    int? chapterCount,
    String? isbn,
    String? publisher,
    String? language,
    List<String>? categories,
    String? format,
    String? edition,
    String? binding,
    String? dimensions,
    double? msrp,
    String? msrpCurrency,
    DateTime? publicationDate,
    String? publicationDatePrecision,
    List<CustomFieldChange> customFieldChanges = const [],
  }) async {
    updateCalled = true;
    updateCalls++;
    lastUpdateCoverUrl = coverUrl;
    lastUpdateTitle = title;
    lastUpdateAuthors = authors;
    lastUpdatePageCount = pageCount;
    lastUpdatePublicationDate = publicationDate;
    lastUpdatePublicationDatePrecision = publicationDatePrecision;
    lastCustomFieldChanges = customFieldChanges;
    if (updateFailure != null) return Err(updateFailure!);
    // Mirror backend full-replace semantics: omitted title would wipe the book.
    if (title == null || title.isEmpty) {
      return const Err(ValidationFailure('title_required'));
    }
    if (authors == null || authors.isEmpty) {
      return const Err(ValidationFailure('authors_required'));
    }
    book = Book(
      id: book.id,
      ownerType: book.ownerType,
      ownerId: book.ownerId,
      title: title,
      authors: authors,
      status: book.status,
      coverUrl: coverUrl ?? book.coverUrl,
      description: description ?? book.description,
      pageCount: pageCount ?? book.pageCount,
      chapterCount: chapterCount ?? book.chapterCount,
      isbn13: book.isbn13,
      isbn10: book.isbn10,
      publisher: publisher ?? book.publisher,
      language: language ?? book.language,
      publicationDate: publicationDate ?? book.publicationDate,
      publicationDatePrecision:
          publicationDatePrecision ?? book.publicationDatePrecision,
      categories: categories ?? book.categories,
      categoryCodes: categories ?? book.categoryCodes,
      format: format ?? book.format,
      edition: edition ?? book.edition,
      binding: binding ?? book.binding,
      dimensions: dimensions ?? book.dimensions,
      msrp: msrp ?? book.msrp,
      msrpCurrency: msrpCurrency ?? book.msrpCurrency,
      rating: book.rating,
      notes: book.notes,
    );
    return Ok(book);
  }

  @override
  Future<Result<Book>> create({
    required String title,
    required List<String> authors,
    String coverUrl = '',
    String isbn = '',
    int? pageCount,
    int? chapterCount,
    String? publisher,
    String? language,
    List<String>? categories,
    String? format,
    String? description,
    String? edition,
    String? binding,
    String? dimensions,
    double? msrp,
    String? msrpCurrency,
    DateTime? publicationDate,
    String? publicationDatePrecision,
    String? initialStatus,
    List<CustomFieldChange> customFieldChanges = const [],
  }) async {
    if (createFailure != null) return Err(createFailure!);
    initialStatusCreated = initialStatus;
    lastCreateCoverUrl = coverUrl;
    lastCustomFieldChanges = customFieldChanges;
    final created = book.copyWith(status: initialStatus);
    createdBooks.add(created);
    return Ok(created);
  }

  @override
  Future<Result<Book>> get(String id) async {
    for (final created in createdBooks) {
      if (created.id == id) return Ok(created);
    }
    return Ok(book);
  }

  @override
  Future<Result<Book>> changeStatus(String id, String status) async {
    changeStatusCalls++;
    statusChangedTo = status;
    return Ok(book);
  }

  @override
  Future<Result<Book>> updatePersonal(
    String id, {
    required double? rating,
  }) async {
    personalCalled = true;
    ratingSaved = rating;
    return Ok(book);
  }

  @override
  Future<Result<Book>> updateRatingReview(
    String id, {
    required double? rating,
    required String reviewMarkdown,
  }) async {
    ratingReviewCalled = true;
    ratingSaved = rating;
    reviewSaved = reviewMarkdown;
    return Ok(book);
  }

  @override
  Future<Result<Book>> updateTotals(
    String id, {
    int? pageCount,
    int? chapterCount,
  }) async => Ok(book);
}

class _FakeCustomFieldRepo extends Fake implements CustomFieldRepository {
  _FakeCustomFieldRepo({
    required this.definitions,
    this.values = const [],
    this.layout,
  });

  final List<CustomFieldDefinition> definitions;
  final List<BookCustomField> values;
  final List<BookDetailFieldLayoutItem>? layout;

  @override
  Future<Result<List<CustomFieldDefinition>>> listDefinitions() async =>
      Ok(definitions);

  @override
  Future<Result<List<BookCustomField>>> listForBook(String bookId) async =>
      Ok(values);

  @override
  Future<Result<List<BookDetailFieldLayoutItem>>> listLayout() async => Ok(
    layout ??
        [
          for (final definition in definitions)
            BookDetailFieldLayoutItem(
              key: definition.id,
              kind: BookDetailFieldKind.custom,
              hidden: false,
            ),
          for (final key in const [
            'synopsis',
            'publisher',
            'isbn',
          ])
            BookDetailFieldLayoutItem(
              key: key,
              kind: BookDetailFieldKind.system,
              hidden: false,
            ),
        ],
  );
}

class _FakeProgressRepo extends Fake implements ProgressRepository {
  _FakeProgressRepo({this.progress, this.getGate});

  final Progress? progress;
  final Completer<void>? getGate;

  @override
  Future<Result<Progress>> get(String bookId) async {
    final gate = getGate;
    if (gate != null) await gate.future;
    return Ok(
      progress ?? Progress(bookEntryId: bookId),
    );
  }

  @override
  Future<Result<Progress>> update(
    String bookId, {
    int? page,
    int? chapter,
    int? percentage,
  }) async => Ok(
    Progress(
      bookEntryId: bookId,
      currentPage: page,
      currentChapter: chapter,
      currentPercentage: percentage,
    ),
  );
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required Book book,
  required BookRepository bookRepo,
  CustomFieldRepository? customFieldRepo,
  ProgressRepository? progressRepo,
}) async {
  // Tall viewport so the whole (lazily-built) form lays out at once.
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bookRepoProvider.overrideWithValue(bookRepo),
        progressRepoProvider.overrideWithValue(
          progressRepo ?? _FakeProgressRepo(),
        ),
        customFieldRepoProvider.overrideWithValue(
          customFieldRepo ?? _FakeCustomFieldRepo(definitions: const []),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: ManualBookFormScreen(initialBook: book),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Override _premiumSessionOverride() => sessionProvider.overrideWith((ref) {
  final notifier = SessionNotifier(ref);
  notifier.setUser(
    AppUser(
      id: '00000000-0000-4000-8000-000000000001',
      email: 'reader@example.com',
      displayName: 'Reader One',
      preferredLocale: 'es',
      timezone: 'UTC',
      onboardingCompletedAt: null,
    ),
  );
  return notifier;
});

Future<void> _pump(
  WidgetTester tester,
  SearchRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchRepoProvider.overrideWithValue(repo),
        booksProvider.overrideWith((ref) async => const <Book>[]),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const SearchScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpAddFromSearch(
  WidgetTester tester, {
  required bool useSystemBack,
}) async {
  final created = Book(
    id: 'new-dune',
    ownerType: 'user',
    ownerId: 'u1',
    title: 'Dune',
    authors: const ['Frank Herbert'],
    status: BookStatus.pending,
    isbn13: '9780441172719',
  );
  final searchRepo = _FakeSearchRepo()
    ..hits = [
      SearchHit(
        title: 'Dune',
        authors: const ['Frank Herbert'],
        isbn: '9780441172719',
      ),
    ];
  final bookRepo = _FakeBookRepo(created);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchRepoProvider.overrideWithValue(searchRepo),
        bookRepoProvider.overrideWithValue(bookRepo),
        booksProvider.overrideWith((ref) async => [...bookRepo.createdBooks]),
        progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
        customFieldRepoProvider.overrideWithValue(
          _FakeCustomFieldRepo(definitions: const []),
        ),
        upcomingEventsProvider.overrideWith(
          (ref) async => const <ReadingEvent>[],
        ),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Biblioteca')),
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push<Book>(
                  MaterialPageRoute<Book>(
                    builder: (_) => const SearchScreen(),
                  ),
                );
              },
              child: const Text('open-search'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open-search'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'Dune');
  await tester.tap(find.byTooltip('Buscar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Frank Herbert'));
  await tester.pumpAndSettle();
  expect(find.byType(ManualBookFormScreen), findsOneWidget);

  Navigator.of(tester.element(find.byType(ManualBookFormScreen))).pop(created);
  await tester.pumpAndSettle();

  expect(
    find.byType(SearchScreen, skipOffstage: false),
    findsOneWidget,
  );
  final owned = tester.widget<BookDetailScreen>(find.byType(BookDetailScreen));
  expect(owned.bookId, created.id);

  if (useSystemBack) {
    expect(await tester.binding.handlePopRoute(), isTrue);
  } else {
    await tester.tap(find.byType(BackButton));
  }
  await tester.pumpAndSettle();

  expect(find.byType(SearchScreen), findsOneWidget);
  expect(find.text('Biblioteca'), findsNothing);
  expect(find.byType(BookDetailScreen), findsNothing);
  expect(find.text('Dune'), findsWidgets);
  expect(find.text('Frank Herbert'), findsOneWidget);
  final bar = tester.widget<SearchBar>(find.byType(SearchBar));
  expect(bar.controller?.text, 'Dune');
}

void main() {
  test('custom decimal input uses API canonical separator', () {
    expect(normalizeCustomFieldDecimal('1,25', const Locale('es')), '1.25');
    expect(normalizeCustomFieldDecimal('-1.25', const Locale('en')), '-1.25');
  });

  testWidgets('shows a scan-ISBN action in the app bar', (tester) async {
    await _pump(tester, _FakeSearchRepo());

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(LucideIcons.scanBarcode),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Escanear ISBN'), findsWidgets);
  });

  testWidgets('catalog search does not autofocus on open', (tester) async {
    await _pump(tester, _FakeSearchRepo());

    final bar = tester.widget<SearchBar>(find.byType(SearchBar));
    expect(bar.autoFocus, isFalse);
    expect(bar.focusNode?.hasFocus ?? false, isFalse);
  });

  testWidgets('idle empty shows search art and add-book CTA', (tester) async {
    await _pump(tester, _FakeSearchRepo());

    expect(find.byType(SearchEmptyArt), findsOneWidget);
    expect(find.text('Escribe un título o autor para buscar.'), findsOneWidget);
    expect(find.text('Añadir libro'), findsOneWidget);
    expect(find.text('Escanear ISBN'), findsWidgets);
    expect(find.text('Buscar por foto'), findsNothing);

    await tester.tap(find.text('Añadir libro'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualBookFormScreen), findsOneWidget);
  });

  testWidgets('no-results empty keeps create-manually CTA', (tester) async {
    final repo = _FakeSearchRepo()..hits = const [];
    await _pump(tester, repo);

    await tester.enterText(find.byType(TextField).first, 'zzzz-no-match');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchEmptyArt), findsOneWidget);
    expect(find.text('Sin resultados.'), findsOneWidget);
    expect(find.text('Añadir manualmente'), findsOneWidget);
    expect(find.text('Escanear ISBN'), findsWidgets);
    expect(find.text('Buscar por foto'), findsNothing);

    await tester.tap(find.text('Añadir manualmente'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualBookFormScreen), findsOneWidget);
  });

  testWidgets('tapping a catalog hit opens the add form', (tester) async {
    final repo = _FakeSearchRepo()
      ..hits = [
        SearchHit(
          title: 'Dune',
          authors: const ['Frank Herbert'],
          isbn: '9780441172719',
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Dune');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Frank Herbert'));
    await tester.pumpAndSettle();

    expect(find.byType(ManualBookFormScreen), findsOneWidget);
    expect(find.byType(BookDetailScreen), findsNothing);
  });

  testWidgets('blank-title catalog hit falls back to add form', (tester) async {
    final repo = _FakeSearchRepo()
      ..lookupHit = SearchHit(
        title: '  ',
        authors: const ['Anon'],
        isbn: '9780765311788',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(definitions: const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(initialQuery: '9780765311788'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lookupCalls, 1);
    expect(find.byType(ManualBookFormScreen), findsOneWidget);
    expect(find.byType(BookDetailScreen), findsNothing);
  });

  testWidgets(
    'search row shows library status when the ISBN is already added',
    (
      tester,
    ) async {
      final repo = _FakeSearchRepo()
        ..hits = [
          SearchHit(
            title: 'Dune',
            authors: const ['Frank Herbert'],
            isbn: '9780441172719',
          ),
        ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepoProvider.overrideWithValue(repo),
            booksProvider.overrideWith(
              (ref) async => [
                Book(
                  id: 'owned-dune',
                  ownerType: 'user',
                  ownerId: 'u1',
                  title: 'Dune',
                  authors: const ['Frank Herbert'],
                  status: BookStatus.reading,
                  isbn13: '9780441172719',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Dune');
      await tester.tap(find.byTooltip('Buscar'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('searchHitOwnedStatus-isbn:9780441172719')),
        findsOneWidget,
      );
      expect(find.text('Leyendo'), findsOneWidget);
    },
  );

  testWidgets('search row hides status when the ISBN is not in the library', (
    tester,
  ) async {
    final repo = _FakeSearchRepo()
      ..hits = [
        SearchHit(
          title: 'Dune',
          authors: const ['Frank Herbert'],
          isbn: '9780441172719',
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith(
            (ref) async => [
              Book(
                id: 'other',
                ownerType: 'user',
                ownerId: 'u1',
                title: 'Other',
                authors: const ['A'],
                status: BookStatus.read,
                isbn13: '9780306406157',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Dune');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('searchHitOwnedStatus-isbn:9780441172719')),
      findsNothing,
    );
    expect(find.text('Leído'), findsNothing);
  });

  testWidgets('search row does not mark a title-only match as owned', (
    tester,
  ) async {
    final repo = _FakeSearchRepo()
      ..hits = [
        SearchHit(
          title: 'Dune',
          authors: const ['Frank Herbert'],
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith(
            (ref) async => [
              Book(
                id: 'owned-dune',
                ownerType: 'user',
                ownerId: 'u1',
                title: 'Dune',
                authors: const ['Frank Herbert'],
                status: BookStatus.pending,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Dune');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    expect(find.byType(BookStatusPill), findsNothing);
    expect(find.text('Pendiente'), findsNothing);
  });

  testWidgets(
    'adding from search opens owned detail; AppBar back restores listing',
    (tester) async {
      await _pumpAddFromSearch(tester, useSystemBack: false);
    },
  );

  testWidgets(
    'adding from search opens owned detail; system back restores listing',
    (tester) async {
      await _pumpAddFromSearch(tester, useSystemBack: true);
    },
  );

  testWidgets('popWhenCreated still closes search with the new book', (
    tester,
  ) async {
    Book? popped;
    final created = Book(
      id: 'picked-1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
      isbn13: '9780441172719',
    );
    final searchRepo = _FakeSearchRepo()
      ..hits = [
        SearchHit(
          title: 'Dune',
          authors: const ['Frank Herbert'],
          isbn: '9780441172719',
        ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(searchRepo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
          bookRepoProvider.overrideWithValue(_FakeBookRepo(created)),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(definitions: const []),
          ),
          upcomingEventsProvider.overrideWith(
            (ref) async => const <ReadingEvent>[],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await Navigator.of(context).push<Book>(
                    MaterialPageRoute<Book>(
                      builder: (_) => const SearchScreen(popWhenCreated: true),
                    ),
                  );
                },
                child: const Text('open-search'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Dune');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frank Herbert'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(ManualBookFormScreen)),
    ).pop(created);
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsNothing);
    expect(popped?.id, 'picked-1');
  });

  testWidgets(
    'ISBN lookup opens the add form',
    (tester) async {
      final repo = _FakeSearchRepo()
        ..lookupHit = SearchHit(
          title: 'Name of the Wind',
          authors: const ['Patrick Rothfuss'],
          isbn: '9780765311788',
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepoProvider.overrideWithValue(repo),
            booksProvider.overrideWith((ref) async => const <Book>[]),
            customFieldRepoProvider.overrideWithValue(
              _FakeCustomFieldRepo(definitions: const []),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const SearchScreen(initialQuery: '9780765311788'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repo.lookupCalls, 1);
      expect(repo.searchCalls, 0);
      expect(find.byType(ManualBookFormScreen), findsOneWidget);
      expect(find.byType(BookDetailScreen), findsNothing);
      expect(find.text('Name of the Wind'), findsWidgets);
    },
  );

  testWidgets('ISBN lookup success opens the add form', (tester) async {
    final repo = _FakeSearchRepo()
      ..lookupHit = SearchHit(
        title: 'Name of the Wind',
        authors: const ['Patrick Rothfuss'],
        isbn: '9780765311788',
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(definitions: const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(initialQuery: '9780765311788'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lookupCalls, 1);
    expect(repo.searchCalls, 0);
    expect(find.byType(ManualBookFormScreen), findsOneWidget);
    expect(find.byType(BookDetailScreen), findsNothing);
  });

  testWidgets(
    'ISBN lookup ignores shared catalog seed ids and opens the add form',
    (tester) async {
      const seedId = '00000000-0000-4000-8000-000000000099';
      final repo = _FakeSearchRepo()
        ..lookupHit = SearchHit(
          title: 'Name of the Wind',
          authors: const ['Patrick Rothfuss'],
          isbn: '9780765311788',
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchRepoProvider.overrideWithValue(repo),
            booksProvider.overrideWith((ref) async => const <Book>[]),
            customFieldRepoProvider.overrideWithValue(
              _FakeCustomFieldRepo(definitions: const []),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const SearchScreen(initialQuery: '9780765311788'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManualBookFormScreen), findsOneWidget);
      expect(find.byType(BookDetailScreen), findsNothing);
    },
  );

  testWidgets('idle empty does not overflow with keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 667);
    tester.view.devicePixelRatio = 1;
    // Short iPhone viewport plus keyboard — reproduces the overflow from Home.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.reset);

    await _pump(tester, _FakeSearchRepo());

    expect(find.byType(SearchEmptyArt), findsOneWidget);
    expect(find.text('Añadir libro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seeds query and column then searches on open', (tester) async {
    final repo = _FakeSearchRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(
            initialQuery: 'Brandon Sanderson',
            initialColumn: 'author',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lastQuery, 'Brandon Sanderson');
    expect(repo.lastColumn, 'author');
  });

  testWidgets('drops column filter once the seeded query is edited', (
    tester,
  ) async {
    final repo = _FakeSearchRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(
            initialQuery: 'Brandon Sanderson',
            initialColumn: 'author',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.lastColumn, 'author');

    await tester.enterText(find.byType(TextField).first, 'Mistborn');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    expect(repo.lastQuery, 'Mistborn');
    expect(repo.lastColumn, isNull);
  });

  testWidgets('loads more catalog pages until exhausted', (
    tester,
  ) async {
    SearchHit hit(String isbn, String title) => SearchHit(
      title: title,
      authors: const ['A'],
      isbn: isbn,
    );
    final repo = _FakeSearchRepo()
      ..pageFor = (page, allLanguages) {
        if (page == 1) {
          return SearchPage(
            items: [hit('9780000000001', 'Uno')],
            page: 1,
            limit: 20,
            hasMore: true,
          );
        }
        return SearchPage(
          items: [hit('9780000000002', 'Dos')],
          page: 2,
          limit: 20,
          hasMore: false,
        );
      };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(
            initialQuery: 'Author Name',
            initialColumn: 'author',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uno'), findsWidgets);
    expect(find.text('Dos'), findsWidgets);
    expect(find.text('Three'), findsNothing);
    expect(repo.searchCalls, 2);
    expect(repo.lastAllLanguages, isFalse);
    expect(repo.lastPage, 2);
  });

  testWidgets('ISBN seed prefers exact lookup before free-text search', (
    tester,
  ) async {
    final repo = _FakeSearchRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepoProvider.overrideWithValue(repo),
          booksProvider.overrideWith((ref) async => const <Book>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const SearchScreen(initialQuery: '9780765311788'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.lookupCalls, 1);
    expect(repo.lastLookupIsbn, '9780765311788');
    // lookup returned null → free-text fallback (preferred + all-languages).
    expect(repo.searchCalls, greaterThanOrEqualTo(1));
    expect(repo.lastQuery, '9780765311788');
    expect(repo.lastColumn, isNull);
  });

  testWidgets('edit form consolidates status and rating as cards', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
      pageCount: 412,
    );
    final repo = _FakeBookRepo(book);
    await _pumpForm(tester, book: book, bookRepo: repo);

    // Unified collapsible sections: General → Tracking → Details.
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Seguimiento'), findsOneWidget);
    expect(find.text('Detalles'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Seguimiento')).dy,
      lessThan(tester.getTopLeft(find.text('Detalles')).dy),
    );
    expect(find.text('Páginas totales'), findsOneWidget);
    expect(find.text('Capítulos totales'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Progreso actual')).dy,
      lessThan(tester.getTopLeft(find.text('Páginas totales')).dy),
    );
    // Status / rating cards match book-detail. Notes live on annotations,
    // not this form.
    expect(find.widgetWithText(BookFieldRow, 'Estado'), findsOneWidget);
    expect(find.widgetWithText(BookFieldRow, 'Pendiente'), findsOneWidget);
    expect(find.widgetWithText(BookFieldRow, 'Reseña'), findsOneWidget);
    expect(find.widgetWithText(BookFieldRow, 'Notas'), findsNothing);
    expect(find.text('Página actual'), findsOneWidget);

    // The primary save action is explicit and consistent across forms:
    // save icon + localized label, while retaining its tooltip.
    expect(find.byTooltip('Guardar'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(
      find.widgetWithIcon(RdButton, LucideIcons.save),
      findsOneWidget,
    );
  });

  testWidgets('edit form disables Save until book fields change', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
      pageCount: 412,
    );
    await _pumpForm(tester, book: book, bookRepo: _FakeBookRepo(book));

    RdButton saveButton() => tester.widget<RdButton>(
      find.widgetWithIcon(RdButton, LucideIcons.save),
    );

    expect(saveButton().onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Dune'),
      'Dune Messiah',
    );
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Dune Messiah'),
      'Dune',
    );
    await tester.pump();
    expect(saveButton().onPressed, isNull);
  });

  testWidgets('edit form Save stays disabled after clearing progress', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
      pageCount: 412,
    );
    await _pumpForm(
      tester,
      book: book,
      bookRepo: _FakeBookRepo(book),
      progressRepo: _FakeProgressRepo(
        progress: Progress(bookEntryId: book.id, currentPage: 12),
      ),
    );

    final pageField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Página actual',
    );
    expect(tester.widget<TextField>(pageField).controller?.text, '12');
    final save = tester.widget<RdButton>(
      find.widgetWithIcon(RdButton, LucideIcons.save),
    );
    expect(save.onPressed, isNull);

    await tester.enterText(pageField, '');
    await tester.pump();
    expect(
      tester
          .widget<RdButton>(find.widgetWithIcon(RdButton, LucideIcons.save))
          .onPressed,
      isNull,
    );
  });

  testWidgets('progress load does not wipe in-flight current-page edits', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
      pageCount: 412,
    );
    final gate = Completer<void>();
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(_FakeBookRepo(book)),
          progressRepoProvider.overrideWithValue(
            _FakeProgressRepo(
              progress: Progress(bookEntryId: book.id, currentPage: 10),
              getGate: gate,
            ),
          ),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(definitions: const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(initialBook: book),
        ),
      ),
    );
    await tester.pump();

    final pageField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Página actual',
    );
    await tester.enterText(pageField, '7');
    await tester.pump();
    expect(
      tester
          .widget<RdButton>(find.widgetWithIcon(RdButton, LucideIcons.save))
          .onPressed,
      isNotNull,
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(pageField).controller?.text, '7');
    expect(
      tester
          .widget<RdButton>(find.widgetWithIcon(RdButton, LucideIcons.save))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('create form keeps Save enabled with no edits', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(
            _FakeBookRepo(
              Book(
                id: 'b1',
                ownerType: 'user',
                ownerId: 'u1',
                title: 'Manual',
                authors: const ['A'],
                status: BookStatus.pending,
              ),
            ),
          ),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(definitions: const []),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const ManualBookFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(BookFieldRow, 'Notas'), findsNothing);

    final save = tester.widget<RdButton>(
      find.widgetWithIcon(RdButton, LucideIcons.save),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('edit form loads and saves custom fields with metadata', (
    tester,
  ) async {
    final book = Book(
      id: 'b-custom',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
    );
    final bookRepo = _FakeBookRepo(book);
    final fieldRepo = _FakeCustomFieldRepo(
      definitions: const [
        CustomFieldDefinition(
          id: 'field-mood',
          name: 'Mood',
          iconKey: 'sparkles',
          type: CustomFieldType.text,
          position: 0,
        ),
      ],
      values: const [
        BookCustomField(
          fieldId: 'field-mood',
          name: 'Mood',
          iconKey: 'sparkles',
          position: 0,
          source: 'personal',
          readOnly: false,
          historical: false,
          value: CustomFieldValue(
            kind: CustomFieldType.text,
            text: 'Reflective',
          ),
        ),
      ],
    );
    await _pumpForm(
      tester,
      book: book,
      bookRepo: bookRepo,
      customFieldRepo: fieldRepo,
    );

    expect(find.text('Campos personalizados'), findsNothing);
    expect(find.text('Detalles'), findsOneWidget);
    final moodField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Mood',
    );
    expect(moodField, findsOneWidget);
    expect(tester.widget<TextField>(moodField).controller?.text, 'Reflective');

    await tester.enterText(moodField, 'Hopeful');
    await tester.pump();
    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(bookRepo.updateCalled, isTrue);
    final change = bookRepo.lastCustomFieldChanges!.single;
    expect(change.fieldId, 'field-mood');
    expect(change.value?.text, 'Hopeful');
  });

  testWidgets('details section follows configured layout order', (
    tester,
  ) async {
    final book = Book(
      id: 'b-layout',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
      publisher: 'Chilton',
      description: 'Desert planet.',
    );
    final fieldRepo = _FakeCustomFieldRepo(
      definitions: const [
        CustomFieldDefinition(
          id: 'field-mood',
          name: 'Mood',
          iconKey: 'sparkles',
          type: CustomFieldType.text,
          position: 0,
        ),
      ],
      layout: const [
        BookDetailFieldLayoutItem(
          key: 'publisher',
          kind: BookDetailFieldKind.system,
          hidden: false,
        ),
        BookDetailFieldLayoutItem(
          key: 'field-mood',
          kind: BookDetailFieldKind.custom,
          hidden: false,
        ),
        BookDetailFieldLayoutItem(
          key: 'synopsis',
          kind: BookDetailFieldKind.system,
          hidden: false,
        ),
        BookDetailFieldLayoutItem(
          key: 'isbn',
          kind: BookDetailFieldKind.system,
          hidden: true,
        ),
      ],
    );
    await _pumpForm(
      tester,
      book: book,
      bookRepo: _FakeBookRepo(book),
      customFieldRepo: fieldRepo,
    );

    final publisher = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Editorial',
    );
    final mood = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'Mood',
    );
    final synopsis = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Sinopsis',
    );
    final isbn = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == 'ISBN',
    );
    expect(publisher, findsOneWidget);
    expect(mood, findsOneWidget);
    expect(synopsis, findsOneWidget);
    expect(isbn, findsNothing);
    expect(
      tester.getTopLeft(publisher).dy,
      lessThan(tester.getTopLeft(mood).dy),
    );
    expect(
      tester.getTopLeft(mood).dy,
      lessThan(tester.getTopLeft(synopsis).dy),
    );
  });

  testWidgets('details section shows every visible system field', (
    tester,
  ) async {
    final book = Book(
      id: 'b-all-fields',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
    );
    final fieldRepo = _FakeCustomFieldRepo(
      definitions: const [],
      layout: [
        for (final key in bookDetailSystemFieldKeys)
          BookDetailFieldLayoutItem(
            key: key,
            kind: BookDetailFieldKind.system,
            hidden: false,
          ),
      ],
    );
    await _pumpForm(
      tester,
      book: book,
      bookRepo: _FakeBookRepo(book),
      customFieldRepo: fieldRepo,
    );

    expect(find.text('Sinopsis'), findsWidgets);
    expect(find.text('Editorial'), findsWidgets);
    expect(find.text('Fecha de publicación'), findsWidgets);
    expect(find.text('Edición'), findsWidgets);
    expect(find.text('Encuadernación'), findsWidgets);
    expect(find.text('Formato'), findsWidgets);
    expect(find.text('Idioma'), findsWidgets);
    expect(find.text('ISBN'), findsWidgets);
    expect(find.text('Dimensiones'), findsWidgets);
    expect(find.text('Precio de lista'), findsWidgets);
    expect(find.text('Moneda'), findsWidgets);
    expect(find.text('Categorías'), findsWidgets);
  });

  testWidgets('catalog hit prefills format and binding on the form', (
    tester,
  ) async {
    final created = Book(
      id: 'b-format-hit',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Mistborn',
      authors: const ['Brandon Sanderson'],
      status: BookStatus.pending,
    );
    final repo = _FakeBookRepo(created);
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(repo),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(
              definitions: const [],
              layout: [
                for (final key in bookDetailSystemFieldKeys)
                  BookDetailFieldLayoutItem(
                    key: key,
                    kind: BookDetailFieldKind.system,
                    hidden: false,
                  ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialHit: SearchHit(
              title: 'Mistborn',
              authors: const ['Brandon Sanderson'],
              binding: 'Hardcover',
              format: BookFormat.physical,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Físico'), findsWidgets);
    expect(find.byIcon(LucideIcons.book), findsWidgets);
    await tester.ensureVisible(find.text('Físico'));
    await tester.tap(find.text('Físico'));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.circleDashed), findsOneWidget);
    expect(find.byIcon(LucideIcons.tabletSmartphone), findsOneWidget);
    expect(find.byIcon(LucideIcons.headphones), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookDashed), findsOneWidget);
    expect(find.text('Tapa dura'), findsWidgets);
    expect(find.text('Encuadernación'), findsWidgets);
  });

  testWidgets('catalog hit shows a localized binding type on the form', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(
            _FakeBookRepo(
              Book(
                id: 'b-binding-es',
                ownerType: 'user',
                ownerId: 'u1',
                title: 'Mistborn',
                authors: const ['Brandon Sanderson'],
                status: BookStatus.pending,
              ),
            ),
          ),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(
              definitions: const [],
              layout: [
                for (final key in bookDetailSystemFieldKeys)
                  BookDetailFieldLayoutItem(
                    key: key,
                    kind: BookDetailFieldKind.system,
                    hidden: false,
                  ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialHit: SearchHit(
              title: 'Mistborn',
              authors: const ['Brandon Sanderson'],
              binding: 'Hardcover',
              format: BookFormat.physical,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tapa dura'), findsWidgets);
    expect(find.text('Encuadernación'), findsWidgets);
    expect(find.text('Hardcover'), findsNothing);
  });

  testWidgets('catalog hit maps language codes onto the selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(
            _FakeBookRepo(
              Book(
                id: 'b-lang-spa',
                ownerType: 'user',
                ownerId: 'u1',
                title: 'Mistborn',
                authors: const ['Brandon Sanderson'],
                status: BookStatus.pending,
              ),
            ),
          ),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          customFieldRepoProvider.overrideWithValue(
            _FakeCustomFieldRepo(
              definitions: const [],
              layout: [
                for (final key in bookDetailSystemFieldKeys)
                  BookDetailFieldLayoutItem(
                    key: key,
                    kind: BookDetailFieldKind.system,
                    hidden: false,
                  ),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialHit: SearchHit(
              title: 'Mistborn',
              authors: const ['Brandon Sanderson'],
              language: 'spa',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bookLanguageSelector')), findsOneWidget);
    expect(find.text('Español'), findsWidgets);
    expect(find.text('spa'), findsNothing);
    await tester.tap(find.byKey(const Key('bookLanguageSelector')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bookCatalogSelect-es')), findsOneWidget);
    expect(find.byKey(const Key('bookCatalogSelect-ja')), findsOneWidget);
  });

  testWidgets('status card opens the shared selector and saves the change', (
    tester,
  ) async {
    final book = Book(
      id: 'b1',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
      pageCount: 412,
    );
    final repo = _FakeBookRepo(book);
    await _pumpForm(tester, book: book, bookRepo: repo);

    await tester.tap(find.text('Estado'));
    await tester.pumpAndSettle();
    // The option-selector sheet lists every status; pick "Leyendo".
    await tester.tap(find.text('Leyendo').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(repo.updateCalled, isTrue);
    expect(repo.statusChangedTo, BookStatus.reading);
  });

  testWidgets(
    'editing a canonical book to Read refreshes spoiler eligibility',
    (
      tester,
    ) async {
      final book = Book(
        id: 'b1',
        ownerType: 'user',
        ownerId: 'u1',
        title: 'Dune',
        authors: const ['Frank Herbert'],
        status: BookStatus.pending,
        isbn13: '9780306406157',
      );
      final repo = _FakeBookRepo(book);
      await _pumpForm(tester, book: book, bookRepo: repo);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ManualBookFormScreen)),
      );

      await tester.tap(find.text('Estado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leído').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.statusChangedTo, BookStatus.read);
      expect(container.read(quoteSpoilerEligibilityRefreshEpochProvider), 1);
    },
  );

  testWidgets(
    'rating card opens rating+review sheet and saves via rating-review',
    (
      tester,
    ) async {
      final book = Book(
        id: 'b1',
        ownerType: 'user',
        ownerId: 'u1',
        title: 'Dune',
        authors: const ['Frank Herbert'],
        status: BookStatus.pending,
        pageCount: 412,
      );
      final repo = _FakeBookRepo(book);
      await _pumpForm(tester, book: book, bookRepo: repo);

      expect(find.byType(BookRatingDisplay), findsOneWidget);
      await tester.tap(find.text('Reseña'));
      await tester.pumpAndSettle();

      expect(find.byType(HalfStarPicker), findsOneWidget);
      expect(find.byKey(const Key('rating-review-save')), findsOneWidget);
      tester.widget<HalfStarPicker>(find.byType(HalfStarPicker)).onChanged(4.5);
      await tester.pump();
      final reviewField = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(reviewField, 'Epic desert saga');
      await tester.tap(find.byKey(const Key('rating-review-save')));
      await tester.pumpAndSettle();

      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('Epic desert saga'), findsOneWidget);

      await tester.tap(find.byTooltip('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.ratingReviewCalled, isTrue);
      expect(repo.ratingSaved, 4.5);
      expect(repo.reviewSaved, 'Epic desert saga');
      expect(repo.personalCalled, isFalse);
    },
  );

  testWidgets('new personal book is created directly in selected status', (
    tester,
  ) async {
    final created = Book(
      id: 'b-new',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Dune',
      authors: const ['Frank Herbert'],
      status: BookStatus.pending,
    );
    final repo = _FakeBookRepo(created);
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(repo),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialHit: SearchHit(
              title: 'Dune',
              authors: const ['Frank Herbert'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Estado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leyendo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir libro'));
    await tester.pumpAndSettle();

    expect(repo.initialStatusCreated, BookStatus.reading);
    expect(repo.changeStatusCalls, 0);
  });

  testWidgets('new personal book can be created as wanted', (tester) async {
    final created = Book(
      id: 'b-want',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Wishlist Book',
      authors: const ['Autor'],
      status: BookStatus.pending,
      publicationDate: DateTime.utc(2006, 7),
      publicationDatePrecision: PublicationDatePrecision.month,
    );
    final repo = _FakeBookRepo(created);
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(repo),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialHit: SearchHit(
              title: 'Wishlist Book',
              authors: const ['Autor'],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Estado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deseado').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Añadir libro'));
    await tester.pumpAndSettle();

    expect(repo.initialStatusCreated, BookStatus.wanted);
    expect(repo.changeStatusCalls, 0);
  });

  testWidgets('manual create shows cover picker with upload option', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(
            _FakeBookRepo(
              Book(
                id: 'b1',
                ownerType: 'user',
                ownerId: 'u1',
                title: 'Manual',
                authors: const ['A'],
                status: BookStatus.pending,
              ),
            ),
          ),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const ManualBookFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BookCover), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.imagePlus));
    await tester.pumpAndSettle();
    expect(find.text('Buscar portadas en línea'), findsOneWidget);
    expect(find.text('Subir una foto'), findsOneWidget);
  });

  testWidgets('create uploads staged cover only after book exists', (
    tester,
  ) async {
    final coverFile = File(
      '${Directory.systemTemp.path}/readendar_cover_test.jpg',
    )..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() {
      if (coverFile.existsSync()) coverFile.deleteSync();
    });

    final created = Book(
      id: 'b-new',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Cover Book',
      authors: const ['Autor'],
      status: BookStatus.pending,
      publicationDate: DateTime.utc(2006, 7),
      publicationDatePrecision: PublicationDatePrecision.month,
    );
    final bookRepo = _FakeBookRepo(created);
    final uploadRepo = _FakeUploadRepository();

    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(bookRepo),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          uploadRepoProvider.overrideWithValue(uploadRepo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialHit: SearchHit(
              title: 'Cover Book',
              authors: const ['Autor'],
              coverUrl: 'https://covers.test/provider.jpg',
            ),
            initialLocalCoverPath: coverFile.path,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('La imagen se subirá al guardar.'), findsOneWidget);
    expect(uploadRepo.uploadBookCoverCalls, 0);

    await tester.tap(find.byTooltip('Añadir libro'));
    await tester.pumpAndSettle();

    expect(bookRepo.lastCreateCoverUrl, 'https://covers.test/provider.jpg');
    expect(uploadRepo.uploadBookCoverCalls, 1);
    expect(uploadRepo.lastBookId, 'b-new');
    expect(uploadRepo.lastFilePath, coverFile.path);
    expect(bookRepo.lastUpdateCoverUrl, 'https://cdn.test/books/cover.jpg');
    // Backend Update is a full replace — cover patch must resend metadata.
    expect(bookRepo.lastUpdateTitle, 'Cover Book');
    expect(bookRepo.lastUpdateAuthors, ['Autor']);
    expect(bookRepo.lastUpdatePublicationDate, DateTime.utc(2006, 7));
    expect(
      bookRepo.lastUpdatePublicationDatePrecision,
      PublicationDatePrecision.month,
    );
    expect(bookRepo.updateCalls, 1);
  });

  testWidgets('create surfaces cover upload failure without orphaning retry', (
    tester,
  ) async {
    final coverFile = File(
      '${Directory.systemTemp.path}/readendar_cover_fail.jpg',
    )..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() {
      if (coverFile.existsSync()) coverFile.deleteSync();
    });

    final created = Book(
      id: 'b-fail',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Fail Cover',
      authors: const ['Autor'],
      status: BookStatus.pending,
    );
    final bookRepo = _FakeBookRepo(created);
    final uploadRepo = _FakeUploadRepository(
      failure: const NetworkFailure('upload down'),
    );

    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(bookRepo),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          uploadRepoProvider.overrideWithValue(uploadRepo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialHit: SearchHit(
              title: 'Fail Cover',
              authors: const ['Autor'],
            ),
            initialLocalCoverPath: coverFile.path,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Añadir libro'));
    await tester.pumpAndSettle();

    expect(uploadRepo.uploadBookCoverCalls, 1);
    expect(bookRepo.updateCalls, 0);
    expect(find.byType(ManualBookFormScreen), findsOneWidget);
    expect(find.text('Sin conexión. Revisa la red.'), findsOneWidget);
  });

  testWidgets('edit defers cover upload until save', (tester) async {
    final coverFile = File(
      '${Directory.systemTemp.path}/readendar_cover_edit.jpg',
    )..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() {
      if (coverFile.existsSync()) coverFile.deleteSync();
    });

    final book = Book(
      id: 'b-edit',
      ownerType: 'user',
      ownerId: 'u1',
      title: 'Edit Me',
      authors: const ['Autor'],
      coverUrl: 'https://covers.test/old.jpg',
      status: BookStatus.pending,
      publicationDate: DateTime.utc(1999),
      publicationDatePrecision: PublicationDatePrecision.year,
    );
    final bookRepo = _FakeBookRepo(book);
    final uploadRepo = _FakeUploadRepository();

    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookRepoProvider.overrideWithValue(bookRepo),
          progressRepoProvider.overrideWithValue(_FakeProgressRepo()),
          uploadRepoProvider.overrideWithValue(uploadRepo),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: ManualBookFormScreen(
            initialBook: book,
            initialLocalCoverPath: coverFile.path,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(uploadRepo.uploadBookCoverCalls, 0);
    expect(find.text('La imagen se subirá al guardar.'), findsOneWidget);

    await tester.tap(find.byTooltip('Guardar'));
    await tester.pumpAndSettle();

    expect(uploadRepo.uploadBookCoverCalls, 1);
    expect(uploadRepo.lastBookId, 'b-edit');
    expect(bookRepo.lastUpdateCoverUrl, 'https://cdn.test/books/cover.jpg');
    expect(bookRepo.lastUpdateTitle, 'Edit Me');
    expect(bookRepo.lastUpdateAuthors, ['Autor']);
    expect(bookRepo.lastUpdatePublicationDate, DateTime.utc(1999));
    expect(
      bookRepo.lastUpdatePublicationDatePrecision,
      PublicationDatePrecision.year,
    );
    // Upload-before-update: one full PATCH, never a cover-only body.
    expect(bookRepo.updateCalls, 1);
  });
}

class _FakeUploadRepository extends ApiUploadRepository {
  _FakeUploadRepository({this.failure})
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  final Failure? failure;
  int uploadBookCoverCalls = 0;
  String? lastBookId;
  String? lastFilePath;

  @override
  Future<Result<String>> uploadBookCover(String bookId, String filePath) async {
    uploadBookCoverCalls++;
    lastBookId = bookId;
    lastFilePath = filePath;
    if (failure != null) return Err(failure!);
    return const Ok('https://cdn.test/books/cover.jpg');
  }
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}
