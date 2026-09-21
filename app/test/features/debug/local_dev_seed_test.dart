import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/features/debug/local_dev_seed.dart';

void main() {
  late Directory temp;
  late LocalStore store;
  final clock = DateTime.utc(2026, 9, 19, 15);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rd-dev-seed');
    store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  test(
    'wipes existing rows then seeds every status, progress kind, and event type',
    () async {
      await store.put(LocalCollections.books, 'old-book', {
        'id': 'old-book',
        'ownerType': 'user',
        'ownerId': 'local-guest',
        'title': 'Should vanish',
        'authors': const ['Nadie'],
        'status': BookStatus.pending,
      });
      final cover = await store.coverFile('old-book');
      await cover.writeAsBytes(const [1, 2, 3]);

      final summary = await seedLocalDevLibrary(store, now: clock);

      expect(await store.get(LocalCollections.books, 'old-book'), isNull);
      expect(cover.existsSync(), isFalse);

      final books = await store.list(LocalCollections.books);
      expect(summary.books, books.length);
      expect(summary.books, greaterThanOrEqualTo(200));
      expect(
        books.map((row) => row['status']).toSet(),
        BookStatus.all.toSet(),
      );
      expect(
        books.map((row) => (row['rating'] as num?)?.toDouble()).toSet(),
        containsAll(<double?>[null, 0.5, 3, 4.5, 5]),
      );

      final progress = [
        for (final row in await store.list(LocalCollections.progress))
          Progress.fromJson(row),
      ];
      expect(summary.progress, progress.length);
      expect(
        progress.any((p) => p.currentPage != null && p.currentChapter == null),
        isTrue,
      );
      expect(
        progress.any((p) => p.currentChapter != null && p.currentPage == null),
        isTrue,
      );
      expect(
        progress.any(
          (p) => p.currentPercentage != null && p.currentPage == null,
        ),
        isTrue,
      );
      expect(
        progress.any(
          (p) =>
              p.currentPage != null &&
              p.currentChapter != null &&
              p.currentPercentage != null,
        ),
        isTrue,
      );

      final events = [
        for (final row in await store.list(LocalCollections.events))
          ReadingEvent.fromJson(row),
      ];
      expect(summary.events, events.length);
      expect(summary.events, greaterThanOrEqualTo(1000));
      expect(
        events.map((e) => e.type).toSet(),
        EventType.values.map((t) => t.backendValue).toSet(),
      );
      final year = clock.year;
      final bulkYearCounts = events
          .where((e) => e.id.startsWith('seed-ev-bulk-'))
          .map((e) => e.dateLocal.year)
          .toSet();
      expect(bulkYearCounts, {year});
      expect(
        events.map((e) => e.status).toSet(),
        containsAll({
          EventStatus.active,
          EventStatus.completed,
          EventStatus.cancelled,
        }),
      );

      final annotations = [
        for (final row in await store.list(LocalCollections.annotations))
          Annotation.fromJson(row),
      ];
      expect(summary.annotations, annotations.length);
      expect(
        annotations.map((a) => a.category).toSet(),
        AnnotationCategory.values.toSet(),
      );
      expect(annotations.any((a) => a.pinned && a.favorite), isTrue);
      expect(annotations.any((a) => a.spoiler), isTrue);

      expect(await store.list(LocalCollections.pageActivity), isNotEmpty);
      expect(await store.list(LocalCollections.bookStatusHistory), isNotEmpty);
      expect(await store.list(LocalCollections.planRuns), isNotEmpty);
      expect(
        await store.list(LocalCollections.customFieldDefinitions),
        isNotEmpty,
      );
      expect(await store.list(LocalCollections.customFieldValues), isNotEmpty);
    },
  );
}
