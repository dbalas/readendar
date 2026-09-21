import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/widgets/custom_field_icon.dart';

void main() {
  test('resolves persisted custom field icons and safely falls back', () {
    expect(customFieldIcon('heart'), LucideIcons.heart);
    expect(customFieldIcon('book-open'), LucideIcons.bookOpen);
    expect(customFieldIcon('coffee'), LucideIcons.coffee);
    expect(customFieldIcon('unknown-future-key'), LucideIcons.tag);
  });

  test('datetime textMode defaults to showing time', () {
    expect(customFieldShowsTime(''), isTrue);
    expect(customFieldShowsTime('date_time'), isTrue);
    expect(customFieldShowsTime('date'), isFalse);
  });

  test('curated icon key list stays unique', () {
    expect(customFieldIconKeys.toSet(), hasLength(customFieldIconKeys.length));
    expect(customFieldIconKeys.length, greaterThan(40));
  });
}
