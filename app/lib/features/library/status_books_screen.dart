import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/filters/filter_icon_button.dart';
import 'package:readendar/features/filters/filters_state.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/library/library_pane.dart';
import 'package:readendar/features/library/owned_book_row.dart';
import 'package:readendar/features/search/search_screen.dart';

/// A simple book list scoped to a single [BookStatus]. Reuses the library's
/// owned book rows and the global filters (search lives in the filter sheet).
/// The status filter is intentionally ignored here since the list is already
/// constrained to [status].
class StatusBooksScreen extends ConsumerWidget {
  const StatusBooksScreen({required this.status, super.key});

  final String status;

  Future<void> _addBook(BuildContext context, WidgetRef ref) async {
    final book = await Navigator.of(context).push<Book>(
      rdPageRoute<Book>(
        context,
        builder: (_) => SearchScreen(initialStatus: status),
      ),
    );
    if (book != null) {
      ref.invalidate(booksProvider);
      ref.invalidatePersonalStats();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final books = ref.watch(visibleBooksProvider);
    final filters = ref.watch(filtersProvider);
    final scoped = filters.copyWith(bookStatuses: const <String>{});
    return Scaffold(
      appBar: AppBar(
        title: Text(bookStatusLabel(l, status)),
        actions: [
          RdIconButton(
            icon: LucideIcons.plus,
            tooltip: l.quickAddBook,
            onPressed: () => _addBook(context, ref),
          ),
          FilterIconButton(
            active: !scoped.isEmpty,
            hideStatus: true,
            booksOnly: true,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RdRefresh(
          onRefresh: () async => ref.invalidate(booksProvider),
          child: books.when(
            skipError: true,
            loading: RdProgress.centered,
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(booksProvider),
            ),
            data: (list) {
              final statusBooks = list
                  .where((b) => b.status == status)
                  .toList(growable: false);

              if (statusBooks.isEmpty) {
                return _StatusEmptyState(
                  status: status,
                  onAddBook: () => _addBook(context, ref),
                  onGoToLibrary: () {
                    Navigator.of(context).pop();
                    openLibrosTab(ref);
                  },
                );
              }

              final filtered = statusBooks
                  .where((b) => bookMatchesFilters(b, scoped))
                  .toList(growable: false);
              if (filtered.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                  children: [
                    EmptyState(
                      icon: LucideIcons.search,
                      message: l.searchNoResults,
                      action: scoped.isEmpty
                          ? null
                          : RdButton.plain(
                              onPressed: () =>
                                  ref.read(filtersProvider.notifier).clear(),
                              icon: LucideIcons.filterX,
                              label: l.filtersClear,
                              compact: true,
                            ),
                    ),
                  ],
                );
              }
              // Lazy rows: swipe chrome + AnimationController must not mount for
              // every book in a large status shelf.
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final b = filtered[index];
                  return Padding(
                    key: ValueKey<String>('status-book-${b.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: OwnedBookRow(
                      book: b,
                      heroCover: true,
                      heroTag: _statusBookHeroTag(status, b.id),
                      onTap: () => Navigator.of(context).push(
                        rdPageRoute<void>(
                          context,
                          builder: (_) => BookDetailScreen(
                            bookId: b.id,
                            heroTag: _statusBookHeroTag(status, b.id),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

String _statusBookHeroTag(String status, String bookId) =>
    'status-$status-book-cover-$bookId';

class _StatusEmptyState extends StatelessWidget {
  const _StatusEmptyState({
    required this.status,
    required this.onAddBook,
    required this.onGoToLibrary,
  });

  final String status;
  final VoidCallback onAddBook;
  final VoidCallback onGoToLibrary;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final icon = bookStatusIcon(status);
    final color = bookStatusColor(status, c);
    final tint = bookStatusTint(status, c);
    final message = _emptyMessage(l, status);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.colors.fg2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            RdButton.primary(
              onPressed: onAddBook,
              icon: LucideIcons.plus,
              label: l.actionAddBook,
            ),
            const SizedBox(height: 8),
            RdButton.plain(
              onPressed: onGoToLibrary,
              icon: LucideIcons.library,
              label: l.statusEmptyGoToLibrary,
            ),
          ],
        ),
      ),
    );
  }

  String _emptyMessage(AppL10n l, String status) => switch (status) {
    BookStatus.reading => l.statusEmptyReading,
    BookStatus.pending => l.statusEmptyPending,
    BookStatus.wanted => l.statusEmptyWanted,
    BookStatus.read => l.statusEmptyRead,
    BookStatus.abandoned => l.statusEmptyAbandoned,
    _ => l.searchNoResults,
  };
}
