import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/catalog_key.dart';

const _spanishLanguageKeys = {
  'es',
  'spa',
  'spanish',
  'espanol',
  'castellano',
  'castilian',
};

/// Empty language (typical BNE hits) counts as Spanish. Explicit non-Spanish
/// codes do not.
bool catalogLanguageIsSpanish(String language) {
  final lang = language.trim();
  if (lang.isEmpty) return true;
  final key = normalizeCatalogKey(lang);
  if (key.isEmpty) return true;
  if (_spanishLanguageKeys.contains(key)) return true;
  final base = key.split(RegExp(r'[-_\s]')).first;
  return _spanishLanguageKeys.contains(base);
}

/// Whether a catalog hit should appear in the Spanish-only product search.
///
/// BNE hits often omit [SearchHit.language]; treat empty language as Spanish
/// because the national-library feed is Spanish by default. Open Library and
/// other sources with an explicit non-Spanish code are excluded.
bool catalogHitIsSpanish(SearchHit hit) =>
    catalogLanguageIsSpanish(hit.language);

/// Prefers a Spanish code when a source lists several languages.
String preferredCatalogLanguage(Iterable<String> raw) {
  final langs = <String>[
    for (final value in raw)
      if (value.trim().isNotEmpty) value.trim(),
  ];
  for (final lang in langs) {
    if (catalogLanguageIsSpanish(lang)) return lang;
  }
  return langs.isEmpty ? '' : langs.first;
}

/// Drops explicit non-Spanish leaks from one upstream page. Does not scan
/// extra catalog pages; Open Library already filters `language=spa`.
SearchPage restrictCatalogPageToSpanish(
  SearchPage page, {
  int? pageNumber,
}) {
  return SearchPage(
    items: [
      for (final hit in page.items)
        if (catalogHitIsSpanish(hit)) hit,
    ],
    page: pageNumber ?? page.page,
    limit: page.limit,
    hasMore: page.hasMore,
    total: page.total,
  );
}

/// One upstream catalog fetch per UI page. Page 2 uses offset 20, not a
/// replay of page 1. Exact ISBN lookups skip the Spanish leak filter: the
/// scanned/typed code is identity, not a language search.
Future<SearchPage> localCatalogSearchPage({
  required Future<SearchPage> Function(int offset) fetch,
  required int page,
  required int limit,
  bool allLanguages = false,
  bool isbnQuery = false,
}) async {
  final rawOffset = (page - 1) * limit;
  final offset = rawOffset < 0 ? 0 : rawOffset;
  final upstream = await fetch(offset);
  if (allLanguages || isbnQuery) return upstream;
  return restrictCatalogPageToSpanish(upstream, pageNumber: page);
}
