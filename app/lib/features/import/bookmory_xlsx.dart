import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/features/import/import_models.dart';

class BookmoryFormatException implements Exception {
  const BookmoryFormatException(this.message);

  final String message;

  @override
  String toString() => 'BookmoryFormatException: $message';
}

ImportParseResult parseBookmoryXlsx(Uint8List bytes) {
  Excel workbook;
  try {
    workbook = Excel.decodeBytes(bytes);
  } on Object {
    throw const BookmoryFormatException('invalid workbook');
  }

  Sheet? booksSheet;
  _Header? bookHeader;
  for (final sheet in workbook.tables.values) {
    final header = _findBookHeader(sheet.rows);
    if (header != null) {
      booksSheet = sheet;
      bookHeader = header;
      break;
    }
  }
  if (booksSheet == null || bookHeader == null) {
    throw const BookmoryFormatException('missing Bookmory books sheet');
  }

  final books = <ImportedBook>[];
  final seenIsbns = <String>{};
  var skippedNoTitle = 0;
  var duplicatesDropped = 0;
  var truncated = false;
  final bookRows = booksSheet.rows;

  for (
    var rowIndex = bookHeader.row + 1;
    rowIndex < bookRows.length;
    rowIndex++
  ) {
    final row = bookRows[rowIndex];
    if (_rowIsEmpty(row)) continue;

    final title = _cell(row, bookHeader.first(_Field.title));
    if (title.isEmpty) {
      skippedNoTitle++;
      continue;
    }

    final isbn = _isbn(_cell(row, bookHeader.first(_Field.isbn)));
    if (isbn.isNotEmpty && !seenIsbns.add(isbnComparisonKey(isbn))) {
      duplicatesDropped++;
      continue;
    }
    if (books.length >= maxImportBooks) {
      truncated = true;
      break;
    }

    final statusValue = _cell(row, bookHeader.first(_Field.status));
    final wishlistValue = _cell(row, bookHeader.first(_Field.wishlist));
    final comments = <String>[
      for (final index in bookHeader.all(_Field.comment))
        if (_cell(row, index).isNotEmpty) _cell(row, index),
    ];
    final rating = _latestRating(row, bookHeader.all(_Field.rating));
    final latestComment = comments.isEmpty ? '' : comments.last;
    final earlierComments = [
      for (final comment in _unique(comments))
        if (comment != latestComment) comment,
    ];
    final mapped = importedReviewAndNotes(
      rating: rating,
      notes: earlierComments.join('\n\n'),
      review: latestComment,
    );

    books.add(
      ImportedBook(
        title: title,
        authors: _authors(_cell(row, bookHeader.first(_Field.authors))),
        isbn: isbn,
        status: _bookStatus(statusValue, wishlistValue),
        pageCount: _integer(_cell(row, bookHeader.first(_Field.pageCount))),
        publisher: _cell(row, bookHeader.first(_Field.publisher)),
        rating: rating,
        notes: mapped.notes,
        reviewMarkdown: mapped.reviewMarkdown,
      ),
    );
  }

  var unmatchedNoteSheets = 0;
  for (final entry in workbook.tables.entries) {
    if (identical(entry.value, booksSheet)) continue;
    final noteRows = entry.value.rows;
    final noteHeader = _findNoteHeader(noteRows);
    if (noteHeader == null) continue;

    final bookIndex = _matchBook(entry.key, books);
    if (bookIndex == null) {
      unmatchedNoteSheets++;
      continue;
    }

    final notes = <String>[];
    for (
      var rowIndex = noteHeader.row + 1;
      rowIndex < noteRows.length;
      rowIndex++
    ) {
      final row = noteRows[rowIndex];
      final content = _cell(row, noteHeader.first(_Field.noteContent));
      if (content.isEmpty) continue;
      final context = <String>[
        _cell(row, noteHeader.first(_Field.noteDate)),
        _cell(row, noteHeader.first(_Field.notePage)),
        _cell(row, noteHeader.first(_Field.noteType)),
      ].where((value) => value.isNotEmpty).join(' · ');
      notes.add(context.isEmpty ? content : '[$context]\n$content');
    }
    if (notes.isEmpty) continue;

    final current = books[bookIndex];
    final joined = [
      if (current.notes.isNotEmpty) current.notes,
      ...notes,
    ].join('\n\n');
    books[bookIndex] = current.copyWith(notes: truncateImportNotes(joined));
  }

  return ImportParseResult(
    books: books,
    skippedNoTitle: skippedNoTitle,
    duplicatesDropped: duplicatesDropped,
    truncated: truncated,
    unmatchedNoteSheets: unmatchedNoteSheets,
  );
}

