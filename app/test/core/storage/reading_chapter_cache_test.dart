import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'Reading Chapter cache is account scoped, bounded and clearable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PrefsStorage(await SharedPreferences.getInstance());

      for (var index = 0; index < 25; index++) {
        expect(
          await storage.setReadingChapterCache(
            'reader-a',
            'story:$index',
            'value-$index',
          ),
          isTrue,
        );
      }
      await storage.setReadingChapterCache(
        'reader-b',
        'story:private',
        'other-account',
      );

      expect(storage.getReadingChapterCache('reader-a', 'story:0'), isNull);
      expect(
        storage.getReadingChapterCache('reader-a', 'story:24'),
        'value-24',
      );
      expect(
        storage.getReadingChapterCache('reader-b', 'story:private'),
        'other-account',
      );

      await storage.clearReadingChapterCache('reader-a');

      expect(storage.getReadingChapterCache('reader-a', 'story:24'), isNull);
      expect(
        storage.getReadingChapterCache('reader-b', 'story:private'),
        'other-account',
      );
    },
  );

  test(
    'Reading Chapter cache rejects oversized entries and evicts by bytes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PrefsStorage(await SharedPreferences.getInstance());

      expect(
        await storage.setReadingChapterCache(
          'reader',
          'too-large',
          'x' * (385 * 1024),
        ),
        isFalse,
      );
      expect(storage.getReadingChapterCache('reader', 'too-large'), isNull);

      for (var index = 0; index < 4; index++) {
        expect(
          await storage.setReadingChapterCache(
            'reader',
            'story:$index',
            String.fromCharCode(65 + index) * (300 * 1024),
          ),
          isTrue,
        );
      }
      expect(storage.getReadingChapterCache('reader', 'story:0'), isNull);
      expect(storage.getReadingChapterCache('reader', 'story:3'), isNotNull);
    },
  );

  test('concurrent cache writes remain indexed and clearable', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PrefsStorage(await SharedPreferences.getInstance());

    await Future.wait([
      storage.setReadingChapterCache('reader', 'story:month', 'month'),
      storage.setReadingChapterCache('reader', 'archive:all', 'archive'),
    ]);

    expect(storage.getReadingChapterCache('reader', 'story:month'), 'month');
    expect(storage.getReadingChapterCache('reader', 'archive:all'), 'archive');

    await storage.clearReadingChapterCache('reader');

    expect(storage.getReadingChapterCache('reader', 'story:month'), isNull);
    expect(storage.getReadingChapterCache('reader', 'archive:all'), isNull);
  });
}
