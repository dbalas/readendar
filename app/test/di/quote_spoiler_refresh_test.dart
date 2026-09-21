import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/di/quote_spoiler_refresh.dart';

Book _book({String status = BookStatus.pending, String isbn = ''}) => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: 'Libro',
  authors: const ['Autor'],
  status: status,
  isbn13: isbn,
);

void main() {
  test('eligibility changes only when canonical Read membership changes', () {
    final pending = _book(isbn: '9780306406157');
    final reading = _book(status: BookStatus.reading, isbn: '9780306406157');
    final read13 = _book(status: BookStatus.read, isbn: '9780306406157');
    final read10 = _book(status: BookStatus.read, isbn: '0306406152');
    final otherRead = _book(status: BookStatus.read, isbn: '9780140328721');

    expect(
      changesQuoteSpoilerEligibility(before: pending, after: reading),
      isFalse,
    );
    expect(
      changesQuoteSpoilerEligibility(before: reading, after: read13),
      isTrue,
    );
    expect(
      changesQuoteSpoilerEligibility(before: read13, after: read10),
      isFalse,
    );
    expect(
      changesQuoteSpoilerEligibility(before: read13, after: otherRead),
      isTrue,
    );
    expect(changesQuoteSpoilerEligibility(after: read13), isTrue);
    expect(changesQuoteSpoilerEligibility(before: read13), isTrue);
    expect(
      changesQuoteSpoilerEligibility(before: _book(status: BookStatus.read)),
      isFalse,
    );
  });
}
