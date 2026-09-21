part of 'providers.dart';

// ─── Quotes ──────────────────────────────────────────

/// Single source of truth for the user's quotes: loads once, then applies
/// mutations in place. Favorite/delete are OPTIMISTIC — the list mutates
/// immediately, the repo call runs, and on failure the previous list is
/// restored (the caller surfaces the returned [Failure]). Create/update wait
/// for the server (the composer shows its own progress state).
class QuotesController extends StateNotifier<AsyncValue<List<Quote>>> {
  QuotesController(this._ref) : super(const AsyncValue.loading()) {
    _load();
  }
  final Ref _ref;

  List<Quote> get _current => state.value ?? const [];

  Future<void> _load() async {
    final r = await _ref.read(quoteRepoProvider).listMine();
    if (!mounted) return;
    state = r.fold(
      AsyncValue.data,
      (f) => AsyncValue.error(FailureException(f), StackTrace.current),
    );
  }

  Future<void> refresh() => _load();

  void _afterMutation() {
    // Bump a sibling provider so Gate can sync the native quotes widget.
    // Never call syncQuotesWidget from this Ref: it reads
    // quotesControllerProvider, and a provider cannot depend on itself.
    _ref.read(quotesMutationTickProvider.notifier).state++;
  }

  Future<Result<Quote>> create({
    required String bookId,
    String? body,
    String? text,
    AnnotationCategory category = AnnotationCategory.quote,
    int? page,
    int? chapter,
    bool pinned = false,
    bool favorite = false,
    String commentary = '',
    String note = '',
    bool spoiler = false,
  }) async {
    final r = await _ref
        .read(quoteRepoProvider)
        .create(
          bookId: bookId,
          body: body ?? text ?? '',
          text: text,
          category: category,
          page: page,
          chapter: chapter,
          pinned: pinned,
          favorite: favorite,
          commentary: commentary,
          note: note,
          spoiler: spoiler,
        );
    if (mounted) {
      r.fold((q) {
        state = AsyncValue.data([q, ..._current]);
        _afterMutation();
        _ref.invalidate(bookAnnotationsProvider(q.bookId));
      }, (_) {});
    }
    return r;
  }

  Future<Result<Quote>> updateQuote(Quote q) async {
    final r = await _ref.read(quoteRepoProvider).update(q);
    if (mounted) {
      r.fold((updated) {
        _replace(updated);
        _afterMutation();
        _ref.invalidate(bookAnnotationsProvider(updated.bookId));
      }, (_) {});
    }
    return r;
  }

  /// Optimistic pin toggle. Returns the failure (already rolled back) or
  /// null on success.
  Future<Failure?> togglePin(Quote q) async {
    final prev = state;
    final toggled = q.copyWith(pinned: !q.pinned);
    _replace(toggled);
    final r = await _ref.read(quoteRepoProvider).update(toggled);
    if (!mounted) return r.failure;
    return r.fold(
      (updated) {
        _replace(updated);
        _afterMutation();
        _ref.invalidate(bookAnnotationsProvider(updated.bookId));
        return null;
      },
      (f) {
        state = prev;
        return f;
      },
    );
  }

  /// Optimistic favorite toggle. Returns the failure (already rolled back) or
  /// null on success.
  Future<Failure?> toggleFavorite(Quote q) async {
    final prev = state;
    final toggled = q.copyWith(favorite: !q.favorite);
    _replace(toggled);
    final r = await _ref.read(quoteRepoProvider).update(toggled);
    if (!mounted) return r.failure;
    return r.fold(
      (updated) {
        _replace(updated);
        _afterMutation();
        _ref.invalidate(bookAnnotationsProvider(updated.bookId));
        return null;
      },
      (f) {
        state = prev;
        return f;
      },
    );
  }

  /// Optimistic delete. Returns the failure (already rolled back) or null.
  Future<Failure?> delete(String id) async {
    final prev = state;
    final removed = _current.where((q) => q.id == id).firstOrNull;
    state = AsyncValue.data(_current.where((q) => q.id != id).toList());
    final r = await _ref.read(quoteRepoProvider).delete(id);
    if (!mounted) return r.failure;
    return r.fold(
      (_) {
        _afterMutation();
        if (removed != null) {
          _ref.invalidate(bookAnnotationsProvider(removed.bookId));
        }
        return null;
      },
      (f) {
        state = prev;
        return f;
      },
    );
  }

  void _replace(Quote q) {
    state = AsyncValue.data([
      for (final e in _current) e.id == q.id ? q : e,
    ]);
  }
}

/// Incremented after every quotes mutation. Gate listens and syncs the native
/// quotes widget + spotlight from its own [WidgetRef], never from this
/// controller's Ref (that would self-depend on [quotesControllerProvider]).
final quotesMutationTickProvider = StateProvider<int>((ref) => 0);

final StateNotifierProvider<QuotesController, AsyncValue<List<Quote>>>
quotesControllerProvider =
    StateNotifierProvider.autoDispose<
      QuotesController,
      AsyncValue<List<Quote>>
    >((
      ref,
    ) {
      _cacheWhileLoggedIn(ref);
      return QuotesController(ref);
    });

/// Annotations of one book via `/v1/books/{id}/annotations`.
final FutureProviderFamily<List<Annotation>, String> bookAnnotationsProvider =
    FutureProvider.autoDispose.family<List<Annotation>, String>((
      ref,
      bookId,
    ) async {
      _cacheWhileLoggedIn(ref);
      final r = await ref.watch(annotationRepoProvider).listForBook(bookId);
      return _requireOk(r);
    });