enum _Field {
  title,
  authors,
  publisher,
  isbn,
  pageCount,
  wishlist,
  status,
  rating,
  comment,
  noteDate,
  notePage,
  noteType,
  noteContent,
}

class _Header {
  const _Header(this.row, this.columns);

  final int row;
  final Map<_Field, List<int>> columns;

  int? first(_Field field) => columns[field]?.firstOrNull;
  List<int> all(_Field field) => columns[field] ?? const [];
}

_Header? _findBookHeader(List<List<Data?>> rows) {
  for (var rowIndex = 0; rowIndex < rows.length && rowIndex < 10; rowIndex++) {
    final columns = _columns(rows[rowIndex], _bookHeaderAliases);
    if (columns.containsKey(_Field.title) &&
        columns.containsKey(_Field.authors)) {
      return _Header(rowIndex, columns);
    }
  }
  return null;
}

_Header? _findNoteHeader(List<List<Data?>> rows) {
  for (var rowIndex = 0; rowIndex < rows.length && rowIndex < 10; rowIndex++) {
    final columns = _columns(rows[rowIndex], _noteHeaderAliases);
    if (columns.containsKey(_Field.noteContent)) {
      return _Header(rowIndex, columns);
    }
  }
  return null;
}

Map<_Field, List<int>> _columns(
  List<Data?> row,
  Map<_Field, Set<String>> aliases,
) {
  final columns = <_Field, List<int>>{};
  for (var index = 0; index < row.length; index++) {
    final value = _normalize(_cell(row, index));
    if (value.isEmpty) continue;
    for (final entry in aliases.entries) {
      if (entry.value.contains(value)) {
        columns.putIfAbsent(entry.key, () => []).add(index);
        break;
      }
    }
  }
  return columns;
}

String _cell(List<Data?> row, int? index) {
  if (index == null || index < 0 || index >= row.length) return '';
  return row[index]?.value?.toString().trim() ?? '';
}

bool _rowIsEmpty(List<Data?> row) =>
    row.every((cell) => cell?.value?.toString().trim().isEmpty ?? true);

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\s_\-–—:：]+'), ' ')
    .replaceAll(RegExp(r'^[\s.!¡?¿()[\]{}]+|[\s.!¡?¿()[\]{}]+$'), '');

String _asciiDigits(String value) {
  const localized = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹０１２３４５６７８９';
  const ascii = '012345678901234567890123456789';
  final out = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = localized.indexOf(char);
    out.write(index < 0 ? char : ascii[index]);
  }
  return out.toString();
}

String _isbn(String value) {
  final normalized = _asciiDigits(
    value,
  ).replaceAll(RegExp('[^0-9Xx]'), '').toUpperCase();
  return normalized.length == 10 || normalized.length == 13 ? normalized : '';
}

int? _integer(String value) {
  final match = RegExp(r'\d+').firstMatch(_asciiDigits(value));
  return match == null ? null : int.tryParse(match.group(0)!);
}

double? _latestRating(List<Data?> row, List<int> indices) {
  double? latest;
  for (final index in indices) {
    final raw = _asciiDigits(_cell(row, index)).replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value != null && value >= 0.5 && value <= 5) latest = value;
  }
  return latest;
}

List<String> _authors(String value) => value
    .split(RegExp(r'[,;\n]'))
    .map((author) => author.trim())
    .where((author) => author.isNotEmpty)
    .toList(growable: false);

