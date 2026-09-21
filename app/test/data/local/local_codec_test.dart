import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/data/local/legacy_server_export.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/data/local/local_store.dart';

void main() {
  test('archiveValue reads backup collection names', () {
    final archive = {
      'page_activity': [
        {'id': 'a1'},
      ],
      'reading_chapter_periods': [
        {'kind': 'month', 'key': '2026-01'},
      ],
    };
    expect(
      archiveValue(archive, LocalCollections.pageActivity),
      isA<List>(),
    );
    expect(
      archiveValue(archive, LocalCollections.readingChapters),
      isA<List>(),
    );
  });

  test('linkedSourceToPersonalIds maps legacy linked ids before personalize', () {
    final map = linkedSourceToPersonalIds([
      {'id': 'personal-1', LegacyServerExport.linkedBookIdKey: 'source-1'},
      {'id': 'personal-2'},
    ]);
    expect(map, {'source-1': 'personal-1'});
  });

  test('widgetSafeCoverUrl prefers the original HTTPS url', () {
    expect(
      widgetSafeCoverUrl({
        'coverUrl': '/tmp/covers/a.jpg',
        'sourceCoverUrl': 'https://covers.openlibrary.org/a-L.jpg',
      }),
      'https://covers.openlibrary.org/a-L.jpg',
    );
    expect(
      widgetSafeCoverUrl({'coverUrl': '/tmp/covers/a.jpg'}),
      '/tmp/covers/a.jpg',
    );
  });

  test('applyNoteChrome copies privateNotes and annotation counts', () {
    final books = <Map<String, dynamic>>[
      {'id': 'b1', 'privateNotes': 'margen'},
      {'id': 'b2'},
    ];
    applyNoteChrome(books, [
      {'bookId': 'b1'},
      {'bookId': 'b1'},
      {'bookId': 'b2'},
    ]);
    expect(books[0]['notes'], 'margen');
    expect(books[0]['annotationCount'], 2);
    expect(books[1]['annotationCount'], 1);
  });
}
