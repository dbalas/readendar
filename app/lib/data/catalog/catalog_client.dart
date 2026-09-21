import 'dart:async';

import 'package:dio/dio.dart';
import 'package:readendar/core/models/book_category_mapping.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/data/catalog/catalog_enrich.dart';
import 'package:readendar/data/catalog/catalog_language.dart';
import 'package:readendar/data/catalog/catalog_title.dart';

/// Aggregates Empathy / Casa del Libro, Open Library, BNE, and Wikidata.
/// No API keys. Google Books and ISBNdb stay off this client.
Dio publicHttpClient() => Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 20),
    headers: {'User-Agent': openLibraryUserAgent},
  ),
);

/// Open Library search.json / isbn.json should answer well before this.
const catalogPrimaryTimeout = Duration(seconds: 10);

/// Cap for BNE SRU/SPARQL. Hung national-library calls must not block forever,
/// but search always waits this long so BNE hits are not dropped.
const catalogSecondaryTimeout = Duration(seconds: 3);

/// Wikidata is description-only. Do not block ISBN lookup on a slow SPARQL.
const catalogBlurbTimeout = Duration(milliseconds: 700);

/// Cover existence check. Full L.jpg downloads are not required.
const catalogCoverProbeTimeout = Duration(seconds: 4);

class _CatalogErr {
  DioException? network;
}

class CatalogClient {
  CatalogClient({
    Dio? dio,
    Duration? secondaryTimeout,
    Duration? blurbTimeout,
    Duration? coverProbeTimeout,
    Duration? primaryTimeout,
  }) : _dio = dio ?? publicHttpClient(),
       _secondaryTimeout = secondaryTimeout ?? catalogSecondaryTimeout,
       _blurbTimeout = blurbTimeout ?? catalogBlurbTimeout,
       _coverProbeTimeout = coverProbeTimeout ?? catalogCoverProbeTimeout,
       _primaryTimeout = primaryTimeout ?? catalogPrimaryTimeout;

  final Dio _dio;
  final Duration _secondaryTimeout;
  final Duration _blurbTimeout;
  final Duration _coverProbeTimeout;
  final Duration _primaryTimeout;

  Future<SearchPage> search(String query, {int offset = 0}) async {
    final q = query.trim();
    if (q.isEmpty) {
      return const SearchPage(items: [], page: 1, limit: 20, hasMore: false);
    }
    final isbn = _digitsIsbn(q);
    if (isbn != null) {
      final hit = await lookupIsbn(isbn);
      return SearchPage(
        items: hit == null ? const [] : [hit],
        page: 1,
        limit: 20,
        hasMore: false,
        total: hit == null ? 0 : 1,
      );
    }
    final err = _CatalogErr();
    final olF = _tryOl(err, () => _openLibrarySearch(q, offset: offset));
    final bneF = offset == 0
        ? _tryList(err, () => _bneSearch(q))
        : Future.value(const <SearchHit>[]);
    final empathyF = offset == 0
        ? _tryList(err, () => _empathySearch(q))
        : Future.value(const <SearchHit>[]);
    final ol = await olF;
    final bne = await bneF;
    final empathy = await empathyF;
    final items = _merge(
      ol.items,
      empathy,
      bne,
    ).map(withFallbackCover).toList();
    if (items.isEmpty && err.network != null) throw err.network!;
    return SearchPage(
      items: items,
      page: (offset ~/ 20) + 1,
      limit: 20,
      hasMore: ol.hasMore,
      total: ol.total,
    );
  }

  Future<SearchHit?> lookupIsbn(String raw) async {
    final isbn = _digitsIsbn(raw);
    if (isbn == null) return null;
    final err = _CatalogErr();
    final seed = SearchHit(title: '', authors: const [], isbn: isbn);
    final wikiCancel = CancelToken();
    final olF = _tryHit(err, () => _openLibraryIsbn(isbn, err));
    final bneF = _tryHit(err, () => _bneIsbn(isbn));
    final empathyF = _tryHit(err, () => _empathyIsbn(isbn));
    final wikiF = _tryHit(
      err,
      () => _wikidataIsbn(isbn, cancelToken: wikiCancel),
    );
    final results = await Future.wait([olF, bneF, empathyF]);
    SearchHit? hit;
    for (final extra in results) {
      if (extra == null) continue;
      final stamped = stampIsbn(extra, isbn);
      if (hit == null) {
        hit = withCanonicalCategories(stamped);
        continue;
      }
      if (catalogHitsMatch(seed, stamped) || catalogHitsMatch(hit, stamped)) {
        hit = mergeCatalogHits(hit, stamped);
      }
    }
    if (hit == null || hit.title.trim().isEmpty) {
      if (!wikiCancel.isCancelled) {
        wikiCancel.cancel('catalog isbn miss');
      }
      if (err.network != null) throw err.network!;
      return null;
    }
    if (_needsWikiFill(hit)) {
      SearchHit? wiki;
      try {
        wiki = await wikiF.timeout(_blurbTimeout);
      } on TimeoutException {
        if (!wikiCancel.isCancelled) {
          wikiCancel.cancel('catalog wiki timeout');
        }
      }
      if (wiki != null) {
        final stamped = stampIsbn(wiki, isbn);
        if (catalogHitsMatch(seed, stamped) || catalogHitsMatch(hit, stamped)) {
          hit = mergeCatalogHits(hit, stamped);
        }
      }
    } else if (!wikiCancel.isCancelled) {
      wikiCancel.cancel('catalog wiki unused');
    }
    return _withVerifiedCover(withCanonicalCategories(hit));
  }

