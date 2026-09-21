import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/annotation_category_style.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/quotes/share/quote_card_styles.dart';
import 'package:readendar/features/quotes/share/quote_share_card.dart';
import 'package:readendar/features/quotes/share/quote_share_render.dart';
import 'package:share_plus/share_plus.dart';

/// Preview-and-share sheet: a swipeable carousel of the card styles plus the
/// two output actions (styled image / bibliographic text).
Future<void> openQuoteShareSheet(
  BuildContext context, {
  required Quote quote,
  required Book? book,
}) {
  return showRdModalSheet<void>(
    context: context,
    builder: (_) => _QuoteShareSheet(quote: quote, book: book),
  );
}

class _QuoteShareSheet extends ConsumerStatefulWidget {
  const _QuoteShareSheet({required this.quote, required this.book});
  final Quote quote;
  final Book? book;

  @override
  ConsumerState<_QuoteShareSheet> createState() => _QuoteShareSheetState();
}

class _QuoteShareSheetState extends ConsumerState<_QuoteShareSheet> {
  final _pageController = PageController(viewportFraction: 0.82);
  final Map<QuoteCardStyle, GlobalKey<State<StatefulWidget>>> _boundaryKeys = {
    for (final s in QuoteCardStyle.values)
      s: GlobalKey(debugLabel: 'quote-card-$s'),
  };
  int _page = 0;
  bool _sharing = false;
  bool _coverPrecached = false;

  /// Whether the private note rides along in the shared card/text. Off by
  /// default — the note stays private unless the user opts in here.
  bool _includeNote = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Warm the cover before capture so the exported PNG never ships a
    // half-loaded image; failure just means cover-less cards.
    final coverUrl = widget.book?.coverUrl;
    if (!_coverPrecached && coverUrl != null && coverUrl.isNotEmpty) {
      _coverPrecached = true;
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(coverUrl),
          context,
        ).catchError((Object _) {}),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Make sure the cover is decoded before the RepaintBoundary capture, so
      // a fast tap on first open can't export a card with a blank/placeholder
      // cover (precacheImage in didChangeDependencies is fire-and-forget).
      final coverUrl = widget.book?.coverUrl;
      if (coverUrl != null && coverUrl.isNotEmpty && mounted) {
        await precacheImage(
          CachedNetworkImageProvider(coverUrl),
          context,
        ).catchError((Object _) {});
      }
      if (!mounted) return;
      const styles = QuoteCardStyle.values;
      await shareQuoteCardImage(_boundaryKeys[styles[_page]]!);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    const styles = QuoteCardStyle.values;
    if (_page >= styles.length) _page = 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AnnotationCategoryStyle.shareTitle(l, widget.quote.category),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 400,
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                for (final style in styles)
                  Center(
                    child: FittedBox(
                      // The card keeps its full 360×450 layout inside the
                      // boundary, so the capture is always full-resolution
                      // regardless of the carousel's on-screen scale.
                      child: RepaintBoundary(
                        key: _boundaryKeys[style],
                        child: QuoteShareCard(
                          quote: widget.quote,
                          book: widget.book,
                          style: style,
                          includeNote: _includeNote,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < styles.length; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? c.accent : c.line,
                  ),
                ),
            ],
          ),
          if (widget.quote.hasNote) ...[
            const SizedBox(height: 6),
            RdCheckboxListTile(
              value: _includeNote,
              onChanged: (v) => setState(() => _includeNote = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.quoteShareIncludeNote),
              subtitle: Text(
                l.quoteShareIncludeNoteHint,
                style: TextStyle(fontSize: 12, color: c.fg3),
              ),
            ),
            const SizedBox(height: 6),
          ] else
            const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: RdButton.secondary(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: formatQuoteShareText(
                        l,
                        widget.quote,
                        widget.book,
                        includeNote: _includeNote,
                      ),
                    ),
                  ),
                  icon: LucideIcons.letterText,
                  label: l.quoteShareText,
                  expand: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RdButton.primary(
                  onPressed: _sharing ? null : _shareImage,
                  loading: _sharing,
                  icon: LucideIcons.imageDown,
                  label: l.quoteShareImage,
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
