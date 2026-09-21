import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/import/import_models.dart';

void main() {
  test('rated review lands in reviewMarkdown and keeps private notes', () {
    final mapped = importedReviewAndNotes(
      rating: 4.5,
      notes: 'secret',
      review: 'Loved it<br>a lot',
    );

    expect(mapped.notes, 'secret');
    expect(mapped.reviewMarkdown, 'Loved it\na lot');
  });

  test('unrated review falls back to private notes', () {
    final mapped = importedReviewAndNotes(rating: null, review: 'public');

    expect(mapped.notes, 'public');
    expect(mapped.reviewMarkdown, isEmpty);
  });

  test('unrated review appends to existing private notes', () {
    final mapped = importedReviewAndNotes(
      rating: null,
      notes: 'secret',
      review: 'public',
    );

    expect(mapped.notes, 'secret\n\npublic');
    expect(mapped.reviewMarkdown, isEmpty);
  });

  test('strips HTML tags from reviews and rejects leftover markup', () {
    final stripped = importedReviewAndNotes(
      rating: 5,
      review: '<p>Nice <i>book</i></p>',
    );
    expect(stripped.reviewMarkdown, 'Nice book');

    final unsafe = importedReviewAndNotes(
      rating: 5,
      review: 'See ![cover](https://example.com/a.png)',
    );
    expect(unsafe.reviewMarkdown, isEmpty);
    expect(unsafe.notes, 'See ![cover](https://example.com/a.png)');
  });

  test('toRowJson emits reviewMarkdown only when set', () {
    const book = ImportedBook(
      title: 'Dune',
      authors: ['Herbert'],
      isbn: '',
      status: 'read',
      rating: 4.5,
      notes: 'secret',
      reviewMarkdown: 'classic',
    );
    final json = book.toRowJson(timezone: 'UTC');
    expect(json['rating'], 4.5);
    expect(json['notes'], 'secret');
    expect(json['reviewMarkdown'], 'classic');

    const bare = ImportedBook(
      title: 'Dune',
      authors: ['Herbert'],
      isbn: '',
      status: 'read',
    );
    expect(
      bare.toRowJson(timezone: 'UTC').containsKey('reviewMarkdown'),
      isFalse,
    );
  });
}
