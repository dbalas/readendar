import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/models/book_category_mapping.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/data/catalog/catalog_language.dart';
import 'package:readendar/data/catalog/catalog_title.dart';

const minCoverBytes = 2048;

/// Open Library large cover. `default=false` 404s when missing.
String openLibraryCoverUrl(String isbn) {
  final key = isbnComparisonKey(isbn);
  if (key.isEmpty) return '';
  return 'https://covers.openlibrary.org/b/isbn/$key-L.jpg?default=false';
}

String openLibraryCoverIdUrl(int id) =>
    'https://covers.openlibrary.org/b/id/$id-L.jpg?default=false';

/// Casa del Libro imagessl jacket. Missing files 404; the defecto tile is
/// filtered by [isPlaceholderCover].
String casaDelLibroCoverUrl(String isbn) {
  final key = isbnComparisonKey(isbn);
  if (key.length != 13) return '';
  final suffix = key.substring(key.length - 2);
  return 'https://imagessl1.casadellibro.com/a/l/t1/$suffix/$key.jpg';
}

/// Wikimedia Commons / Wikipedia file URLs from Wikidata P18.
String commonsCoverUrl(String raw) {
  final u = raw.trim().replaceFirst(
    RegExp('^http://', caseSensitive: false),
    'https://',
  );
  if (u.isEmpty) return '';
  final host = Uri.tryParse(u)?.host.toLowerCase() ?? '';
  if (host.endsWith('wikimedia.org') || host.endsWith('wikipedia.org')) {
    return u;
  }
  return '';
}

/// ISBN cover order when Open Library did not assign a cover-id: CdL first
/// (Spanish retail jackets), then the Open Library ISBN URL.
List<String> fallbackCoverUrls(String isbn) => [
  for (final url in [casaDelLibroCoverUrl(isbn), openLibraryCoverUrl(isbn)])
    if (url.isNotEmpty) url,
];

/// Smaller Open Library derivative used only to verify the jacket exists.
String coverProbeUrl(String url) {
  final u = url.trim();
  if (!u.contains('covers.openlibrary.org') || !u.contains('-L.jpg')) {
    return u;
  }
  return u.replaceFirst('-L.jpg', '-S.jpg');
}

/// Cover-id jackets are assigned only when Open Library has a file.
/// Search already shows them without a byte probe; ISBN fallback URLs still
/// need a cheap existence check because they 404 often.
bool isOpenLibraryCoverId(String url) {
  final path = url.trim().toLowerCase().split('?').first;
  return path.contains('covers.openlibrary.org') && path.contains('/b/id/');
}

bool isOpenLibraryIsbnCover(String url) {
  final path = url.trim().toLowerCase().split('?').first;
  return path.contains('covers.openlibrary.org') && path.contains('/b/isbn/');
}

/// True for a jacket we should keep when merging: cover-id, CdL, Commons.
/// Speculative Open Library ISBN URLs 404 often and must not block Empathy.
bool isStrongCatalogCover(String url) {
  if (!hasUsableCover(url)) return false;
  return !isOpenLibraryIsbnCover(url);
}

bool isPlaceholderCover(String raw) {
  final u = raw.trim().toLowerCase();
  if (u.isEmpty) return true;
  final path = u.split('?').first;
  if (path.endsWith('.gif')) return true;
  if (u.contains('defecto')) return true;
  if (u.contains('cegal.') || u.contains('/marcadas/')) return true;
  if (u.contains('no-image') ||
      u.contains('no_image') ||
      u.contains('nophoto') ||
      u.contains('no_cover') ||
      u.contains('no-cover') ||
      u.contains('nocover')) {
    return true;
  }
  return false;
}

bool hasUsableCover(String url) => !isPlaceholderCover(url);

/// Stable merge key: canonical ISBN, else cleaned title + authors.
String catalogDedupeKey(SearchHit hit) {
  final isbn = isbnComparisonKey(hit.isbn);
  if (isbn.isNotEmpty) return 'isbn:$isbn';
  final author = foldKey(hit.authors.isEmpty ? '' : hit.authors.first);
  return 't:${foldKey(cleanTitle(hit.title))}|$author';
}

String preferIsbn13(Iterable<String> raw) {
  var fallback = '';
  for (final value in raw) {
    final key = isbnComparisonKey(value);
    if (key.isEmpty) continue;
    if (key.startsWith('978') || key.startsWith('979')) return key;
    if (fallback.isEmpty) fallback = key;
  }
  return fallback;
}

SearchHit stampIsbn(SearchHit hit, String isbn) {
  if (hit.isbn.trim().isNotEmpty) return hit;
  final key = isbnComparisonKey(isbn);
  if (key.isEmpty) return hit;
  return hit.copyWith(isbn: key);
}

SearchHit withFallbackCover(SearchHit hit) {
  if (hasUsableCover(hit.coverUrl)) return hit;
  final urls = fallbackCoverUrls(hit.isbn);
  if (urls.isEmpty) return hit;
  return hit.copyWith(coverUrl: urls.first);
}

