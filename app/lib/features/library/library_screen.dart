import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/rd_reorderable_row.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/book_status_groups.dart';
import 'package:readendar/core/widgets/skeleton.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/filters/filter_icon_button.dart';
import 'package:readendar/features/filters/filters_sheet.dart';
import 'package:readendar/features/filters/filters_state.dart';
import 'package:readendar/features/import/import_sources_screen.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/library/library_empty_art.dart';
import 'package:readendar/features/library/library_reorder.dart';
import 'package:readendar/features/library/library_status_bar.dart';
import 'package:readendar/features/library/owned_book_row.dart';
import 'package:readendar/features/roulette/book_roulette_screen.dart';
import 'package:readendar/features/search/isbn_scanner_screen.dart';
import 'package:readendar/features/search/search_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<String>? _orderedIds;
  final Map<String, int> _sectionWindows = {};
  final Set<String> _collapsedSections = {};

  List<Book> _applySavedOrder(List<Book> serverBooks) {
    final serverIds = serverBooks.map((b) => b.id).toSet();
    if (_orderedIds == null ||
        _orderedIds!.toSet().difference(serverIds).isNotEmpty ||
        serverIds.difference(_orderedIds!.toSet()).isNotEmpty) {
      _orderedIds = serverBooks.map((b) => b.id).toList();
    }
    final byId = {for (final book in serverBooks) book.id: book};
    return [
      for (final id in _orderedIds!) ?byId[id],
    ];
  }

  Future<void> _reorderVisible(
    List<Object> rows,
    List<Book> allBooks,
    int oldIndex,
    int newIndex,
  ) async {
    // Index 0 is the search panel. Headers have no drag listener, but remain
    // valid drop boundaries while book rows themselves are the drag targets.
    oldIndex -= 1;
    newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= rows.length) return;
    newIndex = newIndex.clamp(0, rows.length);
    final reorderedRows = List<Object>.of(rows);
    final moved = reorderedRows.removeAt(oldIndex);
    if (moved is! Book) return;
    reorderedRows.insert(newIndex, moved);

    final visibleIds = reorderedRows
        .whereType<Book>()
        .where((book) => book.status == moved.status)
        .map((book) => book.id)
        .toList();
    final completeOrder = spliceStatusReorder(
      allBooks: allBooks,
      status: moved.status,
      visibleIdsInNewOrder: visibleIds,
    );
    setState(() => _orderedIds = completeOrder);

    final result = await ref.read(bookRepoProvider).reorder(completeOrder);
    if (!result.isOk && mounted) {
      _orderedIds = null;
      ref.invalidate(booksProvider);
    }
  }

  Future<void> _openLibraryFilters() async {
    await showFiltersSheet(context, booksOnly: true);
  }

  Future<void> _openBookDiscoveryMenu() async {
    final isbn = await Navigator.of(context).push<String>(
      rdPageRoute<String>(context, builder: (_) => const IsbnScannerScreen()),
    );
    if (!mounted || isbn == null) return;
    await Navigator.of(context).push<void>(
      rdPageRoute<void>(
        context,
        builder: (_) => SearchScreen(initialQuery: isbn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final books = ref.watch(visibleBooksProvider);
    final filters = ref.watch(filtersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navLibrary),
        actions: [
          FilterIconButton(
            active: !filters.isEmpty,
            booksOnly: true,
            onPressed: () => _openLibraryFilters(),
          ),
          RdIconButton(
            icon: LucideIcons.galleryHorizontal,
            color: context.colors.accent,
            tooltip: l.celebrationRoulette,
            onPressed: () => openBookRoulette(context),
          ),
          RdIconButton(
            icon: LucideIcons.scanBarcode,
            tooltip: l.scanIsbnTooltip,
            onPressed: _openBookDiscoveryMenu,
          ),
          RdIconButton(
            icon: LucideIcons.plus,
            tooltip: l.quickAddBook,
            onPressed: () => Navigator.of(context).push(
              rdPageRoute<void>(context, builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      body: _ownedBooksBody(context, l, books, filters),
    );
  }

  Widget _ownedBooksBody(
    BuildContext context,
    AppL10n l,
    AsyncValue<List<Book>> books,
    FiltersState filters,
  ) {
    return RdRefresh(
      onRefresh: () async => ref.invalidate(booksProvider),
      child: books.when(
        skipError: true,
        loading: () => const BookListSkeleton(),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(booksProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              illustration: const LibraryEmptyArt(),
              message: l.libraryEmptyMessage,
              action: RdButton.primary(
                onPressed: () => _showAddBookSheet(context, ref),
                label: l.actionAddBook,
              ),
              secondaryAction: RdButton.plain(
                onPressed: () => Navigator.of(context).push(
                  rdPageRoute<void>(
                    context,
                    builder: (_) => const ImportSourcesScreen(),
                  ),
                ),
                icon: LucideIcons.bookUp,
                label: l.libraryEmptyImport,
              ),
            );
          }
          final ordered = _applySavedOrder(list);
          final filtered = ordered
              .where((b) => bookMatchesFilters(b, filters))
              .toList(growable: false);
          final showAll = !filters.isEmpty;
          final groups = groupByBookStatus(
            filtered,
            statusOf: (book) => book.status,
          );
          // Flat row model so the list builds lazily: a big imported library
          // must not materialize every BookRow up front. Each entry is a
          // section header, a book, or a per-section load-more control.
          final rows = <Object>[
            for (final group in groups) ...[
              _StatusSection(group.status, group.total),
              if (isBookStatusSectionExpanded(
                _collapsedSections,
                group.status,
              )) ...[
                ...showAll
                    ? group.items
                    : group.items.take(
                        _sectionWindows[group.status] ?? kBookSectionWindow,
                      ),
                if (!showAll &&
                    group.total >
                        (_sectionWindows[group.status] ?? kBookSectionWindow))
                  _StatusLoadMore(group.status),
              ],
            ],
          ];
          return ReorderableListView.builder(
            // Restores the scroll offset when returning to the tab (the
            // shell unmounts inactive tabs, dropping plain scroll state).
            key: const PageStorageKey<String>('library-list'),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.only(
              bottom: 16 + rdFloatingNavContentInset(context),
            ),
            itemCount: rows.length + 1,
            onReorderItem: (oldIndex, newIndex) =>
                _reorderVisible(rows, ordered, oldIndex, newIndex),
            // Default Material proxy fills list insets + bottom gap.
            // Rebuild the card alone so feedback matches the row only.
            proxyDecorator: (child, index, animation) {
              if (index <= 0 || index - 1 >= rows.length) return child;
              final row = rows[index - 1];
              if (row is! Book) return child;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: rdReorderableDragProxy(
                  context: context,
                  animation: animation,
                  child: OwnedBookRow(
                    book: row,
                    margin: EdgeInsets.zero,
                  ),
                ),
              );
            },
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(
                  key: const ValueKey<String>('library-header'),
                  children: [
                    const LibraryStatusBar(),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: EmptyState(
                          icon: LucideIcons.search,
                          message: l.searchNoResults,
                          action: filters.isEmpty
                              ? null
                              : RdButton.plain(
                                  onPressed: () => ref
                                      .read(filtersProvider.notifier)
                                      .clear(),
                                  icon: LucideIcons.filterX,
                                  label: l.filtersClear,
                                  compact: true,
                                ),
                        ),
                      ),
                  ],
                );
              }
              final row = rows[i - 1];
              if (row is _StatusSection) {
                return KeyedSubtree(
                  key: ValueKey<String>('library-section-${row.status}'),
                  child: SectionHeader(
                    bookStatusLabel(l, row.status),
                    color: bookStatusColor(row.status, context.colors),
                    count: row.total,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    expanded: isBookStatusSectionExpanded(
                      _collapsedSections,
                      row.status,
                    ),
                    onToggle: () => setState(
                      () => toggleBookStatusSection(
                        _collapsedSections,
                        row.status,
                      ),
                    ),
                  ),
                );
              }
              if (row is _StatusLoadMore) {
                return KeyedSubtree(
                  key: ValueKey<String>('library-more-${row.status}'),
                  child: Center(
                    child: RdButton.plain(
                      onPressed: () => setState(() {
                        _sectionWindows[row.status] =
                            (_sectionWindows[row.status] ??
                                kBookSectionWindow) +
                            kBookSectionWindow;
                      }),
                      label: l.loadMore,
                    ),
                  ),
                );
              }
              final book = row as Book;
              return KeyedSubtree(
                key: ValueKey<String>('library-book-${book.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: RdReorderableRow(
                    index: i,
                    child: OwnedBookRow(
                      book: book,
                      margin: EdgeInsets.zero,
                      heroCover: true,
                      onTap: () => Navigator.of(context).push(
                        rdPageRoute<void>(
                          context,
                          builder: (_) => BookDetailScreen(bookId: book.id),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddBookSheet(BuildContext context, WidgetRef ref) {
    showRdModalSheet<void>(
      context: context,
      builder: (_) => const _AddBookSheet(),
    );
  }
}

class _AddBookSheet extends ConsumerStatefulWidget {
  const _AddBookSheet();
  @override
  ConsumerState<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends ConsumerState<_AddBookSheet> {
  final _query = TextEditingController();
  List<SearchHit> _hits = [];
  bool _searching = false;
  bool _adding = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Same debounce contract as [SearchScreen]: a typing burst costs one
  /// request, and <3-char prefixes never hit the rate-limited endpoint.
  void _onQueryChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 3) return;
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final r = await ref.read(searchRepoProvider).search(q);
    if (!mounted) return;
    // Drop stale responses — a newer (debounced) search owns the sheet now.
    if (_query.text.trim() != q) return;
    setState(() {
      _searching = false;
      _hits = r.value?.items ?? [];
    });
  }

  Future<void> _add(SearchHit h) async {
    if (_adding) return;
    setState(() => _adding = true);
    final r = await ref
        .read(bookRepoProvider)
        .create(
          title: h.title,
          authors: h.authors,
          coverUrl: h.coverUrl,
          description: h.description,
          isbn: h.isbn,
          pageCount: h.pageCount,
          publisher: h.publisher,
          language: h.language,
          categories: h.categories,
        );
    if (!mounted) return;
    if (r.isErr) {
      setState(() => _adding = false);
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: AppL10n.of(context).errorGeneric,
      );
      return;
    }
    unawaited(ref.read(analyticsProvider).logBookAdded(source: 'search'));
    ref.invalidate(booksProvider);
    ref.invalidatePersonalStats();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.actionAddBook,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            RdSearchField(
              controller: _query,
              hintText: l.searchHint,
              showSubmitButton: true,
              submitTooltip: l.searchHint,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 12),
            if (_searching) const LinearProgressIndicator(),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _hits.length,
                itemBuilder: (_, i) {
                  final h = _hits[i];
                  return ListTile(
                    leading: BookCover(
                      title: h.title,
                      coverUrl: h.coverUrl,
                      size: BookCoverSize.xs,
                    ),
                    title: Text(h.title),
                    subtitle: h.authors.isEmpty
                        ? null
                        : Text(
                            h.authors.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: RdIconButton.custom(
                      compact: true,
                      tooltip: l.actionAddBook,
                      onPressed: _adding ? null : () => _add(h),
                      child: _adding
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(LucideIcons.plus),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSection {
  const _StatusSection(this.status, this.total);
  final String status;
  final int total;
}

class _StatusLoadMore {
  const _StatusLoadMore(this.status);
  final String status;
}
