import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/annotation_category_style.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/annotation_markdown.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_context_menu.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_menu.dart';

/// One quote in a list: the passage in serif italic, the page/chapter anchor,
/// the favorite star, and an actions menu (edit / favorite / share / delete).
/// [highlighted] draws an accent border (deep-link landing).
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    required this.quote,
    super.key,
    this.bookLine,
    this.highlighted = false,
    this.card = true,
    this.accentFrame = true,
    this.onTap,
    this.onEdit,
    this.onTogglePin,
    this.onToggleFavorite,
    this.onShare,
    this.onDelete,
  });

  static const _bodyFontSize = 15.0;
  static const _bodyLineHeight = 1.3;
  static const _listPreviewLines = 3;
  static const _favoriteSlotWidth = 34.0;
  static const _categorySlotWidth = 20.0;
  static const _leadingGap = 8.0;
  static const _favoriteIconSize = 18.0;
  static const _categoryIconSize = 17.0;

  static TextStyle _bodyStyle(BuildContext context, {required bool isQuote}) {
    final c = context.colors;
    return TextStyle(
      fontFamily: isQuote ? ReadendarTokens.fontDisplay : null,
      fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
      fontSize: _bodyFontSize,
      height: _bodyLineHeight,
      color: c.fg1,
    );
  }

  final Annotation quote;

  /// "Autor · Título" line under the text; omit when the list is already
  /// grouped under a book header.
  final String? bookLine;
  final bool highlighted;

  /// When false, skip [RdCard] chrome (swipe rows own the card).
  final bool card;

  /// Pin / deep-link accent border. Set false when a parent (e.g.
  /// [RdListItemActions]) owns the frame so swipe actions stay inside it.
  final bool accentFrame;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onTogglePin;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  /// Shared pin / highlight border for list chrome that owns the card frame.
  static BorderSide? accentBorderSide(
    BuildContext context, {
    required bool pinned,
    required bool highlighted,
  }) {
    if (!highlighted && !pinned) return null;
    final c = context.colors;
    return BorderSide(
      color: highlighted ? c.accent : c.warningSoftFg,
      width: highlighted ? 2 : 1,
    );
  }

  /// The "p. 12 · cap. 3" anchor line, or null when unanchored.
  static String? anchorLabel(AppL10n l, Quote q) {
    final parts = [
      if (q.page != null) l.quotePageAbbrev(q.page!),
      if (q.chapter != null) l.quoteChapterAbbrev(q.chapter!),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  List<RdMenuItem<String>> _menuItems(AppL10n l) => [
    if (onEdit != null)
      RdMenuItem(
        value: 'edit',
        label: l.actionEdit,
        icon: LucideIcons.pencil,
      ),
    if (onShare != null)
      RdMenuItem(
        value: 'share',
        label: l.actionShare,
        icon: LucideIcons.share2,
      ),
    if (onTogglePin != null)
      RdMenuItem(
        value: 'pin',
        label: quote.pinned ? l.annotationUnpin : l.annotationPin,
        icon: quote.pinned ? LucideIcons.pinOff : LucideIcons.pin,
      ),
    if (onToggleFavorite != null)
      RdMenuItem(
        value: 'favorite',
        label: quote.favorite ? l.annotationUnfavorite : l.annotationFavorite,
        icon: quote.favorite ? LucideIcons.starOff : LucideIcons.star,
      ),
    if (onDelete != null)
      RdMenuItem(
        value: 'delete',
        label: l.actionDelete,
        icon: LucideIcons.trash2,
        destructive: true,
      ),
  ];

  void _onMenuSelected(String v) {
    switch (v) {
      case 'edit':
        onEdit?.call();
      case 'share':
        onShare?.call();
      case 'pin':
        onTogglePin?.call();
      case 'favorite':
        onToggleFavorite?.call();
      case 'delete':
        onDelete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final hasMeta =
        bookLine != null || quote.page != null || quote.chapter != null;
    final menuItems = _menuItems(l);
    final hasMenu = menuItems.isNotEmpty;
    final overflowItems = menuItems
        .where((i) => i.value != 'favorite')
        .toList(growable: false);
    final isQuote = quote.category == AnnotationCategory.quote;
    final bodyPreview = annotationMarkdownPreview(quote.body);
    final bodyStyle = _bodyStyle(context, isQuote: isQuote);
    const leadingInset = _favoriteSlotWidth + _categorySlotWidth + _leadingGap;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _LeadingRail(
                quote: quote,
                onToggleFavorite: onToggleFavorite,
                favoriteTooltip: quote.favorite
                    ? l.annotationUnfavorite
                    : l.annotationFavorite,
              ),
              const SizedBox(width: _leadingGap),
              Expanded(
                child: _ClampedBodyText(
                  text: isQuote ? '«$bodyPreview»' : bodyPreview,
                  style: bodyStyle,
                  maxLines: _listPreviewLines,
                ),
              ),
              if (overflowItems.isNotEmpty)
                RdOverflowMenu<String>(
                  tooltip: l.annotationActionsTooltip,
                  onSelected: _onMenuSelected,
                  items: overflowItems,
                ),
            ],
          ),
          if (hasMeta) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: leadingInset),
              child: _MetaLine(
                quote: quote,
                bookLine: bookLine,
              ),
            ),
          ],
          if (quote.hasNote) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: leadingInset),
              child: _NoteLine(note: quote.note),
            ),
          ],
        ],
      ),
    );
    final body = card
        ? RdCard(
            onTap: onTap,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: row,
          )
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: row,
              ),
            ),
          );
    final accent = accentFrame
        ? accentBorderSide(
            context,
            pinned: quote.pinned,
            highlighted: highlighted,
          )
        : null;
    final framed = accent == null
        ? body
        : Container(
            decoration: BoxDecoration(
              border: Border.fromBorderSide(accent),
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
            ),
            child: body,
          );
    if (!hasMenu) return framed;
    return RdContextMenu(
      items: menuItems,
      onSelected: _onMenuSelected,
      child: framed,
    );
  }
}