  /// Open Library first, then Empathy, BNE, and Wikidata identity matches.
  Future<SearchHit?> enrich({
    String isbn = '',
    String title = '',
    List<String> authors = const [],
    String coverUrl = '',
    List<String> categories = const [],
    List<String> categoryCodes = const [],
  }) async {
    final seed = SearchHit(
      title: title,
      authors: authors,
      isbn: isbn,
      coverUrl: coverUrl,
      categories: categories,
      categoryCodes: categoryCodes,
    );
    final isbnKey = _digitsIsbn(isbn);
    final cleaned = cleanTitle(title);
    final query =
        isbnKey ??
        [
          if (cleaned.isEmpty) title.trim() else cleaned,
          if (authors.isNotEmpty) authors.first.trim(),
        ].where((s) => s.isNotEmpty).join(' ');
    if (query.isEmpty) {
      final coded = withCanonicalCategories(seed);
      return coded.title.trim().isEmpty ? null : coded;
    }
    final err = _CatalogErr();
    final bneF = isbnKey != null
        ? _tryHit(err, () => _bneIsbn(isbnKey)).then(
            (h) => h == null ? const <SearchHit>[] : [h],
          )
        : _tryList(err, () => _bneSearch(query));
    final olF = isbnKey != null
        ? _tryHit(err, () => _openLibraryIsbn(isbnKey, err)).then(
            (h) => h == null ? const <SearchHit>[] : [h],
          )
        : _tryOl(
            err,
            () => _openLibrarySearch(query, offset: 0),
          ).then((page) => page.items);
    final wikiF = isbnKey != null
        ? _tryHit(err, () => _wikidataIsbn(isbnKey)).then(
            (h) => h == null ? const <SearchHit>[] : [h],
          )
        : Future.value(const <SearchHit>[]);
    final empathyF = isbnKey != null
        ? _tryHit(err, () => _empathyIsbn(isbnKey)).then(
            (h) => h == null ? const <SearchHit>[] : [h],
          )
        : _tryList(err, () => _empathySearch(query));
    final bneHits = await bneF;
    final olHits = await olF;
    final wikiHits = await wikiF;
    final empathyHits = await empathyF;

    var hit =
        pickMatchingHit(seed, olHits) ?? pickMatchingHit(seed, empathyHits);
    for (final extra in [...bneHits, ...wikiHits, ...olHits, ...empathyHits]) {
      final stamped = isbnKey == null ? extra : stampIsbn(extra, isbnKey);
      if (hit == null) {
        if (catalogHitsMatch(seed, stamped)) hit = stamped;
        continue;
      }
      if (catalogHitsMatch(seed, stamped) || catalogHitsMatch(hit, stamped)) {
        hit = mergeCatalogHits(hit, stamped);
      }
    }
    if (hit == null) {
      final coded = withCanonicalCategories(seed);
      if (coded.title.trim().isEmpty && err.network != null) {
        throw err.network!;
      }
      return coded.title.trim().isEmpty ? null : coded;
    }
    return _withVerifiedCover(
      withCanonicalCategories(mergeCatalogHits(hit, seed)),
    );
  }

