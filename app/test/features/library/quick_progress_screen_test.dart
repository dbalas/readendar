import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/library_pane.dart';
import 'package:readendar/features/library/quick_progress_screen.dart';

Book _book(String id, String title) => Book(
  id: id,
  ownerType: 'user',
  ownerId: 'u1',
  title: title,
  authors: const ['Autor'],
  status: BookStatus.reading,
  pageCount: 300,
  chapterCount: 20,
);

Widget _wrap({
  required List<Book> books,
  ProgressRepository? repository,
  bool missingProgress = false,
  Object? progressError,
}) => ProviderScope(
  overrides: [
    booksProvider.overrideWith((ref) async => books),
    for (final book in books)
      progressProvider(book.id).overrideWith(
        (ref) async {
          if (progressError != null) throw progressError;
          if (missingProgress) {
            throw const FailureException(NotFoundFailure());
          }
          return Progress(
            bookEntryId: book.id,
            currentPage: 30,
            currentChapter: 2,
            currentPercentage: 10,
          );
        },
      ),
    if (repository != null) progressRepoProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: const QuickProgressScreen(initialBookId: 'b2'),
  ),
);

void main() {
  testWidgets('preselects deep-linked book and can switch reading book', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(books: [_book('b1', 'Dune'), _book('b2', 'Neuromancer')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Neuromancer'), findsAtLeastNWidgets(1));
    await tester.tap(find.byKey(const Key('quickProgressBookPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dune').last);
    await tester.pumpAndSettle();
    expect(find.text('Dune'), findsAtLeastNWidgets(1));
  });

  testWidgets('submits the same three progress fields', (tester) async {
    final repository = _FakeProgressRepository();
    await tester.pumpWidget(
      _wrap(books: [_book('b2', 'Neuromancer')], repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('progressPageField')),
      '150',
    );
    await tester.enterText(
      find.byKey(const Key('progressChapterField')),
      '8',
    );
    await tester.tap(find.byKey(const Key('progressSaveButton')));
    await tester.pump();

    expect(repository.bookId, 'b2');
    expect(repository.page, 150);
    expect(repository.percentage, 50);
    expect(repository.chapter, 8);
    expect(find.text('Progreso actualizado'), findsOneWidget);
  });

  testWidgets('creates the first progress row when GET returns not found', (
    tester,
  ) async {
    final repository = _FakeProgressRepository();
    await tester.pumpWidget(
      _wrap(
        books: [_book('b2', 'Neuromancer')],
        repository: repository,
        missingProgress: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('progressPageField')), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('progressPageField')),
      '60',
    );
    await tester.tap(find.byKey(const Key('progressSaveButton')));
    await tester.pump();

    expect(repository.bookId, 'b2');
    expect(repository.page, 60);
    expect(repository.percentage, 20);
  });

  testWidgets('progress network failure shows ErrorRetry, not a blank form', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        books: [_book('b2', 'Neuromancer')],
        progressError: const FailureException(NetworkFailure()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(find.byKey(const Key('progressPageField')), findsNothing);
  });

  testWidgets('empty reading state offers Library', (tester) async {
    final container = ProviderContainer(
      overrides: [
        booksProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const QuickProgressScreen(initialBookId: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ir a la biblioteca'), findsOneWidget);
    await tester.tap(find.text('Ir a la biblioteca'));
    await tester.pumpAndSettle();
    expect(container.read(tabIndexProvider), 1);
    expect(container.read(libraryPaneProvider), LibraryPane.books);
  });

  testWidgets('failed update stays open and exposes a localized error', (
    tester,
  ) async {
    final repository = _FakeProgressRepository()..fail = true;
    await tester.pumpWidget(
      _wrap(books: [_book('b2', 'Neuromancer')], repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('progressSaveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión. Revisa la red.'), findsOneWidget);
    expect(find.byKey(const Key('progressSaveButton')), findsOneWidget);
  });
}

class _FakeProgressRepository extends Fake implements ProgressRepository {
  String? bookId;
  int? page;
  int? percentage;
  int? chapter;
  bool fail = false;

  @override
  Future<Result<Progress>> update(
    String bookId, {
    int? page,
    int? chapter,
    int? percentage,
  }) async {
    if (fail) return const Err(NetworkFailure());
    this.bookId = bookId;
    this.page = page;
    this.percentage = percentage;
    this.chapter = chapter;
    return Ok(
      Progress(
        bookEntryId: bookId,
        currentPage: page,
        currentChapter: chapter,
        currentPercentage: percentage,
      ),
    );
  }
}
