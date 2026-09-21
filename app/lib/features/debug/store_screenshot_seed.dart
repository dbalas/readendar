import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/data/local/local_store.dart';

/// Compact library for store screenshots. Not the dense debug seed.
class StoreScreenshotSeedSummary {
  const StoreScreenshotSeedSummary({
    required this.books,
    required this.events,
    required this.annotations,
  });

  final int books;
  final int events;
  final int annotations;
}

const storeScreenshotQuoteBookId = 'shot-book-cien-anos';

/// Clears [store] and writes a small local library that fits marketing shots.
Future<StoreScreenshotSeedSummary> seedStoreScreenshotLibrary(
  LocalStore store, {
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  await store.clearAll();

  final books = _books(clock);
  stampLibraryOrder(books);
  await store.replaceAll(LocalCollections.books, books, idOf: localRowId);
  await store.replaceAll(
    LocalCollections.progress,
    _progress(clock),
    idOf: (row) {
      final id = row['bookEntryId'] as String? ?? '';
      if (id.isEmpty) throw StateError('progress missing bookEntryId');
      return id;
    },
  );
  final events = _events(clock);
  await store.replaceAll(LocalCollections.events, events, idOf: localRowId);
  final annotations = _annotations(clock);
  await store.replaceAll(
    LocalCollections.annotations,
    annotations,
    idOf: localRowId,
  );

  return StoreScreenshotSeedSummary(
    books: books.length,
    events: events.length,
    annotations: annotations.length,
  );
}

String _iso(DateTime value) => value.toUtc().toIso8601String();

String _cover(String isbn) =>
    'https://covers.openlibrary.org/b/isbn/$isbn-L.jpg';

Map<String, dynamic> _book({
  required String id,
  required String title,
  required List<String> authors,
  required String status,
  required DateTime statusChangedAt,
  required int libraryOrder,
  required String isbn13,
  String format = BookFormat.physical,
  int? pageCount,
  int? chapterCount,
  double? rating,
  int annotationCount = 0,
}) => {
  'id': id,
  'ownerType': OwnerType.user,
  'ownerId': localGuestUserId,
  'title': title,
  'authors': authors,
  'status': status,
  'statusChangedAt': _iso(statusChangedAt),
  'libraryOrder': libraryOrder,
  'format': format,
  'pageCount': pageCount,
  'chapterCount': chapterCount,
  'rating': rating,
  'annotationCount': annotationCount,
  'isbn13': isbn13,
  'coverUrl': _cover(isbn13),
  'language': 'es',
  'categories': const <String>[],
  'categoryCodes': const <String>[],
};

List<Map<String, dynamic>> _books(DateTime clock) => [
  _book(
    id: storeScreenshotQuoteBookId,
    title: 'Cien años de soledad',
    authors: const ['Gabriel García Márquez'],
    status: BookStatus.reading,
    statusChangedAt: clock.subtract(const Duration(days: 18)),
    libraryOrder: 0,
    isbn13: '9788497592208',
    pageCount: 496,
    chapterCount: 20,
    rating: 4.5,
    annotationCount: 4,
  ),
  _book(
    id: 'shot-book-rayuela',
    title: 'Rayuela',
    authors: const ['Julio Cortázar'],
    status: BookStatus.reading,
    statusChangedAt: clock.subtract(const Duration(days: 9)),
    libraryOrder: 1,
    isbn13: '9788437604572',
    format: BookFormat.ebook,
    pageCount: 736,
    chapterCount: 155,
    rating: 4,
  ),
  _book(
    id: 'shot-book-aleph',
    title: 'El Aleph',
    authors: const ['Jorge Luis Borges'],
    status: BookStatus.reading,
    statusChangedAt: clock.subtract(const Duration(days: 4)),
    libraryOrder: 2,
    isbn13: '9788466331913',
    pageCount: 224,
    rating: 5,
  ),
  _book(
    id: 'shot-book-paramo',
    title: 'Pedro Páramo',
    authors: const ['Juan Rulfo'],
    status: BookStatus.pending,
    statusChangedAt: clock.subtract(const Duration(days: 2)),
    libraryOrder: 3,
    isbn13: '9788437604145',
    pageCount: 144,
  ),
  _book(
    id: 'shot-book-ficciones',
    title: 'Ficciones',
    authors: const ['Jorge Luis Borges'],
    status: BookStatus.wanted,
    statusChangedAt: clock.subtract(const Duration(days: 1)),
    libraryOrder: 4,
    isbn13: '9788499089515',
    format: BookFormat.ebook,
    pageCount: 224,
    rating: 5,
  ),
  _book(
    id: 'shot-book-quijote',
    title: 'Don Quijote de la Mancha',
    authors: const ['Miguel de Cervantes'],
    status: BookStatus.read,
    statusChangedAt: clock.subtract(const Duration(days: 60)),
    libraryOrder: 5,
    isbn13: '9788467034103',
    pageCount: 1056,
    chapterCount: 126,
    rating: 4,
  ),
];

List<Map<String, dynamic>> _progress(DateTime clock) => [
  {
    'bookEntryId': storeScreenshotQuoteBookId,
    'currentPage': 210,
    'updatedAt': _iso(clock.subtract(const Duration(hours: 6))),
  },
  {
    'bookEntryId': 'shot-book-rayuela',
    'currentChapter': 34,
    'updatedAt': _iso(clock.subtract(const Duration(days: 1))),
  },
  {
    'bookEntryId': 'shot-book-aleph',
    'currentPercentage': 42,
    'updatedAt': _iso(clock.subtract(const Duration(hours: 2))),
  },
  {
    'bookEntryId': 'shot-book-quijote',
    'currentPage': 1056,
    'currentChapter': 126,
    'currentPercentage': 100,
    'updatedAt': _iso(clock.subtract(const Duration(days: 60))),
  },
];

Map<String, dynamic> _event({
  required String id,
  required EventType type,
  required String title,
  required DateTime clock,
  int dayOffset = 0,
  String? bookId,
  String status = EventStatus.active,
  String? timeLocal,
  int? targetChapter,
  int? targetPage,
}) {
  final date = DateTime(
    clock.year,
    clock.month,
    clock.day,
  ).add(Duration(days: dayOffset));
  return {
    'id': id,
    'ownerType': OwnerType.user,
    'ownerId': localGuestUserId,
    'bookId': bookId,
    'type': type.backendValue,
    'title': title,
    'description': '',
    'dateLocal': localYmd(date),
    'timeLocal': timeLocal,
    'tz': timeLocal == null ? null : 'Europe/Madrid',
    'targetChapter': targetChapter,
    'targetPage': targetPage,
    'status': status,
    'reminderEnabled': true,
    'reminderMinutesBefore': timeLocal == null ? 1440 : 60,
    'muted': false,
    'createdAt': _iso(clock),
    'updatedAt': _iso(clock),
  };
}

List<Map<String, dynamic>> _events(DateTime clock) => [
  _event(
    id: 'shot-ev-page',
    type: EventType.pageMilestone,
    title: 'Página 300 de Cien años',
    clock: clock,
    bookId: storeScreenshotQuoteBookId,
    timeLocal: '08:30',
    targetPage: 300,
  ),
  _event(
    id: 'shot-ev-chapter',
    type: EventType.chapterMilestone,
    title: 'Capítulo 40 de Rayuela',
    clock: clock,
    dayOffset: 2,
    bookId: 'shot-book-rayuela',
    timeLocal: '21:00',
    targetChapter: 40,
  ),
  _event(
    id: 'shot-ev-return',
    type: EventType.bookReturn,
    title: 'Devolver Pedro Páramo',
    clock: clock,
    dayOffset: 5,
    bookId: 'shot-book-paramo',
    timeLocal: '18:00',
  ),
  _event(
    id: 'shot-ev-finish',
    type: EventType.finish,
    title: 'Terminé el Quijote',
    clock: clock,
    dayOffset: -4,
    bookId: 'shot-book-quijote',
    status: EventStatus.completed,
  ),
];

List<Map<String, dynamic>> _annotations(DateTime clock) {
  Map<String, dynamic> item({
    required String id,
    required AnnotationCategory category,
    required String body,
    String commentary = '',
    int? page,
    bool pinned = false,
    bool favorite = false,
  }) => {
    'id': id,
    'bookId': storeScreenshotQuoteBookId,
    'category': category.wire,
    'body': body,
    'commentary': commentary,
    'page': page,
    'spoiler': false,
    'pinned': pinned,
    'favorite': favorite,
    'createdAt': _iso(clock.subtract(const Duration(days: 5))),
    'updatedAt': _iso(clock),
    'bookTitle': '',
    'bookAuthors': const <String>[],
    'bookCoverUrl': '',
    'isbn13': '9788497592208',
  };

  return [
    item(
      id: 'shot-ann-quote',
      category: AnnotationCategory.quote,
      body: 'El mundo era tan reciente que muchas cosas carecían de nombre.',
      commentary: 'Arranque que siempre relee.',
      page: 9,
      favorite: true,
      pinned: true,
    ),
    item(
      id: 'shot-ann-note',
      category: AnnotationCategory.note,
      body: 'Anotar el árbol genealógico en la guarda.',
      page: 40,
    ),
    item(
      id: 'shot-ann-theory',
      category: AnnotationCategory.theory,
      body: 'El hielo es el primer contacto con lo imposible.',
      page: 12,
    ),
    item(
      id: 'shot-ann-question',
      category: AnnotationCategory.question,
      body: '¿Cuánto de Macondo es Aracataca y cuánto invención?',
    ),
  ];
}
