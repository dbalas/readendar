import 'package:readendar/core/models/models.dart';

/// Reading metrics shown on the finish-book celebration, computed purely
/// on-device from the book, its full event history and current progress.
///
/// Every field is nullable: the celebration renders only the metrics it can
/// compute, so a book with no start event or no page count still looks good.
class CelebrationMetrics {
  const CelebrationMetrics({this.daysToFinish, this.pagesRead, this.sessions});

  /// Builds the metrics for [book] from its [events] (full history) and
  /// optional [progress]. [now] defaults to the current time and is injectable
  /// for tests.
  factory CelebrationMetrics.from({
    required Book book,
    required List<ReadingEvent> events,
    Progress? progress,
    DateTime? now,
  }) {
    final bookEvents = events
        .where((e) => e.bookId == book.id)
        .toList(growable: false);

    return CelebrationMetrics(
      daysToFinish: _daysToFinish(bookEvents, now ?? DateTime.now()),
      pagesRead: book.pageCount ?? progress?.currentPage,
      sessions: _sessions(bookEvents),
    );
  }

  /// Calendar days from the start of the read to its finish. Null when there
  /// are no events at all to anchor a start date.
  final int? daysToFinish;

  /// Pages in the book (or the last recorded page if the count is unknown).
  final int? pagesRead;

  /// Number of completed reading-milestone events (chapter / page / percentage).
  /// Null when none were completed.
  final int? sessions;

  bool get hasAny =>
      daysToFinish != null || pagesRead != null || sessions != null;

  static const _milestoneTypes = {
    'chapter_milestone',
    'page_milestone',
    'percentage_milestone',
  };

  static int? _daysToFinish(List<ReadingEvent> bookEvents, DateTime now) {
    if (bookEvents.isEmpty) return null;

    DateTime? earliestOf(bool Function(ReadingEvent) test) {
      DateTime? best;
      for (final e in bookEvents.where(test)) {
        if (best == null || e.dateLocal.isBefore(best)) best = e.dateLocal;
      }
      return best;
    }

    final start =
        earliestOf((e) => e.type == 'start') ?? earliestOf((e) => true);
    if (start == null) return null;

    DateTime? finish;
    for (final e in bookEvents.where((e) => e.type == 'finish')) {
      if (finish == null || e.dateLocal.isAfter(finish)) finish = e.dateLocal;
    }
    final end = finish ?? now;

    final days = end.difference(start).inDays;
    return days < 0 ? 0 : days;
  }

  static int? _sessions(List<ReadingEvent> bookEvents) {
    final count = bookEvents
        .where(
          (e) => e.status == 'completed' && _milestoneTypes.contains(e.type),
        )
        .length;
    return count == 0 ? null : count;
  }
}
