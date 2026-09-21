import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/import/babelio_csv.dart';
import 'package:readendar/features/import/import_handoff.dart';
import 'package:url_launcher/url_launcher.dart';

typedef BabelioExportLauncher = Future<bool> Function(Uri uri);
typedef StoryGraphExportLauncher = Future<bool> Function(Uri uri);

const babelioExportUrl = 'https://www.babelio.com/export_bib.php';
const storygraphExportUrl = 'https://app.thestorygraph.com/user-export';

enum ImportFileSource { goodreads, storygraph, bookmory, babelio }

/// Native file filters for every supported import source.
XTypeGroup importFileTypeGroup(ImportFileSource source) => switch (source) {
  ImportFileSource.bookmory => const XTypeGroup(
    label: 'XLSX',
    extensions: ['xlsx'],
    mimeTypes: [
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ],
    uniformTypeIdentifiers: ['org.openxmlformats.spreadsheetml.sheet'],
  ),
  ImportFileSource.goodreads ||
  ImportFileSource.storygraph ||
  ImportFileSource.babelio => const XTypeGroup(
    label: 'CSV',
    extensions: ['csv'],
    mimeTypes: [
      'text/csv',
      'text/comma-separated-values',
      'application/csv',
      'application/vnd.ms-excel',
      'application/octet-stream',
      'text/plain',
    ],
    uniformTypeIdentifiers: [
      'public.comma-separated-values-text',
      'public.text',
    ],
  ),
};

/// Identifies which supported parser owns an OS-opened CSV. Export headers are
/// stable source contracts; falling back to Goodreads preserves the existing
/// source-specific error for unrelated CSV files.
ImportFileSource detectCsvImportSource(String content) {
  final lines = content
      .replaceFirst('\uFEFF', '')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .split('\n')
      .take(10);
  for (final line in lines) {
    final delimiter = line.contains(';') ? ';' : ',';
    final headers = line
        .split(delimiter)
        .map(
          (value) => value
              .replaceAll('"', '')
              .trim()
              .toLowerCase()
              .replaceAll(RegExp('[éèêë]'), 'e'),
        )
        .toSet();
    if (headers.containsAll({
      'title',
      'authors',
      'isbn/uid',
      'read status',
    })) {
      return ImportFileSource.storygraph;
    }
    if (headers.contains('title') && headers.contains('exclusive shelf')) {
      return ImportFileSource.goodreads;
    }
    final hasTitle = headers.any(
      const {'titre', 'titre du livre', 'title', 'book title'}.contains,
    );
    final hasAuthor = headers.any(
      const {'auteur', 'auteurs', 'author', 'authors'}.contains,
    );
    final hasStatus = headers.any(
      const {'statut', 'etat', 'status', 'reading status'}.contains,
    );
    if (hasTitle && hasAuthor && hasStatus) {
      return ImportFileSource.babelio;
    }
  }
  return ImportFileSource.goodreads;
}

/// Shared file-acquisition screen. Source configuration controls only copy,
/// extension and parsing; every successful file enters the same review flow.
class ImportIntroScreen extends ConsumerStatefulWidget {
  const ImportIntroScreen({this.autoContent, super.key})
    : source = ImportFileSource.goodreads,
      autoOpenPicker = false,
      babelioExportLauncher = null,
      storygraphExportLauncher = null;

  const ImportIntroScreen.autoCsv({
    required this.source,
    required String content,
    super.key,
  }) : assert(
         source != ImportFileSource.bookmory,
         'Bookmory auto-import requires XLSX bytes',
       ),
       autoContent = content,
       autoOpenPicker = false,
       babelioExportLauncher = null,
       storygraphExportLauncher = null;

  const ImportIntroScreen.storygraph({
    this.autoOpenPicker = false,
    this.storygraphExportLauncher,
    super.key,
  }) : source = ImportFileSource.storygraph,
       autoContent = null,
       babelioExportLauncher = null;

