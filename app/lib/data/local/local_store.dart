import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Collection names in the local document store.
abstract final class LocalCollections {
  static const books = 'books';
  static const events = 'events';
  static const progress = 'progress';
  static const planRuns = 'planRuns';
  static const annotations = 'annotations';
  static const pageActivity = 'page_activity';
  static const bookStatusHistory = 'book_status_history';
  static const customFieldDefinitions = 'customFieldDefinitions';
  static const customFieldValues = 'customFieldValues';
  static const readingChapters = 'reading_chapter_periods';
  static const workGroupOverrides = 'work_group_overrides';
  static const notificationPreferences = 'notificationPreferences';
  static const profile = 'profile';

  static const List<String> all = [
    books,
    events,
    progress,
    planRuns,
    annotations,
    pageActivity,
    bookStatusHistory,
    customFieldDefinitions,
    customFieldValues,
    readingChapters,
    workGroupOverrides,
    notificationPreferences,
    profile,
  ];
}

/// JSON fields that list queries may filter or sort on. Keep this closed so
/// SQL `json_extract` paths stay parameterized and indexed.
const Set<String> kLocalQueryJsonPaths = {
  'dateLocal',
  'bookId',
  'bookEntryId',
  'libraryOrder',
};

/// Optional predicates for [LocalStore.list]. SQLite applies them with
/// `json_extract` (and matching indexes); the in-memory store mirrors the
/// same rules after decode.
class LocalListQuery {
  const LocalListQuery({
    this.equals = const {},
    this.dateLocalFrom,
    this.dateLocalToExclusive,
    this.orderByPath,
  });

  /// Exact match on JSON string fields (`bookId`, `bookEntryId`, …).
  final Map<String, String> equals;

  /// Inclusive civil-date lower bound (`YYYY-MM-DD`) on `dateLocal`.
  final String? dateLocalFrom;

  /// Exclusive civil-date upper bound (`YYYY-MM-DD`) on `dateLocal`.
  final String? dateLocalToExclusive;

  /// JSON field to sort by (`dateLocal`, `libraryOrder`).
  final String? orderByPath;

  bool get isEmpty =>
      equals.isEmpty &&
      dateLocalFrom == null &&
      dateLocalToExclusive == null &&
      orderByPath == null;
}

/// SQLite document store for the offline library. One row per entity.
/// Tests can use [LocalStore.memory] to skip the native plugin.
class LocalStore {
  LocalStore(Database db, this.filesDir) : _db = db, _memory = null;

  LocalStore.memory(this.filesDir) : _db = null, _memory = {};

  final Database? _db;
  final Directory filesDir;
  final Map<String, Map<String, String>>? _memory;

  static const schemaVersion = 2;

  static Future<LocalStore> open({Database? database, Directory? files}) async {
    final dir = files ?? await getApplicationSupportDirectory();
    final covers = Directory(p.join(dir.path, 'covers'));
    if (!covers.existsSync()) {
      covers.createSync(recursive: true);
    }
    final db =
        database ??
        await openDatabase(
          p.join(dir.path, 'readendar_local.sqlite'),
          version: schemaVersion,
          onCreate: (db, _) async {
            await _createDocsTable(db);
            await _createQueryIndexes(db);
          },
          onUpgrade: (db, oldVersion, _) async {
            if (oldVersion < 2) await _createQueryIndexes(db);
          },
        );
    return LocalStore(db, covers);
  }

  static Future<void> _createDocsTable(Database db) async {
    await db.execute('''
CREATE TABLE docs (
  collection TEXT NOT NULL,
  id TEXT NOT NULL,
  json TEXT NOT NULL,
  PRIMARY KEY (collection, id)
)
''');
    await db.execute('CREATE INDEX docs_collection ON docs(collection)');
  }

  static Future<void> _createQueryIndexes(Database db) async {
    await db.execute(
      r"CREATE INDEX IF NOT EXISTS docs_collection_date_local ON docs(collection, json_extract(json, '$.dateLocal'))",
    );
    await db.execute(
      r"CREATE INDEX IF NOT EXISTS docs_collection_book_id ON docs(collection, json_extract(json, '$.bookId'))",
    );
    await db.execute(
      r"CREATE INDEX IF NOT EXISTS docs_collection_book_entry_id ON docs(collection, json_extract(json, '$.bookEntryId'))",
    );
    await db.execute(
      r"CREATE INDEX IF NOT EXISTS docs_collection_library_order ON docs(collection, json_extract(json, '$.libraryOrder'))",
    );
  }

  Future<List<Map<String, dynamic>>> list(
    String collection, {
    LocalListQuery query = const LocalListQuery(),
  }) async {
    final memory = _memory;
    if (memory != null) {
      final decoded = [
        for (final raw in memory[collection]?.values ?? const <String>[])
          jsonDecode(raw) as Map<String, dynamic>,
      ];
      return _applyQuery(decoded, query);
    }
    final sql = _sqlQuery(query);
    final rows = await _db!.rawQuery(sql.sql, [collection, ...sql.args]);
    return [
      for (final row in rows)
        jsonDecode(row['json']! as String) as Map<String, dynamic>,
    ];
  }

