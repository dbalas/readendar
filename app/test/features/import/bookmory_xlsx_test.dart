import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/features/import/bookmory_xlsx.dart';
import 'package:readendar/features/import/import_models.dart';

void main() {
  test('parses localized two-row headers and repeated reading logs', () {
    final bytes = _workbook(
      booksSheet: 'Libros',
      rows: [
        [
          'Información del libro',
          '',
          '',
          '',
          '',
          '',
          'Registro de lectura 1',
          '',
          'Registro de lectura 2',
          '',
        ],
        [
          'Título',
          'Autores/as',
          'Editorial',
          'ISBN',
          'Total de páginas',
          'Lista de deseos',
          'Estado',
          'Calificaciones de estrellas',
          'Comentario',
          'Calificaciones de estrellas',
          'Comentario',
        ],
        [
          'Libro activo',
          'Autora Uno; Autor Dos',
          'Editorial Prueba',
          '9781234567897',
          'Pág. 832',
          'Sí',
          'Leyendo ahora',
          '3.0',
          'Primer comentario',
          '4.5',
          'Comentario reciente',
        ],
      ],
    );

    final result = parseBookmoryXlsx(bytes);
    final book = result.books.single;

    expect(book.title, 'Libro activo');
    expect(book.authors, ['Autora Uno', 'Autor Dos']);
    expect(book.publisher, 'Editorial Prueba');
    expect(book.isbn, '9781234567897');
    expect(book.pageCount, 832);
    expect(book.status, BookStatus.reading);
    expect(book.rating, 4.5);
    expect(book.format, isNull);
    expect(book.reviewMarkdown, 'Comentario reciente');
    expect(book.notes, contains('Primer comentario'));
    expect(book.notes, isNot(contains('Comentario reciente')));
  });

  test('active, read and abandoned status win over wishlist', () {
    final bytes = _workbook(
      booksSheet: 'Books',
      rows: [
        ['Book information', '', '', 'Reading log 1'],
        ['Title', 'Authors', 'Wishlist', 'Status'],
        ['Pending wish', 'A', 'Yes', 'To read'],
        ['Active wish', 'A', 'Yes', 'Reading'],
        ['Read wish', 'A', 'Yes', "I've read it all!"],
        ['Abandoned wish', 'A', 'Yes', 'Gave up'],
        ['Paused wish', 'A', 'Yes', 'Paused'],
      ],
    );

    final books = parseBookmoryXlsx(bytes).books;
    expect(books[0].status, BookStatus.wanted);
    expect(books[1].status, BookStatus.reading);
    expect(books[2].status, BookStatus.read);
    expect(books[3].status, BookStatus.abandoned);
    expect(books[4].status, BookStatus.reading);
  });

  test('matches note sheets to books and reports unmatched sheets', () {
    final bytes = _workbook(
      booksSheet: 'Libros',
      rows: [
        ['Información del libro', '', ''],
        ['Título', 'Autores/as', 'Estado'],
        ['Carl el mazmorrero', 'Matt Dinniman', '¡Lo terminé de leer!'],
      ],
      noteSheets: {
        'Notas (Carl el mazmorrero)': [
          ['Información de la nota', '', '', ''],
          ['Fecha', 'Página', 'Tipo de nota', 'Contenido'],
          ['2026-01-01', 'Pág. 12', 'Nota', 'Un apunte privado'],
        ],
        'Notas (Libro eliminado)': [
          ['Información de la nota', '', '', ''],
          ['Fecha', 'Página', 'Tipo de nota', 'Contenido'],
          ['2026-01-02', '', 'Nota', 'No debe asignarse'],
        ],
      },
    );

    final result = parseBookmoryXlsx(bytes);
    expect(result.books.single.notes, contains('Un apunte privado'));
    expect(result.books.single.notes, contains('Pág. 12'));
    expect(result.unmatchedNoteSheets, 1);
  });

  test('matches note sheets when the book title contains parentheses', () {
    final bytes = _workbook(
      booksSheet: 'Books',
      rows: [
        ['Book information', '', ''],
        ['Title', 'Authors', 'Status'],
        ['Dune (Dune, #1)', 'Frank Herbert', "I've read it all!"],
      ],
      noteSheets: {
        'Notes (Dune (Dune, #1))': [
          ['Note information', '', '', ''],
          ['Date', 'Page', 'Note type', 'Contents'],
          ['', '', 'Note', 'Fear is the mind-killer'],
        ],
      },
    );

    final result = parseBookmoryXlsx(bytes);
    expect(result.books.single.notes, contains('Fear is the mind-killer'));
    expect(result.unmatchedNoteSheets, 0);
  });

  test('supports every Bookmory export locale', () {
    const locales = [
      (
        'كتب',
        'عنوان',
        'المؤلفون',
        'حالة',
        'قائمة الرغبات',
        'نعم',
        'ليقرأ',
        'قراءة',
        'لقد قرأت كل شيء!',
        'استسلم',
        'متوقف مؤقتًا',
      ),
      (
        'Bücher',
        'Titel',
        'Autor*innen',
        'Status',
        'Wunschzettel',
        'Ja',
        'Lesen',
        'Lektüre',
        'Ich habe alles gelesen!',
        'Aufgegeben',
        'Pausiert',
      ),
      (
        'Books',
        'Title',
        'Authors',
        'Status',
        'Wishlist',
        'Yes',
        'To read',
        'Reading',
        "I've read it all!",
        'Gave up',
        'Paused',
      ),
      (
        'Libros',
        'Título',
        'Autores/as',
        'Estado',
        'Lista de deseos',
        'Sí',
        'Leer más tarde',
        'Leyendo ahora',
        '¡Lo terminé de leer!',
        'Dejé de leer',
        'Pausado',
      ),
      (
        'Livres',
        'Titre',
        'Auteurs',
        'Statut',
        'Liste de souhaits',
        'Oui',
        'À lire',
        'En train de lire',
        "J'ai tout lu !",
        'Abandonné',
        'Mis en pause',
      ),
      (
        'Buku',
        'Judul',
        'Pengarang',
        'Status',
        'Daftar Keinginan',
        'Ya',
        'Untuk dibaca',
        'Membaca',
        'Saya sudah membaca semuanya!',
        'Menyerah',
        'Dijeda',
      ),
      (
        'Libri',
        'Titolo',
        'Autori',
        'Stato',
        'Lista dei desideri',
        'Sì',
        'Leggere',
        'Lettura',
        'Ho letto tutto!',
        'Ha rinunciato',
        'In pausa',
      ),
      (
        '書籍',
        'タイトル',
        '著者',
        'スターテス',
        'ウィッシュリスト',
        'はい',
        '読みたい',
        'いま読んでいる',
        '読み終わった！',
        'やめた',
        '一時停止中',
      ),
      (
        '책 목록',
        '책 제목',
        '저자',
        '읽기 상태',
        '구매하고 싶은 책',
        '네',
        '읽을 예정',
        '읽고있는 중',
        '다 읽었어요!',
        '그만 읽었어요',
        '잠시 중단함',
      ),
      (
        'Książki',
        'Tytuł',
        'Autorzy',
        'Status',
        'Lista życzeń',
        'Tak',
        'Do przeczytania',
        'Czytam',
        'Przeczytane!',
        'Porzucone',
        'Wstrzymano',
      ),
      (
        'livros',
        'Título',
        'Autores',
        'Status',
        'Lista de Desejos',
        'Sim',
        'Quero ler',
        'Lendo',
        'Eu li tudo!',
        'Desisti',
        'Pausado',
      ),
      (
        'Книги',
        'Заголовок',
        'Авторы',
        'Статус',
        'Список желаний',
        'Да',
        'К прочтению',
        'Чтение',
        'Я все прочитал!',
        'Бросил читать',
        'На паузе',
      ),
      (
        'Kitabın',
        'Başlık',
        'Yazarlar',
        'Durum',
        'İstek listesi',
        'Evet',
        'Okuyacağım',
        'Okuyorum',
        'Okudum',
        'Vazgeçti',
        'Duraklatıldı',
      ),
      (
        'Книги',
        'Назва',
        'автори',
        'Статус',
        'Список бажань',
        'Так',
        'Читати',
        'Читаю',
        'Прочитано!',
        'Здався',
        'Призупинено',
      ),
      (
        '图书',
        '标题',
        '作者',
        '状态',
        '愿望清单',
        '是的',
        '待读',
        '在读',
        '已读',
        '放弃',
        '已暂停',
      ),
    ];

    for (final (
          sheet,
          title,
          authors,
          status,
          wishlist,
          yes,
          toRead,
          reading,
          read,
          abandoned,
          paused,
        )
        in locales) {
      final result = parseBookmoryXlsx(
        _workbook(
          booksSheet: sheet,
          rows: [
            ['', '', '', ''],
            [title, authors, wishlist, status],
            ['Wish', 'Author', yes, toRead],
            ['Reading', 'Author', yes, reading],
            ['Read', 'Author', yes, read],
            ['Abandoned', 'Author', yes, abandoned],
            ['Paused', 'Author', yes, paused],
          ],
        ),
      );
      expect(result.books[0].status, BookStatus.wanted, reason: '$sheet wish');
      expect(
        result.books[1].status,
        BookStatus.reading,
        reason: '$sheet active',
      );
      expect(result.books[2].status, BookStatus.read, reason: '$sheet read');
      expect(
        result.books[3].status,
        BookStatus.abandoned,
        reason: '$sheet abandoned',
      );
      expect(
        result.books[4].status,
        BookStatus.reading,
        reason: '$sheet paused',
      );
    }
  });

  test('normalizes localized digits and comma decimal ratings', () {
    final bytes = _workbook(
      booksSheet: 'كتب',
      rows: [
        ['', '', '', '', ''],
        ['عنوان', 'المؤلفون', 'ISBN', 'إجمالي الصفحة', 'تصنيفات النجوم'],
        ['كتاب', 'كاتب', '٩٧٨١٢٣٤٥٦٧٨٩٧', 'صفحة ٨٣٢', '٤,٥'],
      ],
    );

    final book = parseBookmoryXlsx(bytes).books.single;
    expect(book.isbn, '9781234567897');
    expect(book.pageCount, 832);
    expect(book.rating, 4.5);
  });

  test('rejects corrupt and unrelated workbooks', () {
    expect(
      () => parseBookmoryXlsx(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<BookmoryFormatException>()),
    );
    expect(
      () => parseBookmoryXlsx(
        _workbook(
          booksSheet: 'Sheet1',
          rows: [
            ['foo', 'bar'],
            ['one', 'two'],
          ],
        ),
      ),
      throwsA(isA<BookmoryFormatException>()),
    );
  });

  test('truncates imported notes to backend limit', () {
    final bytes = _workbook(
      booksSheet: 'Books',
      rows: [
        ['', '', '', ''],
        ['Title', 'Authors', 'Status', 'Comment'],
        ['Long', 'Author', 'Reading', 'x' * 6000],
      ],
    );

    expect(parseBookmoryXlsx(bytes).books.single.notes.runes.length, 5000);
  });

  test('caps oversized libraries and exposes a warning', () {
    final rows = <List<String>>[
      ['', '', ''],
      ['Title', 'Authors', 'Status'],
      for (var index = 0; index < maxImportBooks + 2; index++)
        ['Book $index', 'Author', 'To read'],
    ];

    final result = parseBookmoryXlsx(
      _workbook(booksSheet: 'Books', rows: rows),
    );
    expect(result.books, hasLength(maxImportBooks));
    expect(result.truncated, isTrue);
  });
}

Uint8List _workbook({
  required String booksSheet,
  required List<List<String>> rows,
  Map<String, List<List<String>>> noteSheets = const {},
}) {
  final excel = Excel.createExcel()..rename('Sheet1', booksSheet);
  for (final row in rows) {
    excel[booksSheet].appendRow(
      row.map<TextCellValue>(TextCellValue.new).toList(),
    );
  }
  for (final entry in noteSheets.entries) {
    for (final row in entry.value) {
      excel[entry.key].appendRow(
        row.map<TextCellValue>(TextCellValue.new).toList(),
      );
    }
  }
  return Uint8List.fromList(excel.encode()!);
}