  const ImportIntroScreen.bookmory({
    this.autoOpenPicker = false,
    super.key,
  }) : source = ImportFileSource.bookmory,
       autoContent = null,
       babelioExportLauncher = null,
       storygraphExportLauncher = null;

  const ImportIntroScreen.babelio({
    this.autoOpenPicker = false,
    this.babelioExportLauncher,
    super.key,
  }) : source = ImportFileSource.babelio,
       autoContent = null,
       storygraphExportLauncher = null;

  final ImportFileSource source;

  /// Raw CSV supplied by the source-aware open-with deep link.
  final String? autoContent;

  /// When true, opens the native picker after the first frame. Normal source
  /// flows leave this false so users see export instructions first.
  final bool autoOpenPicker;

  /// Test seam for the external Babelio export page.
  final BabelioExportLauncher? babelioExportLauncher;

  /// Test seam for the external StoryGraph export page.
  final StoryGraphExportLauncher? storygraphExportLauncher;

  @override
  ConsumerState<ImportIntroScreen> createState() => _ImportIntroScreenState();
}

class _ImportIntroScreenState extends ConsumerState<ImportIntroScreen> {
  bool _busy = false;

  static const int _maxFileBytes = 10 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    final auto = widget.autoContent;
    if (auto != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        switch (widget.source) {
          case ImportFileSource.goodreads:
            await _handleGoodreads(auto, replace: true);
            return;
          case ImportFileSource.storygraph:
            await _handleStoryGraph(auto, replace: true);
            return;
          case ImportFileSource.babelio:
            await _handleBabelio(auto, replace: true);
            return;
          case ImportFileSource.bookmory:
            throw StateError('Bookmory auto-import requires XLSX bytes');
        }
      });
    } else if (widget.autoOpenPicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: [importFileTypeGroup(widget.source)],
      );
      if (file == null) return;
      if (await file.length() > _maxFileBytes) {
        if (mounted) _fail(AppL10n.of(context).importFileTooLarge);
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          _fail(_invalidFileMessage(AppL10n.of(context)));
        }
        return;
      }
      if (!mounted) return;

      switch (widget.source) {
        case ImportFileSource.bookmory:
          await _handleBookmory(bytes);
        case ImportFileSource.goodreads:
          final content = _decodeUtf8(bytes);
          if (content == null) return;
          await _handleGoodreads(content);
        case ImportFileSource.storygraph:
          final content = _decodeUtf8(bytes);
          if (content == null) return;
          await _handleStoryGraph(content);
        case ImportFileSource.babelio:
          final content = decodeBabelioCsvBytes(bytes);
          if (content.trim().isEmpty) {
            _fail(AppL10n.of(context).babelioImportInvalidFile);
            return;
          }
          await _handleBabelio(content);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _decodeUtf8(Uint8List bytes) {
    String content;
    try {
      content = utf8.decode(bytes);
    } on FormatException {
      _fail(AppL10n.of(context).importBadEncoding);
      return null;
    }
    if (content.trim().isEmpty) {
      _fail(_invalidFileMessage(AppL10n.of(context)));
      return null;
    }
    return content;
  }

  Future<void> _handleGoodreads(
    String content, {
    bool replace = false,
  }) async {
    await openImportConfirm(context, content, replace: replace);
  }

  Future<void> _handleBookmory(Uint8List bytes) async {
    await openBookmoryImportConfirm(context, bytes);
  }

  Future<void> _handleStoryGraph(
    String content, {
    bool replace = false,
  }) async {
    await openStoryGraphImportConfirm(context, content, replace: replace);
  }

  Future<void> _handleBabelio(
    String content, {
    bool replace = false,
  }) async {
    await openBabelioImportConfirm(context, content, replace: replace);
  }

  Future<void> _openBabelioExport() async {
    final uri = Uri.parse(babelioExportUrl);
    var opened = false;
    try {
      opened = await (widget.babelioExportLauncher ?? _launchExternal)(uri);
    } on Object {
      opened = false;
    }
    if (!mounted || opened) return;
    _fail(AppL10n.of(context).babelioImportOpenError);
  }

  Future<void> _openStoryGraphExport() async {
    final uri = Uri.parse(storygraphExportUrl);
    var opened = false;
    try {
      opened = await (widget.storygraphExportLauncher ?? _launchExternal)(uri);
    } on Object {
      opened = false;
    }
    if (!mounted || opened) return;
    _fail(AppL10n.of(context).storygraphImportOpenError);
  }

  Future<bool> _launchExternal(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  String _invalidFileMessage(AppL10n l) => switch (widget.source) {
    ImportFileSource.goodreads => l.importInvalidFile,
    ImportFileSource.storygraph => l.storygraphImportInvalidFile,
    ImportFileSource.bookmory => l.bookmoryImportInvalidFile,
    ImportFileSource.babelio => l.babelioImportInvalidFile,
  };

  void _fail(String message) {
    if (!mounted) return;
    showRdToast(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final copy = switch (widget.source) {
      ImportFileSource.goodreads => (
        title: l.importTitle,
        headline: l.importIntroHeadline,
        body: l.importIntroBody,
        steps: [l.importIntroStep1, l.importIntroStep2, l.importIntroStep3],
        pickFile: l.importPickFile,
      ),
      ImportFileSource.bookmory => (
        title: l.bookmoryImportTitle,
        headline: l.bookmoryImportHeadline,
        body: l.bookmoryImportBody,
        steps: [l.bookmoryImportStep1, l.bookmoryImportStep2],
        pickFile: l.bookmoryImportPickFile,
      ),
      ImportFileSource.storygraph => (
        title: l.storygraphImportTitle,
        headline: l.storygraphImportHeadline,
        body: l.storygraphImportBody,
        steps: [l.storygraphImportStep1, l.storygraphImportStep2],
        pickFile: l.storygraphImportPickFile,
      ),
      ImportFileSource.babelio => (
        title: l.babelioImportTitle,
        headline: l.babelioImportHeadline,
        body: l.babelioImportBody,
        steps: [l.babelioImportStep1, l.babelioImportStep2],
        pickFile: l.babelioImportPickFile,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: ReadendarTokens.sp6,
            vertical: ReadendarTokens.sp7,
          ),
          children: [
            Icon(LucideIcons.bookUp, size: 56, color: context.colors.accent),
            const SizedBox(height: ReadendarTokens.sp5),
            Text(
              copy.headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: ReadendarTokens.sp4),
            Text(
              copy.body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colors.fg2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp7),
            RdCard(
              padding: const EdgeInsets.all(ReadendarTokens.sp5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < copy.steps.length; index++) ...[
                    if (index > 0) const SizedBox(height: ReadendarTokens.sp3),
                    _Step(n: index + 1, text: copy.steps[index]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp7),
            if (widget.source == ImportFileSource.babelio ||
                widget.source == ImportFileSource.storygraph) ...[
              RdButton.primary(
                onPressed: _busy
                    ? null
                    : widget.source == ImportFileSource.babelio
                    ? _openBabelioExport
                    : _openStoryGraphExport,
                icon: LucideIcons.externalLink,
                label: widget.source == ImportFileSource.babelio
                    ? l.babelioImportOpenExport
                    : l.storygraphImportOpenExport,
              ),
              const SizedBox(height: ReadendarTokens.sp3),
              RdButton.secondary(
                loading: _busy,
                onPressed: _busy ? null : _pick,
                icon: LucideIcons.fileUp,
                label: copy.pickFile,
              ),
            ] else
              RdButton.primary(
                loading: _busy,
                onPressed: _busy ? null : _pick,
                icon: LucideIcons.fileUp,
                label: copy.pickFile,
              ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ReadendarTokens.sp3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: context.colors.accentSoftBg,
            child: Text(
              '$n',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: context.colors.accentSoftFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: ReadendarTokens.sp4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: ReadendarTokens.sp1),
              child: Text(
                text,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
