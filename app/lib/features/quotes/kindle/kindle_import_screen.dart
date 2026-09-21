// Kindle highlights import: pick `My Clippings.txt` → parse client-side
// (kindle_clippings.dart) → ASSIGN each source book to a library book → REVIEW
// quotes → batched quote create. User-owned clippings file only.

import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/kindle/kindle_clippings.dart';
import 'package:readendar/features/quotes/kindle/kindle_match.dart';
import 'package:readendar/features/quotes/quote_book_picker.dart';
import 'package:readendar/features/widget/widget_sync.dart';

const int _maxFileBytes = 8 * 1024 * 1024; // clippings files are small text
const _batchChunk = 100;

/// Width of the leading lane in the review list — matches `BookCoverSize.xs`
/// (32) so the per-quote checkboxes line up under the book covers and the quote
/// text lines up with the group-header title.
const _reviewLeadWidth = 32.0;

enum _Stage { pick, assign, review, importing, done, error }

class KindleImportScreen extends ConsumerStatefulWidget {
  const KindleImportScreen({
    super.key,
    this.initialResult,
    this.lockedBookId,
  });

  /// When supplied (tests), skip the file picker and open on assign.
  final KindleParseResult? initialResult;

  /// When set (book-annotations entry), every clipping is assigned to this
  /// personal library book and the multi-book assign step is skipped.
  final String? lockedBookId;

  @override
  ConsumerState<KindleImportScreen> createState() => _KindleImportScreenState();
}

class _KindleImportScreenState extends ConsumerState<KindleImportScreen> {
  _Stage _stage = _Stage.pick;
  bool _busy = false;
  late KindleParseResult _parsed;
  List<KindleBookGroup> _groups = const [];

  /// Groups the user unchecked in the assign step (won't be imported).
  final Set<KindleBookGroup> _excluded = {};

  /// Individual quotes the user unchecked in the review step. Tracked by
  /// identity (KindleClipping has no id and instances are unique per parse).
  final Set<KindleClipping> _excludedClippings = {};

  int _sent = 0;
  int _total = 0;
  int _created = 0;
  int _failed = 0;

  /// True once [_groups] has been matched against a *loaded* library. Matching
  /// is deferred to build so a cold/slow `booksProvider` can't silently produce
  /// an all-unmatched list.
  bool _groupsBuilt = false;

  @override
  void initState() {
    super.initState();
    // Notebook-scrape path: the clippings are already parsed — open on the
    // assign step; the actual match runs in build once the library is loaded.
    final init = widget.initialResult;
    if (init != null && !init.isEmpty) {
      _parsed = init;
      _stage = _Stage.assign;
    }
  }

