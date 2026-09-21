// Domain entities shared across features. Pure Dart, no Flutter imports.
//
// Historical hosted DTO shapes kept for the leftover export window.

import 'package:meta/meta.dart';

import 'package:readendar/core/models/enums.dart';

export 'custom_field.dart';
export 'user_stats.dart';

/// How the Home welcome banner is styled. Pure data — the colour/gradient/image
/// resolution lives in core/theme/banner_presets.dart. Mirrors the backend
/// `HomeBanner` value object. [BannerKind.defaultStyle] is the absence of a
/// choice (renders today's periwinkle); on a PATCH it serializes to
/// {type:"default"} which the server stores as no banner.
enum BannerKind { preset, image, defaultStyle }

@immutable
class BannerStyle {
  /// Tolerant of unknown/missing data — an unrecognized type or empty value
  /// degrades to the default (forward-compat with a newer server).
  factory BannerStyle.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const BannerStyle.defaultStyle();
    switch (j['type']) {
      case 'preset':
        final p = (j['preset'] as String?)?.trim() ?? '';
        return p.isEmpty
            ? const BannerStyle.defaultStyle()
            : BannerStyle.preset(p);
      case 'image':
        final u = (j['imageUrl'] as String?)?.trim() ?? '';
        return u.isEmpty
            ? const BannerStyle.defaultStyle()
            : BannerStyle.image(u);
      default:
        return const BannerStyle.defaultStyle();
    }
  }
  const BannerStyle.preset(this.preset)
    : kind = BannerKind.preset,
      imageUrl = '';
  const BannerStyle.image(this.imageUrl) : kind = BannerKind.image, preset = '';
  const BannerStyle.defaultStyle()
    : kind = BannerKind.defaultStyle,
      preset = '',
      imageUrl = '';

  final BannerKind kind;
  final String preset;
  final String imageUrl;

  bool get isDefault => kind == BannerKind.defaultStyle;

  Map<String, dynamic> toJson() => switch (kind) {
    BannerKind.preset => {'type': 'preset', 'preset': preset},
    BannerKind.image => {'type': 'image', 'imageUrl': imageUrl},
    BannerKind.defaultStyle => {'type': 'default'},
  };

  @override
  bool operator ==(Object other) =>
      other is BannerStyle &&
      other.kind == kind &&
      other.preset == preset &&
      other.imageUrl == imageUrl;

  @override
  int get hashCode => Object.hash(kind, preset, imageUrl);
}

