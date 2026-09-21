import 'package:flutter/foundation.dart';

enum ReadingChapterKind {
  month('month'),
  year('year');

  const ReadingChapterKind(this.wire);
  final String wire;

  static ReadingChapterKind fromWire(String value) => switch (value) {
    'year' => ReadingChapterKind.year,
    _ => ReadingChapterKind.month,
  };
}

@immutable
class ReadingChapterRequest {
  const ReadingChapterRequest(this.kind, this.periodKey);

  final ReadingChapterKind kind;
  final String periodKey;

  @override
  bool operator ==(Object other) =>
      other is ReadingChapterRequest &&
      other.kind == kind &&
      other.periodKey == periodKey;

  @override
  int get hashCode => Object.hash(kind, periodKey);
}

@immutable
class ReadingChapterPeriod {
  const ReadingChapterPeriod({
    required this.kind,
    required this.key,
    required this.timezone,
    required this.startsAt,
    required this.endsAt,
    this.seenAt,
  });

  factory ReadingChapterPeriod.fromJson(Map<String, dynamic> json) =>
      ReadingChapterPeriod(
        kind: ReadingChapterKind.fromWire(json['kind'] as String? ?? ''),
        key: json['key'] as String? ?? '',
        timezone: json['timezone'] as String? ?? 'UTC',
        startsAt:
            _date(json['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        endsAt: _date(json['endsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        seenAt: _date(json['seenAt']),
      );

  final ReadingChapterKind kind;
  final String key;
  final String timezone;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? seenAt;
}

@immutable
class ReadingChapterReader {
  const ReadingChapterReader({
    required this.displayName,
    required this.locale,
  });

  factory ReadingChapterReader.fromJson(Map<String, dynamic> json) =>
      ReadingChapterReader(
        displayName: json['displayName'] as String? ?? '',
        locale: json['locale'] as String? ?? '',
      );

  final String displayName;
  final String locale;
}

@immutable
class ReadingChapterCount {
  const ReadingChapterCount({required this.key, required this.count});

  factory ReadingChapterCount.fromJson(Map<String, dynamic> json) =>
      ReadingChapterCount(
        key: json['key'] as String? ?? '',
        count: _integer(json['count']),
      );

  final String key;
  final int count;
}

@immutable
class ReadingChapterBook {
  const ReadingChapterBook({
    required this.entryId,
    required this.workKey,
    required this.title,
    required this.primaryAuthor,
    required this.coverUrl,
    required this.format,
    required this.categories,
    required this.categoryCodes,
    required this.occurrences,
    this.pageCount,
    this.rating,
    this.firstActivityAt,
  });

  factory ReadingChapterBook.fromJson(Map<String, dynamic> json) =>
      ReadingChapterBook(
        entryId: json['entryId'] as String? ?? json['id'] as String? ?? '',
        workKey: json['workKey'] as String? ?? '',
        title: json['title'] as String? ?? '',
        primaryAuthor: json['primaryAuthor'] as String? ?? '',
        coverUrl: json['coverUrl'] as String? ?? '',
        pageCount: _nullableInteger(json['pageCount']),
        format: json['format'] as String? ?? '',
        categories: _strings(json['categories']),
        categoryCodes: _strings(json['categoryCodes']),
        rating: _nullableDouble(json['rating']),
        firstActivityAt: _date(json['firstActivityAt']),
        occurrences: _integer(json['occurrences']),
      );

  final String entryId;
  final String workKey;
  final String title;
  final String primaryAuthor;
  final String coverUrl;
  final int? pageCount;
  final String format;
  final List<String> categories;
  final List<String> categoryCodes;
  final double? rating;
  final DateTime? firstActivityAt;
  final int occurrences;
}

@immutable
class ReadingChapterTotals {
  const ReadingChapterTotals({
    required this.uniqueWorks,
    required this.readingOccurrences,
    required this.started,
    required this.abandoned,
    required this.ongoing,
    required this.knownPages,
    required this.pageKnownCount,
    required this.pageTotalCount,
  });

  factory ReadingChapterTotals.fromJson(Map<String, dynamic> json) =>
      ReadingChapterTotals(
        uniqueWorks: _integer(json['uniqueWorks']),
        readingOccurrences: _integer(json['readingOccurrences']),
        started: _integer(json['started']),
        abandoned: _integer(json['abandoned']),
        ongoing: _integer(json['ongoing']),
        knownPages: _integer(json['knownPages']),
        pageKnownCount: _integer(json['pageKnownCount']),
        pageTotalCount: _integer(json['pageTotalCount']),
      );

  final int uniqueWorks;
  final int readingOccurrences;
  final int started;
  final int abandoned;
  final int ongoing;
  final int knownPages;
  final int pageKnownCount;
  final int pageTotalCount;

  double get pageCoverage =>
      pageTotalCount == 0 ? 0 : (pageKnownCount / pageTotalCount).clamp(0, 1);
}

@immutable
class ReadingChapterRhythmPoint {
  const ReadingChapterRhythmPoint({
    required this.key,
    required this.count,
    required this.pages,
  });

  factory ReadingChapterRhythmPoint.fromJson(Map<String, dynamic> json) =>
      ReadingChapterRhythmPoint(
        key: json['key'] as String? ?? '',
        count: _integer(json['count']),
        pages: _integer(json['pages']),
      );

  final String key;
  final int count;
  final int pages;
}

@immutable
class ReadingChapterComparison {
  const ReadingChapterComparison({
    required this.previousPeriodKey,
    required this.uniqueWorks,
    required this.previousUniqueWorks,
    required this.knownPages,
    required this.previousKnownPages,
  });

  factory ReadingChapterComparison.fromJson(Map<String, dynamic> json) =>
      ReadingChapterComparison(
        previousPeriodKey: json['previousPeriodKey'] as String? ?? '',
        uniqueWorks: _integer(json['uniqueWorks']),
        previousUniqueWorks: _integer(json['previousUniqueWorks']),
        knownPages: _integer(json['knownPages']),
        previousKnownPages: _integer(json['previousKnownPages']),
      );

  final String previousPeriodKey;
  final int uniqueWorks;
  final int previousUniqueWorks;
  final int knownPages;
  final int previousKnownPages;
}

@immutable
class ReadingChapterJourney {
  const ReadingChapterJourney({
    required this.started,
    required this.abandoned,
    required this.ongoing,
  });

  factory ReadingChapterJourney.fromJson(Map<String, dynamic> json) =>
      ReadingChapterJourney(
        started: _integer(json['started']),
        abandoned: _integer(json['abandoned']),
        ongoing: _integer(json['ongoing']),
      );

  final int started;
  final int abandoned;
  final int ongoing;
}

@immutable
class ReadingChapterTaste {
  const ReadingChapterTaste({required this.genres, required this.authors});

  factory ReadingChapterTaste.fromJson(
    Map<String, dynamic> json,
  ) => ReadingChapterTaste(
    genres: _maps(json['genres']).map(ReadingChapterCount.fromJson).toList(),
    authors: _maps(json['authors']).map(ReadingChapterCount.fromJson).toList(),
  );

  final List<ReadingChapterCount> genres;
  final List<ReadingChapterCount> authors;
}

@immutable
class ReadingChapterRatings {
  const ReadingChapterRatings({
    required this.ratedCount,
    required this.distribution,
    this.average,
  });

  factory ReadingChapterRatings.fromJson(Map<String, dynamic> json) =>
      ReadingChapterRatings(
        ratedCount: _integer(json['ratedCount']),
        average: _nullableDouble(json['average']),
        distribution: _maps(
          json['distribution'],
        ).map(ReadingChapterCount.fromJson).toList(),
      );

  final int ratedCount;
  final double? average;
  final List<ReadingChapterCount> distribution;
}

@immutable
class ReadingChapterArchetype {
  const ReadingChapterArchetype({
    required this.name,
    required this.breadthAxis,
    required this.cadenceAxis,
    required this.noveltyAxis,
    required this.scaleAxis,
    required this.genreCoverage,
    required this.novelWorkShare,
    required this.evidenceGenres,
    required this.evidenceAuthors,
  });

  factory ReadingChapterArchetype.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? '';
    return ReadingChapterArchetype(
      // Legacy published snapshots used lantern (wide|steady|return|swift).
      name: rawName == 'lantern' ? 'beacon' : rawName,
      breadthAxis: json['breadthAxis'] as String? ?? '',
      cadenceAxis: json['cadenceAxis'] as String? ?? '',
      noveltyAxis: json['noveltyAxis'] as String? ?? '',
      scaleAxis: json['scaleAxis'] as String? ?? 'swift',
      genreCoverage: _double(json['genreCoverage']),
      novelWorkShare: _double(json['novelWorkShare']),
      evidenceGenres: _maps(
        json['evidenceGenres'],
      ).map(ReadingChapterCount.fromJson).toList(),
      evidenceAuthors: _maps(
        json['evidenceAuthors'],
      ).map(ReadingChapterCount.fromJson).toList(),
    );
  }

  final String name;
  final String breadthAxis;
  final String cadenceAxis;
  final String noveltyAxis;
  final String scaleAxis;
  final double genreCoverage;
  final double novelWorkShare;
  final List<ReadingChapterCount> evidenceGenres;
  final List<ReadingChapterCount> evidenceAuthors;
}

@immutable
class ReadingChapterReflection {
  const ReadingChapterReflection({
    required this.prompt,
    required this.bookEntryId,
    required this.excerpt,
    required this.attribution,
    required this.spoiler,
  });

