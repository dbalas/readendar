// Dart mirrors of the widget snapshot JSON the app writes into the App Group /
// home_widget store. Native targets parse the same shape. The in-app preview
// uses these models too (features/widget/widget_preview.dart).

class WidgetSummary {
  const WidgetSummary({
    required this.readingBooks,
    required this.events,
    this.hasMore = false,
  });

  factory WidgetSummary.fromJson(Map<String, dynamic> j) => WidgetSummary(
    readingBooks: [
      for (final b in _asList(j['readingBooks']))
        if (b is Map<String, dynamic>) WidgetBook.fromJson(b),
    ],
    events: [
      for (final e in _asList(j['events']))
        if (e is Map<String, dynamic>) WidgetEvent.fromJson(e),
    ],
    hasMore: j['hasMore'] == true,
  );

  final List<WidgetBook> readingBooks;
  final List<WidgetEvent> events;

  /// True when more upcoming events exist than returned — the widget shows an
  /// "open calendar" affordance.
  final bool hasMore;

  bool get isEmpty => readingBooks.isEmpty && events.isEmpty;

  Map<String, dynamic> toJson() => {
    'readingBooks': [for (final b in readingBooks) b.toJson()],
    'events': [for (final e in events) e.toJson()],
    'hasMore': hasMore,
  };
}

// Defensive: a malformed payload (wrong type, not just null) must not throw.
List<dynamic> _asList(dynamic v) => v is List ? v : const [];

/// Quotes widgets stay quote-category only. Missing category is a store-client
/// row that still uses the `text`/`favorite` quote shape.
bool _isWidgetQuoteCategory(Map<String, dynamic> j) {
  final c = j['category'];
  return c == null || c == 'quote';
}

class WidgetBook {
  const WidgetBook({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    this.progressPct,
    this.currentPage,
    this.pageCount,
    this.currentChapter,
    this.chapterCount,
  });

  factory WidgetBook.fromJson(Map<String, dynamic> j) => WidgetBook(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    author: j['author'] as String? ?? '',
    coverUrl: j['coverUrl'] as String? ?? '',
    progressPct: (j['progressPct'] as num?)?.toInt(),
    currentPage: (j['currentPage'] as num?)?.toInt(),
    pageCount: (j['pageCount'] as num?)?.toInt(),
    currentChapter: (j['currentChapter'] as num?)?.toInt(),
    chapterCount: (j['chapterCount'] as num?)?.toInt(),
  );

  final String id;
  final String title;
  final String author;
  final String coverUrl;

  /// 0..100, or null when unknown.
  final int? progressPct;
  final int? currentPage;
  final int? pageCount;
  final int? currentChapter;
  final int? chapterCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'coverUrl': coverUrl,
    if (progressPct != null) 'progressPct': progressPct,
    if (currentPage != null) 'currentPage': currentPage,
    if (pageCount != null) 'pageCount': pageCount,
    if (currentChapter != null) 'currentChapter': currentChapter,
    if (chapterCount != null) 'chapterCount': chapterCount,
  };
}

class WidgetEvent {
  const WidgetEvent({
    required this.id,
    required this.type,
    required this.dateLocal,
    this.bookId,
    this.bookTitle,
    this.bookAuthor,
    this.bookCoverUrl,
    this.title,
    this.status = 'active',
    this.timeLocal,
    this.tz,
  });

  factory WidgetEvent.fromJson(Map<String, dynamic> j) => WidgetEvent(
    id: j['id'] as String? ?? '',
    type: j['type'] as String? ?? '',
    dateLocal: j['dateLocal'] as String? ?? '',
    bookId: j['bookId'] as String?,
    bookTitle: j['bookTitle'] as String?,
    bookAuthor: j['bookAuthor'] as String?,
    bookCoverUrl: j['bookCoverUrl'] as String?,
    title: j['title'] as String?,
    status: j['status'] as String? ?? 'active',
    timeLocal: j['timeLocal'] as String?,
    tz: j['tz'] as String?,
  );

