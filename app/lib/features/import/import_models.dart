import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/core/utils/isbn.dart';

/// One row parsed from any supported library export.
class ImportedBook {
  const ImportedBook({
    required this.title,
    required this.authors,
    required this.isbn,
    required this.status,
    this.pageCount,
    this.publisher = '',
    this.format,
    this.rating,
    this.notes = '',
    this.reviewMarkdown = '',
    this.completedOn,
  });

  final String title;
  final List<String> authors;
  final String isbn;
  final String status;
  final int? pageCount;
  final String publisher;
  final String? format;
  final double? rating;
  final String notes;
  final String reviewMarkdown;

  /// Date-only completion value from the source export. Its UTC location is a
  /// neutral container; it is not an instant until [toRowJson] applies the
  /// signed-in account's IANA timezone.
  final DateTime? completedOn;

  String get isbnKey => isbnComparisonKey(isbn);

  ImportedBook copyWith({String? notes}) => ImportedBook(
    title: title,
    authors: authors,
    isbn: isbn,
    status: status,
    pageCount: pageCount,
    publisher: publisher,
    format: format,
    rating: rating,
    notes: notes ?? this.notes,
    reviewMarkdown: reviewMarkdown,
    completedOn: completedOn,
  );

  Map<String, dynamic> toRowJson({required String timezone}) => {
    'title': title,
    'authors': authors,
    'isbn': isbn,
    'status': status,
    if (pageCount != null) 'pageCount': pageCount,
    if (publisher.isNotEmpty) 'publisher': publisher,
    if (format != null) 'format': format,
    if (rating != null) 'rating': rating,
    if (notes.isNotEmpty) 'notes': notes,
    if (reviewMarkdown.isNotEmpty) 'reviewMarkdown': reviewMarkdown,
    if (completedOn != null)
      'completedAt': civilDateStartInAppTimeZone(
        completedOn!,
        timezone,
      ).toIso8601String(),
  };
}

/// Parsed books plus warnings shown before the user commits an import.
class ImportParseResult {
  const ImportParseResult({
    required this.books,
    required this.skippedNoTitle,
    required this.duplicatesDropped,
    required this.truncated,
    this.unmatchedNoteSheets = 0,
    this.skippedNoAuthor = 0,
    this.ratingsRounded = 0,
  });

  final List<ImportedBook> books;
  final int skippedNoTitle;
  final int duplicatesDropped;
  final bool truncated;
  final int unmatchedNoteSheets;
  final int skippedNoAuthor;
  final int ratingsRounded;

  int countWithStatus(String status) =>
      books.where((book) => book.status == status).length;

  int get readCount => countWithStatus(BookStatus.read);
  int get readingCount => countWithStatus(BookStatus.reading);
  int get pendingCount => countWithStatus(BookStatus.pending);
  int get wantedCount => countWithStatus(BookStatus.wanted);
  int get abandonedCount => countWithStatus(BookStatus.abandoned);
  bool get isEmpty => books.isEmpty;
}

const int maxImportBooks = 5000;
const int maxImportNotesLength = 5000;

String truncateImportNotes(String value) {
  final runes = value.trim().runes.toList(growable: false);
  if (runes.length <= maxImportNotesLength) return value.trim();
  return String.fromCharCodes(runes.take(maxImportNotesLength));
}

/// Maps a source private-notes column and a source review column onto Readendar
/// fields. A review is only kept when the row also has a rating (domain rule:
/// review requires rating). Unrated or unsafe reviews fall back to private
/// notes so the text is not dropped.
({String notes, String reviewMarkdown}) importedReviewAndNotes({
  required double? rating,
  String notes = '',
  String review = '',
}) {
  final privateNotes = truncateImportNotes(importedPlainText(notes));
  final reviewText = truncateImportNotes(importedPlainText(review));
  if (reviewText.isEmpty) {
    return (notes: privateNotes, reviewMarkdown: '');
  }
  if (rating != null && !_reviewLooksUnsafe(reviewText)) {
    return (notes: privateNotes, reviewMarkdown: reviewText);
  }
  if (privateNotes.isEmpty || privateNotes == reviewText) {
    return (notes: reviewText, reviewMarkdown: '');
  }
  return (
    notes: truncateImportNotes('$privateNotes\n\n$reviewText'),
    reviewMarkdown: '',
  );
}

/// Source exports often store HTML (`<br>`, `<i>`). Reviews must be markdown
/// without raw HTML, so tags become plain text and `<br>`/`</p>` become
/// newlines.
String importedPlainText(String raw) {
  var value = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  value = value.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n');
  value = value.replaceAll(RegExp('<[^>]*>'), '');
  const named = <String, String>{
    '&nbsp;': ' ',
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
  };
  for (final entry in named.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value.trim();
}

final _rawHtml = RegExp(r'<\s*/?\s*[a-z!]', caseSensitive: false);
final _markdownImage = RegExp(r'!\s*\[');
final _markdownLink = RegExp(r'\[[^\]]+\]\(([^)]+)\)');

bool _reviewLooksUnsafe(String value) {
  if (_rawHtml.hasMatch(value) || _markdownImage.hasMatch(value)) return true;
  for (final match in _markdownLink.allMatches(value)) {
    final target = match.group(1)!.trim().toLowerCase();
    if (!target.startsWith('https://') && !target.startsWith('http://')) {
      return true;
    }
  }
  return false;
}