  Future<Map<String, dynamic>?> get(String collection, String id) async {
    final memory = _memory;
    if (memory != null) {
      final raw = memory[collection]?[id];
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    }
    final rows = await _db!.query(
      'docs',
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['json']! as String) as Map<String, dynamic>;
  }

  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> json,
  ) async {
    final encoded = jsonEncode(json);
    final memory = _memory;
    if (memory != null) {
      memory.putIfAbsent(collection, () => {})[id] = encoded;
      return;
    }
    await _db!.insert('docs', {
      'collection': collection,
      'id': id,
      'json': encoded,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String collection, String id) async {
    final memory = _memory;
    if (memory != null) {
      memory[collection]?.remove(id);
      return;
    }
    await _db!.delete(
      'docs',
      where: 'collection = ? AND id = ?',
      whereArgs: [collection, id],
    );
  }

  Future<void> replaceAll(
    String collection,
    List<Map<String, dynamic>> items, {
    required String Function(Map<String, dynamic> item) idOf,
  }) async {
    final memory = _memory;
    if (memory != null) {
      memory[collection] = {
        for (final item in items) idOf(item): jsonEncode(item),
      };
      return;
    }
    await _db!.transaction((txn) async {
      await txn.delete(
        'docs',
        where: 'collection = ?',
        whereArgs: [collection],
      );
      for (final item in items) {
        await txn.insert('docs', {
          'collection': collection,
          'id': idOf(item),
          'json': jsonEncode(item),
        });
      }
    });
  }

  Future<File> coverFile(String bookId) async {
    return File(p.join(filesDir.path, '$bookId.jpg'));
  }

  /// Copies a staged camera/gallery file into the cover sidecar.
  Future<File> saveCover(String bookId, String sourcePath) async {
    final dest = await coverFile(bookId);
    await dest.parent.create(recursive: true);
    await File(sourcePath).copy(dest.path);
    return dest;
  }

  Future<void> close() async {
    final db = _db;
    if (db == null || !db.isOpen) return;
    await db.close();
  }

  Future<void> clearAll() async {
    final memory = _memory;
    if (memory != null) {
      memory.clear();
    } else {
      await _db!.delete('docs');
    }
    if (filesDir.existsSync()) {
      await for (final entity in filesDir.list()) {
        if (entity is File) {
          try {
            await entity.delete();
          } on FileSystemException {
            // A cover still held open by the image cache is retried next wipe.
          }
        }
      }
    }
  }
}

String _jsonExtract(String path) {
  if (!kLocalQueryJsonPaths.contains(path)) {
    throw ArgumentError.value(path, 'path', 'unsupported local query field');
  }
  return "json_extract(json, '\$.$path')";
}

({String sql, List<Object?> args}) _sqlQuery(LocalListQuery query) {
  final where = StringBuffer('collection = ?');
  final args = <Object?>[];
  for (final entry in query.equals.entries) {
    where.write(' AND ${_jsonExtract(entry.key)} = ?');
    args.add(entry.value);
  }
  if (query.dateLocalFrom != null) {
    where.write(' AND ${_jsonExtract('dateLocal')} >= ?');
    args.add(query.dateLocalFrom);
  }
  if (query.dateLocalToExclusive != null) {
    where.write(' AND ${_jsonExtract('dateLocal')} < ?');
    args.add(query.dateLocalToExclusive);
  }
  final order = query.orderByPath == null
      ? ''
      : query.orderByPath == 'libraryOrder'
      ? ' ORDER BY COALESCE(${_jsonExtract('libraryOrder')}, 0) ASC'
      : ' ORDER BY ${_jsonExtract(query.orderByPath!)} ASC';
  return (
    sql: 'SELECT json FROM docs WHERE $where$order',
    args: args,
  );
}

List<Map<String, dynamic>> _applyQuery(
  List<Map<String, dynamic>> rows,
  LocalListQuery query,
) {
  if (query.isEmpty) return rows;
  final out = <Map<String, dynamic>>[
    for (final row in rows)
      if (_matchesQuery(row, query)) row,
  ];
  final path = query.orderByPath;
  if (path == null) return out;
  out.sort(
    (a, b) => _compareField(a[path], b[path], numeric: path == 'libraryOrder'),
  );
  return out;
}

bool _matchesQuery(Map<String, dynamic> row, LocalListQuery query) {
  for (final entry in query.equals.entries) {
    if (row[entry.key]?.toString() != entry.value) return false;
  }
  final day = _civilDate(row['dateLocal']);
  if (query.dateLocalFrom != null) {
    if (day == null || day.compareTo(query.dateLocalFrom!) < 0) return false;
  }
  if (query.dateLocalToExclusive != null) {
    if (day == null || day.compareTo(query.dateLocalToExclusive!) >= 0) {
      return false;
    }
  }
  return true;
}

String? _civilDate(Object? raw) {
  if (raw is! String || raw.length < 10) return null;
  return raw.substring(0, 10);
}

int _compareField(Object? a, Object? b, {required bool numeric}) {
  if (numeric) {
    final ai = a is num ? a.toInt() : int.tryParse('$a') ?? 0;
    final bi = b is num ? b.toInt() : int.tryParse('$b') ?? 0;
    return ai.compareTo(bi);
  }
  return '${a ?? ''}'.compareTo('${b ?? ''}');
}
