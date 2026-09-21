import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

const readingChapterSchemaVersion = 1;
const readingChapterArchetypeRuleVersion = 3;
const readingChapterMaxBooksPerCard = 100;

const readingChapterCardCoverMosaic = 'coverMosaic';
const readingChapterCardRhythm = 'rhythm';
const readingChapterCardComparison = 'comparison';
const readingChapterCardJourney = 'journey';
const readingChapterCardFormatMix = 'formatMix';
const readingChapterCardTaste = 'taste';
const readingChapterCardRatings = 'ratings';
const readingChapterCardArchetype = 'archetype';
const readingChapterCardReflection = 'reflection';
const readingChapterCardSummary = 'summary';

const readingChapterReadinessUnconfirmedDate = 'unconfirmedDate';
const readingChapterReadinessMissingPages = 'missingPages';
const readingChapterReadinessMissingFormat = 'missingFormat';
const readingChapterReadinessMissingGenres = 'missingGenres';
const readingChapterReadinessMissingCover = 'missingCover';
const readingChapterReadinessReviewGrouping = 'reviewGrouping';
const readingChapterReadinessInvalidPick = 'invalidPick';

const localReadingChapterCapabilities = ReadingChapterCapabilities(
  privateGeneration: true,
);

class ReadingChapterPeriodException implements Exception {
  ReadingChapterPeriodException(this.code);
  final String code;

  @override
  String toString() => code;
}

class ReadingChapterSourceBook {
  const ReadingChapterSourceBook({
    required this.entryId,
    required this.title,
    required this.authors,
    required this.status,
    this.coverUrl = '',
    this.isbn13 = '',
    this.isbn10 = '',
    this.canonicalIsbn = '',
    this.workIdentity = '',
    this.pageCount,
    this.categories = const [],
    this.categoryCodes = const [],
    this.rating,
    this.format = '',
  });

  final String entryId;
  final String title;
  final List<String> authors;
  final String coverUrl;
  final String isbn13;
  final String isbn10;
  final String canonicalIsbn;
  final String workIdentity;
  final int? pageCount;
  final List<String> categories;
  final List<String> categoryCodes;
  final double? rating;
  final String format;
  final String status;
}

class ReadingChapterHistoryRow {
  const ReadingChapterHistoryRow({
    required this.bookEntryId,
    required this.status,
    required this.changedAt,
    required this.dateConfirmed,
    this.id = '',
  });

  final String id;
  final String bookEntryId;
  final String status;
  final DateTime changedAt;
  final bool dateConfirmed;
}

class ReadingChapterPageActivityRow {
  const ReadingChapterPageActivityRow({
    required this.bookEntryId,
    required this.pages,
    required this.occurredAt,
  });

  final String bookEntryId;
  final int pages;
  final DateTime occurredAt;
}

class ReadingChapterSourceData {
  const ReadingChapterSourceData({
    required this.reader,
    required this.revision,
    required this.books,
    this.history = const [],
    this.pageActivity = const [],
    this.groupOverrides = const {},
  });

  final ReadingChapterReader reader;
  final int revision;
  final List<ReadingChapterSourceBook> books;
  final List<ReadingChapterHistoryRow> history;
  final List<ReadingChapterPageActivityRow> pageActivity;
  final Map<String, String> groupOverrides;
}

class ReadingChapterComputePeriod {
  const ReadingChapterComputePeriod({
    required this.kind,
    required this.key,
    required this.timezone,
    required this.startsAt,
    required this.endsAt,
    this.seenAt,
    this.curation = const [],
    this.curationRevision = 0,
  });

  final ReadingChapterKind kind;
  final String key;
  final String timezone;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? seenAt;
  final List<ReadingChapterReflection> curation;
  final int curationRevision;

  ReadingChapterPeriod toStoryPeriod() => ReadingChapterPeriod(
    kind: kind,
    key: key,
    timezone: timezone,
    startsAt: startsAt,
    endsAt: endsAt,
    seenAt: seenAt,
  );
}

class ReadingChapterArchiveProjection {
  const ReadingChapterArchiveProjection({
    required this.uniqueWorks,
    required this.coverUrls,
    required this.meaningful,
  });

  final int uniqueWorks;
  final List<String> coverUrls;
  final bool meaningful;
}

class _Occurrence {
  const _Occurrence({required this.book, required this.at, required this.key});

  final ReadingChapterSourceBook book;
  final DateTime at;
  final String key;
}

class _StatusMoment {
  const _StatusMoment({required this.status, required this.at});

  final String status;
  final DateTime at;
}

class _TouchedJourney {
  const _TouchedJourney({
    required this.touched,
    required this.started,
    required this.abandoned,
    required this.ongoing,
  });

  final Map<String, DateTime> touched;
  final int started;
  final int abandoned;
  final int ongoing;
}

final _letterOrDigit = RegExp(r'[\p{L}\p{Nd}]', unicode: true);
const _validReflectionPrompts = {
  'favorite',
  'biggest_surprise',
  'comfort_read',
  'challenged_me',
  'best_cover',
  'memorable_passage',
  'favorite_return',
  'unfinished_unforgettable',
};