List<String> uniqueCatalogAuthors(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final a in raw) {
    final t = a.trim();
    if (t.isEmpty) continue;
    final key = foldKey(t);
    if (key.isEmpty || !seen.add(key)) continue;
    out.add(t);
  }
  return out;
}

/// True when [hit] is the same work as [seed]: shared ISBN, or the same
/// cleaned title with overlapping authors. Empty identity never matches.
bool catalogHitsMatch(SearchHit seed, SearchHit hit) {
  final seedIsbn = isbnComparisonKey(seed.isbn);
  final hitIsbn = isbnComparisonKey(hit.isbn);
  if (seedIsbn.isNotEmpty && hitIsbn.isNotEmpty && seedIsbn == hitIsbn) {
    return true;
  }
  final seedTitle = foldKey(cleanTitle(seed.title));
  final hitTitle = foldKey(cleanTitle(hit.title));
  if (seedTitle.isEmpty || hitTitle.isEmpty || seedTitle != hitTitle) {
    return false;
  }
  return authorsOverlap(seed.authors, hit.authors);
}

bool authorsOverlap(List<String> a, List<String> b) {
  final ka = authorMatchKeys(a);
  final kb = authorMatchKeys(b);
  if (ka.isEmpty || kb.isEmpty) return false;
  for (final x in ka) {
    for (final y in kb) {
      if (x == y) return true;
      if (x.length >= 5 && y.length >= 5 && (x.contains(y) || y.contains(x))) {
        return true;
      }
    }
  }
  return false;
}

