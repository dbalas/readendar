import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/widgets/book_status_groups.dart';

void main() {
  test('groups in BookStatus.all order and windows each section', () {
    final items = [
      ('read-1', BookStatus.read),
      ('reading-1', BookStatus.reading),
      ('reading-2', BookStatus.reading),
      ('reading-3', BookStatus.reading),
      ('hidden', null),
    ];
    final groups = groupByBookStatus(
      items,
      statusOf: (item) => item.$2,
      window: 2,
    );
    expect(groups.map((group) => group.status), [
      BookStatus.reading,
      BookStatus.read,
      '',
    ]);
    expect(groups[0].total, 3);
    expect(groups[0].items.map((item) => item.$1), ['reading-1', 'reading-2']);
    expect(groups[1].total, 1);
    expect(groups[2].status, '');
    expect(groups[2].items.single.$1, 'hidden');
  });

  test('toggle helpers hide and show a status bucket', () {
    final collapsed = <String>{BookStatus.reading};
    expect(isBookStatusSectionExpanded(collapsed, BookStatus.reading), isFalse);
    expect(isBookStatusSectionExpanded(collapsed, BookStatus.read), isTrue);
    toggleBookStatusSection(collapsed, BookStatus.reading);
    expect(collapsed, isEmpty);
    toggleBookStatusSection(collapsed, BookStatus.read);
    expect(collapsed, {BookStatus.read});
  });
}