  factory ReadingChapterReflection.fromJson(Map<String, dynamic> json) =>
      ReadingChapterReflection(
        prompt: json['prompt'] as String? ?? '',
        bookEntryId:
            json['bookEntryId'] as String? ?? json['bookId'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        attribution: json['attribution'] as String? ?? '',
        spoiler: json['spoiler'] as bool? ?? false,
      );

  final String prompt;
  final String bookEntryId;
  final String excerpt;
  final String attribution;
  final bool spoiler;

  Map<String, dynamic> toMutationJson({required bool safeToReveal}) => {
    'prompt': prompt,
    'bookEntryId': bookEntryId,
    'excerpt': excerpt,
    'attribution': attribution,
    'safeToReveal': safeToReveal,
  };
}

@immutable
class ReadingChapterCard {
  const ReadingChapterCard({
    required this.id,
    required this.kind,
    required this.books,
    required this.rhythm,
    required this.formats,
    this.totals,
    this.comparison,
    this.journey,
    this.taste,
    this.ratings,
    this.archetype,
    this.reflection,
  });

  factory ReadingChapterCard.fromJson(Map<String, dynamic> json) =>
      ReadingChapterCard(
        id: json['id'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        books: _maps(json['books']).map(ReadingChapterBook.fromJson).toList(),
        totals: _optionalMap(json['totals'], ReadingChapterTotals.fromJson),
        rhythm: _maps(
          json['rhythm'],
        ).map(ReadingChapterRhythmPoint.fromJson).toList(),
        comparison: _optionalMap(
          json['comparison'],
          ReadingChapterComparison.fromJson,
        ),
        journey: _optionalMap(json['journey'], ReadingChapterJourney.fromJson),
        formats: _maps(
          json['formats'],
        ).map(ReadingChapterCount.fromJson).toList(),
        taste: _optionalMap(json['taste'], ReadingChapterTaste.fromJson),
        ratings: _optionalMap(json['ratings'], ReadingChapterRatings.fromJson),
        archetype: _optionalMap(
          json['archetype'],
          ReadingChapterArchetype.fromJson,
        ),
        reflection: _optionalMap(
          json['reflection'],
          ReadingChapterReflection.fromJson,
        ),
      );

  final String id;
  final String kind;
  final List<ReadingChapterBook> books;
  final ReadingChapterTotals? totals;
  final List<ReadingChapterRhythmPoint> rhythm;
  final ReadingChapterComparison? comparison;
  final ReadingChapterJourney? journey;
  final List<ReadingChapterCount> formats;
  final ReadingChapterTaste? taste;
  final ReadingChapterRatings? ratings;
  final ReadingChapterArchetype? archetype;
  final ReadingChapterReflection? reflection;
}

@immutable
class ReadingChapterReadinessIssue {
  const ReadingChapterReadinessIssue({
    required this.kind,
    required this.bookEntryId,
    required this.count,
  });