  final String id;
  final String type;

  /// "active" | "completed".
  final String status;

  /// "YYYY-MM-DD".
  final String dateLocal;
  final String? bookId;
  final String? bookTitle;

  /// The event book's author + cover (personal library), so a widget row can
  /// mirror the app's event card. Empty/null when the book isn't resolvable.
  final String? bookAuthor;
  final String? bookCoverUrl;

  /// The event's own persisted title (e.g. "Página 143"), independent of
  /// [bookTitle] — the fallback when a book title can't be resolved.
  final String? title;

  /// "HH:MM", or null for all-day.
  final String? timeLocal;
  final String? tz;

  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'dateLocal': dateLocal,
    'status': status,
    if (bookId != null) 'bookId': bookId,
    if (bookTitle != null) 'bookTitle': bookTitle,
    if (bookAuthor != null) 'bookAuthor': bookAuthor,
    if (bookCoverUrl != null) 'bookCoverUrl': bookCoverUrl,
    if (title != null) 'title': title,
    if (timeLocal != null) 'timeLocal': timeLocal,
    if (tz != null) 'tz': tz,
  };
}

/// The token pair returned by POST /v1/auth/widget-session — a fresh refresh
/// family dedicated to the widget (see the backend auth service).
class WidgetSession {
  const WidgetSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  factory WidgetSession.fromJson(Map<String, dynamic> j) => WidgetSession(
    userId: j['userId'] as String? ?? '',
    accessToken: j['accessToken'] as String? ?? '',
    refreshToken: j['refreshToken'] as String? ?? '',
  );

  final String userId;
  final String accessToken;
  final String refreshToken;
}

/// One saved quote with its book pre-resolved, cached natively under
/// `wdg_quotes_cache`.
class WidgetQuote {
  const WidgetQuote({
    required this.id,
    required this.text,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    this.page,
    this.favorite = false,
    this.note = '',
    this.bookCoverUrl = '',
  });

  factory WidgetQuote.fromJson(Map<String, dynamic> j) => WidgetQuote(
    id: j['id'] as String? ?? '',
    text: (j['body'] as String?) ?? (j['text'] as String?) ?? '',
    page: (j['page'] as num?)?.toInt(),
    favorite: j['favorite'] as bool? ?? false,
    note: (j['commentary'] as String?) ?? (j['note'] as String?) ?? '',
    bookId: j['bookId'] as String? ?? '',
    bookTitle: j['bookTitle'] as String? ?? '',
    bookAuthor: j['bookAuthor'] as String? ?? '',
    bookCoverUrl: j['bookCoverUrl'] as String? ?? '',
  );

  final String id;
  final String text;
  final int? page;
  final bool favorite;

  /// The owner's private note (empty when none). Rendered by a widget instance
  /// only when its config opts in (`QuotesWidgetConfig.showNote`).
  final String note;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String bookCoverUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    if (page != null) 'page': page,
    'favorite': favorite,
    if (note.isNotEmpty) 'note': note,
    'bookId': bookId,
    'bookTitle': bookTitle,
    'bookAuthor': bookAuthor,
    if (bookCoverUrl.isNotEmpty) 'bookCoverUrl': bookCoverUrl,
  };
}

/// The `wdg_quotes_cache` shared-store payload — THE single Dart definition of
/// the JSON contract both native quotes widgets mirror:
/// `{"fetchedAt": ISO-8601, "quotes": [WidgetQuote…]}`. Written by the app
/// after every quote mutation and by the native fetchers on their own refresh.
class WidgetQuotesPayload {
  const WidgetQuotesPayload({required this.fetchedAt, required this.quotes});

