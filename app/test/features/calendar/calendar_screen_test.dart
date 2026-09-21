import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/month_calendar.dart';
import 'package:readendar/core/widgets/rd_segmented_control.dart';
import 'package:readendar/core/widgets/skeleton.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/calendar_screen.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';
import '../../helpers/api_repo_stubs.dart';

Book _book() => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Pedro Paramo',
  authors: const ['Juan Rulfo'],
  status: BookStatus.reading,
);

ReadingEvent _event(
  String id,
  String title,
  DateTime day, {
  String type = 'page_milestone',
}) => ReadingEvent(
  id: id,
  ownerType: 'user',
  ownerId: 'user-1',
  bookId: 'book-1',
  type: type,
  title: title,
  dateLocal: day,
  status: EventStatus.active,
);

Future<void> _pump(
  WidgetTester tester,
  List<ReadingEvent> events, {
  Locale locale = const Locale('es'),
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(events.map((event) => event.id).join(',')),
      overrides: [
        calendarEventsProvider.overrideWith((ref, range) async => events),
        upcomingEventsProvider.overrideWith((ref) async => events),
        booksProvider.overrideWith((ref) async => [_book()]),
        eventRepoProvider.overrideWithValue(_SilentEventRepository()),
      ],
      child: MaterialApp(
        locale: locale,
        theme: theme ?? buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: CalendarScreen(
          key: ValueKey(events.map((event) => event.id).join(',')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, 12);

  testWidgets('calendar load failure shows ErrorRetry', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          calendarEventsProvider.overrideWith(
            (ref, range) async =>
                throw const FailureException(NetworkFailure()),
          ),
          upcomingEventsProvider.overrideWith(
            (ref) async => const <ReadingEvent>[],
          ),
          booksProvider.overrideWith((ref) async => [_book()]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ErrorRetry), findsOneWidget);
  });

  testWidgets('day 1 sits under the correct weekday header column', (
    tester,
  ) async {
    await _pump(tester, const []);

    final selectorBottom = tester
        .getBottomLeft(
          find.byType(RdSegmentedControl<CalendarView>),
        )
        .dy;
    final gridTop = tester.getTopLeft(find.byType(MonthGrid)).dy;
    expect(gridTop - selectorBottom, inInclusiveRange(8, 16));

    // Week starts on Monday (L M X J V S D). DateTime.weekday is 1=Mon..7=Sun,
    // so the Monday-relative column for day 1 is weekday - 1.
    const headers = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final firstOfMonth = DateTime(now.year, now.month);
    final expectedCol = firstOfMonth.weekday - 1;

    final dayX = tester.getCenter(find.text('1').first).dx;
    // The header column horizontally closest to day 1 must be the expected one.
    // (Robust to the small header/grid padding offset.)
    var nearestCol = 0;
    var nearestDist = double.infinity;
    for (var c = 0; c < headers.length; c++) {
      final hx = tester.getCenter(find.text(headers[c])).dx;
      final d = (dayX - hx).abs();
      if (d < nearestDist) {
        nearestDist = d;
        nearestCol = c;
      }
    }

    expect(nearestCol, expectedCol);
  });

  testWidgets('weekday header uses Spanish narrow weekday labels', (
    tester,
  ) async {
    await _pump(tester, const [], locale: const Locale('es'));
    expect(find.text('X'), findsWidgets);
    expect(find.text('W'), findsNothing);
  });

  testWidgets('tapping an empty day opens event creation', (tester) async {
    await _pump(tester, [_event('event-1', 'Read chapter 8', day)]);

    // Day 13 has no events.
    await tester.tap(find.text('13').first);
    await tester.pumpAndSettle();

    expect(find.text('Nuevo evento'), findsOneWidget);
  });

  testWidgets('future-month add button seeds the visible month', (
    tester,
  ) async {
    await _pump(tester, const []);

    await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final target = DateTime(now.year, now.month + 1);
    expect(find.text(DateFormat.yMMMd('es').format(target)), findsOneWidget);
  });

  testWidgets('root calendar FAB uses default scaffold placement', (
    tester,
  ) async {
    await _pump(
      tester,
      const [],
      theme: buildLightTheme().copyWith(platform: TargetPlatform.android),
    );

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(FloatingActionButton),
        matching: find.byType(Padding),
      ),
      findsNothing,
    );
  });

  testWidgets('tapping a day with one event opens its detail', (tester) async {
    await _pump(tester, [_event('event-1', 'Read chapter 8', day)]);

    await tester.tap(find.text('${day.day}').first);
    await tester.pumpAndSettle();

    expect(find.byType(EventDetailSheet), findsOneWidget);
  });

  testWidgets('tapping a day with several events opens the day list', (
    tester,
  ) async {
    await _pump(tester, [
      _event('event-1', 'Read chapter 8', day),
      _event('event-2', 'Discuss ending', day, type: 'deadline'),
    ]);

    await tester.tap(find.text('${day.day}').first);
    await tester.pumpAndSettle();

    expect(find.byType(DayEventsScreen), findsOneWidget);
    // Both event types are listed on the day screen.
    expect(find.text('Hito de página'), findsWidgets);
    expect(find.text('Fecha límite'), findsOneWidget);
    expect(find.text('Read chapter 8'), findsNothing);
    expect(find.text('Discuss ending'), findsNothing);
  });

  testWidgets('day list refreshes when plan events leave the calendar cache', (
    tester,
  ) async {
    final cache = CalendarEventsCache();
    final planned = ReadingEvent(
      id: 'planned',
      ownerType: 'user',
      ownerId: 'user-1',
      bookId: 'book-1',
      type: 'page_milestone',
      title: 'Planned',
      dateLocal: day,
      status: EventStatus.active,
      planId: 'p1',
    );
    final other = _event('other', 'Manual note', day, type: 'note');
    final range = CalendarEventRange(
      from: DateTime(day.year, day.month, day.day),
      to: DateTime(day.year, day.month, day.day + 1),
    );
    cache.write(range, [planned, other]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventsCacheProvider.overrideWithValue(cache),
          calendarEventsProvider.overrideWith((ref, _) async => [other]),
          booksProvider.overrideWith((ref) async => [_book()]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: DayEventsScreen(
            day: day,
            eventContext: EventRenderContext(
              personalBooks: [_book()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventCardCompact), findsNWidgets(2));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DayEventsScreen)),
    );
    container.read(calendarEventsCacheProvider).removePlanId('p1');
    container.invalidate(calendarEventsProvider(range));
    await tester.pumpAndSettle();

    expect(find.byType(EventCardCompact), findsOneWidget);
    expect(find.text('No hay eventos este día'), findsNothing);
  });

  // The reading-plan completion sets calendarFocusProvider then switches tabs.
  // The async events override resolves AFTER the first frame, so this also
  // covers the cold-mount-while-loading case (the pager isn't built on frame 1).
  testWidgets('jumps to a pending focused month once the pager is ready', (
    tester,
  ) async {
    final target = DateTime(now.year, now.month + 5);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarEventsProvider.overrideWith(
            (ref, range) async => <ReadingEvent>[],
          ),
          upcomingEventsProvider.overrideWith((ref) async => <ReadingEvent>[]),
          booksProvider.overrideWith((ref) async => [_book()]),
          calendarFocusProvider.overrideWith((ref) => target),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The month switcher renders a locale-aware "abbrev month + year" header
    // (the test app resolves to es); no technical "6/2026" string.
    expect(find.text(DateFormat.yMMM('es').format(target)), findsOneWidget);
  });

  testWidgets('the month/week/day switcher changes the view', (tester) async {
    await _pump(tester, const []);
    expect(find.text('Mes'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Día'), findsOneWidget);

    // Day view → the empty-day agenda text (not shown in the month grid).
    await tester.tap(find.text('Día'));
    await tester.pumpAndSettle();
    expect(find.text('No hay eventos este día'), findsOneWidget);

    // Back to Month → the numbered grid returns.
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    expect(find.text('No hay eventos este día'), findsNothing);
    expect(find.text('1').first, findsOneWidget);
  });

  testWidgets('empty calendar periods show related empty-state icons', (
    tester,
  ) async {
    await _pump(tester, const []);

    // The month grid is useful content by itself; only its list mode needs the
    // period placeholder.
    expect(find.byType(EmptyState), findsNothing);
    await tester.tap(find.byTooltip('Ver lista'));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No hay eventos este mes'), findsOneWidget);
    expect(
      tester.widget<EmptyState>(find.byType(EmptyState)).icon,
      LucideIcons.calendarRange,
    );

    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No hay eventos esta semana'), findsOneWidget);
    expect(
      tester.widget<EmptyState>(find.byType(EmptyState)).icon,
      LucideIcons.calendarDays,
    );

    await tester.tap(find.text('Día'));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      tester.widget<EmptyState>(find.byType(EmptyState)).icon,
      LucideIcons.calendar,
    );
  });

  testWidgets('month-list empty state aligns with the first event row', (
    tester,
  ) async {
    await _pump(tester, [_event('event-1', 'Read chapter 8', day)]);
    await tester.tap(find.byTooltip('Ver lista'));
    await tester.pumpAndSettle();
    final firstEventRowTop = tester
        .getTopLeft(find.byType(EventCardCompact))
        .dy;

    await _pump(tester, const []);
    final showList = find.byTooltip('Ver lista');
    if (showList.evaluate().isNotEmpty) {
      await tester.tap(showList);
      await tester.pumpAndSettle();
    }

    expect(
      tester.getTopLeft(find.byIcon(LucideIcons.calendarRange)).dy,
      firstEventRowTop,
    );
  });

  testWidgets('month list builds a long agenda lazily', (tester) async {
    final events = [
      for (var i = 0; i < 80; i++)
        _event(
          'event-$i',
          'Event $i',
          DateTime(now.year, now.month, 1 + (i % 28)),
        ),
    ];
    await _pump(tester, events);
    await tester.tap(find.byTooltip('Ver lista'));
    await tester.pumpAndSettle();

    final built = find.byType(EventCardCompact).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(80));
  });

  testWidgets('empty calendar period keeps semantic icon color in dark theme', (
    tester,
  ) async {
    await _pump(tester, const [], theme: buildDarkTheme());

    await tester.tap(find.byTooltip('Ver lista'));
    await tester.pumpAndSettle();

    final iconFinder = find.descendant(
      of: find.byType(EmptyState),
      matching: find.byIcon(LucideIcons.calendarRange),
    );
    final icon = tester.widget<Icon>(iconFinder);
    final context = tester.element(find.byType(EmptyState));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(icon.color, Theme.of(context).colorScheme.outline);
  });

  testWidgets('switching views returns to the current calendar period', (
    tester,
  ) async {
    await _pump(tester, const []);

    // Move the month pager away from today, then change view. Each view must
    // reset to today's corresponding period rather than preserving that page.
    await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
    await tester.pumpAndSettle();
    expect(
      find.text(
        DateFormat.yMMM('es').format(DateTime(now.year, now.month + 1)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    final thisMonday = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - DateTime.monday),
    );
    final thisSunday = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day + 6,
    );
    expect(
      find.text(
        '${DateFormat.MMMd('es').format(thisMonday)} – '
        '${DateFormat.MMMd('es').format(thisSunday)}',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Día'));
    await tester.pumpAndSettle();
    expect(
      find.text(DateFormat.yMMMd('es').format(now)),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();
    expect(
      find.text(DateFormat.yMMM('es').format(now)),
      findsOneWidget,
    );
  });

  testWidgets('view switch renders events for the reset current period', (
    tester,
  ) async {
    final today = DateTime(now.year, now.month, now.day);
    final nextMonth = DateTime(now.year, now.month + 1, now.day);
    await _pump(tester, [
      _event('today', 'Today event', today),
      _event(
        'next-month',
        'Next month event',
        nextMonth,
        type: 'deadline',
      ),
    ]);

    await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
    // Switch while the old pager is still moving; this used to let its page
    // state leak into the new view even though the header had reset to today.
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Día'));
    await tester.pumpAndSettle();

    expect(find.text('Hito de página'), findsOneWidget);
    expect(find.text('Fecha límite'), findsNothing);
  });

  testWidgets('tapping the header label opens a date picker', (tester) async {
    await _pump(tester, const []);
    final label = DateFormat.yMMM('es').format(DateTime(now.year, now.month));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('loads the exact visible month whenever the pager changes', (
    tester,
  ) async {
    final repository = _RangeCapturingEventRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepoProvider.overrideWithValue(repository),
          booksProvider.overrideWith((ref) async => [_book()]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.ranges, [
      (
        from: DateTime(now.year, now.month),
        to: DateTime(now.year, now.month + 1),
      ),
    ]);

    await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
    await tester.pumpAndSettle();

    expect(repository.ranges.last, (
      from: DateTime(now.year, now.month + 1),
      to: DateTime(now.year, now.month + 2),
    ));

    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    final firstDow = MaterialLocalizations.of(
      tester.element(find.byType(CalendarScreen)),
    ).firstDayOfWeekIndex;
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - leadingWeekdayOffset(now, firstDow),
    );
    expect(repository.ranges.last, (
      from: weekStart,
      to: DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + 7,
      ),
    ));

    await tester.tap(find.text('Día'));
    await tester.pumpAndSettle();
    expect(repository.ranges.last, (
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day + 1),
    ));
  });

  testWidgets('pending focus loads its exact target month', (tester) async {
    final repository = _RangeCapturingEventRepository();
    final target = DateTime(now.year + 2, 2, 14);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepoProvider.overrideWithValue(repository),
          booksProvider.overrideWith((ref) async => [_book()]),
          calendarFocusProvider.overrideWith((ref) => target),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.ranges.last, (
      from: DateTime(target.year, target.month),
      to: DateTime(target.year, target.month + 1),
    ));
  });

  testWidgets('cached period stays visible while refreshing it', (
    tester,
  ) async {
    final cache = CalendarEventsCache();
    final repository = _RangeCapturingEventRepository(
      currentMonthEvent: _event(
        'cached',
        'Cached event',
        DateTime(now.year, now.month, now.day),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepoProvider.overrideWithValue(repository),
          calendarEventsCacheProvider.overrideWithValue(cache),
          booksProvider.overrideWith((ref) async => [_book()]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DayEventMarkers), findsOneWidget);

    repository.delayNextCurrentMonthRefresh();
    final range = CalendarEventRange(
      from: DateTime(now.year, now.month),
      to: DateTime(now.year, now.month + 1),
    );
    ProviderScope.containerOf(
      tester.element(find.byType(CalendarScreen)),
    ).invalidate(calendarEventsProvider(range));
    await tester.pump();

    expect(cache.read(range), hasLength(1));
    expect(find.byType(CalendarSkeleton), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(
      tester.widget<MonthGrid>(find.byType(MonthGrid)).events,
      hasLength(1),
    );
    expect(find.byType(DayEventMarkers), findsOneWidget);

    repository.completeDelayedRefresh();
    await tester.pumpAndSettle();
    expect(find.byType(DayEventMarkers), findsNothing);
  });

  testWidgets(
    'shows loading instead of an empty calendar for an uncached period',
    (
      tester,
    ) async {
      final repository = _RangeCapturingEventRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoProvider.overrideWithValue(repository),
            booksProvider.overrideWith((ref) async => [_book()]),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ver lista'));
      await tester.pumpAndSettle();
      final emptyIconTop = tester
          .getTopLeft(find.byIcon(LucideIcons.calendarRange))
          .dy;

      repository.delayNextRequest();
      await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
      await tester.pump();
      // The outgoing empty page must be covered as soon as paging begins,
      // rather than waiting for onPageChanged at the end of the animation.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(repository.ranges, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(CircularProgressIndicator)).dy,
        emptyIconTop,
      );
      // Loading overlays the mounted pager instead of cutting its horizontal
      // transition short.
      expect(find.byType(PageView), findsOneWidget);

      repository.completeDelayedRequest();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No hay eventos este mes'), findsOneWidget);
    },
  );

  testWidgets(
    'month grid stays visible while an uncached period loads',
    (tester) async {
      final repository = _RangeCapturingEventRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoProvider.overrideWithValue(repository),
            booksProvider.overrideWith((ref) async => [_book()]),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      repository.delayNextRequest();
      await tester.tap(find.byIcon(LucideIcons.chevronRight).first);
      await tester.pump();

      // The month grid is navigation context, not an empty state: retain it
      // while markers for the target period arrive.
      expect(find.byType(MonthGrid), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(repository.ranges, hasLength(2));
      expect(find.byType(MonthGrid), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      repository.completeDelayedRequest();
      await tester.pumpAndSettle();
      expect(find.byType(MonthGrid), findsOneWidget);
    },
  );

  testWidgets(
    'a local-library wipe drops day markers before the empty refetch lands',
    (tester) async {
      final repository = _RangeCapturingEventRepository(
        currentMonthEvent: _event(
          'ghost',
          'Ghost',
          DateTime(now.year, now.month, now.day),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoProvider.overrideWithValue(repository),
            booksProvider.overrideWith((ref) async => [_book()]),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: const CalendarScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DayEventMarkers), findsOneWidget);

      repository.currentMonthEvent = null;
      repository.delayNextRequest();
      ProviderScope.containerOf(
        tester.element(find.byType(CalendarScreen)),
      ).read(dataPlaneTickProvider.notifier).state++;
      await tester.pump();

      expect(
        tester.widget<MonthGrid>(find.byType(MonthGrid)).events,
        isEmpty,
      );

      repository.completeDelayedRequest();
      await tester.pumpAndSettle();
      expect(find.byType(DayEventMarkers), findsNothing);
      await tester.tap(find.byTooltip('Ver lista'));
      await tester.pumpAndSettle();
      expect(find.text('No hay eventos este mes'), findsOneWidget);
    },
  );
}

class _SilentEventRepository extends ApiEventRepository {
  _SilentEventRepository() : super(_fakeApi());
}

class _RangeCapturingEventRepository extends ApiEventRepository {
  _RangeCapturingEventRepository({this.currentMonthEvent}) : super(_fakeApi());

  final ranges = <({DateTime from, DateTime to})>[];
  ReadingEvent? currentMonthEvent;
  Completer<Result<List<ReadingEvent>>>? _delayedRequest;

  void delayNextCurrentMonthRefresh() {
    delayNextRequest();
  }

  void completeDelayedRefresh() {
    completeDelayedRequest();
  }

  void delayNextRequest() {
    _delayedRequest = Completer<Result<List<ReadingEvent>>>();
  }

  void completeDelayedRequest() {
    _delayedRequest?.complete(const Ok(<ReadingEvent>[]));
  }

  @override
  Future<Result<List<ReadingEvent>>> list({
    DateTime? from,
    DateTime? to,
  }) async {
    ranges.add((from: from!, to: to!));
    final isCurrentMonth =
        from.year == DateTime.now().year && from.month == DateTime.now().month;
    final delayed = _delayedRequest;
    if (delayed != null && !delayed.isCompleted) {
      return delayed.future;
    }
    if (isCurrentMonth && currentMonthEvent != null) {
      return Ok(<ReadingEvent>[currentMonthEvent!]);
    }
    return const Ok(<ReadingEvent>[]);
  }
}

ApiClient _fakeApi() => ApiClient(
  baseUrl: 'http://localhost',
  storage: _FakeSecureTokenStorage(),
  localeProvider: () => 'es',
);

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
