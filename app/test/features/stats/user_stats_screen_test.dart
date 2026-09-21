import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/stats/stats_kit.dart';
import 'package:readendar/features/stats/user_stats_screen.dart';

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

(DateTime, DateTime) _periodBounds(String granularity, int offset) {
  switch (granularity) {
    case 'day':
      final day = DateTime(2026, 7, 16 + offset);
      return (day, day);
    case 'week':
      final start = DateTime(2026, 7, 13 + offset * 7);
      return (start, start.add(const Duration(days: 6)));
    case 'month':
      return (
        DateTime(2026, 7 + offset),
        DateTime(2026, 8 + offset, 0),
      );
    case 'year':
      return (DateTime(2026 + offset), DateTime(2026 + offset, 12, 31));
    case 'all':
      return (DateTime(2023), DateTime(2026, 12, 31));
    default:
      throw ArgumentError.value(granularity);
  }
}

List<Map<String, dynamic>> _pageBuckets(String granularity, int offset) {
  final (from, to) = _periodBounds(granularity, offset);
  final count = switch (granularity) {
    'day' => 1,
    'week' => 7,
    'month' => to.day,
    'year' => 12,
    'all' => to.year - from.year + 1,
    _ => 0,
  };
  return List.generate(count, (i) {
    final (start, end) = switch (granularity) {
      'day' => (from, from),
      'week' || 'month' => (
        from.add(Duration(days: i)),
        from.add(Duration(days: i)),
      ),
      'year' => (
        DateTime(from.year, i + 1),
        DateTime(from.year, i + 2, 0),
      ),
      'all' => (DateTime(from.year + i), DateTime(from.year + i, 12, 31)),
      _ => (from, to),
    };
    final pages = switch (granularity) {
      'week' => const [20, 30, 40, 50, 0, 0, 0][i],
      'month' =>
        i == 0
            ? 20
            : i == 15
            ? 120
            : 0,
      'year' =>
        i < 6
            ? 10
            : i == 6
            ? 80
            : 0,
      'all' => const [1000, 1500, 1600, 140][i],
      _ => 120,
    };
    final isFuture =
        offset == 0 &&
        switch (granularity) {
          'week' || 'month' => start.isAfter(DateTime(2026, 7, 16)),
          'year' => start.isAfter(DateTime(2026, 7)),
          _ => false,
        };
    return {
      'startDate': _date(start),
      'endDate': _date(end),
      'pages': pages,
      'isFuture': isFuture,
    };
  });
}