  bool _isNetwork(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;

  Future<List<SearchHit>> _tryList(
    _CatalogErr err,
    Future<List<SearchHit>> Function() body,
  ) async {
    try {
      return await body();
    } on Object catch (e) {
      _rememberSourceError(err, e);
      return const [];
    }
  }

  Future<SearchHit?> _tryHit(
    _CatalogErr err,
    Future<SearchHit?> Function() body,
  ) async {
    try {
      return await body();
    } on Object catch (e) {
      _rememberSourceError(err, e);
      return null;
    }
  }

  Future<({List<SearchHit> items, int total, bool hasMore})> _tryOl(
    _CatalogErr err,
    Future<({List<SearchHit> items, int total, bool hasMore})> Function() body,
  ) async {
    try {
      return await body();
    } on Object catch (e) {
      _rememberSourceError(err, e);
      return (items: const <SearchHit>[], total: 0, hasMore: false);
    }
  }

  void _rememberSourceError(_CatalogErr err, Object e) {
    if (e is DioException && _isNetwork(e)) err.network = e;
  }

  Future<SearchHit> _withVerifiedCover(SearchHit hit) async {
    var current = hasUsableCover(hit.coverUrl) ? hit : withFallbackCover(hit);
    if (isOpenLibraryIsbnCover(current.coverUrl)) {
      final preferred = fallbackCoverUrls(current.isbn);
      if (preferred.isNotEmpty) {
        current = current.copyWith(coverUrl: preferred.first);
      }
    }
    if (!hasUsableCover(current.coverUrl)) return current;
    if (isOpenLibraryCoverId(current.coverUrl) ||
        commonsCoverUrl(current.coverUrl).isNotEmpty) {
      return current;
    }
    if (await _coverOk(current.coverUrl)) return current;
    for (final candidate in fallbackCoverUrls(current.isbn)) {
      if (candidate == current.coverUrl) continue;
      if (await _coverOk(candidate)) {
        return current.copyWith(coverUrl: candidate);
      }
    }
    return current.copyWith(coverUrl: '');
  }

  Future<bool> _coverOk(String url) async {
    final probe = coverProbeUrl(url);
    if (await _coverBytesOk(probe)) return true;
    if (probe != url) return _coverBytesOk(url);
    return false;
  }

  Future<bool> _coverBytesOk(String url) async {
    try {
      final r = await _dio
          .get<List<int>>(
            url,
            options: Options(
              responseType: ResponseType.bytes,
              followRedirects: true,
              validateStatus: (s) => s != null && s >= 200 && s < 400,
              receiveTimeout: _coverProbeTimeout,
              headers: const {'Range': 'bytes=0-4095'},
            ),
          )
          .timeout(_coverProbeTimeout);
      return coverBytesOk(r.data ?? const []);
    } on Object {
      return false;
    }
  }

  Future<SearchHit?> _empathyIsbn(String isbn) async {
    final hits = await _empathySearch(isbn, rows: 5);
    for (final hit in hits) {
      final stamped = stampIsbn(hit, isbn);
      if (isbnComparisonKey(stamped.isbn) == isbnComparisonKey(isbn)) {
        return stamped;
      }
    }
    return null;
  }

  Future<List<SearchHit>> _empathySearch(
    String q, {
    int rows = 20,
  }) async {
    final cancel = CancelToken();
    try {
      final r = await _dio
          .get<Map<String, dynamic>>(
            empathySearchUrl,
            queryParameters: {
              'query': q,
              'store': 'ES',
              'lang': 'es',
              'start': '0',
              'rows': '$rows',
            },
            cancelToken: cancel,
            options: Options(
              headers: const {
                'Origin': empathyOrigin,
                'Accept': 'application/json',
              },
              receiveTimeout: _secondaryTimeout,
              sendTimeout: _secondaryTimeout,
            ),
          )
          .timeout(_secondaryTimeout);
      final content =
          (r.data?['catalog'] as Map?)?['content'] as List? ?? const [];
      final hits = <SearchHit>[];
      for (final raw in content) {
        if (raw is! Map) continue;
        final hit = _hitFromEmpathy(Map<String, dynamic>.from(raw));
        if (hit.title.trim().isEmpty) continue;
        hits.add(hit);
      }
      return hits;
    } on TimeoutException {
      if (!cancel.isCancelled) {
        cancel.cancel('catalog empathy timeout');
      }
      return const [];
    } on DioException {
      return const [];
    }
  }

  SearchHit _hitFromEmpathy(Map<String, dynamic> doc) {
    final isbn = preferIsbn13([
      doc['ean']?.toString() ?? '',
      doc['isbn']?.toString() ?? '',
    ]);
    final image = catalogText(doc['image']);
    final cover = hasUsableCover(image) ? image : casaDelLibroCoverUrl(isbn);
    final binding = catalogText(doc['encuadernation'] ?? doc['binding']);
    final productType = catalogText(doc['productType'] ?? doc['type']);
    final categories = [
      ..._coerceStrings(doc['hierarchicalCategories']),
      ..._coerceStrings(doc['hierarchicalCategory']),
      ..._coerceStrings(doc['categories']),
      ..._coerceStrings(doc['category']),
      ..._coerceStrings(doc['genre']),
      ..._coerceStrings(doc['materias']),
    ];
    final released = parseCatalogPublication(
      doc['dateRelease'] ?? doc['releaseDate'] ?? doc['publicationDate'],
    );
    final year = parseCatalogPublication(
      doc['yearPublication'] ?? doc['year'],
    );
    final pub = preferCatalogDate(
      released.date,
      released.precision,
      year.date,
      year.precision,
    );
    return SearchHit(
      title: catalogText(doc['name'] ?? doc['title']),
      subtitle: catalogText(doc['subtitle'] ?? doc['subtitulo']),
      authors: uniqueCatalogAuthors(_coerceStrings(doc['authors'])),
      isbn: isbn,
      coverUrl: hasUsableCover(cover) ? cover : '',
      publisher: catalogText(doc['editorial'] ?? doc['publisher']),
      binding: binding,
      description: catalogText(
        doc['description'] ?? doc['synopsis'] ?? doc['sinopsis'],
      ),
      language: preferredCatalogLanguage([
        catalogText(doc['language'] ?? doc['lang'] ?? doc['idioma']),
        ..._coerceStrings(doc['languages']),
      ]),
      pageCount: parseCatalogPageCount(
        doc['pages'] ??
            doc['numPages'] ??
            doc['numberOfPages'] ??
            doc['pageCount'] ??
            doc['numPaginas'],
      ),
      categories: categories,
      categoryCodes: canonicalCategoryCodes(categories),
      format: catalogFormatFromProduct(productType, binding),
      edition: catalogText(doc['edition'] ?? doc['edicion']),
      publicationDate: pub.date,
      publicationDatePrecision: pub.precision,
    );
  }

  Future<SearchHit?> _openLibraryIsbn(String isbn, _CatalogErr err) async {
    SearchHit? hit;
    var workKey = '';
    var namedAuthors = false;
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '$openLibraryIsbnUrl/$isbn.json',
        options: Options(receiveTimeout: _primaryTimeout),
      );
      final data = r.data;
      if (data != null) {
        hit = _hitFromOpenLibraryWork(data, isbn: isbn);
        namedAuthors = _openLibraryAuthorNames(data['authors']).isNotEmpty;
        final works = data['works'];
        if (works is List && works.isNotEmpty && works.first is Map) {
          final key = (works.first as Map)['key']?.toString() ?? '';
          if (key.startsWith('/works/')) workKey = key;
        }
      }
    } on DioException catch (e) {
      if (_isNetwork(e)) rethrow;
    }

