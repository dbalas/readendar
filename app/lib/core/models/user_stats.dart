// Personal reading-statistics models. Mirrors the backend UserStatsDTO (5
// blocks). Pure Dart, no Flutter imports. Re-exported from models.dart.

import 'package:meta/meta.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
double? _dn(dynamic v) => (v as num?)?.toDouble();

class UserStats {
  UserStats({
    required this.summary,
    required this.overview,
    required this.activity,
    required this.pageActivity,
    required this.taste,
  });

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
    summary: UserStatsSummary.fromJson(j['summary'] as Map<String, dynamic>),
    overview: UserYearOverview.fromJson(
      (j['overview'] as Map<String, dynamic>?) ?? const {},
    ),
    activity: UserStatsActivity.fromJson(j['activity'] as Map<String, dynamic>),
    pageActivity: UserPageActivity.fromJson(
      (j['pageActivity'] as Map<String, dynamic>?) ?? const {},
    ),
    taste: UserStatsTaste.fromJson(j['taste'] as Map<String, dynamic>),
  );
  final UserStatsSummary summary;
  final UserYearOverview overview;
  final UserStatsActivity activity;
  final UserPageActivity pageActivity;
  final UserStatsTaste taste;
}

enum TasteScope {
  year('year'),
  all('all');

  const TasteScope(this.apiValue);
  final String apiValue;

  static TasteScope parse(String? raw) => values.firstWhere(
    (v) => v.apiValue == raw,
    orElse: () => TasteScope.year,
  );
}

enum PageGranularity {
  day('day'),
  week('week'),
  month('month'),
  year('year'),
  all('all');

  const PageGranularity(this.apiValue);
  final String apiValue;

  static PageGranularity parse(String? raw) => values.firstWhere(
    (v) => v.apiValue == raw,
    orElse: () => PageGranularity.month,
  );
}

@immutable
class PageActivityQuery {
  const PageActivityQuery({
    this.granularity = PageGranularity.month,
    this.offset = 0,
    this.tasteScope = TasteScope.year,
  });
  final PageGranularity granularity;
  final int offset;
  final TasteScope tasteScope;

  PageActivityQuery copyWith({
    PageGranularity? granularity,
    int? offset,
    TasteScope? tasteScope,
  }) => PageActivityQuery(
    granularity: granularity ?? this.granularity,
    offset: offset ?? this.offset,
    tasteScope: tasteScope ?? this.tasteScope,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageActivityQuery &&
          other.granularity == granularity &&
          other.offset == offset &&
          other.tasteScope == tasteScope;

  @override
  int get hashCode => Object.hash(granularity, offset, tasteScope);
}

class UserOverviewMonth {
  UserOverviewMonth({
    required this.month,
    required this.books,
    required this.pages,
  });

  factory UserOverviewMonth.fromJson(Map<String, dynamic> j) =>
      UserOverviewMonth(
        month: (j['month'] as String?) ?? '',
        books: _i(j['books']),
        pages: _i(j['pages']),
      );
  final String month;
  final int books;
  final int pages;
}

class UserYearOverview {
  UserYearOverview({
    required this.available,
    required this.year,
    required this.finishedBooks,
    required this.loggedPages,
    required this.activeDays,
    required this.currentDayStreak,
    required this.longestDayStreak,
    required this.previousYearPages,
    required this.changePercent,
    required this.monthly,
  });