  factory WidgetQuotesPayload.fromJson(Map<String, dynamic> j) =>
      WidgetQuotesPayload(
        fetchedAt:
            DateTime.tryParse(j['fetchedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        quotes: [
          for (final q
              in (j['annotations'] as List?) ??
                  (j['quotes'] as List?) ??
                  const [])
            if (q is Map<String, dynamic> && _isWidgetQuoteCategory(q))
              WidgetQuote.fromJson(q),
        ],
      );

  final DateTime fetchedAt;
  final List<WidgetQuote> quotes;

  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'quotes': quotes.map((q) => q.toJson()).toList(),
  };
}

/// What a quotes-widget instance shows: rotate the whole snapshot, rotate a
/// subset (favorites / one book), or pin one fixed quote. Wire values match the
/// native config (`QuotesWidgetConfig.mode` on Android, `QuoteWidgetMode` on
/// iOS) so the same string round-trips app → shared store → both renderers.
enum QuotesWidgetMode {
  all('all'),
  favorites('favorites'),
  book('book'),
  fixed('fixed');

  const QuotesWidgetMode(this.wire);
  final String wire;

  static QuotesWidgetMode fromWire(String? s) {
    // Pre-favorite configs stored the star filter as `pinned`.
    if (s == 'favorites' || s == 'pinned') {
      return QuotesWidgetMode.favorites;
    }
    return QuotesWidgetMode.values.firstWhere(
      (m) => m.wire == s,
      orElse: () => QuotesWidgetMode.all,
    );
  }
}

/// How often a rotating widget flips to the next quote (ignored for [QuotesWidgetMode.fixed]).
/// Wire values match the native cadence strings.
enum QuotesWidgetCadence {
  hourly('1h'),
  sixHourly('6h'),
  daily('daily');

  const QuotesWidgetCadence(this.wire);
  final String wire;

  Duration get period => switch (this) {
    QuotesWidgetCadence.hourly => const Duration(hours: 1),
    QuotesWidgetCadence.sixHourly => const Duration(hours: 6),
    QuotesWidgetCadence.daily => const Duration(days: 1),
  };

  static QuotesWidgetCadence fromWire(String? s) => QuotesWidgetCadence.values
      .firstWhere((c) => c.wire == s, orElse: () => QuotesWidgetCadence.daily);
}

/// The visual appearance a quotes-widget instance renders with — the same
/// palette set the share-quote card offers (`QuoteCardStyle`), plus [auto].
///
/// [auto] keeps the historical behaviour: the widget follows the app's
/// light/dark theme (`wdg_theme`). Every other value is a FIXED brand palette
/// that renders identically regardless of theme (a "sticker" per the theme
/// convention), mirroring how the share card ignores the app theme. The wire
/// strings match `QuoteCardStyle.name` 1:1 so the in-app preview can map
/// straight onto `paletteFor`, and both native renderers key off the same
/// string.
enum QuoteWidgetStyle {
  auto('auto'),
  lightElegant('lightElegant'),
  minimal('minimal'),
  dark('dark'),
  coverGradient('coverGradient'),
  gradientSunset('gradientSunset'),
  gradientForest('gradientForest'),
  gradientOcean('gradientOcean'),
  gradientDusk('gradientDusk'),
  parchment('parchment'),
  mist('mist'),
  pine('pine'),
  honey('honey'),
  noirGold('noirGold');

  const QuoteWidgetStyle(this.wire);
  final String wire;

  bool get isAuto => this == QuoteWidgetStyle.auto;

  static QuoteWidgetStyle fromWire(String? s) => QuoteWidgetStyle.values
      .firstWhere((v) => v.wire == s, orElse: () => QuoteWidgetStyle.auto);
}

/// A quotes-widget instance's configuration, chosen in-app and handed to the
/// native widget (Android seeds per-`appWidgetId` prefs from the pending copy;
/// iOS seeds its AppIntent defaults). The single Dart definition of the config
/// JSON contract both native targets mirror.
class QuotesWidgetConfig {
  const QuotesWidgetConfig({
    this.mode = QuotesWidgetMode.all,
    this.quoteId,
    this.bookId,
    this.cadence = QuotesWidgetCadence.daily,
    this.style = QuoteWidgetStyle.auto,
    this.showNote = false,
  });

