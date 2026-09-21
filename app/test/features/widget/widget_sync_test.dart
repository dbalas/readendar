// Covers syncWidget's local snapshot path: no session → no-op; leftover
// tokens are cleared; the native cache is written from on-device SQLite.
// The actual platform calls (home_widget's MethodChannel) are mocked so these
// run as plain unit tests, no device/emulator needed.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:readendar/features/widget/widget_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../quotes/quotes_test_utils.dart';
import '../../helpers/api_repo_stubs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final store = <String, Object?>{};
  var savedCalls = 0;
  var failSave = false;

  Future<Object?> handler(MethodCall call) async {
    switch (call.method) {
      case 'setAppGroupId':
        return true;
      case 'getWidgetData':
        final id = (call.arguments as Map)['id'] as String;
        return store[id];
      case 'saveWidgetData':
        if (failSave) {
          throw PlatformException(code: 'write_failed');
        }
        savedCalls++;
        final args = call.arguments as Map;
        store[args['id'] as String] = args['data'];
        return true;
      case 'updateWidget':
        return true;
      default:
        return null;
    }
  }

  setUp(() {
    store.clear();
    savedCalls = 0;
    failSave = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // syncWidgetFromRef needs a plain `Ref` (not a `WidgetRef` and not a
  // `ProviderContainer`, neither of which implements `Ref`). A trivial
  // Provider's builder receives a real `Ref`, so we route the call through one
  // instead of constructing a `Ref` by hand.
  final syncCallProvider = Provider<Future<bool> Function()>(
    (ref) =>
        () => syncWidgetFromRef(
          ref,
          ref.read(sessionProvider).user,
        ),
  );

  final syncQuotesCallProvider = Provider<Future<void> Function()>(
    (ref) =>
        () => syncQuotesWidgetFromRef(ref),
  );

  Future<ProviderContainer> buildContainer({
    AppUser? user,
    List<Override> extraOverrides = const [],
    Map<String, Object> preferences = const {},
  }) async {
    SharedPreferences.setMockInitialValues(preferences);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sessionProvider.overrideWith(_TestSession.new),
        ...extraOverrides,
      ],
    );
    if (user != null) {
      // Set the session state directly (not via `setUser`) — `setUser` itself
      // fires a session `syncWidgetFromRef` (see providers.dart), which
      // would race with the explicit calls these tests make below and isn't
      // what's under test here (that hook has its own coverage).
      (container.read(sessionProvider.notifier) as _TestSession).forceState(
        user,
      );
    }
    return container;
  }

  LocalStore _memoryStore() {
    final dir = Directory.systemTemp.createTempSync('wdg-sync');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    return LocalStore.memory(Directory('${dir.path}/covers')..createSync());
  }

  test('no signed-in user → no-op, returns false', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    final ok = await container.read(syncCallProvider)();

    expect(ok, isFalse);
    expect(savedCalls, 0);
  });

  test(
    'session sync uses caller-resolved theme without a cycle',
    () async {
      SharedPreferences.setMockInitialValues({'theme_preset': 'ethereal'});
      final prefs = await SharedPreferences.getInstance();
      store
        ..[kWidgetKeyAccess] = 'stored-access'
        ..[kWidgetKeyRefresh] = 'stored-refresh'
        ..[kWidgetKeyUserId] = 'user-ethereal';
      final local = _memoryStore();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localStoreProvider.overrideWithValue(local),
          sessionProvider.overrideWith(
            (ref) =>
                SessionNotifier(ref)..setUser(_user('user-ethereal')),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(sessionProvider).user?.id, 'user-ethereal');
      await Future<void>.delayed(Duration.zero);

      expect(store[kWidgetKeyAppTheme], 'ethereal');
    },
  );

  test('local sync writes empty credentials and a library snapshot', () async {
    final user = _user('user-1');
    final local = _memoryStore();
    final container = await buildContainer(
      user: user,
      extraOverrides: [localStoreProvider.overrideWithValue(local)],
    );
    addTearDown(container.dispose);

    store[kWidgetKeyAccess] = 'stored-access';
    store[kWidgetKeyRefresh] = 'stored-refresh';
    store[kWidgetKeyUserId] = user.id;

    final ok = await container.read(syncCallProvider)();

    expect(ok, isTrue);
    expect(store[kWidgetKeyAccess], '');
    expect(store[kWidgetKeyRefresh], '');
    expect(store[kWidgetKeyAppTheme], 'original');
    expect(store[kWidgetKeyCachedSummary], contains('"readingBooks":[]'));
  });

  test(
    'iOS Keychain tokens are reused instead of re-minting',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('readendar/widget_secrets'),
            (call) async {
              switch (call.method) {
                case 'read':
                  return {
                    'access': 'kc-access',
                    'refresh': 'kc-refresh',
                  };
                case 'write':
                  return true;
                case 'clear':
                  return true;
                case 'clearShared':
                  return true;
                case 'flushDefaults':
                  return true;
                default:
                  return null;
              }
            },
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('readendar/widget_secrets'),
              null,
            );
      });

      final user = _user('user-1');
      final local = _memoryStore();
      final container = await buildContainer(
        user: user,
        extraOverrides: [localStoreProvider.overrideWithValue(local)],
      );
      addTearDown(container.dispose);

      store[kWidgetKeyUserId] = user.id;

      final ok = await container.read(syncCallProvider)();

      expect(ok, isTrue);
    },
  );

  test(
    'stored leftover tokens are cleared on local sync',
    () async {
      final user = _user('user-2');
      final local = _memoryStore();
      final container = await buildContainer(
        user: user,
        extraOverrides: [localStoreProvider.overrideWithValue(local)],
      );
      addTearDown(container.dispose);

      store[kWidgetKeyAccess] = 'stale-access';
      store[kWidgetKeyRefresh] = 'stale-refresh';
      store[kWidgetKeyUserId] = 'some-other-user';
      store[kWidgetKeyCachedSummary] = 'previous-account-snapshot';

      final ok = await container.read(syncCallProvider)();

      expect(ok, isTrue);
      expect(store[kWidgetKeyAccess], '');
      expect(store[kWidgetKeyRefresh], '');
      expect(store[kWidgetKeyUserId], user.id);
      expect(store[kWidgetKeyCachedSummary], contains('"readingBooks":[]'));
    },
  );

  test(
    'widget theme writes the selected preset (themes are ungated)',
    () async {
      final user = _user('standard-user');
      final local = _memoryStore();
      final container = await buildContainer(
        user: user,
        extraOverrides: [localStoreProvider.overrideWithValue(local)],
        preferences: {'theme_preset': 'ethereal'},
      );
      addTearDown(container.dispose);

      final ok = await container.read(syncCallProvider)();

      expect(ok, isTrue);
      expect(store[kWidgetKeyAppTheme], 'ethereal');
    },
  );

  test('missing local store skips widget sync', () async {
    final user = _user('user-3');
    final container = await buildContainer(user: user);
    addTearDown(container.dispose);

    final ok = await container.read(syncCallProvider)();

    expect(ok, isFalse);
    expect(savedCalls, 0);
  });

  test('shared-storage write failure returns false', () async {
    final user = _user('user-4');
    final local = _memoryStore();
    final container = await buildContainer(
      user: user,
      extraOverrides: [localStoreProvider.overrideWithValue(local)],
    );
    addTearDown(container.dispose);
    failSave = true;

    final ok = await container.read(syncCallProvider)();

    expect(ok, isFalse);
  });

  test('sync writes the live summary snapshot before reloading', () async {
    final user = _user('user-1');
    final local = _memoryStore();
    await local.put(LocalCollections.books, 'b-now', {
      'id': 'b-now',
      'ownerType': 'user',
      'ownerId': user.id,
      'title': 'Dune',
      'authors': ['Herbert'],
      'status': BookStatus.reading,
      'coverUrl': 'c',
    });
    final container = await buildContainer(
      user: user,
      extraOverrides: [localStoreProvider.overrideWithValue(local)],
    );
    addTearDown(container.dispose);

    store[kWidgetKeyCachedSummary] = '{"readingBooks":[{"id":"old"}]}';

    final ok = await container.read(syncCallProvider)();

    expect(ok, isTrue);
    expect(
      store[kWidgetKeyCachedSummary],
      contains('"id":"b-now"'),
      reason: 'app-pushed summary must replace a stale finished-book cache',
    );
    expect(store[kWidgetKeyCachedSummary], isNot(contains('old')));
  });

  test('local sync rewrites leftover tokens and cache', () async {
    final user = _user('user-1');
    final local = _memoryStore();
    final container = await buildContainer(
      user: user,
      extraOverrides: [localStoreProvider.overrideWithValue(local)],
    );
    addTearDown(container.dispose);

    store[kWidgetKeyAccess] = 'stored-access';
    store[kWidgetKeyRefresh] = 'stored-refresh';
    store[kWidgetKeyUserId] = user.id;
    store[kWidgetKeyCachedSummary] = 'keep-me';

    final ok = await container.read(syncCallProvider)();

    expect(ok, isTrue);
    expect(store[kWidgetKeyAccess], '');
    expect(store[kWidgetKeyCachedSummary], contains('"readingBooks":[]'));
  });

  test('pruneFinishedReadingBooks drops finished rows only', () {
    const cached = WidgetSummary(
      readingBooks: [
        WidgetBook(id: 'done', title: 'Old', author: 'A', coverUrl: ''),
        WidgetBook(id: 'keep', title: 'New', author: 'B', coverUrl: ''),
        WidgetBook(id: 'ghost', title: 'Unknown', author: 'C', coverUrl: ''),
      ],
      events: [],
    );
    final pruned = pruneFinishedReadingBooks(cached, {
      'done': testBook(id: 'done', status: BookStatus.read),
      'keep': testBook(id: 'keep'),
    });
    expect(pruned.readingBooks.map((b) => b.id), ['keep', 'ghost']);
    expect(
      identical(pruneFinishedReadingBooks(cached, const {}), cached),
      isTrue,
      reason: 'empty library must not wipe a good cache',
    );
  });

  test(
    'local sync omits finished books from the widget snapshot',
    () async {
      final user = _user('user-1');
      final local = _memoryStore();
      await local.put(LocalCollections.books, 'keep', {
        'id': 'keep',
        'ownerType': 'user',
        'ownerId': user.id,
        'title': 'New',
        'authors': ['B'],
        'status': BookStatus.reading,
        'coverUrl': '',
      });
      await local.put(LocalCollections.books, 'done', {
        'id': 'done',
        'ownerType': 'user',
        'ownerId': user.id,
        'title': 'Old',
        'authors': ['A'],
        'status': BookStatus.read,
        'coverUrl': '',
      });
      final container = await buildContainer(
        user: user,
        extraOverrides: [localStoreProvider.overrideWithValue(local)],
      );
      addTearDown(container.dispose);

      final ok = await container.read(syncCallProvider)();

      expect(ok, isTrue);
      expect(store[kWidgetKeyCachedSummary], contains('"id":"keep"'));
      expect(store[kWidgetKeyCachedSummary], isNot(contains('"id":"done"')));
    },
  );

  test(
    'cold widget refresh does not load the in-app quotes collection',
    () async {
      final repo = _CountingQuoteRepository();
      final container = await buildContainer(
        extraOverrides: [quoteRepoProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(syncQuotesCallProvider)();

      expect(repo.listMineCalls, 0);
      expect(container.exists(quotesControllerProvider), isFalse);
    },
  );

  test('resolveWidgetQuotes copies favorite independently of pin', () {
    final fav = testQuote(
      id: 'q-fav',
      text: 'starred',
      favorite: true,
      pinned: false,
    );
    final pinOnly = testQuote(
      id: 'q-pin',
      text: 'pinned',
      favorite: false,
      pinned: true,
    );
    final book = testBook();
    final quotesState = AsyncValue<List<Quote>>.data([fav, pinOnly]);
    final books = {book.id: book};

    T reader<T>(ProviderListenable<T> provider) {
      if (provider == quotesControllerProvider) return quotesState as T;
      if (provider == booksByIdProvider) return books as T;
      throw StateError('unexpected provider $provider');
    }

    final resolved = resolveWidgetQuotes(reader)!;
    expect(resolved.map((q) => q.id), ['q-fav', 'q-pin']);
    expect(resolved.first.favorite, isTrue);
    expect(resolved.last.favorite, isFalse);
  });

  test('resolveWidgetQuotes drops non-quote categories', () {
    final quote = testQuote(id: 'q1', text: 'cita');
    final note = testQuote(
      id: 'n1',
      text: 'nota',
      category: AnnotationCategory.note,
    );
    final book = testBook();
    final quotesState = AsyncValue<List<Quote>>.data([note, quote]);
    final books = {book.id: book};

    T reader<T>(ProviderListenable<T> provider) {
      if (provider == quotesControllerProvider) return quotesState as T;
      if (provider == booksByIdProvider) return books as T;
      throw StateError('unexpected provider $provider');
    }

    final resolved = resolveWidgetQuotes(reader)!;
    expect(resolved.map((q) => q.id), ['q1']);
  });

  test(
    'quote create + quotesMutationTick sync does not self-depend',
    () async {
      // Regression: wiring syncQuotesWidget with QuotesController's own Ref
      // made syncQuotesWidgetFromRef call exists(quotesControllerProvider)
      // and assert "A provider cannot depend on itself", leaving the
      // composer save button stuck on loading.
      final quoteRepo = _CountingQuoteRepository();
      final container = await buildContainer(
        user: _user('user-q'),
        extraOverrides: [quoteRepoProvider.overrideWithValue(quoteRepo)],
      );
      addTearDown(container.dispose);

      final tickSub = container.listen<int>(quotesMutationTickProvider, (
        previous,
        next,
      ) {
        if (previous == next) return;
        // Mirror Gate: sync via a Ref that is NOT QuotesController's.
        unawaited(container.read(syncQuotesCallProvider)());
      });
      addTearDown(tickSub.close);

      final sub = container.listen(quotesControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(quotesControllerProvider.notifier);

      // Wait for the controller's initial listMine to settle.
      await Future<void>.delayed(Duration.zero);
      expect(quoteRepo.listMineCalls, 1);
      expect(container.read(quotesControllerProvider).hasValue, isTrue);

      final result = await controller.create(
        bookId: 'book-1',
        text: 'a quote',
      );

      expect(result, isA<Ok<Quote>>());
      expect(
        container.read(quotesControllerProvider).value,
        hasLength(1),
        reason: 'mutation must complete even when widget sync runs',
      );
    },
  );

  test(
    'local data plane writes a snapshot without minting a widget JWT',
    () async {
      final user = _user('user-1');
      final covers = await Directory.systemTemp.createTemp('wdg-local');
      addTearDown(() => covers.delete(recursive: true));
      final local = LocalStore.memory(covers);
      await local.put(LocalCollections.books, 'read-1', {
        'id': 'read-1',
        'ownerType': 'user',
        'ownerId': user.id,
        'title': 'Rayuela',
        'authors': ['Cortazar'],
        'status': BookStatus.reading,
        'coverUrl': '',
      });
      await local.put(LocalCollections.events, 'ev-1', {
        'id': 'ev-1',
        'ownerType': 'user',
        'ownerId': user.id,
        'type': 'start',
        'title': 'Inicio',
        'dateLocal': DateTime.now()
            .toUtc()
            .add(const Duration(days: 1))
            .toIso8601String(),
        'status': EventStatus.active,
        'bookId': 'read-1',
      });
      await local.put(LocalCollections.progress, 'read-1', {
        'bookEntryId': 'read-1',
        'currentPage': 40,
        'currentPercentage': 10,
        'updatedAt': DateTime.utc(2026, 9, 19).toIso8601String(),
      });
      await local.put(LocalCollections.annotations, 'q-1', {
        'id': 'q-1',
        'bookId': 'read-1',
        'category': AnnotationCategory.quote.wire,
        'body': 'El cronopio lee.',
        'createdAt': DateTime.utc(2026, 9, 19).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 9, 19).toIso8601String(),
      });
      final container = await buildContainer(
        user: user,
        extraOverrides: [
          localStoreProvider.overrideWithValue(local),
        ],
        preferences: {'data_plane:v1': 'local'},
      );
      addTearDown(container.dispose);

      final ok = await container.read(syncCallProvider)();

      expect(ok, isTrue);
      expect(store[kWidgetKeyAccess], '');
      expect(store[kWidgetKeyRefresh], '');
      expect(store[kWidgetKeyCachedSummary], contains('"id":"read-1"'));
      expect(store[kWidgetKeyCachedSummary], contains('"id":"ev-1"'));
      expect(store[kWidgetKeyQuotesCache], contains('El cronopio lee.'));
      expect(store[kWidgetKeyQuotesCache], contains('"id":"q-1"'));
    },
  );
}

class _TestSession extends SessionNotifier {
  _TestSession(super.ref);
  void forceState(AppUser user) => state = SessionState(user: user);
}

class _CountingQuoteRepository extends ApiAnnotationRepository {
  _CountingQuoteRepository() : super(_fakeClient());

  int listMineCalls = 0;
  int createCalls = 0;

  @override
  Future<Result<List<Quote>>> listMine() async {
    listMineCalls++;
    return const Ok(<Quote>[]);
  }

  @override
  Future<Result<Quote>> create({
    required String bookId,
    required String body,
    AnnotationCategory category = AnnotationCategory.quote,
    int? page,
    int? chapter,
    bool pinned = false,
    String commentary = '',
    bool spoiler = false,
    String? text,
    bool favorite = false,
    String note = '',
  }) async {
    createCalls++;
    return Ok(
      Quote(
        id: 'q-$createCalls',
        bookId: bookId,
        body: body.isNotEmpty ? body : (text ?? ''),
        category: category,
        page: page,
        chapter: chapter,
        pinned: pinned,
        favorite: favorite,
        commentary: commentary.isNotEmpty ? commentary : note,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
  }
}

ApiClient _fakeClient() => ApiClient(
  baseUrl: 'http://localhost',
  storage: _NoopSecureStorage(),
  localeProvider: () => 'es',
);

class _NoopSecureStorage extends SecureTokenStorage {
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

AppUser _user(String id) => AppUser(
  id: id,
  email: '$id@example.com',
  displayName: id,
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: null,
);
