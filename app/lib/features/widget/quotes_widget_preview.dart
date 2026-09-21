// In-app preview of the QUOTES home-screen widget, shown next to the events
// widget's preview in the add-widget flow AND live at the top of the quotes
// widget config screen. Mirrors the native renderers 1:1: a "READENDAR"
// wordmark header (same as the events widget), a serif-italic passage, the
// favorite star, and a footer with the book cover + title + author + page.
//
// The previewed quote is what the given [config] would show right now — the
// same mode filter + `bucket % n` rotation both native widgets and the daily
// notification use (see pickQuotesWidgetQuote), so every surface agrees.
//
// Data comes from the IN-APP quotes (quotesControllerProvider + booksById),
// resolved exactly like syncQuotesWidget pushes to the native cache.
//
// Keeping this in lockstep with ReadendarQuotesWidget.swift and
// ReadendarQuotesWidgetProvider.kt is deliberate: one config + snapshot
// contract, three renderers.

import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/cover_image.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/quotes/share/quote_card_styles.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:readendar/features/widget/widget_sync.dart';

/// Maps a [QuoteWidgetStyle] to the share-card palette it reuses, or null for
/// [QuoteWidgetStyle.auto] (which is theme-adaptive, not a fixed palette).
///
/// An EXHAUSTIVE switch on purpose: adding a [QuoteWidgetStyle] value without a
/// palette becomes a compile error here, instead of the runtime
/// `ArgumentError` a `QuoteCardStyle.values.byName(...)` lookup would throw when
/// the two enums drift. Shared by the preview and the config-screen swatches.
QuoteCardStyle? shareCardStyleFor(QuoteWidgetStyle style) => switch (style) {
  QuoteWidgetStyle.auto => null,
  QuoteWidgetStyle.lightElegant => QuoteCardStyle.lightElegant,
  QuoteWidgetStyle.minimal => QuoteCardStyle.minimal,
  QuoteWidgetStyle.dark => QuoteCardStyle.dark,
  QuoteWidgetStyle.coverGradient => QuoteCardStyle.coverGradient,
  QuoteWidgetStyle.gradientSunset => QuoteCardStyle.gradientSunset,
  QuoteWidgetStyle.gradientForest => QuoteCardStyle.gradientForest,
  QuoteWidgetStyle.gradientOcean => QuoteCardStyle.gradientOcean,
  QuoteWidgetStyle.gradientDusk => QuoteCardStyle.gradientDusk,
  QuoteWidgetStyle.parchment => QuoteCardStyle.parchment,
  QuoteWidgetStyle.mist => QuoteCardStyle.mist,
  QuoteWidgetStyle.pine => QuoteCardStyle.pine,
  QuoteWidgetStyle.honey => QuoteCardStyle.honey,
  QuoteWidgetStyle.noirGold => QuoteCardStyle.noirGold,
};

/// The resolved appearance of the previewed widget for one [QuoteWidgetStyle]
/// (and, for [QuoteWidgetStyle.coverGradient], the current quote's cover). The
/// single place the preview decides colours, so the frame, wordmark, body and
/// state messages all agree. Mirrors the palette the native renderers derive
/// from the same style wire string.
class _WidgetPalette {
  const _WidgetPalette({
    required this.background,
    required this.text,
    required this.meta,
    required this.wordmarkRead,
    required this.wordmarkEndar,
    required this.star,
    this.gradient,
    this.coverBlurUrl,
  });

  /// The theme-adaptive appearance ([QuoteWidgetStyle.auto]) — identical to
  /// what the preview rendered before styles existed.
  factory _WidgetPalette.auto(ReadendarColors c) => _WidgetPalette(
    background: c.surface1,
    text: c.fg1,
    meta: c.fg3,
    wordmarkRead: c.accent,
    wordmarkEndar: c.fg3,
    star: ReadendarTokens.amberStar,
  );

