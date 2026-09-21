// Repository ports. HTTP and SQLite adapters implement these; UI depends
// only on the port, never on Dio.

import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/result.dart';


abstract class BookRepository {
  Future<Result<List<Book>>> listMine();

  Future<Result<Book>> get(String id);

  Future<Result<void>> reorder(List<String> ids);

  Future<Result<Book>> create({
      required String title,
      required List<String> authors,
      String coverUrl = '',
      String isbn = '',
      int? pageCount,
      int? chapterCount,
      String? publisher,
      String? language,
      List<String>? categories,
      String? format,
      String? description,
      String? edition,
      String? binding,
      String? dimensions,
      double? msrp,
      String? msrpCurrency,
      DateTime? publicationDate,
      String? publicationDatePrecision,
      String? initialStatus,
      List<CustomFieldChange> customFieldChanges = const [],
    });

  Future<Result<Book>> update(
      String id, {
      String? title,
      List<String>? authors,
      String? coverUrl,
      String? description,
      int? pageCount,
      int? chapterCount,
      String? isbn,
      String? publisher,
      String? language,
      List<String>? categories,
      String? format,
      String? edition,
      String? binding,
      String? dimensions,
      double? msrp,
      String? msrpCurrency,
      DateTime? publicationDate,
      String? publicationDatePrecision,
      List<CustomFieldChange> customFieldChanges = const [],
    });

  Future<Result<Book>> updateTotals(
      String id, {
      int? pageCount,
      int? chapterCount,
    });

  Future<Result<Book>> updatePersonal(
      String id, {
      required double? rating,
    });

  Future<Result<Book>> updateRatingReview(
      String id, {
      required double? rating,
      required String reviewMarkdown,
    });

  Future<Result<Book>> finish(
      String id, {
      required String idempotencyKey,
      double? rating,
      String reviewMarkdown = '',
      bool saveRatingReview = false,
    });

  Future<Result<Book>> changeStatus(String id, String status);

  Future<Result<BookStatusHistoryPage>> listStatusHistory(
      String bookId, {
      String? cursor,
      int limit = 20,
    });

  Future<Result<BookStatusHistoryEntry>> updateStatusHistoryChangedAt(
      String bookId,
      String entryId,
      DateTime changedAt,
    );

  Future<Result<void>> delete(String id);

  Future<Result<Book>> reread(String id);
}

abstract class CustomFieldRepository {
  Future<Result<List<CustomFieldDefinition>>> listDefinitions();

  Future<Result<List<BookCustomField>>> listForBook(String bookId);

  Future<Result<void>> reorder(List<String> ids);

  Future<Result<List<BookDetailFieldLayoutItem>>> listLayout();

  Future<Result<List<BookDetailFieldLayoutItem>>> saveLayout(
      List<BookDetailFieldLayoutItem> items,
    );

  Future<Result<CustomFieldDefinition>> create({
      required String idempotencyKey,
      required String name,
      required String iconKey,
      required String type,
      String textMode = '',
      List<Map<String, dynamic>>? options,
    });

  Future<Result<CustomFieldDefinition>> update(
      String fieldId, {
      required String name,
      required String iconKey,
      required String type,
      String textMode = '',
      List<Map<String, dynamic>>? options,
      List<String> cascadeOptionDeleteIds = const [],
    });

  Future<Result<void>> delete(String fieldId, {bool cascade = false});
}

abstract class EventRepository {
  Future<Result<List<ReadingEvent>>> list({DateTime? from, DateTime? to});

  Future<Result<List<ReadingEvent>>> listForBook(String bookId);

  Future<Result<List<ReadingEvent>>> listAllForBook(String bookId);

  Future<Result<ReadingEvent>> get(String id);

  Future<Result<ReadingEvent>> create({
      required String ownerType,
      required String ownerId,
      required String type,
      required String title,
      required DateTime dateLocal,
      String? bookId,
      String? timeLocal,
      String? tz,
      String description = '',
      int? targetChapter,
      int? targetPage,
      bool reminderEnabled = true,
      int? reminderMinutesBefore,
      String? idempotencyKey,
    });

  Future<Result<List<EventBatchResult>>> createBatch(
      List<Map<String, dynamic>> events, {
      String? idempotencyKey,
    });

  Future<Result<int>> deleteBatch(List<String> ids);

  Future<Result<ReadingEvent>> update(String id, Map<String, dynamic> body);

  Future<Result<ReadingEvent>> complete(String id);

  Future<Result<ReadingEvent>> uncomplete(String id);

  Future<Result<void>> delete(String id);

  Future<Result<EventUserState>> getUserState(String id);

  Future<Result<EventUserState>> markSeen(String id);

  Future<Result<EventUserState>> setMuted(String id, bool muted);

  Future<Result<EventUserState>> setUserReminder(
      String id, {
      required bool enabled,
      int? minutesBefore,
    });
}

