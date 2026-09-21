import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/month_calendar.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';
import 'package:readendar/features/plan/domain/replan.dart';
import 'package:readendar/features/plan/presentation/plan_screen.dart';
import 'package:readendar/features/plan/presentation/plan_wizard.dart';
import '../../helpers/api_repo_stubs.dart';

Book _book({int? chapterCount = 8, int? pageCount}) => Book(
  id: 'b1',
  ownerType: 'user',
  ownerId: 'u1',
  title: 'Dune',
  authors: const ['Herbert'],
  status: 'reading',
  chapterCount: chapterCount,
  pageCount: pageCount,
);

ReadingEvent _ev(
  String type,
  DateTime date,
  String status, {
  String? id,
  int? chapter,
  int? page,
  bool reminderEnabled = true,
  String planId = 'p1',
}) => ReadingEvent(
  id: id ?? 'e-${date.day}-$type',
  ownerType: 'user',
  ownerId: 'u1',
  bookId: 'b1',
  type: type,
  title: type,
  dateLocal: date,
  status: status,
  targetChapter: chapter,
  targetPage: page,
  planId: planId,
  reminderEnabled: reminderEnabled,
);

Future<void> _pumpReplan(
  WidgetTester tester, {
  List<ReadingEvent>? liveEvents,
  List<ReadingEvent>? allBookEvents,
  DateTime? now,
  Book? book,
  Progress? progress,
  ProgressRepository? progressRepo,
  EventRepository? eventRepo,
  PlanRepository? planRepo,
  PlanRun? run,
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final events =
      liveEvents ??
      [
        _ev('chapter_milestone', DateTime(2024), 'completed', chapter: 2),
        _ev('chapter_milestone', DateTime(2024, 1, 2), 'active', chapter: 4),
        _ev('chapter_milestone', DateTime(2024, 1, 3), 'active', chapter: 6),
        _ev('finish', DateTime(2024, 1, 4), 'active'),
      ];
  final plannedBook = book ?? _book();
  final state = buildReplanState(
    events,
    book: plannedBook,
    now: now ?? DateTime(2024),
    run: run,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (progressRepo != null)
          progressRepoProvider.overrideWithValue(progressRepo),
        if (eventRepo != null) eventRepoProvider.overrideWithValue(eventRepo),
        if (planRepo != null) planRepoProvider.overrideWithValue(planRepo),
        notificationPrefsProvider.overrideWith(
          (ref) async => NotificationPreferences(
            globalEnabled: true,
            defaultReminderMinutesBefore: 1440,
            allDayReminderHour: 9,
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('es'),
        theme: theme ?? buildLightTheme(),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: PlanScreen(
          book: plannedBook,
          progress: progress,
          replan: ReplanLaunch(
            planId: 'p1',
            state: state!,
            allBookEvents: allBookEvents ?? events,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Ensure the Events preview is visible. Replan already opens here; create
/// flows still need Continue through the wizard.
Future<void> _toPreview(WidgetTester tester) async {
  if (find.byType(MonthGrid).evaluate().isNotEmpty) return;
  for (var i = 0; i < 4; i++) {
    if (find.byType(MonthGrid).evaluate().isNotEmpty) return;
    final continueBtn = find.text('Continuar');
    if (continueBtn.evaluate().isEmpty) break;
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();
  }
  expect(find.byType(MonthGrid), findsOneWidget);
}

/// Open the options (last form) step from the replan preview.
Future<void> _toOptionsStep(WidgetTester tester) async {
  if (find.byType(MonthGrid).evaluate().isNotEmpty) {
    await _restartReplanFromPreview(tester);
    await _continueWizard(tester, times: 2);
    return;
  }
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
}

Future<void> _restartReplanFromPreview(WidgetTester tester) async {
  await tester.tap(find.text('Cambiar opciones'));
  await tester.pumpAndSettle();
}

Future<void> _updateProgressFromPrompt(
  WidgetTester tester, {
  required int page,
}) async {
  await tester.tap(find.text('Actualizar progreso'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('progressPageField')), findsOneWidget);
  await tester.enterText(
    find.byKey(const Key('progressPageField')),
    page.toString(),
  );
  await tester.tap(find.byKey(const Key('progressSaveButton')));
  await tester.pumpAndSettle();
}

Future<void> _updateChapterProgressFromPrompt(
  WidgetTester tester, {
  required int chapter,
}) async {
  await tester.tap(find.text('Actualizar progreso'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const Key('progressChapterField')),
    chapter.toString(),
  );
  await tester.tap(find.byKey(const Key('progressSaveButton')));
  await tester.pumpAndSettle();
}

Future<void> _continueWizard(WidgetTester tester, {int times = 1}) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('replan starts on the events preview', (
    tester,
  ) async {
    await _pumpReplan(tester);

    expect(find.text('Replanificar'), findsWidgets);
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(find.text('Cambiar opciones'), findsOneWidget);
    expect(find.text('1 event locked'), findsNothing);

    final lockedCell = tester.widget<CalendarDayCell>(
      find.byWidgetPredicate(
        (widget) => widget is CalendarDayCell && widget.date == DateTime(2024),
      ),
    );
    expect(lockedCell.disabled, isTrue);
  });

  testWidgets('replan change-options jumps to the goal step', (
    tester,
  ) async {
    await _pumpReplan(tester);
    expect(find.byType(MonthGrid), findsOneWidget);

    await _restartReplanFromPreview(tester);

    expect(find.byType(MonthGrid), findsNothing);
    expect(find.text('¿Cómo quieres planificar?'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Cambiar opciones'), findsNothing);
  });

  testWidgets('replan restores every saved option before recalculation', (
    tester,
  ) async {
    final start = DateTime(2026, 8, 14);
    final end = DateTime(2026, 8, 28);
    await _pumpReplan(
      tester,
      now: DateTime(2026, 8, 12),
      book: _book(chapterCount: null, pageCount: 300),
      run: PlanRun(
        id: 'p1',
        bookId: 'b1',
        eventCount: 3,
        mode: 'before_event',
        unit: 'pages',
        startDate: start,
        endDate: end,
        total: 300,
        startUnit: 40,
        excludedWeekdays: const {6, 7},
        remindersOn: false,
        includeStart: false,
        includeFinish: true,
        anchorEventId: 'anchor-1',
        anchorEventTitle: 'Library meeting',
        createdAt: DateTime.utc(2026, 8),
      ),
      liveEvents: [
        _ev('page_milestone', start, 'active', page: 100),
        _ev('page_milestone', DateTime(2026, 8, 21), 'active', page: 200),
        _ev('deadline', end, 'active'),
      ],
    );

    await _restartReplanFromPreview(tester);
    final draft = tester
        .widget<PlanWizardForm>(find.byType(PlanWizardForm))
        .draft;

    expect(draft.mode, PlanMode.beforeEvent);
    expect(draft.unit, PlanUnit.pages);
    expect(draft.startDate, start);
    expect(draft.endDate, end);
    expect(draft.total, 300);
    expect(draft.startUnit, 40);
    expect(draft.perDay, isNull);
    expect(draft.excludedWeekdays, {6, 7});
    expect(draft.remindersOn, isFalse);
    expect(draft.includeStart, isFalse);
    expect(draft.includeFinish, isTrue);
    expect(draft.anchorEventId, 'anchor-1');
    expect(draft.anchorEventTitle, 'Library meeting');
  });

  testWidgets('replan updates existing rows instead of recreating them', (
    tester,
  ) async {
    final events = _CapturingEventRepository();
    await _pumpReplan(
      tester,
      eventRepo: events,
      planRepo: _NoopPlanRepository(),
    );

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar').last);
    await tester.pumpAndSettle();

    expect(events.created, isEmpty);
    expect(events.updates, hasLength(3));
    expect(events.deletedIds, isEmpty);
  });

  testWidgets('replan update failure keeps the preview and old rows', (
    tester,
  ) async {
    final events = _FailingUpdateEventRepository();
    await _pumpReplan(
      tester,
      eventRepo: events,
      planRepo: _NoopPlanRepository(),
    );

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar').last);
    await tester.pumpAndSettle();

    expect(find.text("No se pudo actualizar el plan."), findsOneWidget);
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(events.created, isEmpty);
    expect(events.deletedIds, isEmpty);
  });

  testWidgets('replan restores earlier rows when a later update fails', (
    tester,
  ) async {
    final events = _FailingSecondUpdateEventRepository();
    await _pumpReplan(
      tester,
      eventRepo: events,
      planRepo: _NoopPlanRepository(),
    );

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar').last);
    await tester.pumpAndSettle();

    expect(find.text("No se pudo actualizar el plan."), findsOneWidget);
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(events.deletedIds, isEmpty);
    expect(events.updates.map((update) => update.$1), [
      'e-2-chapter_milestone',
      'e-2-chapter_milestone',
    ]);
    expect(events.updates.last.$2['dateLocal'], '2024-01-02');
    expect(events.updates.last.$2['targetChapter'], 4);
  });

  testWidgets('cancelling an in-flight replan restores the updated row', (
    tester,
  ) async {
    final events = _BlockingFirstUpdateEventRepository();
    await _pumpReplan(
      tester,
      eventRepo: events,
      planRepo: _NoopPlanRepository(),
    );

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar').last);
    await tester.pump();
    final cancel = find.widgetWithText(RdButton, 'Cancelar');
    expect(cancel, findsOneWidget);

    await tester.tap(cancel);
    events.release.complete();
    await tester.pumpAndSettle();

    expect(events.deletedIds, isEmpty);
    expect(events.updates.map((update) => update.$1), [
      'e-2-chapter_milestone',
      'e-2-chapter_milestone',
    ]);
    expect(events.updates.last.$2['dateLocal'], '2024-01-02');
    expect(events.updates.last.$2['targetChapter'], 4);
  });

  testWidgets('replan consolidates duplicate existing milestones', (
    tester,
  ) async {
    final events = _CapturingEventRepository();
    await _pumpReplan(
      tester,
      now: DateTime(2024),
      eventRepo: events,
      planRepo: _NoopPlanRepository(),
      liveEvents: [
        _ev(
          'chapter_milestone',
          DateTime(2024),
          'active',
          id: 'duplicate-1',
          chapter: 4,
        ),
        _ev(
          'chapter_milestone',
          DateTime(2024),
          'active',
          id: 'duplicate-2',
          chapter: 4,
        ),
        _ev(
          'chapter_milestone',
          DateTime(2024, 1, 2),
          'active',
          id: 'future',
          chapter: 6,
        ),
      ],
    );

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar').last);
    await tester.pumpAndSettle();

    expect(events.created, isEmpty);
    expect(events.updates.map((update) => update.$1), [
      'duplicate-1',
      'future',
    ]);
    expect(events.deletedIds, ['duplicate-2']);
  });

  testWidgets('replan restores updates when surplus deletion fails', (
    tester,
  ) async {
    final events = _FailingDeleteEventRepository();
    await _pumpReplan(
      tester,
      now: DateTime(2024),
      eventRepo: events,
      planRepo: _NoopPlanRepository(),
      liveEvents: [
        _ev(
          'chapter_milestone',
          DateTime(2024),
          'active',
          id: 'duplicate-1',
          chapter: 4,
        ),
        _ev(
          'chapter_milestone',
          DateTime(2024),
          'active',
          id: 'duplicate-2',
          chapter: 4,
        ),
        _ev(
          'chapter_milestone',
          DateTime(2024, 1, 2),
          'active',
          id: 'future',
          chapter: 6,
        ),
      ],
    );

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar').last);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(events.deleteAttempts, 3);
    expect(events.updates.map((update) => update.$1), [
      'duplicate-1',
      'future',
      'future',
      'duplicate-1',
    ]);
    expect(events.updates.last.$2['dateLocal'], '2024-01-01');
    expect(events.updates.last.$2['targetChapter'], 4);
  });

  testWidgets(
    'replan keeps one milestone per civil day when duplicate targets differ',
    (tester) async {
      final events = _CapturingEventRepository();
      await _pumpReplan(
        tester,
        now: DateTime(2024),
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        liveEvents: [
          _ev(
            'chapter_milestone',
            DateTime(2024),
            'active',
            id: 'lower-target',
            chapter: 4,
          ),
          _ev(
            'chapter_milestone',
            DateTime(2024),
            'active',
            id: 'higher-target',
            chapter: 6,
          ),
          _ev(
            'chapter_milestone',
            DateTime(2024, 1, 2),
            'active',
            id: 'future',
            chapter: 8,
          ),
        ],
      );

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      expect(events.created, isEmpty);
      expect(events.updates.map((update) => update.$1), [
        'lower-target',
        'future',
      ]);
      expect(events.updates.first.$2['targetChapter'], 6);
      expect(events.deletedIds, ['higher-target']);
    },
  );

  testWidgets(
    'replan replaces a completed same-day milestone with different progress',
    (
      tester,
    ) async {
      final events = _CapturingEventRepository();
      final currentPlanEvents = [
        _ev(
          'chapter_milestone',
          DateTime(2024),
          'active',
          id: 'current',
          chapter: 4,
        ),
        _ev(
          'chapter_milestone',
          DateTime(2024, 1, 2),
          'active',
          id: 'future',
          chapter: 8,
        ),
      ];
      await _pumpReplan(
        tester,
        now: DateTime(2024),
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        liveEvents: currentPlanEvents,
        allBookEvents: [
          ...currentPlanEvents,
          _ev(
            'chapter_milestone',
            DateTime(2024),
            'completed',
            id: 'older-plan-duplicate',
            chapter: 6,
            planId: 'p0',
          ),
        ],
      );

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      expect(events.created, isEmpty);
      expect(events.deletedIds, ['older-plan-duplicate']);
    },
  );

  testWidgets(
    'replan reuses and reopens a completed milestone instead of creating one',
    (tester) async {
      final today = DateTime.now();
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final events = _CapturingEventRepository();
      final live = [
        _ev(
          'page_milestone',
          day(1),
          'completed',
          id: 'completed-100',
          page: 100,
        ),
        _ev('finish', day(2), 'active', id: 'finish'),
      ];
      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 200),
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        run: PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 2,
          mode: 'pace',
          unit: 'pages',
          perDay: 100,
          startDate: day(1),
          total: 200,
          startUnit: 0,
          excludedWeekdays: const {},
          remindersOn: true,
          includeStart: false,
          includeFinish: true,
          createdAt: today,
        ),
        liveEvents: live,
        allBookEvents: live,
      );

      await _restartReplanFromPreview(tester);
      await _continueWizard(tester, times: 3);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      expect(events.created, isEmpty);
      expect(events.deletedIds, isEmpty);
      expect(
        events.updates.map((update) => update.$1),
        contains('completed-100'),
      );
      expect(
        events.updates
            .singleWhere((update) => update.$1 == 'completed-100')
            .$2['planId'],
        'p1',
      );
      expect(events.reopenedIds, contains('completed-100'));
    },
  );

  testWidgets('replan preview back returns to the wizard steps', (
    tester,
  ) async {
    final clock = DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final events = [
      _ev('chapter_milestone', today, 'completed', chapter: 2),
      _ev(
        'chapter_milestone',
        today.add(const Duration(days: 1)),
        'active',
        chapter: 4,
      ),
      _ev('finish', today.add(const Duration(days: 2)), 'active'),
    ];
    final plannedBook = _book();
    final state = buildReplanState(
      events,
      book: plannedBook,
      now: today,
    );

    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlanScreen(
                        book: plannedBook,
                        replan: ReplanLaunch(planId: 'p1', state: state!),
                      ),
                    ),
                  ),
                  child: const Text('Open replan'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open replan'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthGrid), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();

    expect(find.byType(MonthGrid), findsNothing);
    expect(find.text('Paso 3 de 3'), findsOneWidget);
    expect(find.text('Recordatorios'), findsOneWidget);
    expect(find.text('Open replan'), findsNothing);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 2 de 3'), findsOneWidget);

    await tester.tap(find.text('Atrás'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 3'), findsOneWidget);
    expect(find.text('¿Cómo quieres planificar?'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Open replan'), findsOneWidget);
  });

  testWidgets('replan app bar cancel exits from preview', (tester) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlanScreen(
                        book: _book(),
                        replan: ReplanLaunch(
                          planId: 'p1',
                          state: buildReplanState(
                            [
                              _ev(
                                'chapter_milestone',
                                day,
                                'active',
                                chapter: 2,
                              ),
                            ],
                            book: _book(),
                            now: day,
                          )!,
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open replan'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open replan'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthGrid), findsOneWidget);

    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(MonthGrid), findsNothing);
    expect(find.text('Open replan'), findsOneWidget);
  });

  testWidgets('replan preview lists the completed event as a disabled row', (
    tester,
  ) async {
    await _pumpReplan(tester);
    await _toPreview(tester);
    await tester.tap(find.byTooltip('Lista'));
    await tester.pumpAndSettle();

    // The two pending milestones + the finish + the completed anchor render.
    expect(find.byType(EventCardCompact), findsWidgets);

    // The completed anchor (ch2) shows as a disabled row with a lock gutter.
    expect(find.widgetWithText(EventCardCompact, 'Capítulo 2'), findsOneWidget);
    expect(
      tester
          .widget<EventCardCompact>(
            find.widgetWithText(EventCardCompact, 'Capítulo 2'),
          )
          .enabled,
      isFalse,
    );
    expect(find.byIcon(LucideIcons.lock), findsOneWidget);
  });

  testWidgets('past active events are shown as locked and not editable', (
    tester,
  ) async {
    await _pumpReplan(
      tester,
      now: DateTime(2024, 1, 2),
      liveEvents: [
        _ev(
          'chapter_milestone',
          DateTime(2024),
          'active',
          chapter: 2,
        ),
        _ev(
          'chapter_milestone',
          DateTime(2024, 1, 2),
          'active',
          chapter: 4,
        ),
        _ev('finish', DateTime(2024, 1, 3), 'active'),
      ],
    );
    await _toPreview(tester);
    await tester.tap(find.byTooltip('Lista'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(EventCardCompact, 'Capítulo 2'), findsOneWidget);
    expect(find.byIcon(LucideIcons.lock), findsOneWidget);
    expect(find.text('1 event locked'), findsNothing);
  });

  testWidgets(
    'recalculating preserves a start event dated today in its existing row',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final events = _CapturingEventRepository();

      await _pumpReplan(
        tester,
        now: today,
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        run: PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 4,
          mode: 'pace',
          unit: 'chapters',
          perDay: 2,
          startDate: day(-2),
          total: 8,
          startUnit: 0,
          excludedWeekdays: const {},
          remindersOn: true,
          includeStart: true,
          includeFinish: true,
          createdAt: day(-2),
        ),
        liveEvents: [
          _ev('start', today, 'active'),
          _ev('chapter_milestone', day(1), 'active', chapter: 2),
          _ev('finish', day(2), 'active'),
        ],
      );

      await _toPreview(tester);
      final startCell = tester.widget<CalendarDayCell>(
        find.byWidgetPredicate(
          (widget) => widget is CalendarDayCell && widget.date == today,
        ),
      );
      expect(startCell.disabled, isTrue);

      await _restartReplanFromPreview(tester);
      await _continueWizard(tester);
      await tester.tap(find.byIcon(LucideIcons.calendar));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        DateFormat.yMd('es').format(day(1)),
      );
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();
      // Agenda stays progressive — advance to options, then Continue recalculates.
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      expect(events.created.any((body) => body['type'] == 'start'), isFalse);
      expect(events.deletedIds, isNot(contains('e-${today.day}-start')));
    },
  );

  testWidgets(
    'updating progress opens the editor and recalculates from the saved page',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final progressRepo = _FakeProgressRepository();
      final events = _CapturingEventRepository();

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        progress: Progress(bookEntryId: 'b1', currentPage: 100),
        progressRepo: progressRepo,
        eventRepo: events,
        liveEvents: [
          _ev('page_milestone', day(-1), 'active', page: 20),
          _ev('page_milestone', today, 'active', page: 40),
          _ev('page_milestone', day(2), 'active', page: 80),
          _ev('finish', day(3), 'active'),
        ],
      );

      await _toPreview(tester);
      expect(find.text('¿Está actualizado tu progreso de lectura?'), findsOneWidget);
      expect(find.text('Actualizar progreso'), findsOneWidget);

      await _updateProgressFromPrompt(tester, page: 100);
      expect(events.completedIds, [
        'e-${day(-1).day}-page_milestone',
        'e-${today.day}-page_milestone',
        'e-${day(2).day}-page_milestone',
      ]);
      await tester.tap(find.byTooltip('Lista'));
      await tester.pumpAndSettle();

      expect(find.text('¿Está actualizado tu progreso de lectura?'), findsNothing);
      expect(find.widgetWithText(EventCardCompact, 'Página 20'), findsOneWidget);
      expect(find.widgetWithText(EventCardCompact, 'Página 100'), findsOneWidget);
      expect(find.widgetWithText(EventCardCompact, 'Página 130'), findsOneWidget);
      expect(find.widgetWithText(EventCardCompact, 'Página 40'), findsNothing);
    },
  );

  testWidgets(
    'catch-up keeps the existing start event even when it is in the past',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final events = _CapturingEventRepository();
      final pastStart = day(-2);

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        progress: Progress(bookEntryId: 'b1', currentPage: 40),
        progressRepo: _FakeProgressRepository(),
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        run: PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 5,
          mode: 'pace',
          unit: 'pages',
          perDay: 40,
          startDate: pastStart,
          total: 300,
          startUnit: 0,
          excludedWeekdays: const {},
          remindersOn: true,
          includeStart: true,
          includeFinish: true,
          createdAt: pastStart,
        ),
        liveEvents: [
          _ev('start', pastStart, 'completed', id: 'original-start'),
          _ev('page_milestone', day(-1), 'active', page: 20),
          _ev('page_milestone', today, 'active', page: 40),
          _ev('page_milestone', day(2), 'active', page: 80),
          _ev('finish', day(4), 'active'),
        ],
      );

      await _toPreview(tester);
      await _updateProgressFromPrompt(tester, page: 100);

      final previewStarts = tester
          .widget<MonthGrid>(find.byType(MonthGrid))
          .events
          .where((event) => event.type == 'start')
          .toList();
      expect(previewStarts, hasLength(1));
      expect(
        _ymdForTest(previewStarts.single.dateLocal),
        _ymdForTest(pastStart),
      );

      await tester.tap(find.text('Progreso actualizado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      expect(events.created.any((body) => body['type'] == 'start'), isFalse);
      expect(
        events.updates.any((update) => update.$1 == 'original-start'),
        isFalse,
      );
      expect(events.deletedIds, isNot(contains('original-start')));
    },
  );

  testWidgets(
    'saving progress replan removes completed milestones absent from preview',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final events = _CapturingEventRepository();

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        progress: Progress(bookEntryId: 'b1', currentPage: 40),
        progressRepo: _FakeProgressRepository(),
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        liveEvents: [
          _ev('page_milestone', today, 'active', page: 40),
          _ev('page_milestone', day(2), 'active', page: 80),
          _ev('page_milestone', day(4), 'active', page: 120),
          _ev('finish', day(6), 'active'),
        ],
      );

      await _updateProgressFromPrompt(tester, page: 100);
      expect(events.completedIds, [
        'e-${today.day}-page_milestone',
        'e-${day(2).day}-page_milestone',
      ]);

      await tester.tap(find.text('Progreso actualizado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      expect(
        events.reopenedIds,
        containsAll([
          'e-${today.day}-page_milestone',
          'e-${day(2).day}-page_milestone',
        ]),
      );
    },
  );

  testWidgets('progress exactly at today milestone also shows the warning', (
    tester,
  ) async {
    final clock = DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    await _pumpReplan(
      tester,
      now: today,
      book: _book(chapterCount: null, pageCount: 300),
      progress: Progress(bookEntryId: 'b1', currentPage: 40),
      theme: buildDarkTheme(),
      liveEvents: [
        _ev('page_milestone', today, 'active', page: 40),
        _ev('page_milestone', tomorrow, 'active', page: 80),
      ],
    );

    await _toPreview(tester);
    expect(find.text('¿Está actualizado tu progreso de lectura?'), findsOneWidget);
    expect(find.text('Actualizar progreso'), findsOneWidget);
  });

  testWidgets('chapter progress completes reached chapters and recalculates', (
    tester,
  ) async {
    final clock = DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final progressRepo = _FakeProgressRepository();
    final events = _CapturingEventRepository();

    await _pumpReplan(
      tester,
      now: today,
      book: _book(),
      progress: Progress(bookEntryId: 'b1', currentChapter: 3),
      progressRepo: progressRepo,
      eventRepo: events,
      liveEvents: [
        _ev('chapter_milestone', today, 'active', chapter: 2),
        _ev('chapter_milestone', tomorrow, 'active', chapter: 4),
        _ev(
          'finish',
          DateTime(today.year, today.month, today.day + 2),
          'active',
        ),
      ],
    );

    await _updateChapterProgressFromPrompt(tester, chapter: 3);
    await tester.tap(find.byTooltip('Lista'));
    await tester.pumpAndSettle();

    expect(progressRepo.updatedChapter, 3);
    expect(events.completedIds, ['e-${today.day}-chapter_milestone']);
    expect(find.widgetWithText(EventCardCompact, 'Capítulo 3'), findsOneWidget);
  });

  testWidgets('dismissing catch-up banner hides it until recalculate', (
    tester,
  ) async {
    final clock = DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);

    await _pumpReplan(
      tester,
      now: today,
      book: _book(chapterCount: null, pageCount: 300),
      progress: Progress(bookEntryId: 'b1', currentPage: 40),
      liveEvents: [
        _ev('page_milestone', today, 'active', page: 40),
        _ev(
          'page_milestone',
          today.add(const Duration(days: 1)),
          'active',
          page: 80,
        ),
      ],
    );

    await _toPreview(tester);
    expect(find.text('¿Está actualizado tu progreso de lectura?'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Está actualizado tu progreso de lectura?'), findsNothing);
    expect(find.text('Actualizar progreso'), findsNothing);
  });

  testWidgets(
    'a past due milestone offers its page even when recorded progress is behind',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final progressRepo = _FakeProgressRepository();
      final events = _CapturingEventRepository();

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        progress: Progress(bookEntryId: 'b1', currentPage: 10),
        progressRepo: progressRepo,
        eventRepo: events,
        liveEvents: [
          _ev('page_milestone', day(-1), 'active', page: 40),
          _ev('page_milestone', day(2), 'active', page: 80),
        ],
      );

      await _toPreview(tester);
      expect(find.text('¿Está actualizado tu progreso de lectura?'), findsOneWidget);
      expect(find.text('Actualizar progreso'), findsOneWidget);

      await _updateProgressFromPrompt(tester, page: 40);

      expect(progressRepo.updatedPage, 40);
      expect(find.text('¿Está actualizado tu progreso de lectura?'), findsNothing);
    },
  );

  testWidgets('event completion failure keeps the replan prompt actionable', (
    tester,
  ) async {
    final clock = DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final progressRepo = _FakeProgressRepository();

    await _pumpReplan(
      tester,
      now: today,
      book: _book(chapterCount: null, pageCount: 300),
      progress: Progress(bookEntryId: 'b1', currentPage: 10),
      progressRepo: progressRepo,
      eventRepo: _FailingCompleteEventRepository(),
      liveEvents: [
        _ev(
          'page_milestone',
          DateTime(today.year, today.month, today.day - 1),
          'active',
          page: 20,
        ),
        _ev('page_milestone', today, 'active', page: 80),
      ],
    );

    await _updateProgressFromPrompt(tester, page: 40);

    expect(progressRepo.updatedPage, 40);
    expect(find.text("No se pudo actualizar el plan."), findsOneWidget);
    expect(find.text('¿Está actualizado tu progreso de lectura?'), findsOneWidget);
  });

  testWidgets(
    'catch-up updates and reopens the existing completed event for today',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      final events = _CapturingEventRepository();
      final progressRepo = _FakeProgressRepository();

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        progress: Progress(bookEntryId: 'b1', currentPage: 100),
        progressRepo: progressRepo,
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        liveEvents: [
          _ev('page_milestone', today, 'completed', page: 40),
          _ev('page_milestone', tomorrow, 'active', page: 80),
        ],
      );

      await _toPreview(tester);
      await _updateProgressFromPrompt(tester, page: 100);

      final todayCell = tester.widget<CalendarDayCell>(
        find.byWidgetPredicate(
          (widget) => widget is CalendarDayCell && widget.date == today,
        ),
      );
      expect(todayCell.events, hasLength(1));
      expect(todayCell.events.single.targetPage, 100);
      expect(todayCell.events.single.status, 'active');
      expect(todayCell.disabled, isFalse);

      await tester.tap(find.text('Progreso actualizado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      final todayUpdate = events.updates.singleWhere(
        (update) => update.$1 == 'e-${today.day}-page_milestone',
      );
      expect(todayUpdate.$2['targetPage'], 100);
      expect(
        events.reopenedIds,
        containsAll([
          'e-${today.day}-page_milestone',
          'e-${tomorrow.day}-page_milestone',
        ]),
      );
      expect(
        events.created.any((body) => body['dateLocal'] == _ymdForTest(today)),
        isFalse,
      );
      expect(events.deletedIds, isEmpty);
    },
  );

  testWidgets('recalculate is on the form; update is only on the preview', (
    tester,
  ) async {
    await _pumpReplan(tester);

    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);

    await _toOptionsStep(tester);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Actualizar'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
  });

  testWidgets('deadline replan preview never shows null pace', (tester) async {
    await _pumpReplan(
      tester,
      liveEvents: [
        _ev('start', DateTime(2024), 'active'),
        _ev('chapter_milestone', DateTime(2024, 1, 3), 'active', chapter: 4),
        _ev('deadline', DateTime(2024, 1, 10), 'active'),
      ],
    );
    await _toPreview(tester);
    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('Terminar en una fecha'), findsWidgets);
  });

  testWidgets('dirty replan draft blocks Update until recalculate', (
    tester,
  ) async {
    await _pumpReplan(tester);
    await _toPreview(tester);
    expect(find.text('Actualizar'), findsOneWidget);

    await _restartReplanFromPreview(tester);
    await _continueWizard(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Ritmo *'), '1');
    await tester.pumpAndSettle();

    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Actualizar'), findsNothing);

    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Actualizar'), findsOneWidget);
  });

  testWidgets(
    'changing replan start date recalculates and replaces the old start marker',
    (tester) async {
      final today = DateTime.now();
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final events = _CapturingEventRepository();

      await _pumpReplan(
        tester,
        now: today,
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        run: PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 4,
          mode: 'pace',
          unit: 'chapters',
          perDay: 2,
          startDate: day(-2),
          total: 8,
          startUnit: 0,
          excludedWeekdays: const {},
          remindersOn: true,
          includeStart: true,
          includeFinish: true,
          createdAt: day(-2),
        ),
        liveEvents: [
          _ev('start', day(-2), 'completed', id: 'original-start'),
          _ev('chapter_milestone', day(1), 'active', chapter: 2),
          _ev('chapter_milestone', day(3), 'active', chapter: 4),
          _ev('finish', day(5), 'active'),
        ],
      );

      await _restartReplanFromPreview(tester);
      await _continueWizard(tester);
      final newStart = day(2);
      tester
          .widget<PlanDateField>(find.byType(PlanDateField).first)
          .onPick(
            newStart,
          );
      await tester.pumpAndSettle();
      await _continueWizard(tester, times: 2);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final previewStarts = tester
          .widget<MonthGrid>(find.byType(MonthGrid))
          .events
          .where((event) => event.type == 'start')
          .toList();
      expect(previewStarts, hasLength(1));
      expect(
        _ymdForTest(previewStarts.single.dateLocal),
        _ymdForTest(newStart),
      );

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      final startUpdate = events.updates.singleWhere(
        (update) => update.$1 == 'original-start',
      );
      expect(startUpdate.$2['dateLocal'], _ymdForTest(newStart));
      expect(events.reopenedIds, contains('original-start'));
    },
  );

  testWidgets(
    'before_event replan recalculates with endDate and no anchor id',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        run: PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 3,
          mode: 'before_event',
          unit: 'pages',
          startDate: day(-1),
          endDate: day(10),
          total: 300,
          createdAt: day(-1),
        ),
        liveEvents: [
          _ev('page_milestone', day(-1), 'completed', page: 40),
          _ev('page_milestone', day(3), 'active', page: 100),
          _ev('deadline', day(10), 'active'),
        ],
      );

      await _toPreview(tester);
      expect(find.text('Actualizar'), findsWidgets);
      expect(find.text('Antes de un evento'), findsWidgets);

      await _restartReplanFromPreview(tester);
      await _continueWizard(tester);
      // Agenda: flip a weekday chip (semantics label is the full weekday name).
      await tester.tap(find.bySemanticsLabel(RegExp('lunes')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Continuar'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Actualizar'), findsWidgets);
      expect(
        find.text('La fecha límite debe ser igual o posterior a la de inicio.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'before_event catch-up keeps a future event day without stretching',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final progressRepo = _FakeProgressRepository();
      final events = _CapturingEventRepository();
      final eventDay = day(8);

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        progress: Progress(bookEntryId: 'b1', currentPage: 100),
        progressRepo: progressRepo,
        eventRepo: events,
        run: PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 3,
          mode: 'before_event',
          unit: 'pages',
          startDate: day(-1),
          endDate: eventDay,
          total: 300,
          createdAt: day(-1),
        ),
        liveEvents: [
          _ev('page_milestone', day(-1), 'active', page: 20),
          _ev('page_milestone', today, 'active', page: 40),
          _ev('page_milestone', day(4), 'active', page: 120),
          _ev('deadline', eventDay, 'active'),
        ],
      );

      await _toPreview(tester);
      expect(find.text('Actualizar progreso'), findsOneWidget);
      await _updateProgressFromPrompt(tester, page: 100);
      await tester.tap(find.byTooltip('Lista'));
      await tester.pumpAndSettle();

      expect(progressRepo.updatedPage, 100);
      expect(find.text('¿Está actualizado tu progreso de lectura?'), findsNothing);
      expect(find.widgetWithText(EventCardCompact, 'Página 100'), findsOneWidget);
      expect(
        find.text('La fecha límite debe ser igual o posterior a la de inicio.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'before_event catch-up refuses when the event day is already too soon',
    (tester) async {
      final clock = DateTime.now();
      final today = DateTime(clock.year, clock.month, clock.day);
      DateTime day(int offset) =>
          DateTime(today.year, today.month, today.day + offset);
      final progressRepo = _FakeProgressRepository();

      await _pumpReplan(
        tester,
        now: today,
        book: _book(chapterCount: null, pageCount: 300),
        progress: Progress(bookEntryId: 'b1', currentPage: 100),
        progressRepo: progressRepo,
        run: PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 2,
          mode: 'before_event',
          unit: 'pages',
          startDate: day(-1),
          endDate: today,
          total: 300,
          createdAt: day(-1),
        ),
        liveEvents: [
          _ev('page_milestone', today, 'active', page: 40),
          _ev('deadline', today, 'active'),
        ],
      );

      await _toPreview(tester);
      expect(find.text('Actualizar progreso'), findsOneWidget);
      await tester.tap(find.text('Actualizar progreso'));
      await tester.pumpAndSettle();

      expect(progressRepo.updatedPage, isNull);
      expect(
        find.text('La fecha límite debe ser igual o posterior a la de inicio.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('replan app bar delete opens undo confirm and calls undoPlan', (
    tester,
  ) async {
    final planRepo = _UndoTrackingPlanRepository();
    await _pumpReplan(tester, planRepo: planRepo);

    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    expect(find.text('¿Deshacer este plan?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(LucideIcons.trash2),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Deshacer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(planRepo.undoCalls, 1);
    expect(planRepo.lastUndoId, 'p1');
  });

  testWidgets('replan done screen hides plan-level undo', (tester) async {
    final events = _CapturingEventRepository();
    await _pumpReplan(
      tester,
      eventRepo: events,
      planRepo: _NoopPlanRepository(),
    );

    await _toPreview(tester);
    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actualizar').last);
    await tester.pumpAndSettle();

    expect(find.text('¡Plan actualizado!'), findsOneWidget);
    expect(find.text('Deshacer este plan'), findsNothing);
  });

  testWidgets('replan seeds reminders off when live events have none', (
    tester,
  ) async {
    await _pumpReplan(
      tester,
      liveEvents: [
        _ev(
          'chapter_milestone',
          DateTime(2024, 1, 2),
          'active',
          chapter: 4,
          reminderEnabled: false,
        ),
        _ev(
          'chapter_milestone',
          DateTime(2024, 1, 3),
          'active',
          chapter: 6,
          reminderEnabled: false,
        ),
        _ev('finish', DateTime(2024, 1, 4), 'active', reminderEnabled: false),
      ],
    );
    await _toOptionsStep(tester);
    // Options step: Reminders block should be unselected.
    final reminders = tester.getSemantics(find.text('Recordatorios'));
    expect(reminders.flagsCollection.isSelected, isNot(Tristate.isTrue));
  });

  testWidgets(
    'excluding a middle replan day shifts and saves without deleting an event',
    (tester) async {
      final events = _CapturingEventRepository();
      await _pumpReplan(
        tester,
        eventRepo: events,
        planRepo: _NoopPlanRepository(),
        liveEvents: [
          _ev('chapter_milestone', DateTime(2024), 'completed', chapter: 2),
          _ev('chapter_milestone', DateTime(2024, 1, 3), 'active', chapter: 4),
          _ev('chapter_milestone', DateTime(2024, 1, 7), 'active', chapter: 6),
          _ev('finish', DateTime(2024, 1, 11), 'active'),
        ],
      );

      await _toPreview(tester);
      final excludedDay = find.byWidgetPredicate(
        (widget) =>
            widget is CalendarDayCell && widget.date == DateTime(2024, 1, 7),
      );
      await tester.tap(excludedDay);
      await tester.pumpAndSettle();

      CalendarDayCell day(int value) => tester.widget<CalendarDayCell>(
        find.byWidgetPredicate(
          (widget) =>
              widget is CalendarDayCell &&
              widget.date == DateTime(2024, 1, value),
        ),
      );

      expect(day(3).events.single.targetChapter, 4);
      expect(day(4).events, isEmpty);
      expect(day(7).events.single.title, 'Sin lectura');
      expect(day(8).events, isEmpty);
      expect(day(11).events.single.targetChapter, 6);
      expect(day(12).events.single.type, 'finish');

      await tester.tap(find.text('Actualizar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actualizar').last);
      await tester.pumpAndSettle();

      expect(events.deletedIds, isEmpty);
      expect(events.created, isEmpty);
      expect(events.updates.map((update) => update.$1).toSet(), {
        'e-3-chapter_milestone',
        'e-7-chapter_milestone',
        'e-11-finish',
      });
      final persistedById = {
        for (final update in events.updates) update.$1: update.$2,
      };
      expect(
        persistedById['e-3-chapter_milestone']?['dateLocal'],
        '2024-01-03',
      );
      expect(persistedById['e-3-chapter_milestone']?['targetChapter'], 4);
      expect(
        persistedById['e-7-chapter_milestone']?['dateLocal'],
        '2024-01-11',
      );
      expect(persistedById['e-7-chapter_milestone']?['targetChapter'], 6);
      expect(persistedById['e-11-finish']?['dateLocal'], '2024-01-12');
      expect(persistedById['e-11-finish']?['type'], 'finish');
    },
  );

  testWidgets('a completed deadline moves with the shifted calendar tail', (
    tester,
  ) async {
    await _pumpReplan(
      tester,
      liveEvents: [
        _ev('chapter_milestone', DateTime(2024, 7, 14), 'active', chapter: 4),
        _ev('deadline', DateTime(2024, 7, 15), 'completed'),
        _ev('chapter_milestone', DateTime(2024, 7, 16), 'active', chapter: 6),
      ],
    );

    await _toPreview(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is CalendarDayCell && widget.date == DateTime(2024, 7, 14),
      ),
    );
    await tester.pumpAndSettle();

    CalendarDayCell day(int value) => tester.widget<CalendarDayCell>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CalendarDayCell &&
            widget.date == DateTime(2024, 7, value),
      ),
    );

    expect(day(15).events.single.targetChapter, 4);
    expect(day(16).events.single.type, 'deadline');
    expect(day(16).events.single.status, 'completed');
    expect(day(17).events.single.targetChapter, 6);
  });
}

