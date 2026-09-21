import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/data/catalog/catalog_client.dart';
import '../../helpers/api_repo_stubs.dart';

ApiClient catalogImportTestApi() => ApiClient(
  baseUrl: 'http://localhost',
  storage: _MemTokens(),
  localeProvider: () => 'es',
);

class FakeCatalogSearch extends ApiSearchRepository {
  FakeCatalogSearch({
    this.hits = const {},
    this.fail = false,
    this.failTimes = 0,
  }) : super(catalog: CatalogClient(dio: Dio()));

  final Map<String, SearchHit> hits;
  final bool fail;
  final int failTimes;
  int enrichCalls = 0;
  int _failures = 0;

  @override
  Future<Result<SearchHit?>> enrich({
    String isbn = '',
    String title = '',
    List<String> authors = const [],
    String coverUrl = '',
    List<String> categories = const [],
    List<String> categoryCodes = const [],
  }) async {
    enrichCalls++;
    if (fail) return const Err(NetworkFailure());
    if (_failures < failTimes) {
      _failures++;
      return const Err(NetworkFailure());
    }
    if (isbn.isNotEmpty && hits.containsKey(isbn)) return Ok(hits[isbn]);
    return const Ok(null);
  }
}

class FakeCatalogBooks extends ApiBookRepository {
  FakeCatalogBooks({this.failCreates = false, this.createDelay})
    : super(catalogImportTestApi());

  final bool failCreates;
  final Duration? createDelay;
  final List<Map<String, dynamic>> creates = [];
  final ratings = <String, ({double? rating, String review})>{};
  int inFlight = 0;
  int maxInFlight = 0;

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
    inFlight++;
    maxInFlight = math.max(maxInFlight, inFlight);
    if (createDelay != null) await Future<void>.delayed(createDelay!);
    inFlight--;
    if (failCreates) return const Err(NetworkFailure());
    final id = 'b${creates.length}';
    creates.add({
      'id': id,
      'title': title,
      'authors': authors,
      'coverUrl': coverUrl,
      'isbn': isbn,
      'pageCount': pageCount,
      'publisher': publisher,
      'language': language,
      'categories': categories,
      'format': format,
      'description': description,
      'edition': edition,
      'binding': binding,
      'publicationDate': publicationDate,
      'publicationDatePrecision': publicationDatePrecision,
      'status': initialStatus,
    });
    return Ok(
      Book(
        id: id,
        ownerType: OwnerType.user,
        ownerId: 'u',
        title: title,
        authors: authors,
        status: initialStatus ?? BookStatus.pending,
        coverUrl: coverUrl,
        isbn13: isbn,
        pageCount: pageCount,
        publisher: publisher ?? '',
        language: language ?? '',
        categories: categories ?? const [],
        categoryCodes: categories ?? const [],
        description: description ?? '',
        edition: edition ?? '',
        binding: binding ?? '',
        format: format,
        publicationDate: publicationDate,
        publicationDatePrecision: publicationDatePrecision ?? '',
      ),
    );
  }

  @override
  Future<Result<Book>> updateRatingReview(
    String id, {
    required double? rating,
    required String reviewMarkdown,
  }) async {
    ratings[id] = (rating: rating, review: reviewMarkdown);
    return Ok(
      Book(
        id: id,
        ownerType: OwnerType.user,
        ownerId: 'u',
        title: id,
        authors: const [],
        status: BookStatus.pending,
        rating: rating,
        reviewMarkdown: reviewMarkdown,
      ),
    );
  }
}

class FakeCatalogNotes extends ApiAnnotationRepository {
  FakeCatalogNotes() : super(catalogImportTestApi());

  final notes = <({String bookId, String body})>[];

  @override
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
  }) async {
    notes.add((bookId: bookId, body: body));
    return Ok(
      Annotation(
        id: 'n${notes.length}',
        bookId: bookId,
        body: body,
        category: category,
      ),
    );
  }
}

class _MemTokens extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}
