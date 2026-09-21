import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/library/book_share_handoff.dart';

void main() {
  test('book share refs are ISBN-13 only', () {
    expect(isBookShareRef('9780765311788'), isTrue);
    expect(isBookShareRef('0123456789abcd'), isFalse);
    expect(isBookShareRef('too-short'), isFalse);
    expect(isBookShareRef(''), isFalse);
  });
}
