import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/data/catalog/catalog_language.dart';

void main() {
  test('catalogHitIsSpanish accepts Spanish and empty BNE-style hits', () {
    expect(
      catalogHitIsSpanish(
        SearchHit(title: 'Rayuela', authors: const [], language: 'spa'),
      ),
      isTrue,
    );
    expect(
      catalogHitIsSpanish(
        SearchHit(title: 'Rayuela', authors: const [], language: 'español'),
      ),
      isTrue,
    );
    expect(
      catalogHitIsSpanish(
        SearchHit(title: 'Sin idioma', authors: const []),
      ),
      isTrue,
    );
  });

  test('catalogHitIsSpanish rejects explicit English', () {
    expect(
      catalogHitIsSpanish(
        SearchHit(title: 'Dune', authors: const [], language: 'eng'),
      ),
      isFalse,
    );
  });

  test('preferredCatalogLanguage keeps Spanish when the list is mixed', () {
    expect(preferredCatalogLanguage(['eng', 'spa']), 'spa');
    expect(preferredCatalogLanguage(['spa', 'eng']), 'spa');
    expect(preferredCatalogLanguage(['eng']), 'eng');
    expect(preferredCatalogLanguage(const []), '');
  });

  test('restrictCatalogPageToSpanish drops English leaks and keeps paging', () {
    final page = restrictCatalogPageToSpanish(
      SearchPage(
        items: [
          SearchHit(
            title: 'Rayuela',
            authors: const ['Cortázar'],
            language: 'spa',
          ),
          SearchHit(
            title: 'Dune',
            authors: const ['Herbert'],
            language: 'eng',
          ),
        ],
        page: 3,
        limit: 20,
        hasMore: true,
        total: 40,
      ),
      pageNumber: 1,
    );
    expect(page.items, hasLength(1));
    expect(page.items.first.title, 'Rayuela');
    expect(page.page, 1);
    expect(page.hasMore, isTrue);
  });

  test(
    'localCatalogSearchPage fetches one upstream page at the UI offset',
    () async {
      final offsets = <int>[];
      final page = await localCatalogSearchPage(
        fetch: (offset) async {
          offsets.add(offset);
          return SearchPage(
            items: [
              SearchHit(
                title: 'English leak',
                authors: const ['X'],
                language: 'eng',
              ),
              SearchHit(
                title: 'Rayuela',
                authors: const ['Cortázar'],
                language: 'spa',
              ),
            ],
            page: 2,
            limit: 20,
            hasMore: true,
          );
        },
        page: 2,
        limit: 20,
      );
      expect(offsets, [20]);
      expect(page.items.map((e) => e.title).toList(), ['Rayuela']);
      expect(page.page, 2);
      expect(page.hasMore, isTrue);
    },
  );

  test('all-languages catalog pages are not Spanish-filtered', () async {
    final page = await localCatalogSearchPage(
      fetch: (offset) async {
        expect(offset, 0);
        return SearchPage(
          items: [
            SearchHit(
              title: 'Dune',
              authors: const ['Herbert'],
              language: 'eng',
            ),
          ],
          page: 1,
          limit: 20,
          hasMore: false,
        );
      },
      page: 1,
      limit: 20,
      allLanguages: true,
    );
    expect(page.items, hasLength(1));
    expect(page.items.first.title, 'Dune');
  });

  test(
    'localCatalogSearchPage stays empty when the last page is only English',
    () async {
      final page = await localCatalogSearchPage(
        fetch: (offset) async {
          expect(offset, 0);
          return SearchPage(
            items: [
              SearchHit(
                title: 'Dune',
                authors: const ['Herbert'],
                language: 'eng',
              ),
            ],
            page: 1,
            limit: 20,
            hasMore: false,
          );
        },
        page: 1,
        limit: 20,
      );
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    },
  );

  test(
    'localCatalogSearchPage stays empty when more Spanish pages may exist',
    () async {
      final page = await localCatalogSearchPage(
        fetch: (offset) async {
          expect(offset, 0);
          return SearchPage(
            items: [
              SearchHit(
                title: 'Dune',
                authors: const ['Herbert'],
                language: 'eng',
              ),
            ],
            page: 1,
            limit: 20,
            hasMore: true,
          );
        },
        page: 1,
        limit: 20,
      );
      expect(page.items, isEmpty);
      expect(page.hasMore, isTrue);
    },
  );

  test('ISBN catalog pages skip the Spanish leak filter', () async {
    final page = await localCatalogSearchPage(
      fetch: (offset) async {
        expect(offset, 0);
        return SearchPage(
          items: [
            SearchHit(
              title: 'Dune',
              authors: const ['Herbert'],
              language: 'eng',
              isbn: '9780441172719',
            ),
          ],
          page: 1,
          limit: 20,
          hasMore: false,
        );
      },
      page: 1,
      limit: 20,
      isbnQuery: true,
    );
    expect(page.items, hasLength(1));
    expect(page.items.first.title, 'Dune');
  });
}
