import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/data/local/local_store.dart';

/// Local projection of GET /v1/me/stats from books + events (+ optional page logs).
UserStats computeLocalUserStats({
  required List<Book> books,
  required List<ReadingEvent> events,
  List<Map<String, dynamic>> pageActivity = const [],
  DateTime? now,
  PageActivityQuery query = const PageActivityQuery(),
}) {
  final clock = now ?? DateTime.now().toUtc();
  final finishes = _finishDates(books, events);
  return UserStats(
    summary: _summary(books),
    overview: _overview(books, finishes, pageActivity, clock),
    activity: _activity(books, finishes, clock),
    pageActivity: _pageActivity(pageActivity, clock, query),
    taste: _taste(books, finishes, clock, query.tasteScope),
  );
}

Future<UserStats> loadLocalUserStats(
  LocalStore store, {
  DateTime? now,
  PageActivityQuery query = const PageActivityQuery(),
}) async {
  final bookRows = await store.list(LocalCollections.books);
  final eventRows = await store.list(LocalCollections.events);
  final pageRows = await store.list(LocalCollections.pageActivity);
  return computeLocalUserStats(
    books: [for (final row in bookRows) ?_tryBook(row)],
    events: [for (final row in eventRows) ?_tryEvent(row)],
    pageActivity: pageRows,
    now: now,
    query: query,
  );
}

Book? _tryBook(Map<String, dynamic> row) {
  try {
    return Book.fromJson(row);
  } on Object {
    return null;
  }
}

ReadingEvent? _tryEvent(Map<String, dynamic> row) {
  try {
    return ReadingEvent.fromJson(row);
  } on Object {
    return null;
  }
}

class _Finish {
  const _Finish(this.bookId, this.date);
  final String bookId;
  final DateTime date;
}

