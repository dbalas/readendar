import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/core/models/widget_models.dart';

const kLocalWidgetMaxEvents = 10;
const kLocalWidgetEventWindow = Duration(days: 45);

/// Builds the home-widget snapshot from local books, events, and progress.
WidgetSummary buildLocalWidgetSummary({
  required List<Book> books,
  required List<ReadingEvent> events,
  required Map<String, Progress> progressByBookId,
  DateTime? now,
  Map<String, String> widgetCoverById = const {},
}) {
  final clock = now ?? DateTime.now().toUtc();
  final today = localCivilUtc(clock);
  final windowEnd = today.add(kLocalWidgetEventWindow);
  final booksById = {for (final book in books) book.id: book};

  String coverOf(Book book) => widgetCoverById[book.id] ?? book.coverUrl;

  final ranked = <({WidgetBook book, DateTime rank})>[];
  for (final book in books) {
    if (book.status != BookStatus.reading) continue;
    final progress = progressByBookId[book.id];
    var rank = book.statusChangedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (progress != null && progress.updatedAt.isAfter(rank)) {
      rank = progress.updatedAt;
    }
    ranked.add((
      book: WidgetBook(
        id: book.id,
        title: book.title,
        author: book.authors.isEmpty ? '' : book.authors.first,
        coverUrl: coverOf(book),
        progressPct: _progressPct(progress, book.pageCount),
        currentPage: progress?.currentPage,
        pageCount: book.pageCount,
        currentChapter: progress?.currentChapter,
        chapterCount: book.chapterCount,
      ),
      rank: rank,
    ));
  }
  ranked.sort((a, b) {
    final byRank = b.rank.compareTo(a.rank);
    if (byRank != 0) return byRank;
    return a.book.id.compareTo(b.book.id);
  });

  final upcoming = <WidgetEvent>[];
  for (final event in events) {
    final day = localCivilUtc(event.dateLocal);
    if (day.isBefore(today) || day.isAfter(windowEnd)) continue;
    if (event.status == EventStatus.cancelled) continue;
    if (event.status != EventStatus.active &&
        event.status != EventStatus.completed) {
      continue;
    }
    final linked = event.bookId == null ? null : booksById[event.bookId];
    upcoming.add(
      WidgetEvent(
        id: event.id,
        type: event.type,
        dateLocal: localYmd(event.dateLocal),
        bookId: event.bookId,
        bookTitle: linked?.title,
        bookAuthor: linked == null || linked.authors.isEmpty
            ? null
            : linked.authors.first,
        bookCoverUrl: linked == null ? null : coverOf(linked),
        title: event.title,
        status: event.status,
        timeLocal: event.timeLocal,
        tz: event.tz,
      ),
    );
  }
  upcoming.sort((a, b) {
    final byDate = a.dateLocal.compareTo(b.dateLocal);
    if (byDate != 0) return byDate;
    return (a.timeLocal ?? '').compareTo(b.timeLocal ?? '');
  });
  final hasMore = upcoming.length > kLocalWidgetMaxEvents;
  return WidgetSummary(
    readingBooks: [for (final row in ranked) row.book],
    events: [
      for (final event in upcoming.take(kLocalWidgetMaxEvents)) event,
    ],
    hasMore: hasMore,
  );
}

int? _progressPct(Progress? progress, int? pageCount) {
  if (progress == null) return null;
  if (progress.currentPercentage != null) return progress.currentPercentage;
  final page = progress.currentPage;
  if (page == null || pageCount == null || pageCount <= 0) return null;
  final pct = ((page / pageCount) * 100).round();
  if (pct < 0) return 0;
  if (pct > 100) return 100;
  return pct;
}
