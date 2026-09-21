import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/book_status_groups.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/skeleton.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/filters/filter_icon_button.dart';
import 'package:readendar/features/filters/filter_search_field.dart';
import 'package:readendar/features/filters/filters_sheet.dart';
import 'package:readendar/features/filters/filters_state.dart';
import 'package:readendar/features/library/owned_book_row.dart';
import 'package:readendar/features/search/search_screen.dart';

/// Full-screen event book selector. It deliberately reuses Library's rows,
/// section headers, search field, filter sheet, and add-book flow.
class BookPickerScreen extends ConsumerStatefulWidget {
  const BookPickerScreen({super.key, this.selectedBookId});

  final String? selectedBookId;

  @override
  ConsumerState<BookPickerScreen> createState() => _BookPickerScreenState();
}

class _BookPickerScreenState extends ConsumerState<BookPickerScreen> {
  FiltersState _filters = const FiltersState();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.eventBookLabel),
        actions: [
          FilterIconButton(
            active: !_filters.isEmpty,
            onPressed: () => unawaited(_showFilters()),
          ),
          RdIconButton(
            icon: LucideIcons.plus,
            tooltip: l.quickAddBook,
            onPressed: _addBook,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: books.when(
          skipError: true,
          loading: () => const BookListSkeleton(),
          error: (error, _) => ErrorRetry(
            error: error,
            onRetry: () => ref.invalidate(booksProvider),
          ),
          data: (list) => _BookPickerList(
            books: list,
            filters: _filters,
            selectedBookId: widget.selectedBookId,
            onFiltersChanged: (next) => setState(() => _filters = next),
            onClearFilters: () =>
                setState(() => _filters = const FiltersState()),
            onAddBook: _addBook,
            onSelected: (book) => Navigator.of(context).pop(book.id),
          ),
        ),
      ),
    );
  }

  Future<void> _showFilters() async {
    final next = await showFiltersSheet(
      context,
      initialFilters: _filters,
      booksOnly: true,
      statusOptions: BookStatus.all,
    );
    if (next != null && mounted) setState(() => _filters = next);
  }

  Future<void> _addBook() async {
    final book = await Navigator.of(context).push<Book>(
      rdPageRoute<Book>(
        context,
        builder: (_) => const SearchScreen(
          popWhenCreated: true,
        ),
      ),
    );
    if (book == null || !mounted) return;
    Navigator.of(context).pop(book.id);
  }
}

class _BookPickerList extends StatefulWidget {
  const _BookPickerList({
    required this.books,
    required this.filters,
    required this.selectedBookId,
    required this.onFiltersChanged,
    required this.onClearFilters,
    required this.onAddBook,
    required this.onSelected,
  });

  final List<Book> books;
  final FiltersState filters;
  final String? selectedBookId;
  final ValueChanged<FiltersState> onFiltersChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onAddBook;
  final ValueChanged<Book> onSelected;

  @override
  State<_BookPickerList> createState() => _BookPickerListState();
}

class _BookPickerListState extends State<_BookPickerList> {
  final Set<String> _collapsedSections = {};

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    if (widget.books.isEmpty) {
      return EmptyState(
        icon: LucideIcons.book,
        message: l.libraryEmptyMessage,
        action: RdButton.primary(
          onPressed: widget.onAddBook,
          label: l.actionAddBook,
        ),
      );
    }

    final filtered = widget.books
        .where((book) => bookMatchesFilters(book, widget.filters))
        .toList(growable: false);
    final groups = groupByBookStatus(
      filtered,
      statusOf: (book) => book.status,
      order: BookStatus.all,
    );
    final rows = <Object>[
      for (final group in groups) ...[
        group,
        if (isBookStatusSectionExpanded(_collapsedSections, group.status))
          ...group.items,
      ],
    ];

    return ListView.builder(
      key: const PageStorageKey<String>('book-picker-list'),
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilterSearchField(
                  filters: widget.filters,
                  onChanged: widget.onFiltersChanged,
                ),
              ),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: EmptyState(
                    icon: LucideIcons.search,
                    message: l.searchNoResults,
                    action: widget.filters.isEmpty
                        ? null
                        : RdButton.plain(
                            onPressed: widget.onClearFilters,
                            icon: LucideIcons.filterX,
                            label: l.filtersClear,
                            compact: true,
                          ),
                  ),
                ),
            ],
          );
        }
        final row = rows[index - 1];
        if (row is BookStatusGroup<Book>) {
          return SectionHeader(
            bookStatusLabel(l, row.status),
            color: bookStatusColor(row.status, context.colors),
            count: row.total,
            expanded: isBookStatusSectionExpanded(
              _collapsedSections,
              row.status,
            ),
            onToggle: () => setState(
              () => toggleBookStatusSection(_collapsedSections, row.status),
            ),
          );
        }
        final book = row as Book;
        final selected = book.id == widget.selectedBookId
            ? Icon(
                LucideIcons.check,
                color: Theme.of(context).colorScheme.primary,
              )
            : null;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OwnedBookRow(
            book: book,
            trailing: selected,
            onTap: () => widget.onSelected(book),
          ),
        );
      },
    );
  }
}
