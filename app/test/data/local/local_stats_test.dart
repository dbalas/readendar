import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/data/local/local_stats.dart';

void main() {
  final now = DateTime.utc(2026, 9, 19);

  Book book({
    required String id,
    required String status,
    int? pageCount,
    DateTime? changedAt,
    double? rating,
  }) => Book(
    id: id,
    ownerType: 'user',
    ownerId: 'local-guest',
    title: id,
    authors: const ['Autor'],
    status: status,
    pageCount: pageCount,
    statusChangedAt: changedAt,
    rating: rating,
  );

  ReadingEvent finish(String bookId, DateTime date) => ReadingEvent(
    id: 'ev-$bookId',
    ownerType: 'user',
    ownerId: 'local-guest',
    type: 'finish',
    title: 'Fin',
    dateLocal: date,
    status: EventStatus.completed,
    bookId: bookId,
  );

  test('counts books finished this year, currently reading, and pages', () {
    final stats = computeLocalUserStats(
      books: [
        book(
          id: 'read-year',
          status: BookStatus.read,
          pageCount: 200,
          changedAt: DateTime.utc(2026, 4, 2),
          rating: 5,
        ),
        book(
          id: 'read-old',
          status: BookStatus.read,
          pageCount: 80,
          changedAt: DateTime.utc(2025, 1, 1),
        ),
        book(id: 'reading-now', status: BookStatus.reading, pageCount: 300),
        book(id: 'queued', status: BookStatus.pending),
      ],
      events: [
        finish('read-year', DateTime.utc(2026, 4, 2)),
      ],
      pageActivity: [
        {
          'id': 'p1',
          'bookEntryId': 'reading-now',
          'pages': 40,
          'occurredAt': '2026-09-19T10:00:00.000Z',
        },
      ],
      now: now,
    );

    expect(stats.summary.booksRead, 2);
    expect(stats.summary.booksReading, 1);
    expect(stats.summary.booksQueued, 1);
    expect(stats.summary.finishedBookPages, 280);
    expect(stats.activity.finishedYear, 1);
    expect(stats.overview.year, 2026);
    expect(stats.overview.finishedBooks, 1);
    expect(stats.overview.loggedPages, 40);
    expect(stats.pageActivity.available, isTrue);
    expect(stats.pageActivity.todayPages, 40);
  });

  test('empty library yields zeroed stats without throwing', () {
    final stats = computeLocalUserStats(
      books: const [],
      events: const [],
      now: now,
    );
    expect(stats.summary.totalBooks, 0);
    expect(stats.activity.finishedYear, 0);
    expect(stats.pageActivity.available, isFalse);
  });
}