  /// A fixed brand palette, reusing the share card's [paletteFor] so the widget
  /// and the shared image read as the same styles. Only called for non-[QuoteWidgetStyle.auto]
  /// styles, so [shareCardStyleFor] is non-null.
  factory _WidgetPalette.preset(QuoteWidgetStyle style, {String? coverUrl}) {
    final p = paletteFor(shareCardStyleFor(style)!);
    return _WidgetPalette(
      background: p.background,
      gradient: p.gradient,
      coverBlurUrl:
          style == QuoteWidgetStyle.coverGradient &&
              (coverUrl?.isNotEmpty ?? false)
          ? coverUrl
          : null,
      text: p.text,
      meta: p.attribution,
      wordmarkRead: p.wordmarkPrefix,
      wordmarkEndar: p.wordmark,
      star: ReadendarTokens.amberStar,
    );
  }

  factory _WidgetPalette.resolve(
    ReadendarColors c,
    QuoteWidgetStyle style, {
    String? coverUrl,
  }) => style.isAuto
      ? _WidgetPalette.auto(c)
      : _WidgetPalette.preset(style, coverUrl: coverUrl);

  final Color background;
  final Gradient? gradient;

  /// When set, a blurred cover fills the card behind a dark scrim
  /// ([QuoteWidgetStyle.coverGradient]).
  final String? coverBlurUrl;

  final Color text;
  final Color meta;
  final Color wordmarkRead;
  final Color wordmarkEndar;
  final Color star;
}

/// Deterministic DAILY rotation pick, kept for the daily-quote notification
/// (which is always daily over the whole list): the candidate at `epochDay % n`
/// over the stable newest-first list, where the day is the LOCAL epoch day.
/// The general, config-aware pick lives in [pickQuotesWidgetQuote].
int dailyRotationIndex(int candidateCount, DateTime now) {
  if (candidateCount <= 0) return 0;
  final localMillis =
      now.millisecondsSinceEpoch + now.timeZoneOffset.inMilliseconds;
  return (localMillis ~/ Duration.millisecondsPerDay) % candidateCount;
}

/// Device-like framed preview of the quotes widget for a given [config].
/// Renders from the in-app quotes, handling loading / empty itself (mirroring
/// the native empty state). Defaults to the "rotate all, daily" config so the
/// widget hub shows a representative example.
class QuotesWidgetPreview extends ConsumerWidget {
  const QuotesWidgetPreview({
    this.config = const QuotesWidgetConfig(),
    super.key,
  });

  final QuotesWidgetConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final quotesAsync = ref.watch(quotesControllerProvider);
    // Base palette (no cover) for the loading/error frames, which have no quote.
    final base = _WidgetPalette.resolve(c, config.style);
    return switch (quotesAsync) {
      AsyncData() => _resolvedBody(ref, l, c),
      AsyncError() => _Frame(
        palette: base,
        child: _StateMessage(
          icon: LucideIcons.wifiOff,
          text: l.widgetPreviewError,
          color: config.style.isAuto ? c.danger : base.text,
        ),
      ),
      _ => _Frame(
        palette: base,
        child: _LoadingBody(palette: base),
      ),
    };
  }

  Widget _resolvedBody(WidgetRef ref, AppL10n l, ReadendarColors c) {
    final resolved = resolveWidgetQuotes(<T>(p) => ref.watch(p)) ?? const [];
    final quote = pickQuotesWidgetQuote(resolved, config, DateTime.now());
    final palette = _WidgetPalette.resolve(
      c,
      config.style,
      coverUrl: quote?.bookCoverUrl,
    );
    if (quote == null) {
      return _Frame(
        palette: palette,
        child: _WordmarkFrame(
          palette: palette,
          child: _StateMessage(icon: LucideIcons.quote, color: palette.meta),
        ),
      );
    }
    return _Frame(
      palette: palette,
      child: _WordmarkFrame(
        palette: palette,
        child: _QuoteBody(
          quote: quote,
          palette: palette,
          showNote: config.showNote,
        ),
      ),
    );
  }
}

