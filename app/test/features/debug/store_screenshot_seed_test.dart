import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/features/debug/store_screenshot_seed.dart';

void main() {
  late Directory temp;
  late LocalStore store;
  final clock = DateTime.utc(2026, 9, 20, 15);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rd-shot-seed');
    store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test('seeds a compact local library for store screenshots', () async {
    await store.put(LocalCollections.books, 'old-book', {
      'id': 'old-book',
      'ownerType': 'user',
      'ownerId': 'local-guest',
      'title': 'Should vanish',
      'authors': const ['Nadie'],
      'status': BookStatus.pending,
    });

    final summary = await seedStoreScreenshotLibrary(store, now: clock);

    expect(await store.get(LocalCollections.books, 'old-book'), isNull);
    expect(summary.books, 6);
    expect(summary.events, 4);
    expect(summary.annotations, 4);

    final books = [
      for (final row in await store.list(LocalCollections.books))
        Book.fromJson(row),
    ];
    expect(
      books.map((b) => b.status).toSet(),
      containsAll(<String>[
        BookStatus.reading,
        BookStatus.pending,
        BookStatus.wanted,
        BookStatus.read,
      ]),
    );
    expect(
      books.any(
        (b) =>
            b.id == storeScreenshotQuoteBookId &&
            b.title.contains('Cien años') &&
            b.isbn13.isNotEmpty &&
            b.coverUrl.contains(b.isbn13),
      ),
      isTrue,
    );

    final events = await store.list(LocalCollections.events);
    expect(
      events.map((row) => row['type']).toSet(),
      containsAll(<String>[
        EventType.pageMilestone.backendValue,
        EventType.chapterMilestone.backendValue,
        EventType.bookReturn.backendValue,
        EventType.finish.backendValue,
      ]),
    );

    final annotations = await store.list(LocalCollections.annotations);
    expect(
      annotations.every((row) => row['bookId'] == storeScreenshotQuoteBookId),
      isTrue,
    );
  });
}
