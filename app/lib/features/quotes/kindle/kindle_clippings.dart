/// Pure-Dart parser for Kindle's `My Clippings.txt` (mirrors the structure of
/// features/import/goodreads_csv.dart: parse client-side, no plugins, fully
/// unit-testable).
///
/// The file is a sequence of entries separated by lines of `=` characters:
///
///     Cien años de soledad (Gabriel García Márquez)
///     - Tu subrayado en la página 9 | posición 120-122 | Añadido el ...
///
///     El mundo era tan reciente…
///     ==========
///
/// Only HIGHLIGHTS become quotes and NOTES become note-category annotations.
/// Bookmarks (no body) are skipped and counted. The metadata line is
/// matched language-agnostically (Kindle localizes it): the page number is the
/// first `page/página/pàgina/Seite N` group; the "location/posición" range is
/// deliberately NOT mapped to a page.
library;

import 'package:readendar/core/models/enums.dart';

class KindleClipping {
  const KindleClipping({
    required this.title,
    required this.text,
    this.author,
    this.page,
    this.category = AnnotationCategory.quote,
  });

  /// The book title exactly as Kindle wrote it (line 1, minus the author).
  final String title;

  /// The last balanced parenthetical of line 1 — Kindle appends `(Author)`,
  /// and taking the LAST group keeps titles that contain parentheses intact.
  final String? author;
  final String text;
  final int? page;
  final AnnotationCategory category;
}

class KindleParseResult {
  const KindleParseResult({
    required this.clippings,
    required this.skippedNotes,
    required this.skippedBookmarks,
    required this.duplicatesDropped,
  });

  final List<KindleClipping> clippings;
  final int skippedNotes;
  final int skippedBookmarks;
  final int duplicatesDropped;

  bool get isEmpty => clippings.isEmpty;
}

final _separator = RegExp('={6,}');
final _pageRe = RegExp(
  r'(?:page|p[áa]gina|p[àa]gina|seite)\s+(\d+)',
  caseSensitive: false,
);
// Localized markers for the two non-highlight entry kinds. Word-bounded so
// e.g. German "Notiz" doesn't false-positive on \bnote\b and Spanish
// "marcador" doesn't collide with German "Markierung" (= highlight).
final _noteRe = RegExp(r'\b(nota|note|notiz)\b', caseSensitive: false);
final _bookmarkRe = RegExp(
  r'\b(marcador|bookmark|lesezeichen|signet|adreça)\b',
  caseSensitive: false,
);
final _titleAuthorRe = RegExp(r'^(.*)\(([^()]*)\)\s*$');

KindleParseResult parseKindleClippings(String content) {
  // BOM + CRLF normalization (Kindle writes both).
  var src = content;
  if (src.startsWith('﻿')) src = src.substring(1);
  src = src.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  final clippings = <KindleClipping>[];
  final seen = <String>{};
  var notes = 0;
  var bookmarks = 0;
  var duplicates = 0;

  for (final rawEntry in src.split(_separator)) {
    final entry = rawEntry.trim();
    if (entry.isEmpty) continue;
    final lines = entry.split('\n');
    if (lines.length < 2) continue;

    final header = lines.first.trim();
    final meta = lines[1].trim();
    if (!meta.startsWith('-')) continue; // not a clippings entry

    if (_bookmarkRe.hasMatch(meta)) {
      bookmarks++;
      continue;
    }

    final body = lines.skip(2).join('\n').trim();
    final isNote = _noteRe.hasMatch(meta);
    if (body.isEmpty) {
      if (isNote) notes++;
      continue;
    }

    var title = header;
    String? author;
    final m = _titleAuthorRe.firstMatch(header);
    if (m != null && m.group(1)!.trim().isNotEmpty) {
      title = m.group(1)!.trim();
      final a = m.group(2)!.trim();
      if (a.isNotEmpty) author = a;
    }

    final page = _pageRe.firstMatch(meta)?.group(1);

    final key =
        '${title.toLowerCase()}|${body.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')}';
    if (!seen.add(key)) {
      duplicates++;
      continue;
    }

    clippings.add(
      KindleClipping(
        title: title,
        author: author,
        text: body.replaceAll(RegExp(r'\s+'), ' ').trim(),
        page: page == null ? null : int.tryParse(page),
        category: isNote ? AnnotationCategory.note : AnnotationCategory.quote,
      ),
    );
  }

  return KindleParseResult(
    clippings: clippings,
    skippedNotes: notes,
    skippedBookmarks: bookmarks,
    duplicatesDropped: duplicates,
  );
}
