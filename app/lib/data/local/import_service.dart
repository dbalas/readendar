import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/data/local/local_codec.dart';
import 'package:readendar/data/local/local_store.dart';

typedef ExportFetcher = Future<Map<String, dynamic>> Function();
typedef CoverFetcher = Future<CoverBytes> Function(String url);

enum ImportPhase { fetching, persisting, covers }

class ImportProgress {
  const ImportProgress({
    required this.phase,
    this.done,
    this.total,
  });

  final ImportPhase phase;
  final int? done;
  final int? total;

  double? get fraction {
    if (done == null || total == null || total! <= 0) return null;
    return (done! / total!).clamp(0.0, 1.0);
  }
}

typedef ImportProgressListener = void Function(ImportProgress progress);

class CoverBytes {
  const CoverBytes({required this.statusCode, this.bytes});
  final int statusCode;
  final List<int>? bytes;
}

/// Hydrates [LocalStore] from GET /v1/me/export, then flips [DataPlane.local].
class ImportService {
  ImportService({
    required this.store,
    required this.prefs,
    required this.fetchExport,
    required this.fetchCover,
    this.onPlaneFlipped,
  });

  final LocalStore store;
  final PrefsStorage prefs;
  final ExportFetcher fetchExport;
  final CoverFetcher fetchCover;
  final void Function()? onPlaneFlipped;

  File get _checkpointFile =>
      File(p.join(store.filesDir.parent.path, 'import_checkpoint.json'));

  /// Fetch (or resume) the export, persist rows + covers, then flip the plane.
  /// On any failure the data plane stays API.
  Future<Result<void>> importFromApi({
    ImportProgressListener? onProgress,
  }) => guardLocal(() async {
    onProgress?.call(const ImportProgress(phase: ImportPhase.fetching));
    final Map<String, dynamic> archive;
    final fromDisk = await _readCheckpoint();
    if (fromDisk != null) {
      archive = fromDisk;
    } else {
      archive = await _buildCanonicalArchive(seed: await fetchExport());
      await _writeCheckpoint(archive);
    }
    await _applyArchive(archive, onProgress: onProgress);
    await _clearCheckpoint();
  });

  /// Restores a user export: `.zip` from local backup or `.json` from the API.
  Future<void> restoreBackupFile(
    File file, {
    ImportProgressListener? onProgress,
  }) async {
    final lower = file.path.toLowerCase();
    if (lower.endsWith('.zip')) {
      await restoreZipBackup(file, onProgress: onProgress);
      return;
    }
    if (lower.endsWith('.json')) {
      final archive =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      await _applyArchive(archive, onProgress: onProgress);
      return;
    }
    throw const FormatException('unsupported backup format');
  }

  Future<void> _applyArchive(
    Map<String, dynamic> archive, {
    Directory? coverSidecars,
    ImportProgressListener? onProgress,
  }) async {
    onProgress?.call(const ImportProgress(phase: ImportPhase.persisting));
    Map<String, dynamic>? rollbackArchive;
    Directory? rollbackCovers;
    if (await _storeHasData()) {
      rollbackArchive = await _buildCanonicalArchive();
      rollbackCovers = await _snapshotCovers();
    }
    try {
      await store.clearAll();
      await persistArchive(archive);
      if (coverSidecars != null) {
        await _importCoverSidecars(coverSidecars);
      }
      await _downloadCovers(archive, onProgress: onProgress);
      await prefs.setDataPlane(DataPlane.local.name);
      onPlaneFlipped?.call();
    } catch (e) {
      if (rollbackArchive != null) {
        await _restoreRollback(rollbackArchive, rollbackCovers);
      }
      rethrow;
    } finally {
      if (rollbackCovers != null) {
        try {
          await rollbackCovers.delete(recursive: true);
        } on FileSystemException {
          // Temp snapshot; OS cleanup is fallback.
        }
      }
    }
  }

  Future<bool> _storeHasData() async {
    for (final collection in LocalCollections.all) {
      if ((await store.list(collection)).isNotEmpty) return true;
    }
    if (!store.filesDir.existsSync()) return false;
    return await store.filesDir.list().any((entity) => entity is File);
  }

