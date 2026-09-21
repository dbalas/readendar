import 'dart:convert';

import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/data/local/reading_chapter_compute.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

/// On-device Reading Chapter. Compute is local.
class LocalReadingChapterRepository implements ReadingChapterRepository {
  LocalReadingChapterRepository(
    this._store,
    PrefsStorage prefs, {
    DateTime Function()? now,
  }) : _chapterPrefs = prefs,
       _now = now ?? (() => DateTime.now().toUtc());

  final LocalStore _store;
  final PrefsStorage _chapterPrefs;
  final DateTime Function() _now;
  static const _uuid = Uuid();

  @override
  void dispose() {}

  @override
  ReadingChapterStory? cachedStory(ReadingChapterRequest request) => null;

  @override
  ReadingChapterArchive? cachedArchive({String kind = 'all'}) => null;

  @override
  ReadingChapterArchive? cachedLatest() => null;

  @override
  Future<Result<ReadingChapterStory>> fetchStory(
    ReadingChapterRequest request,
  ) => _guard(() async {
    final source = await _loadSource();
    final stored = await _storedPeriod(request.kind, request.periodKey);
    final period = buildReadingChapterPeriod(
      kind: request.kind,
      key: request.periodKey,
      timezone: source.readerTimezone,
      now: _now(),
      curation: stored?.curation ?? const [],
      curationRevision: stored?.curationRevision ?? 0,
    );
    return computeReadingChapter(_filterUntil(source, period.endsAt), period);
  });

  @override
  Future<Result<ReadingChapterArchive>> fetchArchive({
    String kind = 'all',
    String after = '',
    int limit = 20,
  }) => _guard(() async {
    final source = await _loadSource();
    return _archiveFromSource(
      source,
      filter: kind,
      cursor: after,
      limit: limit,
    );
  });

  @override
  Future<Result<ReadingChapterArchive>> fetchLatest() => _guard(() async {
    final source = await _loadSource();
    initializeAppTimeZones();
    final loc = tz.timeZoneDatabase.locations[source.readerTimezone] ?? tz.UTC;
    final now = tz.TZDateTime.from(_now().toUtc(), loc);
    final lastMonth = tz.TZDateTime(loc, now.year, now.month - 1, 1);
    final keys = [
      ReadingChapterComputePeriod(
        kind: ReadingChapterKind.month,
        key:
            '${lastMonth.year.toString().padLeft(4, '0')}-${lastMonth.month.toString().padLeft(2, '0')}',
        timezone: source.readerTimezone,
        startsAt: lastMonth.toUtc(),
        endsAt: tz.TZDateTime(loc, now.year, now.month, 1).toUtc(),
      ),
    ];
    if (now.month == 1) {
      keys.add(
        ReadingChapterComputePeriod(
          kind: ReadingChapterKind.year,
          key: (now.year - 1).toString().padLeft(4, '0'),
          timezone: source.readerTimezone,
          startsAt: tz.TZDateTime(loc, now.year - 1, 1, 1).toUtc(),
          endsAt: tz.TZDateTime(loc, now.year, 1, 1).toUtc(),
        ),
      );
    }
    return _archiveFromSource(
      source,
      filter: 'all',
      cursor: '',
      limit: keys.length,
      periods: keys,
    );
  });

  @override
  Future<Result<void>> markViewed(ReadingChapterRequest request) =>
      _guard(() async {
        final stored = await _storedPeriod(request.kind, request.periodKey);
        final source = await _loadSource();
        final period = buildReadingChapterPeriod(
          kind: request.kind,
          key: request.periodKey,
          timezone: source.readerTimezone,
          now: _now(),
          curation: stored?.curation ?? const [],
          curationRevision: stored?.curationRevision ?? 0,
        );
        await _putPeriod(
          period,
          seenAt: _now(),
          curation: period.curation,
          curationRevision: period.curationRevision,
        );
      });

  @override
  Future<Result<bool>> notificationPreference() => _guard(() async {
    final row = await _store.get(
      LocalCollections.notificationPreferences,
      'reading_chapters',
    );
    return row?['enabled'] as bool? ?? true;
  });

  @override
  Future<Result<bool>> saveNotificationPreference(bool enabled) =>
      _guard(() async {
        await _store.put(
          LocalCollections.notificationPreferences,
          'reading_chapters',
          {'id': 'reading_chapters', 'enabled': enabled},
        );
        return enabled;
      });

