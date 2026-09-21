import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_row.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/data/catalog/catalog_enrich.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/import_models.dart';
import 'package:readendar/features/import/import_progress_screen.dart';

/// Above this many books, a search box appears above the list so the user can
/// find a specific title in a large import.
const _searchThreshold = 10;

/// Shows what was found in the file and lets the user choose exactly which books
/// to import (Q3). The shelf summary at the top and the per-book list below stay
/// in sync: ticking a shelf toggles all its books, ticking books updates the
/// shelf's (tri-state) checkbox and the import button's count.
///
/// Books already in the user's library (matched by ISBN) are flagged and
/// unticked by default — the user decides here whether to import a duplicate.
/// Persist trusts this selection and does not dedupe against the library.
class ImportConfirmScreen extends ConsumerStatefulWidget {
  const ImportConfirmScreen({required this.parsed, super.key});

  final ImportParseResult parsed;

  @override
  ConsumerState<ImportConfirmScreen> createState() =>
      _ImportConfirmScreenState();
}

class _ImportConfirmScreenState extends ConsumerState<ImportConfirmScreen> {
  /// Per-book import selection, keyed by index into `widget.parsed.books`.
  late final Map<int, bool> _selected;

  /// Per-book "already in your library" flag. Populated asynchronously once the
  /// existing-ISBN set resolves; until then every book reads as not-a-duplicate.
  final Map<int, bool> _isDuplicate = {};

  /// Parsed rows projected onto [Book] once, so the list reuses the library's
  /// row widget without rebuilding the model on every scroll frame.
  late final List<Book> _asBooks;

  late final TextEditingController _searchController;
  String _query = '';

  List<ImportedBook> get _books => widget.parsed.books;

