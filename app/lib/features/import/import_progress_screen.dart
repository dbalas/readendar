import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/quote_spoiler_refresh.dart';
import 'package:readendar/features/import/catalog_import.dart';
import 'package:readendar/features/import/import_complete_screen.dart';
import 'package:readendar/features/import/import_models.dart';
import 'package:readendar/features/widget/widget_sync.dart';

export 'package:readendar/features/import/catalog_import.dart'
    show importMaxInFlight, importRetryBackoff, importRowRetries;

/// A book that was created without a cover — offered for manual cover fixing.
class ImportedCoverBook {
  const ImportedCoverBook({
    required this.bookId,
    required this.title,
    required this.authors,
  });
  final String bookId;
  final String title;
  final List<String> authors;
}

/// Final tallies handed to the completion screen.
class ImportSummary {
  const ImportSummary({
    required this.added,
    required this.failed,
    required this.cancelled,
    required this.noCoverBooks,
    required this.failedBooks,
  });

  final int added;
  final int failed;
  final bool cancelled;
  final List<ImportedCoverBook> noCoverBooks;

  /// The actual books that failed, so the completion screen can offer a retry of
  /// just those rather than forcing a re-import of the whole file (P1-A).
  final List<ImportedBook> failedBooks;

  int get noCover => noCoverBooks.length;
}

/// Runs catalog enrich + local create, driving a live progress bar. Rows drain
/// through a small worker pool. A transport failure is retried with backoff; if
/// it still fails, the book is remembered so the user can retry it. Cancelling
/// stops after in-flight rows; everything already imported stays.
class ImportProgressScreen extends ConsumerStatefulWidget {
  const ImportProgressScreen({
    required this.books,
    this.dedupAgainstLibrary = false,
    super.key,
  });

  final List<ImportedBook> books;

  /// When true, books whose ISBN is already in the user's library are dropped
  /// before importing. Used only by the paths that DON'T go through the confirm
  /// screen's dedup — the deep-link auto-import and the failed-books retry — so
  /// re-opening the same file, or retrying a row that secretly committed
  /// before the response was lost, can't create duplicates. The confirm path
  /// leaves this false: there the user explicitly chose the exact set and may
  /// have re-ticked a known duplicate on purpose. ISBN-less books can't be
  /// matched and are always imported.
  final bool dedupAgainstLibrary;

  @override
  ConsumerState<ImportProgressScreen> createState() =>
      _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen> {
  int _processed = 0;
  int _added = 0;
  int _failed = 0;
  bool _cancelled = false;
  final List<ImportedCoverBook> _noCover = [];
  final List<ImportedBook> _failedBooks = [];
  bool _spoilerEligibilityChanged = false;

  /// Progress denominator. Starts at the input size and shrinks if dedup drops
  /// books already in the library, so the bar still reaches 100%.
  late int _total = widget.books.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    var books = widget.books;

    // For the no-confirm paths (auto-import, retry), drop books whose ISBN is
    // already in the library before importing. This is the only dedup we do
    // at persist time: it closes the duplicate window on retry (a row that
    // committed but lost its response now shows up here) and on re-opening
    // the same file. existingIsbnsProvider reflects the freshly invalidated
    // library, so retried books that actually landed are skipped.
    if (widget.dedupAgainstLibrary) {
      Set<String> existing;
      try {
        existing = await ref.read(existingIsbnsProvider.future);
      } on Object {
        existing = const {};
      }
      if (existing.isNotEmpty) {
        books = [
          for (final b in books)
            if (b.isbnKey.isEmpty || !existing.contains(b.isbnKey)) b,
        ];
      }
    }
    if (mounted && books.length != _total) {
      setState(() => _total = books.length);
    }

    final importer = ref.read(catalogImportProvider);
    var next = 0;
    Future<void> worker() async {
      while (!_cancelled) {
        final idx = next++;
        if (idx >= books.length) return;
        final book = books[idx];
        final row = await importer.importOneWithRetry(book, index: idx);
        if (row.outcome == ImportOutcome.created) {
          _added++;
          if (book.status == BookStatus.read && book.isbnKey.isNotEmpty) {
            _spoilerEligibilityChanged = true;
          }
          if (!row.hadCover) {
            _noCover.add(
              ImportedCoverBook(
                bookId: row.bookId,
                title: book.title,
                authors: book.authors,
              ),
            );
          }
        } else {
          _failed++;
          _failedBooks.add(book);
        }
        if (mounted) setState(() => _processed++);
      }
    }

    final workers = math.min(importMaxInFlight, books.length);
    if (workers > 0) {
      await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (!mounted) return;
    ref.invalidate(booksProvider);
    ref.invalidatePersonalStats();
    if (_spoilerEligibilityChanged) {
      notifyQuoteSpoilerEligibilityChanged(ref);
    }
    if (_added > 0) {
      unawaited(syncWidget(ref).catchError((Object _) => false));
      unawaited(ref.read(analyticsProvider).logLibraryImported(count: _added));
    }
    unawaited(
      Navigator.of(context).pushReplacement(
        rdPageRoute<void>(
          context,
          builder: (_) => ImportCompleteScreen(
            summary: ImportSummary(
              added: _added,
              failed: _failed,
              cancelled: _cancelled,
              noCoverBooks: _noCover,
              failedBooks: _failedBooks,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final total = _total;
    final fraction = total == 0 ? 0.0 : _processed / total;
    final label = l.importProgressLabel(_processed, total);

    return PopScope(
      canPop: false, // back button cancels instead of abandoning mid-run
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _cancelled = true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.importProgressTitle),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(ReadendarTokens.sp6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.bookUp,
                  size: 40,
                  color: context.colors.accent,
                ),
                const SizedBox(height: ReadendarTokens.sp5),
                Semantics(
                  liveRegion: true,
                  label: label,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: ReadendarTokens.sp4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
                  child: _processed == 0
                      ? LinearProgressIndicator(
                          minHeight: 8,
                          backgroundColor: context.colors.accentSoftBg,
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: fraction),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          builder: (_, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 8,
                            backgroundColor: context.colors.accentSoftBg,
                          ),
                        ),
                ),
                const SizedBox(height: ReadendarTokens.sp3),
                Text(
                  _cancelled ? l.importCancelling : l.importProgressSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.fg2,
                  ),
                ),
                const SizedBox(height: ReadendarTokens.sp6),
                RdButton.plain(
                  onPressed: _cancelled
                      ? null
                      : () => setState(() => _cancelled = true),
                  icon: LucideIcons.x,
                  label: l.importCancel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