class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.preferredLocale,
    required this.timezone,
    required this.onboardingCompletedAt,
    this.termsAcceptedAt,
    this.termsVersion = '',
    this.analyticsEnabled = false,
    this.analyticsChoiceAt,
    this.analyticsNoticeVersion = '',
    bool autoCreateStatusEvents = false,
    bool alwaysShowSpoilerQuotes = false,
    this.homeBanner = const BannerStyle.defaultStyle(),
  }) : // Public constructor names intentionally differ from nullable backing
       // fields, which keep older hot-reloaded instances fail-safe.
       // ignore: prefer_initializing_formals
       _autoCreateStatusEvents = autoCreateStatusEvents,
       // ignore: prefer_initializing_formals
       _alwaysShowSpoilerQuotes = alwaysShowSpoilerQuotes;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as String,
    email: j['email'] as String,
    displayName: j['displayName'] as String,
    preferredLocale: (j['preferredLocale'] as String?) ?? 'es',
    timezone: (j['timezone'] as String?) ?? 'Europe/Madrid',
    onboardingCompletedAt: j['onboardingCompletedAt'] == null
        ? null
        : DateTime.parse(j['onboardingCompletedAt'] as String),
    termsAcceptedAt: j['termsAcceptedAt'] == null
        ? null
        : DateTime.parse(j['termsAcceptedAt'] as String),
    termsVersion: (j['termsVersion'] as String?) ?? '',
    analyticsEnabled: (j['analyticsEnabled'] as bool?) ?? false,
    analyticsChoiceAt: j['analyticsChoiceAt'] == null
        ? null
        : DateTime.parse(j['analyticsChoiceAt'] as String),
    analyticsNoticeVersion: (j['analyticsNoticeVersion'] as String?) ?? '',
    // Older servers omit the key; treat missing/null as off.
    autoCreateStatusEvents: j['autoCreateStatusEvents'] as bool? ?? false,
    // Older servers omit the key; protect quotes by default.
    alwaysShowSpoilerQuotes: j['alwaysShowSpoilerQuotes'] as bool? ?? false,
    homeBanner: BannerStyle.fromJson(
      j['homeBanner'] as Map<String, dynamic>?,
    ),
  );

  final String id;
  final String email;
  final String displayName;
  final String preferredLocale;
  final String timezone;
  final DateTime? onboardingCompletedAt;
  final DateTime? termsAcceptedAt;
  final String termsVersion;
  final bool analyticsEnabled;
  final DateTime? analyticsChoiceAt;
  final String analyticsNoticeVersion;
  // Nullable storage so hot-reload / older in-memory instances don't crash on
  // read; [autoCreateStatusEvents] coalesces null → false.
  final bool? _autoCreateStatusEvents;
  final bool? _alwaysShowSpoilerQuotes;
  final BannerStyle homeBanner;

  bool get autoCreateStatusEvents => _autoCreateStatusEvents ?? false;
  bool get alwaysShowSpoilerQuotes => _alwaysShowSpoilerQuotes ?? false;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'preferredLocale': preferredLocale,
    'timezone': timezone,
    'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
    'termsAcceptedAt': termsAcceptedAt?.toIso8601String(),
    'termsVersion': termsVersion,
    'analyticsEnabled': analyticsEnabled,
    'analyticsChoiceAt': analyticsChoiceAt?.toIso8601String(),
    'analyticsNoticeVersion': analyticsNoticeVersion,
    'autoCreateStatusEvents': autoCreateStatusEvents,
    'alwaysShowSpoilerQuotes': alwaysShowSpoilerQuotes,
    'homeBanner': homeBanner.toJson(),
  };

  AppUser copyWith({
    String? displayName,
    String? preferredLocale,
    String? timezone,
    DateTime? onboardingCompletedAt,
    DateTime? termsAcceptedAt,
    String? termsVersion,
    bool? analyticsEnabled,
    DateTime? analyticsChoiceAt,
    String? analyticsNoticeVersion,
    bool? autoCreateStatusEvents,
    bool? alwaysShowSpoilerQuotes,
    BannerStyle? homeBanner,
  }) => AppUser(
    id: id,
    email: email,
    displayName: displayName ?? this.displayName,
    preferredLocale: preferredLocale ?? this.preferredLocale,
    timezone: timezone ?? this.timezone,
    onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
    termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
    termsVersion: termsVersion ?? this.termsVersion,
    analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
    analyticsChoiceAt: analyticsChoiceAt ?? this.analyticsChoiceAt,
    analyticsNoticeVersion:
        analyticsNoticeVersion ?? this.analyticsNoticeVersion,
    autoCreateStatusEvents:
        autoCreateStatusEvents ?? this.autoCreateStatusEvents,
    alwaysShowSpoilerQuotes:
        alwaysShowSpoilerQuotes ?? this.alwaysShowSpoilerQuotes,
    homeBanner: homeBanner ?? this.homeBanner,
  );
}

class AuthSession {
  AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    required this.isNewUser,
  });
  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
    user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    isNewUser: (j['isNewUser'] as bool?) ?? false,
  );
  final AppUser user;
  final String accessToken;
  final String refreshToken;
  final bool isNewUser;
}

class MagicLinkRequestResult {
  const MagicLinkRequestResult({
    required this.sent,
    this.devLink,
    this.devCode,
  });

  factory MagicLinkRequestResult.fromJson(Map<String, dynamic> json) {
    return MagicLinkRequestResult(
      sent: json['sent'] == true,
      devLink: json['devLink'] as String?,
      devCode: json['devCode'] as String?,
    );
  }

  final bool sent;
  final String? devLink;
  final String? devCode;
}

class Book {
  Book({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.title,
    required this.authors,
    required this.status,
    this.coverUrl = '',
    this.description = '',
    this.pageCount,
    this.chapterCount,
    this.isbn13 = '',
    this.isbn10 = '',
    this.publisher = '',
    this.language = '',
    this.publicationDate,
    this.publicationDatePrecision = '',
    this.categories = const [],
    this.categoryCodes = const [],
    this.format,
    this.rating,
    this.notes = '',
    this.reviewMarkdown = '',
    this.subtitle = '',
    this.edition = '',
    this.binding = '',
    this.dimensions = '',
    this.msrp,
    this.msrpCurrency = '',
    this.excerpt = '',
    this.related = const [],
    this.statusChangedAt,
    this.annotationCount = 0,
  });

