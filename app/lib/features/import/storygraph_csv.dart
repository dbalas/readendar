// Parses StoryGraph's native "Export StoryGraph Library" CSV. StoryGraph
// exports English headers regardless of the user's Readendar locale.

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/features/import/import_models.dart';

class StoryGraphFormatException implements Exception {
  const StoryGraphFormatException(this.message);

  final String message;

  @override
  String toString() => 'StoryGraphFormatException: $message';
}

ImportParseResult parseStoryGraphCsv(String content) {
  final rows = Csv(
    autoDetect: false,
  ).decode(content.replaceAll(RegExp(r'\r\n?'), '\n'));

  if (rows.isEmpty) {
    throw const StoryGraphFormatException('empty file');
  }

  final header = _findHeader(rows);
  if (header == null) {
    throw const StoryGraphFormatException('missing StoryGraph columns');
  }

  String cell(List<dynamic> row, _Field field) {
    final index = header.columns[field];
    if (index == null || index >= row.length) return '';
    return _repairStoryGraphMojibake(row[index].toString()).trim();
  }

  final books = <ImportedBook>[];
  final seenIsbns = <String>{};
  var skippedNoTitle = 0;
  var skippedNoAuthor = 0;
  var duplicatesDropped = 0;
  var ratingsRounded = 0;
  var truncated = false;

  for (var rowIndex = header.row + 1; rowIndex < rows.length; rowIndex++) {
    final row = rows[rowIndex];
    if (row.isEmpty || row.every((value) => value.toString().trim().isEmpty)) {
      continue;
    }

    final title = cell(row, _Field.title);
    if (title.isEmpty) {
      skippedNoTitle++;
      continue;
    }

    final authors = _authors(cell(row, _Field.authors));
    if (authors.isEmpty) {
      skippedNoAuthor++;
      continue;
    }

    final isbn = _isbn(cell(row, _Field.isbnUid));
    if (isbn.isNotEmpty && !seenIsbns.add(isbnComparisonKey(isbn))) {
      duplicatesDropped++;
      continue;
    }

    if (books.length >= maxImportBooks) {
      truncated = true;
      break;
    }

    final rating = _rating(cell(row, _Field.rating));
    if (rating.rounded) ratingsRounded++;
    final status = _status(cell(row, _Field.status));
    final mapped = importedReviewAndNotes(
      rating: rating.value,
      review: cell(row, _Field.review),
    );
    books.add(
      ImportedBook(
        title: title,
        authors: authors,
        isbn: isbn,
        status: status,
        format: _format(cell(row, _Field.format)),
        rating: rating.value,
        notes: mapped.notes,
        reviewMarkdown: mapped.reviewMarkdown,
        completedOn: status == BookStatus.read
            ? _completionDate(
                cell(row, _Field.lastDateRead),
                cell(row, _Field.datesRead),
              )
            : null,
      ),
    );
  }

  return ImportParseResult(
    books: books,
    skippedNoTitle: skippedNoTitle,
    skippedNoAuthor: skippedNoAuthor,
    duplicatesDropped: duplicatesDropped,
    truncated: truncated,
    ratingsRounded: ratingsRounded,
  );
}

enum _Field {
  title,
  authors,
  isbnUid,
  format,
  status,
  rating,
  review,
  lastDateRead,
  datesRead,
}

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
      final field = _headerFields[_normalize(row[index].toString())];
      if (field != null) columns.putIfAbsent(field, () => index);
    }
    if (columns.containsKey(_Field.title) &&
        columns.containsKey(_Field.authors) &&
        columns.containsKey(_Field.isbnUid) &&
        columns.containsKey(_Field.status)) {
      return _Header(rowIndex, columns);
    }
  }
  return null;
}

final _headerFields = <String, _Field>{
  'title': _Field.title,
  'authors': _Field.authors,
  'isbn/uid': _Field.isbnUid,
  'isbn / uid': _Field.isbnUid,
  'format': _Field.format,
  'read status': _Field.status,
  'star rating': _Field.rating,
  'review': _Field.review,
  'last date read': _Field.lastDateRead,
  'dates read': _Field.datesRead,
};

DateTime? _completionDate(String lastDateRead, String datesRead) {
  final candidates = <String>[
    if (lastDateRead.trim().isNotEmpty) lastDateRead.trim(),
    ...RegExp(
      r'\d{4}[/-]\d{1,2}[/-]\d{1,2}',
    ).allMatches(datesRead).map((match) => match.group(0)!),
  ];
  for (final raw in candidates.reversed) {
    final parts = raw.split(RegExp('[/-]'));
    if (parts.length != 3) continue;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) continue;
    final value = DateTime.utc(year, month, day);
    if (value.year == year && value.month == month && value.day == day) {
      return value;
    }
  }
  return null;
}

List<String> _authors(String raw) {
  final seen = <String>{};
  return [
    for (final value in raw.split(RegExp(r'[,;\n]')))
      if (value.trim().isNotEmpty && seen.add(value.trim())) value.trim(),
  ];
}

String _isbn(String raw) {
  final value = raw.replaceAll(RegExp('[^0-9Xx]'), '').toUpperCase();
  return value.length == 10 || value.length == 13 ? value : '';
}

String _status(String raw) {
  final value = _normalize(raw).replaceAll('-', ' ');
  return switch (value) {
    'read' => BookStatus.read,
    'currently reading' => BookStatus.reading,
    'did not finish' || 'dnf' => BookStatus.abandoned,
    _ => BookStatus.pending,
  };
}

