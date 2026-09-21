import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/l10n/gen/app_localizations_es.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';

void main() {
  test('wrap-up wash follows the theme and stays off paper white in dark', () {
    final dark =
        readingChapterThemeWash(ReadendarColors.dark) as LinearGradient;
    final light =
        readingChapterThemeWash(ReadendarColors.light) as LinearGradient;

    expect(dark.colors, isNot(light.colors));
    for (final color in dark.colors) {
      expect(color, isNot(ReadendarTokens.paper50));
      expect(color, isNot(ReadendarColors.dark.surfaceInv));
      expect(color.computeLuminance(), lessThan(0.45));
    }
  });

  testWidgets('unread badge fills accent in light and dark', (tester) async {
    Future<void> pumpTheme({required bool dark}) async {
      final theme = dark ? buildDarkTheme() : buildLightTheme();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: theme,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Theme(
            data: theme,
            child: const Scaffold(body: ReadingChapterUnreadBadge()),
          ),
        ),
      );
      await tester.pump();
    }

    Color badgeColor() {
      final container = tester.widget<Container>(
        find.byKey(const Key('readingChapterUnreadBadge')),
      );
      return (container.decoration as BoxDecoration).color!;
    }

    await pumpTheme(dark: false);
    expect(find.text('NUEVO'), findsOneWidget);
    expect(badgeColor(), ReadendarColors.light.accent);

    await pumpTheme(dark: true);
    expect(find.text('NUEVO'), findsOneWidget);
    expect(badgeColor(), ReadendarColors.dark.accent);
    expect(badgeColor(), isNot(ReadendarTokens.paper50));
  });

  test('visible cards drop the totals slide', () {
    const totals = ReadingChapterCard(
      id: 'totals',
      kind: 'totals',
      books: [],
      rhythm: [],
      formats: [],
    );
    const summary = ReadingChapterCard(
      id: 'summary',
      kind: 'summary',
      books: [],
      rhythm: [],
      formats: [],
    );
    expect(readingChapterVisibleCards([totals, summary]).single.id, 'summary');
  });

  test('visible readiness keeps reread grouping', () {
    const issues = [
      ReadingChapterReadinessIssue(
        kind: 'reviewGrouping',
        bookEntryId: 'same-work',
        count: 2,
      ),
      ReadingChapterReadinessIssue(
        kind: 'missingPages',
        bookEntryId: 'same-work',
        count: 1,
      ),
    ];
    expect(
      readingChapterVisibleReadiness(issues).map((issue) => issue.kind),
      ['reviewGrouping', 'missingPages'],
    );
  });

  test(
    'share labels name the highlighted book instead of repeating the card title',
    () {
      const book = ReadingChapterBook(
        entryId: 'entry-1',
        workKey: 'isbn:1',
        title: 'Circe',
        primaryAuthor: 'Madeline Miller',
        coverUrl: '',
        format: 'physical',
        categories: [],
        categoryCodes: [],
        occurrences: 1,
      );
      const card = ReadingChapterCard(
        id: 'reflection-1',
        kind: 'reflection',
        books: [book],
        rhythm: [],
        formats: [],
        reflection: ReadingChapterReflection(
          prompt: 'favorite',
          bookEntryId: 'entry-1',
          excerpt: 'exile',
          attribution: 'end',
          spoiler: true,
        ),
      );

      expect(
        readingChapterShareCardLabel(AppL10nEs(), card, const [book]),
        'Libro favorito · Circe',
      );
      expect(
        readingChapterShareCardPrimaryLabel(AppL10nEs(), card),
        'Libro favorito',
      );
      expect(readingChapterShareCardBookTitle(card, const [book]), 'Circe');
      expect(readingChapterBookFor('entry-1', const [book])?.title, 'Circe');
    },
  );

  test(
    'genre labels resolve legacy aliases like mystery to localized categories',
    () async {
      final l10n = await AppL10n.delegate.load(const Locale('es'));
      expect(
        readingChapterGenreLabel(l10n, 'mystery'),
        l10n.bookCategoryMysteryCrime,
      );
      expect(readingChapterGenreLabel(l10n, 'mystery_crime'), l10n.bookCategoryMysteryCrime);
    },
  );

  test('archetype bodies use per-archetype copy', () async {
    final l10n = await AppL10n.delegate.load(const Locale('es'));
    final keeper = readingChapterArchetypeBody(l10n, 'keeper');
    final curator = readingChapterArchetypeBody(l10n, 'curator');
    expect(keeper, isNot(equals(curator)));
    expect(keeper, contains('estanterías'));
    expect(curator, contains('otros estilos'));
    expect(readingChapterArchetypeBody(l10n, 'lantern'), l10n.readingChapterArchetypeBeaconBody);
    expect(keeper, isNot(contains('{breadth}')));
  });

  testWidgets('opening heading weaves the period into the card title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) {
            final l10n = AppL10n.of(context);
            expect(
              readingChapterOpeningHeading(
                l10n,
                context,
                ReadingChapterKind.month,
                '2026-07',
              ),
              l10n.readingChapterOpeningMonth(
                readingChapterPeriodLabel(
                  context,
                  ReadingChapterKind.month,
                  '2026-07',
                ),
              ),
            );
            expect(
              readingChapterOpeningHeading(
                l10n,
                context,
                ReadingChapterKind.year,
                '2025',
              ),
              l10n.readingChapterOpeningYear(
                readingChapterPeriodLabel(
                  context,
                  ReadingChapterKind.year,
                  '2025',
                ),
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
