import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/progress_widget_preview.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:readendar/features/widget/widget_preview.dart';

Widget _wrap(WidgetSummary summary, {ThemeData? theme}) => ProviderScope(
  overrides: [
    widgetSummaryProvider.overrideWith((ref) async => summary),
  ],
  child: MaterialApp(
    locale: const Locale('es'),
    theme: theme ?? buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: const Scaffold(body: ProgressWidgetPreview()),
  ),
);

void main() {
  testWidgets(
    'reuses widget chrome and shows compact progress with book switching',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const WidgetSummary(
            readingBooks: [
              WidgetBook(
                id: 'b1',
                title: 'Dune',
                author: 'Frank Herbert',
                coverUrl: '',
                progressPct: 40,
                currentPage: 120,
                pageCount: 300,
                currentChapter: 7,
                chapterCount: 20,
              ),
              WidgetBook(
                id: 'b2',
                title: 'Neuromancer',
                author: 'William Gibson',
                coverUrl: '',
              ),
            ],
            events: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dune'), findsAtLeastNWidgets(1));
      expect(find.text('120 / 300'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('7 / 20'), findsOneWidget);
      expect(find.byType(ReadendarWidgetPreviewFrame), findsOneWidget);
      expect(find.byType(ReadendarWidgetWordmark), findsOneWidget);
      expect(find.byType(ReadendarWidgetHeader), findsOneWidget);
      expect(
        find.byKey(const Key('readendarWidgetReadingStrip')),
        findsOneWidget,
      );
      expect(find.text('1/2  ›'), findsNothing);
      expect(find.byKey(const Key('progressWidgetBookCard')), findsOneWidget);
      final card = tester.widget<RdCard>(
        find.byKey(const Key('progressWidgetBookCard')),
      );
      expect(card.padding, const EdgeInsets.fromLTRB(12, 10, 12, 10));
      expect(
        tester.widget<BookCover>(find.byType(BookCover)).size,
        BookCoverSize.xs,
      );
      expect(
        find.byKey(const Key('progressWidgetProgressBar')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('progressWidgetAction')), findsOneWidget);
      expect(find.byKey(const Key('progressWidgetDecrease')), findsNothing);
      expect(find.byKey(const Key('progressWidgetField')), findsNothing);
      expect(find.byKey(const Key('progressWidgetIncrease')), findsNothing);
      expect(find.text('Actualizar progreso'), findsOneWidget);
    },
  );

  testWidgets('no reading books offers the Library route', (tester) async {
    await tester.pumpWidget(
      _wrap(const WidgetSummary(readingBooks: [], events: [])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ir a la biblioteca'), findsOneWidget);
    expect(
      find.text('Aún no estás leyendo nada.\n¡Escoge tu próximo libro!'),
      findsOneWidget,
    );
  });

  testWidgets('renders the full progress preview in dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WidgetSummary(
          readingBooks: [
            WidgetBook(
              id: 'b1',
              title: 'Dune',
              author: 'Frank Herbert',
              coverUrl: '',
              progressPct: 40,
              currentPage: 120,
              pageCount: 300,
              currentChapter: 7,
              chapterCount: 20,
            ),
          ],
          events: [],
        ),
        theme: buildDarkTheme(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('120 / 300'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ethereal preview uses constellation progress language', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WidgetSummary(
          readingBooks: [
            WidgetBook(
              id: 'b1',
              title: 'Dune',
              author: 'Frank Herbert',
              coverUrl: '',
              currentPage: 120,
              pageCount: 300,
            ),
          ],
          events: [],
        ),
        theme: buildLightTheme(themeId: ReadendarThemeId.ethereal),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('etherealLinearProgress')), findsOneWidget);
    expect(find.byKey(const Key('progressWidgetProgressBar')), findsOneWidget);
  });

  testWidgets('derives the progress bar from pages when percentage is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WidgetSummary(
          readingBooks: [
            WidgetBook(
              id: 'b1',
              title: 'Dune',
              author: 'Frank Herbert',
              coverUrl: '',
              currentPage: 75,
              pageCount: 300,
            ),
          ],
          events: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('progressWidgetProgressBar')),
    );
    expect(bar.value, .25);
  });

  testWidgets(
    'derives percentage from pages when stored percentage disagrees',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const WidgetSummary(
            readingBooks: [
              WidgetBook(
                id: 'b1',
                title: 'Dune',
                author: 'Frank Herbert',
                coverUrl: '',
                progressPct: 20,
                currentPage: 120,
                pageCount: 300,
              ),
            ],
            events: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('120 / 300'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('20%'), findsNothing);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('progressWidgetProgressBar')),
      );
      expect(bar.value, .4);
    },
  );

  testWidgets('does not draw a false empty bar without measurable progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WidgetSummary(
          readingBooks: [
            WidgetBook(
              id: 'b1',
              title: 'Dune',
              author: 'Frank Herbert',
              coverUrl: '',
            ),
          ],
          events: [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('progressWidgetProgressBar')),
      findsNothing,
    );
  });
}
