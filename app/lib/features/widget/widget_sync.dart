// Orchestrates the widget handoff. Product data is local: write the snapshot
// from on-device books/events/progress. Native widgets render that cache.
// Safe to call on session start, on relevant data changes, and from the Profile
// "add widget" flow.
//
// `WidgetRef` (used by widgets) and `Ref` (used by notifiers, e.g.
// `SessionNotifier`) don't share a common supertype in riverpod, so the actual
// implementation is parameterized over a plain `read` closure both can supply;
// `syncWidget` and `syncWidgetFromRef` are thin typed wrappers around it.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:home_widget/home_widget.dart';

import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/data/local/local_widget_summary.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_models.dart';

/// Writes the local library snapshot into the native widget cache.
/// For `ConsumerWidget`/`ConsumerState` call sites (have a `WidgetRef`).
Future<bool> syncWidget(WidgetRef ref) => _syncWidget(
  <T>(p) => ref.read(p),
  user: ref.read(sessionProvider).user,
);

/// Same as [syncWidget], for call sites holding a plain [Ref] (notifiers, e.g.
/// `SessionNotifier.setUser`). [user] must be supplied by the caller instead of
/// read from `sessionProvider` here: a `SessionNotifier` calling this with its
/// own `_ref` would otherwise have that `Ref` read `sessionProvider` — its own
/// provider — which riverpod forbids ("a provider cannot depend on itself").
/// For the same reason, session-owned callers pass [resolvedAppTheme] rather
/// than asking this function to read the session-derived effective provider.
Future<bool> syncWidgetFromRef(
  Ref ref,
  AppUser? user, {
  ReadendarThemeId? resolvedAppTheme,
}) => _syncWidget(
  <T>(p) => ref.read(p),
  user: user,
  resolvedAppTheme: resolvedAppTheme,
);

/// Same as [syncWidget], for async work that may outlive the widget which
/// started it. The app-level [ProviderContainer] remains valid when a route's
/// `WidgetRef` is disposed.
Future<bool> syncWidgetFromContainer(
  ProviderContainer container,
  AppUser? user,
) => _syncWidget(
  <T>(p) => container.read(p),
  user: user,
);

/// When true (set via `--dart-define=SHOT_CAPTURE=true` for the screenshot
/// harness) every home-screen widget sync is skipped: the native RemoteViews
/// update can exceed the emulator's widget bitmap budget and kill the process
/// mid-capture. Never true in shipped builds.
const _kShotCapture = bool.fromEnvironment('SHOT_CAPTURE');

Future<bool> _syncWidget(
  T Function<T>(ProviderListenable<T> provider) read, {
  required AppUser? user,
  ReadendarThemeId? resolvedAppTheme,
}) async {
  if (_kShotCapture) return false;

  // Read every provider synchronously up-front, before any await. Call sites
  // fire this and-forget then often pop their route (e.g. the event form), so
  // the caller's ref can be disposed by the time the awaits below resume —
  // read() on a disposed ref throws. Snapshotting here keeps all ref access on
  // the synchronous path.
  LocalStore? localStore;
  late final String locale;
  late final String themeMode;
  late final String appTheme;
  try {
    try {
      localStore = read(localStoreProvider);
    } on Object {
      localStore = null;
    }
    locale = 'es';
    themeMode = themeModeName(read(themeModeProvider));
    final ReadendarThemeId effectiveAppTheme;
    if (resolvedAppTheme != null) {
      effectiveAppTheme = resolvedAppTheme;
    } else {
      effectiveAppTheme = read(effectiveReadendarThemeProvider);
    }
    appTheme = effectiveAppTheme.wire;
  } catch (e) {
    debugPrint('syncWidget snapshot failed: $e');
    return false;
  }

  final store = localStore;
  if (store == null) return false;
  return _syncLocalWidget(
    store: store,
    userId: user?.id ?? localGuestUserId,
    locale: locale,
    themeMode: themeMode,
    appTheme: appTheme,
  );
}

