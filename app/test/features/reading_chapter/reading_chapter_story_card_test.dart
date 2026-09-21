import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_story_card.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'rhythm card keeps month labels visible on ${platform.name} ${brightness.name}',
        (tester) async {
          final previous = debugDefaultTargetPlatformOverride;
          debugDefaultTargetPlatformOverride = platform;
          tester.view.physicalSize = const Size(900, 1400);
          tester.view.devicePixelRatio = 1;

          try {
            await tester.pumpWidget(
              MaterialApp(
                locale: const Locale('es'),
                theme: brightness == Brightness.light
                    ? buildLightTheme()
                    : buildDarkTheme(),
                localizationsDelegates: AppL10n.localizationsDelegates,
                supportedLocales: AppL10n.supportedLocales,
                home: const Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 520,
                      height: 680,
                      child: ReadingChapterStoryCard(
                        periodKind: ReadingChapterKind.year,
                        periodKey: '2025',
                        card: _rhythmCard,
                      ),
                    ),
                  ),
                ),
              ),
            );

            expect(find.text('Lectura por periodo'), findsOneWidget);
            expect(
              find.text("La lectura de este capítulo, repartida en el tiempo."),
              findsOneWidget,
            );
            expect(
              find.text('Some stretches were busier. Others were quieter.'),
              findsNothing,
            );
            expect(find.text(DateFormat.MMM('es').format(DateTime(2025, 1))), findsOneWidget);
            expect(find.text(DateFormat.MMM('es').format(DateTime(2025, 12))), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            debugDefaultTargetPlatformOverride = previous;
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        },
      );
    }
  }

  testWidgets('public preview conceals spoiler reflection text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 520,
            height: 680,
            child: ReadingChapterStoryCard(
              periodKind: ReadingChapterKind.year,
              periodKey: '2025',
              concealSpoilers: true,
              card: ReadingChapterCard(
                id: 'reflection-favorite',
                kind: 'reflection',
                books: [],
                rhythm: [],
                formats: [],
                reflection: ReadingChapterReflection(
                  prompt: 'favorite',
                  bookEntryId: 'b1',
                  excerpt: 'The hidden ending',
                  attribution: 'Chapter 12',
                  spoiler: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('The hidden ending'), findsNothing);
    expect(
      find.text(
        'El texto con spoilers permanece oculto en las vistas previas hasta que quien lo vea decida mostrarlo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('public preview conceals attribution-only spoiler text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 520,
            height: 680,
            child: ReadingChapterStoryCard(
              periodKind: ReadingChapterKind.year,
              periodKey: '2025',
              concealSpoilers: true,
              card: ReadingChapterCard(
                id: 'reflection-favorite',
                kind: 'reflection',
                books: [],
                rhythm: [],
                formats: [],
                reflection: ReadingChapterReflection(
                  prompt: 'favorite',
                  bookEntryId: 'b1',
                  excerpt: '',
                  attribution: 'The final chapter explains everything',
                  spoiler: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('The final chapter explains everything'), findsNothing);
    expect(
      find.text(
        'El texto con spoilers permanece oculto en las vistas previas hasta que quien lo vea decida mostrarlo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('safe attribution-only reflection remains visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 520,
            height: 680,
            child: ReadingChapterStoryCard(
              periodKind: ReadingChapterKind.month,
              periodKey: '2026-07',
              concealSpoilers: true,
              card: ReadingChapterCard(
                id: 'reflection-favorite',
                kind: 'reflection',
                books: [],
                rhythm: [],
                formats: [],
                reflection: ReadingChapterReflection(
                  prompt: 'favorite',
                  bookEntryId: 'b1',
                  excerpt: '',
                  attribution: 'Afterword note',
                  spoiler: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Afterword note'), findsOneWidget);
  });

  testWidgets('taste card uses translated genre labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 520,
            height: 680,
            child: ReadingChapterStoryCard(
              periodKind: ReadingChapterKind.year,
              periodKey: '2025',
              card: ReadingChapterCard(
                id: 'taste',
                kind: 'taste',
                books: [],
                rhythm: [],
                formats: [],
                taste: ReadingChapterTaste(
                  genres: [
                    ReadingChapterCount(key: 'fantasy', count: 4),
                  ],
                  authors: [
                    ReadingChapterCount(key: 'Ursula K. Le Guin', count: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Fantasía'), findsOneWidget);
    expect(find.text('fantasy'), findsNothing);
    expect(find.text('4'), findsWidgets);
    expect(find.text('Ursula K. Le Guin'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Géneros y autores'), findsOneWidget);
    expect(find.text('Tu constelación lectora'), findsNothing);
    expect(find.text('Los que se quedaron'), findsNothing);
  });

  testWidgets('comparison arrows paint on iOS instead of Lucide glyphs', (
    tester,
  ) async {
    final previous = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 520,
                height: 680,
                child: ReadingChapterStoryCard(
                  periodKind: ReadingChapterKind.year,
                  periodKey: '2025',
                  card: ReadingChapterCard(
                    id: 'comparison',
                    kind: 'comparison',
                    books: [],
                    rhythm: [],
                    formats: [],
                    comparison: ReadingChapterComparison(
                      previousPeriodKey: '2024',
                      uniqueWorks: 12,
                      previousUniqueWorks: 8,
                      knownPages: 2400,
                      previousKnownPages: 3100,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('readingChapterTrendUp')), findsOneWidget);
      expect(find.byKey(const Key('readingChapterTrendDown')), findsOneWidget);
      expect(find.byIcon(LucideIcons.trendingUp), findsNothing);
      expect(find.byIcon(LucideIcons.trendingDown), findsNothing);
      expect(find.text('Respecto al anterior'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(
        find.text(
          'A comparison, not a score. Reading is allowed to change shape.',
        ),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = previous;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }
  });

  testWidgets('opening card puts the period in the title instead of the footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 520,
            height: 680,
            child: ReadingChapterStoryCard(
              periodKind: ReadingChapterKind.month,
              periodKey: '2026-07',
              card: ReadingChapterCard(
                id: 'opening',
                kind: 'coverMosaic',
                books: const [
                  ReadingChapterBook(
                    entryId: 'b1',
                    workKey: 'w1',
                    title: 'Visible Book',
                    primaryAuthor: 'Visible Author',
                    coverUrl: '',
                    format: 'physical',
                    categories: [],
                    categoryCodes: [],
                    occurrences: 1,
                  ),
                ],
                rhythm: [],
                formats: [],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('ENTRE LIBROS'), findsOneWidget);
    expect(find.text('Un libro dio forma a este capítulo.'), findsOneWidget);
  });

  testWidgets('story card fill follows the active premium theme', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        theme: buildDarkTheme(themeId: ReadendarThemeId.jade),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 520,
            height: 680,
            child: ReadingChapterStoryCard(
              periodKind: ReadingChapterKind.year,
              periodKey: '2025',
              card: ReadingChapterCard(
                id: 'reflection-favorite',
                kind: 'reflection',
                books: [],
                rhythm: [],
                formats: [],
                reflection: ReadingChapterReflection(
                  prompt: 'favorite',
                  bookEntryId: 'b1',
                  excerpt: 'A remembered line',
                  attribution: 'Chapter 3',
                  spoiler: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final box = tester.widget<DecoratedBox>(
      find.byKey(const Key('reading-chapter-card-reflection')),
    );
    final gradient =
        (box.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(
      gradient.colors,
      isNot(contains(ReadendarColors.dark.highlightSoft)),
    );
    expect(
      find.byKey(const Key('reading-chapter-card-art-reflection')),
      findsNothing,
    );
  });
}

const _rhythmCard = ReadingChapterCard(
  id: 'rhythm',
  kind: 'rhythm',
  books: [],
  rhythm: [
    ReadingChapterRhythmPoint(key: '2025-01', count: 2, pages: 80),
    ReadingChapterRhythmPoint(key: '2025-02', count: 1, pages: 40),
    ReadingChapterRhythmPoint(key: '2025-03', count: 3, pages: 120),
    ReadingChapterRhythmPoint(key: '2025-04', count: 1, pages: 30),
    ReadingChapterRhythmPoint(key: '2025-05', count: 2, pages: 90),
    ReadingChapterRhythmPoint(key: '2025-06', count: 4, pages: 200),
    ReadingChapterRhythmPoint(key: '2025-07', count: 1, pages: 20),
    ReadingChapterRhythmPoint(key: '2025-08', count: 2, pages: 70),
    ReadingChapterRhythmPoint(key: '2025-09', count: 3, pages: 110),
    ReadingChapterRhythmPoint(key: '2025-10', count: 2, pages: 95),
    ReadingChapterRhythmPoint(key: '2025-11', count: 1, pages: 50),
    ReadingChapterRhythmPoint(key: '2025-12', count: 2, pages: 88),
  ],
  formats: [],
);
