import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/features/import/goodreads_csv.dart';
import 'package:readendar/features/import/import_models.dart';

// A realistic slice of a real Goodreads export: the canonical header, Excel-
// escaped ISBN columns (`="..."`), quoted fields with embedded commas, an empty
// ISBN ebook, additional authors, and the three exclusive shelves.
const _header =
    'Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Publisher,Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies';

String _row({
  required String title,
  required String author,
  required String shelf,
  String additional = '',
  String isbn = '',
  String isbn13 = '',
  String publisher = '',
  String pages = '',
  String binding = 'Paperback',
  String bookshelves = '',
  String rating = '0',
  String dateRead = '',
}) {
  // Wrap title/author/bookshelves in quotes so embedded commas are handled by
  // the parser. The Bookshelves column sits just before Exclusive Shelf.
  return '1,"$title","$author","x","$additional",="$isbn",="$isbn13",$rating,'
      '4.10,"$publisher",$binding,$pages,2008,2008,$dateRead,2020/01/01,"$bookshelves",,'
      '$shelf,,,,1,1';
}

void main() {
  // ── Verbatim sample from a real user export (note: this account's export has
  // NO "Average Rating" column, and empty ISBNs come as the CSV-escaped Excel
  // formula `"=""""`). This is the exact byte format we must survive. ──
  test(
    'parses a real Goodreads export verbatim (empty ISBNs, no Average Rating)',
    () {
      const csv = '''
Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Publisher,Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies
31135200,Leyendas de los 9 Reinos I Libro 3: El Hijo de la Diosa: Novela de fantasía épica y oscura en español. (Spanish Edition),Darío Ordóñez Barba,"Barba, Darío Ordóñez",,"=""""","=""""",0,,Kindle Edition,719,2016,,,2016/12/22,currently-reading,currently-reading (#1),currently-reading,,,,2,0
187622892,"Alas de sangre (Empíreo, #1)",Rebecca Yarros,"Yarros, Rebecca",,"=""6073901801""","=""9786073901802""",0,Planeta,Paperback,522,2023,2023,,2026/06/05,to-read,to-read (#1),to-read,,,,0,0
27016611,Leyendas de los 9 Reinos I: Libro 1 - El mercenario (Spanish Edition),Darío Ordóñez Barba,"Barba, Darío Ordóñez",,"=""1502456982""","=""9781502456984""",0,CreateSpace Independent Publishing Platform,Paperback,800,2014,2014,,2016/12/22,,,read,,,,1,0
25268709,Leyendas de los 9 Reinos I Libro 2: El Voranto: Novela de fantasía épica y oscura en español. (Spanish Edition),Darío Ordóñez Barba,"Barba, Darío Ordóñez",,"=""""","=""""",0,,Kindle Edition,727,2015,2015,,2016/12/22,,,read,,,,1,0
26771098,El esclavo 3-8-4 (Leyendas de los 9 Reinos) (Spanish Edition),Darío Ordóñez Barba,"Barba, Darío Ordóñez",,"=""1515331342""","=""9781515331346""",0,CreateSpace Independent Publishing Platform,Paperback,572,2018,2015,,2016/12/22,,,read,,,,1,0''';

      final res = parseGoodreadsCsv(csv);

      // All 5 rows parse — no quote desync swallowing rows.
      expect(res.books.length, 5);

      final alas = res.books.firstWhere((b) => b.title.startsWith('Alas'));
      expect(alas.isbn, '9786073901802'); // ISBN13 preferred, cleaned
      expect(alas.status, BookStatus.pending); // to-read
      expect(alas.format, BookFormat.physical); // Paperback
      expect(alas.pageCount, 522);
      expect(alas.publisher, 'Planeta');
      expect(alas.authors, ['Rebecca Yarros']);

      final libro3 = res.books.firstWhere((b) => b.title.contains('Libro 3'));
      expect(libro3.isbn, ''); // empty "=""""  → no ISBN
      expect(libro3.status, BookStatus.reading); // currently-reading
      expect(libro3.format, BookFormat.ebook); // Kindle Edition

      final mercenario = res.books.firstWhere(
        (b) => b.title.contains('mercenario'),
      );
      expect(mercenario.isbn, '9781502456984');
      expect(mercenario.status, BookStatus.read);

      // Two books had no ISBN, so no within-file dedup false positives.
      expect(res.duplicatesDropped, 0);
      expect(res.skippedNoTitle, 0);
    },
  );

  test('parses titles, authors, isbn and maps shelves to status', () {
    final csv = [
      _header,
      _row(
        title: 'The Hunger Games',
        author: 'Suzanne Collins',
        additional: 'Some Illustrator',
        isbn: '0439023483',
        isbn13: '9780439023481',
        publisher: 'Scholastic Press',
        pages: '374',
        shelf: 'read',
      ),
      _row(title: 'Currently Book', author: 'A B', shelf: 'currently-reading'),
      _row(title: 'Want Book', author: 'C D', shelf: 'to-read'),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);

    expect(res.books.length, 3);

    final hg = res.books.first;
    expect(hg.title, 'The Hunger Games');
    expect(hg.authors, ['Suzanne Collins', 'Some Illustrator']);
    expect(hg.isbn, '9780439023481'); // ISBN13 preferred, quotes stripped
    expect(hg.status, BookStatus.read);
    expect(hg.pageCount, 374);
    expect(hg.publisher, 'Scholastic Press');

    expect(res.readingCount, 1);
    expect(res.pendingCount, 1);
    expect(res.readCount, 1);
    expect(res.books[1].status, BookStatus.reading);
    expect(res.books[2].status, BookStatus.pending);
  });

  test('falls back to ISBN10 and tolerates empty ISBN', () {
    final csv = [
      _header,
      _row(title: 'Only Ten', author: 'A', isbn: '0441013597', shelf: 'read'),
      _row(title: 'No ISBN Ebook', author: 'B', shelf: 'to-read'),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);
    expect(res.books[0].isbn, '0441013597');
    expect(res.books[1].isbn, '');
  });

  test('preserves explicit Goodreads completion dates only for read books', () {
    final result = parseGoodreadsCsv(
      [
        _header,
        _row(
          title: 'Finished',
          author: 'A',
          shelf: 'read',
          dateRead: '2025/11/09',
        ),
        _row(
          title: 'Reading',
          author: 'B',
          shelf: 'currently-reading',
          dateRead: '2025/11/10',
        ),
        _row(
          title: 'Invalid',
          author: 'C',
          shelf: 'read',
          dateRead: '2025/13/40',
        ),
      ].join('\n'),
    );

    expect(result.books[0].completedOn, DateTime.utc(2025, 11, 9));
    expect(
      result.books[0].toRowJson(timezone: 'America/Los_Angeles')['completedAt'],
      '2025-11-09T08:00:00.000Z',
    );
    expect(result.books[1].completedOn, isNull);
    expect(result.books[2].completedOn, isNull);
  });

  test('drops within-file duplicates by ISBN, keeps first', () {
    final csv = [
      _header,
      _row(
        title: 'Dune',
        author: 'Herbert',
        isbn13: '9780441013593',
        shelf: 'read',
      ),
      _row(
        title: 'Dune (other ed)',
        author: 'Herbert',
        isbn13: '9780441013593',
        shelf: 'to-read',
      ),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);
    expect(res.books.length, 1);
    expect(res.duplicatesDropped, 1);
    expect(res.books.first.status, BookStatus.read); // first wins
  });

  test('skips rows without a title', () {
    final csv = [
      _header,
      _row(title: '', author: 'Ghost', shelf: 'read'),
      _row(title: 'Real', author: 'Author', shelf: 'read'),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);
    expect(res.books.length, 1);
    expect(res.skippedNoTitle, 1);
  });

  test('handles embedded commas in quoted fields', () {
    final csv = [
      _header,
      _row(
        title: 'Cooked: A Natural History, of Transformation',
        author: 'Pollan',
        shelf: 'read',
      ),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);
    expect(
      res.books.single.title,
      'Cooked: A Natural History, of Transformation',
    );
  });

  test('maps the Binding column to our format (or null)', () {
    final csv = [
      _header,
      _row(title: 'Paper', author: 'A', shelf: 'read'),
      _row(
        title: 'Kindle',
        author: 'B',
        binding: 'Kindle Edition',
        shelf: 'read',
      ),
      _row(
        title: 'Audio',
        author: 'C',
        binding: 'Audible Audio',
        shelf: 'read',
      ),
      _row(
        title: 'Weird',
        author: 'D',
        binding: 'Papyrus Scroll',
        shelf: 'read',
      ),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);
    expect(res.books[0].format, BookFormat.physical);
    expect(res.books[1].format, BookFormat.ebook);
    expect(res.books[2].format, BookFormat.audiobook);
    expect(res.books[3].format, isNull); // unknown binding → no format
  });

  test('maps a did-not-finish custom shelf to abandoned', () {
    final csv = [
      _header,
      // Exclusive shelf says "read", but the DNF custom shelf wins → abandoned.
      _row(title: 'Gave Up', author: 'A', shelf: 'read', bookshelves: 'dnf'),
      // Spanish DNF spelling, on a to-read book.
      _row(
        title: 'Abandonado',
        author: 'B',
        shelf: 'to-read',
        bookshelves: 'abandoned',
      ),
      // No DNF marker → normal mapping.
      _row(title: 'Normal', author: 'C', shelf: 'read'),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);
    expect(res.books[0].status, BookStatus.abandoned);
    expect(res.books[1].status, BookStatus.abandoned);
    expect(res.books[2].status, BookStatus.read);
    expect(res.abandonedCount, 2);
  });

  test('maps a wishlist custom shelf to wanted', () {
    final csv = [
      _header,
      // Exclusive to-read, but wishlist custom shelf → wanted.
      _row(
        title: 'Wish',
        author: 'A',
        shelf: 'to-read',
        bookshelves: 'wishlist',
      ),
      _row(
        title: 'Por comprar',
        author: 'B',
        shelf: 'to-read',
        bookshelves: 'deseados',
      ),
      // DNF still wins over wishlist if both are present.
      _row(
        title: 'Both',
        author: 'C',
        shelf: 'to-read',
        bookshelves: 'wishlist,dnf',
      ),
      _row(title: 'Plain TBR', author: 'D', shelf: 'to-read'),
    ].join('\n');

    final res = parseGoodreadsCsv(csv);
    expect(res.books[0].status, BookStatus.wanted);
    expect(res.books[1].status, BookStatus.wanted);
    expect(res.books[2].status, BookStatus.abandoned);
    expect(res.books[3].status, BookStatus.pending);
    expect(res.wantedCount, 2);
  });

  test('survives a UTF-8 BOM on the header row', () {
    // Goodreads (and Excel round-trips) sometimes prepend a BOM; the header
    // match must still recognize "Title"/"Exclusive Shelf".
    final csv =
        '﻿$_header\n'
        '${_row(title: 'After BOM', author: 'A', shelf: 'read')}';

    final res = parseGoodreadsCsv(csv);
    expect(res.books.single.title, 'After BOM');
    expect(res.books.single.status, BookStatus.read);
  });

  test('rejects a non-Goodreads file', () {
    expect(
      () => parseGoodreadsCsv('foo,bar\n1,2'),
      throwsA(isA<GoodreadsFormatException>()),
    );
  });

  test('truncates beyond the cap and flags it', () {
    final rows = <String>[_header];
    for (var i = 0; i < maxImportBooks + 5; i++) {
      rows.add(_row(title: 'Book $i', author: 'A', shelf: 'to-read'));
    }
    final res = parseGoodreadsCsv(rows.join('\n'));
    expect(res.books.length, maxImportBooks);
    expect(res.truncated, isTrue);
  });

  test('parses My Rating into a 1–5 rating, 0 ⇒ null', () {
    final csv = [
      _header,
      _fullRow(title: 'Rated', rating: '4'),
      _fullRow(title: 'Unrated'),
    ].join('\n');
    final res = parseGoodreadsCsv(csv);
    expect(res.books.firstWhere((b) => b.title == 'Rated').rating, 4);
    expect(res.books.firstWhere((b) => b.title == 'Unrated').rating, isNull);
  });

  test(
    'notes come from Private Notes; My Review becomes reviewMarkdown when rated',
    () {
      final csv = [
        _header,
        _fullRow(
          title: 'HasBoth',
          rating: '5',
          notes: 'secret thoughts',
          review: 'public',
        ),
        _fullRow(title: 'OnlyReviewUnrated', review: 'just a review'),
        _fullRow(title: 'Neither'),
      ].join('\n');
      final res = parseGoodreadsCsv(csv);
      final both = res.books.firstWhere((b) => b.title == 'HasBoth');
      expect(both.notes, 'secret thoughts');
      expect(both.reviewMarkdown, 'public');
      expect(
        res.books.firstWhere((b) => b.title == 'OnlyReviewUnrated').notes,
        'just a review',
      );
      expect(
        res.books
            .firstWhere((b) => b.title == 'OnlyReviewUnrated')
            .reviewMarkdown,
        isEmpty,
      );
      expect(res.books.firstWhere((b) => b.title == 'Neither').notes, '');
    },
  );

  test('review <br> tags become newlines on the review field when rated', () {
    final csv = [
      _header,
      _fullRow(title: 'Brs', rating: '4', review: 'line1<br>line2<br/>line3'),
    ].join('\n');
    final b = parseGoodreadsCsv(csv).books.single;
    expect(b.reviewMarkdown, 'line1\nline2\nline3');
    expect(
      b.toRowJson(timezone: 'Europe/Madrid')['reviewMarkdown'],
      'line1\nline2\nline3',
    );
    expect(
      b.toRowJson(timezone: 'Europe/Madrid').containsKey('notes'),
      isFalse,
    );
    // An unrated/no-notes row omits the keys entirely.
    final bare = _fullRow(title: 'Bare');
    final bareBook = parseGoodreadsCsv('$_header\n$bare').books.single;
    expect(
      bareBook.toRowJson(timezone: 'Europe/Madrid').containsKey('rating'),
      isFalse,
    );
    expect(
      bareBook.toRowJson(timezone: 'Europe/Madrid').containsKey('notes'),
      isFalse,
    );
    expect(
      bareBook
          .toRowJson(timezone: 'Europe/Madrid')
          .containsKey('reviewMarkdown'),
      isFalse,
    );
  });

  test('long notes are truncated to the backend cap', () {
    final long = 'a' * 6000;
    final csv = '$_header\n${_fullRow(title: 'Long', notes: long)}';
    expect(parseGoodreadsCsv(csv).books.single.notes.length, 5000);
  });
}

/// A row that also fills the My Rating / My Review / Private Notes columns
/// (the base [_row] leaves them blank).
String _fullRow({
  required String title,
  String rating = '0',
  String review = '',
  String notes = '',
  String shelf = 'read',
}) =>
    '1,"$title","Author","x","",="",="",$rating,4.10,"",Paperback,200,2008,'
    '2008,,2020/01/01,"",,$shelf,"$review",,"$notes",1,1';
