// Parses a Goodreads "Export Library" CSV (the only robust way to get a user's
// data out of Goodreads — the public API was retired in 2020).
//
// All the messy format-specific logic lives here so the rest of the import flow
// works with clean [ImportedBook] rows. This file is pure Dart (no Flutter) so
// it is exhaustively unit-tested.

import 'package:csv/csv.dart';

import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/features/import/import_models.dart';

/// One book parsed from the export, already mapped onto our domain.
/// Recognized Goodreads exclusive-shelf values → our [BookStatus].
const _shelfToStatus = <String, String>{
  'read': BookStatus.read,
  'currently-reading': BookStatus.reading,
  'to-read': BookStatus.pending,
};

/// Substrings that, when found in a row's custom "Bookshelves", mark the book as
/// did-not-finish → [BookStatus.abandoned]. Goodreads has no exclusive
/// "abandoned" shelf, so users tag DNFs with a custom shelf; we recognize the
/// common spellings across the languages the app supports (en/es/ca/fr/de).
/// Matched case-insensitively as substrings so `did-not-finish`, `dnf-2023`,
/// `abandonado`, `abandonné`, etc. all hit.
const _dnfMarkers = <String>[
  'dnf',
  'did-not-finish',
  'did not finish',
  'not-finished',
  'unfinished',
  'abandon', // abandoned / abandonado / abandonat / abandonné
  'gave-up',
  'gave up',
  'no-termin', // no-terminado / no-termine
  'no termin',
  'abgebrochen', // de
];

/// Custom-shelf markers for wishlist / not-yet-owned books → [BookStatus.wanted].
/// Goodreads has no exclusive wishlist shelf; users tag these on Bookshelves.
const _wishlistMarkers = <String>[
  'wishlist',
  'wish-list',
  'wish list',
  'to-buy',
  'to buy',
  'want-to-buy',
  'want to buy',
  'to-get',
  'to get',
  'deseado', // es/ca
  'deseados',
  'lista-de-deseos',
  'lista de deseos',
  'liste-de-souhaits', // fr
  'liste de souhaits',
  'wunschliste', // de
  'verlanglijst', // nl
  'lista-de-desejos', // pt
  'lista de desejos',
  'desejado',
  'desejados',
];

/// Thrown when the file doesn't look like a Goodreads export at all (no header
/// we recognize). The UI maps this to a friendly "this isn't a Goodreads CSV".
class GoodreadsFormatException implements Exception {
  const GoodreadsFormatException(this.message);
  final String message;
  @override
  String toString() => 'GoodreadsFormatException: $message';
}

/// Parses [content] (the raw CSV text) into importable books.
ImportParseResult parseGoodreadsCsv(String content) {
  // Goodreads quotes fields and embeds commas/newlines, so a real RFC-4180
  // parser is required (not a naive split). Numbers stay strings — the ISBN
  // columns are Excel-escaped text we clean ourselves.
  final rows = Csv(
    autoDetect: false,
  ).decode(content.replaceAll(RegExp(r'\r\n?'), '\n'));

  if (rows.isEmpty) {
    throw const GoodreadsFormatException('empty file');
  }

  final header = rows.first.map((c) => c.toString().trim()).toList();
  final col = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    col[header[i]] = i;
  }
  // The Title + Exclusive Shelf columns are the minimum that identifies a
  // Goodreads export. Without them we refuse rather than import garbage.
  if (!col.containsKey('Title') || !col.containsKey('Exclusive Shelf')) {
    throw const GoodreadsFormatException('missing Goodreads columns');
  }

  String cell(List<dynamic> row, String name) {
    final idx = col[name];
    if (idx == null || idx >= row.length) return '';
    return row[idx].toString().trim();
  }

  final books = <ImportedBook>[];
  final seenIsbns = <String>{};
  var skippedNoTitle = 0;
  var duplicatesDropped = 0;
  var truncated = false;

  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.isEmpty) continue;

    final title = cell(row, 'Title');
    if (title.isEmpty) {
      skippedNoTitle++;
      continue;
    }

    final isbn = _pickIsbn(cell(row, 'ISBN13'), cell(row, 'ISBN'));
    if (isbn.isNotEmpty) {
      final key = isbnComparisonKey(isbn);
      if (seenIsbns.contains(key)) {
        duplicatesDropped++;
        continue;
      }
      seenIsbns.add(key);
    }

    if (books.length >= maxImportBooks) {
      truncated = true;
      break;
    }

    final status = _status(
      cell(row, 'Exclusive Shelf'),
      cell(row, 'Bookshelves'),
    );
    final rating = _rating(cell(row, 'My Rating'));
    final mapped = importedReviewAndNotes(
      rating: rating,
      notes: cell(row, 'Private Notes'),
      review: cell(row, 'My Review'),
    );
    books.add(
      ImportedBook(
        title: title,
        authors: _authors(cell(row, 'Author'), cell(row, 'Additional Authors')),
        isbn: isbn,
        status: status,
        pageCount: _toInt(cell(row, 'Number of Pages')),
        publisher: cell(row, 'Publisher'),
        format: _format(cell(row, 'Binding')),
        rating: rating,
        notes: mapped.notes,
        reviewMarkdown: mapped.reviewMarkdown,
        completedOn: status == BookStatus.read
            ? _exportDate(cell(row, 'Date Read'))
            : null,
      ),
    );
  }

  return ImportParseResult(
    books: books,
    skippedNoTitle: skippedNoTitle,
    duplicatesDropped: duplicatesDropped,
    truncated: truncated,
  );
}