  @override
  Future<Result<ReadingChapterStory>> saveCuration(
    ReadingChapterRequest request, {
    required String expectedSourceRevision,
    required List<ReadingChapterReflection> reflections,
    required Set<String> safeToRevealPrompts,
  }) => _guard(() async {
    final normalized = [
      for (final reflection in reflections)
        ReadingChapterReflection(
          prompt: reflection.prompt,
          bookEntryId: reflection.bookEntryId,
          excerpt: reflection.excerpt.trim(),
          attribution: reflection.attribution.trim(),
          spoiler:
              reflection.excerpt.trim().isNotEmpty ||
                  reflection.attribution.trim().isNotEmpty
              ? reflection.spoiler
              : false,
        ),
    ];
    final invalid = validateReadingChapterCuration(
      kind: request.kind,
      reflections: normalized,
    );
    if (invalid.isNotEmpty) throw _FailureThrow(ValidationFailure(invalid));
    final storyResult = await fetchStory(request);
    final story = storyResult.value;
    if (story == null) {
      throw _FailureThrow(storyResult.failure ?? const UnknownFailure());
    }
    if (story.sourceRevision != expectedSourceRevision) {
      throw _FailureThrow(
        const ConflictFailure('reading_chapter_source_changed'),
      );
    }
    final validEntries = {for (final book in story.books) book.entryId};
    for (final reflection in normalized) {
      if (!validEntries.contains(reflection.bookEntryId)) {
        throw _FailureThrow(
          const ValidationFailure('reading_chapter_book_not_in_period'),
        );
      }
    }
    final stored = await _storedPeriod(request.kind, request.periodKey);
    final source = await _loadSource();
    final period = buildReadingChapterPeriod(
      kind: request.kind,
      key: request.periodKey,
      timezone: source.readerTimezone,
      now: _now(),
      curation: normalized,
      curationRevision: (stored?.curationRevision ?? 0) + 1,
    );
    await _putPeriod(
      period,
      seenAt: stored?.seenAt,
      curation: normalized,
      curationRevision: period.curationRevision,
    );
    return computeReadingChapter(_filterUntil(source, period.endsAt), period);
  });

  @override
  Future<Result<void>> saveGrouping({
    required String mode,
    required List<String> entryIds,
  }) => _guard(() async {
    final groupId = _uuid.v4();
    for (final id in entryIds) {
      await _store.put(LocalCollections.workGroupOverrides, id, {
        'bookEntryId': id,
        'groupId': groupId,
        'mode': mode,
      });
    }
  });

  @override
  Future<Result<void>> resetGrouping(List<String> entryIds) => _guard(() async {
    for (final id in entryIds) {
      await _store.delete(LocalCollections.workGroupOverrides, id);
    }
  });

  Future<_LoadedSource> _loadSource() async {
    final bookRows = await _store.list(LocalCollections.books);
    final books = <ReadingChapterSourceBook>[];
    for (final row in bookRows) {
      try {
        books.add(_sourceBook(Book.fromJson(row)));
      } on Object {
        continue;
      }
    }
    final history = <ReadingChapterHistoryRow>[];
    final seenBooks = <String>{};
    for (final row in await _store.list(LocalCollections.bookStatusHistory)) {
      final parsed = _historyRow(row);
      if (parsed == null) continue;
      history.add(parsed);
      seenBooks.add(parsed.bookEntryId);
    }
    for (final book in books) {
      if (seenBooks.contains(book.entryId)) continue;
      final changedAt = _bookStatusChangedAt(bookRows, book.entryId);
      if (changedAt == null) continue;
      history.add(
        ReadingChapterHistoryRow(
          bookEntryId: book.entryId,
          status: book.status,
          changedAt: changedAt,
          dateConfirmed: true,
        ),
      );
    }
    final pages = <ReadingChapterPageActivityRow>[];
    for (final row in await _store.list(LocalCollections.pageActivity)) {
      final parsed = _pageRow(row);
      if (parsed != null) pages.add(parsed);
    }
    final overrides = <String, String>{};
    for (final row in await _store.list(LocalCollections.workGroupOverrides)) {
      final id = row['bookEntryId'] as String? ?? row['id'] as String? ?? '';
      final groupId = row['groupId'] as String? ?? '';
      if (id.isNotEmpty && groupId.isNotEmpty) overrides[id] = groupId;
    }
    final profile = await _localProfile();
    return _LoadedSource(
      data: ReadingChapterSourceData(
        reader: ReadingChapterReader(
          displayName: profile.displayName,
          locale: profile.locale,
        ),
        revision: books.length + history.length,
        books: books,
        history: history,
        pageActivity: pages,
        groupOverrides: overrides,
      ),
      readerTimezone: profile.timezone,
    );
  }

  ReadingChapterSourceData _filterUntil(
    _LoadedSource source,
    DateTime until,
  ) => ReadingChapterSourceData(
    reader: source.data.reader,
    revision: source.data.revision,
    books: source.data.books,
    history: [
      for (final row in source.data.history)
        if (row.changedAt.isBefore(until)) row,
    ],
    pageActivity: [
      for (final row in source.data.pageActivity)
        if (row.occurredAt.isBefore(until)) row,
    ],
    groupOverrides: source.data.groupOverrides,
  );

