import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/library/book_detail_scope.dart';

void main() {
  test('personal visibility shows library chrome', () {
    final v = BookDetailVisibility.forOwnedBook(
      canEdit: true,
      canPlan: true,
    );
    expect(v.scope, BookDetailScope.personal);
    expect(v.showNotesQuotes, isTrue);
    expect(v.showOverflowMenu, isTrue);
    expect(v.ratingEditable, isTrue);
  });
}