Future<bool> _syncLocalWidget({
  required LocalStore store,
  required String userId,
  required String locale,
  required String themeMode,
  required String appTheme,
}) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await drainPendingWidgetOps(store);
    final books = <Book>[];
    final widgetCoverById = <String, String>{};
    for (final row in await store.list(LocalCollections.books)) {
      try {
        final book = Book.fromJson(row);
        books.add(book);
        widgetCoverById[book.id] = widgetSafeCoverUrl(row);
      } on Object {
        continue;
      }
    }
    final events = <ReadingEvent>[];
    for (final row in await store.list(LocalCollections.events)) {
      try {
        events.add(ReadingEvent.fromJson(row));
      } on Object {
        continue;
      }
    }
    final progressByBookId = <String, Progress>{};
    for (final row in await store.list(LocalCollections.progress)) {
      try {
        final progress = Progress.fromJson(row);
        progressByBookId[progress.bookEntryId] = progress;
      } on Object {
        continue;
      }
    }
    final snapshot = buildLocalWidgetSummary(
      books: books,
      events: events,
      progressByBookId: progressByBookId,
      now: DateTime.now().toUtc(),
      widgetCoverById: widgetCoverById,
    );
    await writeWidgetSummaryCache(snapshot);
    await _writeLocalQuotesCache(
      store: store,
      books: books,
      widgetCoverById: widgetCoverById,
    );
    return writeWidgetPayload(
      buildWidgetPayload(
        accessToken: '',
        refreshToken: '',
        userId: userId,
        apiBaseUrl: '',
        locale: locale,
        themeMode: themeMode,
        appTheme: appTheme,
      ),
    );
  } catch (e) {
    debugPrint('syncWidget local failed: $e');
    return false;
  }
}

Future<void> _writeLocalQuotesCache({
  required LocalStore store,
  required List<Book> books,
  Map<String, String> widgetCoverById = const {},
}) async {
  final booksById = {for (final book in books) book.id: book};
  final quotes = <Annotation>[];
  for (final row in await store.list(LocalCollections.annotations)) {
    try {
      quotes.add(Annotation.fromJson(row));
    } on Object {
      continue;
    }
  }
  quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final resolved = <WidgetQuote>[];
  for (final q in quotes) {
    if (q.category != AnnotationCategory.quote) continue;
    final b = booksById[q.bookId];
    if (b == null) continue;
    resolved.add(
      WidgetQuote(
        id: q.id,
        text: q.body,
        page: q.page,
        favorite: q.favorite,
        note: q.commentary,
        bookId: q.bookId,
        bookTitle: b.title,
        bookAuthor: b.authors.isEmpty ? '' : b.authors.first,
        bookCoverUrl: widgetCoverById[q.bookId] ?? b.coverUrl,
      ),
    );
    if (resolved.length >= kMaxWidgetQuotes) break;
  }
  final payload = WidgetQuotesPayload(
    fetchedAt: DateTime.now().toUtc(),
    quotes: resolved,
  );
  await HomeWidget.setAppGroupId(kWidgetAppGroupId);
  await HomeWidget.saveWidgetData<String>(
    kWidgetKeyQuotesCache,
    jsonEncode(payload.toJson()),
  );
  await reloadQuotesWidget();
}