  Future<ReadingChapterArchive> _archiveFromSource(
    _LoadedSource source, {
    required String filter,
    required String cursor,
    required int limit,
    List<ReadingChapterComputePeriod>? periods,
  }) async {
    var pageLimit = limit;
    if (pageLimit <= 0) pageLimit = 20;
    if (pageLimit > 50) pageLimit = 50;
    final earliest = earliestReadingChapterActivity(source.data);
    if (earliest == null && periods == null) {
      return const ReadingChapterArchive(
        items: [],
        nextCursor: '',
        hasUnread: false,
        capabilities: localReadingChapterCapabilities,
      );
    }
    initializeAppTimeZones();
    final loc = tz.timeZoneDatabase.locations[source.readerTimezone] ?? tz.UTC;
    final nowLocal = tz.TZDateTime.from(_now().toUtc(), loc);
    final earliestLocal = tz.TZDateTime.from(
      (earliest ?? nowLocal).toUtc(),
      loc,
    );
    var candidates =
        periods ??
        candidateReadingChapterPeriods(
          earliestLocal: earliestLocal,
          nowLocal: nowLocal,
          filter: filter,
          timezone: source.readerTimezone,
        );
    if (cursor.isNotEmpty) {
      final index = candidates.indexWhere(
        (period) => periodCursor(period) == cursor,
      );
      if (index >= 0) {
        candidates = candidates.sublist(index + 1);
      }
    }
    final projections = projectAllReadingChapterArchiveItems(
      source.data,
      source.readerTimezone,
    );
    final items = <ReadingChapterArchiveItem>[];
    var hasUnread = false;
    var nextCursor = '';
    for (final candidate in candidates) {
      final projection =
          projections[archivePeriodKey(candidate.kind, candidate.key)];
      if (projection == null || !projection.meaningful) continue;
      late final ReadingChapterComputePeriod period;
      try {
        period = buildReadingChapterPeriod(
          kind: candidate.kind,
          key: candidate.key,
          timezone: source.readerTimezone,
          now: _now(),
        );
      } on ReadingChapterPeriodException {
        continue;
      }
      if (items.length == pageLimit) {
        nextCursor = periodCursor(
          ReadingChapterComputePeriod(
            kind: items.last.kind,
            key: items.last.periodKey,
            timezone: items.last.timezone,
            startsAt: items.last.startsAt,
            endsAt: items.last.endsAt,
          ),
        );
        break;
      }
      final stored = await _storedPeriod(period.kind, period.key);
      final seen = stored?.seenAt != null;
      if (!seen) hasUnread = true;
      items.add(
        ReadingChapterArchiveItem(
          kind: period.kind,
          periodKey: period.key,
          timezone: period.timezone,
          startsAt: period.startsAt,
          endsAt: period.endsAt,
          seen: seen,
          meaningful: true,
          uniqueWorks: projection.uniqueWorks,
          coverUrls: projection.coverUrls,
        ),
      );
    }
    return ReadingChapterArchive(
      items: items,
      nextCursor: nextCursor,
      hasUnread: hasUnread,
      capabilities: localReadingChapterCapabilities,
    );
  }

  Future<_StoredPeriod?> _storedPeriod(
    ReadingChapterKind kind,
    String key,
  ) async {
    final composite = archivePeriodKey(kind, key);
    Map<String, dynamic>? row;
    for (final item in await _store.list(LocalCollections.readingChapters)) {
      final itemKind = item['kind'] as String? ?? '';
      final itemKey = item['key'] as String? ?? '';
      final id = item['id'] as String? ?? '';
      if ((itemKind == kind.wire && itemKey == key) ||
          id == composite ||
          id == key) {
        row = item;
        break;
      }
    }
    if (row == null) return null;
    return _StoredPeriod(
      curation: _curationFrom(row['curation']),
      curationRevision: (row['curationRevision'] as num?)?.toInt() ?? 0,
      seenAt: DateTime.tryParse(row['seenAt'] as String? ?? ''),
    );
  }

  Future<void> _putPeriod(
    ReadingChapterComputePeriod period, {
    required List<ReadingChapterReflection> curation,
    required int curationRevision,
    DateTime? seenAt,
  }) async {
    await _store.put(
      LocalCollections.readingChapters,
      archivePeriodKey(period.kind, period.key),
      {
        'id': archivePeriodKey(period.kind, period.key),
        'kind': period.kind.wire,
        'key': period.key,
        'timezone': period.timezone,
        'startsAt': period.startsAt.toUtc().toIso8601String(),
        'endsAt': period.endsAt.toUtc().toIso8601String(),
        'seenAt': seenAt?.toUtc().toIso8601String(),
        'curationRevision': curationRevision,
        'curation': {
          'reflections': [
            for (final reflection in curation)
              {
                'prompt': reflection.prompt,
                'bookEntryId': reflection.bookEntryId,
                'excerpt': reflection.excerpt,
                'attribution': reflection.attribution,
                'spoiler': reflection.spoiler,
              },
          ],
        },
      },
    );
  }

