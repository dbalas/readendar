import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/reading_chapter_repository.dart';
import 'package:readendar/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/api_repo_stubs.dart';

void main() {
  test(
    'Reading Chapter providers load for a non-premium account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsStorage(await SharedPreferences.getInstance());
      final archive = ReadingChapterArchive(
        items: const [],
        nextCursor: '',
        hasUnread: false,
        capabilities: const ReadingChapterCapabilities(
          privateGeneration: true,
        ),
      );
      final repository = _Repo(prefs, archive);
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith((ref) => _Session(ref, _user())),
          prefsStorageProvider.overrideWithValue(prefs),
          readingChapterRepoProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final latest = Completer<ReadingChapterArchive>();
      final archiveDone = Completer<ReadingChapterArchive>();
      final preference = Completer<bool>();
      final latestSub = container.listen(
        readingChapterLatestProvider,
        (_, next) {
          if (next.hasValue && !latest.isCompleted) {
            latest.complete(next.requireValue);
          }
        },
      );
      final archiveSub = container.listen(
        readingChapterArchiveProvider('all'),
        (_, next) {
          if (next.hasValue && !archiveDone.isCompleted) {
            archiveDone.complete(next.requireValue);
          }
        },
      );
      final preferenceSub = container.listen(
        readingChapterNotificationPreferenceProvider,
        (_, next) {
          if (next.hasValue && !preference.isCompleted) {
            preference.complete(next.requireValue);
          }
        },
      );
      addTearDown(latestSub.close);
      addTearDown(archiveSub.close);
      addTearDown(preferenceSub.close);

      expect(await latest.future, same(archive));
      expect(await archiveDone.future, same(archive));
      expect(await preference.future, isTrue);
    },
  );
}

class _Session extends SessionNotifier {
  _Session(super.ref, AppUser user) {
    state = SessionState(user: user);
  }
}

class _Repo extends ApiReadingChapterRepository {
  _Repo(PrefsStorage prefs, this.archive)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _TokenStorage(),
          localeProvider: () => 'en',
        ),
        prefs,
        '00000000-0000-4000-8000-000000000001',
      );

  final ReadingChapterArchive archive;

  @override
  Future<Result<ReadingChapterArchive>> fetchLatest() async => Ok(archive);

  @override
  Future<Result<ReadingChapterArchive>> fetchArchive({
    String kind = 'all',
    String? after,
    int limit = 20,
  }) async => Ok(archive);

  @override
  Future<Result<bool>> notificationPreference() async => const Ok(true);
}

class _TokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}

AppUser _user() => AppUser(
  id: '00000000-0000-4000-8000-000000000001',
  email: 'reader@example.com',
  displayName: 'Reader',
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: null,
);
