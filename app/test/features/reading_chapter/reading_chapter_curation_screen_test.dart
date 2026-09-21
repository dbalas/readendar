import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/data/reading_chapter_repository.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_curation_screen.dart';

void main() {
  for (final failure in [false, true]) {
    testWidgets(
      'curation save ${failure ? 'shows localized failure and stays open' : 'preserves attribution-only approval and confirms success'}',
      (tester) async {
        final story = _story();
        final repository = _CurationRepository(
          result: failure
              ? const Err(NetworkFailure())
              : Ok<ReadingChapterStory>(story),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              readingChapterRepoProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              locale: const Locale('es'),
              theme: buildLightTheme(),
              localizationsDelegates: AppL10n.localizationsDelegates,
              supportedLocales: AppL10n.supportedLocales,
              home: ReadingChapterCurationScreen(story: story),
            ),
          ),
        );
        final l = AppL10n.of(
          tester.element(find.byType(ReadingChapterCurationScreen)),
        );

        expect(
          find.byKey(const Key('readingChapterHighlightBook-favorite')),
          findsOneWidget,
        );
        expect(find.text(l.readingChapterPromptFavorite), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('readingChapterHighlightBook-favorite')),
            matching: find.text('Matilda'),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('readingChapterHighlightBook-favorite')),
            matching: find.text(l.readingChapterPromptFavorite),
          ),
          findsNothing,
        );

        await tester.tap(find.text(l.readingChapterPromptFavorite));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('readingChapterHighlightBook-favorite')),
          findsNothing,
        );
        expect(find.text(l.readingChapterExcerptOptional), findsNothing);
        expect(find.text(l.readingChapterAttributionOptional), findsNothing);

        await tester.tap(find.text(l.readingChapterPromptFavorite));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('readingChapterHighlightBook-favorite')),
          findsOneWidget,
        );
        expect(find.text(l.readingChapterAttributionOptional), findsOneWidget);

        await tester.tap(find.text(l.actionSave));
        await tester.pump();

        expect(repository.calls, 1);
        expect(repository.expectedSourceRevision, '12-3');
        expect(repository.reflections.single.attribution, 'Chapter 12');
        expect(repository.safeToRevealPrompts, contains('favorite'));
        expect(find.text(l.readingChapterSafeToReveal), findsOneWidget);
        expect(find.text(l.readingChapterSafeToRevealBody), findsOneWidget);
        expect(
          find.text(
            failure ? l.errorNetwork : l.readingChapterHighlightsSaved,
          ),
          findsOneWidget,
        );
        if (failure) {
          expect(find.byType(ReadingChapterCurationScreen), findsOneWidget);
        }
      },
    );
  }
}

ReadingChapterStory _story() {
  const book = ReadingChapterBook(
    entryId: '00000000-0000-4000-8000-000000000001',
    workKey: 'isbn:9780140328721',
    title: 'Matilda',
    primaryAuthor: 'Roald Dahl',
    coverUrl: '',
    format: 'physical',
    categories: ['Ficción'],
    categoryCodes: ['fiction'],
    occurrences: 1,
  );
  return ReadingChapterStory(
    schemaVersion: 1,
    archetypeRuleVersion: 1,
    sourceRevision: '12-3',
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
    cards: const [
      ReadingChapterCard(
        id: 'cover-mosaic',
        kind: 'coverMosaic',
        books: [book],
        rhythm: [],
        formats: [],
      ),
    ],
    readiness: const [],
    curation: const [
      ReadingChapterReflection(
        prompt: 'favorite',
        bookEntryId: '00000000-0000-4000-8000-000000000001',
        excerpt: '',
        attribution: 'Chapter 12',
        spoiler: false,
      ),
    ],
  );
}

class _CurationRepository extends Fake implements ReadingChapterRepository {
  _CurationRepository({required this.result});

  final Result<ReadingChapterStory> result;
  int calls = 0;
  String expectedSourceRevision = '';
  List<ReadingChapterReflection> reflections = const [];
  Set<String> safeToRevealPrompts = const {};

  @override
  Future<Result<ReadingChapterStory>> saveCuration(
    ReadingChapterRequest request, {
    required String expectedSourceRevision,
    required List<ReadingChapterReflection> reflections,
    required Set<String> safeToRevealPrompts,
  }) async {
    calls++;
    this.expectedSourceRevision = expectedSourceRevision;
    this.reflections = reflections;
    this.safeToRevealPrompts = safeToRevealPrompts;
    return result;
  }
}
