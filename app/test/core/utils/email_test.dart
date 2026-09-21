import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/email.dart';

void main() {
  group('isValidEmail', () {
    test('accepts trimmed mixed-case addresses', () {
      expect(isValidEmail('  Marina@Example.COM '), isTrue);
    });

    test('rejects empty, plain text, and incomplete shapes', () {
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('   '), isFalse);
      expect(isValidEmail('notanemail'), isFalse);
      expect(isValidEmail('a@b'), isFalse);
      expect(isValidEmail('@nope.com'), isFalse);
    });
  });
}
