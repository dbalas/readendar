import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/celebration/celebration_metrics.dart';

ReadingEvent _event({
  required String type,
  required DateTime date,
  String status = 'active',
  String bookId = 'book-1',
}) => ReadingEvent(
  id: 'e-$type-${date.millisecondsSinceEpoch}',
  ownerType: 'user',
  ownerId: 'user-1',
  type: type,
  title: type,
  dateLocal: date,
  status: status,
  bookId: bookId,
);

Book _book({int? pageCount}) => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Dune',
  authors: const ['Herbert'],
  status: 'read',
  pageCount: pageCount,
);

void main() {
  group('CelebrationMetrics.from', () {
    test('computes all metrics from full history', () {
      final m = CelebrationMetrics.from(
        book: _book(pageCount: 200),
        events: [
          _event(type: 'start', date: DateTime.utc(2026, 5)),
          _event(
            type: 'chapter_milestone',
            date: DateTime.utc(2026, 5, 4),
            status: 'completed',
          ),
          _event(
            type: 'page_milestone',
            date: DateTime.utc(2026, 5, 8),
            status: 'completed',
          ),
          _event(type: 'finish', date: DateTime.utc(2026, 5, 11)),
        ],
      );

      expect(m.daysToFinish, 10);
      expect(m.pagesRead, 200);
      expect(m.sessions, 2);
      expect(m.hasAny, isTrue);
    });

    test('falls back to earliest event when no start event exists', () {
      final m = CelebrationMetrics.from(
        book: _book(pageCount: 100),
        events: [
          _event(
            type: 'chapter_milestone',
            date: DateTime.utc(2026, 5, 3),
            status: 'completed',
          ),
          _event(type: 'finish', date: DateTime.utc(2026, 5, 9)),
        ],
        now: DateTime.utc(2026, 5, 20),
      );

      expect(m.daysToFinish, 6); // 9th − 3rd
    });

    test('days-to-finish is null with no events', () {
      final m = CelebrationMetrics.from(
        book: _book(pageCount: 100),
        events: const [],
      );
      expect(m.daysToFinish, isNull);
    });

    test('pagesRead falls back to progress page when no pageCount', () {
      final m = CelebrationMetrics.from(
        book: _book(),
        events: const [],
        progress: Progress(bookEntryId: 'book-1', currentPage: 57),
      );
      expect(m.pagesRead, 57);
    });

    test('pagesRead is null when neither pageCount nor progress page exist', () {
      final m = CelebrationMetrics.from(book: _book(), events: const []);
      expect(m.pagesRead, isNull);
    });

    test('sessions is null when no milestones were completed', () {
      final m = CelebrationMetrics.from(
        book: _book(pageCount: 100),
        events: [
          _event(type: 'start', date: DateTime.utc(2026, 5)),
          // active (not completed) milestone does not count
          _event(type: 'chapter_milestone', date: DateTime.utc(2026, 5, 2)),
          _event(type: 'finish', date: DateTime.utc(2026, 5, 5)),
        ],
      );
      expect(m.sessions, isNull);
    });

    test('only counts events for the given book', () {
      final m = CelebrationMetrics.from(
        book: _book(pageCount: 100),
        events: [
          _event(
            type: 'page_milestone',
            date: DateTime.utc(2026, 5, 2),
            status: 'completed',
            bookId: 'other-book',
          ),
        ],
      );
      expect(m.sessions, isNull);
      expect(m.daysToFinish, isNull);
    });
  });
}
