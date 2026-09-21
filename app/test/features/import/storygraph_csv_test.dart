import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/features/import/import_models.dart';
import 'package:readendar/features/import/storygraph_csv.dart';

const _header =
    'Title,Authors,Contributors,ISBN/UID,Format,Read Status,Date Added,Last Date Read,Dates Read,Read Count,Moods,Pace,Character- or Plot-Driven?,Strong Character Development?,Loveable Characters?,Diverse Characters?,Flawed Characters?,Star Rating,Review,Content Warnings,Content Warning Description,Tags,Owned?';

String _row({
  required String title,
  required String authors,
  required String status,
  String isbn = '',
  String format = '',
  String rating = '',
  String review = '',
  String lastDateRead = '2026/02/01',
  String datesRead = '2026/01/01-2026/02/01',
}) =>
    '"$title","$authors","Narrator","$isbn","$format","$status",'
    '"2026/01/01","$lastDateRead","$datesRead","1",'
    '"adventurous","fast","plot","","","","","$rating","$review",'
    '"","","owned","Yes"';

void main() {
  test(
    'parses StoryGraph identity, statuses, formats, ratings and reviews',
    () {
      final result = parseStoryGraphCsv(
        [
          _header,
          _row(
            title: 'The Fifth Season',
            authors: 'N. K. Jemisin, Another Author',
            isbn: '9780316229296',
            format: 'paperback',
            status: 'read',
            rating: '4.25',
            review: 'Great<br>book',
          ),
          _row(
            title: 'Digital Book',
            authors: 'Author Two',
            isbn: 'storygraph-uid-123',
            format: 'digital',
            status: 'currently-reading',
          ),
          _row(
            title: 'Audio Book',
            authors: 'Author Three',
            format: 'audio',
            status: 'to-read',
          ),
          _row(
            title: 'Stopped Book',
            authors: 'Author Four',
            format: 'hardback',
            status: 'did-not-finish',
            rating: '0.25',
          ),
        ].join('\n'),
      );

      expect(result.books, hasLength(4));
      expect(result.books[0].title, 'The Fifth Season');
      expect(result.books[0].authors, ['N. K. Jemisin', 'Another Author']);
      expect(result.books[0].isbn, '9780316229296');
      expect(result.books[0].status, BookStatus.read);
      expect(result.books[0].format, BookFormat.physical);
      expect(result.books[0].rating, 4.5);
      expect(result.books[0].reviewMarkdown, 'Great\nbook');
      expect(result.books[0].notes, isEmpty);
      expect(result.books[0].completedOn, DateTime.utc(2026, 2));
      expect(
        result.books[0].toRowJson(
          timezone: 'America/Los_Angeles',
        )['completedAt'],
        '2026-02-01T08:00:00.000Z',
      );

      expect(result.books[1].isbn, isEmpty);
      expect(result.books[1].status, BookStatus.reading);
      expect(result.books[1].format, BookFormat.ebook);
      expect(result.books[1].completedOn, isNull);
      expect(result.books[2].status, BookStatus.pending);
      expect(result.books[2].format, BookFormat.audiobook);
      expect(result.books[3].status, BookStatus.abandoned);
      expect(result.books[3].format, BookFormat.physical);
      expect(result.books[3].rating, 0.5);
      expect(result.ratingsRounded, 2);
    },
  );

  test('falls back to final Dates Read value and rejects invalid dates', () {
    final result = parseStoryGraphCsv(
      [
        _header,
        _row(
          title: 'Reread',
          authors: 'A',
          status: 'read',
          lastDateRead: '',
          datesRead: '2024/02/01, 2025/03/04',
        ),
        _row(
          title: 'Invalid',
          authors: 'B',
          status: 'read',
          lastDateRead: '2025/02/30',
          datesRead: '',
        ),
      ].join('\n'),
    );

    expect(result.books[0].completedOn, DateTime.utc(2025, 3, 4));
    expect(result.books[1].completedOn, isNull);
  });

  test('accepts BOM, header preambles and common status spelling variants', () {
    final result = parseStoryGraphCsv(
      [
        'StoryGraph library export',
        '\uFEFF$_header',
        _row(
          title: 'DNF',
          authors: 'A',
          status: 'did not finish',
          rating: '4.75',
        ),
      ].join('\n'),
    );

    expect(result.books.single.status, BookStatus.abandoned);
    expect(result.books.single.rating, 5);
    expect(result.ratingsRounded, 1);
  });

  test(
    'repairs StoryGraph MacRoman mojibake without changing real symbols',
    () {
      final result = parseStoryGraphCsv(
        [
          _header,
          _row(
            title: 'Jos√© and the symbol √',
            authors: 'Milan ≈†imeƒçka',
            status: 'read',
            review: 'Cr√®me br√ªl√©e',
          ),
        ].join('\n'),
      );

      final book = result.books.single;
      expect(book.title, 'José and the symbol √');
      expect(book.authors, ['Milan Šimečka']);
      expect(book.notes, 'Crème brûlée');
    },
  );

  test('drops duplicate ISBNs and reports missing titles and authors', () {
    final result = parseStoryGraphCsv(
      [
        _header,
        _row(
          title: 'First',
          authors: 'A',
          isbn: '9780316229296',
          status: 'read',
        ),
        _row(
          title: 'Duplicate edition',
          authors: 'A',
          isbn: '9780316229296',
          status: 'to-read',
        ),
        _row(title: '', authors: 'A', status: 'read'),
        _row(title: 'No author', authors: '', status: 'read'),
      ].join('\n'),
    );

    expect(result.books.single.title, 'First');
    expect(result.duplicatesDropped, 1);
    expect(result.skippedNoTitle, 1);
    expect(result.skippedNoAuthor, 1);
  });

  test('drops ISBN-10 and ISBN-13 encodings of the same edition', () {
    final result = parseStoryGraphCsv(
      [
        _header,
        _row(
          title: 'ISBN-10',
          authors: 'A',
          isbn: '0306406152',
          status: 'read',
        ),
        _row(
          title: 'ISBN-13',
          authors: 'A',
          isbn: '9780306406157',
          status: 'read',
        ),
      ].join('\n'),
    );

    expect(result.books.single.title, 'ISBN-10');
    expect(result.duplicatesDropped, 1);
  });

  test('truncates reviews to the backend notes limit', () {
    final review = List.filled(maxImportNotesLength + 1, 'x').join();
    final book = parseStoryGraphCsv(
      [
        _header,
        _row(
          title: 'Long review',
          authors: 'A',
          status: 'read',
          review: review,
        ),
      ].join('\n'),
    ).books.single;

    expect(book.notes.runes, hasLength(maxImportNotesLength));
    expect(book.toRowJson(timezone: 'Europe/Madrid')['notes'], book.notes);
  });

  test('truncates rated reviews onto reviewMarkdown', () {
    final review = List.filled(maxImportNotesLength + 1, 'x').join();
    final book = parseStoryGraphCsv(
      [
        _header,
        _row(
          title: 'Long rated review',
          authors: 'A',
          status: 'read',
          rating: '4',
          review: review,
        ),
      ].join('\n'),
    ).books.single;

    expect(book.reviewMarkdown.runes, hasLength(maxImportNotesLength));
    expect(book.notes, isEmpty);
    expect(
      book.toRowJson(timezone: 'Europe/Madrid')['reviewMarkdown'],
      book.reviewMarkdown,
    );
  });

  test('preserves commas, quotes and newlines in quoted reviews', () {
    const csv = '''
Title,Authors,ISBN/UID,Read Status,Review
"A book","An author","","read","First line, with comma
Second line says ""great"""''';

    final book = parseStoryGraphCsv(csv).books.single;

    expect(book.notes, 'First line, with comma\nSecond line says "great"');
  });

  test('rejects CSV files without StoryGraph columns', () {
    expect(
      () => parseStoryGraphCsv('Title,Author\nA book,Someone'),
      throwsA(isA<StoryGraphFormatException>()),
    );
  });

  test('caps large StoryGraph exports', () {
    final rows = <String>[_header];
    for (var i = 0; i <= maxImportBooks; i++) {
      rows.add(_row(title: 'Book $i', authors: 'A', status: 'read'));
    }

    final result = parseStoryGraphCsv(rows.join('\n'));

    expect(result.books, hasLength(maxImportBooks));
    expect(result.truncated, isTrue);
  });
}