List<String> authorMatchKeys(List<String> authors) {
  final seen = <String>{};
  final out = <String>[];
  void add(String k) {
    if (k.length < 4 || !seen.add(k)) return;
    out.add(k);
  }

  for (final a in authors) {
    for (final part in a.split(RegExp('[/;,+&]'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final folded = foldKey(trimmed);
      if (folded.isNotEmpty) add(folded);
      final fields = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
      if (fields.isNotEmpty) add(foldKey(fields.last));
    }
  }
  return out;
}

/// Fills empty fields from [fill] without overwriting a richer [primary].
/// Existing covers and validated category codes stay on the primary.
SearchHit mergeCatalogHits(SearchHit primary, SearchHit fill) {
  final cover = isStrongCatalogCover(primary.coverUrl)
      ? primary.coverUrl
      : (hasUsableCover(fill.coverUrl) ? fill.coverUrl : primary.coverUrl);
  final rawCategories = <String>[
    ...primary.categories,
    ...fill.categories,
  ];
  final primaryCodes = needsCategoryEnrich(primary.categoryCodes)
      ? const <String>[]
      : [
          for (final c in primary.categoryCodes)
            if (bookCategoryCodes.contains(resolveBookCategoryCode(c)))
              resolveBookCategoryCode(c),
        ];
  final codes = primaryCodes.isNotEmpty
      ? primaryCodes
      : canonicalCategoryCodes([
          ...primary.categoryCodes,
          ...fill.categoryCodes,
          ...rawCategories,
        ]);
  final date = preferCatalogDate(
    primary.publicationDate,
    primary.publicationDatePrecision,
    fill.publicationDate,
    fill.publicationDatePrecision,
  );
  final title = _prefer(primary.title, fill.title);
  return SearchHit(
    title: title,
    authors: primary.authors.isNotEmpty ? primary.authors : fill.authors,
    subtitle: _prefer(primary.subtitle, fill.subtitle),
    coverUrl: cover,
    description: _preferLonger(primary.description, fill.description),
    isbn: preferIsbn13([primary.isbn, fill.isbn]),
    publisher: _prefer(primary.publisher, fill.publisher),
    language: preferredCatalogLanguage([primary.language, fill.language]),
    categories: rawCategories.toSet().toList(),
    categoryCodes: codes,
    pageCount: primary.pageCount ?? fill.pageCount,
    binding: _prefer(primary.binding, fill.binding),
    edition: _prefer(primary.edition, fill.edition),
    format: primary.format ?? fill.format,
    publicationDate: date.date,
    publicationDatePrecision: date.precision,
  );
}

SearchHit withCanonicalCategories(SearchHit hit) {
  if (!needsCategoryEnrich(hit.categoryCodes)) return hit;
  final codes = canonicalCategoryCodes([
    ...hit.categoryCodes,
    ...hit.categories,
  ]);
  if (codes.isEmpty) return hit;
  return hit.copyWith(categoryCodes: codes);
}

SearchHit? pickMatchingHit(SearchHit seed, Iterable<SearchHit> hits) {
  for (final hit in hits) {
    if (catalogHitsMatch(seed, hit)) return hit;
  }
  return null;
}

bool coverBytesOk(List<int> bytes) {
  if (bytes.length < minCoverBytes) return false;
  if (bytes.length >= 6) {
    final header = String.fromCharCodes(bytes.take(6));
    if (header == 'GIF87a' || header == 'GIF89a') return false;
  }
  return true;
}

String _prefer(String a, String b) => a.trim().isNotEmpty ? a : b;

String _preferLonger(String a, String b) {
  final ta = a.trim();
  final tb = b.trim();
  if (ta.isEmpty) return tb;
  if (tb.isEmpty) return ta;
  return tb.length > ta.length ? tb : ta;
}

int? parseCatalogPageCount(Object? raw) {
  if (raw is num) {
    final n = raw.toInt();
    return n >= 8 && n < 20000 ? n : null;
  }
  if (raw is List || raw is Map) {
    return parseCatalogPageCount(catalogText(raw));
  }
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return null;
  final withUnit = RegExp(
    r'(\d{2,5})\s*(?:p\.?|pp\.?|p[aá]gs?\.?|p[aá]ginas?|pages?)',
    caseSensitive: false,
  ).firstMatch(s);
  if (withUnit != null) {
    return parseCatalogPageCount(int.parse(withUnit.group(1)!));
  }
  if (RegExp(r'^\d{2,5}$').hasMatch(s)) {
    return parseCatalogPageCount(int.parse(s));
  }
  return null;
}

({DateTime? date, String precision}) parseCatalogPublication(Object? raw) {
  if (raw is DateTime) {
    return (
      date: DateTime.utc(raw.year, raw.month, raw.day),
      precision: PublicationDatePrecision.day,
    );
  }
  if (raw is List || raw is Map) {
    return parseCatalogPublication(catalogText(raw));
  }
  if (raw is num) {
    return parseCatalogPublication(raw.toInt().toString());
  }
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return (date: null, precision: '');
  if (RegExp(r'^\d{10}$').hasMatch(s)) {
    final t = DateTime.fromMillisecondsSinceEpoch(
      int.parse(s) * 1000,
      isUtc: true,
    );
    return (
      date: DateTime.utc(t.year, t.month, t.day),
      precision: PublicationDatePrecision.day,
    );
  }
  if (RegExp(r'^\d{13}$').hasMatch(s)) {
    final t = DateTime.fromMillisecondsSinceEpoch(int.parse(s), isUtc: true);
    return (
      date: DateTime.utc(t.year, t.month, t.day),
      precision: PublicationDatePrecision.day,
    );
  }
  final day = DateTime.tryParse(s);
  if (day != null && s.length >= 10) {
    return (
      date: DateTime.utc(day.year, day.month, day.day),
      precision: PublicationDatePrecision.day,
    );
  }
  final month = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(s);
  if (month != null) {
    return (
      date: DateTime.utc(
        int.parse(month.group(1)!),
        int.parse(month.group(2)!),
      ),
      precision: PublicationDatePrecision.month,
    );
  }
  if (RegExp(r'^\d{4}$').hasMatch(s)) {
    return (
      date: DateTime.utc(int.parse(s)),
      precision: PublicationDatePrecision.year,
    );
  }
  final year = RegExp(r'\b(1[0-9]{3}|20[0-9]{2})\b').firstMatch(s);
  if (year != null) {
    return (
      date: DateTime.utc(int.parse(year.group(1)!)),
      precision: PublicationDatePrecision.year,
    );
  }
  return (date: null, precision: '');
}

({DateTime? date, String precision}) preferCatalogDate(
  DateTime? a,
  String aPrecision,
  DateTime? b,
  String bPrecision,
) {
  final ar = _dateRank(a, aPrecision);
  final br = _dateRank(b, bPrecision);
  if (br > ar) return (date: b, precision: bPrecision);
  if (ar > 0) return (date: a, precision: aPrecision);
  if (br > 0) return (date: b, precision: bPrecision);
  return (date: null, precision: '');
}

int _dateRank(DateTime? date, String precision) {
  if (date == null) return 0;
  return switch (precision) {
    PublicationDatePrecision.day => 3,
    PublicationDatePrecision.month => 2,
    PublicationDatePrecision.year => 1,
    _ => 1,
  };
}

String? catalogFormatFromProduct(String productType, String binding) {
  final p = foldKey(productType);
  final b = foldKey(binding);
  if (p.contains('audio') || b.contains('audio')) {
    return BookFormat.audiobook;
  }
  if (p.contains('ebook') ||
      p.contains('digital') ||
      b.contains('ebook') ||
      b.contains('kindle')) {
    return BookFormat.ebook;
  }
  if (p.contains('libro') ||
      b.contains('tapa') ||
      b.contains('paper') ||
      b.contains('hard')) {
    return BookFormat.physical;
  }
  return null;
}

String catalogText(Object? raw) {
  if (raw is String) return raw.trim();
  if (raw is Map) {
    return catalogText(raw['value'] ?? raw['text']);
  }
  if (raw is List) {
    for (final item in raw) {
      final t = catalogText(item);
      if (t.isNotEmpty) return t;
    }
  }
  return '';
}
