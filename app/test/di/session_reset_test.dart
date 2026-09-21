import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import '../helpers/api_repo_stubs.dart';

/// Regression for the account-switch bug. The per-user list providers
/// (`booksProvider`, …) are `autoDispose` + `_cacheWhileLoggedIn`:
///
///  • While logged in, a `keepAlive` link keeps them warm so re-entering a view
///    shows cached data instantly (stale-while-revalidate).
///  • On logout (session user → null) the link is closed; once every data
///    screen has unmounted the provider tears down for real, so the next
///    account re-fetches from scratch — never an empty page from a stale empty
///    cache, never a flash of the previous account's data.
void main() {
  test(
    'cache survives in-session navigation but is dropped on logout',
    () async {
      final repo = _SwitchableBookRepository();
      final container = ProviderContainer(
        overrides: [
          bookRepoProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(_TestSession.new),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(sessionProvider.notifier) as _TestSession;

      // Log into the secondary account (no books) and open a screen.
      session.setUser(_user('user-secondary'));
      repo.books = const <Book>[];
      final screenA = container.listen(booksProvider, (_, _) {});
      expect(await container.read(booksProvider.future), isEmpty);
      expect(repo.listMineCount, 1);

      // Navigate away (screen unmounts). keepAlive holds the cache: re-reading
      // does NOT trigger a refetch.
      screenA.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(booksProvider).value, isEmpty);
      expect(repo.listMineCount, 1, reason: 'in-session cache must be reused');

      // Logout: the keepAlive link is closed and, with no screen listening, the
      // provider is torn down.
      session.forceLogout();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Log into the main account, which has data. A new screen mounts.
      session.setUser(_user('user-main'));
      repo.books = [_book('book-main', 'Pedro Paramo')];
      final screenB = container.listen(booksProvider, (_, _) {});
      addTearDown(screenB.close);

      // It must NOT surface the previous account's empty cache as a settled
      // value — it loads from scratch.
      final mid = container.read(booksProvider);
      expect(mid.isLoading, isTrue);
      expect(
        mid.value,
        isNull,
        reason: "must not flash the previous account's data",
      );

      final loaded = await container.read(booksProvider.future);
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'book-main');
      expect(repo.listMineCount, 2);
    },
  );
}

/// Test session notifier that can drive setUser/logout without the
/// production side effects (storage, local notifications).
class _TestSession extends SessionNotifier {
  _TestSession(super.ref);

  void forceLogout() => state = const SessionState();
}

Book _book(String id, String title) => Book(
  id: id,
  ownerType: 'user',
  ownerId: 'user-main',
  title: title,
  authors: const [],
  status: BookStatus.reading,
);

AppUser _user(String id) => AppUser(
  id: id,
  email: '$id@example.com',
  displayName: id,
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: null,
);

ApiClient _fakeClient() => ApiClient(
  baseUrl: 'http://localhost',
  storage: _NoopSecureStorage(),
  localeProvider: () => 'es',
);

class _SwitchableBookRepository extends ApiBookRepository {
  _SwitchableBookRepository() : super(_fakeClient());

  List<Book> books = const <Book>[];
  int listMineCount = 0;

  @override
  Future<Result<List<Book>>> listMine() async {
    listMineCount += 1;
    return Ok(books);
  }
}

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
