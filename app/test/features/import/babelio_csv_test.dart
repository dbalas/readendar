import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/features/import/babelio_csv.dart';
import 'package:readendar/features/import/import_models.dart';

const _header =
    '"ISBN";"Titre";"Auteur";"Editeur";"Date de publication";"Date d`entrée dans Babelio";"Statut";"Note"';

void main() {
  test('parses the native Babelio export format', () {
    const csv =
        '''
$_header
"9782729119225";"RUR : Rossum's Universal Robots";"&#268,apek Karel";"Editions de La Différence";"2011-02-17";"2013-07-02 22:12:45";"Lu";"4"
"9782213677651";"Amazonie &amp; ailleurs";"Malet Jean-Baptiste";"Fayard";"2013-05-02";"2013-06-14 22:08:00";"En cours";"4,5"
"9782070737628";"Vies parallèles";"Plutarque";"Gallimard";"2001-11-30";"2013-03-04 07:52:31";"Pense-bête";"0"
''';

    final result = parseBabelioCsv(csv);

    expect(result.books, hasLength(3));
    expect(result.books[0].title, "RUR : Rossum's Universal Robots");
    expect(result.books[0].authors, ['Čapek Karel']);
    expect(result.books[0].publisher, 'Editions de La Différence');
    expect(result.books[0].isbn, '9782729119225');
    expect(result.books[0].status, BookStatus.read);
    expect(result.books[0].rating, 4);
    expect(result.books[0].pageCount, isNull);
    expect(result.books[0].format, isNull);
    expect(result.books[1].title, 'Amazonie & ailleurs');
    expect(result.books[1].status, BookStatus.reading);
    expect(result.books[1].rating, 4.5);
    expect(result.books[2].status, BookStatus.wanted);
    expect(result.books[2].rating, isNull);
  });

  test('maps Babelio statuses without requiring an English export', () {
    final result = parseBabelioCsv('''
$_header
"";"Lu";"Author";"";"";"";"Lu";""
"";"À lire";"Author";"";"";"";"À lire";""
"";"En cours";"Author";"";"";"";"En cours de lecture";""
"";"Mémo";"Author";"";"";"";"Pense-bête";""
"";"Abandonné";"Author";"";"";"";"Abandonné";""
''');

    expect(
      result.books.map((book) => book.status),
      [
        BookStatus.read,
        BookStatus.pending,
        BookStatus.reading,
        BookStatus.wanted,
        BookStatus.abandoned,
      ],
    );
  });

  test('accepts BOM and header punctuation variants', () {
    const csv =
        '\uFEFF"ISBN";"Titre";"Auteur";"Éditeur";"Statut";"Note"\n"=9782070737628";"Vies parallèles";"Plutarque";"Gallimard";"A lire";"5"';

    final book = parseBabelioCsv(csv).books.single;

    expect(book.isbn, '9782070737628');
    expect(book.publisher, 'Gallimard');
    expect(book.status, BookStatus.pending);
  });

  test('finds a supported header after an Excel preamble', () {
    const csv = '''
sep=;
"EAN-13";"Titre du livre";"Auteurs";"Éditeur";"État";"Ma note"
"9782070737628";"Vies parallèles";"Plutarque";"Gallimard";"Lu";"5"
''';

    final book = parseBabelioCsv(csv).books.single;

    expect(book.title, 'Vies parallèles');
    expect(book.authors, ['Plutarque']);
    expect(book.isbn, '9782070737628');
    expect(book.publisher, 'Gallimard');
    expect(book.status, BookStatus.read);
    expect(book.rating, 5);
  });

  test('decodes older Windows-1252 Babelio exports', () {
    const csv =
        'ISBN;Titre;Auteur;Editeur;Statut;Note\n'
        ';L’été — «édition»;François;Éditions du Café;Lu;5';

    final content = decodeBabelioCsvBytes(
      Uint8List.fromList(
        latin1.encode(csv.replaceAll('’', '\x92').replaceAll('—', '\x97')),
      ),
    );
    final book = parseBabelioCsv(content).books.single;

    expect(book.title, 'L’été — «édition»');
    expect(book.authors, ['François']);
    expect(book.publisher, 'Éditions du Café');
  });

  test('accepts exports without an optional ISBN column', () {
    const csv =
        'Titre;Auteur;Editeur;Statut;Note\n'
        'A book;An author;A publisher;Lu;4';

    final book = parseBabelioCsv(csv).books.single;

    expect(book.title, 'A book');
    expect(book.isbn, isEmpty);
  });

  test('reports skipped titles and drops duplicate ISBNs', () {
    final result = parseBabelioCsv('''
$_header
"9782070737628";"First";"Author";"";"";"";"Lu";""
"9782070737628";"Duplicate";"Author";"";"";"";"Lu";""
"9780000000002";"";"Author";"";"";"";"Lu";""
''');

    expect(result.books.single.title, 'First');
    expect(result.duplicatesDropped, 1);
    expect(result.skippedNoTitle, 1);
  });

  test('skips rows without an author before review', () {
    final result = parseBabelioCsv('''
$_header
"9782070737628";"Missing author";"";"";"";"";"Lu";""
"";"Valid";"Plutarque";"";"";"";"Lu";""
''');

    expect(result.books.single.title, 'Valid');
    expect(result.skippedNoAuthor, 1);
  });

  test('drops ratings the backend cannot persist', () {
    final book = parseBabelioCsv('''
$_header
"";"Book";"Author";"";"";"";"Lu";"4,2"
''').books.single;

    expect(book.rating, isNull);
  });

  test('maps Critique onto reviewMarkdown when the row is rated', () {
    const csv = '''
"ISBN";"Titre";"Auteur";"Editeur";"Statut";"Note";"Critique"
"";"Book";"Author";"";"Lu";"4";"Une <i>belle</i> lecture"
"";"Unrated";"Author";"";"Lu";"0";"Sans note"
''';

    final result = parseBabelioCsv(csv);

    expect(result.books[0].rating, 4);
    expect(result.books[0].reviewMarkdown, 'Une belle lecture');
    expect(result.books[0].notes, isEmpty);
    expect(result.books[1].rating, isNull);
    expect(result.books[1].reviewMarkdown, isEmpty);
    expect(result.books[1].notes, 'Sans note');
  });

  test('rejects files without Babelio columns', () {
    expect(
      () => parseBabelioCsv('Title,Author\nA book,Someone'),
      throwsA(isA<BabelioFormatException>()),
    );
  });

  test('caps large Babelio exports', () {
    final rows = <String>[_header];
    for (var i = 0; i <= maxImportBooks; i++) {
      rows.add('"";"Book $i";"Author";"";"";"";"Lu";""');
    }

    final result = parseBabelioCsv(rows.join('\n'));

    expect(result.books, hasLength(maxImportBooks));
    expect(result.truncated, isTrue);
  });
}