String _bookStatus(String status, String wishlist) {
  final normalized = _normalize(status);
  if (_readStatuses.contains(normalized)) return BookStatus.read;
  if (_readingStatuses.contains(normalized) ||
      _pausedStatuses.contains(normalized)) {
    return BookStatus.reading;
  }
  if (_abandonedStatuses.contains(normalized)) return BookStatus.abandoned;
  if (_yesValues.contains(_normalize(wishlist))) return BookStatus.wanted;
  return BookStatus.pending;
}

int? _matchBook(String sheetName, List<ImportedBook> books) {
  var candidate = sheetName;
  final open = sheetName.indexOf('(');
  final close = sheetName.lastIndexOf(')');
  if (open >= 0 && close > open) {
    candidate = sheetName.substring(open + 1, close);
  }
  final normalizedCandidate = _normalize(candidate);
  if (normalizedCandidate.isEmpty) return null;

  final matches = <int>[];
  for (var index = 0; index < books.length; index++) {
    final title = _normalize(books[index].title);
    if (title == normalizedCandidate ||
        title.startsWith(normalizedCandidate) ||
        normalizedCandidate.startsWith(title)) {
      matches.add(index);
    }
  }
  return matches.length == 1 ? matches.single : null;
}

List<String> _unique(List<String> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (seen.add(value)) value,
  ];
}

Set<String> _aliases(List<String> values) => values.map(_normalize).toSet();

final _bookHeaderAliases = <_Field, Set<String>>{
  _Field.title: _aliases([
    'عنوان',
    'Titel',
    'Title',
    'Título',
    'Titre',
    'Judul',
    'Titolo',
    'タイトル',
    '책 제목',
    'Tytuł',
    'Заголовок',
    'Başlık',
    'Назва',
    '标题',
  ]),
  _Field.authors: _aliases([
    'المؤلفون',
    'Autor*innen',
    'Authors',
    'Autores/as',
    'Auteurs',
    'Pengarang',
    'Autori',
    '著者',
    '저자',
    'Autorzy',
    'Autores',
    'Авторы',
    'Yazarlar',
    'автори',
    '作者',
  ]),
  _Field.publisher: _aliases([
    'الناشر',
    'Verlag',
    'Publisher',
    'Editorial',
    'Éditeur',
    'Penerbit',
    'Editore',
    '出版社',
    '출판사',
    'Wydawnictwo',
    'Editor',
    'Издатель',
    'Yayımcı',
    'Видавець',
    '出版商',
  ]),
  _Field.isbn: _aliases(['ISBN']),
  _Field.pageCount: _aliases([
    'إجمالي الصفحة',
    'Seitenanzahl',
    'Total pages',
    'Total de páginas',
    'Total de page',
    'Jumlah halaman',
    'Pagina totale',
    '総ページ',
    '전체 페이지 수',
    'Łączna liczba stron',
    'página total',
    'Всего страниц',
    'toplam sayfa',
    'Всього стор',
    '总页数',
  ]),
  _Field.wishlist: _aliases([
    'قائمة الرغبات',
    'Wunschzettel',
    'Wishlist',
    'Lista de deseos',
    'Liste de souhaits',
    "Liste d'envie", // Older French Bookmory builds.
    'Daftar Keinginan',
    'Lista dei desideri',
    'ウィッシュリスト',
    '구매하고 싶은 책',
    'Lista życzeń',
    'Lista de Desejos',
    'Список желаний',
    'İstek listesi',
    'Список бажань',
    '愿望清单',
  ]),
  _Field.status: _aliases([
    'حالة',
    'Status',
    'Estado',
    'Statut',
    'Stato',
    'スターテス',
    '읽기 상태',
    'Durum',
    'Статус',
    '状态',
  ]),
  _Field.rating: _aliases([
    'تصنيفات النجوم',
    'Sternebewertungen',
    'Star ratings',
    'Calificaciones de estrellas',
    'Classement par étoiles',
    'Peringkat bintang',
    'Classificazioni a stelle',
    '星による評価',
    '별점',
    'Ocena',
    'Classificação por estrelas',
    'Звездные рейтинги',
    'Yıldız derecelendirmeleri',
    'Зіркові рейтинги',
    '星级评分',
  ]),
  _Field.comment: _aliases([
    'تعليق',
    'Kommentar',
    'Comment',
    'Comentario',
    'Commenter',
    'Komentar',
    'Commento',
    'コメント',
    '의견',
    'Komentarz',
    'Comente',
    'Комментарий',
    'Yorum',
    'коментар',
    '评论',
  ]),
};