/// Legacy name: same as [bookAnnotationsProvider].
final bookQuotesProvider = bookAnnotationsProvider;

/// id → personal book, for event-card resolution.
final Provider<Map<String, Book>> booksByIdProvider =
    Provider.autoDispose<Map<String, Book>>((ref) {
      final books = ref.watch(visibleBooksProvider).value ?? const <Book>[];
      return {for (final b in books) b.id: b};
    });

final FutureProviderFamily<ReadingEvent, String> eventProvider = FutureProvider
    .autoDispose
    .family<ReadingEvent, String>((
      ref,
      id,
    ) async {
      final r = await ref.watch(eventRepoProvider).get(id);
      return r.fold((v) => v, (f) => throw FailureException(f));
    });

/// Full event history for one book (no date window), fetched directly from the
/// backend. Unlike [eventsForBookProvider] — which slices the ±window
/// `upcomingEventsProvider` — this loads every event so the finish-book
/// celebration can compute days-to-finish / session counts for long reads.
final FutureProviderFamily<List<ReadingEvent>, String>
bookEventsHistoryProvider = FutureProvider.autoDispose
    .family<List<ReadingEvent>, String>((ref, bookId) async {
      final r = await ref.watch(eventRepoProvider).listForBook(bookId);
      return _requireOk(r);
    });

/// Recent reading-plan runs for a book (spec §6.9), most-recent first, capped at
/// 10 by the backend. Backs the book-detail "last planned" caption and the plan
/// history screen.
final FutureProviderFamily<List<PlanRun>, String> bookPlansProvider =
    FutureProvider.autoDispose.family<List<PlanRun>, String>((
      ref,
      bookId,
    ) async {
      final r = await ref.watch(planRepoProvider).listPlans(bookId);
      return _requireOk(r);
    });

/// Whether the device currently has any network transport. Product lists no
/// longer consult this; catalog search and the one-time cloud import still do.
/// Defaults to online while the first check is in flight (no banner flash).
/// Deliberately NOT autoDispose: the shell watches it for the app's whole
/// lifetime, and keeping one connectivity subscription warm avoids
/// re-subscribing churn on auth/shell transitions.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> rs) =>
      rs.any((r) => r != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  await for (final results in connectivity.onConnectivityChanged) {
    yield online(results);
  }
});

/// The selected tab index of the root [MainShell]. Exposed as a provider (vs.
/// local `setState`) so flows pushed above the shell — e.g. the finish-book
/// celebration's "Go to my library" — can deterministically select a tab.
final tabIndexProvider = StateProvider<int>((ref) => 0);

/// Data feeds owned by each root tab. Startup/resume code uses this mapping so
/// a foreground return refreshes only what the user can currently see instead
/// of waking every session-cached collection.
List<ProviderBase<Object?>> mainTabDataProviders(int tabIndex) =>
    switch (tabIndex) {
      0 => [upcomingEventsProvider, booksProvider],
      1 => [booksProvider],
      2 => [upcomingEventsProvider, booksProvider],
      _ => const [],
    };

/// Calendar-dot projection for the root shell. On Home/Calendar the events feed
/// belongs to the active screen anyway. On other tabs, consume it only if that
/// feed is already warm; navigation chrome must never start a wide request.
final Provider<bool> shellCalendarNovedadesDotProvider =
    Provider.autoDispose<bool>((ref) {
      final tabIndex = ref.watch(tabIndexProvider);
      final activeScreenUsesEvents = tabIndex == 0 || tabIndex == 2;
      if (!activeScreenUsesEvents && !ref.exists(upcomingEventsProvider)) {
        return false;
      }
      return ref.watch(calendarNovedadesDotProvider);
    });

/// When set, the calendar screen jumps to this day's month and selects it on its
/// next build, then clears the value. Used by the reading-plan completion screen
/// to land the user on the first generated event's month.
final calendarFocusProvider = StateProvider<DateTime?>((ref) => null);

/// Events for a specific book, derived once from `upcomingEventsProvider` so
/// the book detail screen doesn't re-filter the full event list on every
/// rebuild and so subsequent rebuilds don't trigger downstream listeners
/// when the filtered slice is unchanged.
final ProviderFamily<AsyncValue<List<ReadingEvent>>, String>
eventsForBookProvider = Provider.autoDispose
    .family<AsyncValue<List<ReadingEvent>>, String>((ref, bookId) {
      return ref
          .watch(upcomingEventsProvider)
          .whenData(
            (list) =>
                list.where((e) => e.bookId == bookId).toList(growable: false),
          );
    });

final FutureProvider<NotificationPreferences> notificationPrefsProvider =
    FutureProvider.autoDispose<NotificationPreferences>((ref) async {
      _cacheWhileLoggedIn(ref);
      final r = await ref.watch(notificationRepoProvider).get();
      return _requireOk(r);
    });

final FutureProvider<Set<String>> existingIsbnsProvider =
    FutureProvider.autoDispose<Set<String>>((
      ref,
    ) async {
      final books = await ref.watch(booksProvider.future);
      final result = <String>{};
      for (final book in books) {
        final key = isbnComparisonKey(book.isbnDisplay);
        if (key.isNotEmpty) result.add(key);
      }
      return result;
    });
