import 'dart:io';

import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/book_category_mapping.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/data/local/local_library_repos.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:uuid/uuid.dart';

/// SQLite-backed [BookRepository] used after import / for new installs.
class LocalBookRepository implements BookRepository {
  LocalBookRepository(this._store);

  final LocalStore _store;
  static const _col = LocalCollections.books;
  static const _uuid = Uuid();

  @override
  Future<Result<List<Book>>> listMine() async {
    try {
      final rows = await _store.list(
        _col,
        query: const LocalListQuery(orderByPath: 'libraryOrder'),
      );
      return Ok([for (final row in rows) Book.fromJson(row)]);
    } on Object catch (e) {
      return Err(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<Book>> get(String id) async {
    final row = await _store.get(_col, id);
    if (row == null) return const Err(NotFoundFailure());
    return Ok(Book.fromJson(row));
  }

  @override
  Future<Result<void>> reorder(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final row = await _store.get(_col, ids[i]);
      if (row == null) continue;
      row['libraryOrder'] = i;
      await _store.put(_col, ids[i], row);
    }
    return const Ok(null);
  }

  @override
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
  }) async {
    final id = _uuid.v4();
    final json = <String, dynamic>{
      'id': id,
      'title': title,
      'authors': authors,
      'coverUrl': coverUrl,
      'isbn13': isbn,
      'pageCount': pageCount,
      'chapterCount': chapterCount,
      'publisher': publisher ?? '',
      'language': language ?? '',
      'categories': categories ?? const <String>[],
      'categoryCodes': canonicalCategoryCodes(categories ?? const <String>[]),
      'format': format,
      'description': description ?? '',
      'edition': edition ?? '',
      'binding': binding ?? '',
      'dimensions': dimensions ?? '',
      'msrp': msrp,
      'msrpCurrency': msrpCurrency ?? '',
      'publicationDate': publicationDate?.toUtc().toIso8601String(),
      'publicationDatePrecision': publicationDatePrecision ?? '',
      'status': initialStatus ?? 'pending',
      'ownerType': 'user',
      'ownerId': localGuestUserId,
    };
    final now = DateTime.now().toUtc().toIso8601String();
    json['statusChangedAt'] = now;
    json['libraryOrder'] = await _nextLibraryOrder();
    await _store.put(_col, id, json);
    await _appendStatusHistory(
      bookId: id,
      status: json['status'] as String,
      changedAt: now,
    );
    if (customFieldChanges.isNotEmpty) {
      await applyLocalCustomFieldChanges(_store, id, customFieldChanges);
    }
    return Ok(Book.fromJson(json));
  }

