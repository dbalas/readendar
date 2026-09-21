/// Pure matching of parsed Kindle clippings to the user's library books.
///
/// Tiers per source book (title as Kindle wrote it):
///  1. exact normalized-title equality → auto-match;
///  2. normalized prefix/contains + an author-surname overlap → suggested
///     match (pre-filled but visually marked so the user double-checks);
///  3. otherwise unmatched — the user assigns a book (or excludes the group).
library;

import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/quotes/kindle/kindle_clippings.dart';

class KindleBookGroup {
  KindleBookGroup({
    required this.sourceTitle,
    required this.clippings,
    this.sourceAuthor,
    this.match,
    this.suggested = false,
  });

  final String sourceTitle;
  final String? sourceAuthor;
  final List<KindleClipping> clippings;

  /// The assigned library book (auto, suggested, or user-picked). Null =
  /// unmatched; the group is skipped unless the user assigns one.
  Book? match;

  /// True when [match] came from the fuzzy tier (show a "check this" hint).
  bool suggested;
}

// Parallel maps: each rune in _diacritics maps to the ASCII rune at the same
// index in _plain. They MUST stay the same length (asserted below) — a
// mismatch would index _plain out of range (an earlier bug: the à-è-ì-ò-ù run
// dropped its leading 'a', crashing on 'ß').
const _diacritics = 'áàäâãéèëêíìïîóòöôõúùüûñçàèìòùáéíóúäöüß';
const _plain = 'aaaaaeeeeiiiiooooouuuuncaeiouaeiouaous';

/// Lowercase, strip diacritics + punctuation, drop a leading article, collapse
/// whitespace — so "El Aleph" matches "aleph" and "Cien años…" survives the
/// Kindle file's plain-ASCII variants.
String normalizeKindleTitle(String s) {
  assert(
    _diacritics.length == _plain.length,
    'diacritic maps out of sync (${_diacritics.length} vs ${_plain.length})',
  );
  var out = s.toLowerCase();
  final sb = StringBuffer();
  for (final rune in out.runes) {
    final ch = String.fromCharCode(rune);
    final i = _diacritics.indexOf(ch);
    // Defensive bound check: a map-length mismatch must degrade to the
    // original char, never throw and crash the whole import.
    sb.write(i >= 0 && i < _plain.length ? _plain[i] : ch);
  }
  out = sb
      .toString()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  out = out.replaceFirst(
    RegExp(r'^(the|a|an|el|la|los|las|un|una|le|les|der|die|das)\s+'),
    '',
  );
  return out;
}

bool _authorsOverlap(String? sourceAuthor, List<String> bookAuthors) {
  if (sourceAuthor == null || sourceAuthor.isEmpty) return false;
  final sourceWords = normalizeKindleTitle(
    sourceAuthor,
  ).split(' ').where((w) => w.length > 2).toSet();
  for (final a in bookAuthors) {
    final words = normalizeKindleTitle(a).split(' ').where((w) => w.length > 2);
    if (words.any(sourceWords.contains)) return true;
  }
  return false;
}

/// Groups [clippings] by source book and resolves each group against
/// [library] (personal books only — the caller pre-filters).
List<KindleBookGroup> matchKindleClippings(
  List<KindleClipping> clippings,
  List<Book> library,
) {
  final groups = <String, KindleBookGroup>{};
  for (final c in clippings) {
    groups
        .putIfAbsent(
          c.title,
          () => KindleBookGroup(
            sourceTitle: c.title,
            sourceAuthor: c.author,
            clippings: [],
          ),
        )
        .clippings
        .add(c);
  }

  final byNormTitle = <String, Book>{};
  for (final b in library) {
    byNormTitle.putIfAbsent(normalizeKindleTitle(b.title), () => b);
  }

  for (final g in groups.values) {
    final norm = normalizeKindleTitle(g.sourceTitle);
    // Tier 1: exact normalized title.
    final exact = byNormTitle[norm];
    if (exact != null) {
      g.match = exact;
      continue;
    }
    // Tier 2: prefix/contains either way + author-surname overlap.
    for (final b in library) {
      final bn = normalizeKindleTitle(b.title);
      if (bn.isEmpty || norm.isEmpty) continue;
      final titleClose =
          bn.startsWith(norm) ||
          norm.startsWith(bn) ||
          bn.contains(norm) ||
          norm.contains(bn);
      if (titleClose && _authorsOverlap(g.sourceAuthor, b.authors)) {
        g.match = b;
        g.suggested = true;
        break;
      }
    }
  }

  // Books you already have (matched) float to the top so they aren't buried
  // under the long tail of unmatched titles; within each bucket, more highlights
  // first. Computed once — the order stays stable when the user later assigns a
  // book to an unmatched group, so rows don't jump around under their finger.
  final out = groups.values.toList()
    ..sort((a, b) {
      final am = a.match != null;
      final bm = b.match != null;
      if (am != bm) return am ? -1 : 1;
      return b.clippings.length.compareTo(a.clippings.length);
    });
  return out;
}