/// Closed civil period in [timezone]. Throws [ReadingChapterPeriodException]
/// when the key, timezone, or closed-window check fails.
ReadingChapterComputePeriod buildReadingChapterPeriod({
  required ReadingChapterKind kind,
  required String key,
  required String timezone,
  required DateTime now,
  List<ReadingChapterReflection> curation = const [],
  int curationRevision = 0,
}) {
  initializeAppTimeZones();
  final loc = timezone == 'UTC' || timezone == 'Etc/UTC'
      ? tz.UTC
      : tz.timeZoneDatabase.locations[timezone];
  if (loc == null) {
    throw ReadingChapterPeriodException('invalid_timezone');
  }
  late final tz.TZDateTime start;
  late final tz.TZDateTime end;
  switch (kind) {
    case ReadingChapterKind.month:
      final parsed = DateTime.tryParse('$key-01');
      if (parsed == null ||
          '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}' !=
              key) {
        throw ReadingChapterPeriodException('invalid_reading_chapter_period');
      }
      start = tz.TZDateTime(loc, parsed.year, parsed.month, 1);
      end = tz.TZDateTime(loc, parsed.year, parsed.month + 1, 1);
    case ReadingChapterKind.year:
      final year = int.tryParse(key);
      if (year == null ||
          year < 1970 ||
          year.toString().padLeft(4, '0') != key) {
        throw ReadingChapterPeriodException('invalid_reading_chapter_period');
      }
      start = tz.TZDateTime(loc, year, 1, 1);
      end = tz.TZDateTime(loc, year + 1, 1, 1);
  }
  final nowLocal = tz.TZDateTime.from(now.toUtc(), loc);
  if (end.isAfter(nowLocal)) {
    throw ReadingChapterPeriodException('reading_chapter_period_not_closed');
  }
  return ReadingChapterComputePeriod(
    kind: kind,
    key: key,
    timezone: timezone,
    startsAt: start.toUtc(),
    endsAt: end.toUtc(),
    curation: curation,
    curationRevision: curationRevision,
  );
}

ReadingChapterComputePeriod previousReadingChapterPeriod(
  ReadingChapterComputePeriod period,
) {
  initializeAppTimeZones();
  final loc = tz.timeZoneDatabase.locations[period.timezone] ?? tz.UTC;
  final start = tz.TZDateTime.from(period.startsAt.toUtc(), loc);
  if (period.kind == ReadingChapterKind.month) {
    final previous = tz.TZDateTime(loc, start.year, start.month - 1, 1);
    return ReadingChapterComputePeriod(
      kind: ReadingChapterKind.month,
      key:
          '${previous.year.toString().padLeft(4, '0')}-${previous.month.toString().padLeft(2, '0')}',
      timezone: period.timezone,
      startsAt: previous.toUtc(),
      endsAt: tz.TZDateTime(loc, start.year, start.month, 1).toUtc(),
    );
  }
  final previous = tz.TZDateTime(loc, start.year - 1, 1, 1);
  return ReadingChapterComputePeriod(
    kind: ReadingChapterKind.year,
    key: previous.year.toString().padLeft(4, '0'),
    timezone: period.timezone,
    startsAt: previous.toUtc(),
    endsAt: tz.TZDateTime(loc, start.year, 1, 1).toUtc(),
  );
}

/// Pure projection. Source rows, period bounds, and curation determine cards.
ReadingChapterStory computeReadingChapter(
  ReadingChapterSourceData data,
  ReadingChapterComputePeriod period,
) {
  final booksById = {for (final row in data.books) row.entryId: row};
  final completed = _completionOccurrences(data, period, booksById);
  final previous = _completionOccurrences(
    data,
    previousReadingChapterPeriod(period),
    booksById,
  );
  final journey = _touchedBooks(data, period, booksById);
  final works = _groupOccurrences(completed);
  final touchedWorks = _storyBooksFromTouched(journey.touched, data);
  final totals = _buildTotals(
    completed,
    works,
    journey.started,
    journey.abandoned,
    journey.ongoing,
  );
  final cards = <ReadingChapterCard>[];
  var opening = works;
  if (opening.isEmpty) opening = touchedWorks;
  if (opening.isNotEmpty) {
    cards.add(
      _card(
        id: 'opening',
        kind: readingChapterCardCoverMosaic,
        books: _capStoryBooks(opening),
      ),
    );
  }
  final rhythm = _buildRhythm(data, period, completed);
  final minRhythm = period.kind == ReadingChapterKind.month ? 1 : 2;
  if (rhythm.length >= minRhythm) {
    cards.add(
      _card(id: 'rhythm', kind: readingChapterCardRhythm, rhythm: rhythm),
    );
  }
  final comparison = _buildComparison(period, completed, previous);
  if (comparison != null) {
    cards.add(
      _card(
        id: 'comparison',
        kind: readingChapterCardComparison,
        comparison: comparison,
      ),
    );
  }
  if (period.kind == ReadingChapterKind.year) {
    if (journey.started + journey.abandoned + journey.ongoing > 0) {
      cards.add(
        _card(
          id: 'journey',
          kind: readingChapterCardJourney,
          journey: ReadingChapterJourney(
            started: journey.started,
            abandoned: journey.abandoned,
            ongoing: journey.ongoing,
          ),
          books: _capStoryBooks(touchedWorks),
        ),
      );
    }
    final formats = _buildFormats(completed);
    if (formats.isNotEmpty) {
      cards.add(
        _card(
          id: 'formats',
          kind: readingChapterCardFormatMix,
          formats: formats,
        ),
      );
    }
    final tasteAndRatings = _buildTasteAndRatings(works);
    if (tasteAndRatings.taste != null) {
      cards.add(
        _card(
          id: 'taste',
          kind: readingChapterCardTaste,
          taste: tasteAndRatings.taste,
        ),
      );
    }
    if (tasteAndRatings.ratings != null) {
      cards.add(
        _card(
          id: 'ratings',
          kind: readingChapterCardRatings,
          ratings: tasteAndRatings.ratings,
        ),
      );
    }
    final archetype = _buildArchetype(data, period, completed, works);
    if (archetype != null) {
      cards.add(
        _card(
          id: 'archetype',
          kind: readingChapterCardArchetype,
          archetype: archetype,
        ),
      );
    }
  }
  final seenPrompts = <String>{};
  for (var index = 0; index < period.curation.length; index++) {
    final reflection = period.curation[index];
    if (!seenPrompts.add(reflection.prompt)) continue;
    if (!booksById.containsKey(reflection.bookEntryId)) continue;
    final at = journey.touched[reflection.bookEntryId] ?? period.startsAt;
    cards.add(
      _card(
        id: 'reflection-${index + 1}',
        kind: readingChapterCardReflection,
        books: [
          _storyBookFromRow(booksById[reflection.bookEntryId]!, data, at),
        ],
        reflection: reflection,
      ),
    );
  }
  final meaningful = journey.touched.isNotEmpty;
  if (meaningful) {
    cards.add(
      _card(
        id: 'summary',
        kind: readingChapterCardSummary,
        books: _summaryBooks(works, touchedWorks),
        totals: totals,
      ),
    );
  }
  return ReadingChapterStory(
    schemaVersion: readingChapterSchemaVersion,
    archetypeRuleVersion: readingChapterArchetypeRuleVersion,
    sourceRevision: '${data.revision}-${period.curationRevision}',
    period: period.toStoryPeriod(),
    reader: data.reader,
    meaningful: meaningful,
    cards: cards,
    readiness: _buildReadiness(data, period, journey.touched, booksById),
    curation: period.curation,
  );
}

