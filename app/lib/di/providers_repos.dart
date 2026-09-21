part of 'providers.dart';

// ─── API client ──────────────────────────────────────

bool _skipSessionClear(Ref ref) {
  if (!apiWindowOpen) return true;
  try {
    return PrefsStorage(ref.read(sharedPreferencesProvider)).getDataPlane() ==
        'local';
  } on Object {
    return false;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    storage: storage,
    localeProvider: () {
      final l = ref.read(localeProvider);
      return l == null ? 'es' : localeToTag(l);
    },
    onLoggedOut: () => ref.read(sessionProvider.notifier).clear(),
    skipSessionClear: () => _skipSessionClear(ref),
    enableLogging: kDebugMode,
  );
});

// ─── Repositories ────────────────────────────────────

final authRepoProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);
final userRepoProvider = Provider<UserRepository>(
  (ref) => ApiUserRepository(ref.watch(apiClientProvider)),
);
final localStoreProvider = Provider<LocalStore>((ref) {
  throw StateError('localStoreProvider must be overridden in main');
});

final dataPlaneTickProvider = StateProvider<int>((ref) => 0);

/// True while cloud import is still offered (API window open, not yet
/// imported). The download card can log the user in if no leftover JWT
/// is present. Product data stays on the local plane.
final cloudImportAvailableProvider = StateProvider<bool>((ref) => false);

/// True from the moment any surface starts cloud-import auth until that
/// import finishes or is cancelled. Home must not auto-start a second fetch.
final cloudImportInFlightProvider = StateProvider<bool>((ref) => false);

final dataPlaneProvider = Provider<DataPlane>((ref) {
  ref.watch(dataPlaneTickProvider);
  return DataPlane.local;
});

T _localProductRepo<T>(
  Ref ref, {
  required T Function(LocalStore store) local,
}) {
  // Wiping the local library bumps this tick without changing DataPlane, so
  // repos must watch it directly.
  ref.watch(dataPlaneTickProvider);
  return local(ref.watch(localStoreProvider));
}

T _requireOk<T>(Result<T> result) {
  return result.fold(
    (value) => value,
    (failure) => throw FailureException(failure),
  );
}

final bookRepoProvider = Provider<BookRepository>(
  (ref) => _localProductRepo(ref, local: LocalBookRepository.new),
);
final customFieldRepoProvider = Provider<CustomFieldRepository>(
  (ref) => _localProductRepo(ref, local: LocalCustomFieldRepository.new),
);
final eventRepoProvider = Provider<EventRepository>(
  (ref) => _localProductRepo(ref, local: LocalEventRepository.new),
);
final progressRepoProvider = Provider<ProgressRepository>(
  (ref) => _localProductRepo(ref, local: LocalProgressRepository.new),
);

/// The compact snapshot the native widget renders, fetched for the in-app
/// preview (the "add widget" sheet shows the user what their widget will look
/// like). Same endpoint the native widget self-fetches; here it feeds a Dart
/// render so the preview and the real widget stay in sync. autoDispose: the
/// preview is transient (only alive while the sheet is open).
final FutureProvider<WidgetSummary> widgetSummaryProvider =
    FutureProvider.autoDispose<WidgetSummary>((
      ref,
    ) async {
      final books = _requireOk(await ref.watch(bookRepoProvider).listMine());
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);
      final events = _requireOk(
        await ref
            .watch(eventRepoProvider)
            .list(
              from: today,
              to: today.add(kLocalWidgetEventWindow),
            ),
      );
      final progressByBookId = <String, Progress>{};
      for (final book in books) {
        if (book.status != BookStatus.reading) continue;
        final progress =
            (await ref.watch(progressRepoProvider).get(book.id)).value;
        if (progress != null) progressByBookId[book.id] = progress;
      }
      return buildLocalWidgetSummary(
        books: books,
        events: events,
        progressByBookId: progressByBookId,
        now: now,
      );
    });

/// The quotes snapshot the quotes widget renders, fetched for its in-app
/// preview (same endpoint the native widget self-fetches). autoDispose: only
/// alive while the preview sheet is open.
final FutureProvider<List<WidgetQuote>> widgetQuotesProvider =
    FutureProvider.autoDispose<List<WidgetQuote>>((
      ref,
    ) async {
      final books =
          (await ref.watch(bookRepoProvider).listMine()).value ??
          const <Book>[];
      final quotes =
          (await ref.watch(annotationRepoProvider).listMine()).value ??
          const <Annotation>[];
      final booksById = {for (final book in books) book.id: book};
      final resolved = <WidgetQuote>[];
      final sorted = [...quotes]
        ..sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        );
      for (final q in sorted) {
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
    });
