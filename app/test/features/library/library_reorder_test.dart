import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/library/library_reorder.dart';

Book _book(String id, {required String status}) => Book(
  id: id,
  ownerType: 'user',
  ownerId: 'user-1',
  title: id,
  authors: const ['Autor'],
  status: status,
);

void main() {
  test('permutes one status prefix and keeps hidden plus other statuses', () {
    final books = [
      _book('r1', status: BookStatus.reading),
      _book('p1', status: BookStatus.pending),
      _book('r2', status: BookStatus.reading),
      _book('r3', status: BookStatus.reading),
    ];
    expect(
      spliceStatusReorder(
        allBooks: books,
        status: BookStatus.reading,
        visibleIdsInNewOrder: ['r2', 'r1'],
      ),
      ['r2', 'p1', 'r1', 'r3'],
    );
  });

  test(
    'search subset permutes matches and leaves unmatched books in place',
    () {
      final books = [
        _book('a', status: BookStatus.reading),
        _book('b', status: BookStatus.reading),
        _book('c', status: BookStatus.reading),
        _book('d', status: BookStatus.reading),
      ];
      expect(
        spliceStatusReorder(
          allBooks: books,
          status: BookStatus.reading,
          visibleIdsInNewOrder: ['d', 'b'],
        ),
        ['a', 'd', 'c', 'b'],
      );
    },
  );

  test('rejects a visible list that includes another status', () {
    final books = [
      _book('r1', status: BookStatus.reading),
      _book('p1', status: BookStatus.pending),
    ];
    expect(
      spliceStatusReorder(
        allBooks: books,
        status: BookStatus.reading,
        visibleIdsInNewOrder: ['r1', 'p1'],
      ),
      ['r1', 'p1'],
    );
  });
}