/// Applies widget taps that native queued while the local plane had no JWT.
@visibleForTesting
Future<void> applyPendingWidgetOps(LocalStore store, String? raw) async {
  if (raw == null || raw.isEmpty || raw == '[]') return;
  late final Object decoded;
  try {
    decoded = jsonDecode(raw) as Object;
  } on Object {
    return;
  }
  if (decoded is! List) return;
  for (final item in decoded) {
    if (item is! Map) continue;
    final op = item['op'] as String? ?? '';
    if (op == 'progress') {
      final bookId = item['bookId'] as String? ?? '';
      if (bookId.isEmpty) continue;
      final field = item['field'] as String? ?? 'page';
      final value = (item['value'] as num?)?.toInt();
      if (value == null) continue;
      final existing =
          await store.get(LocalCollections.progress, bookId) ??
          <String, dynamic>{'bookEntryId': bookId};
      if (field == 'chapter') {
        existing['currentChapter'] = value;
      } else {
        existing['currentPage'] = value;
        final book = await store.get(LocalCollections.books, bookId);
        final pages = (book?['pageCount'] as num?)?.toInt();
        if (pages != null && pages > 0) {
          existing['currentPercentage'] = ((value * 100) / pages).round().clamp(
            0,
            100,
          );
        }
      }
      existing['bookEntryId'] = bookId;
      existing['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await store.put(LocalCollections.progress, bookId, existing);
    } else if (op == 'complete') {
      final eventId = item['eventId'] as String? ?? '';
      if (eventId.isEmpty) continue;
      final complete = item['complete'] == true;
      final row = await store.get(LocalCollections.events, eventId);
      if (row == null) continue;
      row['status'] = complete ? EventStatus.completed : EventStatus.active;
      await store.put(LocalCollections.events, eventId, row);
    }
  }
}

Future<void> drainPendingWidgetOps(LocalStore store) async {
  final raw = await HomeWidget.getWidgetData<String>(kWidgetKeyPendingOps);
  await applyPendingWidgetOps(store, raw);
  await HomeWidget.saveWidgetData<String>(kWidgetKeyPendingOps, '[]');
}

/// Drops cached reading rows whose in-app status is no longer `reading`.
/// Used when a finished book must not linger on the widget snapshot.
/// [booksById] empty is a no-op (same rule as quotes: do not wipe a good cache).
@visibleForTesting
WidgetSummary pruneFinishedReadingBooks(
  WidgetSummary cached,
  Map<String, Book> booksById,
) {
  if (booksById.isEmpty) return cached;
  final kept = <WidgetBook>[
    for (final b in cached.readingBooks)
      if (_keepCachedReadingBook(b, booksById)) b,
  ];
  if (kept.length == cached.readingBooks.length) return cached;
  return WidgetSummary(
    readingBooks: kept,
    events: cached.events,
    hasMore: cached.hasMore,
  );
}

bool _keepCachedReadingBook(WidgetBook b, Map<String, Book> booksById) {
  final book = booksById[b.id];
  if (book == null) return true;
  return book.status == BookStatus.reading;
}

Future<void> pruneStaleWidgetSummaryCache(
  T Function<T>(ProviderListenable<T> provider) read,
) async {
  try {
    final books = read(booksByIdProvider);
    if (books.isEmpty) return;
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    final raw = await HomeWidget.getWidgetData<String?>(
      kWidgetKeyCachedSummary,
    );
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    final cached = WidgetSummary.fromJson(Map<String, dynamic>.from(decoded));
    final pruned = pruneFinishedReadingBooks(cached, books);
    if (identical(pruned, cached)) return;
    await writeWidgetSummaryCache(pruned);
  } catch (e) {
    debugPrint('pruneStaleWidgetSummaryCache failed: $e');
  }
}

/// Cap so the app-pushed quotes cache stays bounded.
const kMaxWidgetQuotes = 500;

/// Resolves the current in-app quotes against the loaded books into the widget
/// snapshot shape — the exact set (and order) both `syncQuotesWidget` (which
/// pushes it to the native cache) and the in-app preview render from, so the
/// preview shows precisely what the widget will. Mirrors
/// `usecase/widget.ListAnnotations`: newest-first, quotes whose book can't be
/// resolved are dropped FIRST, then capped at [kMaxWidgetQuotes].
///
/// Returns null when the quotes list isn't loaded yet (cold start) — callers
/// distinguish "not loaded" from "loaded but empty" ([].
List<WidgetQuote>? resolveWidgetQuotes(
  T Function<T>(ProviderListenable<T> provider) read,
) {
  final quotes = read(quotesControllerProvider).value;
  if (quotes == null) return null;
  final booksById = read(booksByIdProvider);
  final resolved = <WidgetQuote>[];
  for (final q in quotes) {
    if (q.category != AnnotationCategory.quote) continue;
    final b = booksById[q.bookId];
    if (b == null) continue;
    resolved.add(
      WidgetQuote(
        id: q.id,
        text: q.body,
        page: q.page,
        favorite: q.favorite,
        note: q.commentary,
        bookId: q.bookId,
        bookTitle: b.title,
        bookAuthor: b.authors.isEmpty ? '' : b.authors.first,
        bookCoverUrl: b.coverUrl,
      ),
    );
    if (resolved.length >= kMaxWidgetQuotes) break;
  }
  return resolved;
}

/// Pushes the current quotes snapshot into the shared store the quotes widget
/// renders from, then reloads it. The app already holds quotes + books, so
/// this makes widget updates instant after a mutation instead of waiting for
/// the native refresh poll. No-op while the quotes list isn't loaded (the
/// native fetch path still covers that case).
///
/// The resolution mirrors `usecase/widget.ListAnnotations`: newest-first, quotes
/// whose book can't be resolved are dropped, capped at [kMaxWidgetQuotes].
Future<void> syncQuotesWidget(WidgetRef ref) => _syncQuotesWidget(
  ref.read,
  hasInAppQuotes: _quotesWidgetHasInAppQuotes(ref.read, ref.exists),
);

/// Same as [syncQuotesWidget] for plain [Ref] call sites (notifiers/hooks).
///
/// Do **not** call this with [QuotesController]'s own `Ref`: that Ref's
/// `exists`/`read` of [quotesControllerProvider] asserts "a provider cannot
/// depend on itself". Mutation hooks must use a [WidgetRef] (e.g. app Gate)
/// or another provider's Ref — same rule as [syncWidgetFromRef] + session.
Future<void> syncQuotesWidgetFromRef(Ref ref) => _syncQuotesWidget(
  ref.read,
  hasInAppQuotes: _quotesWidgetHasInAppQuotes(ref.read, ref.exists),
);

/// Whether the API-plane quotes sync should read [quotesControllerProvider].
///
/// When [localStoreProvider] is installed (production app), [_syncQuotesWidget]
/// always builds the cache from on-device annotations and never needs the
/// in-app controller. Probing `exists(quotesControllerProvider)` in that case
/// is wrong and can race [QuotesController] mid-build during
/// [SessionNotifier] bootstrap → [CircularDependencyError].
bool _quotesWidgetHasInAppQuotes(
  T Function<T>(ProviderListenable<T> provider) read,
  bool Function(ProviderBase<Object?> provider) exists,
) {
  try {
    read(localStoreProvider);
    return false;
  } on Object {
    return exists(quotesControllerProvider);
  }
}

Future<void> _syncQuotesWidget(
  T Function<T>(ProviderListenable<T> provider) read, {
  required bool hasInAppQuotes,
}) async {
  if (_kShotCapture) return;
  LocalStore? store;
  try {
    store = read(localStoreProvider);
  } on Object {
    store = null;
  }
  if (store != null) {
    try {
      final books = <Book>[];
      for (final row in await store.list(LocalCollections.books)) {
        try {
          books.add(Book.fromJson(row));
        } on Object {
          continue;
        }
      }
      await _writeLocalQuotesCache(store: store, books: books);
    } on Object catch (e) {
      debugPrint('syncQuotesWidget local failed: $e');
    }
    return;
  }
  try {
    // A resume widget refresh must not instantiate QuotesController: its
    // constructor downloads the user's entire quote collection. When the quotes
    // UI has not been opened this session, let the native widget refresh itself
    // from its narrow endpoint using the already-shared widget token instead.
    if (!hasInAppQuotes) {
      await reloadQuotesWidget();
      return;
    }
    final resolved = resolveWidgetQuotes(read);
    // Quotes not loaded yet (cold start / cold resume): we can't build a
    // snapshot, but still reload so the NATIVE side re-fetches from the server
    // with the shared token — otherwise (reloadWidget no longer reloads the
    // quotes widget) nothing would refresh it on a cold resume.
    if (resolved == null) {
      await reloadQuotesWidget();
      return;
    }
    // The user has quotes but none resolved (books not loaded yet, or none of
    // the quotes' books are in the map): don't overwrite a good native cache
    // with an empty snapshot — reload so the native side re-fetches instead.
    // Notes/theories/questions in the same list are not widget quotes.
    final quotesLoaded = (read(quotesControllerProvider).value ?? const [])
        .where((q) => q.category == AnnotationCategory.quote);
    if (quotesLoaded.isNotEmpty && resolved.isEmpty) {
      await reloadQuotesWidget();
      return;
    }
    final payload = WidgetQuotesPayload(
      fetchedAt: DateTime.now().toUtc(),
      quotes: resolved,
    );
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await HomeWidget.saveWidgetData<String>(
      kWidgetKeyQuotesCache,
      jsonEncode(payload.toJson()),
    );
    await reloadQuotesWidget();
  } catch (e) {
    debugPrint('syncQuotesWidget failed: $e');
  }
}
