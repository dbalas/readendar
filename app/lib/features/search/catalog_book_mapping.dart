import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/isbn.dart';

/// Shared book-row model for a catalog hit. Keeps the catalog cover when
/// [owned] is a library copy.
Book bookFromSearchHit(SearchHit hit, {Book? owned}) {
  final cover = hit.coverUrl.trim();
  if (owned != null) {
    return owned.copyWith(
      coverUrl: cover.isNotEmpty ? cover : null,
    );
  }
  final (isbn13, isbn10) = isbnFieldsFromSearchHit(hit.isbn);
  return Book(
    id: hit.dedupeKey,
    ownerType: OwnerType.user,
    ownerId: '',
    title: hit.title,
    authors: hit.authors,
    status: BookStatus.pending,
    coverUrl: cover,
    description: hit.description,
    pageCount: hit.pageCount,
    isbn13: isbn13,
    isbn10: isbn10,
    publisher: hit.publisher,
    language: hit.language,
    categories: hit.categories,
    categoryCodes: hit.categoryCodes,
    format: hit.format,
    subtitle: hit.subtitle,
    edition: hit.edition,
    binding: hit.binding,
    publicationDate: hit.publicationDate,
    publicationDatePrecision: hit.publicationDatePrecision,
  );
}

/// Library copy for a catalog search row. ISBN / related-edition keys only.
Book? findOwnedLibraryBookForSearchHit(List<Book>? books, SearchHit hit) {
  if (books == null || books.isEmpty) return null;
  final (isbn13, isbn10) = isbnFieldsFromSearchHit(hit.isbn);
  final keys = <String>{
    for (final raw in [isbn13, isbn10])
      if (isbnComparisonKey(raw).isNotEmpty) isbnComparisonKey(raw),
  };
  if (keys.isEmpty) return null;
  return books.where((book) {
    final key = isbnComparisonKey(book.isbnDisplay);
    return key.isNotEmpty && keys.contains(key);
  }).firstOrNull;
}

/// Places [raw] into ISBN-13 and/or ISBN-10 so library matching works.
(String, String) isbnFieldsFromSearchHit(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return ('', '');
  final digits = StringBuffer();
  for (final u in trimmed.codeUnits) {
    if (u >= 0x30 && u <= 0x39) {
      digits.writeCharCode(u);
    } else if (u == 0x58 || u == 0x78) {
      digits.write('X');
    }
  }
  final cleaned = digits.toString();
  final canonical = normalizeScannedIsbn(trimmed);
  if (canonical != null) {
    if (cleaned.length == 10) return (canonical, cleaned);
    return (canonical, '');
  }
  if (cleaned.length == 13) return (cleaned, '');
  if (cleaned.length == 10) return ('', cleaned);
  return (trimmed, '');
}