final _noteHeaderAliases = <_Field, Set<String>>{
  _Field.noteDate: _aliases([
    'تاريخ',
    'Datum',
    'Date',
    'Fecha',
    'Tanggal',
    'Data',
    '日にち',
    '날짜',
    'Дата',
    'Tarih',
    '日期',
  ]),
  _Field.notePage: _aliases([
    'صفحة',
    'Buchseite',
    'Page',
    'Página',
    'Halaman',
    'Pagina',
    'ページ',
    '페이지',
    'Strona',
    'Страница',
    'Sayfa',
    'Сторінка',
    '页数',
  ]),
  _Field.noteType: _aliases([
    'نوع الملاحظة',
    'Notiztyp',
    'Note type',
    'Tipo de nota',
    'Type de note',
    'Jenis catatan',
    'Tipo di nota',
    'ノートタイプ',
    '노트 타입',
    'Typ notatki',
    'tipo de nota',
    'Тип примечания',
    'Not türü',
    'Тип примітки',
    '笔记类型',
  ]),
  _Field.noteContent: _aliases([
    'محتويات',
    'Inhalt',
    'Contents',
    'Contenido',
    'Contenu',
    'Isi',
    'Contenuti',
    'コンテンツ',
    '내용',
    'Treść',
    'Conteúdo',
    'Содержание',
    'içindekiler',
    'Зміст',
    '内容',
  ]),
};

final Set<String> _readStatuses = _aliases([
  'لقد قرأت كل شيء!',
  'Ich habe alles gelesen!',
  "I've read it all!",
  '¡Lo terminé de leer!',
  "J'ai tout lu !",
  'Saya sudah membaca semuanya!',
  'Ho letto tutto!',
  '読み終わった！',
  '다 읽었어요!',
  'Przeczytane!',
  'Eu li tudo!',
  'Я все прочитал!',
  'Okudum',
  'Прочитано!',
  '已读',
]);

final Set<String> _readingStatuses = _aliases([
  'قراءة',
  'Lektüre',
  'Reading',
  'Leyendo ahora',
  'En train de lire',
  'Membaca',
  'Lettura',
  'いま読んでいる',
  '읽고있는 중',
  'Czytam',
  'Lendo',
  'Чтение',
  'Okuyorum',
  'Читаю',
  '在读',
]);

final Set<String> _abandonedStatuses = _aliases([
  'استسلم',
  'Aufgegeben',
  'Gave up',
  'Dejé de leer',
  'Abandonné',
  'Menyerah',
  'Ha rinunciato',
  'やめた',
  '그만 읽었어요',
  'Porzucone',
  'Desisti',
  'Бросил читать',
  'Vazgeçti',
  'Здався',
  '放弃',
]);

final Set<String> _pausedStatuses = _aliases([
  'متوقف مؤقتًا',
  'Pausiert',
  'Paused',
  'Pausado',
  'Mis en pause',
  'Dijeda',
  'In pausa',
  '一時停止中',
  '잠시 중단함',
  'Wstrzymano',
  'На паузе',
  'Duraklatıldı',
  'Призупинено',
  '已暂停',
]);

final Set<String> _yesValues = _aliases([
  'نعم',
  'Ja',
  'Yes',
  'Sí',
  'Oui',
  'Ya',
  'Sì',
  'はい',
  '네',
  'Tak',
  'Sim',
  'Да',
  'Evet',
  'Так',
  '是的',
  '是',
  'true',
  '1',
]);