  factory ReadingChapterReadinessIssue.fromJson(Map<String, dynamic> json) =>
      ReadingChapterReadinessIssue(
        kind: json['kind'] as String? ?? '',
        bookEntryId: json['bookEntryId'] as String? ?? '',
        count: _integer(json['count']),
      );

  final String kind;
  final String bookEntryId;
  final int count;
}

@immutable
class ReadingChapterStory {
  const ReadingChapterStory({
    required this.schemaVersion,
    required this.archetypeRuleVersion,
    required this.sourceRevision,
    required this.period,
    required this.reader,
    required this.meaningful,
    required this.cards,
    required this.readiness,
    required this.curation,
  });

  factory ReadingChapterStory.fromJson(Map<String, dynamic> json) =>
      ReadingChapterStory(
        schemaVersion: _integer(json['schemaVersion']),
        archetypeRuleVersion: _integer(json['archetypeRuleVersion']),
        sourceRevision: json['sourceRevision'] as String? ?? '',
        period: ReadingChapterPeriod.fromJson(_map(json['period'])),
        reader: ReadingChapterReader.fromJson(_map(json['reader'])),
        meaningful: json['meaningful'] as bool? ?? false,
        cards: _maps(json['cards']).map(ReadingChapterCard.fromJson).toList(),
        readiness: _maps(
          json['readiness'],
        ).map(ReadingChapterReadinessIssue.fromJson).toList(),
        curation: _maps(
          json['curation'],
        ).map(ReadingChapterReflection.fromJson).toList(),
      );