  Future<Directory> _snapshotCovers() async {
    final dest = Directory(
      p.join(
        store.filesDir.parent.path,
        'import-rollback-covers-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await dest.create(recursive: true);
    if (store.filesDir.existsSync()) {
      await for (final entity in store.filesDir.list()) {
        if (entity is File) {
          await entity.copy(p.join(dest.path, p.basename(entity.path)));
        }
      }
    }
    return dest;
  }

  Future<void> _restoreRollback(
    Map<String, dynamic> archive,
    Directory? covers,
  ) async {
    await store.clearAll();
    await persistArchive(archive);
    if (covers != null) {
      await _importCoverSidecars(covers);
    }
  }

  Future<void> _importCoverSidecars(Directory coversIn) async {
    if (!coversIn.existsSync()) return;
    await store.filesDir.create(recursive: true);
    await for (final entity in coversIn.list()) {
      if (entity is File) {
        await entity.copy(
          p.join(store.filesDir.path, p.basename(entity.path)),
        );
      }
    }
  }

  /// Writes JSON + cover sidecars into [dest] (`export.json` + `covers/`).
  Future<void> writeFileBackup(Directory dest) async {
    await dest.create(recursive: true);
    final dump = await _buildCanonicalArchive();
    await File(
      p.join(dest.path, 'export.json'),
    ).writeAsString(jsonEncode(dump));
    final coversOut = Directory(p.join(dest.path, 'covers'));
    await coversOut.create(recursive: true);
    if (store.filesDir.existsSync()) {
      await for (final entity in store.filesDir.list()) {
        if (entity is File) {
          await entity.copy(p.join(coversOut.path, p.basename(entity.path)));
        }
      }
    }
  }

  /// Restores JSON + cover sidecars from a folder produced by [writeFileBackup].
  Future<void> restoreFileBackup(
    Directory src, {
    ImportProgressListener? onProgress,
  }) async {
    final file = File(p.join(src.path, 'export.json'));
    final archive =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final coversIn = Directory(p.join(src.path, 'covers'));
    await _applyArchive(
      archive,
      coverSidecars: coversIn,
      onProgress: onProgress,
    );
  }

  /// Zip backup from a server `/v1/me/export` payload (covers fetched on restore).
  Future<File> writeZipBackupFromServerArchive(
    Directory dest,
    Map<String, dynamic> serverArchive,
  ) async {
    await dest.create(recursive: true);
    final dump = await _buildCanonicalArchive(seed: serverArchive);
    await File(
      p.join(dest.path, 'export.json'),
    ).writeAsString(jsonEncode(dump));
    return _zipBackupDirectory(dest);
  }

  Future<Map<String, dynamic>> _buildCanonicalArchive({
    Map<String, dynamic>? seed,
  }) async {
    final dump = <String, dynamic>{
      'formatVersion': localBackupFormatVersion,
      'libraryLayout': seed == null ? 'preserved' : 'server',
      'exportedAt': seed?['exportedAt']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      'devicePrefs': prefs.snapshotForBackup(),
    };
    for (final collection in LocalCollections.all) {
      final key = exportKeyForCollection(collection);
      Object? raw = seed == null
          ? await store.list(collection)
          : archiveValue(seed, collection);
      if (seed != null && raw == null) {
        raw = const <Object>[];
      }
      if (collection == LocalCollections.books && raw is List) {
        final rows = [
          for (final item in raw)
            if (item is Map) Map<String, dynamic>.from(item),
        ];
        rows.sort(compareLibraryOrder);
        dump[key] = rows;
        continue;
      }
      dump[key] = raw;
    }
    return dump;
  }

  Future<File> _zipBackupDirectory(Directory dest) async {
    final archive = Archive();
    final export = File(p.join(dest.path, 'export.json'));
    final exportBytes = await export.readAsBytes();
    archive.addFile(
      ArchiveFile('export.json', exportBytes.length, exportBytes),
    );
    final covers = Directory(p.join(dest.path, 'covers'));
    if (covers.existsSync()) {
      await for (final entity in covers.list()) {
        if (entity is! File) continue;
        final bytes = await entity.readAsBytes();
        archive.addFile(
          ArchiveFile(
            'covers/${p.basename(entity.path)}',
            bytes.length,
            bytes,
          ),
        );
      }
    }
    final encoded = ZipEncoder().encode(archive) ??
        (throw StateError('zip encode failed'));
    final zip = File(p.join(dest.path, 'readendar-backup.zip'));
    await zip.writeAsBytes(Uint8List.fromList(encoded), flush: true);
    return zip;
  }

  /// Zip of [writeFileBackup] (`export.json` + `covers/`).
  Future<File> writeZipBackup(Directory dest) async {
    await writeFileBackup(dest);
    return _zipBackupDirectory(dest);
  }

  /// Restores a zip produced by [writeZipBackup].
  Future<void> restoreZipBackup(
    File zipFile, {
    ImportProgressListener? onProgress,
  }) async {
    final decoded = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    final dest = Directory(
      p.join(
        store.filesDir.parent.path,
        'restore-${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
    await dest.create(recursive: true);
    for (final file in decoded) {
      if (!file.isFile) continue;
      final out = File(p.join(dest.path, file.name));
      await out.parent.create(recursive: true);
      await out.writeAsBytes(file.content as List<int>);
    }
    await restoreFileBackup(dest, onProgress: onProgress);
    try {
      await dest.delete(recursive: true);
    } on FileSystemException {
      // Temp extract; OS cache cleanup is fallback.
    }
  }

  Future<Map<String, dynamic>?> _readCheckpoint() async {
    if (_checkpointFile.existsSync()) {
      return jsonDecode(await _checkpointFile.readAsString())
          as Map<String, dynamic>;
    }
    final leftover = prefs.getImportCheckpointJson();
    if (leftover == null || leftover.isEmpty) return null;
    final decoded = jsonDecode(leftover) as Map<String, dynamic>;
    await _writeCheckpoint(decoded);
    return decoded;
  }

  Future<void> _writeCheckpoint(Map<String, dynamic> archive) async {
    await _checkpointFile.parent.create(recursive: true);
    await _checkpointFile.writeAsString(jsonEncode(archive), flush: true);
    await prefs.clearImportCheckpoint();
  }

  Future<void> _clearCheckpoint() async {
    if (_checkpointFile.existsSync()) {
      await _checkpointFile.delete();
    }
    await prefs.clearImportCheckpoint();
  }

  Future<void> persistArchive(Map<String, dynamic> archive) async {
    final linkedIds = linkedSourceToPersonalIds(
      archiveValue(archive, LocalCollections.books),
    );

    Future<void> replace(
      String collection,
      Map<String, dynamic> Function(Map<String, dynamic> row) mapRow,
    ) => _replaceList(
      collection,
      archiveValue(archive, collection),
      mapRow,
    );

    Map<String, dynamic> remap(Map<String, dynamic> row) {
      final out = Map<String, dynamic>.from(row);
      remapBookRef(out, linkedIds);
      return out;
    }

    final bookRows = [
      for (final item in asObjectList(
        archiveValue(archive, LocalCollections.books),
      ))
        personalizeOwner(item),
    ];
    if (!preservesLibraryLayout(archive)) {
      stampLibraryOrder(bookRows);
    }

    final annotationRows = [
      for (final item in asObjectList(
        archiveValue(archive, LocalCollections.annotations),
      ))
        remap(item),
    ];
    applyNoteChrome(bookRows, annotationRows);

    await store.replaceAll(
      LocalCollections.books,
      bookRows,
      idOf: localRowId,
    );
    await replace(LocalCollections.events, (row) {
      final out = personalizeOwner(row);
      remapBookRef(out, linkedIds);
      return out;
    });
    await replace(LocalCollections.progress, remap);
    await replace(LocalCollections.planRuns, remap);
    await store.replaceAll(
      LocalCollections.annotations,
      annotationRows,
      idOf: localRowId,
    );
    await replace(LocalCollections.pageActivity, remap);
    await replace(LocalCollections.bookStatusHistory, (row) {
      final out = remap(row);
      final bookId =
          out['bookId'] as String? ?? out['bookEntryId'] as String? ?? '';
      if (bookId.isNotEmpty) {
        out['bookId'] = bookId;
        out['bookEntryId'] = bookId;
      }
      return out;
    });
    await replace(
      LocalCollections.customFieldDefinitions,
      Map<String, dynamic>.from,
    );
    await replace(LocalCollections.readingChapters, (row) {
      final out = remap(row);
      remapCurationBookRefs(out, linkedIds);
      final kind = out['kind'] as String? ?? '';
      final key = out['key'] as String? ?? '';
      if (kind.isNotEmpty && key.isNotEmpty) {
        out['id'] = '$kind:$key';
      }
      return out;
    });
    await replace(LocalCollections.workGroupOverrides, (row) {
      final out = remap(row);
      final bookId = out['bookEntryId'] as String? ?? '';
      if (bookId.isNotEmpty) out['id'] = bookId;
      return out;
    });

    final customItems = [
      for (final row in customFieldValueRows(
        archiveValue(archive, LocalCollections.customFieldValues),
      ))
        remap(row),
    ];
    await store.replaceAll(
      LocalCollections.customFieldValues,
      customItems,
      idOf: localRowId,
    );

    final profileRows = singletonOrList(
      archiveValue(archive, LocalCollections.profile),
      'me',
    );
    if (profileRows.isNotEmpty) {
      final row = profileRows.first..['id'] = 'me';
      await store.put(LocalCollections.profile, 'me', row);
      await prefs.setLocalProfileJson(
        jsonEncode(_localGuestProfileJson(row)),
      );
    }
    final notifRows = singletonOrList(
      archiveValue(archive, LocalCollections.notificationPreferences),
      'me',
    );
    if (notifRows.isNotEmpty) {
      final row = notifRows.first..['id'] = 'me';
      await store.put(LocalCollections.notificationPreferences, 'me', row);
    }

    final devicePrefs = devicePrefsFromArchive(archive);
    if (devicePrefs is Map) {
      await prefs.restoreFromBackup(Map<String, dynamic>.from(devicePrefs));
    }
  }

  Future<void> _replaceList(
    String collection,
    Object? raw,
    Map<String, dynamic> Function(Map<String, dynamic> row) mapRow,
  ) async {
    if (raw is! List) {
      await store.replaceAll(collection, const [], idOf: localRowId);
      return;
    }
    final items = <Map<String, dynamic>>[
      for (final item in raw)
        if (item is Map) mapRow(Map<String, dynamic>.from(item)),
    ];
    await store.replaceAll(collection, items, idOf: localRowId);
  }

  Future<void> _downloadCovers(
    Map<String, dynamic> archive, {
    ImportProgressListener? onProgress,
  }) async {
    // dart:io has no portable free-disk-space API across iOS and Android.
    // Skip the preflight. A single dead cover must not abort the import.
    // File.writeAsBytes still fails loudly if the volume is full.
    final books = asObjectList(archiveValue(archive, LocalCollections.books));
    const batch = 6;
    var done = 0;
    final total = books.length;
    onProgress?.call(
      ImportProgress(phase: ImportPhase.covers, done: done, total: total),
    );
    for (var i = 0; i < books.length; i += batch) {
      final end = i + batch > books.length ? books.length : i + batch;
      await Future.wait([
        for (final row in books.sublist(i, end)) _downloadOneCover(row),
      ]);
      done = end;
      onProgress?.call(
        ImportProgress(phase: ImportPhase.covers, done: done, total: total),
      );
    }
  }

  Future<void> _downloadOneCover(Map<String, dynamic> row) async {
    final id = row['id'];
    final coverUrl = row['coverUrl'];
    if (id is! String || id.isEmpty) return;
    if (coverUrl is! String || coverUrl.trim().isEmpty) return;
    final remote = coverUrl.trim();
    final dest = await store.coverFile(id);
    final result = await fetchCover(remote);
    if (result.statusCode == 404) {
      await dest.writeAsBytes(const <int>[]);
      await _rewriteCoverUrl(id, dest.path, sourceCoverUrl: remote);
      return;
    }
    if (result.statusCode != 200 || result.bytes == null) {
      if (!isRemoteCoverUrl(remote)) {
        await _rewriteCoverUrl(id, '');
      }
      return;
    }
    await dest.writeAsBytes(result.bytes!);
    await _rewriteCoverUrl(id, dest.path, sourceCoverUrl: remote);
  }

  Future<void> _rewriteCoverUrl(
    String id,
    String path, {
    String? sourceCoverUrl,
  }) async {
    final stored = await store.get(LocalCollections.books, id);
    if (stored == null) return;
    stored['coverUrl'] = path;
    if (sourceCoverUrl != null && isRemoteCoverUrl(sourceCoverUrl)) {
      stored['sourceCoverUrl'] = sourceCoverUrl;
    }
    await store.put(LocalCollections.books, id, stored);
  }
}

Map<String, dynamic> _localGuestProfileJson(Map<String, dynamic> row) => {
  'id': localGuestUserId,
  'email': '',
  'displayName': (row['displayName'] as String?) ?? '',
  'preferredLocale': (row['preferredLocale'] as String?) ?? 'es',
  'timezone': (row['timezone'] as String?) ?? 'Europe/Madrid',
  'onboardingCompletedAt': row['onboardingCompletedAt'],
  'termsAcceptedAt': row['termsAcceptedAt'],
  'termsVersion': (row['termsVersion'] as String?) ?? '',
  'analyticsEnabled': false,
  'autoCreateStatusEvents': row['autoCreateStatusEvents'] ?? false,
  'alwaysShowSpoilerQuotes': row['alwaysShowSpoilerQuotes'] ?? false,
  if (row['homeBanner'] != null) 'homeBanner': row['homeBanner'],
};
