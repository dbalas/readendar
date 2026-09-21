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
import 'package:readendar/features/search/cover_picker_screen.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/import/import_progress_screen.dart';
import 'package:readendar/features/library/library_pane.dart';

/// Optional post-import step (Q7): the books that came in without a cover. The
/// user searches for the right edition and attaches its cover — reusing the
/// existing book search. Already-imported books are just updated in place.
class ImproveCoversScreen extends ConsumerStatefulWidget {
  const ImproveCoversScreen({required this.books, super.key});

  final List<ImportedCoverBook> books;

  @override
  ConsumerState<ImproveCoversScreen> createState() =>
      _ImproveCoversScreenState();
}

class _ImproveCoversScreenState extends ConsumerState<ImproveCoversScreen> {
  // Covers chosen this session, keyed by bookId. The book stays in the list once
  // fixed — we just swap its cover in place so the user sees the result.
  final Map<String, String> _newCovers = {};

  void _goToLibrary() {
    openLibrosTab(ref);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _fix(ImportedCoverBook book) async {
    final hit = await Navigator.of(context).push<SearchHit>(
      rdPageRoute<SearchHit>(
        context,
        builder: (_) => CoverPickerScreen(
          query: book.title,
          author: book.authors.isNotEmpty ? book.authors.first : '',
        ),
      ),
    );
    if (hit == null || hit.coverUrl.isEmpty || !mounted) return;

    final l = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(bookRepoProvider);

    // The backend PATCH is a full replace, so re-send the book's current fields
    // alongside the new cover (sending cover alone would blank title/authors).
    final current = await repo.get(book.bookId);
    if (!mounted) return;
    final b = current.fold<Book?>((v) => v, (_) => null);
    if (b == null) {
      showRdToast(
        context,
        messenger: messenger,
        tone: RdToastTone.error,
        message: l.errorGeneric,
      );
      return;
    }

    final res = await repo.update(
      b.id,
      title: b.title,
      authors: b.authors,
      coverUrl: hit.coverUrl,
      description: b.description.isNotEmpty
          ? b.description
          : (hit.description.isEmpty ? null : hit.description),
      pageCount: b.pageCount,
      isbn: b.isbnDisplay,
      publisher: b.publisher,
      language: b.language,
      categories: b.categories,
      format: b.format,
      publicationDate: b.publicationDate,
      publicationDatePrecision: b.publicationDatePrecision,
    );
    if (!mounted) return;
    res.fold(
      (_) {
        ref.invalidate(booksProvider);
        // Keep the row, just swap its cover in place (don't drop it).
        setState(() => _newCovers[book.bookId] = hit.coverUrl);
        showRdToast(
          context,
          messenger: messenger,
          tone: RdToastTone.success,
          message: l.importCoverUpdated,
        );
      },
      (_) => showRdToast(
        context,
        messenger: messenger,
        tone: RdToastTone.error,
        message: l.errorGeneric,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.importImproveTitle),
        actions: [
          RdButton.plain(
            onPressed: _goToLibrary,
            label: l.importDone,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: widget.books.isEmpty
            ? EmptyState(
                icon: LucideIcons.check,
                message: l.importAllCoversDone,
                action: RdButton.primary(
                  onPressed: _goToLibrary,
                  label: l.importGoToLibrary,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(ReadendarTokens.sp4),
                itemCount: widget.books.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: ReadendarTokens.sp3,
                      ),
                      child: Text(
                        l.importImproveHint,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.colors.fg2,
                        ),
                      ),
                    );
                  }
                  final book = widget.books[i - 1];
                  final newCover = _newCovers[book.bookId];
                  // Reuse the app's standard book card (same look as the library /
                  // event lists). Status pill hidden — only the cover matters here.
                  return BookRow(
                    book: Book(
                      id: book.bookId,
                      ownerType: OwnerType.user,
                      ownerId: '',
                      title: book.title,
                      authors: book.authors,
                      status: BookStatus.pending,
                      coverUrl: newCover ?? '',
                    ),
                    showStatus: false,
                    onTap: () => _fix(book),
                    // Done → a sage check; pending → a tonal "pick a cover" button.
                    // Tapping the row re-opens the picker either way.
                    trailing: newCover != null
                        ? Icon(
                            LucideIcons.circleCheck,
                            color: context.colors.success,
                          )
                        : IconButton.filledTonal(
                            icon: const Icon(LucideIcons.imagePlus, size: 18),
                            tooltip: l.importImproveSearchTitle,
                            onPressed: () => _fix(book),
                          ),
                  );
                },
              ),
      ),
    );
  }
}
