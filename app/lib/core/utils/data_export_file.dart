import 'dart:io';

const _exportPrefix = 'readendar-export-';
const _exportSuffix = '.json';

/// Removes exports left behind when the process was terminated while the
/// platform share sheet still held the file.
Future<void> cleanupStaleDataExports(Directory directory) async {
  try {
    if (!directory.existsSync()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith(_exportPrefix) || !name.endsWith(_exportSuffix)) {
        continue;
      }
      try {
        await entity.delete();
      } on FileSystemException {
        // A share provider may still hold a previous file. The next export
        // retries cleanup; the OS temporary-directory lifecycle is fallback.
      }
    }
  } on FileSystemException {
    // Export creation below will surface a usable error if the directory itself
    // is unavailable. Cleanup remains best effort.
  }
}

/// Writes a short-lived account export, hands it to the platform share flow,
/// and removes it whether sharing succeeds, fails, or is cancelled.
Future<void> shareTemporaryDataExport({
  required Directory directory,
  required String contents,
  required Future<void> Function(File file) share,
}) async {
  await cleanupStaleDataExports(directory);
  final file = File(
    '${directory.path}/$_exportPrefix${DateTime.now().microsecondsSinceEpoch}$_exportSuffix',
  );
  try {
    await file.writeAsString(contents, flush: true);
    await share(file);
  } finally {
    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // The privacy-safe cleanup was attempted. Temporary-directory lifecycle
      // remains the OS fallback if the file is locked by the share provider.
    }
  }
}