abstract class PlanRepository {
  Future<Result<PlanRun>> createPlanRun({
      required String id,
      required String bookId,
      required int eventCount,
      required String mode,
      required String unit,
      int? perDay,
      DateTime? startDate,
      DateTime? endDate,
      int? total,
      int? startUnit,
      Set<int>? excludedWeekdays,
      bool? remindersOn,
      bool? includeStart,
      bool? includeFinish,
      String? anchorEventId,
      String? anchorEventTitle,
    });

  Future<Result<List<PlanRun>>> listPlans(
      String bookId, {
      int limit = 20,
      int offset = 0,
    });

  Future<Result<int>> undoPlan(String planId);
}

abstract class ProgressRepository {
  Future<Result<Progress>> get(String bookId);

  Future<Result<Progress>> update(
      String bookId, {
      int? page,
      int? chapter,
      int? percentage,
    });
}

abstract class AnnotationRepository {
  Future<Result<List<Annotation>>> listMine();

  Future<Result<List<Annotation>>> listForBook(
      String bookId, {
      AnnotationCategory? category,
      String q = '',
    });

  Future<Result<Annotation>> get(String id);

  Future<Result<Annotation>> create({
      required String bookId,
      required String body,
      AnnotationCategory category = AnnotationCategory.quote,
      int? page,
      int? chapter,
      bool pinned = false,
      String commentary = '',
      bool spoiler = false,
      String? text,
      bool favorite = false,
      String note = '',
    });

  Future<Result<Annotation>> update(Annotation a);

  Future<Result<void>> delete(String id);

  Future<Result<List<AnnotationBatchRowResult>>> createBatch(
      List<AnnotationBatchItem> items,
    );
}

abstract class NotificationRepository {
  Future<Result<NotificationPreferences>> get();

  Future<Result<NotificationPreferences>> update({
      bool? globalEnabled,
      int? defaultReminderMinutesBefore,
      int? allDayReminderHour,
    });
}

abstract class ReadingChapterRepository {
  void dispose();

  ReadingChapterStory? cachedStory(ReadingChapterRequest request);

  ReadingChapterArchive? cachedArchive({String kind = 'all'});

  ReadingChapterArchive? cachedLatest();

  Future<Result<ReadingChapterStory>> fetchStory(ReadingChapterRequest request);

  Future<Result<ReadingChapterArchive>> fetchArchive({
      String kind = 'all',
      String after = '',
      int limit = 20,
    });

  Future<Result<ReadingChapterArchive>> fetchLatest();

  Future<Result<void>> markViewed(ReadingChapterRequest request);

  Future<Result<bool>> notificationPreference();

  Future<Result<bool>> saveNotificationPreference(bool enabled);

  Future<Result<ReadingChapterStory>> saveCuration(
      ReadingChapterRequest request, {
      required String expectedSourceRevision,
      required List<ReadingChapterReflection> reflections,
      required Set<String> safeToRevealPrompts,
    });

  Future<Result<void>> saveGrouping({
      required String mode,
      required List<String> entryIds,
    });

  Future<Result<void>> resetGrouping(List<String> entryIds);
}

typedef QuoteRepository = AnnotationRepository;

abstract class AuthRepository {
  Future<Result<MagicLinkRequestResult>> requestMagicLink({
    required String email,
    required String locale,
  });

  Future<Result<AuthSession>> verifyMagicLink({
    required String token,
    required String locale,
  });

  Future<Result<AuthSession>> signInGoogle({
    required String idToken,
    required String locale,
  });

  Future<Result<AuthSession>> signInApple({
    required String idToken,
    required String locale,
    String? name,
  });

  Future<Result<void>> logout();
}

abstract class UserRepository {
  Future<Result<AppUser>> getMe();

  Future<Result<AppUser>> updateMe({
    String? displayName,
    String? preferredLocale,
    String? timezone,
    bool completeOnboarding = false,
    String? acceptedTermsVersion,
    bool? analyticsEnabled,
    String? analyticsNoticeVersion,
    bool? autoCreateStatusEvents,
    bool? alwaysShowSpoilerQuotes,
    BannerStyle? homeBanner,
  });

  Future<Result<UserStats>> myStats({
    PageActivityQuery query = const PageActivityQuery(),
  });

  Future<Result<String>> exportData();
}

abstract class SearchRepository {
  Future<Result<SearchPage>> search(
    String query, {
    String? column,
    int page = 1,
    int limit = 20,
    bool allLanguages = false,
  });

  Future<Result<SearchHit?>> lookupByIsbn(String isbn);

  Future<Result<SearchHit?>> enrich({
    String isbn = '',
    String title = '',
    List<String> authors = const [],
    String coverUrl = '',
    List<String> categories = const [],
    List<String> categoryCodes = const [],
  });
}

abstract class UploadRepository {
  Future<Result<String>> uploadBookCover(String bookId, String filePath);
}
