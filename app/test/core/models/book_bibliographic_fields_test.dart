import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';

void main() {
  Map<String, dynamic> base(Map<String, dynamic> extra) => {
    'id': '1',
    'ownerType': 'user',
    'ownerId': 'u1',
    'title': 'Mistborn',
    'authors': ['Brandon Sanderson'],
    'status': 'reading',
    ...extra,
  };

  test('Book.fromJson parses catalog bibliographic fields', () {
    final b = Book.fromJson(
      base({
        'subtitle': 'The Final Empire',
        'edition': '1st',
        'binding': 'Hardcover',
        'dimensions': '9.3 × 6.4 × 1.6 inches · 1.65 pounds',
        'msrp': 24.95,
        'msrpCurrency': 'USD',
        'excerpt': 'Once, a hero arose.',
        'related': ['9780765311789', 'The Well of Ascension'],
        'publicationDate': '2006-07-01T00:00:00Z',
        'publicationDatePrecision': 'month',
        'categories': ['Science Fiction & Fantasy'],
        'categoryCodes': ['fantasy', 'science_fiction'],
      }),
    );
    expect(b.subtitle, 'The Final Empire');
    expect(b.edition, '1st');
    expect(b.binding, 'Hardcover');
    expect(b.dimensions, contains('inches'));
    expect(b.msrp, 24.95);
    expect(b.msrpCurrency, 'USD');
    expect(b.excerpt, 'Once, a hero arose.');
    expect(b.related, ['9780765311789', 'The Well of Ascension']);
    expect(b.publicationDate, DateTime.utc(2006, 7));
    expect(b.publicationDatePrecision, 'month');
    expect(b.categoryCodes, ['fantasy', 'science_fiction']);
  });

  test('Book.fromJson defaults the new fields when absent', () {
    final b = Book.fromJson(base({}));
    expect(b.subtitle, '');
    expect(b.edition, '');
    expect(b.binding, '');
    expect(b.dimensions, '');
    expect(b.msrp, isNull);
    expect(b.msrpCurrency, '');
    expect(b.excerpt, '');
    expect(b.related, isEmpty);
    expect(b.publicationDate, isNull);
    expect(b.publicationDatePrecision, '');
    expect(b.categoryCodes, isEmpty);
  });

  test('copyWith preserves catalog bibliographic fields', () {
    final b = Book.fromJson(
      base({
        'subtitle': 'Sub',
        'edition': '2nd',
        'binding': 'Paperback',
        'dimensions': 'dims',
        'msrp': 10.0,
        'msrpCurrency': 'USD',
        'excerpt': 'ex',
        'related': ['9780000000001'],
        'publicationDate': '2006-01-01T00:00:00Z',
        'publicationDatePrecision': 'year',
        'categoryCodes': ['fantasy'],
      }),
    );
    final c = b.copyWith(status: 'read');
    expect(c.status, 'read');
    expect(c.subtitle, 'Sub');
    expect(c.edition, '2nd');
    expect(c.binding, 'Paperback');
    expect(c.dimensions, 'dims');
    expect(c.msrp, 10.0);
    expect(c.msrpCurrency, 'USD');
    expect(c.excerpt, 'ex');
    expect(c.related, ['9780000000001']);
    expect(c.publicationDate, DateTime.utc(2006));
    expect(c.publicationDatePrecision, 'year');
    expect(c.categoryCodes, ['fantasy']);
  });

  test('review markdown stays separate from private notes', () {
    final book = Book.fromJson(
      base({'privateNotes': 'secret', 'reviewMarkdown': 'public candidate'}),
    );
    expect(book.notes, 'secret');
    expect(book.reviewMarkdown, 'public candidate');
    final changed = book.copyWith(notes: 'new secret');
    expect(changed.notes, 'new secret');
    expect(changed.reviewMarkdown, 'public candidate');
  });
}
