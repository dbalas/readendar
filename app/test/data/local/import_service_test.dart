import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/data/local/legacy_server_export.dart';
import 'package:readendar/data/local/import_service.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory temp;
  late LocalStore store;
  late PrefsStorage prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = PrefsStorage(await SharedPreferences.getInstance());
    temp = await Directory.systemTemp.createTemp('rd-import');
    store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
  });

  tearDown(() async {
    if (temp.existsSync()) await temp.delete(recursive: true);
  });

  Map<String, dynamic> bookJson({
    String id = 'book-1',
    String ownerType = 'user',
    String? coverUrl = 'https://covers.example/a.jpg',
    String? legacyLinkedOwnerId,
  }) => {
    'id': id,
    'ownerType': ownerType,
    'ownerId': ownerType == OwnerType.user ? 'user-1' : 'legacy-1',
    'title': 'Rayuela',
    'authors': ['Cortazar'],
    'status': BookStatus.reading,
    'coverUrl': coverUrl,
    if (legacyLinkedOwnerId != null)
      LegacyServerExport.linkedOwnerIdKey: legacyLinkedOwnerId,
  };

  test(
    'success persists rows, downloads covers, then flips the plane',
    () async {
      var exportCalls = 0;
      final service = ImportService(
        store: store,
        prefs: prefs,
        fetchExport: () async {
          exportCalls++;
          return {
            'books': [
              bookJson(),
              bookJson(
                id: 'legacy-book',
                ownerType: LegacyServerExport.ownerTypeShared,
                coverUrl: '',
                legacyLinkedOwnerId: 'legacy-1',
              ),
            ],
            'events': [
              {
                'id': 'ev-1',
                'ownerType': LegacyServerExport.ownerTypeShared,
                'ownerId': 'legacy-1',
                'type': 'start',
                'title': 'Inicio',
                'dateLocal': '2026-09-01',
                'status': EventStatus.active,
              },
            ],
            'progress': [
              {
                'bookEntryId': 'book-1',
                'currentPage': 12,
                'updatedAt': '2026-09-01T00:00:00.000Z',
              },
            ],
            'readingChapters': [
              {
                'kind': 'month',
                'key': '2025-07',
                'timezone': 'UTC',
                'startsAt': '2025-07-01T00:00:00.000Z',
                'endsAt': '2025-07-31T23:59:59.000Z',
                'curationRevision': 0,
                'curation': {'reflections': <Object>[]},
              },
            ],
            'workGroupOverrides': [
              {'bookEntryId': 'book-1', 'groupId': 'group-1'},
            ],
          };
        },
        fetchCover: (url) async =>
            const CoverBytes(statusCode: 200, bytes: [9, 8, 7]),
      );

      final result = await service.importFromApi();

      expect(result.isOk, isTrue);
      expect(exportCalls, 1);
      expect(prefs.getDataPlane(), DataPlane.local.name);
      expect(prefs.getImportCheckpointJson(), isNull);
      final books = await store.list(LocalCollections.books);
      expect(books, hasLength(2));
      expect(books.every((b) => b['ownerType'] == 'user'), isTrue);
      expect(books.every((b) => b['ownerId'] == localGuestUserId), isTrue);
      expect(
        books.firstWhere((b) => b['id'] == 'legacy-book')[
            LegacyServerExport.linkedOwnerIdKey],
        isNull,
      );
      final events = await store.list(LocalCollections.events);
      expect(events.single['ownerType'], 'user');
      final chapters = await store.list(LocalCollections.readingChapters);
      expect(chapters.single['id'], 'month:2025-07');
      final overrides = await store.list(LocalCollections.workGroupOverrides);
      expect(overrides.single['id'], 'book-1');
      final cover = await store.coverFile('book-1');
      expect(cover.existsSync(), isTrue);
      expect(await cover.readAsBytes(), [9, 8, 7]);
      expect(
        books.firstWhere((b) => b['id'] == 'book-1')['coverUrl'],
        cover.path,
      );
    },
  );

  test('cover 404 writes an empty placeholder and still flips local', () async {
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => {
        'books': [bookJson()],
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 404),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isTrue);
    expect(prefs.getDataPlane(), DataPlane.local.name);
    final cover = await store.coverFile('book-1');
    expect(cover.existsSync(), isTrue);
    expect(await cover.length(), 0);
    final books = await store.list(LocalCollections.books);
    expect(books.single['coverUrl'], cover.path);
  });

  test('cover 5xx skips the file and still flips local', () async {
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => {
        'books': [bookJson()],
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 500),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isTrue);
    expect(prefs.getDataPlane(), DataPlane.local.name);
    final cover = await store.coverFile('book-1');
    expect(cover.existsSync(), isFalse);
    final books = await store.list(LocalCollections.books);
    expect(books.single['coverUrl'], 'https://covers.example/a.jpg');
  });

  test('imported profile is copied into the local guest prefs', () async {
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => {
        'books': [bookJson()],
        'profile': {
          'id': 'user-uuid',
          'email': 'ada@example.com',
          'displayName': 'Ada',
          'preferredLocale': 'es',
          'timezone': 'Europe/Madrid',
        },
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 404),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isTrue);
    final stored =
        jsonDecode(prefs.getLocalProfileJson()!) as Map<String, dynamic>;
    expect(stored['id'], localGuestUserId);
    expect(stored['email'], '');
    expect(stored['displayName'], 'Ada');
  });

  test('existing checkpoint skips the export request', () async {
    var exportCalls = 0;
    await prefs.setImportCheckpointJson(
      '{"books":[{"id":"book-1","ownerType":"user","ownerId":"u","title":"A","authors":["B"],"status":"reading"}]}',
    );
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async {
        exportCalls++;
        throw StateError('export should not run');
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 404),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isTrue);
    expect(exportCalls, 0);
    expect(prefs.getDataPlane(), DataPlane.local.name);
    expect(await store.list(LocalCollections.books), hasLength(1));
  });

  test('file checkpoint skips the export request', () async {
    var exportCalls = 0;
    final checkpoint = File('${temp.path}/import_checkpoint.json');
    await checkpoint.writeAsString(
      '{"books":[{"id":"book-2","ownerType":"user","ownerId":"u","title":"A","authors":["B"],"status":"reading"}]}',
    );
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async {
        exportCalls++;
        throw StateError('export should not run');
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 404),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isTrue);
    expect(exportCalls, 0);
    expect(prefs.getDataPlane(), DataPlane.local.name);
    expect(await store.list(LocalCollections.books), hasLength(1));
    expect(checkpoint.existsSync(), isFalse);
  });

  test('file backup round-trips JSON and cover sidecars', () async {
    await store.put(LocalCollections.books, 'book-1', bookJson(coverUrl: ''));
    final cover = await store.coverFile('book-1');
    await cover.writeAsBytes(const [1, 2, 3, 4]);
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    final backup = Directory('${temp.path}/backup');
    await service.writeFileBackup(backup);

    final restoredDir = Directory('${temp.path}/restored-covers')..createSync();
    final restoredStore = LocalStore.memory(restoredDir);
    final restoredPrefs = PrefsStorage(await SharedPreferences.getInstance());
    final restore = ImportService(
      store: restoredStore,
      prefs: restoredPrefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    await restore.restoreFileBackup(backup);

    final books = await restoredStore.list(LocalCollections.books);
    expect(books.single['id'], 'book-1');
    expect(await (await restoredStore.coverFile('book-1')).readAsBytes(), [
      1,
      2,
      3,
      4,
    ]);
    expect(restoredPrefs.getDataPlane(), DataPlane.local.name);
  });

  test('zip backup round-trips JSON and cover sidecars', () async {
    await store.put(LocalCollections.books, 'book-1', bookJson(coverUrl: ''));
    final cover = await store.coverFile('book-1');
    await cover.writeAsBytes(const [9, 8, 7]);
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    final dest = Directory('${temp.path}/zip-backup');
    final zip = await service.writeZipBackup(dest);

    final restoredDir = Directory('${temp.path}/zip-restored-covers')
      ..createSync();
    final restoredStore = LocalStore.memory(restoredDir);
    final restoredPrefs = PrefsStorage(await SharedPreferences.getInstance());
    final restore = ImportService(
      store: restoredStore,
      prefs: restoredPrefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    await restore.restoreZipBackup(zip);

    final books = await restoredStore.list(LocalCollections.books);
    expect(books.single['id'], 'book-1');
    expect(await (await restoredStore.coverFile('book-1')).readAsBytes(), [
      9,
      8,
      7,
    ]);
    expect(restoredPrefs.getDataPlane(), DataPlane.local.name);
  });

  test('import failure leaves the data plane on API', () async {
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => throw StateError('export down'),
      fetchCover: (url) async => const CoverBytes(statusCode: 200, bytes: [1]),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isFalse);
    expect(prefs.getDataPlane(), isNot(DataPlane.local.name));
    expect(await store.list(LocalCollections.books), isEmpty);
  });

  test('stamps libraryOrder from export array order', () async {
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => {
        'books': [
          bookJson(id: 'second'),
          bookJson(id: 'first', coverUrl: ''),
        ],
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 404),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isTrue);
    final books = await store.list(LocalCollections.books);
    expect(books.firstWhere((b) => b['id'] == 'second')['libraryOrder'], 0);
    expect(books.firstWhere((b) => b['id'] == 'first')['libraryOrder'], 1);
  });

  test('remaps legacy linked source book ids onto personal copies and restores notes', () async {
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => {
        'books': [
          {
            ...bookJson(id: 'personal-1', coverUrl: ''),
            LegacyServerExport.linkedBookIdKey: 'source-book-1',
            'privateNotes': 'margen',
          },
        ],
        'events': [
          {
            'id': 'ev-legacy',
            'ownerType': 'user',
            'ownerId': 'user-1',
            'bookId': 'source-book-1',
            'type': 'start',
            'title': 'Inicio',
            'dateLocal': '2026-09-01',
            'status': EventStatus.active,
          },
        ],
        'annotations': [
          {
            'id': 'note-1',
            'bookId': 'source-book-1',
            'body': 'cita',
            'category': 'quote',
            'createdAt': '2026-09-01T00:00:00.000Z',
          },
        ],
        'progress': [
          {
            'bookEntryId': 'source-book-1',
            'currentPage': 9,
            'updatedAt': '2026-09-01T00:00:00.000Z',
          },
        ],
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 404),
    );

    final result = await service.importFromApi();

    expect(result.isOk, isTrue);
    final books = await store.list(LocalCollections.books);
    expect(books.single['notes'], 'margen');
    expect(books.single['annotationCount'], 1);
    final events = await store.list(LocalCollections.events);
    expect(events.single['bookId'], 'personal-1');
    final notes = await store.list(LocalCollections.annotations);
    expect(notes.single['bookId'], 'personal-1');
    final progress = await store.list(LocalCollections.progress);
    expect(progress.single['bookEntryId'], 'personal-1');
  });

  test('canonical backup preserves libraryOrder and device prefs', () async {
    await prefs.setTheme('dark');
    await prefs.setThemePreset('ocean');
    await store.put(
      LocalCollections.books,
      'first',
      bookJson(id: 'first', coverUrl: '')..['libraryOrder'] = 2,
    );
    await store.put(
      LocalCollections.books,
      'second',
      bookJson(id: 'second', coverUrl: '')..['libraryOrder'] = 0,
    );
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    final backup = Directory('${temp.path}/order-backup');
    await service.writeFileBackup(backup);
    final export =
        jsonDecode(await File('${backup.path}/export.json').readAsString())
            as Map<String, dynamic>;
    expect(export['formatVersion'], localBackupFormatVersion);
    expect(export['libraryLayout'], 'preserved');
    final books = export['books'] as List;
    expect(books.first['id'], 'second');
    expect(books.last['id'], 'first');

    final restoredStore = LocalStore.memory(Directory('${temp.path}/order-r'));
    final restoredPrefs = PrefsStorage(await SharedPreferences.getInstance());
    final restore = ImportService(
      store: restoredStore,
      prefs: restoredPrefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    await restore.restoreFileBackup(backup);

    final restoredBooks = await restoredStore.list(LocalCollections.books);
    restoredBooks.sort((a, b) {
      final ao = (a['libraryOrder'] as num?)?.toInt() ?? 0;
      final bo = (b['libraryOrder'] as num?)?.toInt() ?? 0;
      return ao.compareTo(bo);
    });
    expect(restoredBooks.map((b) => b['id']).toList(), ['second', 'first']);
    expect(restoredPrefs.getTheme(), 'dark');
    expect(restoredPrefs.getThemePreset(), 'ocean');
  });

  test('failed apply rolls back library and covers', () async {
    await store.put(LocalCollections.books, 'keep', bookJson(id: 'keep'));
    final cover = await store.coverFile('keep');
    await cover.writeAsBytes(const [4, 5, 6]);
    final incoming = Directory('${temp.path}/incoming-backup');
    await incoming.create(recursive: true);
    await File(p.join(incoming.path, 'export.json')).writeAsString(
      jsonEncode({
        'books': [bookJson(id: 'new-book', coverUrl: '')],
      }),
    );
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
      onPlaneFlipped: () => throw StateError('post-apply failed'),
    );

    expect(
      () => service.restoreFileBackup(incoming),
      throwsA(isA<StateError>()),
    );
    final books = await store.list(LocalCollections.books);
    expect(books.single['id'], 'keep');
    expect(await cover.readAsBytes(), [4, 5, 6]);
  });

  test('import clears existing local rows before applying export', () async {
    await store.put(LocalCollections.books, 'old', bookJson(id: 'old'));
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => {
        'books': [bookJson(id: 'new-book', coverUrl: '')],
      },
      fetchCover: (url) async => const CoverBytes(statusCode: 404),
    );
    final result = await service.importFromApi();
    expect(result.isOk, isTrue);
    final books = await store.list(LocalCollections.books);
    expect(books, hasLength(1));
    expect(books.single['id'], 'new-book');
  });

  test('file backup restores snake_case collections and profile lists', () async {
    await store.put(LocalCollections.books, 'book-1', bookJson(coverUrl: ''));
    await store.put(LocalCollections.pageActivity, 'act-1', {
      'id': 'act-1',
      'bookEntryId': 'book-1',
      'pages': 12,
      'occurredAt': '2026-09-01T00:00:00.000Z',
    });
    await store.put(LocalCollections.profile, 'me', {
      'id': 'me',
      'displayName': 'Ada',
    });
    await store.put(LocalCollections.customFieldValues, 'book-1', {
      'id': 'book-1',
      'items': [
        {'fieldId': 'f1', 'value': 'x'},
      ],
    });
    final service = ImportService(
      store: store,
      prefs: prefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    final backup = Directory('${temp.path}/backup-full');
    await service.writeFileBackup(backup);

    final restoredDir = Directory('${temp.path}/restored-full')..createSync();
    final restoredStore = LocalStore.memory(restoredDir);
    final restoredPrefs = PrefsStorage(await SharedPreferences.getInstance());
    final restore = ImportService(
      store: restoredStore,
      prefs: restoredPrefs,
      fetchExport: () async => throw StateError('unused'),
      fetchCover: (url) async => throw StateError('unused'),
    );
    await restore.restoreFileBackup(backup);

    expect(await restoredStore.list(LocalCollections.pageActivity), hasLength(1));
    expect(
      (await restoredStore.list(LocalCollections.customFieldValues)).single['id'],
      'book-1',
    );
    final profile = jsonDecode(restoredPrefs.getLocalProfileJson()!)
        as Map<String, dynamic>;
    expect(profile['displayName'], 'Ada');
  });
}