String archivePeriodKey(ReadingChapterKind kind, String key) =>
    '${kind.wire}:$key';

ReadingChapterArchiveProjection projectReadingChapterArchiveItem(
  ReadingChapterSourceData data,
  ReadingChapterComputePeriod period,
) {
  final booksById = {for (final row in data.books) row.entryId: row};
  final journey = _touchedBooks(data, period, booksById);
  var opening = _groupOccurrences(
    _completionOccurrences(data, period, booksById),
  );
  if (opening.isEmpty) {
    opening = _storyBooksFromTouched(journey.touched, data);
  }
  final covers = <String>[];
  for (final item in opening) {
    if (item.coverUrl.isNotEmpty && covers.length < 4) {
      covers.add(item.coverUrl);
    }
  }
  return ReadingChapterArchiveProjection(
    uniqueWorks: _groupOccurrences(
      _completionOccurrences(data, period, booksById),
    ).length,
    coverUrls: covers,
    meaningful: journey.touched.isNotEmpty,
  );
}

Map<String, ReadingChapterArchiveProjection>
projectAllReadingChapterArchiveItems(
  ReadingChapterSourceData data,
  String timezone,
) {
  initializeAppTimeZones();
  final loc = tz.timeZoneDatabase.locations[timezone] ?? tz.UTC;
  final booksById = {for (final row in data.books) row.entryId: row};
  final months = <String, _ArchiveBucket>{};
  final years = <String, _ArchiveBucket>{};

  _ArchiveBucket bucket(Map<String, _ArchiveBucket> store, String key) =>
      store.putIfAbsent(key, _ArchiveBucket.new);

  void touch(_ArchiveBucket item, String id, DateTime at) {
    final existing = item.touched[id];
    if (existing == null || at.isBefore(existing)) {
      item.touched[id] = at;
    }
  }

  void complete(
    _ArchiveBucket item,
    ReadingChapterSourceBook row,
    DateTime at,
  ) {
    item.completed.add(
      _Occurrence(
        book: row,
        at: at,
        key: readingChapterWorkKey(row, data.groupOverrides),
      ),
    );
  }

  for (final history in data.history) {
    if (!history.dateConfirmed) continue;
    final row = booksById[history.bookEntryId];
    if (row == null) continue;
    final local = tz.TZDateTime.from(history.changedAt.toUtc(), loc);
    final month = bucket(
      months,
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}',
    );
    final year = bucket(years, local.year.toString().padLeft(4, '0'));
    if (_isReadingActivityStatus(history.status)) {
      touch(month, history.bookEntryId, history.changedAt);
      touch(year, history.bookEntryId, history.changedAt);
    }
    if (history.status == BookStatus.read) {
      complete(month, row, history.changedAt);
      complete(year, row, history.changedAt);
    }
  }
  for (final page in data.pageActivity) {
    if (page.pages <= 0) continue;
    if (!booksById.containsKey(page.bookEntryId)) continue;
    final local = tz.TZDateTime.from(page.occurredAt.toUtc(), loc);
    touch(
      bucket(
        months,
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}',
      ),
      page.bookEntryId,
      page.occurredAt,
    );
    touch(
      bucket(years, local.year.toString().padLeft(4, '0')),
      page.bookEntryId,
      page.occurredAt,
    );
  }

  ReadingChapterArchiveProjection project(_ArchiveBucket item) {
    final works = _groupOccurrences(item.completed);
    var opening = works;
    if (opening.isEmpty) {
      opening = _storyBooksFromTouched(item.touched, data);
    }
    final covers = <String>[];
    for (final book in opening) {
      if (book.coverUrl.isNotEmpty && covers.length < 4) {
        covers.add(book.coverUrl);
      }
    }
    return ReadingChapterArchiveProjection(
      uniqueWorks: works.length,
      coverUrls: covers,
      meaningful: item.touched.isNotEmpty,
    );
  }

  return {
    for (final entry in months.entries)
      archivePeriodKey(ReadingChapterKind.month, entry.key): project(
        entry.value,
      ),
    for (final entry in years.entries)
      archivePeriodKey(ReadingChapterKind.year, entry.key): project(
        entry.value,
      ),
  };
}

DateTime? earliestReadingChapterActivity(ReadingChapterSourceData data) {
  DateTime? earliest;
  for (final row in data.history) {
    if (!row.dateConfirmed || !_isReadingActivityStatus(row.status)) continue;
    if (earliest == null || row.changedAt.isBefore(earliest)) {
      earliest = row.changedAt;
    }
  }
  for (final row in data.pageActivity) {
    if (row.pages <= 0) continue;
    if (earliest == null || row.occurredAt.isBefore(earliest)) {
      earliest = row.occurredAt;
    }
  }
  return earliest;
}

