import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/data/reading_chapter_repository.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_stage.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_story_screen.dart';

void main() {
  testWidgets('story cards page by swipe physics without next-card buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStory(tester, story: _story());
    final l = AppL10n.of(
      tester.element(find.byType(ReadingChapterStoryScreen)),
    );
    expect(find.text('Caminos distintos'), findsOneWidget);
    expect(find.text('Los números detrás de las páginas'), findsNothing);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text(l.readingChapterNextCard), findsNothing);
    expect(find.text(l.readingChapterPreviousCard), findsNothing);
    expect(find.byTooltip(l.actionShare), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    final segments = find.descendant(
      of: find.byType(ReadingChapterStoryProgress),
      matching: find.byType(GestureDetector),
    );
    await tester.tap(segments.at(1));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsOneWidget);
    expect(find.text(l.readingChapterNextCard), findsNothing);
  });

  testWidgets('swipe keeps the same pager and lands on the next card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpStory(tester, story: _story());
    final pageView = tester.element(find.byType(PageView));

    await tester.fling(find.byType(PageView), const Offset(-320, 0), 1200);
    await tester.pump();
    expect(tester.element(find.byType(PageView)), same(pageView));
    await tester.pumpAndSettle();

    expect(tester.element(find.byType(PageView)), same(pageView));
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets(
    'enrich sheet icons stay centered and back from a book returns to the sheet',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const bookId = '00000000-0000-4000-8000-000000000009';
      final book = Book(
        id: bookId,
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Matilda',
        authors: const ['Roald Dahl'],
        status: BookStatus.read,
      );
      await _pumpStory(
        tester,
        story: _story(
          books: const [
            ReadingChapterBook(
              entryId: bookId,
              workKey: 'isbn:9780140328721',
              title: 'Matilda',
              primaryAuthor: 'Roald Dahl',
              coverUrl: '',
              format: 'physical',
              categories: ['Ficción'],
              categoryCodes: ['fiction'],
              occurrences: 1,
            ),
          ],
          readiness: const [
            ReadingChapterReadinessIssue(
              kind: 'missingPages',
              bookEntryId: bookId,
              count: 1,
            ),
          ],
        ),
        extraOverrides: [
          bookProvider(bookId).overrideWith((ref) async => book),
          progressProvider(
            bookId,
          ).overrideWith((ref) async => Progress(bookEntryId: bookId)),
          booksProvider.overrideWith((ref) async => [book]),
          eventsForBookProvider(
            bookId,
          ).overrideWith((ref) => const AsyncValue.data(<ReadingEvent>[])),
        ],
      );
      final l = AppL10n.of(
        tester.element(find.byType(ReadingChapterStoryScreen)),
      );

      await tester.tap(find.text(l.readingChapterReadinessBanner(1)));
      await tester.pumpAndSettle();

      expect(find.text(l.readingChapterReadinessTitle), findsOneWidget);
      expect(find.text(l.readingChapterReadinessMissingPages), findsOneWidget);
      final iconBox = tester.widget<SizedBox>(
        find.byKey(const Key('readingChapterReadinessIcon-missingPages')),
      );
      expect(iconBox.width, 44);
      expect(iconBox.height, 44);
      expect(iconBox.child, isA<DecoratedBox>());
      final iconSlot = iconBox.child! as DecoratedBox;
      expect(iconSlot.child, isA<Center>());
      expect((iconSlot.child! as Center).child, isA<Icon>());

      await tester.tap(find.text(l.readingChapterReadinessMissingPages));
      await tester.pumpAndSettle();

      expect(find.byType(BookDetailScreen), findsOneWidget);
      expect(
        find.text(l.readingChapterReadinessTitle, skipOffstage: false),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(BookDetailScreen), findsNothing);
      expect(find.text(l.readingChapterReadinessTitle), findsOneWidget);
      expect(find.text(l.readingChapterReadinessMissingPages), findsOneWidget);
    },
  );

  testWidgets('enrich sheet shows reread grouping and scrolls a long list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const bookId = '00000000-0000-4000-8000-000000000009';
    final readiness = [
      const ReadingChapterReadinessIssue(
        kind: 'reviewGrouping',
        bookEntryId: bookId,
        count: 2,
      ),
      for (var i = 0; i < 12; i++)
        ReadingChapterReadinessIssue(
          kind: 'missingPages',
          bookEntryId: bookId,
          count: 1,
        ),
    ];
    await _pumpStory(
      tester,
      story: _story(
        books: const [
          ReadingChapterBook(
            entryId: bookId,
            workKey: 'isbn:9780140328721',
            title: 'Matilda',
            primaryAuthor: 'Roald Dahl',
            coverUrl: '',
            format: 'physical',
            categories: ['Ficción'],
            categoryCodes: ['fiction'],
            occurrences: 2,
          ),
        ],
        readiness: readiness,
      ),
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'story should not overflow before opening the sheet',
    );
    final l = AppL10n.of(
      tester.element(find.byType(ReadingChapterStoryScreen)),
    );

    await tester.tap(
      find.text(l.readingChapterReadinessBanner(13)),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.readingChapterReadinessTitle), findsOneWidget);
    expect(find.text(l.readingChapterReadinessGrouping), findsOneWidget);
    expect(
      find.byKey(const Key('readingChapterReadinessList')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const Key('readingChapterReadinessList')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(l.actionClose), findsOneWidget);
  });

  testWidgets('story load failure shows ErrorRetry, not the empty chapter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const request = ReadingChapterRequest(ReadingChapterKind.month, '2026-07');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readingChapterRepoProvider.overrideWithValue(_StoryRepository()),
          readingChapterStoryProvider.overrideWith(
            (ref, _) async* {
              throw const FailureException(NetworkFailure());
            },
          ),
          readingChapterLatestProvider.overrideWith(
            (ref) => Stream.value(
              const ReadingChapterArchive(
                items: [],
                nextCursor: '',
                hasUnread: false,
                capabilities: ReadingChapterCapabilities(
                  privateGeneration: true,
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const ReadingChapterStoryScreen(request: request),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ErrorRetry), findsOneWidget);
    expect(
      find.text('Este capítulo aún no tiene actividad lectora'),
      findsNothing,
    );
  });
}

