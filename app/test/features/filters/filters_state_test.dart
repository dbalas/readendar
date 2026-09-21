import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/filters/filters_state.dart';

Book _book({
  String status = BookStatus.reading,
  String title = 'Pedro Páramo',
  List<String> authors = const ['Juan Rulfo'],
  String description = 'Un hombre busca a su padre en Comala.',
}) => Book(
  id: 'book-1',
  ownerType: 'user',
  ownerId: 'user-1',
  title: title,
  authors: authors,
  description: description,
  status: status,
);

void main() {
  group('bookMatchesFilters', () {
    test('empty filters match everything', () {
      expect(bookMatchesFilters(_book(), const FiltersState()), isTrue);
    });

    test('status filter includes only the selected statuses', () {
      const filters = FiltersState(bookStatuses: {BookStatus.reading});
      expect(bookMatchesFilters(_book(), filters), isTrue);
      expect(
        bookMatchesFilters(_book(status: BookStatus.pending), filters),
        isFalse,
      );
    });

    test('free-text query matches title, author or description', () {
      expect(
        bookMatchesFilters(_book(), const FiltersState(query: 'páramo')),
        isTrue,
      );
      expect(
        bookMatchesFilters(_book(), const FiltersState(query: 'JUAN')),
        isTrue,
      );
      expect(
        bookMatchesFilters(_book(), const FiltersState(query: 'comala')),
        isTrue,
      );
      expect(
        bookMatchesFilters(_book(), const FiltersState(query: 'rayuela')),
        isFalse,
      );
    });

    test('all active criteria must pass together', () {
      const filters = FiltersState(
        bookStatuses: {BookStatus.reading},
        query: 'pedro',
      );
      expect(bookMatchesFilters(_book(), filters), isTrue);
      expect(
        bookMatchesFilters(_book(status: BookStatus.read), filters),
        isFalse,
      );
      expect(bookMatchesFilters(_book(title: 'Rayuela'), filters), isFalse);
    });
  });
}