  final int schemaVersion;
  final int archetypeRuleVersion;
  final String sourceRevision;
  final ReadingChapterPeriod period;
  final ReadingChapterReader reader;
  final bool meaningful;
  final List<ReadingChapterCard> cards;
  final List<ReadingChapterReadinessIssue> readiness;
  final List<ReadingChapterReflection> curation;

  List<ReadingChapterBook> get books {
    final seen = <String>{};
    return [
      for (final card in cards)
        for (final book in card.books)
          if (seen.add(book.entryId)) book,
    ];
  }
}

@immutable
class ReadingChapterCapabilities {
  const ReadingChapterCapabilities({required this.privateGeneration});

  factory ReadingChapterCapabilities.fromJson(Map<String, dynamic> json) =>
      ReadingChapterCapabilities(
        privateGeneration: json['privateGeneration'] as bool? ?? false,
      );

  final bool privateGeneration;
}

@immutable
class ReadingChapterArchiveItem {
  const ReadingChapterArchiveItem({
    required this.kind,
    required this.periodKey,
    required this.timezone,
    required this.startsAt,
    required this.endsAt,
    required this.seen,
    required this.meaningful,
    required this.uniqueWorks,
    required this.coverUrls,
  });

  factory ReadingChapterArchiveItem.fromJson(Map<String, dynamic> json) =>
      ReadingChapterArchiveItem(
        kind: ReadingChapterKind.fromWire(json['kind'] as String? ?? ''),
        periodKey: json['periodKey'] as String? ?? '',
        timezone: json['timezone'] as String? ?? 'UTC',
        startsAt:
            _date(json['startsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        endsAt: _date(json['endsAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        seen: json['seen'] as bool? ?? false,
        meaningful: json['meaningful'] as bool? ?? false,
        uniqueWorks: _integer(json['uniqueWorks']),
        coverUrls: _strings(json['coverUrls']),
      );

  final ReadingChapterKind kind;
  final String periodKey;
  final String timezone;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool seen;
  final bool meaningful;
  final int uniqueWorks;
  final List<String> coverUrls;

  ReadingChapterRequest get request => ReadingChapterRequest(kind, periodKey);
}

@immutable
class ReadingChapterArchive {
  const ReadingChapterArchive({
    required this.items,
    required this.nextCursor,
    required this.hasUnread,
    required this.capabilities,
  });

  factory ReadingChapterArchive.fromJson(Map<String, dynamic> json) =>
      ReadingChapterArchive(
        items: _maps(
          json['items'],
        ).map(ReadingChapterArchiveItem.fromJson).toList(),
        nextCursor: json['nextCursor'] as String? ?? '',
        hasUnread: json['hasUnread'] as bool? ?? false,
        capabilities: ReadingChapterCapabilities.fromJson(
          _map(json['capabilities']),
        ),
      );

  final List<ReadingChapterArchiveItem> items;
  final String nextCursor;
  final bool hasUnread;
  final ReadingChapterCapabilities capabilities;
}

int _integer(Object? value) => value is num ? value.toInt() : 0;
int? _nullableInteger(Object? value) => value is num ? value.toInt() : null;
double _double(Object? value) => value is num ? value.toDouble() : 0;
double? _nullableDouble(Object? value) =>
    value is num ? value.toDouble() : null;
DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
Map<String, dynamic> _map(Object? value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? Map<String, dynamic>.from(value)
    : const {};
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map(_map).where((item) => item.isNotEmpty).toList(growable: false)
    : const [];
T? _optionalMap<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  final map = _map(value);
  return map.isEmpty ? null : parse(map);
}
