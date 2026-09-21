import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/book_status_groups.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/search_field.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/owned_book_row.dart';
import 'package:readendar/features/search/search_screen.dart';

/// Bottom-sheet book picker for the quote composer / Kindle import: personal
/// library only, grouped with the same status sections and rows as Library,
/// with a local filter field and a pinned "Create book" action. When
/// [seedTitle] is supplied (the Kindle import passes the highlighted book's
/// title/author), the create flow opens the search pre-filled so the user can
/// pick a match or fill the form fast.
Future<Book?> pickQuoteBook(
  BuildContext context, {
  String? seedTitle,
  String? seedAuthor,
}) {
  return showRdModalSheet<Book>(
    context: context,
    builder: (_) =>
        _QuoteBookPickerSheet(seedTitle: seedTitle, seedAuthor: seedAuthor),
  );
}

class _QuoteBookPickerSheet extends ConsumerStatefulWidget {
  const _QuoteBookPickerSheet({this.seedTitle, this.seedAuthor});

  final String? seedTitle;
  final String? seedAuthor;

  @override
  ConsumerState<_QuoteBookPickerSheet> createState() =>
      _QuoteBookPickerSheetState();
}

class _QuoteBookPickerSheetState extends ConsumerState<_QuoteBookPickerSheet> {
  final _filter = TextEditingController();
  final Set<String> _collapsedSections = {};

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  bool _matches(Book b, String q) {
    if (q.isEmpty) return true;
    final needle = q.toLowerCase();
    return b.title.toLowerCase().contains(needle) ||
        b.authors.any((a) => a.toLowerCase().contains(needle));
  }

  /// Opens the full search screen (seeded with the source title, if any) so the
  /// user can pick a remote match or create the book manually; on save the new
  /// [Book] is returned and we close the picker with it selected.
  Future<void> _createBook() async {
    final seed = [
      widget.seedTitle?.trim() ?? '',
      widget.seedAuthor?.trim() ?? '',
    ].where((s) => s.isNotEmpty).join(' ');
    final book = await Navigator.of(context).push<Book>(
      rdPageRoute<Book>(
        context,
        builder: (_) => SearchScreen(
          initialQuery: seed.isEmpty ? null : seed,
          popWhenCreated: true,
        ),
      ),
    );
    if (book != null && mounted) Navigator.of(context).pop(book);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final books = (ref.watch(booksProvider).value ?? const <Book>[]).toList();
    final q = _filter.text.trim();
    final filtered = books.where((b) => _matches(b, q)).toList();
    final groups = groupByBookStatus(
      filtered,
      statusOf: (book) => book.status,
    );
    final rows = <Object>[
      for (final group in groups) ...[
        group,
        if (isBookStatusSectionExpanded(_collapsedSections, group.status))
          ...group.items,
      ],
    ];
    return Padding(
      padding: EdgeInsets.zero,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.quoteBookPickerTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              RdSearchField(
                controller: _filter,
                hintText: l.quoteBookPickerFilterHint,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              // Persistent create affordance, pinned above the list.
              RdButton.secondary(
                onPressed: _createBook,
                icon: LucideIcons.plus,
                label: l.quoteBookPickerCreate,
                expand: true,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 360,
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          l.searchNoResults,
                          style: TextStyle(color: c.fg3),
                        ),
                      )
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final row = rows[i];
                          if (row is BookStatusGroup<Book>) {
                            return SectionHeader(
                              bookStatusLabel(l, row.status),
                              color: bookStatusColor(row.status, c),
                              // The sheet already has a 16px content inset;
                              // keep the final 20px title alignment from
                              // Library instead of adding its full 20px again.
                              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                              count: row.total,
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
                            );
                          }
                          final b = row as Book;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: OwnedBookRow(
                              book: b,
                              onTap: () => Navigator.of(context).pop(b),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
