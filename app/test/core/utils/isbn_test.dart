import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/isbn.dart';

void main() {
  group('normalizeScannedIsbn', () {
    test('accepts a valid ISBN-13 (978)', () {
      expect(normalizeScannedIsbn('9780765311788'), '9780765311788');
    });

    test('accepts a valid ISBN-13 (979)', () {
      // 9791234567896 is a valid 979-prefixed EAN-13 check digit.
      expect(normalizeScannedIsbn('9791234567896'), '9791234567896');
    });

    test('strips hyphens and spaces', () {
      expect(normalizeScannedIsbn('978-0-7653-1178-8'), '9780765311788');
      expect(normalizeScannedIsbn(' 978 0 7653 1178 8 '), '9780765311788');
    });

    test('drops a trailing EAN-5 price add-on', () {
      expect(normalizeScannedIsbn('978076531178850999'), '9780765311788');
    });

    test('converts a valid ISBN-10 to ISBN-13', () {
      // 0306406152 -> 9780306406157
      expect(normalizeScannedIsbn('0306406152'), '9780306406157');
    });

    test('accepts ISBN-10 with trailing X check digit', () {
      // 080442957X is a valid ISBN-10.
      expect(normalizeScannedIsbn('080442957X'), isNotNull);
    });

    test('rejects an ISBN-13 with a bad check digit', () {
      expect(normalizeScannedIsbn('9780765311789'), isNull);
    });

    test('rejects a non-book EAN-13 (e.g. a grocery UPC)', () {
      // A valid EAN-13 that is not 978/979 prefixed.
      expect(normalizeScannedIsbn('4006381333931'), isNull);
    });

    test('rejects garbage / wrong length', () {
      expect(normalizeScannedIsbn('hello'), isNull);
      expect(normalizeScannedIsbn('12345'), isNull);
      expect(normalizeScannedIsbn(''), isNull);
    });
  });

  group('isValidScannedIsbn', () {
    test('mirrors normalizeScannedIsbn', () {
      expect(isValidScannedIsbn('9780765311788'), isTrue);
      expect(isValidScannedIsbn('4006381333931'), isFalse);
    });
  });

  group('formatIsbnDisplay', () {
    test('hyphenates ISBN-13 Bookland values', () {
      expect(formatIsbnDisplay('9780765311788'), '978-0-7653-1178-8');
      expect(formatIsbnDisplay('9780441172719'), '978-0-441-17271-9');
      expect(formatIsbnDisplay('9780306406157'), '978-0-306-40615-7');
    });

    test('accepts already hyphenated input', () {
      expect(formatIsbnDisplay('978-0-7653-1178-8'), '978-0-7653-1178-8');
    });

    test('hyphenates ISBN-10 values', () {
      expect(formatIsbnDisplay('076531178X'), '0-7653-1178-X');
      expect(formatIsbnDisplay('0441172719'), '0-441-17271-9');
    });

    test('falls back for unknown lengths', () {
      expect(formatIsbnDisplay('12345'), '12345');
      expect(formatIsbnDisplay('4006381333931'), '4006381333931');
      expect(formatIsbnDisplay(''), isEmpty);
    });
  });

  group('looksLikeIsbnQuery', () {
    test('accepts scanned and typed book ISBNs', () {
      expect(looksLikeIsbnQuery('9780765311788'), isTrue);
      expect(looksLikeIsbnQuery('978-0-7653-1178-8'), isTrue);
      expect(looksLikeIsbnQuery('0306406152'), isTrue);
    });

    test('rejects free-text catalog queries', () {
      expect(looksLikeIsbnQuery('Rayuela'), isFalse);
      expect(looksLikeIsbnQuery('978'), isFalse);
      expect(looksLikeIsbnQuery(''), isFalse);
    });
  });

  group('isbnComparisonKey', () {
    test('collapses equivalent ISBN-10 and ISBN-13 values', () {
      expect(isbnComparisonKey('0306406152'), '9780306406157');
      expect(isbnComparisonKey('9780306406157'), '9780306406157');
    });

    test('keeps a stable cleaned key for legacy unvalidated values', () {
      expect(isbnComparisonKey('="123-456-789-0"'), '1234567890');
      expect(isbnComparisonKey(''), isEmpty);
    });
  });
}