List<ReadingChapterComputePeriod> candidateReadingChapterPeriods({
  required DateTime earliestLocal,
  required DateTime nowLocal,
  required String filter,
  required String timezone,
}) {
  final periods = <ReadingChapterComputePeriod>[];
  if (filter.isEmpty ||
      filter == 'all' ||
      filter == ReadingChapterKind.month.wire) {
    var month = DateTime(nowLocal.year, nowLocal.month - 1, 1);
    final floor = DateTime(earliestLocal.year, earliestLocal.month, 1);
    while (!month.isBefore(floor)) {
      periods.add(
        ReadingChapterComputePeriod(
          kind: ReadingChapterKind.month,
          key:
              '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}',
          timezone: timezone,
          startsAt: DateTime.utc(month.year, month.month, 1),
          endsAt: DateTime.utc(month.year, month.month + 1, 1),
        ),
      );
      month = DateTime(month.year, month.month - 1, 1);
    }
  }
  if (filter.isEmpty ||
      filter == 'all' ||
      filter == ReadingChapterKind.year.wire) {
    for (var year = nowLocal.year - 1; year >= earliestLocal.year; year--) {
      periods.add(
        ReadingChapterComputePeriod(
          kind: ReadingChapterKind.year,
          key: year.toString().padLeft(4, '0'),
          timezone: timezone,
          startsAt: DateTime.utc(year, 1, 1),
          endsAt: DateTime.utc(year + 1, 1, 1),
        ),
      );
    }
  }
  periods.sort((a, b) => periodCursor(b).compareTo(periodCursor(a)));
  return periods;
}

String periodCursor(ReadingChapterComputePeriod period) {
  var key = period.key;
  if (period.kind == ReadingChapterKind.year) key = '$key-12';
  return '$key|${period.kind.wire}';
}

String validateReadingChapterCuration({
  required ReadingChapterKind kind,
  required List<ReadingChapterReflection> reflections,
}) {
  if (kind == ReadingChapterKind.year &&
      reflections.isNotEmpty &&
      reflections.length != 3) {
    return 'reading_chapter_reflections_must_be_three';
  }
  if (kind == ReadingChapterKind.month && reflections.length > 1) {
    return 'reading_chapter_month_favorite_only';
  }
  final seen = <String>{};
  for (final reflection in reflections) {
    if (!_validReflectionPrompts.contains(reflection.prompt)) {
      return 'invalid_reading_chapter_prompt';
    }
    if (kind == ReadingChapterKind.month && reflection.prompt != 'favorite') {
      return 'reading_chapter_month_favorite_only';
    }
    if (reflection.bookEntryId.isEmpty) return 'invalid_id';
    if (!seen.add(reflection.prompt)) {
      return 'duplicate_reading_chapter_prompt';
    }
    if (reflection.excerpt.runes.length > 300 ||
        reflection.attribution.runes.length > 120) {
      return 'reading_chapter_excerpt_too_long';
    }
  }
  return '';
}

String readingChapterWorkKey(
  ReadingChapterSourceBook row,
  Map<String, String> overrides,
) {
  final manual = overrides[row.entryId];
  if (manual != null && manual.isNotEmpty) return 'manual:$manual';
  if (row.workIdentity.isNotEmpty) return row.workIdentity;
  if (row.canonicalIsbn.isNotEmpty) {
    return 'isbn:${canonicalIsbn13(row.canonicalIsbn)}';
  }
  final from13 = canonicalIsbn13(row.isbn13);
  if (from13.isNotEmpty) return 'isbn:$from13';
  final from10 = canonicalIsbn13(row.isbn10);
  if (from10.isNotEmpty) return 'isbn:$from10';
  final author = row.authors.isNotEmpty ? row.authors.first : '';
  return 'text:${normalizeReadingChapterIdentity(row.title)}|${normalizeReadingChapterIdentity(author)}';
}

/// Mirrors Go `book.CanonicalISBN13`: no check-digit gate, ISBN-10 to 13.
String canonicalIsbn13(String raw) {
  final cleaned = _isbnDigitsAndX(raw);
  if (cleaned.length == 13) return cleaned;
  if (cleaned.length == 10) return _isbn10To13(cleaned);
  return '';
}

String normalizeReadingChapterIdentity(String value) {
  final b = StringBuffer();
  var space = false;
  for (final r in value.trim().toLowerCase().runes) {
    if (_letterOrDigit.hasMatch(String.fromCharCode(r))) {
      b.writeCharCode(r);
      space = false;
    } else if (!space && b.isNotEmpty) {
      b.writeCharCode(0x20);
      space = true;
    }
  }
  return b.toString().trim();
}

List<_Occurrence> _completionOccurrences(
  ReadingChapterSourceData data,
  ReadingChapterComputePeriod period,
  Map<String, ReadingChapterSourceBook> books,
) {
  final out = <_Occurrence>[];
  for (final history in data.history) {
    if (history.status != BookStatus.read ||
        !history.dateConfirmed ||
        history.changedAt.isBefore(period.startsAt) ||
        !history.changedAt.isBefore(period.endsAt)) {
      continue;
    }
    final row = books[history.bookEntryId];
    if (row == null) continue;
    out.add(
      _Occurrence(
        book: row,
        at: history.changedAt,
        key: readingChapterWorkKey(row, data.groupOverrides),
      ),
    );
  }
  out.sort((a, b) {
    if (a.at.isAtSameMomentAs(b.at)) {
      return a.book.entryId.compareTo(b.book.entryId);
    }
    return a.at.compareTo(b.at);
  });
  return out;
}

List<ReadingChapterBook> _groupOccurrences(List<_Occurrence> rows) {
  final groups = <String, ReadingChapterBook>{};
  final order = <String>[];
  for (final item in rows) {
    final existing = groups[item.key];
    if (existing == null) {
      groups[item.key] = _storyBookFromOccurrence(item);
      order.add(item.key);
    } else {
      groups[item.key] = ReadingChapterBook(
        entryId: existing.entryId,
        workKey: existing.workKey,
        title: existing.title,
        primaryAuthor: existing.primaryAuthor,
        coverUrl: existing.coverUrl,
        pageCount: existing.pageCount,
        format: existing.format,
        categories: existing.categories,
        categoryCodes: existing.categoryCodes,
        rating: existing.rating,
        firstActivityAt: existing.firstActivityAt,
        occurrences: existing.occurrences + 1,
      );
    }
  }
  return [for (final key in order) groups[key]!];
}

