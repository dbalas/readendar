import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/import/catalog_import.dart';
import 'package:readendar/features/import/import_models.dart';

import 'catalog_import_fakes.dart';

ImportedBook _row({
  required String title,
  String isbn = '',
  String status = BookStatus.pending,
  List<String> authors = const ['Autor'],
  double? rating,
  String notes = '',
  String review = '',
  String publisher = '',
  int? pageCount,
}) => ImportedBook(
  title: title,
  authors: authors,
  isbn: isbn,
  status: status,
  publisher: publisher,
  pageCount: pageCount,
  rating: rating,
  notes: notes,
  reviewMarkdown: review,
);

void main() {
  test(
    'enrich hit wins cover, categories, description, and identity',
    () async {
      final search = FakeCatalogSearch(
        hits: {
          '9780439023481': SearchHit(
            title: 'Dune',
            authors: const ['Frank Herbert'],
            isbn: '9780441172719',
            coverUrl: 'https://covers.example/dune.jpg',
            description: 'Arena.',
            publisher: 'Chilton',
            language: 'en',
            categoryCodes: const ['science_fiction'],
            pageCount: 412,
            binding: 'Paperback',
            edition: '40th',
            publicationDate: DateTime.utc(1965, 8, 1),
            publicationDatePrecision: 'day',
          ),
        },
      );
      final books = FakeCatalogBooks();
      final importer = CatalogImport(search: search, books: books);

      final row = await importer.importOne(
        _row(
          title: 'Dune CSV',
          isbn: '9780439023481',
          publisher: 'CSV Pub',
          pageCount: 10,
        ),
      );

      expect(row.outcome, ImportOutcome.created);
      expect(row.hadCover, isTrue);
      expect(search.enrichCalls, 1);
      expect(books.creates, hasLength(1));
      final created = books.creates.single;
      expect(created['title'], 'Dune');
      expect(created['authors'], ['Frank Herbert']);
      expect(created['isbn'], '9780441172719');
      expect(created['coverUrl'], 'https://covers.example/dune.jpg');
      expect(created['description'], 'Arena.');
      expect(created['publisher'], 'Chilton');
      expect(created['language'], 'en');
      expect(created['categories'], ['science_fiction']);
      expect(created['pageCount'], 412);
      expect(created['binding'], 'Paperback');
      expect(created['edition'], '40th');
      expect(created['publicationDate'], DateTime.utc(1965, 8, 1));
      expect(created['publicationDatePrecision'], 'day');
    },
  );

  test('enrich miss still creates from the CSV row', () async {
    final search = FakeCatalogSearch();
    final books = FakeCatalogBooks();
    final importer = CatalogImport(search: search, books: books);

    final row = await importer.importOne(
      _row(title: 'Only CSV', isbn: '9780000000000', publisher: 'House'),
    );

    expect(row.outcome, ImportOutcome.created);
    expect(row.hadCover, isFalse);
    expect(books.creates.single['title'], 'Only CSV');
    expect(books.creates.single['isbn'], '9780000000000');
    expect(books.creates.single['publisher'], 'House');
    expect(books.creates.single['coverUrl'], '');
  });

  test('enrich transport failure fails the row', () async {
    final search = FakeCatalogSearch(fail: true);
    final books = FakeCatalogBooks();
    final importer = CatalogImport(search: search, books: books);

    final row = await importer.importOne(_row(title: 'Nope'));

    expect(row.outcome, ImportOutcome.failed);
    expect(row.error, 'network');
    expect(books.creates, isEmpty);
  });

  test('create transport failure fails the row', () async {
    final search = FakeCatalogSearch();
    final books = FakeCatalogBooks(failCreates: true);
    final importer = CatalogImport(search: search, books: books);

    final row = await importer.importOne(_row(title: 'Nope'));

    expect(row.outcome, ImportOutcome.failed);
    expect(row.error, 'network');
  });

  test('retry recovers after transient enrich failures', () async {
    final search = FakeCatalogSearch(
      failTimes: 2,
      hits: {
        '9780441013593': SearchHit(
          title: 'Neuromancer',
          authors: const ['Gibson'],
          isbn: '9780441013593',
          coverUrl: 'https://covers.example/n.jpg',
        ),
      },
    );
    final books = FakeCatalogBooks();
    final importer = CatalogImport(search: search, books: books);

    final row = await importer.importOneWithRetry(
      _row(title: 'Neuromancer', isbn: '9780441013593'),
      backoff: Duration.zero,
    );

    expect(row.outcome, ImportOutcome.created);
    expect(search.enrichCalls, 3);
    expect(books.creates, hasLength(1));
  });

  test('retry exhaustion leaves the row failed', () async {
    final search = FakeCatalogSearch(fail: true);
    final books = FakeCatalogBooks();
    final importer = CatalogImport(search: search, books: books);

    final row = await importer.importOneWithRetry(
      _row(title: 'Gone'),
      backoff: Duration.zero,
    );

    expect(row.outcome, ImportOutcome.failed);
    expect(search.enrichCalls, 1 + importRowRetries);
    expect(books.creates, isEmpty);
  });

  test('rating, review, and notes persist after create', () async {
    final search = FakeCatalogSearch();
    final books = FakeCatalogBooks();
    final notes = FakeCatalogNotes();
    final importer = CatalogImport(
      search: search,
      books: books,
      annotations: notes,
    );

    final row = await importer.importOne(
      _row(
        title: 'Rated',
        rating: 4.5,
        review: 'Brutal.',
        notes: 'Keep private',
      ),
    );

    expect(row.outcome, ImportOutcome.created);
    expect(books.ratings[row.bookId]?.rating, 4.5);
    expect(books.ratings[row.bookId]?.review, 'Brutal.');
    expect(notes.notes.single.body, 'Keep private');
    expect(notes.notes.single.bookId, row.bookId);
  });
}
