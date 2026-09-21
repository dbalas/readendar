// Annotations saved on one book. Reached from the book-detail summary card.
// Search, category chips (All | one category), swipe-delete,
// pin highlight (max 3). Kindle import lives on the app bar for personal books.

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/annotation_category_style.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_create_action.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_list_item_actions.dart';
import 'package:readendar/core/widgets/rd_menu.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/kindle/kindle_import_screen.dart';
import 'package:readendar/features/quotes/annotations_empty_art.dart';
import 'package:readendar/features/quotes/quote_card.dart';
import 'package:readendar/features/quotes/quote_composer_sheet.dart';
import 'package:readendar/features/quotes/share/quote_share_sheet.dart';

class BookAnnotationsScreen extends ConsumerStatefulWidget {
  const BookAnnotationsScreen({
    required this.bookId,
    this.highlightAnnotationId,
    this.book,
    super.key,
  });

  final String bookId;
  final String? highlightAnnotationId;

  /// Seed from book detail before [booksByIdProvider] is warm.
  final Book? book;

  @override
  ConsumerState<BookAnnotationsScreen> createState() =>
      _BookAnnotationsScreenState();
}

/// Legacy name for [BookAnnotationsScreen].
class BookQuotesScreen extends BookAnnotationsScreen {
  const BookQuotesScreen({
    required super.bookId,
    super.key,
    String? highlightQuoteId,
  }) : super(highlightAnnotationId: highlightQuoteId);
}

