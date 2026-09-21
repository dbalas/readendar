import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/data/local/reading_chapter_compute.dart';

void main() {
  setUpAll(initializeAppTimeZones);

  test('empty period with shelf-only changes is not meaningful', () {
    final period = buildReadingChapterPeriod(
      kind: ReadingChapterKind.month,
      key: '2025-07',
      timezone: 'UTC',
      now: DateTime.utc(2025, 8, 2),
    );
    final book = _chapterBook(
      id: 'pending-1',
      title: 'Future read',
      status: BookStatus.pending,
      pages: null,
      categories: const [],
      format: '',
      coverUrl: '',
    );
    final story = computeReadingChapter(
      ReadingChapterSourceData(
        reader: _reader,
        revision: 1,
        books: [book],
        history: [
          ReadingChapterHistoryRow(
            bookEntryId: book.entryId,
            status: BookStatus.pending,
            changedAt: DateTime.utc(2025, 7, 10, 12),
            dateConfirmed: true,
          ),
        ],
      ),
      period,
    );

    expect(story.meaningful, isFalse);
    expect(story.cards, isEmpty);
  });

  test(
    'one completed book in a month emits opening then summary',
    () {
      final period = buildReadingChapterPeriod(
        kind: ReadingChapterKind.month,
        key: '2025-07',
        timezone: 'UTC',
        now: DateTime.utc(2025, 8, 2),
      );
      final book = _chapterBook(
        id: 'read-1',
        title: 'July read',
        status: BookStatus.read,
        pages: 240,
      );
      final story = computeReadingChapter(
        ReadingChapterSourceData(
          reader: _reader,
          revision: 2,
          books: [book],
          history: [
            ReadingChapterHistoryRow(
              bookEntryId: book.entryId,
              status: BookStatus.read,
              changedAt: DateTime.utc(2025, 7, 18, 12),
              dateConfirmed: true,
            ),
          ],
        ),
        period,
      );

      expect(story.meaningful, isTrue);
      expect(
        story.cards.map((card) => card.id),
        containsAll(['opening', 'summary']),
      );
      expect(story.cards.first.id, 'opening');
      expect(story.cards.first.kind, readingChapterCardCoverMosaic);
      expect(story.cards.last.id, 'summary');
      expect(story.cards.last.kind, readingChapterCardSummary);
      expect(
        story.cards.any((card) => card.kind == readingChapterCardJourney),
        isFalse,
      );
      expect(story.cards.last.totals?.uniqueWorks, 1);
      expect(story.cards.last.totals?.readingOccurrences, 1);
    },
  );

  test(
    'year with started, abandoned, and ongoing emits a journey card',
    () {
      final period = buildReadingChapterPeriod(
        kind: ReadingChapterKind.year,
        key: '2025',
        timezone: 'UTC',
        now: DateTime.utc(2026, 1, 2),
      );
      final started = _chapterBook(
        id: 'started-1',
        title: 'Long read',
        status: BookStatus.reading,
        pages: 400,
      );
      final abandoned = _chapterBook(
        id: 'abandoned-1',
        title: 'Put down',
        status: BookStatus.abandoned,
        pages: 180,
      );
      final story = computeReadingChapter(
        ReadingChapterSourceData(
          reader: _reader,
          revision: 3,
          books: [started, abandoned],
          history: [
            ReadingChapterHistoryRow(
              bookEntryId: started.entryId,
              status: BookStatus.reading,
              changedAt: DateTime.utc(2025, 2, 4),
              dateConfirmed: true,
            ),
            ReadingChapterHistoryRow(
              bookEntryId: abandoned.entryId,
              status: BookStatus.abandoned,
              changedAt: DateTime.utc(2025, 8, 4),
              dateConfirmed: true,
            ),
          ],
        ),
        period,
      );

      expect(story.meaningful, isTrue);
      final journey = story.cards.where(
        (card) => card.kind == readingChapterCardJourney,
      );
      expect(journey, hasLength(1));
      expect(journey.single.id, 'journey');
      expect(journey.single.journey?.started, 1);
      expect(journey.single.journey?.abandoned, 1);
      expect(journey.single.journey?.ongoing, 1);
      expect(
        story.cards.map((card) => card.kind),
        containsAllInOrder([
          readingChapterCardCoverMosaic,
          readingChapterCardJourney,
          readingChapterCardSummary,
        ]),
      );
    },
  );

  test('month uses exact civil bounds across Madrid DST', () {
    final period = buildReadingChapterPeriod(
      kind: ReadingChapterKind.month,
      key: '2026-03',
      timezone: 'Europe/Madrid',
      now: DateTime.utc(2026, 5, 1),
    );
    expect(period.startsAt, DateTime.utc(2026, 2, 28, 23));
    expect(period.endsAt, DateTime.utc(2026, 3, 31, 22));
    expect(
      () => buildReadingChapterPeriod(
        kind: ReadingChapterKind.month,
        key: '2026-08',
        timezone: 'Europe/Madrid',
        now: DateTime.utc(2026, 8, 13),
      ),
      throwsA(
        isA<ReadingChapterPeriodException>().having(
          (error) => error.code,
          'code',
          'reading_chapter_period_not_closed',
        ),
      ),
    );
  });

  test('canonical ISBN aliases group as one work', () {
    final period = buildReadingChapterPeriod(
      kind: ReadingChapterKind.year,
      key: '2025',
      timezone: 'UTC',
      now: DateTime.utc(2026, 1, 2),
    );
    final first = _chapterBook(
      id: 'a',
      title: 'Same Work',
      author: 'Writer',
      isbn: '0306406152',
      status: BookStatus.read,
      pages: 100,
    );
    final second = _chapterBook(
      id: 'b',
      title: 'Same Work',
      author: 'Writer',
      isbn: '9780306406157',
      status: BookStatus.read,
      pages: 140,
    );
    final story = computeReadingChapter(
      ReadingChapterSourceData(
        reader: _reader,
        revision: 1,
        books: [first, second],
        history: [
          ReadingChapterHistoryRow(
            bookEntryId: first.entryId,
            status: BookStatus.read,
            changedAt: DateTime.utc(2025, 1, 1, 12),
            dateConfirmed: true,
          ),
          ReadingChapterHistoryRow(
            bookEntryId: second.entryId,
            status: BookStatus.read,
            changedAt: DateTime.utc(2025, 2, 1, 12),
            dateConfirmed: true,
          ),
        ],
      ),
      period,
    );
    final totals = story.cards
        .firstWhere((card) => card.kind == readingChapterCardSummary)
        .totals;
    expect(totals?.uniqueWorks, 1);
    expect(totals?.readingOccurrences, 2);
    expect(totals?.knownPages, 240);
  });
}

const _reader = ReadingChapterReader(
  displayName: 'Reader',
  locale: 'es',
);

ReadingChapterSourceBook _chapterBook({
  required String id,
  required String title,
  required String status,
  String author = 'Author',
  String isbn = '',
  int? pages = 200,
  List<String> categories = const ['fiction'],
  String format = 'physical',
  String coverUrl = 'https://covers.example/book.jpg',
}) => ReadingChapterSourceBook(
  entryId: id,
  title: title,
  authors: [author],
  isbn13: isbn,
  status: status,
  pageCount: pages,
  categoryCodes: categories,
  coverUrl: coverUrl,
  format: format,
);
