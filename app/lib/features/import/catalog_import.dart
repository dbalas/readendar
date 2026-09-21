import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/features/import/import_models.dart';

/// How many rows enrich+create at once. Empathy, Open Library, and BNE are
/// public sources with tight rate limits; 3 hides per-row latency without a stampede.
const int importMaxInFlight = 3;

/// Transport retries after the first attempt. Per-row validation (empty title)
/// is not retried; the parser already dropped those rows.
const int importRowRetries = 2;

/// Base backoff between row retries; multiplied by the attempt number.
const Duration importRetryBackoff = Duration(milliseconds: 400);

class CatalogImportRow {
  const CatalogImportRow({
    required this.index,
    required this.outcome,
    this.bookId = '',
    this.hadCover = false,
    this.error = '',
  });

  final int index;
  final String outcome;
  final String bookId;
  final bool hadCover;
  final String error;
}

/// Catalog enrich, then persist through the active book store.
class CatalogImport {
  CatalogImport({
    required this.search,
    required this.books,
    this.annotations,
  });

  final SearchRepository search;
  final BookRepository books;
  final AnnotationRepository? annotations;

  Future<CatalogImportRow> importOne(
    ImportedBook book, {
    int index = 0,
  }) async {
    final enriched = await search.enrich(
      isbn: book.isbn,
      title: book.title,
      authors: book.authors,
    );
    if (enriched.isErr) {
      return CatalogImportRow(
        index: index,
        outcome: ImportOutcome.failed,
        error: enriched.failure?.code ?? 'network',
      );
    }
    final hit = enriched.value;
    final created = await books.create(
      title: _prefer(hit?.title, book.title),
      authors: (hit != null && hit.authors.isNotEmpty)
          ? hit.authors
          : book.authors,
      coverUrl: hit?.coverUrl ?? '',
      isbn: _prefer(hit?.isbn, book.isbn),
      pageCount: hit?.pageCount ?? book.pageCount,
      publisher: _nullablePrefer(hit?.publisher, book.publisher),
      language: _emptyToNull(hit?.language),
      categories: _categories(hit),
      format: book.format ?? hit?.format,
      description: _emptyToNull(hit?.description),
      edition: _emptyToNull(hit?.edition),
      binding: _emptyToNull(hit?.binding),
      publicationDate: hit?.publicationDate,
      publicationDatePrecision: _emptyToNull(hit?.publicationDatePrecision),
      initialStatus: book.status,
    );
    if (created.isErr) {
      return CatalogImportRow(
        index: index,
        outcome: ImportOutcome.failed,
        error: created.failure?.code ?? 'unknown',
      );
    }
    final entry = created.value!;
    if (book.rating != null || book.reviewMarkdown.isNotEmpty) {
      await books.updateRatingReview(
        entry.id,
        rating: book.rating,
        reviewMarkdown: book.reviewMarkdown,
      );
    }
    if (book.notes.isNotEmpty) {
      await annotations?.create(
        bookId: entry.id,
        body: book.notes,
        category: AnnotationCategory.note,
      );
    }
    return CatalogImportRow(
      index: index,
      outcome: ImportOutcome.created,
      bookId: entry.id,
      hadCover: entry.coverUrl.trim().isNotEmpty,
    );
  }

  Future<CatalogImportRow> importOneWithRetry(
    ImportedBook book, {
    int index = 0,
    int retries = importRowRetries,
    Duration backoff = importRetryBackoff,
  }) async {
    var result = await importOne(book, index: index);
    var attempt = 0;
    while (result.outcome != ImportOutcome.created && attempt < retries) {
      attempt++;
      await Future<void>.delayed(backoff * attempt);
      result = await importOne(book, index: index);
    }
    return result;
  }
}

String _prefer(String? catalog, String fallback) {
  final value = catalog?.trim() ?? '';
  return value.isNotEmpty ? value : fallback.trim();
}

String? _nullablePrefer(String? catalog, String fallback) {
  final value = _prefer(catalog, fallback);
  return value.isEmpty ? null : value;
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

List<String>? _categories(SearchHit? hit) {
  if (hit == null) return null;
  if (hit.categoryCodes.isNotEmpty) return hit.categoryCodes;
  if (hit.categories.isNotEmpty) return hit.categories;
  return null;
}
