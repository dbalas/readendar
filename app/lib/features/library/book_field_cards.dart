// Shared visual building blocks for the tap-to-edit "field cards" (status,
// rating). Both the book-detail screen and the book form use these so the two
// surfaces render identical cards. Only their onTap differs (detail persists
// immediately, the form edits local draft state).

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/cover_badge.dart';

const bookFieldCardContentPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 12,
);

/// Shared geometry for the primary line inside Status, Progress, and Rating.
/// Keeping the leading/content/trailing slots here prevents their margins from
/// drifting when one of those cards gains a custom action.
class BookFieldRow extends StatelessWidget {
  const BookFieldRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final Widget leading;
  final String title;
  final Widget subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle =
        (theme.textTheme.bodyMedium ?? DefaultTextStyle.of(context).style)
            .copyWith(color: context.colors.fg2);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                DefaultTextStyle.merge(
                  style: subtitleStyle,
                  child: subtitle,
                ),
              ],
            ),
          ),
          if (trailing != null)
            SizedBox.square(
              dimension: 48,
              child: Center(child: trailing),
            ),
        ],
      ),
    );
  }
}

/// The rounded 36×36 tinted icon tile used as the leading of every field card.
class BookFieldLeadingIcon extends StatelessWidget {
  const BookFieldLeadingIcon({
    required this.background,
    required this.icon,
    required this.color,
    this.iconSize = 18,
    super.key,
  });
  final Color background;
  final IconData icon;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

/// Read-only row of 5 half-aware stars for a rating value.
class BookStaticStars extends StatelessWidget {
  const BookStaticStars({required this.value, this.size = 18, super.key});
  final double value;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            starIconForRating(value, i),
            size: size,
            color: ReadendarTokens.amber500,
          ),
      ],
    );
  }
}

/// Canonical rating readout used by book detail, celebration, and the add/edit
/// book form: large half-stars, amber number when rated, pencil when editable
/// and unrated, plus an optional single-line review caption.
class BookRatingDisplay extends StatelessWidget {
  const BookRatingDisplay({
    required this.rating,
    this.review = '',
    this.showEditHint = false,
    this.starSize = 30,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.reviewKey,
    super.key,
  });

  final double? rating;
  final String review;
  final bool showEditHint;
  final double starSize;
  final CrossAxisAlignment crossAxisAlignment;
  final Key? reviewKey;

  /// Single-line preview for the public review under the stars.
  static String reviewCaption(String review) =>
      review.replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final hasReview = review.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BookStaticStars(value: rating ?? 0, size: starSize),
            if (rating != null) ...[
              const SizedBox(width: 10),
              Text(
                fmtRating(rating!),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.colors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (rating == null && showEditHint) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.pencil, size: 16, color: context.colors.fg3),
            ],
          ],
        ),
        if (hasReview) ...[
          const SizedBox(height: 4),
          Text(
            reviewCaption(review),
            key: reviewKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: crossAxisAlignment == CrossAxisAlignment.center
                ? TextAlign.center
                : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colors.fg3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

/// A plain-text peek at a Markdown note for a card subtitle — strips the most
/// common Markdown syntax so the preview reads cleanly.
String bookNotesPreview(String markdown) =>
    _bookNotesPlain(markdown, collapseWhitespace: true);

/// Same Markdown strip as [bookNotesPreview], but keeps paragraph breaks for
/// full-body display (e.g. a review sheet).
String bookNotesBody(String markdown) =>
    _bookNotesPlain(markdown, collapseWhitespace: false);

String _bookNotesPlain(String markdown, {required bool collapseWhitespace}) {
  final stripped = markdown
      .replaceAll(
        RegExp(r'!?\[([^\]]*)\]\([^)]*\)'),
        r'$1',
      ) // links/images → text
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '') // headings
      .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '') // blockquotes
      .replaceAll(
        RegExp(r'^\s*([-*+]|\d+\.)\s+', multiLine: true),
        '',
      ) // list markers
      .replaceAll(RegExp(r'(\*\*|__|[*_`~])'), ''); // emphasis / code marks
  if (collapseWhitespace) {
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  return stripped
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// The canonical tap-to-edit field card: a tinted leading icon, a label title,
/// a value subtitle, and a trailing chevron. A caller may replace the chevron
/// with a contextual action, such as the status-history button.
class BookFieldCard extends StatelessWidget {
  const BookFieldCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    super.key,
  });
  final Widget leading;
  final String title;
  final Widget subtitle;
  final Widget? trailing;

  /// When null the card is read-only (no default chevron or card tap). A custom
  /// [trailing] action may still remain available, such as viewing history.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveTrailing =
        trailing ??
        (onTap == null ? null : const Icon(LucideIcons.chevronRight, size: 18));
    return RdCard(
      padding: bookFieldCardContentPadding,
      onTap: onTap,
      child: BookFieldRow(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: effectiveTrailing,
      ),
    );
  }
}
