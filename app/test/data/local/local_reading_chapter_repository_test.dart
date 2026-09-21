import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/local/local_reading_chapter_repository.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/data/local/reading_chapter_compute.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'local fetchStory computes opening and summary without the API',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = PrefsStorage(await SharedPreferences.getInstance());
      final dir = await Directory.systemTemp.createTemp('rd-chapter');
      addTearDown(() => dir.delete(recursive: true));
      final store = LocalStore.memory(
        Directory('${dir.path}/covers')..createSync(),
      );
      await store.put(LocalCollections.books, 'read-1', {
        'id': 'read-1',
        'ownerType': 'user',
        'ownerId': 'local-guest',
        'title': 'July read',
        'authors': ['Author'],
        'status': BookStatus.read,
        'coverUrl': 'https://covers.example/book.jpg',
        'isbn13': '9780306406157',
        'pageCount': 240,
        'categoryCodes': ['fiction'],
        'format': 'physical',
        'statusChangedAt': '2025-07-18T12:00:00Z',
      });
      await store.put(LocalCollections.bookStatusHistory, 'h1', {
        'id': 'h1',
        'bookId': 'read-1',
        'status': BookStatus.read,
        'changedAt': '2025-07-18T12:00:00Z',
        'dateConfirmed': true,
      });
      await store.put(LocalCollections.profile, 'me', {
        'id': 'me',
        'displayName': 'Reader',
        'timezone': 'UTC',
        'preferredLocale': 'es',
      });
      final repo = LocalReadingChapterRepository(
        store,
        prefs,
        now: () => DateTime.utc(2025, 8, 2),
      );

      final result = await repo.fetchStory(
        const ReadingChapterRequest(ReadingChapterKind.month, '2025-07'),
      );

      expect(result.isOk, isTrue);
      final story = result.value!;
      expect(story.meaningful, isTrue);
      expect(
        story.cards.map((card) => card.kind),
        containsAll([readingChapterCardCoverMosaic, readingChapterCardSummary]),
      );
    },
  );
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
