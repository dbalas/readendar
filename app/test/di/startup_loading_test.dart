import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('root-tab refresh map contains only screen-owned feeds', () {
    expect(mainTabDataProviders(0), [
      upcomingEventsProvider,
      booksProvider,
    ]);
    expect(mainTabDataProviders(1), [booksProvider]);
    expect(mainTabDataProviders(2), [
      upcomingEventsProvider,
      booksProvider,
    ]);
    expect(mainTabDataProviders(3), isEmpty);
    expect(mainTabDataProviders(4), isEmpty);
  });

  test('calendar badge stays lazy on a tab that does not use events', () async {
    var eventFetches = 0;
    final container = ProviderContainer(
      overrides: [
        tabIndexProvider.overrideWith((ref) => 1),
        upcomingEventsProvider.overrideWith((ref) async {
          eventFetches++;
          return const <ReadingEvent>[];
        }),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      shellCalendarNovedadesDotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);

    expect(container.read(shellCalendarNovedadesDotProvider), isFalse);
    expect(container.exists(upcomingEventsProvider), isFalse);
    expect(eventFetches, 0);
  });

  test('calendar badge shares the events feed on Home', () async {
    var eventFetches = 0;
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        tabIndexProvider.overrideWith((ref) => 0),
        upcomingEventsProvider.overrideWith((ref) async {
          eventFetches++;
          return const <ReadingEvent>[];
        }),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final sub = container.listen(
      shellCalendarNovedadesDotProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    expect(eventFetches, 1);
  });

  test(
    'calendar cache seeds a visible period without replacing exact data',
    () {
      final cache = CalendarEventsCache();
      final range = CalendarEventRange(
        from: DateTime(2026, 8),
        to: DateTime(2026, 9),
      );
      final august = _event('august', DateTime.utc(2026, 8, 12));
      final september = _event('september', DateTime.utc(2026, 9));

      cache.seedIfAbsent(range, [august, september]);
      expect(cache.read(range), [august]);

      final exact = _event('exact', DateTime.utc(2026, 8, 20));
      cache.write(range, [exact]);
      cache.seedIfAbsent(range, [august]);
      expect(cache.read(range), [exact]);
    },
  );

  test('calendar cache drops a plan id immediately on undo', () {
    final cache = CalendarEventsCache();
    final range = CalendarEventRange(
      from: DateTime(2026, 8),
      to: DateTime(2026, 9),
    );
    final kept = _event('kept', DateTime.utc(2026, 8, 10));
    final planned = ReadingEvent(
      id: 'planned',
      ownerType: 'user',
      ownerId: 'user-1',
      type: 'chapter_milestone',
      title: 'planned',
      dateLocal: DateTime.utc(2026, 8, 12),
      status: 'active',
      planId: 'p1',
    );
    cache.write(range, [kept, planned]);
    cache.removePlanId('p1');
    expect(cache.read(range), [kept]);
  });

  test('visibleFor prefers cache over provider data', () {
    final cache = CalendarEventsCache();
    final range = CalendarEventRange(
      from: DateTime(2026, 8),
      to: DateTime(2026, 9),
    );
    final kept = _event('kept', DateTime.utc(2026, 8, 10));
    final other = _event('other', DateTime.utc(2026, 8, 11));
    cache.write(range, [kept]);
    expect(cache.visibleFor(range, AsyncValue.data([other])), [kept]);
  });

  test('visibleFor uses provider data when the cache is empty', () {
    final cache = CalendarEventsCache();
    final range = CalendarEventRange(
      from: DateTime(2026, 8),
      to: DateTime(2026, 9),
    );
    final kept = _event('kept', DateTime.utc(2026, 8, 10));
    expect(cache.visibleFor(range, AsyncValue.data([kept])), [kept]);
  });

  test('seedFromUpcomingIfReady skips a loading feed', () {
    final cache = CalendarEventsCache();
    final range = CalendarEventRange(
      from: DateTime(2026, 8),
      to: DateTime(2026, 9),
    );
    cache.seedFromUpcomingIfReady(
      range,
      const AsyncLoading<List<ReadingEvent>>(),
    );
    expect(cache.read(range), isNull);
  });

  test('calendar events cache is recreated on data-plane tick', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final range = CalendarEventRange(
      from: DateTime(2026, 8),
      to: DateTime(2026, 9),
    );
    final first = container.read(calendarEventsCacheProvider);
    first.write(range, [_event('ghost', DateTime.utc(2026, 8, 10))]);
    container.read(dataPlaneTickProvider.notifier).state++;
    final second = container.read(calendarEventsCacheProvider);
    expect(identical(first, second), isFalse);
    expect(second.read(range), isNull);
  });
}

ReadingEvent _event(String id, DateTime day) => ReadingEvent(
  id: id,
  ownerType: 'user',
  ownerId: 'user-1',
  type: 'note',
  title: id,
  dateLocal: day,
  status: 'active',
);
