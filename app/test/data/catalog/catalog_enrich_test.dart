import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/data/catalog/catalog_enrich.dart';

void main() {
  test('openLibraryCoverUrl uses the ISBN cover path', () {
    expect(
      openLibraryCoverUrl('9788408324751'),
      'https://covers.openlibrary.org/b/isbn/9788408324751-L.jpg?default=false',
    );
    expect(openLibraryCoverUrl('978-84-083-2475-1'), contains('9788408324751'));
  });

  test('placeholder covers are not usable', () {
    expect(
      hasUsableCover(
        'https://imagessl4.casadellibro.com/a/l/t1/defecto4.jpg',
      ),
      isFalse,
    );
    expect(hasUsableCover(''), isFalse);
    expect(
      hasUsableCover(
        'https://covers.openlibrary.org/b/isbn/9788408324751-L.jpg?default=false',
      ),
      isTrue,
    );
    expect(
      hasUsableCover(
        'https://imagessl1.casadellibro.com/a/l/t1/35/9788410466135.jpg',
      ),
      isTrue,
    );
  });

  test('Casa del Libro cover URL follows the imagessl ISBN pattern', () {
    expect(
      casaDelLibroCoverUrl('9788410466135'),
      'https://imagessl1.casadellibro.com/a/l/t1/35/9788410466135.jpg',
    );
    expect(casaDelLibroCoverUrl(''), isEmpty);
  });

  test('empty cover prefers Casa del Libro then Open Library ISBN', () {
    final hit = SearchHit(
      title: 'Carl el Mazmorrero',
      authors: const ['Matt Dinniman'],
      isbn: '9788410466135',
    );
    expect(withFallbackCover(hit).coverUrl, contains('casadellibro.com'));
  });

  test('speculative Open Library ISBN covers do not block Empathy jackets', () {
    final olIsbn = SearchHit(
      title: 'Carl el Mazmorrero',
      authors: const ['Matt Dinniman'],
      isbn: '9788410466135',
      coverUrl: openLibraryCoverUrl('9788410466135'),
    );
    final cdl = SearchHit(
      title: 'Carl el Mazmorrero',
      authors: const ['Matt Dinniman'],
      isbn: '9788410466135',
      coverUrl: casaDelLibroCoverUrl('9788410466135'),
    );
    expect(isStrongCatalogCover(olIsbn.coverUrl), isFalse);
    expect(isStrongCatalogCover(cdl.coverUrl), isTrue);
    expect(
      mergeCatalogHits(olIsbn, cdl).coverUrl,
      contains('casadellibro.com'),
    );
  });

  test('Commons file URLs upgrade to https', () {
    expect(
      commonsCoverUrl(
        'http://commons.wikimedia.org/wiki/Special:FilePath/Dune.jpg',
      ),
      'https://commons.wikimedia.org/wiki/Special:FilePath/Dune.jpg',
    );
    expect(commonsCoverUrl('https://evil.example/x.jpg'), isEmpty);
  });

  test(
    'catalogHitsMatch accepts ISBN or cleaned title plus author overlap',
    () {
      final seed = SearchHit(
        title: 'Nieve (EBOOK)',
        authors: const ['María Nieves'],
        isbn: '9788408324751',
      );
      expect(
        catalogHitsMatch(
          seed,
          SearchHit(
            title: 'Other',
            authors: const ['Someone'],
            isbn: '9788408324751',
          ),
        ),
        isTrue,
      );
      expect(
        catalogHitsMatch(
          seed,
          SearchHit(title: 'Nieve', authors: const ['Maria Nieves']),
        ),
        isTrue,
      );
      expect(
        catalogHitsMatch(
          SearchHit(title: 'Rayuela', authors: const ['Julio Cortázar']),
          SearchHit(title: 'Rayuela', authors: const ['Cortázar']),
        ),
        isTrue,
      );
      expect(
        catalogHitsMatch(
          SearchHit(
            title: 'Peter Pan: Los inéditos',
            authors: const ['James Matthew Barrie'],
          ),
          SearchHit(
            title: 'Peter Pan: los inéditos',
            authors: const ['J. M. Barrie'],
          ),
        ),
        isTrue,
      );
      expect(
        catalogHitsMatch(
          seed,
          SearchHit(title: 'Nieve', authors: const ['Someone Else']),
        ),
        isFalse,
      );
      expect(
        catalogHitsMatch(
          SearchHit(title: '', authors: const [], isbn: '9788408324751'),
          SearchHit(title: 'Unrelated', authors: const ['X']),
        ),
        isFalse,
      );
    },
  );

  test('merge keeps the primary cover and fills validated categories', () {
    final olCover = SearchHit(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      isbn: '9780441172719',
      coverUrl: openLibraryCoverUrl('9780441172719'),
    );
    final extra = SearchHit(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      isbn: '9780441172719',
      categories: const ['Science fiction'],
    );
    final merged = mergeCatalogHits(olCover, extra);
    expect(merged.coverUrl, contains('openlibrary.org'));
    expect(merged.categoryCodes, ['science_fiction']);
  });

  test('empty primary cover does not block an Open Library jacket', () {
    final empty = SearchHit(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      isbn: '9780441172719',
    );
    final ol = SearchHit(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      isbn: '9780441172719',
      coverUrl: openLibraryCoverUrl('9780441172719'),
      categories: const ['Science fiction'],
    );
    expect(mergeCatalogHits(empty, ol).coverUrl, contains('openlibrary.org'));
  });

  test('merge does not overwrite validated primary categories', () {
    final primary = SearchHit(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      coverUrl: openLibraryCoverUrl('9780441172719'),
      categories: const ['Ciencia ficción'],
      categoryCodes: const ['science_fiction'],
    );
    final ol = SearchHit(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      categories: const ['Fantasy'],
      categoryCodes: const ['fantasy'],
    );
    expect(mergeCatalogHits(primary, ol).categoryCodes, ['science_fiction']);
  });

  test('merge prefers a Spanish language over English', () {
    final merged = mergeCatalogHits(
      SearchHit(
        title: 'Rayuela',
        authors: const ['Cortázar'],
        language: 'eng',
      ),
      SearchHit(
        title: 'Rayuela',
        authors: const ['Cortázar'],
        language: 'spa',
      ),
    );
    expect(merged.language, 'spa');
  });

  test('coverProbeUrl uses the small Open Library derivative', () {
    expect(
      coverProbeUrl(
        'https://covers.openlibrary.org/b/id/99-L.jpg?default=false',
      ),
      'https://covers.openlibrary.org/b/id/99-S.jpg?default=false',
    );
    expect(
      coverProbeUrl('https://example.com/cover.jpg'),
      'https://example.com/cover.jpg',
    );
  });

  test('Open Library cover-id jackets skip the byte probe', () {
    expect(
      isOpenLibraryCoverId(
        'https://covers.openlibrary.org/b/id/99-L.jpg?default=false',
      ),
      isTrue,
    );
    expect(
      isOpenLibraryCoverId(
        'https://covers.openlibrary.org/b/isbn/9788437604572-L.jpg?default=false',
      ),
      isFalse,
    );
  });

  test('dedupe key treats hyphenated and digit ISBNs as the same edition', () {
    final a = SearchHit(
      title: 'Rayuela',
      authors: const ['Cortázar'],
      isbn: '978-84-376-0457-2',
    );
    final b = SearchHit(
      title: 'Rayuela',
      authors: const ['Cortazar'],
      isbn: '9788437604572',
    );
    expect(catalogDedupeKey(a), catalogDedupeKey(b));
  });

  test('parseCatalogPageCount keeps numeric pages and rejects spine size', () {
    expect(parseCatalogPageCount(432), 432);
    expect(parseCatalogPageCount('432 p.'), 432);
    expect(parseCatalogPageCount('X, 480 páginas'), 480);
    expect(parseCatalogPageCount('24 cm'), isNull);
    expect(parseCatalogPageCount(3), isNull);
  });

  test('parseCatalogPublication prefers unix day over year', () {
    final day = parseCatalogPublication(1752105600);
    expect(day.date, DateTime.utc(2025, 7, 10));
    expect(day.precision, PublicationDatePrecision.day);
    final year = parseCatalogPublication('2025');
    expect(year.date, DateTime.utc(2025));
    expect(year.precision, PublicationDatePrecision.year);
    final preferred = preferCatalogDate(
      year.date,
      year.precision,
      day.date,
      day.precision,
    );
    expect(preferred.date, DateTime.utc(2025, 7, 10));
    expect(preferred.precision, PublicationDatePrecision.day);
  });

  test('merge keeps the longer synopsis and the more precise date', () {
    final merged = mergeCatalogHits(
      SearchHit(
        title: 'Carl el Mazmorrero',
        authors: const ['Matt Dinniman'],
        isbn: '9788410466135',
        description: 'Corto.',
        publicationDate: DateTime.utc(2025),
        publicationDatePrecision: PublicationDatePrecision.year,
      ),
      SearchHit(
        title: 'Carl el Mazmorrero',
        authors: const ['Matt Dinniman'],
        isbn: '9788410466135',
        description: 'Sinopsis larga de Carl en la mazmorra.',
        publicationDate: DateTime.utc(2025, 7, 10),
        publicationDatePrecision: PublicationDatePrecision.day,
        pageCount: 480,
      ),
    );
    expect(merged.description, 'Sinopsis larga de Carl en la mazmorra.');
    expect(merged.publicationDate, DateTime.utc(2025, 7, 10));
    expect(merged.publicationDatePrecision, PublicationDatePrecision.day);
    expect(merged.pageCount, 480);
  });
}
