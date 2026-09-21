// QuotesWidgetPreview mirrors the native quotes widget (a "READENDAR" wordmark
// header, serif-italic passage, cover/title/author footer, favorite star) and
// must stay in visual lockstep with ReadendarQuotesWidget.swift /
// ReadendarQuotesWidgetProvider.kt. It renders from the user's IN-APP quotes
// (quotesControllerProvider + booksById), resolved exactly like the native
// cache — NOT from the widget-session endpoint — so it exemplifies real data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/share/quote_card_styles.dart';
import 'package:readendar/features/widget/quotes_widget_preview.dart';
import 'package:readendar/features/widget/widget_models.dart';

import '../quotes/quotes_test_utils.dart';

Widget _wrap(
  FakeQuoteRepository repo,
  List<Book> books, {
  ThemeData? theme,
  QuotesWidgetConfig config = const QuotesWidgetConfig(),
}) => ProviderScope(
  overrides: [
    quoteRepoProvider.overrideWithValue(repo),
    booksProvider.overrideWith((ref) async => books),
  ],
  child: MaterialApp(
    theme: theme ?? buildLightTheme(),
    locale: const Locale('es'),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(
      body: Center(child: QuotesWidgetPreview(config: config)),
    ),
  ),
);

/// A repo whose listMine fails, to drive the preview's error branch.
class _FailingQuoteRepository extends FakeQuoteRepository {
  _FailingQuoteRepository() : super([]);
  @override
  Future<Result<List<Quote>>> listMine() async =>
      const Err(UnknownFailure('boom'));
}

void main() {
  test('every share-card style has a widget style (plus auto)', () {
    final widgetWires = QuoteWidgetStyle.values
        .where((s) => !s.isAuto)
        .map((s) => s.wire)
        .toSet();
    final shareNames = QuoteCardStyle.values.map((s) => s.name).toSet();
    expect(widgetWires, shareNames);
    for (final style in QuoteWidgetStyle.values) {
      if (style.isAuto) {
        expect(shareCardStyleFor(style), isNull);
      } else {
        expect(shareCardStyleFor(style)?.name, style.wire);
      }
    }
  });

  final books = [
    testBook(coverUrl: ''),
  ];

  test('dailyRotationIndex is deterministic per day and wraps by count', () {
    final day = DateTime.utc(2026, 7, 2, 15);
    final sameDay = DateTime.utc(2026, 7, 2, 23);
    expect(dailyRotationIndex(7, day), dailyRotationIndex(7, sameDay));
    final nextDay = DateTime.utc(2026, 7, 3, 1);
    expect(
      dailyRotationIndex(7, nextDay),
      (dailyRotationIndex(7, day) + 1) % 7,
    );
    expect(dailyRotationIndex(0, day), 0);
  });

  test('pickQuotesWidgetQuote filters favorites and one book', () {
    final all = [
      const WidgetQuote(
        id: 'q1',
        text: 'a',
        bookId: 'b1',
        bookTitle: 'B1',
        bookAuthor: '',
      ),
      const WidgetQuote(
        id: 'q2',
        text: 'b',
        favorite: true,
        bookId: 'b2',
        bookTitle: 'B2',
        bookAuthor: '',
      ),
    ];
    // Favorites → only q2 is a candidate.
    final fav = pickQuotesWidgetQuote(
      all,
      const QuotesWidgetConfig(mode: QuotesWidgetMode.favorites),
      DateTime.utc(2026, 7, 2),
    );
    expect(fav?.id, 'q2');
    // Fixed → the exact picked quote regardless of the clock.
    final fixed = pickQuotesWidgetQuote(
      all,
      const QuotesWidgetConfig(mode: QuotesWidgetMode.fixed, quoteId: 'q1'),
      DateTime.utc(2026, 7, 5),
    );
    expect(fixed?.id, 'q1');
  });

  test('rotation advances the pick across time buckets per cadence', () {
    final quotes = [
      for (var i = 0; i < 3; i++)
        WidgetQuote(
          id: 'q$i',
          text: 't$i',
          bookId: 'b',
          bookTitle: 'B',
          bookAuthor: '',
        ),
    ];
    // UTC → timeZoneOffset 0, so the bucket is deterministic (epoch/period).
    int idxAt(DateTime t, QuotesWidgetCadence c) {
      final q = pickQuotesWidgetQuote(
        quotes,
        QuotesWidgetConfig(cadence: c),
        t,
      )!;
      return quotes.indexWhere((e) => e.id == q.id);
    }

    // Daily: stable within the day, advances by one at the next day (cyclic).
    const daily = QuotesWidgetCadence.daily;
    expect(
      idxAt(DateTime.utc(2026, 7, 3, 8), daily),
      idxAt(DateTime.utc(2026, 7, 3, 22), daily),
      reason: 'same day → same quote',
    );
    expect(
      idxAt(DateTime.utc(2026, 7, 4, 1), daily),
      (idxAt(DateTime.utc(2026, 7, 3, 8), daily) + 1) % 3,
      reason: 'next day → next quote',
    );

    // Hourly: consecutive hours advance by exactly one.
    const hourly = QuotesWidgetCadence.hourly;
    expect(
      idxAt(DateTime.utc(2026, 7, 3, 9), hourly),
      (idxAt(DateTime.utc(2026, 7, 3, 8), hourly) + 1) % 3,
    );

    // Six-hourly: same 6h block stable, next block advances by one.
    const six = QuotesWidgetCadence.sixHourly;
    expect(
      idxAt(DateTime.utc(2026, 7, 3, 1), six),
      idxAt(DateTime.utc(2026, 7, 3, 5), six),
    );
    expect(
      idxAt(DateTime.utc(2026, 7, 3, 7), six),
      (idxAt(DateTime.utc(2026, 7, 3, 1), six) + 1) % 3,
    );
  });

  testWidgets('renders the pick with brand header, book footer + star', (
    tester,
  ) async {
    final repo = FakeQuoteRepository([
      testQuote(page: 12, favorite: true),
    ]);
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap(repo, books));
      await tester.pumpAndSettle();
    });

    expect(find.text('«El mundo era tan reciente»'), findsOneWidget);
    expect(find.text('Cien años de soledad'), findsWidgets);
    expect(find.textContaining('Gabriel García Márquez'), findsOneWidget);
    expect(find.textContaining('p. 12'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    // The brand header must be present (parity with the events widget).
    expect(find.byType(QuotesBrandWordmark), findsOneWidget);
  });

  testWidgets('renders in dark theme too', (tester) async {
    final repo = FakeQuoteRepository([
      testQuote(text: 'Cita oscura'),
    ]);
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(_wrap(repo, books, theme: buildDarkTheme()));
      await tester.pumpAndSettle();
    });
    expect(find.text('«Cita oscura»'), findsOneWidget);
  });

  testWidgets('empty library shows the add-your-first-quote state', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(FakeQuoteRepository([]), books));
    await tester.pumpAndSettle();
    expect(find.text('Añade tu primera cita'), findsOneWidget);
    // Header still shows so the empty state reads as the widget, not a blank.
    expect(find.byType(QuotesBrandWordmark), findsOneWidget);
  });

  testWidgets('notes-only library shows the add-your-first-quote state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FakeQuoteRepository([
          testQuote(text: 'una nota', category: AnnotationCategory.note),
        ]),
        books,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Añade tu primera cita'), findsOneWidget);
    expect(find.text('«una nota»'), findsNothing);
  });

  testWidgets('load error shows the error state', (tester) async {
    await tester.pumpWidget(_wrap(_FailingQuoteRepository(), books));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo actualizar'), findsOneWidget);
  });
}
