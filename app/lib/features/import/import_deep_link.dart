// Receives "Open with Readendar" CSV files and drops the user into the import
// flow with the file already parsed.
//
// Platform reality: iOS "Open in / Copy to Readendar" delivers a readable
// `file://` URL (the document is copied into the app's Inbox), which we read
// directly. Android delivers a `content://` URI that `File` can't open, so we
// read its bytes through a platform channel backed by the ContentResolver
// (see MainActivity.kt). Either way the file is parsed and the user jumps
// straight into the import. The in-app file picker remains the guaranteed
// fallback on both platforms.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:readendar/core/utils/app_deep_link_hub.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/import_intro_screen.dart';

/// Platform channel for reading a `content://` CSV on Android (iOS never hits
/// it — it delivers `file://`). Mirrors the channel name in MainActivity.kt.
const MethodChannel contentUriChannel = MethodChannel('readendar/content');

/// Exposed as a provider so it can hold a real [Ref] and outlive any widget.
final importDeepLinkProvider = Provider<ImportDeepLink>(ImportDeepLink.new);

class ImportDeepLink {
  ImportDeepLink(this._ref);
  final Ref _ref;
  bool _attached = false;
  bool _openingStagedImport = false;

  /// Registers with the shared hub. Safe to call once at boot.
  void attach() {
    if (_attached) return;
    _attached = true;
    _ref.read(appDeepLinkHubProvider).register(handle);
  }

  Future<void> handle(Uri uri) async {
    final content = await readCsvFromUri(uri);
    if (content == null) return;
    // Stage the exact bytes in app-private storage before deleting iOS's Inbox
    // copy or attempting navigation. Cold links often arrive before the shell
    // and before the root navigator exists; deleting first used to lose the import.
    final staged = await stageOpenedCsv(content);
    if (!staged) return;
    // iOS copies the opened document into our app's Inbox; once it's read into
    // memory, delete that copy so repeated "Open with Readendar" imports don't
    // pile up in the sandbox (also Apple's documented expectation). content://
    // (Android) isn't ours to delete — the OS owns it.
    if (uri.scheme == 'file') unawaited(_deleteOpenedFile(uri));
    await resume();
  }

  /// Opens one privately staged import after both authentication and navigation
  /// are ready. The staging file remains until the Import flow returns, so an
  /// app termination during the handoff is recoverable on the next launch.
  Future<void> resume() async {
    if (_openingStagedImport) return;
    // The import writes to a library, so it only makes sense when signed in.
    if (_ref.read(sessionProvider).user == null) return;
    final nav = _ref.read(rootNavigatorKeyProvider).currentState;
    if (nav == null) return;
    final content = await readStagedOpenedCsv();
    if (content == null) return;
    _openingStagedImport = true;
    try {
      final source = detectCsvImportSource(content);
      await nav.push(
        rdPageRoute<void>(
          nav.context,
          builder: (_) =>
              ImportIntroScreen.autoCsv(source: source, content: content),
        ),
      );
      await deleteStagedOpenedCsv();
    } finally {
      _openingStagedImport = false;
    }
  }

  /// Removes the opened-in file (iOS copies it into our Inbox sandbox). The URI
  /// always points inside our own sandbox, so this can only delete our copy.
  /// Best-effort — a missing/already-removed file is fine.
  Future<void> _deleteOpenedFile(Uri uri) async {
    try {
      final file = File(uri.toFilePath());
      if (file.existsSync()) await file.delete();
    } on Object {
      // ignore — cleanup is best-effort.
    }
  }
}

/// Hard cap on an opened-in CSV, mirroring the in-app picker. Stops a huge file
/// from being read fully into memory and OOM-ing the device.
const int _maxOpenInCsvBytes = 10 * 1024 * 1024;
const _openedCsvStagingName = 'pending-open-in-import.csv';

Future<Directory> _defaultImportStagingDirectory() =>
    getApplicationSupportDirectory();

/// Persists an externally opened CSV to app-private storage. Kept separate
/// from [ImportDeepLink] so the ordering contract is unit-testable.
Future<bool> stageOpenedCsv(
  String content, {
  Future<Directory> Function()? directoryProvider,
}) async {
  if (utf8.encode(content).length > _maxOpenInCsvBytes) return false;
  try {
    final directory =
        await (directoryProvider ?? _defaultImportStagingDirectory)();
    await directory.create(recursive: true);
    await File('${directory.path}/$_openedCsvStagingName').writeAsString(
      content,
      flush: true,
    );
    return true;
  } on Object {
    return false;
  }
}

Future<String?> readStagedOpenedCsv({
  Future<Directory> Function()? directoryProvider,
}) async {
  try {
    final directory =
        await (directoryProvider ?? _defaultImportStagingDirectory)();
    final file = File('${directory.path}/$_openedCsvStagingName');
    if (!await file.exists() || await file.length() > _maxOpenInCsvBytes) {
      return null;
    }
    return await file.readAsString();
  } on Object {
    return null;
  }
}

Future<void> deleteStagedOpenedCsv({
  Future<Directory> Function()? directoryProvider,
}) async {
  try {
    final directory =
        await (directoryProvider ?? _defaultImportStagingDirectory)();
    final file = File('${directory.path}/$_openedCsvStagingName');
    if (await file.exists()) await file.delete();
  } on Object {
    // A later startup retries cleanup from the same private location.
  }
}

/// Reads a `content://` CSV's bytes via the platform channel and decodes them.
/// Returns null on any failure (missing plugin in tests, too large, unreadable).
Future<String?> _readContentUri(Uri uri) async {
  try {
    final bytes = await contentUriChannel.invokeMethod<Object?>(
      'readContentUri',
      {'uri': uri.toString()},
    );
    if (bytes is! List<int>) return null;
    // Strict decode: a file that isn't valid UTF-8 throws FormatException, which
    // we treat as unreadable (→ null → in-app picker fallback) rather than
    // silently importing mojibake titles.
    return utf8.decode(bytes);
  } on Object {
    return null;
  }
}

/// Reads a CSV opened into the app from a deep link.
///
/// - `file://` (iOS open-in): read directly, must end in `.csv`.
/// - `content://` (Android): read its bytes through [_readContentUri] (the
///   intent-filter already matched the CSV mime type, so there's no extension
///   to check). [contentReader] is injectable so tests stay deterministic.
///
/// Anything else, oversized files, or read failures return null so the caller
/// falls back to the in-app picker. Exposed for unit testing the URI gate.
Future<String?> readCsvFromUri(
  Uri uri, {
  Future<String?> Function(Uri uri)? contentReader,
}) async {
  if (uri.scheme == 'file') {
    if (!uri.path.toLowerCase().endsWith('.csv')) return null;
    try {
      final file = File(uri.toFilePath());
      if (await file.length() > _maxOpenInCsvBytes) return null;
      return await file.readAsString();
    } on Object {
      return null;
    }
  }
  if (uri.scheme == 'content') {
    return (contentReader ?? _readContentUri)(uri);
  }
  return null;
}