  Future<_LocalProfile> _localProfile() async {
    const fallback = _LocalProfile(
      displayName: '',
      locale: 'es',
      timezone: 'Europe/Madrid',
    );
    final stored = _profileFromMap(
      await _store.get(LocalCollections.profile, 'me'),
    );
    if (stored != null) return stored;
    final raw = _chapterPrefs.getLocalProfileJson();
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return fallback;
      return _profileFromMap(Map<String, dynamic>.from(map)) ?? fallback;
    } on Object {
      return fallback;
    }
  }
}

_LocalProfile? _profileFromMap(Map<String, dynamic>? map) {
  if (map == null) return null;
  final timezone = map['timezone'] as String? ?? '';
  final locale =
      (map['preferredLocale'] as String?) ?? (map['locale'] as String?) ?? '';
  return _LocalProfile(
    displayName: map['displayName'] as String? ?? '',
    locale: locale.isNotEmpty ? locale : 'es',
    timezone: timezone.isNotEmpty ? timezone : 'Europe/Madrid',
  );
}

List<ReadingChapterReflection> _curationFrom(Object? raw) {
  final list = raw is List
      ? raw
      : raw is Map
      ? raw['reflections']
      : null;
  if (list is! List) return const [];
  return [
    for (final item in list)
      if (item is Map<String, dynamic>)
        ReadingChapterReflection.fromJson(item)
      else if (item is Map)
        ReadingChapterReflection.fromJson(Map<String, dynamic>.from(item)),
  ];
}

ReadingChapterSourceBook _sourceBook(Book book) => ReadingChapterSourceBook(
  entryId: book.id,
  title: book.title,
  authors: book.authors,
  coverUrl: book.coverUrl,
  isbn13: book.isbn13,
  isbn10: book.isbn10,
  pageCount: book.pageCount,
  categories: book.categories,
  categoryCodes: book.categoryCodes,
  rating: book.rating,
  format: book.format ?? '',
  status: book.status,
);

ReadingChapterHistoryRow? _historyRow(Map<String, dynamic> row) {
  final bookEntryId =
      row['bookEntryId'] as String? ?? row['bookId'] as String? ?? '';
  final status = row['status'] as String? ?? '';
  final changedAt = DateTime.tryParse(row['changedAt'] as String? ?? '');
  if (bookEntryId.isEmpty || status.isEmpty || changedAt == null) return null;
  return ReadingChapterHistoryRow(
    id: row['id'] as String? ?? '',
    bookEntryId: bookEntryId,
    status: status,
    changedAt: changedAt.toUtc(),
    dateConfirmed: row['dateConfirmed'] as bool? ?? true,
  );
}

ReadingChapterPageActivityRow? _pageRow(Map<String, dynamic> row) {
  final bookEntryId = row['bookEntryId'] as String? ?? '';
  final pages = (row['pages'] as num?)?.toInt() ?? 0;
  final occurredAt = DateTime.tryParse(row['occurredAt'] as String? ?? '');
  if (bookEntryId.isEmpty || occurredAt == null) return null;
  return ReadingChapterPageActivityRow(
    bookEntryId: bookEntryId,
    pages: pages,
    occurredAt: occurredAt.toUtc(),
  );
}

DateTime? _bookStatusChangedAt(
  List<Map<String, dynamic>> bookRows,
  String id,
) {
  for (final row in bookRows) {
    if (row['id'] != id) continue;
    return DateTime.tryParse(row['statusChangedAt'] as String? ?? '');
  }
  return null;
}

Future<Result<T>> _guard<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on ReadingChapterPeriodException catch (error) {
    return Err(ValidationFailure(error.code));
  } on _FailureThrow catch (error) {
    return Err(error.failure);
  } on Object catch (error) {
    return Err(UnknownFailure(error.toString()));
  }
}

class _FailureThrow implements Exception {
  const _FailureThrow(this.failure);
  final Failure failure;
}

class _LoadedSource {
  const _LoadedSource({required this.data, required this.readerTimezone});
  final ReadingChapterSourceData data;
  final String readerTimezone;
}

class _StoredPeriod {
  const _StoredPeriod({
    required this.curation,
    required this.curationRevision,
    this.seenAt,
  });
  final List<ReadingChapterReflection> curation;
  final int curationRevision;
  final DateTime? seenAt;
}

class _LocalProfile {
  const _LocalProfile({
    required this.displayName,
    required this.locale,
    required this.timezone,
  });
  final String displayName;
  final String locale;
  final String timezone;
}
