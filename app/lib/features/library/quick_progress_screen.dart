import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_dropdown_field.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/skeleton.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/library_pane.dart';
import 'package:readendar/features/library/progress_editor.dart';

class QuickProgressScreen extends ConsumerStatefulWidget {
  const QuickProgressScreen({required this.initialBookId, super.key});

  final String initialBookId;

  @override
  ConsumerState<QuickProgressScreen> createState() =>
      _QuickProgressScreenState();
}

class _QuickProgressScreenState extends ConsumerState<QuickProgressScreen> {
  String? _selectedBookId;

  @override
  void initState() {
    super.initState();
    _selectedBookId = widget.initialBookId;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.actionUpdateProgress)),
      body: books.when(
        skipError: true,
        loading: () => const BookListSkeleton(),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () => ref.invalidate(booksProvider),
        ),
        data: (allBooks) {
          final reading = allBooks
              .where(
                (book) => book.status == BookStatus.reading,
              )
              .toList(growable: false);
          if (reading.isEmpty) {
            return EmptyState(
              icon: LucideIcons.bookOpen,
              message: l.statusEmptyReading,
              action: RdButton.primary(
                onPressed: _goToLibrary,
                icon: LucideIcons.library,
                label: l.statusEmptyGoToLibrary,
              ),
            );
          }

          final selected = reading.firstWhere(
            (book) => book.id == _selectedBookId,
            orElse: () => reading.first,
          );
          _selectedBookId = selected.id;
          final progress = ref.watch(progressProvider(selected.id));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surface1,
                  borderRadius: BorderRadius.circular(
                    ReadendarTokens.radiusCard,
                  ),
                  border: Border.all(color: context.colors.line),
                ),
                child: Row(
                  children: [
                    BookCover(
                      title: selected.title,
                      author: selected.authors.firstOrNull,
                      coverUrl: selected.coverUrl,
                      size: BookCoverSize.sm,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        key: const Key('quickProgressBookPicker'),
                        child: RdDropdownField<String>(
                          key: ValueKey(selected.id),
                          value: selected.id,
                          label: l.statusReading,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(LucideIcons.bookOpen),
                          ),
                          items: [
                            for (final book in reading)
                              RdDropdownItem(
                                value: book.id,
                                label: book.title,
                              ),
                          ],
                          onChanged: (id) {
                            if (id != null) {
                              setState(() => _selectedBookId = id);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              progress.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(32),
                  child: RdProgress.centered(),
                ),
                error: (error, _) {
                  if (error is FailureException &&
                      error.failure is NotFoundFailure) {
                    return ProgressEditorForm(
                      key: ValueKey(selected.id),
                      book: selected,
                      onSaved: _closeAfterSave,
                    );
                  }
                  return ErrorRetry(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(progressProvider(selected.id)),
                  );
                },
                data: (value) => ProgressEditorForm(
                  key: ValueKey(selected.id),
                  book: selected,
                  initial: value,
                  onSaved: _closeAfterSave,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _goToLibrary() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    openLibrosTab(ref);
  }

  void _closeAfterSave() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