Future<void> _pumpStory(
  WidgetTester tester, {
  required ReadingChapterStory story,
  List<Override> extraOverrides = const [],
}) async {
  const request = ReadingChapterRequest(ReadingChapterKind.month, '2026-07');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        readingChapterRepoProvider.overrideWithValue(_StoryRepository()),
        readingChapterStoryProvider.overrideWith(
          (ref, _) => Stream.value(story),
        ),
        readingChapterLatestProvider.overrideWith(
          (ref) => Stream.value(
            const ReadingChapterArchive(
              items: [],
              nextCursor: '',
              hasUnread: false,
              capabilities: ReadingChapterCapabilities(
                privateGeneration: true,
              ),
            ),
          ),
        ),
        ...extraOverrides,
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const ReadingChapterStoryScreen(request: request),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

ReadingChapterStory _story({
  List<ReadingChapterBook> books = const [],
  List<ReadingChapterReadinessIssue> readiness = const [],
}) => ReadingChapterStory(
  schemaVersion: 1,
  archetypeRuleVersion: 1,
  sourceRevision: '1-0',
  period: ReadingChapterPeriod(
    kind: ReadingChapterKind.month,
    key: '2026-07',
    timezone: 'UTC',
    startsAt: DateTime.utc(2026, 7),
    endsAt: DateTime.utc(2026, 8),
  ),
  reader: const ReadingChapterReader(
    displayName: 'Reader',
    locale: 'es',
  ),
  meaningful: true,
  cards: [
    ReadingChapterCard(
      id: 'journey',
      kind: 'journey',
      books: books,
      rhythm: const [],
      formats: const [],
      journey: const ReadingChapterJourney(
        started: 4,
        ongoing: 2,
        abandoned: 1,
      ),
    ),
    const ReadingChapterCard(
      id: 'summary',
      kind: 'summary',
      books: [],
      rhythm: [],
      formats: [],
      totals: ReadingChapterTotals(
        uniqueWorks: 9,
        readingOccurrences: 5,
        started: 6,
        abandoned: 1,
        ongoing: 2,
        knownPages: 1280,
        pageKnownCount: 4,
        pageTotalCount: 5,
      ),
    ),
  ],
  readiness: readiness,
  curation: const [],
);

class _StoryRepository extends Fake implements ReadingChapterRepository {
  @override
  Future<Result<void>> markViewed(ReadingChapterRequest request) async =>
      const Ok(null);
}
