part of 'providers.dart';

// ─── Data providers (auto-refreshing lists) ─────────

// These top-level lists are `autoDispose` + `_cacheWhileLoggedIn`, which gives
// us two behaviours at once:
//
//  • Within a session the cache is kept warm (the `keepAlive` link survives tab
//    swaps and pushes), so re-entering a view shows what's already in memory
//    instantly — no loading spinner. Screens revalidate in the background with
//    `RevalidateOnEnter`, and `when(skipLoadingOnRefresh: true)` keeps the
//    cached data on screen while the refetch runs (stale-while-revalidate).
//  • On logout the link is closed; with every data screen unmounted the
//    autoDispose provider tears down for real, so the next account re-fetches
//    from scratch — no empty pages, and no flash of the previous user's data.
//
// A plain `invalidate` is NOT enough for the reset: it keeps the previous value
// via `AsyncValue` "refreshing", which `valueOrNull` would surface as the prior
// account's data. Only a true dispose (autoDispose with the link closed) drops
// it.

/// Keeps an autoDispose provider warm for the lifetime of the logged-in
/// session, then lets it tear down on logout so per-user data never leaks into
/// the next account. Re-evaluated on every (re)build, so it stays correct
/// across background revalidations.
void _cacheWhileLoggedIn(Ref ref) {
  final link = ref.keepAlive();
  final sub = ref.listen<String?>(sessionProvider.select((s) => s.user?.id), (
    previous,
    next,
  ) {
    if (next == null) link.close();
  });
  ref.onDispose(sub.close);
}

final FutureProvider<List<Book>> booksProvider =
    FutureProvider.autoDispose<List<Book>>((ref) async {
      _cacheWhileLoggedIn(ref);
      final r = await ref.watch(bookRepoProvider).listMine();
      return _requireOk(r);
    });

/// Personal book IDs deleted this session. Overlay on [booksProvider] so
/// stale-while-revalidate cannot keep a deleted row tappable (Wanted / library
/// would otherwise still open it and 404 into the generic error screen).
final StateProvider<Set<String>> removedPersonalBookIdsProvider =
    StateProvider.autoDispose<Set<String>>((ref) {
      _cacheWhileLoggedIn(ref);
      return const <String>{};
    });

List<Book> excludeRemovedPersonalBooks(List<Book> books, Set<String> removed) {
  if (removed.isEmpty) return books;
  return [
    for (final book in books)
      if (!removed.contains(book.id)) book,
  ];
}

/// [booksProvider] minus [removedPersonalBookIdsProvider]. List screens must
/// watch this, not the raw fetch, after a local delete.
final Provider<AsyncValue<List<Book>>> visibleBooksProvider =
    Provider.autoDispose<AsyncValue<List<Book>>>((ref) {
      final removed = ref.watch(removedPersonalBookIdsProvider);
      final books = ref.watch(booksProvider);
      if (removed.isEmpty) return books;
      return books.whenData(
        (list) => excludeRemovedPersonalBooks(list, removed),
      );
    });

void rememberRemovedPersonalBook(WidgetRef ref, String id) {
  _rememberRemovedPersonalBookId(
    ref.read(removedPersonalBookIdsProvider.notifier),
    id,
  );
}

void rememberRemovedPersonalBookIn(ProviderContainer container, String id) {
  _rememberRemovedPersonalBookId(
    container.read(removedPersonalBookIdsProvider.notifier),
    id,
  );
}

void _rememberRemovedPersonalBookId(
  StateController<Set<String>> notifier,
  String id,
) {
  if (notifier.state.contains(id)) return;
  notifier.state = {...notifier.state, id};
}

final FutureProvider<List<ReadingEvent>>
upcomingEventsProvider = FutureProvider.autoDispose<List<ReadingEvent>>((
  ref,
) async {
  _cacheWhileLoggedIn(ref);
  final now = DateTime.now();
  final r = await ref
      .watch(eventRepoProvider)
      .list(
        from: now.subtract(const Duration(days: 30)),
        // Wide forward window so a freshly-created reading plan (which can start
        // weeks out and run for months) is visible when the plan flow jumps the
        // calendar to its first event's month.
        to: now.add(const Duration(days: 400)),
      );
  return _requireOk(r);
});

/// Exact date window rendered by the calendar. The interval is [from, to), using
/// civil-date boundaries.
///
/// Equality intentionally ignores DateTime timezone/clock fields because the
/// backend contract is a floating calendar date.
@immutable
class CalendarEventRange {
  const CalendarEventRange({
    required this.from,
    required this.to,
  });

  final DateTime from;
  final DateTime to;

  static int _dayKey(DateTime value) =>
      value.year * 10000 + value.month * 100 + value.day;

  @override
  bool operator ==(Object other) =>
      other is CalendarEventRange &&
      _dayKey(other.from) == _dayKey(from) &&
      _dayKey(other.to) == _dayKey(to);

  @override
  int get hashCode => Object.hash(_dayKey(from), _dayKey(to));
}

class CalendarEventsCache {
  final _items = <CalendarEventRange, List<ReadingEvent>>{};

