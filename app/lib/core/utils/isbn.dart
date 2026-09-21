// ISBN normalization + validation for the barcode scanner (spec §17).
//
// Book barcodes are EAN-13 (the ISBN-13, prefix 978/979 — the international
// "Bookland" standard every modern book uses) and sometimes carry an EAN-5
// price add-on we ignore. This helper accepts a raw scanned (or typed) string
// and returns a checksum-valid ISBN-13, or null when the code is not a book
// ISBN. Mirrors the backend's NormalizeISBN intent but adds check-digit
// validation so junk barcodes never hit catalog lookup.

/// True when [raw] should use exact ISBN lookup, not free-text catalog search.
bool looksLikeIsbnQuery(String raw) {
  final q = raw.trim();
  if (q.isEmpty) return false;
  if (normalizeScannedIsbn(q) != null) return true;
  final d = q.replaceAll(RegExp('[^0-9Xx]'), '');
  return d.length == 10 || d.length == 13;
}

/// Returns a checksum-valid ISBN-13 for [raw], or null if it is not a book ISBN.
///
/// Accepts: EAN-13/ISBN-13 with a 978/979 prefix and ISBN-10 (converted to 13,
/// for the manual-entry fallback). Hyphens/spaces and any trailing EAN-5 price
/// add-on are stripped.
String? normalizeScannedIsbn(String raw) {
  final digits = _digitsAndX(raw);

  // Drop a trailing EAN-5 price add-on if present (18 = 13 + 5).
  final core = digits.length == 18 ? digits.substring(0, 13) : digits;

  switch (core.length) {
    case 13:
      return _isValidIsbn13(core) && _hasBookPrefix(core) ? core : null;
    case 10:
      return _isValidIsbn10(core) ? _isbn10To13(core) : null;
    default:
      return null;
  }
}

/// True when [raw] resolves to a valid book ISBN-13.
bool isValidScannedIsbn(String raw) => normalizeScannedIsbn(raw) != null;

/// Stable key for comparing ISBNs across import sources and stored books.
///
/// Valid ISBN-10 values are converted to ISBN-13 so the two representations of
/// one edition compare equal. Legacy imports historically accepted
/// checksum-invalid 10/13-character values, so those retain a cleaned key
/// instead of disappearing from duplicate detection.
String isbnComparisonKey(String raw) {
  final canonical = normalizeScannedIsbn(raw);
  if (canonical != null) return canonical;
  final cleaned = _digitsAndX(raw);
  return cleaned.length == 10 || cleaned.length == 13 ? cleaned : '';
}

/// Human-readable ISBN for UI labels (standard hyphen groups).
///
/// Valid Bookland ISBN-13 values render as `978-0-7653-1178-8`. ISBN-10 keeps
/// the same registrant/title splits. Unknown lengths fall back to the cleaned
/// digits so legacy imports still show something stable.
String formatIsbnDisplay(String raw) {
  final cleaned = _digitsAndX(raw);
  if (cleaned.length == 13 && _hasBookPrefix(cleaned)) {
    return '${cleaned.substring(0, 3)}-${_hyphenateIsbn10(cleaned.substring(3))}';
  }
  if (cleaned.length == 10) {
    return _hyphenateIsbn10(cleaned);
  }
  final trimmed = raw.trim();
  return trimmed.isNotEmpty ? trimmed : cleaned;
}

String _hyphenateIsbn10(String isbn10) {
  final s = isbn10.toUpperCase();
  if (s.length != 10) return isbn10;

  final groupLen = _isbn10RegistrationGroupLen(s);
  var i = groupLen;

  final publisherLen = _isbn10PublisherLen(s, groupLen: groupLen);
  i += publisherLen;

  return [
    s.substring(0, groupLen),
    s.substring(groupLen, i),
    s.substring(i, 9),
    s.substring(9),
  ].join('-');
}

int _isbn10RegistrationGroupLen(String isbn10) {
  final first = isbn10.codeUnitAt(0) - 0x30;
  if (first <= 7) return 1;
  if (first == 8) return 1;
  final prefix = int.tryParse(isbn10.substring(0, 3)) ?? 0;
  return prefix >= 930 ? 3 : 1;
}

int _isbn10PublisherLen(String isbn10, {required int groupLen}) {
  final bodyLen = 9 - groupLen;
  if (bodyLen <= 1) return 1;
  if (groupLen == 1 && (isbn10[0] == '0' || isbn10[0] == '1')) {
    final second = isbn10.codeUnitAt(1) - 0x30;
    return second >= 7 ? 4 : 3;
  }
  if (groupLen == 3) return bodyLen > 2 ? 2 : 1;
  return bodyLen > 2 ? 2 : 1;
}

String _digitsAndX(String raw) {
  final b = StringBuffer();
  for (final u in raw.codeUnits) {
    if (u >= 0x30 && u <= 0x39) {
      b.writeCharCode(u); // '0'..'9'
    } else if (u == 0x58 || u == 0x78) {
      b.write('X'); // 'X' or 'x'
    }
  }
  return b.toString();
}

bool _hasBookPrefix(String isbn13) =>
    isbn13.startsWith('978') || isbn13.startsWith('979');

final _isbn13Re = RegExp(r'^\d{13}$');
final _isbn10Re = RegExp(r'^\d{9}[\dX]$');

bool _isValidIsbn13(String s) {
  if (!_isbn13Re.hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    final d = s.codeUnitAt(i) - 0x30;
    sum += i.isEven ? d : d * 3;
  }
  return sum % 10 == 0;
}

bool _isValidIsbn10(String s) {
  if (!_isbn10Re.hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    final ch = s[i];
    final d = (ch == 'X') ? 10 : ch.codeUnitAt(0) - 0x30;
    sum += d * (10 - i);
  }
  return sum % 11 == 0;
}

/// Converts a valid ISBN-10 to a checksum-correct ISBN-13 (978 + first 9 digits
/// + recomputed check digit).
String _isbn10To13(String isbn10) {
  final body = '978${isbn10.substring(0, 9)}';
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final d = body.codeUnitAt(i) - 0x30;
    sum += i.isEven ? d : d * 3;
  }
  final check = (10 - (sum % 10)) % 10;
  return '$body$check';
}