class _FakeProgressRepository extends ApiProgressRepository {
  _FakeProgressRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  int? updatedPage;
  int? updatedChapter;

  @override
  Future<Result<Progress>> update(
    String bookId, {
    int? page,
    int? chapter,
    int? percentage,
  }) async {
    updatedPage = page;
    updatedChapter = chapter;
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

String _ymdForTest(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _CapturingEventRepository extends ApiEventRepository {
  _CapturingEventRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  final List<Map<String, dynamic>> created = [];
  final List<(String, Map<String, dynamic>)> updates = [];
  final List<String> completedIds = [];
  final List<String> reopenedIds = [];
  final List<String> deletedIds = [];

  @override
  Future<Result<List<EventBatchResult>>> createBatch(
    List<Map<String, dynamic>> eventsBatch, {
    String? idempotencyKey,
  }) async {
    created.addAll(eventsBatch);
    return Ok([
      for (var index = 0; index < eventsBatch.length; index++)
        EventBatchResult(index: index, outcome: 'created', id: 'new-$index'),
    ]);
  }

  @override
  Future<Result<ReadingEvent>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    updates.add((id, body));
    return Ok(
      _ev(
        body['type'] as String,
        DateTime.parse(body['dateLocal'] as String),
        'completed',
        page: body['targetPage'] as int?,
      ),
    );
  }

  @override
  Future<Result<ReadingEvent>> complete(String id) async {
    completedIds.add(id);
    return Ok(_ev('page_milestone', DateTime.now(), 'completed'));
  }

  @override
  Future<Result<ReadingEvent>> uncomplete(String id) async {
    reopenedIds.add(id);
    return Ok(_ev('page_milestone', DateTime.now(), 'active'));
  }

  @override
  Future<Result<int>> deleteBatch(List<String> ids) async {
    deletedIds.addAll(ids);
    return Ok(ids.length);
  }
}

class _FailingCompleteEventRepository extends _CapturingEventRepository {
  @override
  Future<Result<ReadingEvent>> complete(String id) async =>
      const Err(NetworkFailure('offline'));
}

class _FailingUpdateEventRepository extends _CapturingEventRepository {
  @override
  Future<Result<ReadingEvent>> update(
    String id,
    Map<String, dynamic> body,
  ) async => const Err(NetworkFailure('offline'));
}

class _FailingSecondUpdateEventRepository extends _CapturingEventRepository {
  var _calls = 0;

  @override
  Future<Result<ReadingEvent>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    _calls++;
    if (_calls == 2) return const Err(NetworkFailure('offline'));
    return super.update(id, body);
  }
}

class _BlockingFirstUpdateEventRepository extends _CapturingEventRepository {
  final Completer<void> release = Completer<void>();
  var _calls = 0;