ReadingChapterBook _storyBookFromOccurrence(_Occurrence item) {
  return ReadingChapterBook(
    entryId: item.book.entryId,
    workKey: item.key,
    title: item.book.title,
    primaryAuthor: item.book.authors.isNotEmpty ? item.book.authors.first : '',
    coverUrl: item.book.coverUrl,
    pageCount: item.book.pageCount,
    format: item.book.format,
    categories: List<String>.of(item.book.categories),
    categoryCodes: List<String>.of(item.book.categoryCodes),
    rating: item.book.rating,
    firstActivityAt: item.at,
    occurrences: 1,
  );
}

ReadingChapterBook _storyBookFromRow(
  ReadingChapterSourceBook row,
  ReadingChapterSourceData data,
  DateTime at,
) {
  return ReadingChapterBook(
    entryId: row.entryId,
    workKey: readingChapterWorkKey(row, data.groupOverrides),
    title: row.title,
    primaryAuthor: row.authors.isNotEmpty ? row.authors.first : '',
    coverUrl: row.coverUrl,
    pageCount: row.pageCount,
    format: row.format,
    categories: List<String>.of(row.categories),
    categoryCodes: List<String>.of(row.categoryCodes),
    rating: row.rating,
    firstActivityAt: at,
    occurrences: 1,
  );
}

_TouchedJourney _touchedBooks(
  ReadingChapterSourceData data,
  ReadingChapterComputePeriod period,
  Map<String, ReadingChapterSourceBook> books,
) {
  final touched = <String, DateTime>{};
  final startedEntries = <String>{};
  final abandonedEntries = <String>{};
  final statusAtEnd = <String, _StatusMoment>{};
  for (final history in data.history) {
    if (!history.dateConfirmed || !history.changedAt.isBefore(period.endsAt)) {
      continue;
    }
    if (!books.containsKey(history.bookEntryId)) continue;
    final current = statusAtEnd[history.bookEntryId];
    if (current == null || history.changedAt.isAfter(current.at)) {
      statusAtEnd[history.bookEntryId] = _StatusMoment(
        status: history.status,
        at: history.changedAt,
      );
    }
    if (history.changedAt.isBefore(period.startsAt)) continue;
    if (!_isReadingActivityStatus(history.status)) continue;
    final existing = touched[history.bookEntryId];
    if (existing == null || history.changedAt.isBefore(existing)) {
      touched[history.bookEntryId] = history.changedAt;
    }
    switch (history.status) {
      case BookStatus.reading:
        startedEntries.add(history.bookEntryId);
      case BookStatus.abandoned:
        abandonedEntries.add(history.bookEntryId);
    }
  }
  for (final page in data.pageActivity) {
    if (page.pages <= 0 ||
        page.occurredAt.isBefore(period.startsAt) ||
        !page.occurredAt.isBefore(period.endsAt)) {
      continue;
    }
    if (!books.containsKey(page.bookEntryId)) continue;
    final existing = touched[page.bookEntryId];
    if (existing == null || page.occurredAt.isBefore(existing)) {
      touched[page.bookEntryId] = page.occurredAt;
    }
  }
  var ongoing = 0;
  for (final id in touched.keys) {
    var status = books[id]!.status;
    final moment = statusAtEnd[id];
    if (moment != null) status = moment.status;
    if (status == BookStatus.reading) ongoing++;
  }
  return _TouchedJourney(
    touched: touched,
    started: startedEntries.length,
    abandoned: abandonedEntries.length,
    ongoing: ongoing,
  );
}

bool _isReadingActivityStatus(String status) {
  switch (status) {
    case BookStatus.reading:
    case BookStatus.read:
    case BookStatus.abandoned:
      return true;
    default:
      return false;
  }
}

List<ReadingChapterBook> _storyBooksFromTouched(
  Map<String, DateTime> touched,
  ReadingChapterSourceData data,
) {
  final rows = <_Occurrence>[];
  for (final row in data.books) {
    final at = touched[row.entryId];
    if (at == null) continue;
    rows.add(
      _Occurrence(
        book: row,
        at: at,
        key: readingChapterWorkKey(row, data.groupOverrides),
      ),
    );
  }
  rows.sort((a, b) => a.at.compareTo(b.at));
  return _groupOccurrences(rows);
}

ReadingChapterTotals _buildTotals(
  List<_Occurrence> completed,
  List<ReadingChapterBook> works,
  int started,
  int abandoned,
  int ongoing,
) {
  var knownPages = 0;
  var pageKnownCount = 0;
  for (final item in completed) {
    final pages = item.book.pageCount;
    if (pages != null) {
      knownPages += pages;
      pageKnownCount++;
    }
  }
  return ReadingChapterTotals(
    uniqueWorks: works.length,
    readingOccurrences: completed.length,
    started: started,
    abandoned: abandoned,
    ongoing: ongoing,
    knownPages: knownPages,
    pageKnownCount: pageKnownCount,
    pageTotalCount: completed.length,
  );
}

