import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/progress_display.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/themed_linear_progress.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:readendar/features/widget/widget_preview.dart';

/// In-app preview of the quick-progress widget. It deliberately reuses the
/// events widget's frame, wordmark, state treatment, book-cover scale, card
/// surface, and accent footer so all Readendar widgets read as one family.
class ProgressWidgetPreview extends ConsumerWidget {
  const ProgressWidgetPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final summary = ref.watch(widgetSummaryProvider);
    return ReadendarWidgetPreviewFrame(
      child: switch (summary) {
        AsyncData(:final value) => _ProgressBody(summary: value),
        AsyncError() => _ProgressState(
          icon: LucideIcons.wifiOff,
          text: l.widgetPreviewError,
          action: l.retry,
          color: c.danger,
        ),
        _ => const SizedBox(
          height: 132,
          child: ReadendarWidgetLoadingBody(),
        ),
      },
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.summary});

  final WidgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    if (summary.readingBooks.isEmpty) {
      return _ProgressState(
        icon: LucideIcons.library,
        text: l.statusEmptyReading,
        action: l.statusEmptyGoToLibrary,
        color: c.fg3,
      );
    }

    final book = summary.readingBooks.first;
    final pct = _effectiveProgress(book);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReadendarWidgetHeader(books: summary.readingBooks),
        const SizedBox(height: 8),
        RdCard(
          key: const Key('progressWidgetBookCard'),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              BookCover(
                title: book.title,
                author: book.author,
                coverUrl: book.coverUrl,
                size: BookCoverSize.xs,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (book.author.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.fg2, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 5),
                    _ProgressMeta(book: book),
                    if (pct != null) ...[
                      const SizedBox(height: 6),
                      ThemedLinearProgress(
                        indicatorKey: const Key('progressWidgetProgressBar'),
                        value: pct / 100,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const _ProgressInlineForm(),
      ],
    );
  }
}

/// Static gallery preview of the native primary action. It opens the compact
/// page/chapter keypad in the installed Android or iOS widget.
class _ProgressInlineForm extends StatelessWidget {
  const _ProgressInlineForm();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RdButton.primary(
        key: const Key('progressWidgetAction'),
        onPressed: () {},
        label: AppL10n.of(context).actionUpdateProgress,
        expand: true,
        compact: true,
      ),
    );
  }
}

/// Same compact subtitle language as the app's progress card: page and chapter
/// are icon-labelled, percentage is self-describing, and separators keep the
/// whole status on one line instead of three bespoke metric boxes.
class _ProgressMeta extends StatelessWidget {
  const _ProgressMeta({required this.book});

  final WidgetBook book;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const iconSize = 12.0;
    final style = TextStyle(
      color: c.fg2,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    );
    final separator = Text(
      '  ·  ',
      style: style.copyWith(color: c.fgFaint),
    );
    final pctLabel =
        shouldShowProgressPercentLabel(
          currentPage: book.currentPage,
          currentPercentage: book.progressPct,
          pageCount: book.pageCount,
        )
        ? effectiveProgressPercent(
            currentPage: book.currentPage,
            currentPercentage: book.progressPct,
            pageCount: book.pageCount,
          )
        : null;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(LucideIcons.bookOpen, size: iconSize, color: c.fg2),
          const SizedBox(width: 3),
          Text(_fraction(book.currentPage, book.pageCount), style: style),
          separator,
          Text(
            pctLabel == null ? '—' : '$pctLabel%',
            style: style,
          ),
          separator,
          Icon(LucideIcons.bookmark, size: iconSize, color: c.fg2),
          const SizedBox(width: 3),
          Text(
            _fraction(book.currentChapter, book.chapterCount),
            style: style,
          ),
        ],
      ),
    );
  }
}

class _ProgressState extends StatelessWidget {
  const _ProgressState({
    required this.icon,
    required this.text,
    required this.action,
    required this.color,
  });

  final IconData icon;
  final String text;
  final String action;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReadendarWidgetWordmark(),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: ReadendarWidgetStateMessage(
            icon: icon,
            text: text,
            color: color,
          ),
        ),
        Center(
          child: Text(
            action,
            style: TextStyle(
              color: context.colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

String _fraction(int? current, int? total) {
  if (current == null) return '—';
  return total == null ? '$current' : '$current / $total';
}

int? _effectiveProgress(WidgetBook book) => effectiveProgressPercent(
  currentPage: book.currentPage,
  currentPercentage: book.progressPct,
  pageCount: book.pageCount,
);