  factory Book.fromJson(Map<String, dynamic> j) => Book(
    id: j['id'] as String,
    ownerType: j['ownerType'] as String,
    ownerId: j['ownerId'] as String,
    title: j['title'] as String,
    authors: ((j['authors'] as List?) ?? const []).cast<String>(),
    coverUrl: (j['coverUrl'] as String?) ?? '',
    description: (j['description'] as String?) ?? '',
    pageCount: j['pageCount'] as int?,
    chapterCount: j['chapterCount'] as int?,
    isbn13: (j['isbn13'] as String?) ?? '',
    isbn10: (j['isbn10'] as String?) ?? '',
    publisher: (j['publisher'] as String?) ?? '',
    language: (j['language'] as String?) ?? '',
    publicationDate: j['publicationDate'] == null
        ? null
        : DateTime.tryParse(j['publicationDate'] as String),
    publicationDatePrecision: (j['publicationDatePrecision'] as String?) ?? '',
    categories: ((j['categories'] as List?) ?? const []).cast<String>(),
    categoryCodes: ((j['categoryCodes'] as List?) ?? const []).cast<String>(),
    format: j['format'] as String?,
    status: j['status'] as String,
    rating: (j['rating'] as num?)?.toDouble(),
    notes: (j['notes'] as String?) ?? (j['privateNotes'] as String?) ?? '',
    reviewMarkdown: (j['reviewMarkdown'] as String?) ?? '',
    subtitle: (j['subtitle'] as String?) ?? '',
    edition: (j['edition'] as String?) ?? '',
    binding: (j['binding'] as String?) ?? '',
    dimensions: (j['dimensions'] as String?) ?? '',
    msrp: (j['msrp'] as num?)?.toDouble(),
    msrpCurrency: (j['msrpCurrency'] as String?) ?? '',
    excerpt: (j['excerpt'] as String?) ?? '',
    related: ((j['related'] as List?) ?? const []).cast<String>(),
    statusChangedAt: j['statusChangedAt'] == null
        ? null
        : DateTime.tryParse(j['statusChangedAt'] as String),
    annotationCount: (j['annotationCount'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String ownerType;
  final String ownerId;
  final String title;
  final List<String> authors;
  final String coverUrl;
  final String description;
  final int? pageCount;
  final int? chapterCount;
  final String isbn13;
  final String isbn10;
  final String publisher;
  final String language;
  final DateTime? publicationDate;
  final String publicationDatePrecision;
  final List<String> categories;
  final List<String> categoryCodes;
  final String? format;

  /// Catalog bibliographic metadata (empty/null when unknown or manually added).
  final String subtitle;
  final String edition;
  final String binding;

  /// Formatted physical dimensions + weight, ready to display.
  final String dimensions;
  final double? msrp;
  final String msrpCurrency;
  final String excerpt;
  final List<String> related;
  final String status;

  /// Instant the current [status] was set (or last corrected via history).
  /// Null when older clients/fixtures omit it.
  final DateTime? statusChangedAt;

  /// Private half-star rating (0–5.0). Null = unrated.
  final double? rating;

  /// Private free-text notes.
  final String notes;

  /// Private review markdown.
  final String reviewMarkdown;

  final int annotationCount;

  bool get hasNotes => notes.trim().isNotEmpty || annotationCount > 0;
  String get isbnDisplay => isbn13.isNotEmpty ? isbn13 : isbn10;

  /// Copies the entry overriding the fields the UI mutates optimistically
  /// (status, rating, notes, chapterCount). `clearRating: true` sets rating to
  /// null — a plain `rating` argument can't express "clear" vs "unchanged".
  Book copyWith({
    String? status,
    DateTime? statusChangedAt,
    double? rating,
    bool clearRating = false,
    String? notes,
    String? reviewMarkdown,
    int? chapterCount,
    int? annotationCount,
    String? coverUrl,
  }) => Book(
    id: id,
    ownerType: ownerType,
    ownerId: ownerId,
    title: title,
    authors: authors,
    status: status ?? this.status,
    statusChangedAt: statusChangedAt ?? this.statusChangedAt,
    coverUrl: coverUrl ?? this.coverUrl,
    description: description,
    pageCount: pageCount,
    chapterCount: chapterCount ?? this.chapterCount,
    isbn13: isbn13,
    isbn10: isbn10,
    publisher: publisher,
    language: language,
    publicationDate: publicationDate,
    publicationDatePrecision: publicationDatePrecision,
    categories: categories,
    categoryCodes: categoryCodes,
    format: format,
    rating: clearRating ? null : (rating ?? this.rating),
    notes: notes ?? this.notes,
    reviewMarkdown: reviewMarkdown ?? this.reviewMarkdown,
    subtitle: subtitle,
    edition: edition,
    binding: binding,
    dimensions: dimensions,
    msrp: msrp,
    msrpCurrency: msrpCurrency,
    excerpt: excerpt,
    related: related,
    annotationCount: annotationCount ?? this.annotationCount,
  );
}

class BookStatusHistoryEntry {
  BookStatusHistoryEntry({
    required this.id,
    required this.status,
    required this.changedAt,
    this.isBaseline = false,
    this.origin = 'transition',
    this.dateConfirmed = true,
  });

  factory BookStatusHistoryEntry.fromJson(Map<String, dynamic> j) =>
      BookStatusHistoryEntry(
        id: j['id'] as String,
        status: j['status'] as String,
        changedAt: DateTime.parse(j['changedAt'] as String),
        isBaseline: (j['isBaseline'] as bool?) ?? false,
        origin:
            (j['origin'] as String?) ??
            (((j['isBaseline'] as bool?) ?? false) ? 'baseline' : 'transition'),
        dateConfirmed:
            (j['dateConfirmed'] as bool?) ??
            !((j['isBaseline'] as bool?) ?? false),
      );

  final String id;
  final String status;
  final DateTime changedAt;
  final bool isBaseline;
  final String origin;
  final bool dateConfirmed;

  BookStatusHistoryEntry copyWith({
    DateTime? changedAt,
    bool? isBaseline,
    String? origin,
    bool? dateConfirmed,
  }) => BookStatusHistoryEntry(
    id: id,
    status: status,
    changedAt: changedAt ?? this.changedAt,
    isBaseline: isBaseline ?? this.isBaseline,
    origin: origin ?? this.origin,
    dateConfirmed: dateConfirmed ?? this.dateConfirmed,
  );
}

class BookStatusHistoryPage {
  BookStatusHistoryPage({required this.items, this.nextCursor});

  factory BookStatusHistoryPage.fromJson(Map<String, dynamic> j) =>
      BookStatusHistoryPage(
        items: ((j['items'] as List?) ?? const [])
            .map(
              (e) => BookStatusHistoryEntry.fromJson(
                e as Map<String, dynamic>,
              ),
            )
            .toList(),
        nextCursor: j['nextCursor'] as String?,
      );

  final List<BookStatusHistoryEntry> items;
  final String? nextCursor;
}

class ReadingEvent {
  ReadingEvent({
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.type,
    required this.title,
    required this.dateLocal,
    required this.status,
    this.description = '',
    this.bookId,
    this.timeLocal,
    this.tz,
    this.targetChapter,
    this.targetPage,
    this.reminderEnabled = true,
    this.reminderMinutesBefore,
    this.seenAt,
    this.muted = false,
    this.createdAt,
    this.updatedAt,
    this.planId,
  });

  factory ReadingEvent.fromJson(Map<String, dynamic> j) {
    final raw = j['dateLocal'] as String;
    final dl = raw.length == 10
        ? DateTime.parse('${raw}T00:00:00Z')
        : DateTime.parse(raw);
    return ReadingEvent(
      id: j['id'] as String,
      ownerType: j['ownerType'] as String,
      ownerId: j['ownerId'] as String,
      bookId: j['bookId'] as String?,
      type: j['type'] as String,
      title: j['title'] as String,
      description: (j['description'] as String?) ?? '',
      dateLocal: dl,
      timeLocal: j['timeLocal'] as String?,
      tz: j['tz'] as String?,
      targetChapter: j['targetChapter'] as int?,
      targetPage: j['targetPage'] as int?,
      status: j['status'] as String,
      reminderEnabled: (j['reminderEnabled'] as bool?) ?? true,
      reminderMinutesBefore: j['reminderMinutesBefore'] as int?,
      seenAt: j['seenAt'] == null
          ? null
          : DateTime.parse(j['seenAt'] as String),
      muted: (j['muted'] as bool?) ?? false,
      createdAt: j['createdAt'] == null
          ? null
          : DateTime.parse(j['createdAt'] as String),
      updatedAt: j['updatedAt'] == null
          ? null
          : DateTime.parse(j['updatedAt'] as String),
      planId: j['planId'] as String?,
    );
  }

  final String id;
  final String ownerType;
  final String ownerId;
  final String? bookId;
  final String type;
  final String title;
  final String description;

  /// Calendar day in the event's tz (or floating for all-day). Stored UTC midnight.
  final DateTime dateLocal;

  /// "HH:MM" in tz; null = all-day.
  final String? timeLocal;

  /// IANA tz; required iff timeLocal != null.
  final String? tz;
  final int? targetChapter;
  final int? targetPage;
  final String status;
  final bool reminderEnabled;

  /// Minutes before the event. null = no reminder.
  final int? reminderMinutesBefore;
  final DateTime? seenAt;
  final bool muted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The reading-plan run that created this event (spec §6.9), or null for a
  /// hand-made event. Lets the replanner load the live events of a plan and
  /// re-space the pending ones. See `features/plan/domain/replan.dart`.
  final String? planId;

  bool get isAllDay => timeLocal == null;
  bool get isInformational =>
      type == 'start' ||
      type == 'finish' ||
      type == 'abandoned' ||
      type == 'release';
  bool get isCompletable => !isInformational;
}

class EventUserState {
  EventUserState({
    required this.eventId,
    required this.status,
    required this.reminderEnabled,
    required this.muted,
    this.seenAt,
    this.completedAt,
    this.reminderMinutesBefore,
  });

  factory EventUserState.fromJson(Map<String, dynamic> j) => EventUserState(
    eventId: j['eventId'] as String,
    status: j['status'] as String,
    seenAt: j['seenAt'] == null ? null : DateTime.parse(j['seenAt'] as String),
    completedAt: j['completedAt'] == null
        ? null
        : DateTime.parse(j['completedAt'] as String),
    reminderEnabled: (j['reminderEnabled'] as bool?) ?? true,
    reminderMinutesBefore: j['reminderMinutesBefore'] as int?,
    muted: (j['muted'] as bool?) ?? false,
  );
  final String eventId;
  final String status;
  final DateTime? seenAt;
  final DateTime? completedAt;
  final bool reminderEnabled;
  final int? reminderMinutesBefore;
  final bool muted;

  bool get isModified => seenAt == null;
  bool get isCompleted => status == 'completed';
}

class Progress {
  Progress({
    required this.bookEntryId,
    this.currentPage,
    this.currentChapter,
    this.currentPercentage,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();
  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
    bookEntryId: (j['bookEntryId'] as String?) ?? '',
    currentPage: j['currentPage'] as int?,
    currentChapter: j['currentChapter'] as int?,
    currentPercentage: j['currentPercentage'] as int?,
    updatedAt: j['updatedAt'] == null
        ? DateTime.now()
        : DateTime.parse(j['updatedAt'] as String),
  );
  final String bookEntryId;
  final int? currentPage;
  final int? currentChapter;
  final int? currentPercentage;
  final DateTime updatedAt;
}

/// Unified book annotation (note, theory, question, or quote). Mirrors the
/// backend `Annotation` DTO. Legacy quote JSON (`text`/`note`/`favorite`) is
/// still accepted on read.

/// Matches backend `annotation.MaxBodyLen`.
const int kAnnotationMaxBodyLen = 250000;

bool annotationBodyExceedsLimit(String body) =>
    body.trim().runes.length > kAnnotationMaxBodyLen;

class Annotation {
  Annotation({
    required this.id,
    required this.bookId,
    String? body,
    String? text,
    this.category = AnnotationCategory.quote,
    String commentary = '',
    String note = '',
    this.page,
    this.chapter,
    this.spoiler = false,
    this.pinned = false,
    this.favorite = false,
    this.pinnedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.bookTitle = '',
    this.bookAuthors = const [],
    this.bookCoverUrl = '',
    this.isbn13 = '',
  }) : body = body ?? text ?? '',
       commentary = commentary.isNotEmpty ? commentary : note,
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Annotation.fromJson(Map<String, dynamic> j) {
    return Annotation(
      id: (j['id'] as String?) ?? '',
      bookId: (j['bookId'] as String?) ?? '',
      category: AnnotationCategory.fromWire(j['category'] as String?),
      body: (j['body'] as String?) ?? (j['text'] as String?) ?? '',
      commentary: (j['commentary'] as String?) ?? (j['note'] as String?) ?? '',
      page: (j['page'] as num?)?.toInt(),
      chapter: (j['chapter'] as num?)?.toInt(),
      spoiler: (j['spoiler'] as bool?) ?? false,
      pinned: (j['pinned'] as bool?) ?? false,
      favorite: (j['favorite'] as bool?) ?? false,
      pinnedAt: j['pinnedAt'] == null
          ? null
          : DateTime.tryParse(j['pinnedAt'] as String),
      createdAt: j['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(j['createdAt'] as String),
      updatedAt: j['updatedAt'] == null
          ? DateTime.now()
          : DateTime.parse(j['updatedAt'] as String),
      bookTitle: (j['bookTitle'] as String?) ?? '',
      bookAuthors: ((j['bookAuthors'] as List?) ?? const []).cast<String>(),
      bookCoverUrl: (j['bookCoverUrl'] as String?) ?? '',
      isbn13: (j['isbn13'] as String?) ?? '',
    );
  }

  final String id;
  final String bookId;
  final AnnotationCategory category;
  final String body;
  final String commentary;
  final int? page;
  final int? chapter;
  final bool spoiler;
  final bool pinned;
  final bool favorite;
  final DateTime? pinnedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String bookTitle;
  final List<String> bookAuthors;
  final String bookCoverUrl;
  final String isbn13;

  /// Legacy aliases used by quote UI/tests while call sites migrate.
  String get text => body;
  String get note => commentary;
  bool get hasCommentary => commentary.trim().isNotEmpty;
  bool get hasNote => hasCommentary;

  Annotation copyWith({
    String? body,
    String? text,
    AnnotationCategory? category,
    String? commentary,
    String? note,
    int? Function()? page,
    int? Function()? chapter,
    bool? spoiler,
    bool? pinned,
    bool? favorite,
    DateTime? Function()? pinnedAt,
    DateTime? updatedAt,
  }) => Annotation(
    id: id,
    bookId: bookId,
    category: category ?? this.category,
    body: body ?? text ?? this.body,
    commentary: commentary ?? note ?? this.commentary,
    page: page != null ? page() : this.page,
    chapter: chapter != null ? chapter() : this.chapter,
    spoiler: spoiler ?? this.spoiler,
    pinned: pinned ?? this.pinned,
    favorite: favorite ?? this.favorite,
    pinnedAt: pinnedAt != null ? pinnedAt() : this.pinnedAt,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    bookTitle: bookTitle,
    bookAuthors: bookAuthors,
    bookCoverUrl: bookCoverUrl,
    isbn13: isbn13,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookId': bookId,
    'category': category.wire,
    'body': body,
    if (commentary.isNotEmpty) 'commentary': commentary,
    if (page != null) 'page': page,
    if (chapter != null) 'chapter': chapter,
    'spoiler': spoiler,
    'pinned': pinned,
    'favorite': favorite,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// Legacy name for [Annotation]. Prefer [Annotation] in new code.
typedef Quote = Annotation;

class NotificationPreferences {
  NotificationPreferences({
    required this.globalEnabled,
    required this.defaultReminderMinutesBefore,
    required this.allDayReminderHour,
  });
  factory NotificationPreferences.fromJson(Map<String, dynamic> j) =>
      NotificationPreferences(
        globalEnabled: (j['globalEnabled'] as bool?) ?? true,
        defaultReminderMinutesBefore:
            (j['defaultReminderMinutesBefore'] as int?) ?? 1440,
        allDayReminderHour: (j['allDayReminderHour'] as int?) ?? 9,
      );
  final bool globalEnabled;
  final int defaultReminderMinutesBefore;
  final int allDayReminderHour;
}

class SearchHit {
  SearchHit({
    required this.title,
    required this.authors,
    this.subtitle = '',
    this.coverUrl = '',
    this.description = '',
    this.isbn = '',
    this.publisher = '',
    this.language = '',
    this.categories = const [],
    this.categoryCodes = const [],
    this.pageCount,
    this.binding = '',
    this.edition = '',
    this.format,
    this.publicationDate,
    this.publicationDatePrecision = '',
  });
  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
    title: (j['Title'] ?? j['title'] ?? '') as String,
    authors: ((j['Authors'] ?? j['authors'] ?? const <Object?>[]) as List)
        .cast<String>(),
    subtitle: ((j['Subtitle'] ?? j['subtitle'] ?? '') as String).trim(),
    coverUrl: (j['CoverURL'] ?? j['coverUrl'] ?? '') as String,
    description: (j['Description'] ?? j['description'] ?? '') as String,
    isbn: (j['ISBN'] ?? j['isbn'] ?? '') as String,
    publisher: (j['Publisher'] ?? j['publisher'] ?? '') as String,
    language: (j['Language'] ?? j['language'] ?? '') as String,
    categories:
        (((j['Categories'] ?? j['categories']) as List?) ?? const <Object?>[])
            .cast<String>(),
    categoryCodes:
        (((j['CategoryCodes'] ?? j['categoryCodes']) as List?) ??
                const <Object?>[])
            .cast<String>(),
    pageCount: (j['PageCount'] ?? j['pageCount']) as int?,
    binding: (j['Binding'] ?? j['binding'] ?? '') as String,
    edition: (j['Edition'] ?? j['edition'] ?? '') as String,
    format: (j['Format'] ?? j['format']) as String?,
    publicationDate: _searchHitDate(
      j['publicationDate'] ?? j['PublicationDate'],
    ),
    publicationDatePrecision:
        ((j['PublicationDatePrecision'] ?? j['publicationDatePrecision'] ?? '')
                as String)
            .trim(),
  );
  final String title;
  final String subtitle;
  final List<String> authors;
  final String coverUrl;
  final String description;
  final String isbn;
  final String publisher;
  final String language;
  final List<String> categories;
  final List<String> categoryCodes;
  final int? pageCount;
  final String binding;
  final String edition;
  final String? format;
  final DateTime? publicationDate;
  final String publicationDatePrecision;

  /// Dedupes preferred-language pages against later all-languages pages.
  String get dedupeKey {
    final id = isbn.trim();
    if (id.isNotEmpty) return 'isbn:$id';
    final author = authors.isNotEmpty ? authors.first : '';
    return 't:${title.trim().toLowerCase()}|$author'.toLowerCase();
  }

  SearchHit copyWith({
    String? title,
    List<String>? authors,
    String? subtitle,
    String? coverUrl,
    String? description,
    String? isbn,
    String? publisher,
    String? language,
    List<String>? categories,
    List<String>? categoryCodes,
    int? pageCount,
    String? binding,
    String? edition,
    String? format,
    DateTime? publicationDate,
    String? publicationDatePrecision,
  }) => SearchHit(
    title: title ?? this.title,
    authors: authors ?? this.authors,
    subtitle: subtitle ?? this.subtitle,
    coverUrl: coverUrl ?? this.coverUrl,
    description: description ?? this.description,
    isbn: isbn ?? this.isbn,
    publisher: publisher ?? this.publisher,
    language: language ?? this.language,
    categories: categories ?? this.categories,
    categoryCodes: categoryCodes ?? this.categoryCodes,
    pageCount: pageCount ?? this.pageCount,
    binding: binding ?? this.binding,
    edition: edition ?? this.edition,
    format: format ?? this.format,
    publicationDate: publicationDate ?? this.publicationDate,
    publicationDatePrecision:
        publicationDatePrecision ?? this.publicationDatePrecision,
  );
}

DateTime? _searchHitDate(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}

/// One page from `GET /v1/search/books`.
class SearchPage {
  const SearchPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
    this.total = 0,
  });

  factory SearchPage.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List?) ?? const [];
    int asInt(Object? v, int fallback) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return fallback;
    }

    return SearchPage(
      items: items
          .map((e) => SearchHit.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: asInt(j['page'], 1),
      limit: asInt(j['limit'], 20),
      total: asInt(j['total'], 0),
      hasMore: j['hasMore'] == true,
    );
  }

  final List<SearchHit> items;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;
}

/// Per-row outcome of a bulk event create (POST /v1/events/batch). Index-aligned
/// to the posted events. `outcome` is "created" (with `id`) or "failed" (`error`).
class EventBatchResult {
  EventBatchResult({
    required this.index,
    required this.outcome,
    this.id = '',
    this.error = '',
  });

  factory EventBatchResult.fromJson(Map<String, dynamic> j) => EventBatchResult(
    index: (j['index'] as int?) ?? 0,
    outcome: (j['outcome'] as String?) ?? '',
    id: (j['id'] as String?) ?? '',
    error: (j['error'] as String?) ?? '',
  );

  final int index;
  final String outcome;
  final String id;
  final String error;

  bool get isCreated => outcome == 'created';
}

/// A reading-plan run (spec §6.9): groups the events created by one "Planificar"
/// generation so the book detail can show a history and each run can be undone.
/// `startDate`/`endDate` are date-only (parsed at UTC midnight).
class PlanRun {
  PlanRun({
    required this.id,
    required this.bookId,
    required this.eventCount,
    required this.mode,
    required this.unit,
    required this.createdAt,
    this.perDay,
    this.startDate,
    this.endDate,
    this.total,
    this.startUnit,
    this.excludedWeekdays,
    this.remindersOn,
    this.includeStart,
    this.includeFinish,
    this.anchorEventId,
    this.anchorEventTitle,
  });

  factory PlanRun.fromJson(Map<String, dynamic> j) => PlanRun(
    id: j['id'] as String,
    bookId: j['bookId'] as String,
    eventCount: (j['eventCount'] as num?)?.toInt() ?? 0,
    mode: (j['mode'] as String?) ?? '',
    unit: (j['unit'] as String?) ?? '',
    perDay: (j['perDay'] as num?)?.toInt(),
    startDate: _parseDate(j['startDate']),
    endDate: _parseDate(j['endDate']),
    total: (j['total'] as num?)?.toInt(),
    startUnit: (j['startUnit'] as num?)?.toInt(),
    excludedWeekdays: (j['excludedWeekdays'] as List?)
        ?.map((value) => (value as num).toInt())
        .toSet(),
    remindersOn: j['remindersOn'] as bool?,
    includeStart: j['includeStart'] as bool?,
    includeFinish: j['includeFinish'] as bool?,
    anchorEventId: j['anchorEventId'] as String?,
    anchorEventTitle: j['anchorEventTitle'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  final String id;
  final String bookId;
  final int eventCount;

  /// Generator mode: "pace" | "deadline" | "before_event".
  final String mode;

  /// Generator unit, e.g. "chapters" | "pages".
  final String unit;
  final int? perDay;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? total;
  final int? startUnit;
  final Set<int>? excludedWeekdays;
  final bool? remindersOn;
  final bool? includeStart;
  final bool? includeFinish;
  final String? anchorEventId;
  final String? anchorEventTitle;
  final DateTime createdAt;

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return raw.length == 10
        ? DateTime.parse('${raw}T00:00:00Z')
        : DateTime.parse(raw);
  }
}

/// One row of a batch-create outcome, index-aligned to the posted items.
class AnnotationBatchRowResult {
  AnnotationBatchRowResult({
    required this.index,
    required this.outcome,
    this.id,
    this.error,
  });

  factory AnnotationBatchRowResult.fromJson(Map<String, dynamic> j) =>
      AnnotationBatchRowResult(
        index: (j['index'] as int?) ?? 0,
        outcome: (j['outcome'] as String?) ?? 'failed',
        id: j['id'] as String?,
        error: j['error'] as String?,
      );
  final int index;
  final String outcome; // 'created' | 'failed'
  final String? id;
  final String? error;
  bool get created => outcome == 'created';
}

/// One item of a batch create (Kindle clippings import).
class AnnotationBatchItem {
  AnnotationBatchItem({
    required this.bookId,
    String? body,
    String? text,
    this.page,
    this.category = AnnotationCategory.quote,
  }) : body = body ?? text ?? '';
  final String bookId;
  final String body;
  final int? page;
  final AnnotationCategory category;
  Map<String, dynamic> toJson() => {
    'bookId': bookId,
    'body': body,
    'category': category.wire,
    if (page != null) 'page': page,
  };
}

typedef QuoteBatchRowResult = AnnotationBatchRowResult;
typedef QuoteBatchItem = AnnotationBatchItem;