  List<ReadingEvent>? read(CalendarEventRange range) => _items[range];

  void write(CalendarEventRange range, List<ReadingEvent> events) {
    _items[range] = List<ReadingEvent>.unmodifiable(events);
  }

  /// Seeds a visible period from the already-complete Home feed. The exact
  /// period provider still revalidates in the background; never overwrite an
  /// exact response with this broader, potentially older snapshot.
  void seedIfAbsent(
    CalendarEventRange range,
    Iterable<ReadingEvent> events,
  ) {
    if (_items.containsKey(range)) return;
    final fromKey = CalendarEventRange._dayKey(range.from);
    final toKey = CalendarEventRange._dayKey(range.to);
    _items[range] = List<ReadingEvent>.unmodifiable([
      for (final event in events)
        if (CalendarEventRange._dayKey(event.dateLocal) >= fromKey &&
            CalendarEventRange._dayKey(event.dateLocal) < toKey)
          event,
    ]);
  }

  /// Drop every cached row tagged with [planId]. Calendar reads the cache
  /// before the async period query, so a provider invalidate alone can leave
  /// deleted plan events visible until the refetch completes.
  void removePlanId(String planId) {
    for (final range in _items.keys.toList()) {
      final next = _items[range]!
          .where((event) => event.planId != planId)
          .toList(growable: false);
      _items[range] = List<ReadingEvent>.unmodifiable(next);
    }
  }

  void clear() => _items.clear();

  /// Home's wide feed can fill a newly opened period. Ignore a refresh/reload
  /// still carrying the previous library: that is how a local wipe used to
  /// stamp deleted events back onto an empty cache.
  void seedFromUpcomingIfReady(
    CalendarEventRange range,
    AsyncValue<List<ReadingEvent>> upcoming,
  ) {
    if (read(range) != null) return;
    if (!upcoming.hasValue || upcoming.isLoading) return;
    final value = upcoming.value;
    if (value == null) return;
    seedIfAbsent(range, value);
  }

  /// Prefer the in-memory cache (instant, including while a background refetch
  /// runs). If the cache was dropped, ignore a FutureProvider's previous value
  /// so deleted events cannot linger on the grid with an empty agenda.
  List<ReadingEvent> visibleFor(
    CalendarEventRange range,
    AsyncValue<List<ReadingEvent>> asyncEvents,
  ) {
    final cached = read(range);
    if (cached != null) return cached;
    if (asyncEvents.hasValue && asyncEvents.isLoading) {
      return const [];
    }
    return asyncEvents.value ?? const [];
  }
}

/// Session-scoped in-memory cache. Recreated when the user id or the local
/// library generation changes, so calendar data cannot leak across sessions
/// or "delete data on this device" wipes (those keep the same guest id).
final calendarEventsCacheProvider = Provider<CalendarEventsCache>((ref) {
  ref.watch(sessionProvider.select((session) => session.user?.id));
  ref.watch(dataPlaneTickProvider);
  return CalendarEventsCache();
});

final FutureProviderFamily<List<ReadingEvent>, CalendarEventRange>
calendarEventsProvider = FutureProvider.autoDispose
    .family<List<ReadingEvent>, CalendarEventRange>((ref, range) async {
      ref.watch(dataPlaneTickProvider);
      final repo = ref.watch(eventRepoProvider);
      final cache = ref.read(calendarEventsCacheProvider);
      final result = await repo.list(from: range.from, to: range.to);
      return result.fold(
        (value) {
          cache.write(range, value);
          return value;
        },
        (failure) {
          final cached = cache.read(range);
          if (cached != null) return cached;
          throw FailureException(failure);
        },
      );
    });

/// Invalidates every active month/week/day query after an event mutation.
///
/// Keep the in-memory values intact unless the cache is cleared: calendar
/// screens render them immediately while the invalidated providers revalidate
/// in the background. A local-library wipe must clear, otherwise the grid
/// keeps markers for events the store no longer has.
extension CalendarEventsRefInvalidation on Ref {
  void invalidateCalendarEvents({
    String? removedPlanId,
    bool clearCache = false,
  }) {
    final cache = read(calendarEventsCacheProvider);
    if (clearCache) {
      cache.clear();
    } else if (removedPlanId != null) {
      cache.removePlanId(removedPlanId);
    }
    invalidate(calendarEventsProvider);
  }
}

extension CalendarEventsWidgetRefInvalidation on WidgetRef {
  void invalidateCalendarEvents({
    String? removedPlanId,
    bool clearCache = false,
  }) {
    final cache = read(calendarEventsCacheProvider);
    if (clearCache) {
      cache.clear();
    } else if (removedPlanId != null) {
      cache.removePlanId(removedPlanId);
    }
    invalidate(calendarEventsProvider);
  }
}

