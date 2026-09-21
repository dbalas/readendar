import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';

void main() {
  test('book and search-hit payloads parse canonical category codes', () {
    final book = Book.fromJson({
      'id': 'book-1',
      'ownerType': 'user',
      'ownerId': 'user-1',
      'title': 'Dune',
      'authors': ['Frank Herbert'],
      'status': 'read',
      'categories': ['Science Fiction', 'Space Opera'],
      'categoryCodes': ['science_fiction'],
    });
    final hit = SearchHit.fromJson({
      'Título': 'Dune',
      'Authors': ['Frank Herbert'],
      'Categorías': ['Science Fiction'],
      'CategoryCodes': ['science_fiction'],
    });

    expect(book.categories, ['Science Fiction', 'Space Opera']);
    expect(book.categoryCodes, ['science_fiction']);
    expect(book.copyWith(status: 'reading').categoryCodes, ['science_fiction']);
    expect(hit.categoryCodes, ['science_fiction']);
  });

  test('search hit parses subtitle', () {
    final withSubtitle = SearchHit.fromJson({
      'Title': 'Ciudad de Medialuna',
      'Subtitle': 'Casa de tierra y sangre',
      'Authors': ['Sarah J. Maas'],
    });
    expect(withSubtitle.subtitle, 'Casa de tierra y sangre');
  });
}
