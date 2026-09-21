/// Title folding and retailer-suffix stripping. Mirrors
/// Catalog title fold key used by search ranking.
library;

const _formatNoiseToken = {
  'ebook',
  'ebookedition',
  'ebookedicion',
  'epub',
  'pdf',
  'mobi',
  'azw',
  'azw3',
  'kindle',
  'kindleedition',
  'edicionkindle',
  'amazonkindle',
  'kindleunlimited',
  'audiobook',
  'audiolibro',
  'audio',
  'digital',
  'electronico',
  'libroelectronico',
  'tapadura',
  'tapablanda',
  'cartone',
  'bolsillo',
  'hardcover',
  'paperback',
  'massmarket',
  'spanishedition',
  'englishedition',
  'edicionespanola',
  'edicionenespanol',
  'edicionespañola',
};

const _editionNoiseToken = {
  'especial',
  'limitada',
  'limitado',
  'limited',
  'deluxe',
  'coleccionista',
  'colleccionista',
  'conmemorativa',
  'actualizada',
  'revisada',
  'ampliada',
  'aumentada',
  'corregida',
  'nueva',
  'nova',
  'oficial',
  'official',
  'pelicula',
  'lujo',
  'sorteo',
  'cantos',
  'tintados',
  'pintados',
  'friday',
  'estuche',
  'pack',
  'lanzamiento',
  'tapa',
  'dura',
  'blanda',
  'espanol',
  'spanish',
  'english',
  'ingles',
  'catala',
  'euskera',
  'euskara',
  'galego',
  'gallego',
  'castellano',
};

const _noiseGlueToken = {
  'edicion',
  'edicio',
  'edition',
  'ed',
  'en',
  'con',
  'de',
  'y',
  'i',
  'a',
  'un',
  'una',
  'el',
  'la',
  'los',
  'las',
  'del',
  'por',
  'para',
  'the',
  'of',
  'and',
  'black',
  'precio',
};

const _strongTrailingToken = {
  'ebook',
  'epub',
  'pdf',
  'mobi',
  'azw',
  'azw3',
  'kindle',
  'audiobook',
  'audiolibro',
};

const _editionWord = {'edicion', 'edicio', 'edition', 'ed'};

/// Strips format and retailer coletillas so stored names and catalog queries
/// match the work.
String cleanTitle(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';
  while (true) {
    var n = s;
    n = _stripWrappedNoise(n, '(', ')');
    n = _stripWrappedNoise(n, '[', ']');
    n = _stripTrailingSepNoise(n, ' - ');
    n = _stripTrailingSepNoise(n, ' / ');
    n = _stripTrailingStrongToken(n);
    n = n.replaceAll(RegExp(r'[\s\-/|,;]+$'), '').trim();
    if (n != s) n = n.replaceAll(RegExp('  +'), ' ').trim();
    if (n == s) return n;
    s = n;
  }
}

/// Lowercase letters+digits only, accents folded. Same contract as Go foldKey.
String foldKey(String raw) {
  final buf = StringBuffer();
  for (final rune in raw.trim().toLowerCase().runes) {
    final folded = _foldRune(String.fromCharCode(rune));
    for (final unit in folded.codeUnits) {
      final isLetter = unit >= 0x61 && unit <= 0x7a;
      final isDigit = unit >= 0x30 && unit <= 0x39;
      if (isLetter || isDigit) buf.writeCharCode(unit);
    }
  }
  return buf.toString();
}

String _foldRune(String ch) {
  switch (ch) {
    case 'á' || 'à' || 'ä' || 'â' || 'ã' || 'å' || 'ā':
      return 'a';
    case 'é' || 'è' || 'ë' || 'ê' || 'ē':
      return 'e';
    case 'í' || 'ì' || 'ï' || 'î' || 'ī':
      return 'i';
    case 'ó' || 'ò' || 'ö' || 'ô' || 'õ' || 'ø' || 'ō':
      return 'o';
    case 'ú' || 'ù' || 'ü' || 'û' || 'ū':
      return 'u';
    case 'ý' || 'ÿ':
      return 'y';
    case 'ñ' || 'ň':
      return 'n';
    case 'ç' || 'č' || 'ć':
      return 'c';
    case 'š':
      return 's';
    case 'ž':
      return 'z';
    case 'æ':
      return 'ae';
    case 'œ':
      return 'oe';
    case 'ß':
      return 'ss';
    case 'ł':
      return 'l';
    default:
      return ch;
  }
}

String _stripWrappedNoise(String s, String open, String close) {
  final rs = s.runes.toList();
  if (rs.length < 3) return s;
  final openR = open.runes.first;
  final closeR = close.runes.first;
  final drop = <({int from, int to})>[];
  for (var i = 0; i < rs.length; i++) {
    if (rs[i] != openR) continue;
    var depth = 0;
    for (var j = i; j < rs.length; j++) {
      if (rs[j] == openR) depth++;
      if (rs[j] == closeR) {
        depth--;
        if (depth != 0) continue;
        final inner = String.fromCharCodes(rs.sublist(i + 1, j)).trim();
        if (_isFormatNoise(inner)) {
          drop.add((from: i, to: j));
        }
        i = j;
      }
      if (depth == 0) break;
    }
  }
  if (drop.isEmpty) return s;
  final buf = StringBuffer();
  var prev = 0;
  for (final sp in drop) {
    buf.write(String.fromCharCodes(rs.sublist(prev, sp.from)));
    prev = sp.to + 1;
  }
  buf.write(String.fromCharCodes(rs.sublist(prev)));
  return buf.toString();
}

String _stripTrailingSepNoise(String s, String sep) {
  s = s.trim();
  final lower = s.toLowerCase();
  final i = lower.lastIndexOf(sep.toLowerCase());
  if (i < 0) return s;
  final head = s.substring(0, i).trim();
  final tail = s.substring(i + sep.length).trim();
  if (head.isEmpty || tail.isEmpty || !_isFormatNoise(tail)) return s;
  return head;
}

String _stripTrailingStrongToken(String s) {
  final fields = s.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (fields.length < 2) return s;
  final last = fields.last.replaceAll(RegExp(r'[()[\]]'), '');
  if (!_strongTrailingToken.contains(foldKey(last))) return s;
  return fields.sublist(0, fields.length - 1).join(' ').trim();
}

bool _isFormatNoise(String inner) {
  inner = inner.trim();
  if (inner.isEmpty) return false;
  if (_formatNoiseToken.contains(foldKey(inner))) return true;
  final parts = inner.split(RegExp(r'[,\/+|·;«»"\s]+'));
  var strong = false;
  var hasEdWord = false;
  var saw = false;
  for (final p in parts) {
    final k = foldKey(p);
    if (k.isEmpty) continue;
    saw = true;
    if (_formatNoiseToken.contains(k) || _editionNoiseToken.contains(k)) {
      strong = true;
      continue;
    }
    if (_noiseGlueToken.contains(k)) {
      if (_editionWord.contains(k)) hasEdWord = true;
      continue;
    }
    if (_isEditionNumber(k)) continue;
    return false;
  }
  return saw && (strong || hasEdWord);
}

bool _isEditionNumber(String k) {
  if (k.isEmpty) return false;
  var n = k;
  while (n.length > 1 && (n.endsWith('a') || n.endsWith('o'))) {
    n = n.substring(0, n.length - 1);
  }
  if (n.isEmpty) return false;
  return RegExp(r'^[0-9]+$').hasMatch(n);
}