DateTime? _exportDate(String raw) {
  final match = RegExp(
    r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$',
  ).firstMatch(raw.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final value = DateTime.utc(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    return null;
  }
  return value;
}

/// Goodreads writes ISBNs as Excel text formulas, e.g. `="9780439023481"` (or an
/// empty `=""`). Strip the `=` and quotes and keep only ISBN characters. Prefers
/// the 13-digit column.
String _cleanIsbn(String raw) {
  final s = raw.replaceAll(RegExp('[^0-9Xx]'), '').toUpperCase();
  return (s.length == 13 || s.length == 10) ? s : '';
}

String _pickIsbn(String isbn13, String isbn10) {
  final i13 = _cleanIsbn(isbn13);
  if (i13.isNotEmpty) return i13;
  return _cleanIsbn(isbn10);
}

List<String> _authors(String primary, String additional) {
  final out = <String>[];
  if (primary.trim().isNotEmpty) out.add(primary.trim());
  for (final a in additional.split(',')) {
    final t = a.trim();
    if (t.isNotEmpty) out.add(t);
  }
  return out;
}

/// Maps a row to a [BookStatus]. Custom-shelf signals win over the exclusive
/// shelf: DNF → abandoned, then wishlist → wanted, else exclusive-shelf map.
String _status(String shelf, String bookshelves) {
  if (_hasMarker(bookshelves, _dnfMarkers)) return BookStatus.abandoned;
  if (_hasMarker(bookshelves, _wishlistMarkers)) return BookStatus.wanted;
  return _shelfToStatus[shelf.trim().toLowerCase()] ?? BookStatus.pending;
}

bool _hasMarker(String bookshelves, List<String> markers) {
  if (bookshelves.isEmpty) return false;
  final b = bookshelves.toLowerCase();
  for (final marker in markers) {
    if (b.contains(marker)) return true;
  }
  return false;
}

/// Maps a Goodreads "Binding" (e.g. "Paperback", "Kindle Edition", "Audiobook")
/// onto one of our [BookFormat] values. Returns null for unknown/empty bindings
/// so the book just keeps no format rather than a wrong one.
String? _format(String binding) {
  final b = binding.toLowerCase();
  if (b.isEmpty) return null;
  if (b.contains('audio') || b.contains('audible')) return BookFormat.audiobook;
  if (b.contains('kindle') ||
      b.contains('ebook') ||
      b.contains('e-book') ||
      b.contains('nook') ||
      b.contains('digital')) {
    return BookFormat.ebook;
  }
  if (b.contains('paperback') ||
      b.contains('hardcover') ||
      b.contains('hardback') ||
      b.contains('mass market') ||
      b.contains('board book') ||
      b.contains('library binding') ||
      b.contains('turtleback') ||
      b.contains('leather') ||
      b.contains('spiral')) {
    return BookFormat.physical;
  }
  return null;
}

int? _toInt(String s) {
  if (s.isEmpty) return null;
  return int.tryParse(s.replaceAll(RegExp('[^0-9]'), ''));
}

/// Goodreads "My Rating" is an integer 0–5 (0 = unrated). Maps to 1–5 or null.
double? _rating(String raw) {
  final v = int.tryParse(raw.trim());
  if (v == null || v < 1 || v > 5) return null;
  return v.toDouble();
}