  factory QuotesWidgetConfig.fromJson(Map<String, dynamic> j) =>
      QuotesWidgetConfig(
        mode: QuotesWidgetMode.fromWire(j['mode'] as String?),
        quoteId: j['quoteId'] as String?,
        bookId: j['bookId'] as String?,
        cadence: QuotesWidgetCadence.fromWire(j['cadence'] as String?),
        style: QuoteWidgetStyle.fromWire(j['style'] as String?),
        showNote: j['showNote'] as bool? ?? false,
      );

  final QuotesWidgetMode mode;

  /// Only meaningful for [QuotesWidgetMode.fixed].
  final String? quoteId;

  /// Only meaningful for [QuotesWidgetMode.book].
  final String? bookId;

  final QuotesWidgetCadence cadence;

  /// The widget's appearance. [QuoteWidgetStyle.auto] follows the app theme;
  /// every other value is a fixed brand palette (see [QuoteWidgetStyle]).
  final QuoteWidgetStyle style;

  /// When true, a shown quote's private note is rendered on the widget. Off by
  /// default (mirrors the share-time opt-in): the note stays private otherwise.
  final bool showNote;

  QuotesWidgetConfig copyWith({
    QuotesWidgetMode? mode,
    String? quoteId,
    String? bookId,
    QuotesWidgetCadence? cadence,
    QuoteWidgetStyle? style,
    bool? showNote,
  }) => QuotesWidgetConfig(
    mode: mode ?? this.mode,
    quoteId: quoteId ?? this.quoteId,
    bookId: bookId ?? this.bookId,
    cadence: cadence ?? this.cadence,
    style: style ?? this.style,
    showNote: showNote ?? this.showNote,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.wire,
    if (quoteId != null) 'quoteId': quoteId,
    if (bookId != null) 'bookId': bookId,
    'cadence': cadence.wire,
    'style': style.wire,
    'showNote': showNote,
  };
}

/// The quotes a config would rotate over, mirroring native
/// `QuotesRotation.candidates`: fixed → the picked quote (or the newest as a
/// fallback); else the mode filter, falling back to the whole list when the
/// filter is empty. [quotes] must be in the stable newest-first order.
List<WidgetQuote> quotesWidgetCandidates(
  List<WidgetQuote> quotes,
  QuotesWidgetConfig config,
) {
  if (config.mode == QuotesWidgetMode.fixed) {
    for (final q in quotes) {
      if (q.id == config.quoteId) return [q];
    }
    return quotes.isEmpty ? const [] : [quotes.first];
  }
  final filtered = switch (config.mode) {
    QuotesWidgetMode.favorites => quotes.where((q) => q.favorite).toList(),
    QuotesWidgetMode.book =>
      quotes.where((q) => q.bookId == config.bookId).toList(),
    _ => quotes,
  };
  return filtered.isEmpty ? quotes : filtered;
}

/// The quote a config shows at [now], using the exact local-time bucket formula
/// the native widgets and the in-app preview share (`bucket % count` over the
/// candidates). Returns null only when there are no candidates.
WidgetQuote? pickQuotesWidgetQuote(
  List<WidgetQuote> quotes,
  QuotesWidgetConfig config,
  DateTime now,
) {
  final candidates = quotesWidgetCandidates(quotes, config);
  if (candidates.isEmpty) return null;
  if (config.mode == QuotesWidgetMode.fixed) return candidates.first;
  final localMillis =
      now.millisecondsSinceEpoch + now.timeZoneOffset.inMilliseconds;
  final bucket = localMillis ~/ config.cadence.period.inMilliseconds;
  return candidates[bucket % candidates.length];
}
