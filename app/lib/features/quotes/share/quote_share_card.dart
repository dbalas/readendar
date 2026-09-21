import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/features/quotes/share/quote_card_styles.dart';

/// Logical size of the exported card (captured at 3× → 1080×1350 px, the 4:5
/// portrait ratio share sheets prefer).
const kQuoteShareCardSize = Size(360, 450);

/// The shareable quote card, rendered at a FIXED size and captured to a PNG
/// via a RepaintBoundary above it. Self-contained brand art: identical output
/// in both app themes.
class QuoteShareCard extends StatelessWidget {
  const QuoteShareCard({
    required this.quote,
    required this.book,
    required this.style,
    super.key,
    this.includeNote = false,
  });

  final Quote quote;
  final Book? book;
  final QuoteCardStyle style;

  /// When true (and the quote has a note), the private note is rendered on the
  /// card. Off by default — the note stays private unless the user opts in.
  final bool includeNote;

  @override
  Widget build(BuildContext context) {
    final p = paletteFor(style);
    final coverUrl = book?.coverUrl;
    final author = (book?.authors ?? const []).join(', ');

    return SizedBox.fromSize(
      size: kQuoteShareCardSize,
      child: DecoratedBox(
        decoration: BoxDecoration(color: p.background, gradient: p.gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (style == QuoteCardStyle.coverGradient &&
                coverUrl != null &&
                coverUrl.isNotEmpty) ...[
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Image(
                  image: CachedNetworkImageProvider(coverUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              // Scrim so the paper-tone text always clears the artwork.
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xB3141326)),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branding top-left.
                  Row(
                    children: [
                      SvgPicture.asset(
                        'assets/icons/app-icon.svg',
                        width: 18,
                        height: 18,
                      ),
                      const SizedBox(width: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Read',
                              style: TextStyle(color: p.wordmarkPrefix),
                            ),
                            TextSpan(
                              text: 'endar',
                              style: TextStyle(color: p.wordmark),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontFamily: ReadendarTokens.fontUi,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Align(
                      child: Text(
                        quote.text,
                        maxLines: 9,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: ReadendarTokens.fontDisplay,
                          fontStyle: FontStyle.italic,
                          fontSize: quote.text.length > 220 ? 18 : 22,
                          height: 1.4,
                          color: p.text,
                        ),
                      ),
                    ),
                  ),
                  if (includeNote && quote.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      quote.note.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: ReadendarTokens.fontUi,
                        fontSize: 12,
                        height: 1.35,
                        color: p.attribution,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(width: 48, height: 2, color: p.rule),
                  const SizedBox(height: 12),
                  // Footer: cover + attribution. Wraps naturally to its size.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (coverUrl != null && coverUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image(
                            image: CachedNetworkImageProvider(coverUrl),
                            width: 34,
                            height: 51,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (author.isNotEmpty)
                              Text(
                                author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: ReadendarTokens.fontUi,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: p.text,
                                ),
                              ),
                            _AttributionLine(
                              bookTitle: book?.title,
                              quote: quote,
                              palette: p,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The book attribution line: title + page/chapter anchors with icons (no "p." or "cap." abbreviations).
/// Mirrors the app-wide visual language: `bookOpen` for page, `bookmark` for chapter.
class _AttributionLine extends StatelessWidget {
  const _AttributionLine({
    required this.bookTitle,
    required this.quote,
    required this.palette,
  });

  final String? bookTitle;
  final Quote quote;
  final QuoteCardPalette palette;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];

    void addSeparator() {
      if (spans.isNotEmpty) {
        spans.add(
          TextSpan(
            text: ' · ',
            style: TextStyle(color: palette.attribution),
          ),
        );
      }
    }

    void addIcon(IconData icon, String text) {
      addSeparator();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(icon, size: 11, color: palette.attribution),
          ),
        ),
      );
      spans.add(TextSpan(text: text));
    }

    if (bookTitle != null && bookTitle!.isNotEmpty) {
      spans.add(TextSpan(text: bookTitle));
    }
    if (quote.page != null) addIcon(LucideIcons.bookOpen, '${quote.page}');
    if (quote.chapter != null) {
      addIcon(LucideIcons.bookmark, '${quote.chapter}');
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontSize: 12,
        color: palette.attribution,
      ),
    );
  }
}
