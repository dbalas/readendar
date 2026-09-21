import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/import/babelio_csv.dart';
import 'package:readendar/features/import/bookmory_xlsx.dart';
import 'package:readendar/features/import/goodreads_csv.dart';
import 'package:readendar/features/import/import_confirm_screen.dart';
import 'package:readendar/features/import/import_models.dart';
import 'package:readendar/features/import/storygraph_csv.dart';

/// Parses raw Goodreads CSV [content] off the main isolate and, on success,
/// navigates to [ImportConfirmScreen]. On failure it shows a localized snackbar
/// and returns without navigating.
///
/// This is the single "have the CSV string → review" seam shared by every way a
/// CSV can reach the app: the manual file picker and the "Open with Readendar"
/// deep link. Keeping it in one place means both behave identically (same
/// off-isolate parse, same error copy, same confirm screen) and the confirm
/// screen's library dedupe protects them both.
///
/// Pass [replace] to swap the current route instead of stacking on top of it —
/// used by transient landing screens (deep-link) that should not remain in the
/// back stack behind the confirm screen.
///
/// Returns `true` once it has navigated to the confirm screen, or `false` if the
/// CSV was unparseable/empty (after showing the snackbar).
Future<bool> openImportConfirm(
  BuildContext context,
  String content, {
  bool replace = false,
}) async {
  final l = AppL10n.of(context);
  void fail(String message) {
    if (!context.mounted) return;
    showRdToast(context, message: message);
  }

  ImportParseResult parsed;
  try {
    // A large export (thousands of RFC-4180 rows with embedded newlines) would
    // freeze the UI if parsed on the main isolate.
    parsed = await compute(parseGoodreadsCsv, content);
  } on Object {
    fail(l.importInvalidFile);
    return false;
  }
  if (parsed.isEmpty) {
    fail(l.importEmptyFile);
    return false;
  }
  if (!context.mounted) return false;
  return _openParsedImport(context, parsed, replace: replace);
}

/// Bookmory's XLSX acquisition adapter. Once parsed, it uses the exact same
/// review and import pipeline as Goodreads.
Future<bool> openBookmoryImportConfirm(
  BuildContext context,
  Uint8List bytes, {
  bool replace = false,
}) async {
  final l = AppL10n.of(context);
  ImportParseResult parsed;
  try {
    parsed = await compute(parseBookmoryXlsx, bytes);
  } on Object {
    if (context.mounted) {
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: l.bookmoryImportInvalidFile,
      );
    }
    return false;
  }
  if (parsed.isEmpty) {
    if (context.mounted) {
      showRdToast(context, tone: RdToastTone.error, message: l.importEmptyFile);
    }
    return false;
  }
  if (!context.mounted) return false;
  return _openParsedImport(context, parsed, replace: replace);
}

/// Babelio's native CSV acquisition adapter. Once parsed, it uses the same
/// review and import pipeline as every other source.
Future<bool> openBabelioImportConfirm(
  BuildContext context,
  String content, {
  bool replace = false,
}) async {
  final l = AppL10n.of(context);
  ImportParseResult parsed;
  try {
    parsed = await compute(parseBabelioCsv, content);
  } on Object {
    if (context.mounted) {
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: l.babelioImportInvalidFile,
      );
    }
    return false;
  }
  if (parsed.isEmpty) {
    if (context.mounted) {
      showRdToast(context, tone: RdToastTone.error, message: l.importEmptyFile);
    }
    return false;
  }
  if (!context.mounted) return false;
  return _openParsedImport(context, parsed, replace: replace);
}

/// StoryGraph's native CSV acquisition adapter. Once parsed, it uses the same
/// review and import pipeline as every other source.
Future<bool> openStoryGraphImportConfirm(
  BuildContext context,
  String content, {
  bool replace = false,
}) async {
  final l = AppL10n.of(context);
  ImportParseResult parsed;
  try {
    parsed = await compute(parseStoryGraphCsv, content);
  } on Object {
    if (context.mounted) {
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: l.storygraphImportInvalidFile,
      );
    }
    return false;
  }
  if (parsed.isEmpty) {
    if (context.mounted) {
      showRdToast(context, tone: RdToastTone.error, message: l.importEmptyFile);
    }
    return false;
  }
  if (!context.mounted) return false;
  return _openParsedImport(context, parsed, replace: replace);
}

Future<bool> _openParsedImport(
  BuildContext context,
  ImportParseResult parsed, {
  required bool replace,
}) async {
  if (!context.mounted) return false;
  final route = rdPageRoute<void>(
    context,
    builder: (_) => ImportConfirmScreen(parsed: parsed),
  );
  if (replace) {
    await Navigator.of(context).pushReplacement(route);
  } else {
    await Navigator.of(context).push(route);
  }
  return true;
}