  @override
  Future<Result<ReadingEvent>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    _calls++;
    if (_calls == 1) await release.future;
    return super.update(id, body);
  }
}

class _FailingDeleteEventRepository extends _CapturingEventRepository {
  int deleteAttempts = 0;

  @override
  Future<Result<int>> deleteBatch(List<String> ids) async {
    deleteAttempts++;
    return const Err(NetworkFailure('offline'));
  }
}

class _UndoTrackingPlanRepository extends ApiPlanRepository {
  _UndoTrackingPlanRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  int undoCalls = 0;
  String? lastUndoId;

  @override
  Future<Result<int>> undoPlan(String planId) async {
    undoCalls += 1;
    lastUndoId = planId;
    return const Ok(3);
  }
}

class _NoopPlanRepository extends ApiPlanRepository {
  _NoopPlanRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'en',
        ),
      );

  @override
  Future<Result<PlanRun>> createPlanRun({
    required String id,
    required String bookId,
    required int eventCount,
    required String mode,
    required String unit,
    int? perDay,
    DateTime? startDate,
    DateTime? endDate,
    int? total,
    int? startUnit,
    Set<int>? excludedWeekdays,
    bool? remindersOn,
    bool? includeStart,
    bool? includeFinish,
    String? anchorEventId,
    String? anchorEventTitle,
  }) async => Ok(
    PlanRun(
      id: id,
      bookId: bookId,
      eventCount: eventCount,
      mode: mode,
      unit: unit,
      createdAt: DateTime.utc(2026),
    ),
  );
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