/// List preview clamped to [maxLines] with a visible trailing ellipsis.
class _ClampedBodyText extends StatelessWidget {
  const _ClampedBodyText({
    required this.text,
    required this.style,
    required this.maxLines,
  });

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Favorite + category icons, vertically centered with the annotation body.
class _LeadingRail extends StatelessWidget {
  const _LeadingRail({
    required this.quote,
    required this.onToggleFavorite,
    required this.favoriteTooltip,
  });

  final Annotation quote;
  final VoidCallback? onToggleFavorite;
  final String favoriteTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: QuoteCard._favoriteSlotWidth,
          child: onToggleFavorite == null
              ? const SizedBox.shrink()
              : RdIconButton.compact(
                  tooltip: favoriteTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: QuoteCard._favoriteSlotWidth,
                    minHeight: 32,
                  ),
                  onPressed: onToggleFavorite,
                  icon: quote.favorite ? LucideIcons.star : LucideIcons.starOff,
                  size: QuoteCard._favoriteIconSize,
                  color: quote.favorite ? ReadendarTokens.amberStar : c.fg3,
                ),
        ),
        SizedBox(
          width: QuoteCard._categorySlotWidth,
          child: Icon(
            AnnotationCategoryStyle.icon(quote.category),
            size: QuoteCard._categoryIconSize,
            color: AnnotationCategoryStyle.hue(quote.category),
          ),
        ),
      ],
    );
  }
}

/// The under-text meta line: optional "Autor · Título" plus the page/chapter
/// anchor rendered with the app-wide icon language — `bookOpen` for the page,
/// `bookmark` for the chapter (mirrors the book-detail progress subtitle), so
/// no "p." / "cap." abbreviations leak into the UI.
class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.quote,
    this.bookLine,
  });

  final Quote quote;
  final String? bookLine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = TextStyle(fontSize: 12, color: c.fg3);
    final parts = <Widget>[];

    // Decorative middle-dot between meta segments, rendered as a small filled
    // circle (not a Text literal — the no-hardcoded-text guard rejects those,
    // and a "·" glyph carries no translatable meaning anyway).
    void addSeparator() {
      if (parts.isNotEmpty) {
        parts.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.circle, size: 3, color: c.fgFaint),
          ),
        );
      }
    }

    void addAnchor(IconData icon, String text) {
      addSeparator();
      parts.add(Icon(icon, size: 12, color: c.fg3));
      parts.add(const SizedBox(width: 3));
      parts.add(Text(text, style: style));
    }

    if (bookLine != null) {
      addSeparator();
      parts.add(
        Flexible(
          child: Text(
            bookLine!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      );
    }
    if (quote.page != null) addAnchor(LucideIcons.bookOpen, '${quote.page}');
    if (quote.chapter != null) {
      addAnchor(LucideIcons.bookmark, '${quote.chapter}');
    }

    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}

/// The owner's private note under the passage: a sticky-note icon + the note
/// text on a tinted surface, so it reads as a personal annotation distinct from
/// the quote itself. Only rendered when the quote has a note.
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.stickyNote, size: 13, color: c.fg3),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, height: 1.3, color: c.fg2),
            ),
          ),
        ],
      ),
    );
  }
}