  @override
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
  }) async {
    final row = await _store.get(_col, id);
    if (row == null) return const Err(NotFoundFailure());
    if (title != null) row['title'] = title;
    if (authors != null) row['authors'] = authors;
    if (coverUrl != null) row['coverUrl'] = coverUrl;
    if (description != null) row['description'] = description;
    if (pageCount != null) row['pageCount'] = pageCount;
    if (chapterCount != null) row['chapterCount'] = chapterCount;
    if (isbn != null) row['isbn13'] = isbn;
    if (publisher != null) row['publisher'] = publisher;
    if (language != null) row['language'] = language;
    if (categories != null) {
      row['categories'] = categories;
      row['categoryCodes'] = canonicalCategoryCodes(categories);
    }
    if (format != null) row['format'] = format;
    if (edition != null) row['edition'] = edition;
    if (binding != null) row['binding'] = binding;
    if (dimensions != null) row['dimensions'] = dimensions;
    if (msrp != null) row['msrp'] = msrp;
    if (msrpCurrency != null) row['msrpCurrency'] = msrpCurrency;
    if (publicationDate != null) {
      row['publicationDate'] = publicationDate.toUtc().toIso8601String();
    }
    if (publicationDatePrecision != null) {
      row['publicationDatePrecision'] = publicationDatePrecision;
    }
    await _store.put(_col, id, row);
    if (customFieldChanges.isNotEmpty) {
      await applyLocalCustomFieldChanges(_store, id, customFieldChanges);
    }
    return Ok(Book.fromJson(row));
  }

  @override
  Future<Result<Book>> updateTotals(
    String id, {
    int? pageCount,
    int? chapterCount,
  }) async {
    final row = await _store.get(_col, id);
    if (row == null) return const Err(NotFoundFailure());
    if (pageCount != null) row['pageCount'] = pageCount;
    if (chapterCount != null) row['chapterCount'] = chapterCount;
    await _store.put(_col, id, row);
    return Ok(Book.fromJson(row));
  }

  @override
  Future<Result<Book>> updatePersonal(
    String id, {
    required double? rating,
  }) async {
    final row = await _store.get(_col, id);
    if (row == null) return const Err(NotFoundFailure());
    row['rating'] = rating;
    await _store.put(_col, id, row);
    return Ok(Book.fromJson(row));
  }

  @override
  Future<Result<Book>> updateRatingReview(
    String id, {
    required double? rating,
    required String reviewMarkdown,
  }) async {
    final row = await _store.get(_col, id);
    if (row == null) return const Err(NotFoundFailure());
    row['rating'] = rating;
    row['reviewMarkdown'] = reviewMarkdown;
    await _store.put(_col, id, row);
    return Ok(Book.fromJson(row));
  }

  @override
  Future<Result<Book>> finish(
    String id, {
    required String idempotencyKey,
    double? rating,
    String reviewMarkdown = '',
    bool saveRatingReview = false,
  }) async {
    if (saveRatingReview) {
      final rated = await updateRatingReview(
        id,
        rating: rating,
        reviewMarkdown: reviewMarkdown,
      );
      if (rated.isErr) return rated;
    }
    final row = await _store.get(_col, id);
    if (row != null) {
      final pages = (row['pageCount'] as num?)?.toInt();
      final progress =
          await _store.get(LocalCollections.progress, id) ??
          <String, dynamic>{'bookEntryId': id};
      final prevPage = (progress['currentPage'] as num?)?.toInt() ?? 0;
      progress['currentPercentage'] = 100;
      if (pages != null && pages > 0) progress['currentPage'] = pages;
      progress['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await _store.put(LocalCollections.progress, id, progress);
      if (pages != null && pages > prevPage) {
        final activityId = _uuid.v4();
        await _store.put(LocalCollections.pageActivity, activityId, {
          'id': activityId,
          'bookEntryId': id,
          'pages': pages - prevPage,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }
    return changeStatus(id, BookStatus.read);
  }

  @override
  Future<Result<BookStatusHistoryPage>> listStatusHistory(
    String bookId, {
    String? cursor,
    int limit = 20,
  }) async {
    final rows = await _store.list(LocalCollections.bookStatusHistory);
    final items = [
      for (final row in rows)
        if (row['bookId'] == bookId || row['bookEntryId'] == bookId)
          BookStatusHistoryEntry.fromJson(row),
    ]..sort((a, b) => b.changedAt.compareTo(a.changedAt));
    return Ok(BookStatusHistoryPage(items: items.take(limit).toList()));
  }

  @override
  Future<Result<BookStatusHistoryEntry>> updateStatusHistoryChangedAt(
    String bookId,
    String entryId,
    DateTime changedAt,
  ) async {
    final row = await _store.get(LocalCollections.bookStatusHistory, entryId);
    if (row == null) return const Err(NotFoundFailure());
    row['changedAt'] = changedAt.toUtc().toIso8601String();
    await _store.put(LocalCollections.bookStatusHistory, entryId, row);
    return Ok(BookStatusHistoryEntry.fromJson(row));
  }

  @override
  Future<Result<Book>> reread(String id) =>
      changeStatus(id, BookStatus.pending);

  @override
  Future<Result<void>> delete(String id) async {
    await _store.delete(_col, id);
    await _store.delete(LocalCollections.progress, id);
    await _store.delete(LocalCollections.workGroupOverrides, id);
    await _store.delete(LocalCollections.customFieldValues, id);
    await _deleteMatching(LocalCollections.events, id);
    await _deleteMatching(LocalCollections.annotations, id);
    await _deleteMatching(LocalCollections.pageActivity, id);
    await _deleteMatching(LocalCollections.bookStatusHistory, id);
    await _deleteMatching(LocalCollections.planRuns, id);
    final cover = await _store.coverFile(id);
    if (cover.existsSync()) {
      try {
        await cover.delete();
      } on FileSystemException {
        // Image cache may still hold the sidecar.
      }
    }
    return const Ok(null);
  }

  Future<void> _deleteMatching(String collection, String bookId) async {
    final rows = await _store.list(collection);
    for (final row in rows) {
      if (row['bookId'] == bookId || row['bookEntryId'] == bookId) {
        await _store.delete(collection, localRowId(row));
      }
    }
  }

  Future<int> _nextLibraryOrder() async {
    var maxOrder = -1;
    for (final row in await _store.list(_col)) {
      final order = (row['libraryOrder'] as num?)?.toInt() ?? -1;
      if (order > maxOrder) maxOrder = order;
    }
    return maxOrder + 1;
  }

  @override
  Future<Result<Book>> changeStatus(String id, String status) async {
    final row = await _store.get(_col, id);
    if (row == null) return const Err(NotFoundFailure());
    row['status'] = status;
    final changedAt = DateTime.now().toUtc().toIso8601String();
    row['statusChangedAt'] = changedAt;
    await _store.put(_col, id, row);
    await _appendStatusHistory(
      bookId: id,
      status: status,
      changedAt: changedAt,
    );
    return Ok(Book.fromJson(row));
  }

  Future<void> _appendStatusHistory({
    required String bookId,
    required String status,
    required String changedAt,
  }) async {
    final historyId = _uuid.v4();
    await _store.put(LocalCollections.bookStatusHistory, historyId, {
      'id': historyId,
      'bookId': bookId,
      'bookEntryId': bookId,
      'status': status,
      'changedAt': changedAt,
      'origin': 'transition',
      'dateConfirmed': true,
    });
  }
}