/// Same widget-tile shell as the events preview so both read as siblings. The
/// outer gradient border is the theme-based "home screen" chrome; the inner
/// card adopts the chosen [palette] (solid / gradient / blurred cover).
class _Frame extends StatelessWidget {
  const _Frame({required this.child, required this.palette});
  final Widget child;
  final _WidgetPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const cardRadius = 20.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accentSoftBg, c.accent2SoftBg],
        ),
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.background,
          gradient: palette.gradient,
          borderRadius: BorderRadius.circular(cardRadius),
          border: Border.all(color: c.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: -8,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cardRadius),
          child: Stack(
            children: [
              if (palette.coverBlurUrl != null) ...[
                Positioned.fill(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Image(
                      image: CachedNetworkImageProvider(palette.coverBlurUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                // Scrim so the paper-tone text always clears the artwork.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ReadendarTokens.coverScrim,
                    ),
                  ),
                ),
              ],
              Padding(padding: const EdgeInsets.all(14), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The brand header ("READENDAR" wordmark) above the content, matching the
/// events widget's header and both native quotes renderers.
class _WordmarkFrame extends StatelessWidget {
  const _WordmarkFrame({required this.child, required this.palette});
  final Widget child;
  final _WidgetPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [QuotesBrandWordmark._(palette: palette)]),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// "READ" in accent + "ENDAR" muted — identical to the events preview wordmark
/// and both native renderers, so all Readendar widgets share one brand mark.
/// A palette override keeps the wordmark legible on the
/// preset backgrounds.
class QuotesBrandWordmark extends StatelessWidget {
  const QuotesBrandWordmark({super.key}) : _palette = null;
  const QuotesBrandWordmark._({required this._palette});

  final _WidgetPalette? _palette;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final read = _palette?.wordmarkRead ?? c.accent;
    final endar = _palette?.wordmarkEndar ?? c.fg3;
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        children: [
          TextSpan(
            text: 'READ',
            style: TextStyle(color: read),
          ),
          TextSpan(
            text: 'ENDAR',
            style: TextStyle(color: endar),
          ),
        ],
      ),
    );
  }
}

/// The quote card body: passage + footer (cover chip, book line, star). Colours
/// come from the resolved [palette] so it reads correctly on every style.
class _QuoteBody extends StatelessWidget {
  const _QuoteBody({
    required this.quote,
    required this.palette,
    this.showNote = false,
  });
  final WidgetQuote quote;
  final _WidgetPalette palette;

  /// Whether the config opted to render the private note (mirrors
  /// `QuotesWidgetConfig.showNote`).
  final bool showNote;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final withNote = showNote && quote.note.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '«${quote.text}»',
          maxLines: withNote ? 2 : 4,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: ReadendarTokens.fontDisplay,
            fontStyle: FontStyle.italic,
            fontSize: 16,
            height: 1.35,
            color: palette.text,
          ),
        ),
        if (withNote) ...[
          const SizedBox(height: 6),
          Text(
            quote.note.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.3, color: palette.meta),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            _MiniCover(title: quote.bookTitle, coverUrl: quote.bookCoverUrl),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  Text(
                    [
                      if (quote.bookAuthor.isNotEmpty) quote.bookAuthor,
                      if (quote.page != null) l.quotePageAbbrev(quote.page!),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: palette.meta),
                  ),
                ],
              ),
            ),
            if (quote.favorite)
              Icon(Icons.star_rounded, size: 16, color: palette.star),
          ],
        ),
      ],
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.title, required this.coverUrl});
  final String title;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 24,
      height: 34,
      color: ReadendarTokens.periwinkle600,
      alignment: Alignment.center,
      child: Text(
        title.isEmpty ? '?' : title.characters.first.toUpperCase(),
        style: const TextStyle(
          color: ReadendarTokens.paper50,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 24,
        height: 34,
        child: RemoteCoverImage(
          url: coverUrl,
          tier: CoverDisplayTier.thumb,
          placeholder: fallback,
          error: fallback,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, this.text, this.color});
  final IconData icon;

  /// Null → the localized "add your first quote" empty message.
  final String? text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final resolvedColor = color ?? c.fg3;
    final label = text ?? AppL10n.of(context).quotesWidgetPreviewEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: resolvedColor),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: resolvedColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.palette});
  final _WidgetPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // On a preset background the theme `line` can vanish — tint the skeleton
    // bars from the palette text so they stay visible on dark/gradient cards.
    final barColor =
        palette.gradient != null ||
            palette.coverBlurUrl != null ||
            palette.background.computeLuminance() < 0.5
        ? palette.text.withValues(alpha: 0.25)
        : c.line;
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
    return Column(
      key: const Key('quotesWidgetPreviewLoading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar(double.infinity, 12),
        const SizedBox(height: 8),
        bar(180, 12),
        const SizedBox(height: 14),
        bar(120, 8),
      ],
    );
  }
}
