import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  final eventRepoOverride = eventRepoProvider.overrideWithValue(
    _FakeEventRepository(),
  );

  testWidgets('renders linked book title and author', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final event = ReadingEvent(
      id: 'event-1',
      ownerType: 'user',
      ownerId: 'user-1',
      bookId: book.id,
      type: 'page_milestone',
      title: 'Read to page 80',
      dateLocal: DateTime.utc(2026, 6, 12),
      status: EventStatus.active,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepoOverride],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: EventDetailSheet(event: event, book: book),
          ),
        ),
      ),
    );

    expect(find.text('Hito de página'), findsOneWidget);
    expect(find.text('Read to page 80'), findsNothing);
    expect(find.text('Pedro Paramo'), findsWidgets);
    expect(find.text('Juan Rulfo'), findsOneWidget);
  });

  testWidgets('opens book detail when the linked book row is tapped', (
    tester,
  ) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
    );
    final event = ReadingEvent(
      id: 'event-1',
      ownerType: 'user',
      ownerId: 'user-1',
      bookId: book.id,
      type: 'page_milestone',
      title: 'Read to page 80',
      dateLocal: DateTime.utc(2026, 6, 12),
      status: EventStatus.active,
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dir = Directory.systemTemp.createTempSync('event-detail');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final store = LocalStore.memory(Directory('${dir.path}/covers')..createSync());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          eventRepoOverride,
          sharedPreferencesProvider.overrideWithValue(prefs),
          localStoreProvider.overrideWithValue(store),
          bookProvider.overrideWith((ref, id) async => book),
          booksProvider.overrideWith((ref) async => [book]),
          eventsForBookProvider(book.id).overrideWith(
            (ref) => const AsyncValue.data(<ReadingEvent>[]),
          ),
          progressProvider(book.id).overrideWith(
            (ref) async => Progress(bookEntryId: book.id),
          ),
          bookPlansProvider(book.id).overrideWith((ref) async => <PlanRun>[]),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => RdButton.primary(
                label: 'Open event',
                onPressed: () => showEventDetailSheet(context, event, book: book),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedro Paramo').last);
    await tester.pumpAndSettle();

    expect(find.byType(BookDetailScreen), findsOneWidget);
    expect(tester.widget<BookDetailScreen>(find.byType(BookDetailScreen)).bookId, 'book-1');
  });

  testWidgets('selection mode offers Plan until here for a future event', (
    tester,
  ) async {
    ReadingEvent? picked;
    final event = _futureEvent();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepoOverride],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: EventDetailSheet(
              event: event,
              onPlanUntilHere: (e) => picked = e,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Planificar hasta aquí'), findsOneWidget);
    expect(find.text('¡Completar!'), findsNothing);
    expect(find.byIcon(LucideIcons.edit), findsNothing);

    await tester.tap(find.text('Planificar hasta aquí'));
    await tester.pumpAndSettle();
    expect(picked?.id, event.id);
  });

  testWidgets('selection mode disables Plan until here for a past event', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepoOverride],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: EventDetailSheet(
              event: _pastEvent(),
              onPlanUntilHere: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Planificar hasta aquí'), findsOneWidget);
    expect(
      find.text('Elige un evento de hoy o futuro.'),
      findsOneWidget,
    );
    final button = tester.widget<RdButton>(
      find.widgetWithText(RdButton, 'Planificar hasta aquí'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('lets a completed event be marked pending again', (tester) async {
    final events = _FakeEventRepository();
    final event = ReadingEvent(
      id: 'event-1',
      ownerType: 'user',
      ownerId: 'user-1',
      type: 'page_milestone',
      title: 'Read to page 80',
      dateLocal: DateTime.utc(2026, 6, 12),
      status: EventStatus.completed,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepoProvider.overrideWithValue(events)],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildDarkTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(body: EventDetailSheet(event: event)),
        ),
      ),
    );

    await tester.tap(find.text('Reabrir'));
    await tester.pumpAndSettle();

    expect(events.uncompletedEventId, event.id);
  });

  testWidgets('completing an event refreshes the active calendar range', (
    tester,
  ) async {
    final events = _FakeEventRepository();
    final range = CalendarEventRange(
      from: DateTime(2026, 6),
      to: DateTime(2026, 7),
    );
    var calendarLoads = 0;
    final container = ProviderContainer(
      overrides: [
        eventRepoProvider.overrideWithValue(events),
        calendarEventsProvider.overrideWith((ref, requestedRange) async {
          calendarLoads++;
          return const <ReadingEvent>[];
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      calendarEventsProvider(range),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(calendarEventsProvider(range).future);

    final event = ReadingEvent(
      id: 'event-1',
      ownerType: 'user',
      ownerId: 'user-1',
      type: 'deadline',
      title: 'Terminar el libro',
      dateLocal: DateTime.utc(2026, 6, 12),
      status: EventStatus.active,
      seenAt: DateTime.utc(2026, 6, 1),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(body: EventDetailSheet(event: event)),
        ),
      ),
    );

    await tester.tap(find.text('¡Completar!'));
    await tester.pumpAndSettle();

    expect(events.completedEventId, event.id);
    expect(calendarLoads, 2);
  });

  testWidgets('shows the complete action for an active completable event', (
    tester,
  ) async {
    final event = ReadingEvent(
      id: 'event-1',
      ownerType: 'user',
      ownerId: 'user-1',
      type: 'page_milestone',
      title: 'Read to page 80',
      dateLocal: DateTime.utc(2026, 6, 12),
      status: EventStatus.active,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepoOverride],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildLightTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(body: EventDetailSheet(event: event)),
        ),
      ),
    );

    final action = tester.widget<RdButton>(
      find.widgetWithText(RdButton, '¡Completar!'),
    );
    expect(action.variant, RdButtonVariant.primary);
    expect(action.icon, LucideIcons.check);
  });

  testWidgets(
    'shows a colored re-plan icon immediately before edit for an active plan event',
    (tester) async {
      final book = Book(
        id: 'book-1',
        ownerType: 'user',
        ownerId: 'user-1',
        title: 'Pedro Paramo',
        authors: const ['Juan Rulfo'],
        status: BookStatus.reading,
        chapterCount: 300,
      );
      final event = ReadingEvent(
        id: 'event-1',
        ownerType: 'user',
        ownerId: 'user-1',
        bookId: book.id,
        type: 'chapter_milestone',
        title: 'Chapter 50',
        dateLocal: DateTime.utc(2099, 1, 10),
        status: EventStatus.active,
        targetChapter: 50,
        planId: 'plan-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepoOverride,
            progressProvider('book-1').overrideWith(
              (ref) async =>
                  Progress(bookEntryId: 'book-1', currentChapter: 10),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            theme: buildLightTheme(),
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Scaffold(
              body: EventDetailSheet(event: event, book: book),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Planificar hasta aquí'), findsNothing);
      expect(find.text('Replanificar'), findsNothing);
      final replanIcon = find.byIcon(LucideIcons.calendarSync);
      final editIcon = find.byIcon(LucideIcons.edit);
      expect(replanIcon, findsOneWidget);
      expect(editIcon, findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: replanIcon,
                matching: find.byType(IconButton),
              ),
            )
            .color,
        ReadendarColors.light.accent,
      );
      expect(
        tester.getTopLeft(replanIcon).dx,
        lessThan(tester.getTopLeft(editIcon).dx),
      );
    },
  );

  testWidgets('a completed event in a plan still offers the re-plan icon, '
      'without "Plan up to here"', (tester) async {
    final book = Book(
      id: 'book-1',
      ownerType: 'user',
      ownerId: 'user-1',
      title: 'Pedro Paramo',
      authors: const ['Juan Rulfo'],
      status: BookStatus.reading,
      chapterCount: 300,
    );
    final event = ReadingEvent(
      id: 'event-1',
      ownerType: 'user',
      ownerId: 'user-1',
      bookId: book.id,
      type: 'chapter_milestone',
      title: 'Chapter 50',
      dateLocal: DateTime.utc(2099, 1, 10),
      status: EventStatus.completed,
      targetChapter: 50,
      planId: 'plan-1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [eventRepoOverride],
        child: MaterialApp(
          locale: const Locale('es'),
          theme: buildDarkTheme(),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Scaffold(
            body: EventDetailSheet(event: event, book: book),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planificar hasta aquí'), findsNothing);
    expect(find.text('Replanificar'), findsNothing);
    final replanIcon = find.byIcon(LucideIcons.calendarSync);
    expect(replanIcon, findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(of: replanIcon, matching: find.byType(IconButton)),
          )
          .color,
      ReadendarColors.dark.accent,
    );
  });




}

class _FakeEventRepository extends ApiEventRepository {
  _FakeEventRepository()
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _FakeSecureTokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  String? reminderEventId;
  bool? reminderEnabled;
  int? reminderMinutes;
  String? uncompletedEventId;
  String? completedEventId;

  @override
  Future<Result<EventUserState>> markSeen(String id) async => Ok(
    EventUserState(
      eventId: id,
      status: 'active',
      reminderEnabled: false,
      muted: false,
      seenAt: DateTime.utc(2026),
    ),
  );

  @override
  Future<Result<ReadingEvent>> complete(String id) async {
    completedEventId = id;
    return Ok(
      ReadingEvent(
        id: id,
        ownerType: 'user',
        ownerId: 'user-1',
        type: 'deadline',
        title: 'Terminar el libro',
        dateLocal: DateTime.utc(2026, 6, 12),
        status: EventStatus.completed,
      ),
    );
  }

  @override
  Future<Result<ReadingEvent>> uncomplete(String id) async {
    uncompletedEventId = id;
    return Ok(
      ReadingEvent(
        id: id,
        ownerType: 'user',
        ownerId: 'user-1',
        type: 'page_milestone',
        title: 'Read to page 80',
        dateLocal: DateTime.utc(2026, 6, 12),
        status: EventStatus.active,
      ),
    );
  }

  @override
  Future<Result<EventUserState>> setUserReminder(
    String id, {
    required bool enabled,
    int? minutesBefore,
  }) async {
    reminderEventId = id;
    reminderEnabled = enabled;
    reminderMinutes = minutesBefore;
    return Ok(
      EventUserState(
        eventId: id,
        status: 'active',
        reminderEnabled: enabled,
        reminderMinutesBefore: minutesBefore,
        muted: false,
        seenAt: DateTime.utc(2026),
      ),
    );
  }
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}

ReadingEvent _futureEvent() {
  final tomorrow = DateTime.now().add(const Duration(days: 2));
  return ReadingEvent(
    id: 'event-future',
    ownerType: 'user',
    ownerId: 'user-1',
    type: 'deadline',
    title: 'Deadline',
    dateLocal: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
    status: EventStatus.active,
  );
}

ReadingEvent _pastEvent() => ReadingEvent(
  id: 'event-past',
  ownerType: 'user',
  ownerId: 'user-1',
  type: 'deadline',
  title: 'Old deadline',
  dateLocal: DateTime(2020),
  status: EventStatus.active,
);
