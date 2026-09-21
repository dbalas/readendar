/// Lightweight, dependency-free collation for user-facing alphabetical sorts.
///
/// Dart's `String.compareTo` compares UTF-16 code units, which mis-orders
/// accented Latin letters (e.g. "Ábaco" would sort after "Zorro", and "ñ" after
/// "z"). Since every locale we ship uses the Latin script (es, ca, en, fr, de,
/// it, pt, nl), folding diacritics to their base letter before comparing gives a
/// natural, locale-friendly order without pulling in a full ICU collator.
const Map<String, String> _diacritics = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'ā': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ø': 'o',
  'ō': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
  'ÿ': 'y',
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
};

/// Normalizes [s] for sorting: lower-cased, trimmed, with common Latin
/// diacritics folded to their base letter.
String foldForSort(String s) {
  final lower = s.toLowerCase().trim();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(_diacritics[ch] ?? ch);
  }
  return buf.toString();
}

/// Locale-friendly comparison of two user-visible strings (diacritic-folded,
/// case-insensitive), falling back to the raw comparison on ties so distinct
/// accented spellings stay stable.
int compareLocale(String a, String b) {
  final c = foldForSort(a).compareTo(foldForSort(b));
  return c != 0 ? c : a.toLowerCase().compareTo(b.toLowerCase());
}