  Future<void> _pick() async {
    final l = AppL10n.of(context);
    setState(() => _busy = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Kindle clippings', extensions: ['txt']),
        ],
      );
      if (file == null) return; // cancelled
      if (await file.length() > _maxFileBytes) {
        _snack(l.kindleImportInvalidFile);
        return;
      }
      final bytes = await file.readAsBytes();
      final String content;
      try {
        content = utf8.decode(bytes, allowMalformed: true);
      } on FormatException {
        _snack(l.kindleImportInvalidFile);
        return;
      }
      final parsed = parseKindleClippings(content);
      if (parsed.isEmpty) {
        _snack(l.kindleImportNoHighlights);
        return;
      }
      setState(() {
        _parsed = parsed;
        _groupsBuilt = false; // matched in build once the library is loaded
        _stage = _Stage.assign;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Matched, included groups — the ones that contribute quotes downstream.
  Iterable<KindleBookGroup> get _includedGroups =>
      _groups.where((g) => g.match != null && !_excluded.contains(g));

  /// Quotes selected for import: included groups minus per-quote deselections.
  int get _selectedQuoteCount => _includedGroups.fold(
    0,
    (acc, g) => acc + g.clippings.where(_isSelected).length,
  );

  bool _isSelected(KindleClipping c) => !_excludedClippings.contains(c);

  bool get _allSelected {
    for (final g in _includedGroups) {
      for (final c in g.clippings) {
        if (_excludedClippings.contains(c)) return false;
      }
    }
    return true;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        for (final g in _includedGroups) {
          _excludedClippings.addAll(g.clippings);
        }
      } else {
        _excludedClippings.clear();
      }
    });
  }

  Future<void> _assignBook(KindleBookGroup g) async {
    final picked = await pickQuoteBook(
      context,
      seedTitle: g.sourceTitle,
      seedAuthor: g.sourceAuthor,
    );
    if (picked != null && mounted) {
      setState(() {
        g
          ..match = picked
          ..suggested = false;
        _excluded.remove(g);
      });
    }
  }

  Future<void> _start() async {
    final items = <QuoteBatchItem>[];
    for (final g in _includedGroups) {
      final book = g.match!;
      for (final c in g.clippings) {
        if (!_isSelected(c)) continue;
        // Pages beyond the book's known pageCount would be rejected row-by-row
        // (page_out_of_range); drop the anchor instead of losing the quote.
        final page =
            (c.page != null &&
                book.pageCount != null &&
                c.page! > book.pageCount!)
            ? null
            : c.page;
        items.add(
          QuoteBatchItem(
            bookId: book.id,
            text: c.text,
            page: page,
            category: c.category,
          ),
        );
      }
    }
    if (items.isEmpty) return;
    setState(() {
      _stage = _Stage.importing;
      _total = items.length;
      _sent = 0;
      _created = 0;
      _failed = 0;
    });
    final repo = ref.read(quoteRepoProvider);
    for (var i = 0; i < items.length; i += _batchChunk) {
      final chunk = items.sublist(
        i,
        i + _batchChunk > items.length ? items.length : i + _batchChunk,
      );
      // The batch insert is atomic (retry-safe: no partial duplicates), so a
      // whole-chunk failure is likely a transient blip — retry the chunk once
      // before writing off its (valid) rows, rather than silently dropping up
      // to 100 good quotes.
      var r = await repo.createBatch(chunk);
      if (!mounted) return;
      if (r.failure != null) {
        r = await repo.createBatch(chunk);
        if (!mounted) return;
      }
      r.fold(
        (rows) {
          _created += rows.where((e) => e.created).length;
          _failed += rows.where((e) => !e.created).length;
        },
        // Still failing after a retry: count the chunk as failed but keep going
        // so a persistent blip doesn't abort the whole import.
        (_) => _failed += chunk.length,
      );
      setState(() => _sent += chunk.length);
    }
    // Refresh the in-app list + push the fresh snapshot to the quotes widget.
    await ref.read(quotesControllerProvider.notifier).refresh();
    if (!mounted) return;
    unawaited(syncQuotesWidget(ref).catchError((Object _) {}));
    // Nothing landed at all → a hard failure; let the user retry. Any success
    // (even partial) shows the done screen with the failed count.
    setState(
      () =>
          _stage = (_created == 0 && _failed > 0) ? _Stage.error : _Stage.done,
    );
  }

  /// Returns to Quotes. A single pop is enough from every entry (library,
  /// annotations, or a test that skips the picker).
  void _goToQuotes() => Navigator.of(context).pop();

  /// The stage the OS/AppBar back button should step back to, or null when back
  /// should leave the import screen entirely. Keeps the hardware back button in
  /// sync with the flow: from `review` it returns to `assign`, not out to the
  /// start of the import.
  _Stage? get _previousStage => switch (_stage) {
    _Stage.review => _Stage.assign,
    // File picker can step back to pick. Tests that skip the picker via
    // [initialResult] have no pick stage, so back exits.
    _Stage.assign => widget.initialResult == null ? _Stage.pick : null,
    _Stage.error => _Stage.review,
    // `pick`/`done` exit; `importing` is blocked (canPop false, no fallback).
    _Stage.pick || _Stage.importing || _Stage.done => null,
  };

  void _snack(String msg) {
    if (!mounted) return;
    showRdToast(context, message: msg);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final prev = _previousStage;
    return PopScope(
      // Let the route pop only when the current stage has no earlier stage to
      // fall back to (and never mid-import); otherwise step back a stage.
      canPop: prev == null && _stage != _Stage.importing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || prev == null) return;
        setState(() => _stage = prev);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.kindleImportTitle)),
        body: switch (_stage) {
          _Stage.pick => _buildPick(l),
          _Stage.assign => _buildAssign(l),
          _Stage.review => _buildReview(l),
          _Stage.importing => _buildProgress(l),
          _Stage.done => _buildDone(l),
          _Stage.error => _buildError(l),
        },
      ),
    );
  }

  Widget _buildPick(AppL10n l) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: EmptyState(
        icon: LucideIcons.bookUp,
        message: l.kindleImportIntro,
        action: RdButton.primary(
          onPressed: _busy ? null : _pick,
          loading: _busy,
          icon: LucideIcons.fileUp,
          label: l.kindleImportPick,
        ),
      ),
    );
  }

  // ── Assign step (book matching) ────────────────────────────────────────────

  Widget _buildAssign(AppL10n l) {
    final c = context.colors;
    final parsed = _parsed;
    // Defer the library match until booksProvider has resolved, so a cold load
    // doesn't mark every book unmatched. Once built, the user's assignments and
    // exclusions own the list — we never re-match over their edits.
    if (!_groupsBuilt) {
      final booksAsync = ref.watch(booksProvider);
      if (booksAsync.isLoading && !booksAsync.hasValue) {
        return _CenteredPane(
          children: [RdProgress.centered()],
        );
      }
      final books = (booksAsync.value ?? const <Book>[]).toList();
      _groups = matchKindleClippings(parsed.clippings, books);
      _groupsBuilt = true;
      final lockedId = widget.lockedBookId;
      if (lockedId != null) {
        final locked = books.where((b) => b.id == lockedId).firstOrNull;
        if (locked != null) {
          for (final g in _groups) {
            g
              ..match = locked
              ..suggested = false;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _stage == _Stage.assign) {
              setState(() => _stage = _Stage.review);
            }
          });
        }
      }
    }
    final skipped = parsed.skippedNotes + parsed.skippedBookmarks;
    final canContinue = _includedGroups.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _groups.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    [
                      l.kindleImportGroups(_groups.length),
                      if (skipped > 0) l.kindleImportSkipped(skipped),
                      if (parsed.duplicatesDropped > 0)
                        l.kindleImportDuplicates(parsed.duplicatesDropped),
                    ].join(' · '),
                    style: TextStyle(color: c.fg3, fontSize: 12),
                  ),
                );
              }
              final g = _groups[i - 1];
              return _AssignTile(
                group: g,
                included: g.match != null && !_excluded.contains(g),
                onToggle: g.match == null
                    ? null
                    : (v) => setState(() {
                        if (v) {
                          _excluded.remove(g);
                        } else {
                          _excluded.add(g);
                        }
                      }),
                onTapBook: () => _assignBook(g),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RdButton.primary(
              onPressed: canContinue
                  ? () => setState(() => _stage = _Stage.review)
                  : null,
              icon: LucideIcons.arrowRight,
              label: l.kindleImportContinue,
              expand: true,
            ),
          ),
        ),
      ],
    );
  }

  // ── Review step (per-quote selection) ──────────────────────────────────────

  Widget _buildReview(AppL10n l) {
    final c = context.colors;
    // Flatten included groups into header + quote rows, grouped by book.
    final rows = <Object>[];
    for (final g in _includedGroups) {
      rows
        ..add(g)
        ..addAll(g.clippings);
    }
    final selected = _selectedQuoteCount;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.kindleImportReviewTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                l.kindleImportReviewSubtitle,
                style: TextStyle(color: c.fg3, fontSize: 12),
              ),
              const SizedBox(height: 4),
              // Full-width "select all" row (compact — no ListTile min-height
              // padding): checkbox in the same lane as the covers/quote
              // checkboxes, checked when every quote is selected, indeterminate
              // when only some are.
              InkWell(
                onTap: _toggleSelectAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: _reviewLeadWidth,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Checkbox(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            tristate: true,
                            value: _allSelected
                                ? true
                                : (selected > 0 ? null : false),
                            onChanged: (_) => _toggleSelectAll(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(l.kindleImportSelectAll),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              if (row is KindleBookGroup) {
                return _ReviewGroupHeader(book: row.match!);
              }
              final clip = row as KindleClipping;
              return _ReviewQuoteTile(
                clipping: clip,
                selected: _isSelected(clip),
                onToggle: (v) => setState(() {
                  if (v) {
                    _excludedClippings.remove(clip);
                  } else {
                    _excludedClippings.add(clip);
                  }
                }),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RdButton.primary(
              onPressed: selected == 0 ? null : _start,
              icon: LucideIcons.bookUp,
              label: l.kindleImportStart(selected),
              expand: true,
            ),
          ),
        ),
      ],
    );
  }

  // ── Importing / done / error (centered) ────────────────────────────────────

  Widget _buildProgress(AppL10n l) {
    final pct = _total == 0 ? 0.0 : _sent / _total;
    return _CenteredPane(
      children: [
        Text(
          l.kindleImportProgress,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
          child: LinearProgressIndicator(value: pct, minHeight: 6),
        ),
        const SizedBox(height: 8),
        Text('$_sent / $_total', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildDone(AppL10n l) {
    final c = context.colors;
    return _CenteredPane(
      children: [
        Icon(LucideIcons.circleCheck, size: 48, color: c.success),
        const SizedBox(height: 16),
        Text(
          l.kindleImportDone(_created),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_failed > 0) ...[
          const SizedBox(height: 8),
          Text(
            l.kindleImportFailed(_failed),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.danger),
          ),
        ],
        const SizedBox(height: 24),
        RdButton.primary(
          onPressed: _goToQuotes,
          icon: LucideIcons.quote,
          label: l.kindleImportGoToQuotes,
        ),
        // Some rows failed but others landed — offer a retry too. The batch
        // insert is atomic/idempotent (no partial duplicates), so re-posting the
        // whole selection safely re-attempts only the rows that didn't stick.
        if (_failed > 0) ...[
          const SizedBox(height: 8),
          RdButton.plain(
            onPressed: _start,
            icon: LucideIcons.refreshCw,
            label: l.kindleImportRetry,
          ),
        ],
      ],
    );
  }

  Widget _buildError(AppL10n l) {
    final c = context.colors;
    return _CenteredPane(
      children: [
        Icon(LucideIcons.alertTriangle, size: 48, color: c.danger),
        const SizedBox(height: 16),
        Text(
          l.kindleImportErrorTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        RdButton.primary(
          onPressed: _start,
          icon: LucideIcons.refreshCw,
          label: l.kindleImportRetry,
        ),
        const SizedBox(height: 8),
        RdButton.plain(
          onPressed: _goToQuotes,
          label: l.kindleImportGoToQuotes,
        ),
      ],
    );
  }
}

/// Vertically + horizontally centered pane with a comfortable max width, so the
/// import progress / success / error content sits in the middle of the screen
/// instead of hugging the top.
class _CenteredPane extends StatelessWidget {
  const _CenteredPane({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// One source book in the assign step: a checkbox (include in import), the
/// matched cover or an unmatched marker, and the title/match subtitle. Tapping
/// the body opens the picker to (re)assign or create the target book.
class _AssignTile extends StatelessWidget {
  const _AssignTile({
    required this.group,
    required this.included,
    required this.onToggle,
    required this.onTapBook,
  });

  final KindleBookGroup group;
  final bool included;

  /// Null when the group is unmatched (checkbox disabled until a book is set).
  final ValueChanged<bool>? onToggle;
  final VoidCallback onTapBook;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final g = group;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RdCheckbox(
              value: included,
              onChanged: onToggle == null ? null : (v) => onToggle!(v ?? false),
            ),
            if (g.match != null)
              BookCover(
                title: g.match!.title,
                coverUrl: g.match!.coverUrl,
                size: BookCoverSize.xs,
              )
            else
              Icon(LucideIcons.circleHelp, color: c.warning),
          ],
        ),
        title: Text(
          g.sourceTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: included ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          [
            l.quotesCount(g.clippings.length),
            if (g.match == null)
              l.kindleImportUnmatched
            else if (g.suggested)
              '${l.kindleImportSuggested}: ${g.match!.title}'
            else
              g.match!.title,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: g.match == null ? c.warning : c.fg3,
          ),
        ),
        trailing: Icon(LucideIcons.pencil, size: 16, color: c.fg3),
        onTap: onTapBook,
      ),
    );
  }
}

/// Book header in the review list (cover + title), mirroring the "My quotes"
/// grouping so the review reads like the destination.
class _ReviewGroupHeader extends StatelessWidget {
  const _ReviewGroupHeader({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
      child: Row(
        children: [
          BookCover(
            title: book.title,
            coverUrl: book.coverUrl,
            size: BookCoverSize.xs,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// One quote in the review list: a checkbox, the passage (serif italic, like
/// the QuoteCard) and the page anchor.
class _ReviewQuoteTile extends StatelessWidget {
  const _ReviewQuoteTile({
    required this.clipping,
    required this.selected,
    required this.onToggle,
  });

  final KindleClipping clipping;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => onToggle(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Checkbox in the same lane (and left edge) as the book covers,
            // centered vertically with the quote text.
            SizedBox(
              width: _reviewLeadWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: RdCheckbox(
                  value: selected,
                  onChanged: (v) => onToggle(v ?? false),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '«${clipping.text}»',
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ReadendarTokens.fontDisplay,
                      fontStyle: FontStyle.italic,
                      fontSize: 15,
                      height: 1.3,
                      color: selected ? c.fg1 : c.fgFaint,
                    ),
                  ),
                  if (clipping.page != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.bookOpen, size: 12, color: c.fg3),
                        const SizedBox(width: 3),
                        Text(
                          '${clipping.page}',
                          style: TextStyle(fontSize: 12, color: c.fg3),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