    final needSearch = hit == null || hit.title.trim().isEmpty || !namedAuthors;
    final workF = workKey.isEmpty || !needSearch
        ? null
        : _tryHit(err, () => _openLibraryWork(workKey, isbn));
    final searchF = needSearch
        ? _tryOl(
            err,
            () => _openLibrarySearch(
              isbn,
              offset: 0,
              restrictToSpanish: false,
            ),
          )
        : null;

    if (workF != null) {
      final work = await workF;
      if (work != null) {
        hit = hit == null ? work : mergeCatalogHits(hit, work);
      }
    }
    if (searchF == null) return hit;

    try {
      final page = await searchF;
      for (final doc in page.items) {
        final stamped = stampIsbn(doc, isbn);
        final sameIsbn =
            isbnComparisonKey(stamped.isbn) == isbnComparisonKey(isbn);
        if (!sameIsbn && (hit == null || !catalogHitsMatch(hit, stamped))) {
          continue;
        }
        hit = hit == null ? stamped : mergeCatalogHits(hit, stamped);
      }
    } on DioException catch (e) {
      if (_isNetwork(e)) rethrow;
    }
    return hit;
  }

  Future<SearchHit?> _openLibraryWork(String key, String isbn) async {
    final wr = await _dio.get<Map<String, dynamic>>(
      'https://openlibrary.org$key.json',
      options: Options(receiveTimeout: _primaryTimeout),
    );
    final work = wr.data;
    if (work == null) return null;
    return _hitFromOpenLibraryWork(work, isbn: isbn);
  }

  Future<({List<SearchHit> items, int total, bool hasMore})> _openLibrarySearch(
    String q, {
    required int offset,
    bool restrictToSpanish = true,
  }) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        openLibrarySearchUrl,
        queryParameters: {
          'q': q,
          if (restrictToSpanish) 'language': 'spa',
          'limit': 20,
          'offset': offset,
          'fields':
              'key,title,subtitle,author_name,cover_i,isbn,publisher,language,number_of_pages_median,first_sentence,subject,first_publish_year,publish_date',
        },
        options: Options(receiveTimeout: _primaryTimeout),
      );
      final docs = (r.data?['docs'] as List?) ?? const [];
      final total = (r.data?['numFound'] as num?)?.toInt() ?? docs.length;
      final items = <SearchHit>[
        for (final raw in docs)
          if (raw is Map<String, dynamic>) _hitFromOpenLibraryDoc(raw),
      ];
      return (
        items: items,
        total: total,
        hasMore: offset + items.length < total,
      );
    } on DioException {
      rethrow;
    }
  }

  Future<List<SearchHit>> _bneSearch(
    String q, {
    CancelToken? cancelToken,
  }) async {
    final cancel = cancelToken ?? CancelToken();
    try {
      final r = await _dio
          .get<String>(
            bneSruBase,
            queryParameters: {
              'operation': 'searchRetrieve',
              'version': '1.2',
              'query': 'alma.all_for_ui="${_sruLiteral(q)}"',
              'recordSchema': 'dc',
              'maximumRecords': '10',
              'startRecord': '1',
            },
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.plain,
              receiveTimeout: _secondaryTimeout,
              sendTimeout: _secondaryTimeout,
            ),
          )
          .timeout(_secondaryTimeout);
      return _parseDc(r.data ?? '');
    } on TimeoutException {
      if (!cancel.isCancelled) {
        cancel.cancel('catalog bne search timeout');
      }
      return const [];
    } on DioException {
      return const [];
    }
  }

  Future<SearchHit?> _bneIsbn(String isbn) async {
    final cancel = CancelToken();
    try {
      return await _bneIsbnUncapped(
        isbn,
        cancelToken: cancel,
      ).timeout(_secondaryTimeout);
    } on TimeoutException {
      if (!cancel.isCancelled) {
        cancel.cancel('catalog bne isbn timeout');
      }
      return null;
    }
  }

  Future<SearchHit?> _bneIsbnUncapped(
    String isbn, {
    required CancelToken cancelToken,
  }) {
    return _firstNonNullHit(
      _bneSparqlIsbn(isbn, cancelToken: cancelToken),
      _bneSruIsbn(isbn, cancelToken: cancelToken),
    ).then((hit) => hit == null ? null : stampIsbn(hit, isbn));
  }

  Future<SearchHit?> _firstNonNullHit(
    Future<SearchHit?> a,
    Future<SearchHit?> b,
  ) {
    final done = Completer<SearchHit?>();
    var pending = 2;
    SearchHit? untitled;
    DioException? network;

    void settle(SearchHit? hit, Object? error) {
      if (done.isCompleted) return;
      if (hit != null && hit.title.trim().isNotEmpty) {
        done.complete(
          untitled == null ? hit : mergeCatalogHits(hit, untitled!),
        );
        return;
      }
      if (hit != null) untitled ??= hit;
      if (error is DioException && _isNetwork(error)) network = error;
      pending--;
      if (pending > 0) return;
      if (untitled != null) {
        done.complete(untitled);
      } else if (network != null) {
        done.completeError(network!);
      } else {
        done.complete(null);
      }
    }

    a.then((hit) => settle(hit, null), onError: (Object e) => settle(null, e));
    b.then((hit) => settle(hit, null), onError: (Object e) => settle(null, e));
    return done.future;
  }

  Future<SearchHit?> _bneSruIsbn(
    String isbn, {
    CancelToken? cancelToken,
  }) async {
    try {
      final r = await _dio.get<String>(
        bneSruBase,
        queryParameters: {
          'operation': 'searchRetrieve',
          'version': '1.2',
          'query': 'alma.isbn="${_sruLiteral(isbn)}"',
          'recordSchema': 'dc',
          'maximumRecords': '1',
          'startRecord': '1',
        },
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: _secondaryTimeout,
          sendTimeout: _secondaryTimeout,
        ),
      );
      final hits = _parseDc(r.data ?? '');
      if (hits.isEmpty) return null;
      return stampIsbn(hits.first, isbn);
    } on DioException {
      return null;
    }
  }

  Future<SearchHit?> _bneSparqlIsbn(
    String isbn, {
    CancelToken? cancelToken,
  }) async {
    try {
      const prefixes = '''
PREFIX bne: <http://datos.bne.es/def/>
PREFIX dcterms: <http://purl.org/dc/terms/>
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
''';
      final query =
          '''
$prefixes
SELECT ?item ?title ?desc ?img ?author ?date ?publisher ?extent ?subject WHERE {
  ?item bne:codigoISBN ?isbn .
  FILTER(REPLACE(STR(?isbn), "-", "") = "$isbn")
  OPTIONAL { ?item dcterms:title ?title }
  OPTIONAL { ?item dcterms:description ?desc }
  OPTIONAL { ?item foaf:depiction ?img }
  OPTIONAL { ?item dcterms:creator ?c . ?c foaf:name ?author }
  OPTIONAL { ?item dcterms:date ?date }
  OPTIONAL { ?item dcterms:publisher ?publisher }
  OPTIONAL { ?item dcterms:extent ?extent }
  OPTIONAL { ?item dcterms:subject ?subject }
}
LIMIT 5
''';
      final r = await _dio.post<Map<String, dynamic>>(
        bneSparqlUrl,
        data: {
          'query': query,
          'format': 'application/sparql-results+json',
        },
        cancelToken: cancelToken,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Accept': 'application/sparql-results+json'},
          receiveTimeout: _secondaryTimeout,
        ),
      );
      final bindings =
          (r.data?['results'] as Map?)?['bindings'] as List? ?? const [];
      if (bindings.isEmpty || bindings.first is! Map) return null;
      final b = Map<String, dynamic>.from(bindings.first as Map);
      String val(String k) {
        final node = b[k];
        if (node is Map && node['value'] != null) {
          return node['value'].toString().trim();
        }
        return '';
      }

      final title = val('title');
      final img = val('img');
      final subjects = [
        if (val('subject').isNotEmpty) val('subject'),
      ];
      final pub = parseCatalogPublication(val('date'));
      if (title.isEmpty && !hasUsableCover(img) && val('desc').isEmpty) {
        return null;
      }
      return SearchHit(
        title: title,
        authors: uniqueCatalogAuthors([
          if (val('author').isNotEmpty) val('author'),
        ]),
        isbn: isbn,
        coverUrl: hasUsableCover(img) ? img : '',
        description: val('desc'),
        publisher: val('publisher'),
        language: 'spa',
        pageCount: parseCatalogPageCount(val('extent')),
        categories: subjects,
        categoryCodes: canonicalCategoryCodes(subjects),
        publicationDate: pub.date,
        publicationDatePrecision: pub.precision,
      );
    } on DioException catch (e) {
      if (_isNetwork(e)) rethrow;
      return null;
    }
  }

  Future<SearchHit?> _wikidataIsbn(
    String isbn, {
    CancelToken? cancelToken,
  }) async {
    try {
      final query =
          '''
SELECT ?item ?desc ?img ?pages ?date WHERE {
  ?item wdt:P212 ?isbn .
  FILTER(REPLACE(STR(?isbn), "-", "") = "$isbn")
  OPTIONAL {
    ?item schema:description ?desc .
    FILTER(LANG(?desc) = "es")
  }
  OPTIONAL { ?item wdt:P18 ?img }
  OPTIONAL { ?item wdt:P1104 ?pages }
  OPTIONAL { ?item wdt:P577 ?date }
}
LIMIT 1
''';
      final r = await _dio.post<Map<String, dynamic>>(
        wikidataSparqlUrl,
        data: {
          'query': query,
          'format': 'json',
        },
        cancelToken: cancelToken,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {'Accept': 'application/sparql-results+json'},
          receiveTimeout: _secondaryTimeout,
        ),
      );
      final bindings =
          (r.data?['results'] as Map?)?['bindings'] as List? ?? const [];
      if (bindings.isEmpty || bindings.first is! Map) return null;
      final b = Map<String, dynamic>.from(bindings.first as Map);
      final node = b['desc'];
      var desc = '';
      if (node is Map && node['value'] != null) {
        desc = node['value'].toString().trim();
      }
      final imgNode = b['img'];
      var img = '';
      if (imgNode is Map && imgNode['value'] != null) {
        img = commonsCoverUrl(imgNode['value'].toString());
      }
      final pagesNode = b['pages'];
      Object? pages;
      if (pagesNode is Map && pagesNode['value'] != null) {
        pages = pagesNode['value'];
      }
      final dateNode = b['date'];
      Object? date;
      if (dateNode is Map && dateNode['value'] != null) {
        date = dateNode['value'];
      }
      final pub = parseCatalogPublication(date);
      if (desc.isEmpty &&
          !hasUsableCover(img) &&
          parseCatalogPageCount(pages) == null &&
          pub.date == null) {
        return null;
      }
      return SearchHit(
        title: '',
        authors: const [],
        isbn: isbn,
        coverUrl: hasUsableCover(img) ? img : '',
        description: desc,
        pageCount: parseCatalogPageCount(pages),
        publicationDate: pub.date,
        publicationDatePrecision: pub.precision,
      );
    } on DioException catch (e) {
      if (_isNetwork(e)) rethrow;
      return null;
    }
  }

  List<SearchHit> _merge(
    Iterable<SearchHit> preferred,
    Iterable<SearchHit> mid,
    Iterable<SearchHit> rest,
  ) {
    final acc = <SearchHit>[];
    for (final hit in [...preferred, ...mid, ...rest]) {
      final key = catalogDedupeKey(hit);
      if (key == 't:|' || key == 'isbn:') continue;
      final coded = withCanonicalCategories(hit);
      final i = acc.indexWhere((e) => catalogHitsMatch(e, coded));
      if (i < 0) {
        acc.add(coded);
      } else {
        acc[i] = mergeCatalogHits(acc[i], coded);
      }
    }
    return acc;
  }

  SearchHit _hitFromOpenLibraryDoc(Map<String, dynamic> doc) {
    final isbns = (doc['isbn'] as List?)?.map((e) => e.toString()) ?? const [];
    final isbn = preferIsbn13(isbns);
    final coverId = doc['cover_i'];
    final coverUrl = coverId is num && coverId > 0
        ? openLibraryCoverIdUrl(coverId.toInt())
        : openLibraryCoverUrl(isbn);
    final subjects = ((doc['subject'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final released = parseCatalogPublication(doc['publish_date']);
    final year = parseCatalogPublication(doc['first_publish_year']);
    final pub = preferCatalogDate(
      released.date,
      released.precision,
      year.date,
      year.precision,
    );
    return SearchHit(
      title: catalogText(doc['title']),
      subtitle: catalogText(doc['subtitle']),
      authors: uniqueCatalogAuthors(
        ((doc['author_name'] as List?) ?? const []).map((e) => e.toString()),
      ),
      coverUrl: hasUsableCover(coverUrl) ? coverUrl : '',
      isbn: isbn,
      publisher: catalogText(doc['publisher']),
      language: preferredCatalogLanguage(
        ((doc['language'] as List?) ?? const []).map((e) => e.toString()),
      ),
      pageCount: parseCatalogPageCount(
        doc['number_of_pages_median'] ?? doc['number_of_pages'],
      ),
      categories: subjects,
      categoryCodes: canonicalCategoryCodes(subjects),
      description: catalogText(doc['first_sentence']),
      publicationDate: pub.date,
      publicationDatePrecision: pub.precision,
    );
  }

  SearchHit _hitFromOpenLibraryWork(
    Map<String, dynamic> data, {
    required String isbn,
  }) {
    var authors = _openLibraryAuthorNames(data['authors']);
    if (authors.isEmpty) {
      final by = catalogText(data['by_statement']);
      if (by.isNotEmpty) authors = [by];
    }
    final subjects = _coerceStrings(
      data['subjects'] ?? data['subject'] ?? data['subject_places'],
    );
    final coverIds = data['covers'];
    var cover = '';
    if (coverIds is List && coverIds.isNotEmpty && coverIds.first is num) {
      final id = (coverIds.first as num).toInt();
      if (id > 0) cover = openLibraryCoverIdUrl(id);
    }
    if (cover.isEmpty) cover = openLibraryCoverUrl(isbn);
    final isbn13 = preferIsbn13([
      isbn,
      ...(((data['isbn_13'] as List?) ?? const []).map((e) => e.toString())),
      ...(((data['isbn_10'] as List?) ?? const []).map((e) => e.toString())),
    ]);
    final pub = parseCatalogPublication(
      data['publish_date'] ?? data['publish_year'] ?? data['copyright_date'],
    );
    return SearchHit(
      title: catalogText(data['title']),
      subtitle: catalogText(data['subtitle']),
      authors: uniqueCatalogAuthors(authors),
      isbn: isbn13.isEmpty ? isbn : isbn13,
      coverUrl: hasUsableCover(cover) ? cover : '',
      publisher: catalogText(data['publishers'] ?? data['publisher']),
      language: preferredCatalogLanguage(
        _openLibraryLanguageCodes(data['languages'] ?? data['language']),
      ),
      pageCount: parseCatalogPageCount(
        data['number_of_pages'] ?? data['pagination'],
      ),
      categories: subjects,
      categoryCodes: canonicalCategoryCodes(subjects),
      description: catalogText(data['description'] ?? data['first_sentence']),
      binding: catalogText(data['physical_format']),
      publicationDate: pub.date,
      publicationDatePrecision: pub.precision,
    );
  }

  List<SearchHit> _parseDc(String xml) {
    final blocks = xml.split(
      RegExp('</(?:srw:)?record>', caseSensitive: false),
    );
    final hits = <SearchHit>[];
    for (final block in blocks) {
      final titles = _dcValues(block, 'title');
      if (titles.isEmpty) continue;
      final creators = _dcValues(block, 'creator');
      final contributors = [
        for (final name in _dcValues(block, 'contributor'))
          _bnePersonName(name),
      ].where((name) => name.isNotEmpty);
      final isbn = preferIsbn13(_dcValues(block, 'identifier'));
      final subjects = _dcValues(block, 'subject');
      final descriptions = _dcValues(block, 'description');
      final publishers = _dcValues(block, 'publisher');
      final languages = _dcValues(block, 'language');
      final formats = _dcValues(block, 'format');
      final pub = parseCatalogPublication(
        _dcValues(block, 'date').firstOrNull,
      );
      int? pages;
      for (final format in formats) {
        pages = parseCatalogPageCount(format);
        if (pages != null) break;
      }
      hits.add(
        SearchHit(
          title: titles.first,
          authors: uniqueCatalogAuthors([
            ...creators,
            ...contributors,
          ]),
          isbn: isbn,
          description: descriptions.firstOrNull ?? '',
          publisher: publishers.firstOrNull ?? '',
          language: preferredCatalogLanguage(languages),
          categories: subjects,
          categoryCodes: canonicalCategoryCodes(subjects),
          pageCount: pages,
          publicationDate: pub.date,
          publicationDatePrecision: pub.precision,
        ),
      );
      if (hits.length >= 10) break;
    }
    return hits;
  }

  List<String> _dcValues(String xml, String localName) {
    return [
      for (final m in RegExp(
        '<dc:$localName>([^<]+)</dc:$localName>',
        caseSensitive: false,
      ).allMatches(xml))
        m.group(1)!.trim(),
    ];
  }

  String _bnePersonName(String raw) {
    return raw
        .replaceFirst(
          RegExp(
            r'\s+(autor|traductor|editor|ilustrador|compiler)\s+\S+$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  List<String> _coerceStrings(Object? v) {
    switch (v) {
      case null:
        return const [];
      case final String s:
        final t = s.trim();
        if (t.isEmpty) return const [];
        if (t.contains('>')) {
          return [
            for (final p in t.split('>'))
              if (p.trim().isNotEmpty) p.trim(),
          ];
        }
        if (t.contains(';')) {
          return [
            for (final p in t.split(';'))
              if (p.trim().isNotEmpty) p.trim(),
          ];
        }
        if (t.contains(',')) {
          return [
            for (final p in t.split(','))
              if (p.trim().isNotEmpty) p.trim(),
          ];
        }
        return [t];
      case final List<Object?> list:
        return [for (final x in list) ..._coerceStrings(x)];
      case final Map<Object?, Object?> map:
        return _coerceStrings(map['value'] ?? map['id'] ?? map['name']);
      default:
        return const [];
    }
  }

  String? _digitsIsbn(String raw) {
    final canonical = normalizeScannedIsbn(raw);
    if (canonical != null) return canonical;
    final d = raw.replaceAll(RegExp('[^0-9Xx]'), '');
    if (d.length == 10 || d.length == 13) return d.toUpperCase();
    return null;
  }

  String _sruLiteral(String raw) =>
      raw.replaceAll('\\', ' ').replaceAll('"', ' ');

  bool _needsWikiFill(SearchHit hit) =>
      hit.description.trim().isEmpty ||
      hit.pageCount == null ||
      hit.publicationDate == null ||
      needsCategoryEnrich(hit.categoryCodes) ||
      !hasUsableCover(hit.coverUrl);

  List<String> _openLibraryLanguageCodes(Object? raw) {
    final out = <String>[];
    void add(String value) {
      var t = value.trim();
      if (t.isEmpty) return;
      const prefix = '/languages/';
      final i = t.toLowerCase().lastIndexOf(prefix);
      if (i >= 0) t = t.substring(i + prefix.length);
      if (t.isNotEmpty) out.add(t);
    }

    if (raw is String) {
      add(raw);
      return out;
    }
    if (raw is! List) return out;
    for (final item in raw) {
      if (item is String) {
        add(item);
        continue;
      }
      if (item is Map) {
        add((item['key'] ?? item['value'] ?? item['code'] ?? '').toString());
      }
    }
    return out;
  }

  List<String> _openLibraryAuthorNames(Object? raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final a in raw) {
      if (a is String) {
        final t = a.trim();
        if (t.isNotEmpty) out.add(t);
        continue;
      }
      if (a is! Map) continue;
      final nested = a['author'];
      final name =
          a['name'] ??
          (nested is Map ? nested['name'] : null) ??
          a['personal_name'];
      if (name == null) continue;
      final t = name.toString().trim();
      if (t.isNotEmpty) out.add(t);
    }
    return out;
  }
}