class _BookAnnotationsScreenState extends ConsumerState<BookAnnotationsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final GlobalKey _highlightKey = GlobalKey();
  final Set<AnnotationCategory> _categories = {};
  bool _favoritesOnly = false;
  bool _scrolledToHighlight = false;
  bool _clearedInitialFocus = false;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Book? _resolvedBook() {
    final seeded = widget.book;
    if (seeded != null && seeded.id == widget.bookId) return seeded;
    return ref.watch(booksByIdProvider)[widget.bookId];
  }

  Future<Book?> _ensureBook(Book? book) async {
    if (book != null) return book;
    final r = await ref.read(bookRepoProvider).get(widget.bookId);
    return r.fold((v) => v, (f) {
      if (mounted) showRdFailureToast(context, f);
      return null;
    });
  }

  Future<void> _add(Book? book, {AnnotationCategory? category}) async {
    final target = await _ensureBook(book);
    if (target == null || !mounted) return;
    final created = await openQuoteComposer(
      context,
      book: target,
      category: category ?? AnnotationCategory.note,
    );
    if (created == null || !mounted) return;
    _showCreatedToast(created, target);
  }

  void _showCreatedToast(Annotation created, Book? book) {
    final l = AppL10n.of(context);
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.annotationCreated,
      actionLabel: l.actionShare,
      onAction: () {
        if (!mounted) return;
        openQuoteShareSheet(context, quote: created, book: book);
      },
    );
  }

  Future<void> _delete(Annotation a) async {
    final l = AppL10n.of(context);
    final ok = await showConfirmDialog(
      context: context,
      icon: LucideIcons.trash2,
      confirmIcon: LucideIcons.trash2,
      title: l.annotationDeleteConfirmTitle,
      message: l.annotationDeleteConfirmMessage,
      confirmLabel: l.actionDelete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final f = await ref.read(quotesControllerProvider.notifier).delete(a.id);
    ref.invalidate(bookAnnotationsProvider(widget.bookId));
    if (f != null && mounted) {
      showRdFailureToast(context, f);
    }
  }

  Future<void> _togglePin(Annotation a, {required int pinnedCount}) async {
    if (!a.pinned && pinnedCount >= AnnotationCategory.maxPinsPerBook) {
      showRdToast(context, message: AppL10n.of(context).annotationPinLimit);
      return;
    }
    final f = await ref.read(quotesControllerProvider.notifier).togglePin(a);
    if (f != null && mounted) {
      showRdFailureToast(context, f);
    }
  }

  Future<void> _toggleFavorite(Annotation a) async {
    final f = await ref
        .read(quotesControllerProvider.notifier)
        .toggleFavorite(a);
    if (f != null && mounted) {
      showRdFailureToast(context, f);
    }
  }

  void _openKindleImport() {
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (_) => KindleImportScreen(lockedBookId: widget.bookId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final book = _resolvedBook();
    final annotationsAsync = ref.watch(bookAnnotationsProvider(widget.bookId));
    final canCreate = book != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.annotationsTitle),
        actions: [
          if (book != null)
            RdIconButton(
              tooltip: l.kindleImportTitle,
              icon: LucideIcons.bookUp,
              onPressed: _openKindleImport,
            ),
          if (canCreate)
            ...RdCreateAction.appBarActions(
              context: context,
              onPressed: () => _openCreateMenu(book),
              tooltip: l.annotationAdd,
            ),
        ],
      ),
      floatingActionButton: canCreate
          ? RdCreateAction.fab(
              context: context,
              onPressed: () => _openCreateMenu(book),
              tooltip: l.annotationAdd,
            )
          : null,
      body: annotationsAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        skipError: true,
        loading: RdProgress.centered,
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(bookAnnotationsProvider(widget.bookId)),
        ),
        data: (fetched) {
          // Overlay pin/favorite from the optimistic controller so toggles
          // paint immediately (book list is a separate FutureProvider).
          final all = _withControllerOverlay(
            fetched,
            ref.watch(quotesControllerProvider).value,
          );
          final needle = _search.text.trim().toLowerCase();
          final filtered = all.where((a) {
            if (_categories.isNotEmpty && !_categories.contains(a.category)) {
              return false;
            }
            if (_favoritesOnly && !a.favorite) return false;
            if (needle.isEmpty) return true;
            return a.body.toLowerCase().contains(needle) ||
                a.commentary.toLowerCase().contains(needle);
          }).toList();
          final pinCapCount = all
              .where(
                (a) => a.pinned && a.category != AnnotationCategory.quote,
              )
              .length;

          if (all.isEmpty) {
            return RefreshableEmptyState(
              illustration: const AnnotationsEmptyArt(),
              message: l.annotationsEmptyMessage,
              onRefresh: () async =>
                  ref.invalidate(bookAnnotationsProvider(widget.bookId)),
              action: canCreate
                  ? RdButton.primary(
                      onPressed: () => _openCreateMenu(book),
                      icon: LucideIcons.plus,
                      label: l.annotationAdd,
                    )
                  : null,
            );
          }

          if (widget.highlightAnnotationId != null && !_scrolledToHighlight) {
            _scrolledToHighlight = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final ctx = _highlightKey.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  duration: const Duration(milliseconds: 300),
                );
              }
            });
          }

          if (!_clearedInitialFocus) {
            _clearedInitialFocus = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_searchFocus.hasFocus) _searchFocus.unfocus();
            });
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: RdSearchField(
                  controller: _search,
                  focusNode: _searchFocus,
                  hintText: l.annotationsSearchHint,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: Icon(
                          _categories.length == 1
                              ? AnnotationCategoryStyle.icon(_categories.single)
                              : LucideIcons.tags,
                          size: 16,
                          color: _categories.isEmpty
                              ? null
                              : _categories.length == 1
                              ? AnnotationCategoryStyle.foreground(
                                  _categories.single,
                                  Theme.of(context).brightness,
                                )
                              : context.colors.accentSoftFg,
                        ),
                        backgroundColor: _categories.isEmpty
                            ? null
                            : _categories.length == 1
                            ? AnnotationCategoryStyle.softBg(_categories.single)
                            : context.colors.accentSoftBg,
                        side: _categories.isEmpty
                            ? null
                            : BorderSide(
                                color: _categories.length == 1
                                    ? AnnotationCategoryStyle.hue(
                                        _categories.single,
                                      )
                                    : context.colors.accent,
                              ),
                        label: Text(
                          _categories.isEmpty
                              ? l.annotationFilterCategories
                              : _categories.length == 1
                              ? AnnotationCategoryStyle.label(
                                  l,
                                  _categories.single,
                                )
                              : '${l.annotationFilterCategories} · ${_categories.length}',
                        ),
                        onPressed: () async {
                          final next = await _showCategoryFilterSheet(
                            context,
                            _categories,
                          );
                          if (next != null && mounted) {
                            setState(() {
                              _categories
                                ..clear()
                                ..addAll(next);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: ReadendarTokens.sp2),
                      ActionChip(
                        avatar: Icon(
                          LucideIcons.star,
                          size: 16,
                          color: _favoritesOnly
                              ? ReadendarTokens.amberStar
                              : null,
                        ),
                        backgroundColor: _favoritesOnly
                            ? ReadendarTokens.amberStar.withValues(alpha: 0.16)
                            : null,
                        side: _favoritesOnly
                            ? const BorderSide(color: ReadendarTokens.amberStar)
                            : null,
                        label: Text(l.annotationFilterFavorites),
                        onPressed: () =>
                            setState(() => _favoritesOnly = !_favoritesOnly),
                      ),
                      if (_categories.isNotEmpty || _favoritesOnly) ...[
                        const SizedBox(width: ReadendarTokens.sp1),
                        RdIconButton.compact(
                          tooltip: l.filtersClear,
                          onPressed: () => setState(() {
                            _categories.clear();
                            _favoritesOnly = false;
                          }),
                          icon: LucideIcons.filterX,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: EmptyState(
                          icon: LucideIcons.search,
                          message: l.annotationsFilterEmpty,
                        ),
                      )
                    : RdRefresh(
                        onRefresh: () async => ref.invalidate(
                          bookAnnotationsProvider(widget.bookId),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final a = filtered[i];
                            final highlighted =
                                a.id == widget.highlightAnnotationId;
                            final card = QuoteCard(
                              quote: a,
                              highlighted: highlighted,
                              card: false,
                              // Swipe chrome owns the pin/highlight frame so
                              // the delete strip stays inside the border.
                              accentFrame: false,
                              onTap: () => openQuoteComposer(
                                context,
                                book: book,
                                existing: a,
                              ),
                              onEdit: () => openQuoteComposer(
                                context,
                                book: book,
                                existing: a,
                              ),
                              onTogglePin: () => _togglePin(
                                a,
                                pinnedCount: pinCapCount,
                              ),
                              onToggleFavorite: () => _toggleFavorite(a),
                              onShare: () => openQuoteShareSheet(
                                context,
                                quote: a,
                                book: book,
                              ),
                              onDelete: () => _delete(a),
                            );
                            final wrapped = RdListItemActions(
                              border: QuoteCard.accentBorderSide(
                                context,
                                pinned: a.pinned,
                                highlighted: highlighted,
                              ),
                              items: [
                                RdMenuItem(
                                  value: 'delete',
                                  label: l.actionDelete,
                                  icon: LucideIcons.trash2,
                                  destructive: true,
                                ),
                              ],
                              onSelected: (_) => _delete(a),
                              child: card,
                            );
                            return Padding(
                              key: highlighted ? _highlightKey : null,
                              padding: const EdgeInsets.only(bottom: 8),
                              child: wrapped,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreateMenu(Book? book) async {
    final selected = await pickAnnotationCategoryToCreate(context);
    if (selected == null || !mounted) return;
    await _add(book, category: selected);
  }
}

/// Prefer controller pin/favorite over the book-list snapshot.
List<Annotation> _withControllerOverlay(
  List<Annotation> bookRows,
  List<Annotation>? controllerRows,
) {
  if (controllerRows == null || controllerRows.isEmpty) return bookRows;
  final byId = {for (final q in controllerRows) q.id: q};
  return [
    for (final a in bookRows) byId[a.id] ?? a,
  ];
}

Future<Set<AnnotationCategory>?> _showCategoryFilterSheet(
  BuildContext context,
  Set<AnnotationCategory> initial,
) {
  final draft = {...initial};
  return showRdModalSheet<Set<AnnotationCategory>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final l = AppL10n.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.annotationFilterCategories,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: ReadendarTokens.sp4),
              Wrap(
                spacing: ReadendarTokens.sp2,
                runSpacing: ReadendarTokens.sp2,
                children: [
                  for (final cat in AnnotationCategory.values)
                    AnnotationCategoryChip(
                      category: cat,
                      selected: draft.contains(cat),
                      onSelected: (selected) => setSheetState(() {
                        if (selected) {
                          draft.add(cat);
                        } else {
                          draft.remove(cat);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: ReadendarTokens.sp4),
              Row(
                children: [
                  RdButton.plain(
                    onPressed: () => setSheetState(draft.clear),
                    label: l.actionReset,
                  ),
                  const Spacer(),
                  RdButton.primary(
                    onPressed: () => Navigator.pop(context, {...draft}),
                    label: l.actionApply,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
