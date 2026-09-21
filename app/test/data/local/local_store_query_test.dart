import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:readendar/data/local/local_library_repos.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> _event({
  required String id,
  required String date,
  String bookId = 'book-a',
}) => {
  'id': id,
  'ownerType': 'user',
  'ownerId': 'local-guest',
  'bookId': bookId,
  'type': 'page_milestone',
  'title': 'Read $id',
  'dateLocal': date,
  'status': 'active',
};

Future<void> _seedYearOfEvents(LocalStore store) async {
  for (var i = 0; i < 400; i++) {
    final day = DateTime.utc(2026).add(Duration(days: i));
    final ymd =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    await store.put(
      LocalCollections.events,
      'e$i',
      _event(id: 'e$i', date: ymd),
    );
  }
}

void main() {
  group('memory', () {
    late Directory temp;
    late LocalStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rd-local-query-mem');
      store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
    });

    tearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('date window returns only in-range events from hundreds', () async {
      await _seedYearOfEvents(store);
      final rows = await store.list(
        LocalCollections.events,
        query: const LocalListQuery(
          dateLocalFrom: '2026-03-01',
          dateLocalToExclusive: '2026-04-01',
          orderByPath: 'dateLocal',
        ),
      );
      expect(rows, hasLength(31));
      expect(rows.first['dateLocal'], '2026-03-01');
      expect(rows.last['dateLocal'], '2026-03-31');
    });

    test('bookId filter skips other books', () async {
      await store.put(
        LocalCollections.events,
        'a1',
        _event(id: 'a1', date: '2026-09-01'),
      );
      await store.put(
        LocalCollections.events,
        'b1',
        _event(id: 'b1', date: '2026-09-01', bookId: 'book-b'),
      );
      final rows = await store.list(
        LocalCollections.events,
        query: const LocalListQuery(equals: {'bookId': 'book-a'}),
      );
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'a1');
    });

    test('libraryOrder sort is numeric', () async {
      await store.put(LocalCollections.books, 'c', {
        'id': 'c',
        'libraryOrder': 12,
      });
      await store.put(LocalCollections.books, 'a', {
        'id': 'a',
        'libraryOrder': 2,
      });
      await store.put(LocalCollections.books, 'b', {
        'id': 'b',
        'libraryOrder': 3,
      });
      final rows = await store.list(
        LocalCollections.books,
        query: const LocalListQuery(orderByPath: 'libraryOrder'),
      );
      expect(rows.map((r) => r['id']), ['a', 'b', 'c']);
    });
  });

  group('sqlite', () {
    late Directory temp;
    late LocalStore store;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rd-local-query-sql');
      store = await LocalStore.open(files: temp);
    });

    tearDown(() async {
      await store.close();
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('date window uses sqlite and keeps civil-date bounds', () async {
      await _seedYearOfEvents(store);
      final rows = await store.list(
        LocalCollections.events,
        query: const LocalListQuery(
          dateLocalFrom: '2026-03-01',
          dateLocalToExclusive: '2026-04-01',
          orderByPath: 'dateLocal',
        ),
      );
      expect(rows, hasLength(31));
      expect(rows.first['id'], 'e59');
      expect(rows.last['dateLocal'], '2026-03-31');
    });

    test('v1 databases gain query indexes on open', () async {
      await store.close();
      final sqlitePath = p.join(temp.path, 'readendar_local.sqlite');
      await File(sqlitePath).delete();
      final v1 = await openDatabase(
        sqlitePath,
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
CREATE TABLE docs (
  collection TEXT NOT NULL,
  id TEXT NOT NULL,
  json TEXT NOT NULL,
  PRIMARY KEY (collection, id)
)
''');
          await db.execute(
            'CREATE INDEX docs_collection ON docs(collection)',
          );
        },
      );
      await v1.insert('docs', {
        'collection': LocalCollections.events,
        'id': 'keep',
        'json':
            '{"id":"keep","ownerType":"user","ownerId":"local-guest",'
            '"bookId":"book-a","type":"start","title":"Start",'
            '"dateLocal":"2026-09-20","status":"active"}',
      });
      await v1.close();

      store = await LocalStore.open(files: temp);
      final rows = await store.list(
        LocalCollections.events,
        query: const LocalListQuery(
          dateLocalFrom: '2026-09-01',
          dateLocalToExclusive: '2026-10-01',
        ),
      );
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'keep');

      final db = await openDatabase(sqlitePath);
      final names = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index'",
      );
      await db.close();
      expect(
        names.map((r) => r['name']),
        containsAll([
          'docs_collection_date_local',
          'docs_collection_book_id',
          'docs_collection_library_order',
        ]),
      );
    });
  });

  group('LocalEventRepository', () {
    late Directory temp;
    late LocalStore store;
    late LocalEventRepository events;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('rd-local-events');
      store = LocalStore.memory(Directory('${temp.path}/covers')..createSync());
      events = LocalEventRepository(store);
    });

    tearDown(() async {
      if (temp.existsSync()) await temp.delete(recursive: true);
    });

    test('list range ignores events outside the civil-date window', () async {
      await _seedYearOfEvents(store);
      final result = await events.list(
        from: DateTime(2026, 6),
        to: DateTime(2026, 7),
      );
      expect(result.isOk, isTrue);
      expect(result.value, hasLength(30));
      expect(result.value!.first.dateLocal.month, 6);
      expect(result.value!.last.dateLocal.day, 30);
    });

    test('listForBook does not return other books', () async {
      await store.put(
        LocalCollections.events,
        'a1',
        _event(id: 'a1', date: '2026-09-01'),
      );
      await store.put(
        LocalCollections.events,
        'b1',
        _event(id: 'b1', date: '2026-09-02', bookId: 'book-b'),
      );
      final result = await events.listForBook('book-a');
      expect(result.value, hasLength(1));
      expect(result.value!.single.id, 'a1');
    });
  });
}