Map<String, dynamic> _sampleMap({
  String granularity = 'month',
  int offset = 0,
}) {
  final (from, to) = _periodBounds(granularity, offset);
  final totalPages = switch (granularity) {
    'all' => 4240,
    _ => 140,
  };
  final averagePages = switch (granularity) {
    'day' => 120.0,
    'week' => 35.0,
    'month' => offset == 0 ? 8.75 : 140.0 / to.day,
    'year' => offset == 0 ? 20.0 : 140.0 / 12.0,
    'all' => 1060.0,
    _ => 0.0,
  };
  return {
    'summary': {
      'booksRead': 12,
      'booksReading': 2,
      'booksQueued': 5,
      'booksWanted': 3,
      'booksAbandoned': 1,
      'totalBooks': 20,
      'finishedBookPages': 4200,
      'readingSince': '2025-09-01T00:00:00Z',
    },
    'overview': {
      'year': 2026,
      'finishedBooks': 9,
      'loggedPages': 2860,
      'activeDays': 74,
      'currentDayStreak': 6,
      'longestDayStreak': 12,
      'previousYearPages': 2383,
      'changePercent': 20.0,
      'monthly': [
        for (var month = 1; month <= 12; month++)
          {
            'month': '2026-${month.toString().padLeft(2, '0')}',
            'books': month <= 7 ? (month % 3) + 1 : 0,
            'pages': month <= 7 ? 240 + month * 35 : 0,
          },
      ],
    },
    'activity': {
      'finished30': 2,
      'finishedYear': 9,
      'added30': 3,
      'currentStreak': 3,
      'longestStreak': 5,
      'bestMonth': '2026-03',
      'bestMonthCount': 4,
      'monthly': [
        {'month': '2026-04', 'count': 1},
        {'month': '2026-05', 'count': 2},
        {'month': '2026-06', 'count': 1},
      ],
    },
    'pageActivity': {
      'granularity': granularity,
      'offset': offset,
      'from': _date(from),
      'to': _date(to),
      'totalPages': totalPages,
      'todayPages': 120,
      'previousPages': granularity == 'all' ? null : 100,
      'averagePages': averagePages,
      'activeBuckets': switch (granularity) {
        'week' => 4,
        'month' => 2,
        'year' => 7,
        'all' => 4,
        _ => 1,
      },
      'activeDays': switch (granularity) {
        'week' => 4,
        'month' => 2,
        'year' => 50,
        'all' => 300,
        _ => 1,
      },
      'buckets': _pageBuckets(granularity, offset),
    },
    'taste': {
      'scope': 'year',
      'completedCount': 9,
      'topGenres': [
        {
          'code': 'fantasy',
          'genre': 'Fantasía',
          'count': 6,
          'ratedCount': 5,
          'avgRating': 4.6,
        },
        {
          'code': 'history',
          'genre': 'Historia',
          'count': 2,
          'ratedCount': 2,
          'avgRating': 3.8,
        },
      ],
      'topAuthors': [
        {'author': 'Herbert', 'count': 3, 'ratedCount': 3, 'avgRating': 4.7},
      ],
      'avgRating': 4.2,
      'ratedCount': 8,
      'highRatingPercent': 75,
      'ratingDistribution': [
        {'rating': 1, 'count': 0},
        {'rating': 2, 'count': 1},
        {'rating': 3, 'count': 1},
        {'rating': 4, 'count': 3},
        {'rating': 5, 'count': 3},
      ],
      'formats': [
        {'format': 'physical', 'count': 5},
        {'format': 'ebook', 'count': 3},
        {'format': 'audiobook', 'count': 1},
      ],
    },
  };
}