List<ReadingChapterRhythmPoint> _buildRhythm(
  ReadingChapterSourceData data,
  ReadingChapterComputePeriod period,
  List<_Occurrence> completed,
) {
  initializeAppTimeZones();
  final loc = tz.timeZoneDatabase.locations[period.timezone] ?? tz.UTC;
  final byKey = <String, ReadingChapterRhythmPoint>{};
  final trackedBooks = <String>{};
  for (final page in data.pageActivity) {
    if (page.pages > 0) trackedBooks.add(page.bookEntryId);
  }
  var hasMetric = false;
  for (final item in completed) {
    final key = _rhythmKey(
      period,
      tz.TZDateTime.from(item.at.toUtc(), loc),
    );
    final point =
        byKey[key] ?? ReadingChapterRhythmPoint(key: key, count: 0, pages: 0);
    var pages = point.pages;
    if (!trackedBooks.contains(item.book.entryId) &&
        item.book.pageCount != null) {
      pages += item.book.pageCount!;
    }
    byKey[key] = ReadingChapterRhythmPoint(
      key: key,
      count: point.count + 1,
      pages: pages,
    );
    hasMetric = true;
  }
  for (final page in data.pageActivity) {
    if (page.pages <= 0 ||
        page.occurredAt.isBefore(period.startsAt) ||
        !page.occurredAt.isBefore(period.endsAt)) {
      continue;
    }
    final key = _rhythmKey(
      period,
      tz.TZDateTime.from(page.occurredAt.toUtc(), loc),
    );
    final point =
        byKey[key] ?? ReadingChapterRhythmPoint(key: key, count: 0, pages: 0);
    byKey[key] = ReadingChapterRhythmPoint(
      key: key,
      count: point.count,
      pages: point.pages + page.pages,
    );
    hasMetric = true;
  }
  if (!hasMetric) return const [];
  if (period.kind == ReadingChapterKind.year) {
    final start = tz.TZDateTime.from(period.startsAt.toUtc(), loc);
    for (var month = 0; month < 12; month++) {
      final cursor = tz.TZDateTime(loc, start.year, start.month + month, 1);
      final key =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}';
      byKey.putIfAbsent(
        key,
        () => ReadingChapterRhythmPoint(key: key, count: 0, pages: 0),
      );
    }
  } else {
    final lastDay = tz.TZDateTime.from(
      period.endsAt.toUtc(),
      loc,
    ).subtract(const Duration(microseconds: 1)).day;
    final weeks = (lastDay + 6) ~/ 7;
    for (var week = 1; week <= weeks; week++) {
      final key = 'week-$week';
      byKey.putIfAbsent(
        key,
        () => ReadingChapterRhythmPoint(key: key, count: 0, pages: 0),
      );
    }
  }
  final keys = byKey.keys.toList()..sort();
  return [for (final key in keys) byKey[key]!];
}

String _rhythmKey(ReadingChapterComputePeriod period, tz.TZDateTime local) {
  if (period.kind == ReadingChapterKind.month) {
    return 'week-${((local.day - 1) ~/ 7) + 1}';
  }
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}';
}

ReadingChapterComparison? _buildComparison(
  ReadingChapterComputePeriod period,
  List<_Occurrence> current,
  List<_Occurrence> previous,
) {
  if (previous.isEmpty || current.isEmpty) return null;
  var knownPages = 0;
  var previousKnownPages = 0;
  for (final item in current) {
    if (item.book.pageCount != null) knownPages += item.book.pageCount!;
  }
  for (final item in previous) {
    if (item.book.pageCount != null) {
      previousKnownPages += item.book.pageCount!;
    }
  }
  return ReadingChapterComparison(
    previousPeriodKey: previousReadingChapterPeriod(period).key,
    uniqueWorks: _groupOccurrences(current).length,
    previousUniqueWorks: _groupOccurrences(previous).length,
    knownPages: knownPages,
    previousKnownPages: previousKnownPages,
  );
}

List<ReadingChapterCount> _buildFormats(List<_Occurrence> completed) {
  final counts = <String, int>{};
  for (final item in completed) {
    if (item.book.format.isNotEmpty) {
      counts[item.book.format] = (counts[item.book.format] ?? 0) + 1;
    }
  }
  return _sortedCounts(counts);
}

({ReadingChapterTaste? taste, ReadingChapterRatings? ratings})
_buildTasteAndRatings(List<ReadingChapterBook> works) {
  final genres = <String, int>{};
  final authors = <String, int>{};
  final ratingBuckets = <String, int>{};
  var ratingTotal = 0.0;
  var rated = 0;
  for (final work in works) {
    final codes = work.categoryCodes.isNotEmpty
        ? work.categoryCodes
        : work.categories;
    final seenGenres = <String>{};
    for (final genre in codes) {
      final key = genre.trim();
      if (key.isEmpty || !seenGenres.add(key)) continue;
      genres[key] = (genres[key] ?? 0) + 1;
    }
    if (work.primaryAuthor.isNotEmpty) {
      authors[work.primaryAuthor] = (authors[work.primaryAuthor] ?? 0) + 1;
    }
    final rating = work.rating;
    if (rating != null) {
      rated++;
      ratingTotal += rating;
      var bucket = rating.ceil();
      if (bucket < 1) bucket = 1;
      if (bucket > 5) bucket = 5;
      ratingBuckets['$bucket'] = (ratingBuckets['$bucket'] ?? 0) + 1;
    }
  }
  ReadingChapterTaste? taste;
  if (genres.isNotEmpty || authors.isNotEmpty) {
    taste = ReadingChapterTaste(
      genres: _sortedCounts(genres),
      authors: _sortedCounts(authors),
    );
  }
  ReadingChapterRatings? ratings;
  if (rated > 0) {
    ratings = ReadingChapterRatings(
      ratedCount: rated,
      average: ratingTotal / rated,
      distribution: _sortedCounts(ratingBuckets),
    );
  }
  return (taste: taste, ratings: ratings);
}

List<ReadingChapterCount> _sortedCounts(Map<String, int> values) {
  final out = [
    for (final entry in values.entries)
      ReadingChapterCount(key: entry.key, count: entry.value),
  ];
  out.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) return byCount;
    return a.key.compareTo(b.key);
  });
  return out;
}