/// Local, per-user timestamp (epoch ms) of the last time the user opened the
/// Calendar tab. Bumped by `MainShell` whenever the calendar tab becomes active;
/// mirrors the onboarding/clipboard local flags (no backend round-trip).
class CalendarSeenNotifier extends StateNotifier<int> {
  CalendarSeenNotifier(this._prefs, this._userId)
    : super(_prefs.getCalendarSeenAt(_userId));
  final PrefsStorage _prefs;
  final String _userId;

  Future<void> markSeenNow() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now <= state) return; // clock skew / re-entry guard
    state = now;
    await _prefs.setCalendarSeenAt(_userId, now);
  }
}

final calendarSeenAtProvider = StateNotifierProvider<CalendarSeenNotifier, int>(
  (ref) {
    final uid = ref.watch(sessionProvider).user?.id ?? '';
    return CalendarSeenNotifier(ref.watch(prefsStorageProvider), uid);
  },
);

/// Whether the Calendar bottom-nav tab should show a "novedades" dot: there is
/// at least one event still unseen (seenAt == null) that turned new or modified
/// *after* the user last opened the calendar. Opening the tab bumps
/// `calendarSeenAtProvider`, which clears the dot until the next update.
/// Local acknowledgement only; per-event badges keep using `seenAt`.
final Provider<bool> calendarNovedadesDotProvider = Provider.autoDispose<bool>((
  ref,
) {
  final events =
      ref.watch(upcomingEventsProvider).value ?? const <ReadingEvent>[];
  final seenAt = ref.watch(calendarSeenAtProvider);
  return events.any((e) {
    if (e.seenAt != null) return false;
    final stamp = e.updatedAt ?? e.createdAt;
    // No timestamp → treat as a fresh novelty so it isn't silently swallowed.
    return stamp == null || stamp.millisecondsSinceEpoch > seenAt;
  });
});

// Detail-backing `family` providers stay `autoDispose` (per-id entries are
// released on logout, never leaking to the next account) but use
// `_cacheWhileLoggedIn` so that, within a session, a previously-opened book
// stays warm. Re-opening a detail view then shows the cached entity instantly
// while `RevalidateOnEnter` refetches it in the background — the same
// stale-while-revalidate behaviour as the top-level lists.

final FutureProviderFamily<Book, String> bookProvider = FutureProvider
    .autoDispose
    .family<Book, String>((
      ref,
      id,
    ) async {
      _cacheWhileLoggedIn(ref);
      final r = await ref.watch(bookRepoProvider).get(id);
      return r.fold((v) => v, (f) => throw FailureException(f));
    });

/// Optimistic overlay for a single book. Set to a patched [Book] just before a
/// mutation's network call so the detail screen reflects it instantly; cleared
/// once the refetch confirms (revealing identical real data) or on failure
/// (reverting). Consumers should watch [bookViewProvider], not this directly.
final StateProviderFamily<Book?, String> bookOverlayProvider = StateProvider
    .autoDispose
    .family<Book?, String>(
      (ref, id) => null,
    );

/// The book as the UI should render it: the optimistic overlay when present,
/// otherwise the real [bookProvider] value. Lets rating/status edits show
/// immediately without waiting for the round-trip + refetch.
final ProviderFamily<AsyncValue<Book>, String>
bookViewProvider = Provider.autoDispose.family<AsyncValue<Book>, String>((
  ref,
  id,
) {
  if (ref.watch(removedPersonalBookIdsProvider).contains(id)) {
    return AsyncValue.error(
      const FailureException(NotFoundFailure()),
      StackTrace.empty,
    );
  }
  final overlay = ref.watch(bookOverlayProvider(id));
  final base = ref.watch(bookProvider(id));
  // Keep the overlay only while the base still has data to fall back on; if the
  // base errored or is reloading from scratch, defer to it so errors surface.
  if (overlay != null && base.hasValue) return AsyncValue.data(overlay);
  return base;
});

final FutureProvider<UserStats> userStatsProvider =
    FutureProvider.autoDispose<UserStats>((ref) async {
      _cacheWhileLoggedIn(ref);
      return loadLocalUserStats(ref.watch(localStoreProvider));
    });

/// Personal statistics for a particular page-activity period.
final FutureProviderFamily<UserStats, PageActivityQuery> userPageStatsProvider =
    FutureProvider.autoDispose.family<UserStats, PageActivityQuery>((
      ref,
      query,
    ) async {
      return loadLocalUserStats(
        ref.watch(localStoreProvider),
        query: query,
      );
    });

extension PersonalStatsRefInvalidation on Ref {
  void invalidatePersonalStats() {
    invalidate(userStatsProvider);
    invalidate(userPageStatsProvider);
  }
}

extension PersonalStatsWidgetRefInvalidation on WidgetRef {
  void invalidatePersonalStats() {
    invalidate(userStatsProvider);
    invalidate(userPageStatsProvider);
  }
}

final FutureProviderFamily<Progress, String> progressProvider = FutureProvider
    .autoDispose
    .family<Progress, String>((
      ref,
      bookId,
    ) async {
      _cacheWhileLoggedIn(ref);
      final r = await ref.watch(progressRepoProvider).get(bookId);
      return r.fold((v) => v, (f) => throw FailureException(f));
    });