  factory UserYearOverview.fromJson(Map<String, dynamic> j) => UserYearOverview(
    available: j.isNotEmpty,
    year: _i(j['year']),
    finishedBooks: _i(j['finishedBooks']),
    loggedPages: _i(j['loggedPages']),
    activeDays: _i(j['activeDays']),
    currentDayStreak: _i(j['currentDayStreak']),
    longestDayStreak: _i(j['longestDayStreak']),
    previousYearPages: _i(j['previousYearPages']),
    changePercent: _dn(j['changePercent']),
    monthly: ((j['monthly'] as List?) ?? const [])
        .map((e) => UserOverviewMonth.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  final bool available;
  final int year;
  final int finishedBooks;
  final int loggedPages;
  final int activeDays;
  final int currentDayStreak;
  final int longestDayStreak;
  final int previousYearPages;
  final double? changePercent;
  final List<UserOverviewMonth> monthly;
}

class UserPageBucket {
  UserPageBucket({
    required this.startDate,
    required this.endDate,
    required this.pages,
    required this.isFuture,
  });

  factory UserPageBucket.fromJson(Map<String, dynamic> j) => UserPageBucket(
    startDate:
        DateTime.tryParse((j['startDate'] as String?) ?? '') ?? DateTime(1970),
    endDate:
        DateTime.tryParse((j['endDate'] as String?) ?? '') ?? DateTime(1970),
    pages: _i(j['pages']),
    isFuture: j['isFuture'] == true,
  );
  final DateTime startDate;
  final DateTime endDate;
  final int pages;
  final bool isFuture;
}

class UserPageActivity {
  UserPageActivity({
    required this.available,
    required this.granularity,
    required this.offset,
    required this.from,
    required this.to,
    required this.totalPages,
    required this.todayPages,
    required this.previousPages,
    required this.averagePages,
    required this.activeBuckets,
    required this.activeDays,
    required this.buckets,
  });

  factory UserPageActivity.fromJson(Map<String, dynamic> j) {
    if (j.isEmpty) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return UserPageActivity(
        available: false,
        granularity: PageGranularity.month,
        offset: 0,
        from: DateTime(today.year, today.month),
        to: DateTime(today.year, today.month + 1, 0),
        totalPages: 0,
        todayPages: 0,
        previousPages: null,
        averagePages: 0,
        activeBuckets: 0,
        activeDays: 0,
        buckets: const [],
      );
    }
    return UserPageActivity(
      available: true,
      granularity: PageGranularity.parse(j['granularity'] as String?),
      offset: _i(j['offset']),
      from: DateTime.tryParse((j['from'] as String?) ?? '') ?? DateTime(1970),
      to: DateTime.tryParse((j['to'] as String?) ?? '') ?? DateTime(1970),
      totalPages: _i(j['totalPages']),
      todayPages: _i(j['todayPages']),
      previousPages: (j['previousPages'] as num?)?.toInt(),
      averagePages: _d(j['averagePages']),
      activeBuckets: _i(j['activeBuckets']),
      activeDays: _i(j['activeDays']),
      buckets: ((j['buckets'] as List?) ?? const [])
          .map((e) => UserPageBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  final bool available;
  final PageGranularity granularity;
  final int offset;
  final DateTime from;
  final DateTime to;
  final int totalPages;
  final int todayPages;
  final int? previousPages;
  final double averagePages;
  final int activeBuckets;
  final int activeDays;
  final List<UserPageBucket> buckets;
}

class UserStatsSummary {
  UserStatsSummary({
    required this.booksRead,
    required this.booksReading,
    required this.booksQueued,
    required this.booksWanted,
    required this.booksAbandoned,
    required this.totalBooks,
    required this.finishedBookPages,
    required this.readingSince,
  });
  factory UserStatsSummary.fromJson(Map<String, dynamic> j) => UserStatsSummary(
    booksRead: _i(j['booksRead']),
    booksReading: _i(j['booksReading']),
    booksQueued: _i(j['booksQueued']),
    booksWanted: _i(j['booksWanted']),
    booksAbandoned: _i(j['booksAbandoned']),
    totalBooks: _i(j['totalBooks']),
    finishedBookPages: _i(j['finishedBookPages'] ?? j['totalPagesRead']),
    readingSince: (j['readingSince'] as String?) == null
        ? null
        : DateTime.tryParse(j['readingSince'] as String),
  );
  final int booksRead;
  final int booksReading;
  final int booksQueued;
  final int booksWanted;
  final int booksAbandoned;
  final int totalBooks;
  final int finishedBookPages;
  final DateTime? readingSince;
}

class UserMonthCount {
  UserMonthCount({required this.month, required this.count});
  factory UserMonthCount.fromJson(Map<String, dynamic> j) => UserMonthCount(
    month: (j['month'] as String?) ?? '',
    count: _i(j['count']),
  );
  final String month;
  final int count;
}

class UserStatsActivity {
  UserStatsActivity({
    required this.finished30,
    required this.finishedYear,
    required this.added30,
    required this.currentStreak,
    required this.longestStreak,
    required this.bestMonth,
    required this.bestMonthCount,
    required this.monthly,
  });
  factory UserStatsActivity.fromJson(Map<String, dynamic> j) =>
      UserStatsActivity(
        finished30: _i(j['finished30']),
        finishedYear: _i(j['finishedYear']),
        added30: _i(j['added30']),
        currentStreak: _i(j['currentStreak']),
        longestStreak: _i(j['longestStreak']),
        bestMonth: (j['bestMonth'] as String?) ?? '',
        bestMonthCount: _i(j['bestMonthCount']),
        monthly: ((j['monthly'] as List?) ?? const [])
            .map((e) => UserMonthCount.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
  final int finished30;
  final int finishedYear;
  final int added30;
  final int currentStreak;
  final int longestStreak;
  final String bestMonth;
  final int bestMonthCount;
  final List<UserMonthCount> monthly;
}

class UserGenreAffinity {
  UserGenreAffinity({
    required this.code,
    required this.genre,
    required this.count,
    required this.ratedCount,
    required this.avgRating,
  });
  factory UserGenreAffinity.fromJson(Map<String, dynamic> j) =>
      UserGenreAffinity(
        code: (j['code'] as String?) ?? '',
        genre: (j['genre'] as String?) ?? '',
        count: _i(j['count']),
        ratedCount: _i(j['ratedCount']),
        avgRating: _dn(j['avgRating']),
      );
  final String code;
  final String genre;
  final int count;
  final int ratedCount;
  final double? avgRating;
}

class UserAuthorAffinity {
  UserAuthorAffinity({
    required this.author,
    required this.count,
    required this.ratedCount,
    required this.avgRating,
  });
  factory UserAuthorAffinity.fromJson(Map<String, dynamic> j) =>
      UserAuthorAffinity(
        author: (j['author'] as String?) ?? '',
        count: _i(j['count']),
        ratedCount: _i(j['ratedCount']),
        avgRating: _dn(j['avgRating']),
      );
  final String author;
  final int count;
  final int ratedCount;
  final double? avgRating;
}

class UserRatingBucket {
  UserRatingBucket({required this.rating, required this.count});
  factory UserRatingBucket.fromJson(Map<String, dynamic> j) =>
      UserRatingBucket(rating: _i(j['rating']), count: _i(j['count']));
  final int rating;
  final int count;
}

class UserFormatCount {
  UserFormatCount({required this.format, required this.count});
  factory UserFormatCount.fromJson(Map<String, dynamic> j) => UserFormatCount(
    format: (j['format'] as String?) ?? 'other',
    count: _i(j['count']),
  );
  final String format;
  final int count;
}

class UserStatsTaste {
  UserStatsTaste({
    required this.scope,
    required this.completedCount,
    required this.topGenres,
    required this.topAuthors,
    required this.avgRating,
    required this.ratedCount,
    required this.highRatingPercent,
    required this.ratingDistribution,
    required this.formats,
  });
  factory UserStatsTaste.fromJson(Map<String, dynamic> j) => UserStatsTaste(
    scope: TasteScope.parse(j['scope'] as String?),
    completedCount: _i(j['completedCount']),
    topGenres: ((j['topGenres'] as List?) ?? const [])
        .map((e) => UserGenreAffinity.fromJson(e as Map<String, dynamic>))
        .toList(),
    topAuthors: ((j['topAuthors'] as List?) ?? const [])
        .map((e) => UserAuthorAffinity.fromJson(e as Map<String, dynamic>))
        .toList(),
    avgRating: _dn(j['avgRating']),
    ratedCount: _i(j['ratedCount']),
    highRatingPercent: _i(j['highRatingPercent']),
    ratingDistribution: ((j['ratingDistribution'] as List?) ?? const [])
        .map((e) => UserRatingBucket.fromJson(e as Map<String, dynamic>))
        .toList(),
    formats: ((j['formats'] as List?) ?? const [])
        .map((e) => UserFormatCount.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
  final TasteScope scope;
  final int completedCount;
  final List<UserGenreAffinity> topGenres;
  final List<UserAuthorAffinity> topAuthors;
  final double? avgRating;
  final int ratedCount;
  final int highRatingPercent;
  final List<UserRatingBucket> ratingDistribution;
  final List<UserFormatCount> formats;
}
