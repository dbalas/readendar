import 'package:flutter/material.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/book_status_ui.dart';
import 'package:readendar/core/widgets/card.dart';

class BookRow extends StatelessWidget {
  const BookRow({
    required this.book,
    super.key,
    this.onTap,
    this.trailing,
    this.statusAction,
    this.statusActionAtEnd = false,
    this.showStatus = true,
    this.showIsbn = false,
    this.caption,
    this.heroCover = false,
    this.heroTag,
    this.backgroundColor,
    this.borderColor,
    this.cover,
    this.coverUrl,
    this.localCoverPath,
    this.statusKey,
    this.footer,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.card = true,
  });

  final Book book;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Optional action rendered on the status row (next to the status pill) so it
  /// doesn't steal horizontal space from the title/author.
  final Widget? statusAction;

  /// When true, [statusAction] is pushed to the right edge of the status line
  /// (badge on the left, action right-aligned on the same line) instead of
  /// flowing next to the pill in a [Wrap].
  final bool statusActionAtEnd;
  final bool showStatus;

  /// ISBN caption for catalog/search hits where editions must be distinguished.
  final bool showIsbn;

  /// Same chip as ISBN, raw label (e.g. a publication date). Wins over ISBN.
  final String? caption;
  final Color? backgroundColor;
  final Color? borderColor;

  /// Replaces [BookCover] when the row is showing a local crop or other
  /// non-catalog thumbnail.
  final Widget? cover;

  /// Wins over the book's coverUrl so catalog hits can keep the catalog image
  /// even when [book] is an owned library copy.
  final String? coverUrl;

  /// Staged local file. Wins over [coverUrl] and the book's coverUrl.
  final String? localCoverPath;

  final Key? statusKey;

  /// Opt-in: flies the cover to the book detail's header ([Hero] tag
  /// `book-cover-<id>`). Keep OFF in lists that can repeat a book on the same
  /// route or render books without server ids (e.g. import previews) — Hero
  /// tags must be unique per route.
  final bool heroCover;

  /// Optional tag override for lists that can coexist with another mounted
  /// list containing the same books, such as the Home shell's status view and
  /// its retained Library tab.
  final Object? heroTag;

  /// Optional content below the cover/meta row, still inside the same card
  /// (e.g. a public review preview on a profile books list).
  final Widget? footer;

  /// Outer spacing around the card. Owned swipe rows use [EdgeInsets.zero]
  /// and own the bottom gap so the action strip clips to the card only.
  final EdgeInsetsGeometry margin;

  /// When false, skips [RdCard] chrome so a parent (swipe shell) can own the
  /// rounded clip and the delete strip can reveal as a full panel.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final isbn = book.isbnDisplay.trim();
    final chipLabel = caption?.trim() ?? '';
    final isbnLabel = showIsbn && chipLabel.isEmpty && isbn.isNotEmpty
        ? formatIsbnDisplay(isbn)
        : '';
    final coverWidget =
        cover ??
        BookCover(
          title: book.title,
          author: book.authors.firstOrNull,
          coverUrl: coverUrl ?? book.coverUrl,
          localImagePath: localCoverPath,
          color: ReadendarTokens.teal500,
          size: BookCoverSize.sm,
          rating: book.rating,
          hasNotes: book.hasNotes,
        );
    final meta = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heroCover && book.id.isNotEmpty && cover == null)
          Hero(tag: heroTag ?? 'book-cover-${book.id}', child: coverWidget)
        else
          coverWidget,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              if (book.authors.isNotEmpty)
                Text(
                  book.authors.first,
                  // fg3, not fgFaint: 11.5px content text needs ≥4.5:1
                  // contrast (WCAG AA); the fainter level is ~3.3:1 on paper.
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.colors.fg3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (chipLabel.isNotEmpty || isbnLabel.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: book.authors.isNotEmpty ? 3 : 0,
                  ),
                  child: _IsbnChip(
                    chipLabel.isNotEmpty ? chipLabel : isbnLabel,
                  ),
                ),
              if (showStatus || statusAction != null) ...[
                const SizedBox(height: 6),
                if (statusActionAtEnd && statusAction != null)
                  Row(
                    children: [
                      if (showStatus) _StatusPill(book.status, key: statusKey),
                      const Spacer(),
                      statusAction!,
                    ],
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (showStatus) _StatusPill(book.status, key: statusKey),
                      ?statusAction,
                    ],
                  ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
    final body = footer == null
        ? meta
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              meta,
              const SizedBox(height: 8),
              footer!,
            ],
          );
    if (!card) {
      final padded = Padding(
        padding: const EdgeInsets.all(10),
        child: body,
      );
      return Padding(
        padding: margin,
        child: onTap == null ? padded : InkWell(onTap: onTap, child: padded),
      );
    }
    return Padding(
      padding: margin,
      child: RdCard(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        padding: const EdgeInsets.all(10),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class _IsbnChip extends StatelessWidget {
  const _IsbnChip(this.isbn);

  final String isbn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface2,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          child: Text(
            isbn,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.45,
              color: c.fg3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bookStatusTint(status, c),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      ),
      child: Text(
        bookStatusLabel(AppL10n.of(context), status),
        style: TextStyle(
          fontSize: 10.5,
          color: bookStatusColor(status, c),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
