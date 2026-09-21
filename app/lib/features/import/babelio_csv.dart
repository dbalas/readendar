// Parses Babelio's native library export. Babelio writes a semicolon-delimited
// CSV with French headers, regardless of the language used by Readendar.

import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/features/import/import_models.dart';

class BabelioFormatException implements Exception {
  const BabelioFormatException(this.message);

  final String message;

  @override
  String toString() => 'BabelioFormatException: $message';
}

/// Modern exports are UTF-8, while older Babelio downloads use Windows-1252.
String decodeBabelioCsvBytes(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return String.fromCharCodes(
      bytes.map(
        (byte) => byte >= 0x80 && byte <= 0x9f
            ? _windows1252CodePoints[byte - 0x80]
            : byte,
      ),
    );
  }
}

const _windows1252CodePoints = <int>[
  0x20ac,
  0x0081,
  0x201a,
  0x0192,
  0x201e,
  0x2026,
  0x2020,
  0x2021,
  0x02c6,
  0x2030,
  0x0160,
  0x2039,
  0x0152,
  0x008d,
  0x017d,
  0x008f,
  0x0090,
  0x2018,
  0x2019,
  0x201c,
  0x201d,
  0x2022,
  0x2013,
  0x2014,
  0x02dc,
  0x2122,
  0x0161,
  0x203a,
  0x0153,
  0x009d,
  0x017e,
  0x0178,
];

ImportParseResult parseBabelioCsv(String content) {
  final rows = Csv().decode(content.replaceAll(RegExp(r'\r\n?'), '\n'));

  if (rows.isEmpty) {
    throw const BabelioFormatException('empty file');
  }

  final header = _findHeader(rows);
  if (header == null) {
    throw const BabelioFormatException('missing Babelio columns');
  }

  String cell(List<dynamic> row, _Field field) {
    final index = header.columns[field];
    if (index == null || index >= row.length) return '';
    return _decodeEntities(row[index].toString().trim());
  }

  final books = <ImportedBook>[];
  final seenIsbns = <String>{};
  var skippedNoTitle = 0;
  var duplicatesDropped = 0;
  var truncated = false;
  var skippedNoAuthor = 0;

  for (var rowIndex = header.row + 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.isEmpty) continue;

    final title = cell(row, _Field.title);
    if (title.isEmpty) {
      skippedNoTitle++;
      continue;
    }

    final author = cell(row, _Field.author);
    if (author.isEmpty) {
      skippedNoAuthor++;
      continue;
    }

    final isbn = _cleanIsbn(cell(row, _Field.isbn));
    if (isbn.isNotEmpty && !seenIsbns.add(isbnComparisonKey(isbn))) {
      duplicatesDropped++;
      continue;
    }

    if (books.length >= maxImportBooks) {
      truncated = true;
      break;
    }

    final rating = _rating(cell(row, _Field.rating));
    final mapped = importedReviewAndNotes(
      rating: rating,
      review: cell(row, _Field.review),
    );
    books.add(
      ImportedBook(
        title: title,
        authors: [author],
        isbn: isbn,
        status: _status(cell(row, _Field.status)),
        publisher: cell(row, _Field.publisher),
        rating: rating,
        notes: mapped.notes,
        reviewMarkdown: mapped.reviewMarkdown,
      ),
    );
  }

  return ImportParseResult(
    books: books,
    skippedNoTitle: skippedNoTitle,
    duplicatesDropped: duplicatesDropped,
    truncated: truncated,
    skippedNoAuthor: skippedNoAuthor,
  );
}

enum _Field { isbn, title, author, publisher, status, rating, review }

class _Header {
  const _Header(this.row, this.columns);

  final int row;
  final Map<_Field, int> columns;
}

_Header? _findHeader(List<List<dynamic>> rows) {
  for (var rowIndex = 0; rowIndex < rows.length && rowIndex < 10; rowIndex++) {
    final columns = <_Field, int>{};
    final row = rows[rowIndex];
    for (var index = 0; index < row.length; index++) {
      final value = _normalize(row[index].toString());
      for (final entry in _headerAliases.entries) {
        if (entry.value.contains(value)) {
          columns.putIfAbsent(entry.key, () => index);
          break;
        }
      }
    }
    if (columns.containsKey(_Field.title) &&
        columns.containsKey(_Field.author) &&
        columns.containsKey(_Field.status)) {
      return _Header(rowIndex, columns);
    }
  }
  return null;
}

Set<String> _aliases(List<String> values) => values.map(_normalize).toSet();

final _headerAliases = <_Field, Set<String>>{
  _Field.isbn: _aliases(['ISBN', 'ISBN-10', 'ISBN-13', 'EAN', 'EAN-13']),
  _Field.title: _aliases(['Titre', 'Titre du livre', 'Title', 'Book title']),
  _Field.author: _aliases(['Auteur', 'Auteurs', 'Author', 'Authors']),
  _Field.publisher: _aliases(['Editeur', 'Éditeur', 'Publisher']),
  _Field.status: _aliases(['Statut', 'État', 'Status', 'Reading status']),
  _Field.rating: _aliases(['Note', 'Ma note', 'Rating', 'My rating']),
  _Field.review: _aliases([
    'Critique',
    'Critiques',
    'Ma critique',
    'Avis',
    'Review',
    'My review',
  ]),
};

String _cleanIsbn(String raw) {
  final value = raw.replaceAll(RegExp('[^0-9Xx]'), '').toUpperCase();
  return value.length == 10 || value.length == 13 ? value : '';
}

String _status(String raw) {
  final status = _normalize(raw);
  if (status.contains('abandon')) return BookStatus.abandoned;
  if (status.contains('pense bete') ||
      status == 'memo' ||
      status.contains('souhait')) {
    return BookStatus.wanted;
  }
  if (status.contains('en cours')) return BookStatus.reading;
  if (status == 'lu' || status == 'lus' || status == 'lue') {
    return BookStatus.read;
  }
  return BookStatus.pending;
}

double? _rating(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null ||
      value < 0.5 ||
      value > 5 ||
      value * 2 != (value * 2).truncateToDouble()) {
    return null;
  }
  return value;
}

String _normalize(String raw) {
  return raw
      .replaceFirst('\uFEFF', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[’`´]'), "'")
      .replaceAll(RegExp('[àáâäãå]'), 'a')
      .replaceAll(RegExp('[çč]'), 'c')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[ñ]'), 'n')
      .replaceAll(RegExp('[òóôöõ]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll(RegExp('[ýÿ]'), 'y')
      .replaceAll(RegExp('[^a-z0-9]+'), ' ')
      .trim();
}

String _decodeEntities(String value) {
  var decoded = value.replaceAllMapped(
    RegExp('&#(?:x([0-9a-fA-F]+)|([0-9]+))[;,]'),
    (match) {
      final radix = match.group(1) == null ? 10 : 16;
      final digits = match.group(1) ?? match.group(2)!;
      final codePoint = int.tryParse(digits, radix: radix);
      if (codePoint == null || codePoint > 0x10FFFF) return match.group(0)!;
      return String.fromCharCode(codePoint);
    },
  );
  const named = <String, String>{
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
  };
  for (final entry in named.entries) {
    decoded = decoded.replaceAll(entry.key, entry.value);
  }
  return decoded;
}