// A phone-width, tall viewport so the whole lazy dashboard builds while still
// exercising the segmented control and period chart at realistic constraints.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  UserStats stats, {
  ThemeData? theme,
  Future<UserStats> Function(PageActivityQuery query)? pageStatsLoader,
}) async {
  _tallViewport(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userStatsProvider.overrideWith((ref) async => stats),
        userPageStatsProvider.overrideWith((ref, query) async {
          if (pageStatsLoader != null) return pageStatsLoader(query);
          return UserStats.fromJson(
            _sampleMap(
              granularity: query.granularity.apiValue,
              offset: query.offset,
            ),
          );
        }),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: theme ?? buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const UserStatsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('page activity query has value equality for Riverpod family keys', () {
    expect(const PageActivityQuery().granularity, PageGranularity.month);
    expect(
      const PageActivityQuery(
        granularity: PageGranularity.week,
        offset: -2,
        tasteScope: TasteScope.all,
      ),
      const PageActivityQuery(
        granularity: PageGranularity.week,
        offset: -2,
        tasteScope: TasteScope.all,
      ),
    );
  });

  testWidgets('home shows the overview and a navigation row per section', (
    tester,
  ) async {
    await _pump(tester, UserStats.fromJson(_sampleMap()));

    // Overview block at the top (es locale).
    expect(find.text('Resumen'), findsOneWidget);
    expect(find.text('9'), findsWidgets); // books finished this year
    expect(find.text('2.860'), findsOneWidget); // real logged page deltas
    expect(find.text('74'), findsOneWidget); // active reading days
    expect(find.textContaining('+20%'), findsOneWidget); // year comparison
    expect(find.byType(BooksPagesTrendChart), findsOneWidget);
    expect(find.byType(DistributionPanel), findsOneWidget);
    expect(find.byKey(const Key('distribution-panel-bar')), findsOneWidget);
    final compositionBarSize = tester.getSize(
      find.byKey(const Key('distribution-panel-bar')),
    );
    expect(compositionBarSize.width, greaterThan(300));
    expect(compositionBarSize.height, 18);
    expect(
      find.descendant(
        of: find.byKey(const Key('distribution-panel-bar')),
        matching: find.byType(DecoratedBox),
      ),
      findsNWidgets(5),
    );

    // One tappable row per remaining section.
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('140 págs.'), findsOneWidget);
    expect(find.text('Lectura actual'), findsNothing);
    expect(find.text('Ritmo y hábitos'), findsNothing);
    expect(find.text('Gustos'), findsOneWidget);

    // Detail values live behind navigation, not on the home screen.
    expect(find.text('Dune'), findsNothing);
  });

  testWidgets(
    'activity detail pivots page totals and exposes range navigation',
    (
      tester,
    ) async {
      await _pump(tester, UserStats.fromJson(_sampleMap()));

      await tester.tap(find.text('Actividad'));
      await tester.pumpAndSettle();

      expect(find.text('Semana'), findsOneWidget);
      expect(find.text('Mes'), findsOneWidget);
      expect(find.text('Año'), findsOneWidget);
      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('Día'), findsNothing);
      expect(find.text('Páginas'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Días de lectura'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
      expect(find.text('Periodo anterior'), findsWidgets);
      expect(find.text('Ritmo'), findsNothing);
      expect(find.text('julio de 2026'), findsOneWidget);
      final periodNavigation = find.byKey(
        const ValueKey('page-activity-period-navigation'),
      );
      final periodNavigationHeight = tester.getSize(periodNavigation).height;
      expect(periodNavigationHeight, kMinInteractiveDimension);
      expect(
        tester.widgetList<MetricGrid>(find.byType(MetricGrid)).first.maxColumns,
        2,
      );
      final monthChart = tester
          .widgetList<BarTrendChart>(find.byType(BarTrendChart))
          .first;
      expect(monthChart.showYAxis, isTrue);
      expect(monthChart.values, hasLength(31));
      expect(monthChart.mutedIndices, containsAll(<int>{16, 30}));
      expect(monthChart.mutedIndices, isNot(contains(15)));
      final heatmap = tester.widget<ReadingHeatmap>(
        find.byType(ReadingHeatmap),
      );
      expect(heatmap.days, hasLength(31));
      expect(heatmap.days.where((day) => day.value == 0), isNotEmpty);
      expect(heatmap.days.first.label, contains('págs.'));
      final heatmapCell = find.byTooltip(heatmap.days.first.label);
      final heatmapCellSize = tester.getSize(heatmapCell);
      expect(heatmapCellSize.width, closeTo(heatmapCellSize.height, 0.01));
      expect(find.byTooltip('Periodo siguiente'), findsOneWidget);

      await tester.tap(find.byTooltip('Periodo anterior'));
      await tester.pumpAndSettle();
      expect(find.text('junio de 2026'), findsOneWidget);
      expect(
        tester
            .widgetList<BarTrendChart>(find.byType(BarTrendChart))
            .first
            .values,
        hasLength(30),
      );

      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();
      expect(find.text('13 jul 2026 – 19 jul 2026'), findsOneWidget);
      expect(
        tester
            .widgetList<BarTrendChart>(find.byType(BarTrendChart))
            .first
            .values,
        hasLength(7),
      );

      await tester.tap(find.byTooltip('Periodo anterior'));
      await tester.pumpAndSettle();
      expect(find.text('6 jul 2026 – 12 jul 2026'), findsOneWidget);

      await tester.tap(find.text('Año'));
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsWidgets);
      final yearChart = tester
          .widgetList<BarTrendChart>(find.byType(BarTrendChart))
          .first;
      expect(yearChart.values, hasLength(12));
      expect(yearChart.mutedIndices, containsAll(<int>{7, 11}));
      expect(yearChart.mutedIndices, isNot(contains(6)));

      await tester.tap(find.byTooltip('Periodo anterior'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsWidgets);
      expect(find.byTooltip('Periodo siguiente'), findsOneWidget);

      await tester.tap(find.text('Todo'));
      await tester.pumpAndSettle();
      expect(find.text('2023 – 2026'), findsOneWidget);
      expect(
        tester
            .widgetList<BarTrendChart>(find.byType(BarTrendChart))
            .first
            .values,
        hasLength(4),
      );
      expect(find.byTooltip('Periodo anterior'), findsNothing);
      expect(find.byTooltip('Periodo siguiente'), findsNothing);
      expect(
        tester.getSize(periodNavigation).height,
        periodNavigationHeight,
      );
      expect(
        tester.widgetList<MetricGrid>(find.byType(MetricGrid)).first.maxColumns,
        2,
      );
    },
  );

  testWidgets('period changes keep the shell while the inner panel fades', (
    tester,
  ) async {
    await _pump(
      tester,
      UserStats.fromJson(_sampleMap()),
      pageStatsLoader: (query) async {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        return UserStats.fromJson(
          _sampleMap(
            granularity: query.granularity.apiValue,
            offset: query.offset,
          ),
        );
      },
    );

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semana'));
    await tester.pump();

    // The shell and granularity selector remain mounted while only the
    // period panel is refreshed. The last result stays in place while the
    // request is pending, so a spinner/panel is never stacked over the chart.
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('13 jul 2026 – 19 jul 2026'), findsOneWidget);
  });

  testWidgets('metrics section chevrons stay readable in dark mode', (
    tester,
  ) async {
    await _pump(
      tester,
      UserStats.fromJson(_sampleMap()),
      theme: buildDarkTheme(),
    );

    final chevrons = tester
        .widgetList<Icon>(find.byIcon(LucideIcons.chevronRight))
        .toList();
    expect(chevrons, isNotEmpty);
    for (final icon in chevrons) {
      expect(icon.color, ReadendarColors.dark.fg3);
    }
  });

  testWidgets('activity chart renders in dark theme without overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      UserStats.fromJson(_sampleMap()),
      theme: buildDarkTheme(),
    );
    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(find.text('Páginas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty page history keeps the chart without an extra notice', (
    tester,
  ) async {
    final map = _sampleMap();
    map['pageActivity'] = {
      'granularity': 'month',
      'offset': 0,
      'from': '2026-07-01',
      'to': '2026-07-31',
      'totalPages': 0,
      'todayPages': 0,
      'previousPages': 0,
      'averagePages': 0,
      'activeBuckets': 0,
      'activeDays': 0,
      'buckets': [
        for (final bucket in _pageBuckets('month', 0)) {...bucket, 'pages': 0},
      ],
    };
    await _pump(
      tester,
      UserStats.fromJson(map),
      pageStatsLoader: (_) async => UserStats.fromJson(map),
    );
    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Tu actividad aparecerá cuando actualices la página de un libro.',
      ),
      findsNothing,
    );
    expect(find.byType(BarTrendChart), findsWidgets);
  });

  testWidgets('missing server activity never renders a 1970 range', (
    tester,
  ) async {
    final map = _sampleMap()..remove('pageActivity');
    await _pump(tester, UserStats.fromJson(map));
    expect(find.text('—'), findsWidgets);
    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'La actividad de páginas no está disponible con esta versión del servidor.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('1970'), findsNothing);
  });

  testWidgets('taste detail shows ratings, affinity, formats, and scope', (
    tester,
  ) async {
    PageActivityQuery? requested;
    await _pump(
      tester,
      UserStats.fromJson(_sampleMap()),
      pageStatsLoader: (query) async {
        requested = query;
        final map = _sampleMap();
        (map['taste'] as Map<String, dynamic>)['scope'] =
            query.tasteScope.apiValue;
        return UserStats.fromJson(map);
      },
    );

    await tester.tap(find.text('Gustos'));
    await tester.pumpAndSettle();

    expect(find.text('Fantasía'), findsOneWidget);
    expect(find.text('Herbert'), findsOneWidget);
    expect(find.text('Este año'), findsNothing);
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Papel'), findsOneWidget);
    expect(find.text('Ebook'), findsOneWidget);
    expect(find.byType(BarTrendChart), findsOneWidget);
    expect(
      tester.widget<BarTrendChart>(find.byType(BarTrendChart)).showYAxis,
      isTrue,
    );
    expect(find.byType(DonutDistributionPanel), findsOneWidget);
    expect(find.text('Autores repetidos'), findsWidgets);

    await tester.tap(find.text('Histórico'));
    await tester.pumpAndSettle();
    expect(requested?.tasteScope, TasteScope.all);
  });
}
