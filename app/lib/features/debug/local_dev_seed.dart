import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/data/local/local_store.dart';

/// Counts written by [seedLocalDevLibrary] after wiping the local store.
class LocalDevSeedSummary {
  const LocalDevSeedSummary({
    required this.books,
    required this.events,
    required this.annotations,
    required this.progress,
  });

  final int books;
  final int events;
  final int annotations;
  final int progress;
}

/// Clears [store] and writes a dense local library for debug exploration.
Future<LocalDevSeedSummary> seedLocalDevLibrary(
  LocalStore store, {
  DateTime? now,
}) async {
  final clock = now ?? DateTime.now();
  await store.clearAll();

  final books = _books(clock);
  stampLibraryOrder(books);
  await store.replaceAll(LocalCollections.books, books, idOf: localRowId);

  final progress = _progress(clock);
  await store.replaceAll(
    LocalCollections.progress,
    progress,
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

  await store.replaceAll(
    LocalCollections.pageActivity,
    _pageActivity(clock),
    idOf: localRowId,
  );
  await store.replaceAll(
    LocalCollections.bookStatusHistory,
    _statusHistory(clock),
    idOf: localRowId,
  );
  await store.replaceAll(
    LocalCollections.planRuns,
    _planRuns(clock),
    idOf: localRowId,
  );
  await store.replaceAll(
    LocalCollections.customFieldDefinitions,
    _customFieldDefinitions(),
    idOf: localRowId,
  );
  await store.replaceAll(
    LocalCollections.customFieldValues,
    _customFieldValues(),
    idOf: localRowId,
  );

  return LocalDevSeedSummary(
    books: books.length,
    events: events.length,
    annotations: annotations.length,
    progress: progress.length,
  );
}

const _minDevSeedBooks = 200;
const _minDevSeedEvents = 1000;

const _readingPages = 'seed-book-reading-pages';
const _readingChapters = 'seed-book-reading-chapters';
const _readingPercent = 'seed-book-reading-percent';
const _readingMixed = 'seed-book-reading-mixed';
const _pending = 'seed-book-pending';
const _wanted = 'seed-book-wanted';
const _read = 'seed-book-read';
const _abandoned = 'seed-book-abandoned';

const _anchorBookIds = [
  _readingPages,
  _readingChapters,
  _readingPercent,
  _readingMixed,
  _pending,
  _wanted,
  _read,
  _abandoned,
];

const _bulkAuthorPool = <List<String>>[
  ['Gabriel García Márquez'],
  ['Julio Cortázar'],
  ['Jorge Luis Borges'],
  ['Roberto Bolaño'],
  ['Miguel de Cervantes'],
  ['Isabel Allende'],
  ['Juan Rulfo'],
  ['Elena Poniatowska'],
  ['Carlos Fuentes'],
  ['Rosario Castellanos'],
];

const _bulkCategoryPool = [
  'Ficción',
  'Ensayo',
  'Poesía',
  'Historia',
  'Ciencia ficción',
];

String _bulkBookId(int index) => 'seed-book-bulk-${index.toString().padLeft(3, '0')}';

String _devBookId(int slot) => slot < _anchorBookIds.length
    ? _anchorBookIds[slot]
    : _bulkBookId(slot - _anchorBookIds.length);

String _iso(DateTime value) => value.toUtc().toIso8601String();

String _ymdOffset(DateTime clock, int days) {
  final d = DateTime(
    clock.year,
    clock.month,
    clock.day,
  ).add(Duration(days: days));
  return localYmd(d);
}

Map<String, dynamic> _book({
  required String id,
  required String title,
  required List<String> authors,
  required String status,
  required DateTime statusChangedAt,
  required int libraryOrder,
  String format = BookFormat.physical,
  int? pageCount,
  int? chapterCount,
  double? rating,
  String notes = '',
  String reviewMarkdown = '',
  int annotationCount = 0,
  String description = '',
  List<String> categories = const [],
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
  'notes': notes,
  'reviewMarkdown': reviewMarkdown,
  'annotationCount': annotationCount,
  'description': description,
  'categories': categories,
  'categoryCodes': const <String>[],
  'coverUrl': '',
  'language': 'es',
};

List<Map<String, dynamic>> _anchorBooks(DateTime clock) => [
  _book(
    id: _readingPages,
    title: 'Cien años de soledad',
    authors: const ['Gabriel García Márquez'],
    status: BookStatus.reading,
    statusChangedAt: clock.subtract(const Duration(days: 18)),
    libraryOrder: 0,
    pageCount: 496,
    chapterCount: 20,
    rating: 4.5,
    notes: 'Macondo se expande más de lo que recordaba.',
    reviewMarkdown: 'Una relectura a fuego lento.',
    annotationCount: 4,
    description: 'La saga de los Buendía en Macondo.',
    categories: const ['Ficción'],
  ),
  _book(
    id: _readingChapters,
    title: 'Rayuela',
    authors: const ['Julio Cortázar'],
    status: BookStatus.reading,
    statusChangedAt: clock.subtract(const Duration(days: 9)),
    libraryOrder: 1,
    format: BookFormat.ebook,
    pageCount: 736,
    chapterCount: 155,
    rating: 3,
    notes: 'Tablero de dirección a mano.',
    annotationCount: 1,
  ),
  _book(
    id: _readingPercent,
    title: 'El Aleph',
    authors: const ['Jorge Luis Borges'],
    status: BookStatus.reading,
    statusChangedAt: clock.subtract(const Duration(days: 4)),
    libraryOrder: 2,
    format: BookFormat.audiobook,
    pageCount: 224,
    rating: 5,
  ),
  _book(
    id: _readingMixed,
    title: '2666',
    authors: const ['Roberto Bolaño'],
    status: BookStatus.reading,
    statusChangedAt: clock.subtract(const Duration(days: 40)),
    libraryOrder: 3,
    format: BookFormat.ebook,
    pageCount: 1120,
    chapterCount: 5,
    rating: 0.5,
    notes: 'Empiezo otra vez la parte de los críticos.',
  ),
  _book(
    id: _pending,
    title: 'Pedro Páramo',
    authors: const ['Juan Rulfo'],
    status: BookStatus.pending,
    statusChangedAt: clock.subtract(const Duration(days: 2)),
    libraryOrder: 4,
    pageCount: 144,
    chapterCount: 1,
  ),
  _book(
    id: _wanted,
    title: 'Ficciones',
    authors: const ['Jorge Luis Borges'],
    status: BookStatus.wanted,
    statusChangedAt: clock.subtract(const Duration(days: 1)),
    libraryOrder: 5,
    format: BookFormat.ebook,
    pageCount: 224,
    rating: 5,
  ),
  _book(
    id: _read,
    title: 'Don Quijote de la Mancha',
    authors: const ['Miguel de Cervantes'],
    status: BookStatus.read,
    statusChangedAt: clock.subtract(const Duration(days: 60)),
    libraryOrder: 6,
    pageCount: 1056,
    chapterCount: 126,
    rating: 4,
    reviewMarkdown: 'Más cómico y más triste de lo que prometen los resúmenes.',
  ),
  _book(
    id: _abandoned,
    title: 'La casa de los espíritus',
    authors: const ['Isabel Allende'],
    status: BookStatus.abandoned,
    statusChangedAt: clock.subtract(const Duration(days: 12)),
    libraryOrder: 7,
    format: BookFormat.other,
    pageCount: 512,
    chapterCount: 14,
    rating: 2,
    notes: 'Lo dejo para más adelante.',
  ),
];

List<Map<String, dynamic>> _books(DateTime clock) {
  final anchors = _anchorBooks(clock);
  final bulk = <Map<String, dynamic>>[];
  const formats = [
    BookFormat.physical,
    BookFormat.ebook,
    BookFormat.audiobook,
    BookFormat.other,
  ];
  const ratings = <double?>[null, 0.5, 1, 2.5, 3, 4, 4.5, 5];

  for (var i = 0; i < _minDevSeedBooks - anchors.length; i++) {
    final status = BookStatus.all[i % BookStatus.all.length];
    final pages = 120 + (i * 17) % 900;
    bulk.add(
      _book(
        id: _bulkBookId(i),
        title: 'Volumen de prueba ${i + 1}',
        authors: _bulkAuthorPool[i % _bulkAuthorPool.length],
        status: status,
        statusChangedAt: clock.subtract(Duration(days: 1 + (i % 400))),
        libraryOrder: anchors.length + i,
        format: formats[i % formats.length],
        pageCount: pages,
        chapterCount: (pages / 25).ceil(),
        rating: ratings[i % ratings.length],
        categories: [_bulkCategoryPool[i % _bulkCategoryPool.length]],
        description: 'Datos generados para pruebas locales.',
      ),
    );
  }
  return [...anchors, ...bulk];
}

List<Map<String, dynamic>> _progress(DateTime clock) => [
  {
    'bookEntryId': _readingPages,
    'currentPage': 210,
    'updatedAt': _iso(clock.subtract(const Duration(hours: 6))),
  },
  {
    'bookEntryId': _readingChapters,
    'currentChapter': 34,
    'updatedAt': _iso(clock.subtract(const Duration(days: 1))),
  },
  {
    'bookEntryId': _readingPercent,
    'currentPercentage': 42,
    'updatedAt': _iso(clock.subtract(const Duration(hours: 2))),
  },
  {
    'bookEntryId': _readingMixed,
    'currentPage': 480,
    'currentChapter': 3,
    'currentPercentage': 43,
    'updatedAt': _iso(clock.subtract(const Duration(days: 3))),
  },
  {
    'bookEntryId': _read,
    'currentPage': 1056,
    'currentChapter': 126,
    'currentPercentage': 100,
    'updatedAt': _iso(clock.subtract(const Duration(days: 60))),
  },
  {
    'bookEntryId': _abandoned,
    'currentPage': 90,
    'currentPercentage': 18,
    'updatedAt': _iso(clock.subtract(const Duration(days: 12))),
  },
  for (var i = 0; i < _minDevSeedBooks - _anchorBookIds.length; i++)
    if ({
          BookStatus.reading,
          BookStatus.read,
        }.contains(BookStatus.all[i % BookStatus.all.length]))
      {
        'bookEntryId': _bulkBookId(i),
        if (i.isEven)
          'currentPage': ((120 + (i * 17) % 900) * ((i % 9) + 1) / 10).round(),
        if (i.isOdd) 'currentPercentage': (i * 7) % 100,
        'updatedAt': _iso(clock.subtract(Duration(days: i % 30))),
      },
];

Map<String, dynamic> _event({
  required String id,
  required EventType type,
  required String title,
  required DateTime clock,
  int dayOffset = 0,
  DateTime? onCalendarDate,
  String? bookId,
  String status = EventStatus.active,
  String? timeLocal,
  String? tz,
  int? targetChapter,
  int? targetPage,
  String description = '',
  String? planId,
}) {
  final date = onCalendarDate != null
      ? DateTime(
          onCalendarDate.year,
          onCalendarDate.month,
          onCalendarDate.day,
        )
      : DateTime(
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
    'description': description,
    'dateLocal': localYmd(date),
    'timeLocal': timeLocal,
    'tz': tz,
    'targetChapter': targetChapter,
    'targetPage': targetPage,
    'status': status,
    'reminderEnabled': true,
    'reminderMinutesBefore': timeLocal == null ? 1440 : 60,
    'muted': false,
    'createdAt': _iso(clock),
    'updatedAt': _iso(clock),
    'planId': planId,
  };
}

String _bulkEventTitle(EventType type, int index) => switch (type) {
  EventType.start => 'Inicio volumen $index',
  EventType.finish => 'Fin volumen $index',
  EventType.abandoned => 'Abandono volumen $index',
  EventType.chapterMilestone => 'Hito capítulo $index',
  EventType.pageMilestone => 'Hito página $index',
  EventType.deadline => 'Fecha límite $index',
  EventType.bookReturn => 'Devolución $index',
  EventType.release => 'Lanzamiento $index',
};

List<Map<String, dynamic>> _anchorEvents(DateTime clock) {
  const planId = 'seed-plan-rayuela';
  return [
    _event(
      id: 'seed-ev-start',
      type: EventType.start,
      title: 'Empiezo Cien años de soledad',
      clock: clock,
      dayOffset: -18,
      bookId: _readingPages,
      status: EventStatus.completed,
    ),
    _event(
      id: 'seed-ev-finish',
      type: EventType.finish,
      title: 'Terminé el Quijote',
      clock: clock,
      dayOffset: -60,
      bookId: _read,
      status: EventStatus.completed,
    ),
    _event(
      id: 'seed-ev-abandoned',
      type: EventType.abandoned,
      title: 'Dejo La casa de los espíritus',
      clock: clock,
      dayOffset: -12,
      bookId: _abandoned,
      status: EventStatus.completed,
    ),
    _event(
      id: 'seed-ev-chapter',
      type: EventType.chapterMilestone,
      title: 'Capítulo 40 de Rayuela',
      clock: clock,
      dayOffset: 2,
      bookId: _readingChapters,
      timeLocal: '21:00',
      tz: 'Europe/Madrid',
      targetChapter: 40,
      planId: planId,
    ),
    _event(
      id: 'seed-ev-page',
      type: EventType.pageMilestone,
      title: 'Página 300 de Cien años',
      clock: clock,
      dayOffset: 1,
      bookId: _readingPages,
      timeLocal: '08:30',
      tz: 'Europe/Madrid',
      targetPage: 300,
    ),
    _event(
      id: 'seed-ev-deadline',
      type: EventType.deadline,
      title: 'Fecha límite 2666',
      clock: clock,
      dayOffset: 21,
      bookId: _readingMixed,
      description: 'Antes del viaje.',
    ),
    _event(
      id: 'seed-ev-cancelled',
      type: EventType.pageMilestone,
      title: 'Página 50 descartada',
      clock: clock,
      dayOffset: 5,
      bookId: _readingPages,
      targetPage: 50,
      status: EventStatus.cancelled,
    ),
    _event(
      id: 'seed-ev-return',
      type: EventType.bookReturn,
      title: 'Devolver Pedro Páramo',
      clock: clock,
      dayOffset: 7,
      bookId: _pending,
      timeLocal: '18:00',
      tz: 'Europe/Madrid',
    ),
    _event(
      id: 'seed-ev-release',
      type: EventType.release,
      title: 'Nueva edición de Ficciones',
      clock: clock,
      dayOffset: 14,
      bookId: _wanted,
    ),
    _event(
      id: 'seed-ev-chapter-done',
      type: EventType.chapterMilestone,
      title: 'Capítulo 20 de Rayuela',
      clock: clock,
      dayOffset: -3,
      bookId: _readingChapters,
      targetChapter: 20,
      status: EventStatus.completed,
      planId: planId,
    ),
  ];
}

List<Map<String, dynamic>> _events(DateTime clock) {
  final anchors = _anchorEvents(clock);
  final bulk = <Map<String, dynamic>>[];
  final bulkTarget = _minDevSeedEvents - anchors.length;
  final year = clock.year;
  final jan1 = DateTime(year, 1, 1);
  final daysInYear = DateTime(year, 12, 31).difference(jan1).inDays + 1;
  const types = EventType.values;
  const statusCycle = [
    EventStatus.active,
    EventStatus.completed,
    EventStatus.cancelled,
  ];

  for (var i = 0; i < bulkTarget; i++) {
    final dayIndex = (i * daysInYear) ~/ bulkTarget;
    final date = jan1.add(Duration(days: dayIndex));
    final type = types[i % types.length];
    final withTime = i % 3 == 0;
    bulk.add(
      _event(
        id: 'seed-ev-bulk-${i.toString().padLeft(4, '0')}',
        type: type,
        title: _bulkEventTitle(type, i + 1),
        clock: clock,
        onCalendarDate: date,
        bookId: _devBookId(i % _minDevSeedBooks),
        status: statusCycle[i % statusCycle.length],
        timeLocal: withTime
            ? '${(8 + i % 12).toString().padLeft(2, '0')}:00'
            : null,
        tz: withTime ? 'Europe/Madrid' : null,
        targetChapter: type == EventType.chapterMilestone ? 1 + (i % 40) : null,
        targetPage: type == EventType.pageMilestone ? 1 + (i % 200) : null,
        description: i % 5 == 0 ? 'Evento de prueba generado.' : '',
      ),
    );
  }
  return [...anchors, ...bulk];
}

List<Map<String, dynamic>> _annotations(DateTime clock) {
  Map<String, dynamic> item({
    required String id,
    required String bookId,
    required AnnotationCategory category,
    required String body,
    String commentary = '',
    int? page,
    int? chapter,
    bool pinned = false,
    bool favorite = false,
    bool spoiler = false,
  }) => {
    'id': id,
    'bookId': bookId,
    'category': category.wire,
    'body': body,
    'commentary': commentary,
    'page': page,
    'chapter': chapter,
    'spoiler': spoiler,
    'pinned': pinned,
    'favorite': favorite,
    'createdAt': _iso(clock.subtract(const Duration(days: 5))),
    'updatedAt': _iso(clock),
    'bookTitle': '',
    'bookAuthors': const <String>[],
    'bookCoverUrl': '',
    'isbn13': '',
  };

  return [
    item(
      id: 'seed-ann-quote',
      bookId: _readingPages,
      category: AnnotationCategory.quote,
      body: 'El mundo era tan reciente que muchas cosas carecían de nombre.',
      commentary: 'Arranque que siempre relée.',
      page: 9,
      favorite: true,
      pinned: true,
    ),
    item(
      id: 'seed-ann-note',
      bookId: _readingPages,
      category: AnnotationCategory.note,
      body: 'Anotar el árbol genealógico en la guarda.',
      page: 40,
    ),
    item(
      id: 'seed-ann-theory',
      bookId: _readingPages,
      category: AnnotationCategory.theory,
      body: 'El hielo es el primer contacto con lo imposible.',
      page: 12,
    ),
    item(
      id: 'seed-ann-question',
      bookId: _readingPages,
      category: AnnotationCategory.question,
      body: '¿Cuánto de Macondo es Aracataca y cuánto invención?',
      spoiler: true,
    ),
    item(
      id: 'seed-ann-rayuela',
      bookId: _readingChapters,
      category: AnnotationCategory.quote,
      body:
          'Andábamos sin buscarnos pero sabiendo que andábamos para encontrarnos.',
      chapter: 1,
    ),
  ];
}

List<Map<String, dynamic>> _pageActivity(DateTime clock) => [
  for (final offset in const [40, 18, 10, 6, 3, 1, 0])
    {
      'id': 'seed-act-$offset',
      'bookEntryId': offset >= 30 ? _read : _readingPages,
      'pages': offset >= 30 ? 40 : 12 + offset,
      'occurredAt': _iso(clock.subtract(Duration(days: offset))),
    },
];

List<Map<String, dynamic>> _statusHistory(DateTime clock) => [
  {
    'id': 'seed-hist-quijote-wanted',
    'bookId': _read,
    'bookEntryId': _read,
    'status': BookStatus.wanted,
    'changedAt': _iso(clock.subtract(const Duration(days: 200))),
    'origin': 'baseline',
    'dateConfirmed': true,
  },
  {
    'id': 'seed-hist-quijote-reading',
    'bookId': _read,
    'bookEntryId': _read,
    'status': BookStatus.reading,
    'changedAt': _iso(clock.subtract(const Duration(days: 120))),
    'origin': 'transition',
    'dateConfirmed': true,
  },
  {
    'id': 'seed-hist-quijote-read',
    'bookId': _read,
    'bookEntryId': _read,
    'status': BookStatus.read,
    'changedAt': _iso(clock.subtract(const Duration(days: 60))),
    'origin': 'transition',
    'dateConfirmed': true,
  },
  {
    'id': 'seed-hist-cien-reading',
    'bookId': _readingPages,
    'bookEntryId': _readingPages,
    'status': BookStatus.reading,
    'changedAt': _iso(clock.subtract(const Duration(days: 18))),
    'origin': 'transition',
    'dateConfirmed': true,
  },
];

List<Map<String, dynamic>> _planRuns(DateTime clock) => [
  {
    'id': 'seed-plan-rayuela',
    'bookId': _readingChapters,
    'eventCount': 2,
    'mode': 'pace',
    'unit': 'chapters',
    'perDay': 2,
    'startDate': _ymdOffset(clock, -10),
    'total': 155,
    'startUnit': 20,
    'remindersOn': true,
    'includeStart': false,
    'includeFinish': true,
    'createdAt': _iso(clock.subtract(const Duration(days: 10))),
  },
];

List<Map<String, dynamic>> _customFieldDefinitions() => [
  {
    'id': 'seed-field-translator',
    'name': 'Traductor',
    'iconKey': 'tag',
    'type': 'text',
    'textMode': '',
    'position': 0,
    'usageCount': 1,
    'options': const <Map<String, dynamic>>[],
  },
];

List<Map<String, dynamic>> _customFieldValues() => [
  {
    'id': _readingPages,
    'items': [
      {
        'fieldId': 'seed-field-translator',
        'name': 'Traductor',
        'iconKey': 'tag',
        'textMode': '',
        'position': 0,
        'source': 'personal',
        'readOnly': false,
        'historical': false,
        'value': {'kind': 'text', 'text': 'Gregorio y Barbara Rabassa'},
      },
    ],
  },
];
