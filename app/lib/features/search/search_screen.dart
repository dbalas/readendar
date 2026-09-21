// P-06 — Búsqueda / añadir libro (spec §17).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/search/isbn_scanner_screen.dart';
import 'package:readendar/features/search/manual_book_form_screen.dart';
import 'package:readendar/features/search/search_empty_art.dart';
import 'package:readendar/features/search/search_hit_row.dart';

export 'package:readendar/features/search/custom_field_decimal.dart';
export 'package:readendar/features/search/manual_book_form_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialColumn,
    this.initialStatus,
    this.autoScan = false,
    this.popWhenCreated = false,
  });

  /// Pre-fills the search box and runs a search on open (e.g. the Kindle
  /// quick-create flow seeds this with the highlighted book's title). When
  /// [popWhenCreated] is true the screen still returns the created [Book]
  /// via `Navigator.pop`.
  final String? initialQuery;

  /// Optional search mode applied while the box still holds the deep-link seed
  /// (`author` → author catalog of that author's books).
  final String? initialColumn;

  /// Seeds the review/create form status (e.g. adding from a status-scoped
  /// home-banner list so the book lands in that list).
  final String? initialStatus;

  /// Opens the ISBN barcode scanner immediately on first frame (e.g. the
  /// library's one-tap scan action), so the user lands straight in the camera.
  final bool autoScan;

  /// Pickers that need the created [Book] as a route result. Library/home
  /// search keeps this screen so the user can keep adding from the same query.
  final bool popWhenCreated;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final _seenKeys = <String>{};
  List<SearchHit> _hits = [];
  bool _searching = false;
  bool _searched = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  Object? _error;
  Object? _pageError;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final seed = widget.initialQuery?.trim();
    if (seed != null && seed.isNotEmpty) {
      _query.text = seed;
      // Run once after the first frame so `setState` inside search/lookup is safe.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Related / deep-links often seed an ISBN — resolve exactly first.
        if (normalizeScannedIsbn(seed) != null) {
          unawaited(_resolveIsbn(seed));
        } else {
          unawaited(_search());
        }
      });
    } else if (widget.autoScan) {
      // Land straight in the barcode scanner (one-tap scan entry from Library).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_scan());
      });
    }
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _query.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 320) unawaited(_loadMore());
  }

  /// Column filter applies only while the box still holds the deep-link seed
  /// (author). Editing the query drops it so later searches stay free-text.
  String? get _columnForCurrentQuery {
    final seed = widget.initialQuery?.trim();
    final col = widget.initialColumn?.trim();
    if (seed == null || seed.isEmpty || col == null || col.isEmpty) return null;
    if (_query.text.trim() != seed) return null;
    return col;
  }

  /// Catalog pages are unfiltered. Stop when upstream says there is no more.
  void _applyPagingFlags(bool upstreamHasMore) {
    _hasMore = upstreamHasMore;
  }

  void _appendUnique(Iterable<SearchHit> items) {
    for (final h in items) {
      final key = h.dedupeKey;
      if (_seenKeys.contains(key)) continue;
      _seenKeys.add(key);
      _hits.add(h);
    }
  }

  Book? _ownedLibraryBook(List<Book>? books, SearchHit hit) {
    if (books == null || books.isEmpty) return null;
    final key = isbnComparisonKey(hit.isbn);
    if (key.isEmpty) return null;
    for (final book in books) {
      if (isbnComparisonKey(book.isbnDisplay) == key) return book;
    }
    return null;
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final generation = ++_requestGeneration;
    setState(() {
      _searching = true;
      _searched = true;
      _loadingMore = false;
      _error = null;
      _pageError = null;
      _hits = [];
      _seenKeys.clear();
      _page = 1;
      _hasMore = false;
    });
    final r = await ref
        .read(searchRepoProvider)
        .search(
          q,
          column: _columnForCurrentQuery,
        );
    if (!mounted || generation != _requestGeneration) return;
    // Drop a stale response if the user changed the query and re-searched
    // before this one landed.
    if (_query.text.trim() != q) {
      setState(() {
        _searching = false;
        _hasMore = false;
      });
      return;
    }
    setState(() {
      _searching = false;
      if (r.isErr) {
        _error = r.failure;
        _hits = [];
        _hasMore = false;
        return;
      }
      final page = r.value!;
      _appendUnique(page.items);
      _page = page.page;
      _applyPagingFlags(page.hasMore);
      _error = null;
    });
  }

  Future<void> _loadMore() async {
    if (_searching || _loadingMore || !_hasMore || _error != null) return;
    final q = _query.text.trim();
    if (q.isEmpty) return;
    final generation = _requestGeneration;
    final nextPage = _page + 1;

    setState(() {
      _loadingMore = true;
      _pageError = null;
    });

    final r = await ref
        .read(searchRepoProvider)
        .search(
          q,
          column: _columnForCurrentQuery,
          page: nextPage,
        );
    if (!mounted || generation != _requestGeneration) return;
    if (_query.text.trim() != q) {
      setState(() => _loadingMore = false);
      return;
    }
    setState(() {
      _loadingMore = false;
      if (r.isErr) {
        _pageError = r.failure;
        return;
      }
      final page = r.value!;
      _page = page.page;
      _appendUnique(page.items);
      _applyPagingFlags(page.hasMore);
      _pageError = null;
    });
  }

  /// Opens the barcode scanner, then resolves the scanned or typed ISBN. On a
  /// hit we open public catalog detail; otherwise we drop the ISBN into the
  /// search box and run a normal text search (results / create-manually).
  Future<void> _scan() async {
    final isbn = await Navigator.of(context).push<String>(
      rdPageRoute<String>(context, builder: (_) => const IsbnScannerScreen()),
    );
    if (isbn == null) {
      // Cancelled the scanner. When the scanner was the entry point (one-tap
      // scan from Library), don't strand the user on the intermediate search
      // screen — pop it so "back" returns straight to Library.
      if (widget.autoScan && mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() => _query.text = isbn);
    await _resolveIsbn(isbn);
  }

  /// Exact ISBN lookup (scan / related deep-link), then free-text fallback.
  Future<void> _resolveIsbn(String isbn) async {
    setState(() {
      _searching = true;
      _searched = true;
      _error = null;
    });
    final r = await ref.read(searchRepoProvider).lookupByIsbn(isbn);
    if (!mounted) return;
    final hit = r.value;
    if (hit != null) {
      setState(() => _searching = false);
      await _review(hit);
      return;
    }
    if (r.isErr) {
      setState(() {
        _searching = false;
        _error = r.failure;
      });
      return;
    }
    // Not found by exact ISBN — fall back to a free-text search of the code.
    setState(() => _searching = false);
    await _search();
  }

  Future<void> _review(SearchHit h) async {
    final book = await Navigator.of(context).push<Book>(
      rdPageRoute<Book>(
        context,
        builder: (_) => ManualBookFormScreen(
          initialHit: h,
          initialStatus: widget.initialStatus,
        ),
      ),
    );
    if (!mounted || book == null) return;
    await _onCreatedBook(book);
  }

  Future<void> _createManual() async {
    final book = await Navigator.of(context).push<Book>(
      rdPageRoute<Book>(
        context,
        builder: (_) => ManualBookFormScreen(
          initialStatus: widget.initialStatus,
        ),
      ),
    );
    if (!mounted || book == null) return;
    await _onCreatedBook(book);
  }

  /// Pickers pop this route with the new [Book]. Library search stays mounted
  /// and opens owned detail so back (AppBar and system) restores the listing.
  Future<void> _onCreatedBook(Book book) async {
    if (widget.popWhenCreated) {
      Navigator.of(context).pop(book);
      return;
    }
    await Navigator.of(context).push<void>(
      rdPageRoute<void>(
        context,
        builder: (_) => BookDetailScreen(bookId: book.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.searchTitle),
        actions: [
          RdIconButton(
            tooltip: l.scanIsbnTooltip,
            icon: LucideIcons.scanBarcode,
            onPressed: _scan,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: RdSearchField(
                controller: _query,
                hintText: l.searchHint,
                showSubmitButton: true,
                submitTooltip: l.actionSearch,
                onSubmitted: (_) => _search(),
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            Expanded(child: _buildResults(l)),
          ],
        ),
      ),
    );
  }

  Widget _searchEmptyActions(AppL10n l) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RdButton.primary(
          onPressed: _scan,
          icon: LucideIcons.scanBarcode,
          label: l.searchScanIsbn,
        ),
        const SizedBox(height: 8),
        RdButton.plain(
          onPressed: _createManual,
          icon: LucideIcons.plus,
          label: _searched ? l.searchCreateManually : l.actionAddBook,
        ),
      ],
    );
  }

  Widget _buildResults(AppL10n l) {
    if (_searching && _hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              l.searchSearching,
              style: TextStyle(color: context.colors.fgFaint),
            ),
          ],
        ),
      );
    }
    if (_error != null && _hits.isEmpty) {
      return ErrorRetry(error: _error!, onRetry: _search);
    }
    if (_hits.isEmpty) {
      // Preferred-language page can be empty while other-language pages remain.
      if (_hasMore || _loadingMore) {
        if (_hasMore && !_loadingMore) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_loadMore());
          });
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                l.searchSearching,
                style: TextStyle(color: context.colors.fgFaint),
              ),
            ],
          ),
        );
      }
      return EmptyState(
        illustration: const SearchEmptyArt(),
        message: _searched ? l.searchNoResults : l.searchEmptyHint,
        action: _searchEmptyActions(l),
      );
    }

    final footerExtra = (_loadingMore || _pageError != null || _hasMore)
        ? 1
        : 0;
    final libraryBooks = ref.watch(visibleBooksProvider).value;
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: _hits.length + 1 + footerExtra,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i < _hits.length) {
          final h = _hits[i];
          final owned = _ownedLibraryBook(libraryBooks, h);
          return SearchHitRow(
            hit: h,
            owned: owned,
            onTap: () => _review(h),
          );
        }
        if (footerExtra > 0 && i == _hits.length) {
          if (_pageError != null) {
            return RdButton.plain(
              onPressed: _loadMore,
              label: localizedErrorMessage(l, _pageError!),
            );
          }
          if (_loadingMore || _hasMore) {
            // Trigger load when the spinner row builds near the end.
            if (_hasMore && !_loadingMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) unawaited(_loadMore());
              });
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: RdButton.secondary(
            onPressed: _createManual,
            icon: LucideIcons.plus,
            label: l.searchCreateManually,
          ),
        );
      },
    );
  }
}