  @override
  void initState() {
    super.initState();
    _selected = {for (var i = 0; i < _books.length; i++) i: true};
    _asBooks = [for (final b in _books) _toBook(b)];
    _searchController = TextEditingController();
    _loadDuplicates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Projects a parsed import row onto the [Book] model so it renders with the
  /// exact same row widget the library uses (cover + title + author + status).
  /// Preview covers use catalog jackets (Open Library cover-id or Casa del Libro).
  Book _toBook(ImportedBook b) => Book(
    id: '',
    ownerType: OwnerType.user,
    ownerId: '',
    title: b.title,
    authors: b.authors,
    status: b.status,
    coverUrl: _previewCoverUrl(b.isbn),
    isbn13: b.isbn.length == 13 ? b.isbn : '',
    isbn10: b.isbn.length == 10 ? b.isbn : '',
    rating: b.rating,
    notes: b.notes,
    reviewMarkdown: b.reviewMarkdown,
  );

  String _previewCoverUrl(String isbn) {
    if (isbn.trim().isEmpty) return '';
    return openLibraryCoverUrl(isbn);
  }

  /// Loads the library's existing ISBNs (cheap — just the ISBN set, see
  /// `existingIsbnsProvider`) and unticks any book we already own. A failure
  /// (offline / not loaded) is non-fatal: nothing gets flagged and everything
  /// stays selected, so the import still works.
  Future<void> _loadDuplicates() async {
    Set<String> existing;
    try {
      existing = await ref.read(existingIsbnsProvider.future);
    } on Object {
      existing = const {};
    }
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _books.length; i++) {
        final b = _books[i];
        final dup = b.isbnKey.isNotEmpty && existing.contains(b.isbnKey);
        _isDuplicate[i] = dup;
        if (dup) _selected[i] = false;
      }
    });
  }

  List<int> _indicesForStatus(String status) => [
    for (var i = 0; i < _books.length; i++)
      if (_books[i].status == status) i,
  ];

  /// Indices of the rows the list should show, narrowed by the search query.
  List<int> get _visibleIndices {
    if (_query.isEmpty) {
      return [for (var i = 0; i < _books.length; i++) i];
    }
    return [
      for (var i = 0; i < _books.length; i++)
        if (_matchesQuery(_books[i])) i,
    ];
  }

  bool _matchesQuery(ImportedBook b) {
    if (b.title.toLowerCase().contains(_query)) return true;
    return b.authors.any((a) => a.toLowerCase().contains(_query));
  }

  List<ImportedBook> get _selectedBooks => [
    for (var i = 0; i < _books.length; i++)
      if (_selected[i]!) _books[i],
  ];

  /// Tri-state value for a shelf: all books on → true, none → false, some → null.
  bool? _shelfValue(List<int> indices) {
    if (indices.isEmpty) return false;
    final on = indices.where((i) => _selected[i]!).length;
    if (on == 0) return false;
    if (on == indices.length) return true;
    return null;
  }

  void _toggleShelf(List<int> indices) {
    final allOn = indices.isNotEmpty && indices.every((i) => _selected[i]!);
    setState(() {
      for (final i in indices) {
        _selected[i] = !allOn;
      }
    });
  }

  void _toggleBook(int index, bool on) => setState(() => _selected[index] = on);

  void _start() {
    final books = _selectedBooks;
    Navigator.of(context).pushReplacement(
      rdPageRoute<void>(
        context,
        builder: (_) => ImportProgressScreen(books: books),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final p = widget.parsed;
    final count = _selectedBooks.length;
    final visible = _visibleIndices;
    final showSearch = _books.length > _searchThreshold;

    return Scaffold(
      appBar: AppBar(title: Text(l.importConfirmTitle)),
      body: SafeArea(
        top: false,
        // The summary can grow beyond a phone viewport when all shelves and
        // warnings are present. Keep it in the same scrollable surface as the
        // book list so the import action never becomes unreachable.
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ReadendarTokens.sp5,
                  ReadendarTokens.sp5,
                  ReadendarTokens.sp5,
                  ReadendarTokens.sp4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.importFound(p.books.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: ReadendarTokens.sp4),
                    RdCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: _shelfTiles(l)),
                    ),
                    const SizedBox(height: ReadendarTokens.sp4),
                    // Set expectations: tell the user what does and doesn't come over
                    // from the source so a "flat" library isn't a surprise (P2-E).
                    _Note(text: l.importMetadataNote),
                    if (p.ratingsRounded > 0)
                      _Note(
                        text: l.importRoundedRatingsNote(p.ratingsRounded),
                      ),
                    if (p.duplicatesDropped > 0)
                      _Note(text: l.importDuplicatesNote(p.duplicatesDropped)),
                    if (p.skippedNoTitle > 0)
                      _Note(text: l.importSkippedNote(p.skippedNoTitle)),
                    if (p.skippedNoAuthor > 0)
                      _Note(
                        text: l.importSkippedAuthorNote(p.skippedNoAuthor),
                      ),
                    if (p.unmatchedNoteSheets > 0)
                      _Note(
                        text: l.importUnmatchedNotes(p.unmatchedNoteSheets),
                      ),
                    if (p.truncated)
                      _Note(text: l.importTruncatedNote(maxImportBooks)),
                    const SizedBox(height: ReadendarTokens.sp5),
                    SizedBox(
                      width: double.infinity,
                      child: RdButton.primary(
                        onPressed: count == 0 ? null : _start,
                        icon: LucideIcons.bookUp,
                        label: l.importStart(count),
                      ),
                    ),
                    if (showSearch) ...[
                      const SizedBox(height: ReadendarTokens.sp4),
                      RdSearchField(
                        controller: _searchController,
                        hintText: l.searchHint,
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                        onClear: () => setState(() => _query = ''),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            // ── Scrollable, virtualized per-book list ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                ReadendarTokens.sp5,
                ReadendarTokens.sp4,
                ReadendarTokens.sp5,
                ReadendarTokens.sp4,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, position) {
                    final index = visible[position];
                    final selected = _selected[index]!;
                    final isDuplicate = _isDuplicate[index] ?? false;
                    return BookRow(
                      key: ValueKey(index),
                      book: _asBooks[index],
                      onTap: () => _toggleBook(index, !selected),
                      statusAction: isDuplicate
                          ? _DuplicateChip(
                              label: l.importDuplicateInLibrary,
                            )
                          : null,
                      trailing: Checkbox(
                        value: selected,
                        semanticLabel: _asBooks[index].title,
                        onChanged: (v) => _toggleBook(index, v ?? false),
                      ),
                    );
                  },
                  childCount: visible.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the shelf summary rows, skipping shelves with no books and inserting
  /// dividers only between the rows that are actually shown.
  List<Widget> _shelfTiles(AppL10n l) {
    final specs = <(IconData, String)>[
      (LucideIcons.bookOpenCheck, BookStatus.read),
      (LucideIcons.bookOpen, BookStatus.reading),
      (LucideIcons.bookMarked, BookStatus.pending),
      (LucideIcons.heart, BookStatus.wanted),
      (LucideIcons.bookX, BookStatus.abandoned),
    ];
    final tiles = <Widget>[];
    for (final (icon, status) in specs) {
      final indices = _indicesForStatus(status);
      if (indices.isEmpty) continue;
      if (tiles.isNotEmpty) tiles.add(const Divider(height: 1));
      final selectedCount = indices.where((i) => _selected[i]!).length;
      tiles.add(
        _ShelfTile(
          icon: icon,
          label: bookStatusLabel(l, status),
          count: indices.length,
          selectedCount: selectedCount,
          value: _shelfValue(indices),
          onChanged: () => _toggleShelf(indices),
        ),
      );
    }
    return tiles;
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.selectedCount,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int count;
  final int selectedCount;
  final bool? value; // null = some-but-not-all selected (tri-state)
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      tristate: true,
      onChanged: (_) => onChanged(),
      controlAffinity: ListTileControlAffinity.trailing,
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ReadendarTokens.sp4,
      ),
      secondary: Icon(icon, color: context.colors.accent),
      title: Row(
        children: [
          Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: ReadendarTokens.sp2),
          Text(
            '$selectedCount/$count',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.fg2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "already in your library" badge shown on a row's status line.
class _DuplicateChip extends StatelessWidget {
  const _DuplicateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.dangerSoftBg,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.libraryBig, size: 11, color: c.dangerSoftFg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: c.dangerSoftFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ReadendarTokens.sp2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: context.colors.fg2),
          const SizedBox(width: ReadendarTokens.sp2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.fg2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
