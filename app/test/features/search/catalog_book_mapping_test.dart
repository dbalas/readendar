import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/search/catalog_book_mapping.dart';

void main() {
  test('bookFromSearchHit maps ISBN-13 catalog fields', () {
    final book = bookFromSearchHit(
      SearchHit(
        title: 'Dune',
        authors: const ['Frank Herbert'],
        isbn: '9780441172719',
        coverUrl: 'https://covers.example/dune.jpg',
        publisher: 'Chilton',
        language: 'en',
        categoryCodes: const ['science_fiction'],
        pageCount: 412,
        publicationDate: DateTime.utc(1965, 8, 1),
        publicationDatePrecision: PublicationDatePrecision.day,
      ),
    );
    expect(book.title, 'Dune');
    expect(book.isbn13, '9780441172719');
    expect(book.coverUrl, 'https://covers.example/dune.jpg');
    expect(book.publisher, 'Chilton');
    expect(book.pageCount, 412);
    expect(book.publicationDate, DateTime.utc(1965, 8, 1));
    expect(book.publicationDatePrecision, PublicationDatePrecision.day);
  });

  test('findOwnedLibraryBookForSearchHit matches ISBN only', () {
    final owned = Book(
      id: 'lib-1',
      ownerType: OwnerType.user,
      ownerId: 'user-1',
      title: 'Other title',
      authors: const ['Frank Herbert'],
      status: BookStatus.reading,
      isbn13: '9780441172719',
    );
    final hit = SearchHit(
      title: 'Dune',
      authors: const ['Frank Herbert'],
      isbn: '9780441172719',
    );
    expect(findOwnedLibraryBookForSearchHit([owned], hit)?.id, 'lib-1');
    final other = Book(
      id: 'lib-2',
      ownerType: OwnerType.user,
      ownerId: 'user-1',
      title: 'Other title',
      authors: const ['Frank Herbert'],
      status: BookStatus.reading,
      isbn13: '9780140328721',
    );
    expect(findOwnedLibraryBookForSearchHit([other], hit), isNull);
  });
}