final planRepoProvider = Provider<PlanRepository>(
  (ref) => _localProductRepo(ref, local: LocalPlanRepository.new),
);

final importServiceProvider = Provider<ImportService>((ref) {
  final users = ref.watch(userRepoProvider);
  return ImportService(
    store: ref.watch(localStoreProvider),
    prefs: ref.watch(prefsStorageProvider),
    fetchExport: () async {
      final result = await users.exportData();
      return result.fold(
        (raw) => jsonDecode(raw) as Map<String, dynamic>,
        (f) => throw FailureException(f),
      );
    },
    fetchCover: (url) async {
      final res = await publicHttpClient().get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (_) => true,
        ),
      );
      return CoverBytes(statusCode: res.statusCode ?? 0, bytes: res.data);
    },
    onPlaneFlipped: () {
      ref.read(dataPlaneTickProvider.notifier).state++;
      unawaited(() async {
        try {
          await ref.read(secureStorageProvider).clear();
          await clearWidgetData();
          await syncWidgetFromRef(ref, ref.read(sessionProvider).user);
        } on Object catch (e) {
          debugPrint('local plane flip cleanup failed: $e');
        }
      }());
    },
  );
});

final searchRepoProvider = Provider<SearchRepository>(
  (ref) => CatalogSearchRepository(),
);
final notificationRepoProvider = Provider<NotificationRepository>(
  (ref) => _localProductRepo(ref, local: LocalNotificationRepository.new),
);
final uploadRepoProvider = Provider<UploadRepository>(
  (ref) => LocalUploadRepository(ref.watch(localStoreProvider)),
);
final catalogImportProvider = Provider<CatalogImport>(
  (ref) => CatalogImport(
    search: ref.watch(searchRepoProvider),
    books: ref.watch(bookRepoProvider),
    annotations: ref.watch(annotationRepoProvider),
  ),
);
final annotationRepoProvider = Provider<AnnotationRepository>(
  (ref) => _localProductRepo(ref, local: LocalAnnotationRepository.new),
);
final quoteRepoProvider = annotationRepoProvider;
final readingChapterRepoProvider = Provider<ReadingChapterRepository>((ref) {
  final repository = LocalReadingChapterRepository(
    ref.watch(localStoreProvider),
    ref.watch(prefsStorageProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final StreamProviderFamily<ReadingChapterArchive, String>
readingChapterArchiveProvider = StreamProvider.autoDispose
    .family<ReadingChapterArchive, String>((ref, kind) async* {
      final repo = ref.watch(readingChapterRepoProvider);
      final cached = repo.cachedArchive(kind: kind);
      if (cached != null) yield cached;
      final result = await repo.fetchArchive(kind: kind);
      if (result.isErr) {
        if (cached == null) throw FailureException(result.failure!);
        return;
      }
      yield result.value!;
    });

final StreamProvider<ReadingChapterArchive> readingChapterLatestProvider =
    StreamProvider.autoDispose<ReadingChapterArchive>((ref) async* {
      final repo = ref.watch(readingChapterRepoProvider);
      final cached = repo.cachedLatest();
      if (cached != null) yield cached;
      final result = await repo.fetchLatest();
      if (result.isErr) {
        if (cached == null) throw FailureException(result.failure!);
        return;
      }
      yield result.value!;
    });

final StreamProviderFamily<ReadingChapterStory, ReadingChapterRequest>
readingChapterStoryProvider = StreamProvider.autoDispose
    .family<ReadingChapterStory, ReadingChapterRequest>((ref, request) async* {
      final repo = ref.watch(readingChapterRepoProvider);
      final cached = repo.cachedStory(request);
      if (cached != null) yield cached;
      final result = await repo.fetchStory(request);
      if (result.isErr) {
        if (cached == null) throw FailureException(result.failure!);
        return;
      }
      yield result.value!;
    });

final FutureProvider<bool> readingChapterNotificationPreferenceProvider =
    FutureProvider.autoDispose<bool>(
      (ref) async {
        _cacheWhileLoggedIn(ref);
        final result = await ref
            .watch(readingChapterRepoProvider)
            .notificationPreference();
        return result.fold(
          (value) => value,
          (failure) => throw FailureException(failure),
        );
      },
    );

/// Root navigator key, attached to the top-level `MaterialApp`. Lets flows
/// triggered from outside the widget tree (e.g. an "Open with Readendar" CSV
/// deep link) push a route without a BuildContext.
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);
// Debug-only leftover JWT mint for cloud-import QA until 15 October 2026.
final debugRepoProvider = Provider<DebugRepository?>((ref) {
  if (!kDebugMode) return null;
  return DebugRepository(ref.watch(apiClientProvider));
});