List<_Finish> _finishDates(List<Book> books, List<ReadingEvent> events) {
  final byBook = <String, DateTime>{};
  for (final event in events) {
    if (event.type != 'finish' || event.bookId == null) continue;
    byBook[event.bookId!] = event.dateLocal;
  }
  for (final book in books) {
    if (book.status != BookStatus.read) continue;
    byBook.putIfAbsent(
      book.id,
      () => book.statusChangedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
  return [for (final e in byBook.entries) _Finish(e.key, e.value)];
}

UserStatsSummary _summary(List<Book> books) {
  var read = 0;
  var reading = 0;
  var queued = 0;
  var wanted = 0;
  var abandoned = 0;
  var finishedPages = 0;
  DateTime? earliest;
  for (final book in books) {
    switch (book.status) {
      case BookStatus.read:
        read++;
        finishedPages += book.pageCount ?? 0;
      case BookStatus.reading:
        reading++;
      case BookStatus.pending:
        queued++;
      case BookStatus.wanted:
        wanted++;
      case BookStatus.abandoned:
        abandoned++;
      default:
        break;
    }
    final added = book.statusChangedAt;
    if (added != null && (earliest == null || added.isBefore(earliest))) {
      earliest = added;
    }
  }
  return UserStatsSummary(
    booksRead: read,
    booksReading: reading,
    booksQueued: queued,
    booksWanted: wanted,
    booksAbandoned: abandoned,
    totalBooks: books.length,
    finishedBookPages: finishedPages,
    readingSince: earliest,
  );
}

int _monthIndex(DateTime t) => t.year * 12 + t.month - 1;

String _monthKey(int idx) {
  final y = idx ~/ 12;
  final mo = (idx % 12) + 1;
  return '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}';
}

UserYearOverview _overview(
  List<Book> books,
  List<_Finish> finishes,
  List<Map<String, dynamic>> pageActivity,
  DateTime now,
) {
  final year = now.year;
  var finishedYear = 0;
  final pagesByMonth = <int, int>{};
  final booksByMonth = <int, int>{};
  for (final finish in finishes) {
    if (finish.date.year != year) continue;
    finishedYear++;
    booksByMonth[_monthIndex(finish.date)] =
        (booksByMonth[_monthIndex(finish.date)] ?? 0) + 1;
  }
  var loggedPages = 0;
  var previousYearPages = 0;
  final activeDays = <String>{};
  for (final row in pageActivity) {
    final pages = (row['pages'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse((row['occurredAt'] as String?) ?? '');
    if (at == null) continue;
    if (at.year == year) {
      loggedPages += pages;
      pagesByMonth[_monthIndex(at)] = (pagesByMonth[_monthIndex(at)] ?? 0) + pages;
      activeDays.add(localDayKey(at));
    } else if (at.year == year - 1) {
      previousYearPages += pages;
    }
  }
  if (pageActivity.isEmpty) {
    final byId = {for (final b in books) b.id: b};
    for (final finish in finishes) {
      if (finish.date.year != year) continue;
      loggedPages += byId[finish.bookId]?.pageCount ?? 0;
    }
  }
  double? change;
  if (previousYearPages > 0) {
    change = ((loggedPages - previousYearPages) / previousYearPages) * 100;
  }
  final nowIdx = _monthIndex(now);
  final monthly = <UserOverviewMonth>[
    for (var i = 11; i >= 0; i--)
      UserOverviewMonth(
        month: _monthKey(nowIdx - i),
        books: booksByMonth[nowIdx - i] ?? 0,
        pages: pagesByMonth[nowIdx - i] ?? 0,
      ),
  ];
  final dayStreaks = _dayStreaks(activeDays, now);
  return UserYearOverview(
    available: true,
    year: year,
    finishedBooks: finishedYear,
    loggedPages: loggedPages,
    activeDays: activeDays.length,
    currentDayStreak: dayStreaks.current,
    longestDayStreak: dayStreaks.longest,
    previousYearPages: previousYearPages,
    changePercent: change,
    monthly: monthly,
  );
}

String localDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

({int current, int longest}) _dayStreaks(Set<String> days, DateTime now) {
  if (days.isEmpty) return (current: 0, longest: 0);
  final parsed = [
    for (final key in days) DateTime.parse('${key}T00:00:00Z'),
  ]..sort();
  var longest = 1;
  var run = 1;
  for (var i = 1; i < parsed.length; i++) {
    final gap = parsed[i].difference(parsed[i - 1]).inDays;
    if (gap == 1) {
      run++;
      if (run > longest) longest = run;
    } else if (gap > 1) {
      run = 1;
    }
  }
  var current = 0;
  var cursor = DateTime.utc(now.year, now.month, now.day);
  while (days.contains(localDayKey(cursor))) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  if (current == 0) {
    final yesterday = DateTime.utc(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    cursor = yesterday;
    while (days.contains(localDayKey(cursor))) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }
  return (current: current, longest: longest);
}

UserStatsActivity _activity(
  List<Book> books,
  List<_Finish> finishes,
  DateTime now,
) {
  final w30 = now.subtract(const Duration(days: 30));
  var finished30 = 0;
  var finishedYear = 0;
  var added30 = 0;
  final byMonth = <int, int>{};
  for (final finish in finishes) {
    byMonth[_monthIndex(finish.date)] =
        (byMonth[_monthIndex(finish.date)] ?? 0) + 1;
    if (finish.date.isAfter(w30)) finished30++;
    if (finish.date.year == now.year) finishedYear++;
  }
  for (final book in books) {
    final added = book.statusChangedAt;
    if (added != null && added.isAfter(w30)) added30++;
  }
  final nowIdx = _monthIndex(now);
  final monthly = <UserMonthCount>[
    for (var i = 11; i >= 0; i--)
      UserMonthCount(
        month: _monthKey(nowIdx - i),
        count: byMonth[nowIdx - i] ?? 0,
      ),
  ];
  var bestMonth = '';
  var bestCount = 0;
  var bestIdx = -1;
  for (final e in byMonth.entries) {
    if (bestIdx < 0 ||
        e.value > bestCount ||
        (e.value == bestCount && e.key > bestIdx)) {
      bestIdx = e.key;
      bestCount = e.value;
    }
  }
  if (bestIdx >= 0) bestMonth = _monthKey(bestIdx);

  var currentStreak = 0;
  var anchor = nowIdx;
  if ((byMonth[nowIdx] ?? 0) == 0) anchor = nowIdx - 1;
  for (var i = anchor; (byMonth[i] ?? 0) > 0; i--) {
    currentStreak++;
  }
  final idxs = byMonth.keys.toList()..sort();
  var longest = 0;
  var run = 0;
  var prev = 0;
  for (var i = 0; i < idxs.length; i++) {
    final idx = idxs[i];
    if (i > 0 && idx == prev + 1) {
      run++;
    } else {
      run = 1;
    }
    if (run > longest) longest = run;
    prev = idx;
  }
  return UserStatsActivity(
    finished30: finished30,
    finishedYear: finishedYear,
    added30: added30,
    currentStreak: currentStreak,
    longestStreak: longest,
    bestMonth: bestMonth,
    bestMonthCount: bestCount,
    monthly: monthly,
  );
}

UserPageActivity _pageActivity(
  List<Map<String, dynamic>> rows,
  DateTime now,
  PageActivityQuery query,
) {
  if (rows.isEmpty) {
    return UserPageActivity.fromJson(const {});
  }
  final today = DateTime.utc(now.year, now.month, now.day);
  final (:from, :to, :previousFrom, :previousTo) = _rangeFor(
    query.granularity,
    query.offset,
    today,
  );
  var total = 0;
  var todayPages = 0;
  var previous = 0;
  final byDay = <String, int>{};
  for (final row in rows) {
    final pages = (row['pages'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse((row['occurredAt'] as String?) ?? '');
    if (at == null) continue;
    final day = DateTime.utc(at.year, at.month, at.day);
    if (!day.isBefore(from) && !day.isAfter(to)) {
      total += pages;
      byDay[localDayKey(day)] = (byDay[localDayKey(day)] ?? 0) + pages;
    }
    if (day == today) todayPages += pages;
    if (!day.isBefore(previousFrom) && !day.isAfter(previousTo)) {
      previous += pages;
    }
  }
  final buckets = <UserPageBucket>[
    for (final e in (byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
      UserPageBucket(
        startDate: DateTime.parse('${e.key}T00:00:00Z'),
        endDate: DateTime.parse('${e.key}T00:00:00Z'),
        pages: e.value,
        isFuture: DateTime.parse('${e.key}T00:00:00Z').isAfter(today),
      ),
  ];
  final activeDays = byDay.length;
  return UserPageActivity(
    available: true,
    granularity: query.granularity,
    offset: query.offset,
    from: from,
    to: to,
    totalPages: total,
    todayPages: todayPages,
    previousPages: previous,
    averagePages: activeDays == 0 ? 0 : total / activeDays,
    activeBuckets: buckets.where((b) => b.pages > 0).length,
    activeDays: activeDays,
    buckets: buckets,
  );
}

({DateTime from, DateTime to, DateTime previousFrom, DateTime previousTo})
_rangeFor(PageGranularity granularity, int offset, DateTime today) {
  switch (granularity) {
    case PageGranularity.day:
      final from = today.add(Duration(days: offset));
      return (
        from: from,
        to: from,
        previousFrom: from.subtract(const Duration(days: 1)),
        previousTo: from.subtract(const Duration(days: 1)),
      );
    case PageGranularity.week:
      final start = today.subtract(Duration(days: today.weekday % 7));
      final from = start.add(Duration(days: offset * 7));
      final to = from.add(const Duration(days: 6));
      return (
        from: from,
        to: to,
        previousFrom: from.subtract(const Duration(days: 7)),
        previousTo: from.subtract(const Duration(days: 1)),
      );
    case PageGranularity.month:
      final monthStart = DateTime.utc(today.year, today.month + offset);
      final next = DateTime.utc(monthStart.year, monthStart.month + 1);
      final to = next.subtract(const Duration(days: 1));
      final prevStart = DateTime.utc(monthStart.year, monthStart.month - 1);
      return (
        from: monthStart,
        to: to,
        previousFrom: prevStart,
        previousTo: monthStart.subtract(const Duration(days: 1)),
      );
    case PageGranularity.year:
      final from = DateTime.utc(today.year + offset);
      final to = DateTime.utc(from.year, 12, 31);
      return (
        from: from,
        to: to,
        previousFrom: DateTime.utc(from.year - 1),
        previousTo: DateTime.utc(from.year - 1, 12, 31),
      );
    case PageGranularity.all:
      return (
        from: DateTime.utc(1970),
        to: today,
        previousFrom: DateTime.utc(1970),
        previousTo: DateTime.utc(1970),
      );
  }
}

UserStatsTaste _taste(
  List<Book> books,
  List<_Finish> finishes,
  DateTime now,
  TasteScope scope,
) {
  final finishedThisYear = {
    for (final f in finishes)
      if (f.date.year == now.year) f.bookId,
  };
  final selected = [
    for (final book in books)
      if (book.status == BookStatus.read)
        if (scope != TasteScope.year || finishedThisYear.contains(book.id))
          book,
  ];
  final authors = <String, int>{};
  var ratingSum = 0.0;
  var rated = 0;
  var high = 0;
  final dist = [0, 0, 0, 0, 0];
  final formats = <String, int>{};
  for (final book in selected) {
    for (final author in book.authors) {
      final name = author.trim();
      if (name.isEmpty) continue;
      authors[name] = (authors[name] ?? 0) + 1;
    }
    final rating = book.rating;
    if (rating != null) {
      rated++;
      ratingSum += rating;
      if (rating >= 4) high++;
      var bucket = rating.ceil();
      if (bucket < 1) bucket = 1;
      if (bucket > 5) bucket = 5;
      dist[bucket - 1]++;
    }
    final format = book.format?.trim();
    if (format != null && format.isNotEmpty) {
      formats[format] = (formats[format] ?? 0) + 1;
    }
  }
  final topAuthors = [
    for (final e in authors.entries)
      UserAuthorAffinity(
        author: e.key,
        count: e.value,
        ratedCount: 0,
        avgRating: null,
      ),
  ]..sort((a, b) => b.count.compareTo(a.count));
  return UserStatsTaste(
    scope: scope,
    completedCount: selected.length,
    topGenres: const [],
    topAuthors: topAuthors.take(5).toList(),
    avgRating: rated == 0 ? null : ratingSum / rated,
    ratedCount: rated,
    highRatingPercent: rated == 0 ? 0 : ((high / rated) * 100).round(),
    ratingDistribution: [
      for (var i = 0; i < 5; i++)
        UserRatingBucket(rating: i + 1, count: dist[i]),
    ],
    formats: [
      for (final e in formats.entries)
        UserFormatCount(format: e.key, count: e.value),
    ],
  );
}