ReadingChapterArchetype? _buildArchetype(
  ReadingChapterSourceData data,
  ReadingChapterComputePeriod period,
  List<_Occurrence> completed,
  List<ReadingChapterBook> works,
) {
  if (period.kind != ReadingChapterKind.year || works.length < 3) return null;
  var genreWorks = 0;
  final genreWeights = <String, double>{};
  for (final work in works) {
    final genres = work.categoryCodes.isNotEmpty
        ? work.categoryCodes
        : work.categories;
    final clean = <String>[];
    final seen = <String>{};
    for (final genre in genres) {
      final key = genre.trim();
      if (key.isEmpty || !seen.add(key)) continue;
      clean.add(key);
    }
    if (clean.isEmpty) continue;
    genreWorks++;
    final weight = 1 / clean.length;
    for (final genre in clean) {
      genreWeights[genre] = (genreWeights[genre] ?? 0) + weight;
    }
  }
  final coverage = genreWorks / works.length;
  if (coverage < 0.8) return null;
  final weighted =
      [
        for (final entry in genreWeights.entries)
          (key: entry.key, value: entry.value),
      ]..sort((a, b) {
        final byValue = b.value.compareTo(a.value);
        if (byValue != 0) return byValue;
        return a.key.compareTo(b.key);
      });
  final top = weighted.first.value / genreWorks;
  final topTwo = weighted.length > 1
      ? top + weighted[1].value / genreWorks
      : top;
  final breadth = (top >= 0.5 || topTwo >= 0.75) ? 'anchored' : 'wide';

  initializeAppTimeZones();
  final loc = tz.timeZoneDatabase.locations[period.timezone] ?? tz.UTC;
  final activeMonths = <String>{};
  for (final item in completed) {
    final local = tz.TZDateTime.from(item.at.toUtc(), loc);
    activeMonths.add(
      '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}',
    );
  }
  for (final page in data.pageActivity) {
    if (!page.occurredAt.isBefore(period.startsAt) &&
        page.occurredAt.isBefore(period.endsAt) &&
        page.pages > 0) {
      final local = tz.TZDateTime.from(page.occurredAt.toUtc(), loc);
      activeMonths.add(
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}',
      );
    }
  }
  if (activeMonths.isEmpty) return null;
  final steady =
      activeMonths.length >= 8 && _maxInactiveGap(activeMonths, period) <= 2;
  final cadence = steady ? 'steady' : 'tidal';

  final priorWorks = <String>{};
  final priorAuthors = <String>{};
  final booksById = {for (final row in data.books) row.entryId: row};
  for (final history in data.history) {
    if (history.status != BookStatus.read ||
        !history.dateConfirmed ||
        !history.changedAt.isBefore(period.startsAt)) {
      continue;
    }
    final row = booksById[history.bookEntryId];
    if (row == null) continue;
    priorWorks.add(readingChapterWorkKey(row, data.groupOverrides));
    if (row.authors.isNotEmpty) {
      priorAuthors.add(normalizeReadingChapterIdentity(row.authors.first));
    }
  }
  if (priorWorks.length < 3) return null;
  var newBoth = 0;
  for (final work in works) {
    final seenWork = priorWorks.contains(work.workKey);
    final seenAuthor = priorAuthors.contains(
      normalizeReadingChapterIdentity(work.primaryAuthor),
    );
    if (!seenWork && !seenAuthor) newBoth++;
  }
  final novelShare = newBoth / works.length;
  final novelty = novelShare >= 0.6 ? 'explore' : 'return';
  final scale = _scaleAxis(works);
  return ReadingChapterArchetype(
    name: _archetypeName(breadth, cadence, novelty, scale),
    breadthAxis: breadth,
    cadenceAxis: cadence,
    noveltyAxis: novelty,
    scaleAxis: scale,
    genreCoverage: coverage,
    novelWorkShare: novelShare,
    evidenceGenres: [
      for (final item in weighted)
        ReadingChapterCount(key: item.key, count: (item.value * 100).round()),
    ],
    evidenceAuthors: _buildTasteAndRatings(works).taste?.authors ?? const [],
  );
}

int _maxInactiveGap(Set<String> active, ReadingChapterComputePeriod period) {
  initializeAppTimeZones();
  final loc = tz.timeZoneDatabase.locations[period.timezone] ?? tz.UTC;
  var month = tz.TZDateTime.from(period.startsAt.toUtc(), loc);
  final end = tz.TZDateTime.from(period.endsAt.toUtc(), loc);
  var gap = 0;
  var longest = 0;
  while (month.isBefore(end)) {
    final key =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
    if (active.contains(key)) {
      gap = 0;
    } else {
      gap++;
      if (gap > longest) longest = gap;
    }
    month = tz.TZDateTime(loc, month.year, month.month + 1, 1);
  }
  return longest;
}

String _scaleAxis(List<ReadingChapterBook> works) {
  final pages = [
    for (final work in works)
      if (work.pageCount != null && work.pageCount! > 0) work.pageCount!,
  ]..sort();
  if (pages.length < 2) return 'swift';
  final mid = pages.length ~/ 2;
  final median = pages.length.isEven
      ? (pages[mid - 1] + pages[mid]) ~/ 2
      : pages[mid];
  return median >= 350 ? 'tome' : 'swift';
}

String _archetypeName(
  String breadth,
  String cadence,
  String novelty,
  String scale,
) {
  final key = '$breadth|$cadence|$novelty';
  if (scale == 'tome') {
    return switch (key) {
      'anchored|steady|return' => 'vault',
      'anchored|steady|explore' => 'scholar',
      'anchored|tidal|return' => 'oak',
      'anchored|tidal|explore' => 'forge',
      'wide|steady|return' => 'beacon',
      'wide|steady|explore' => 'atlas',
      'wide|tidal|return' => 'nebula',
      'wide|tidal|explore' => 'leviathan',
      _ => '',
    };
  }
  return switch (key) {
    'anchored|steady|return' => 'keeper',
    'anchored|steady|explore' => 'curator',
    'anchored|tidal|return' => 'hearth',
    'anchored|tidal|explore' => 'spark',
    'wide|steady|return' => 'beacon',
    'wide|steady|explore' => 'cartographer',
    'wide|tidal|return' => 'constellation',
    'wide|tidal|explore' => 'comet',
    _ => '',
  };
}