String? _format(String raw) {
  final value = _normalize(raw);
  if (value.contains('audio')) return BookFormat.audiobook;
  if (value.contains('digital') ||
      value.contains('ebook') ||
      value.contains('e-book')) {
    return BookFormat.ebook;
  }
  if (value.contains('paperback') ||
      value.contains('hardback') ||
      value.contains('hardcover') ||
      value == 'physical') {
    return BookFormat.physical;
  }
  return null;
}

({double? value, bool rounded}) _rating(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null || value <= 0 || value > 5) {
    return (value: null, rounded: false);
  }

  // StoryGraph supports quarter-stars; Readendar persists half-stars. Keep the
  // source rating as closely as the domain allows, with exact quarters rounding
  // upward to the nearest half-star.
  final rounded = (value * 2).round() / 2;
  return (
    value: rounded.clamp(0.5, 5).toDouble(),
    rounded: rounded != value,
  );
}

String _normalize(String raw) => raw
    .replaceFirst('\uFEFF', '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ');

/// StoryGraph currently exports non-ASCII UTF-8 bytes after interpreting them
/// as MacRoman (for example José → Jos√©). The resulting CSV is valid UTF-8, so
/// byte-level decoding cannot detect the damage. Reverse only complete
/// MacRoman glyph sequences that form a valid UTF-8 scalar; standalone real
/// symbols remain untouched.
String _repairStoryGraphMojibake(String raw) {
  final runes = raw.runes.toList(growable: false);
  final repaired = StringBuffer();
  var index = 0;
  while (index < runes.length) {
    final firstByte = _macRomanByteByCodePoint[runes[index]];
    final length = firstByte == null ? 0 : _utf8SequenceLength(firstByte);
    if (length > 1 && index + length <= runes.length) {
      final bytes = <int>[firstByte!];
      var complete = true;
      for (var offset = 1; offset < length; offset++) {
        final byte = _macRomanByteByCodePoint[runes[index + offset]];
        if (byte == null || byte < 0x80 || byte > 0xbf) {
          complete = false;
          break;
        }
        bytes.add(byte);
      }
      if (complete) {
        try {
          repaired.write(utf8.decode(bytes));
          index += length;
          continue;
        } on FormatException {
          // Not a UTF-8 sequence after all; preserve the original glyph.
        }
      }
    }
    repaired.writeCharCode(runes[index]);
    index++;
  }
  return repaired.toString();
}

int _utf8SequenceLength(int byte) {
  if (byte >= 0xc2 && byte <= 0xdf) return 2;
  if (byte >= 0xe0 && byte <= 0xef) return 3;
  if (byte >= 0xf0 && byte <= 0xf4) return 4;
  return 0;
}

final _macRomanByteByCodePoint = <int, int>{
  for (var index = 0; index < _macRomanCodePoints.length; index++)
    _macRomanCodePoints[index]: index + 0x80,
};

const _macRomanCodePoints = <int>[
  0x00c4,
  0x00c5,
  0x00c7,
  0x00c9,
  0x00d1,
  0x00d6,
  0x00dc,
  0x00e1,
  0x00e0,
  0x00e2,
  0x00e4,
  0x00e3,
  0x00e5,
  0x00e7,
  0x00e9,
  0x00e8,
  0x00ea,
  0x00eb,
  0x00ed,
  0x00ec,
  0x00ee,
  0x00ef,
  0x00f1,
  0x00f3,
  0x00f2,
  0x00f4,
  0x00f6,
  0x00f5,
  0x00fa,
  0x00f9,
  0x00fb,
  0x00fc,
  0x2020,
  0x00b0,
  0x00a2,
  0x00a3,
  0x00a7,
  0x2022,
  0x00b6,
  0x00df,
  0x00ae,
  0x00a9,
  0x2122,
  0x00b4,
  0x00a8,
  0x2260,
  0x00c6,
  0x00d8,
  0x221e,
  0x00b1,
  0x2264,
  0x2265,
  0x00a5,
  0x00b5,
  0x2202,
  0x2211,
  0x220f,
  0x03c0,
  0x222b,
  0x00aa,
  0x00ba,
  0x03a9,
  0x00e6,
  0x00f8,
  0x00bf,
  0x00a1,
  0x00ac,
  0x221a,
  0x0192,
  0x2248,
  0x2206,
  0x00ab,
  0x00bb,
  0x2026,
  0x00a0,
  0x00c0,
  0x00c3,
  0x00d5,
  0x0152,
  0x0153,
  0x2013,
  0x2014,
  0x201c,
  0x201d,
  0x2018,
  0x2019,
  0x00f7,
  0x25ca,
  0x00ff,
  0x0178,
  0x2044,
  0x20ac,
  0x2039,
  0x203a,
  0xfb01,
  0xfb02,
  0x2021,
  0x00b7,
  0x201a,
  0x201e,
  0x2030,
  0x00c2,
  0x00ca,
  0x00c1,
  0x00cb,
  0x00c8,
  0x00cd,
  0x00ce,
  0x00cf,
  0x00cc,
  0x00d3,
  0x00d4,
  0xf8ff,
  0x00d2,
  0x00da,
  0x00db,
  0x00d9,
  0x0131,
  0x02c6,
  0x02dc,
  0x00af,
  0x02d8,
  0x02d9,
  0x02da,
  0x00b8,
  0x02dd,
  0x02db,
  0x02c7,
];
