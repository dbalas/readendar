import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/data/local/legacy_server_export.dart';
import 'package:readendar/data/local/local_store.dart';

String localYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime localCivilUtc(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

bool localDateInRange(DateTime dateLocal, DateTime? from, DateTime? to) {
  final d = localCivilUtc(dateLocal);
  if (from != null && d.isBefore(localCivilUtc(from))) return false;
  if (to != null && !d.isBefore(localCivilUtc(to))) return false;
  return true;
}

class LocalNotFound implements Exception {
  const LocalNotFound();
}

Future<Result<T>> guardLocal<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on LocalNotFound {
    return const Err(NotFoundFailure());
  } on Object catch (e) {
    return Err(UnknownFailure(e.toString()));
  }
}

Map<String, dynamic> personalizeOwner(Map<String, dynamic> row) {
  final out = Map<String, dynamic>.from(row);
  out['ownerType'] = 'user';
  out['ownerId'] = localGuestUserId;
  for (final key in LegacyServerExport.stripKeys) {
    out.remove(key);
  }
  return out;
}

String localRowId(Map<String, dynamic> item) {
  final id = item['id'] ?? item['bookEntryId'] ?? item['key'];
  if (id is String && id.isNotEmpty) return id;
  throw StateError('local row missing id');
}

/// Current on-disk backup envelope written by [ImportService.writeFileBackup].
const localBackupFormatVersion = 1;

/// Server export keys vs SQLite collection names used by file/zip backups.
const archiveKeyAliases = <String, List<String>>{
  LocalCollections.books: ['books'],
  LocalCollections.events: ['events'],
  LocalCollections.progress: ['progress'],
  LocalCollections.planRuns: ['planRuns'],
  LocalCollections.annotations: ['annotations'],
  LocalCollections.pageActivity: ['pageActivity', 'page_activity'],
  LocalCollections.bookStatusHistory: [
    'bookStatusHistory',
    'book_status_history',
  ],
  LocalCollections.customFieldDefinitions: ['customFieldDefinitions'],
  LocalCollections.customFieldValues: ['customFieldValues'],
  LocalCollections.readingChapters: [
    'readingChapters',
    'reading_chapter_periods',
  ],
  LocalCollections.workGroupOverrides: [
    'workGroupOverrides',
    'work_group_overrides',
  ],
  LocalCollections.notificationPreferences: ['notificationPreferences'],
  LocalCollections.profile: ['profile'],
};

Object? archiveValue(Map<String, dynamic> archive, String collection) {
  for (final key in archiveKeyAliases[collection] ?? [collection]) {
    if (archive.containsKey(key)) return archive[key];
  }
  return null;
}

/// Canonical JSON key for a collection in user-facing backups.
String exportKeyForCollection(String collection) {
  final aliases = archiveKeyAliases[collection];
  if (aliases != null && aliases.isNotEmpty) return aliases.first;
  return collection;
}

bool isCanonicalLocalBackup(Map<String, dynamic> archive) =>
    (archive['formatVersion'] as num?)?.toInt() == localBackupFormatVersion;

bool preservesLibraryLayout(Map<String, dynamic> archive) =>
    archive['libraryLayout'] == 'preserved';

Object? devicePrefsFromArchive(Map<String, dynamic> archive) =>
    archive['devicePrefs'];

int compareLibraryOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
  final ao = (a['libraryOrder'] as num?)?.toInt() ?? 0;
  final bo = (b['libraryOrder'] as num?)?.toInt() ?? 0;
  return ao.compareTo(bo);
}

/// Legacy server-export book link field (wire name unchanged for old backups).
Map<String, String> linkedSourceToPersonalIds(Object? books) {
  final out = <String, String>{};
  if (books is! List) return out;
  for (final item in books) {
    if (item is! Map) continue;
    final id = item['id'];
    final linked = item[LegacyServerExport.linkedBookIdKey];
    if (id is String &&
        id.isNotEmpty &&
        linked is String &&
        linked.isNotEmpty) {
      out[linked] = id;
    }
  }
  return out;
}

void remapBookRef(
  Map<String, dynamic> row,
  Map<String, String> linkedIds, {
  List<String> keys = const ['bookId', 'bookEntryId', 'id'],
}) {
  for (final key in keys) {
    final value = row[key];
    if (value is String && linkedIds.containsKey(value)) {
      row[key] = linkedIds[value];
    }
  }
}

void remapCurationBookRefs(
  Map<String, dynamic> period,
  Map<String, String> linkedIds,
) {
  final curation = period['curation'];
  if (curation is! Map) return;
  final reflections = curation['reflections'];
  if (reflections is! List) return;
  for (var i = 0; i < reflections.length; i++) {
    final item = reflections[i];
    if (item is! Map) continue;
    final mapped = Map<String, dynamic>.from(item);
    remapBookRef(mapped, linkedIds);
    reflections[i] = mapped;
  }
}

bool isRemoteCoverUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

/// HTTPS original when import kept a sandbox path on coverUrl.
String widgetSafeCoverUrl(Map<String, dynamic> row) {
  final source = row['sourceCoverUrl'] as String? ?? '';
  if (isRemoteCoverUrl(source)) return source;
  final cover = row['coverUrl'] as String? ?? '';
  if (isRemoteCoverUrl(cover)) return cover;
  return cover;
}

void stampLibraryOrder(List<Map<String, dynamic>> books) {
  for (var i = 0; i < books.length; i++) {
    books[i]['libraryOrder'] = i;
  }
}

void applyNoteChrome(
  List<Map<String, dynamic>> books,
  List<Map<String, dynamic>> annotations,
) {
  final counts = <String, int>{};
  for (final row in annotations) {
    final bookId = row['bookId'];
    if (bookId is! String || bookId.isEmpty) continue;
    counts[bookId] = (counts[bookId] ?? 0) + 1;
  }
  for (final book in books) {
    final id = book['id'];
    if (id is! String) continue;
    book['annotationCount'] = counts[id] ?? 0;
    final notes = book['notes'] ?? book['privateNotes'];
    if (notes is String && notes.isNotEmpty) {
      book['notes'] = notes;
    }
  }
}

List<Map<String, dynamic>> asObjectList(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  return const [];
}

/// Server export is a map of bookId → values. File backups store `{id, items}`.
List<Map<String, dynamic>> customFieldValueRows(Object? raw) {
  if (raw is Map) {
    return [
      for (final entry in raw.entries)
        {'id': entry.key.toString(), 'items': entry.value},
    ];
  }
  return asObjectList(raw);
}

List<Map<String, dynamic>> singletonOrList(Object? raw, String fallbackId) {
  if (raw is Map) {
    final row = Map<String, dynamic>.from(raw);
    row['id'] = row['id'] ?? fallbackId;
    return [row];
  }
  return asObjectList(raw);
}