List<ReadingChapterReadinessIssue> _buildReadiness(
  ReadingChapterSourceData data,
  ReadingChapterComputePeriod period,
  Map<String, DateTime> touched,
  Map<String, ReadingChapterSourceBook> booksById,
) {
  final issues = <ReadingChapterReadinessIssue>[];
  for (final history in data.history) {
    if (history.status == BookStatus.read &&
        !history.dateConfirmed &&
        !history.changedAt.isBefore(period.startsAt) &&
        history.changedAt.isBefore(period.endsAt)) {
      issues.add(
        ReadingChapterReadinessIssue(
          kind: readingChapterReadinessUnconfirmedDate,
          bookEntryId: history.bookEntryId,
          count: 1,
        ),
      );
    }
  }
  for (final id in touched.keys) {
    final row = booksById[id];
    if (row == null) continue;
    if (row.pageCount == null) {
      issues.add(
        ReadingChapterReadinessIssue(
          kind: readingChapterReadinessMissingPages,
          bookEntryId: id,
          count: 1,
        ),
      );
    }
    if (row.format.isEmpty) {
      issues.add(
        ReadingChapterReadinessIssue(
          kind: readingChapterReadinessMissingFormat,
          bookEntryId: id,
          count: 1,
        ),
      );
    }
    if (row.categoryCodes.isEmpty && row.categories.isEmpty) {
      issues.add(
        ReadingChapterReadinessIssue(
          kind: readingChapterReadinessMissingGenres,
          bookEntryId: id,
          count: 1,
        ),
      );
    }
    if (row.coverUrl.trim().isEmpty) {
      issues.add(
        ReadingChapterReadinessIssue(
          kind: readingChapterReadinessMissingCover,
          bookEntryId: id,
          count: 1,
        ),
      );
    }
  }
  issues.addAll(_groupingReadiness(touched, data, booksById));
  for (final reflection in period.curation) {
    if (!touched.containsKey(reflection.bookEntryId) ||
        reflection.excerpt.runes.length > 300) {
      issues.add(
        ReadingChapterReadinessIssue(
          kind: readingChapterReadinessInvalidPick,
          bookEntryId: reflection.bookEntryId,
          count: 1,
        ),
      );
    }
  }
  return issues;
}

List<ReadingChapterReadinessIssue> _groupingReadiness(
  Map<String, DateTime> touched,
  ReadingChapterSourceData data,
  Map<String, ReadingChapterSourceBook> booksById,
) {
  final bySig = <String, _GroupSig>{};
  for (final id in touched.keys) {
    final row = booksById[id];
    if (row == null) continue;
    final author = row.authors.isNotEmpty ? row.authors.first : '';
    final sig =
        '${normalizeReadingChapterIdentity(row.title)}|${normalizeReadingChapterIdentity(author)}';
    if (sig == '|') continue;
    final group = bySig.putIfAbsent(sig, () => _GroupSig(first: id));
    group.keys.add(readingChapterWorkKey(row, data.groupOverrides));
    group.count++;
  }
  return [
    for (final group in bySig.values)
      if (group.keys.length > 1)
        ReadingChapterReadinessIssue(
          kind: readingChapterReadinessReviewGrouping,
          bookEntryId: group.first,
          count: group.count,
        ),
  ];
}

class _GroupSig {
  _GroupSig({required this.first});
  final String first;
  final Set<String> keys = {};
  int count = 0;
}

class _ArchiveBucket {
  final Map<String, DateTime> touched = {};
  final List<_Occurrence> completed = [];
}

List<ReadingChapterBook> _capStoryBooks(List<ReadingChapterBook> books) {
  if (books.length <= readingChapterMaxBooksPerCard) return List.of(books);
  return books.sublist(0, readingChapterMaxBooksPerCard);
}

List<ReadingChapterBook> _summaryBooks(
  List<ReadingChapterBook> completed,
  List<ReadingChapterBook> touched,
) {
  final source = completed.isNotEmpty ? completed : touched;
  if (source.length > 6) return source.sublist(0, 6);
  return List.of(source);
}

ReadingChapterCard _card({
  required String id,
  required String kind,
  List<ReadingChapterBook> books = const [],
  List<ReadingChapterRhythmPoint> rhythm = const [],
  List<ReadingChapterCount> formats = const [],
  ReadingChapterTotals? totals,
  ReadingChapterComparison? comparison,
  ReadingChapterJourney? journey,
  ReadingChapterTaste? taste,
  ReadingChapterRatings? ratings,
  ReadingChapterArchetype? archetype,
  ReadingChapterReflection? reflection,
}) => ReadingChapterCard(
  id: id,
  kind: kind,
  books: books,
  rhythm: rhythm,
  formats: formats,
  totals: totals,
  comparison: comparison,
  journey: journey,
  taste: taste,
  ratings: ratings,
  archetype: archetype,
  reflection: reflection,
);

String _isbnDigitsAndX(String raw) {
  final b = StringBuffer();
  for (final u in raw.codeUnits) {
    if (u >= 0x30 && u <= 0x39) {
      b.writeCharCode(u);
    } else if (u == 0x58 || u == 0x78) {
      b.write('X');
    }
  }
  return b.toString();
}

String _isbn10To13(String isbn10) {
  if (isbn10.length != 10) return '';
  final core = '978${isbn10.substring(0, 9)}';
  var sum = 0;
  for (var i = 0; i < core.length; i++) {
    final d = core.codeUnitAt(i) - 0x30;
    if (d < 0 || d > 9) return '';
    sum += i.isEven ? d : 3 * d;
  }
  final check = (10 - (sum % 10)) % 10;
  return '$core$check';
}
