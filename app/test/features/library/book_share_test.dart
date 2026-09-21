import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/features/library/book_share.dart';

void main() {
  test('ISBN books share an Open Library URL', () {
    expect(
      bookSharePublicUrl(isbn13: '9780765311788', isbn10: ''),
      '$openLibraryIsbnUrl/9780765311788',
    );
    expect(
      bookSharePublicUrl(isbn13: '', isbn10: '076531178X'),
      '$openLibraryIsbnUrl/9780765311788',
    );
  });

  test('manual books without an ISBN are not shareable', () {
    expect(
      bookSharePublicUrl(isbn13: '', isbn10: '', shareRef: 'not-an-isbn'),
      isNull,
    );
    expect(bookSharePublicUrl(isbn13: '', isbn10: ''), isNull);
  });

  test('a leftover 13-digit share ref still maps to Open Library', () {
    expect(
      bookSharePublicUrl(
        isbn13: '',
        isbn10: '',
        shareRef: '9780765311788',
      ),
      '$openLibraryIsbnUrl/9780765311788',
    );
  });
}
