import 'package:flutter/material.dart';

import 'package:readendar/core/theme/banner_presets.dart';
import 'package:readendar/core/theme/tokens.dart';

/// The share-card visual styles offered in the preview carousel. Card colors
/// are deliberate brand CONSTANTS ("sticker" art per the theme convention):
/// the exported image must look identical regardless of the app theme.
///
/// Saturated `gradient*` styles reuse home banner presets (see [bannerPresets]).
/// The remaining styles are unique solid / paper treatments so adjacent
/// carousel cards never read as near-duplicates.
enum QuoteCardStyle {
  lightElegant,
  minimal,
  dark,
  coverGradient,
  gradientSunset,
  gradientForest,
  gradientOcean,
  gradientDusk,
  parchment,
  mist,
  pine,
  honey,
  noirGold,
}

class QuoteCardPalette {
  const QuoteCardPalette({
    required this.background,
    required this.text,
    required this.attribution,
    required this.rule,
    required this.wordmark,
    required this.wordmarkPrefix,
    this.gradient,
  });

  final Color background;

  /// When set, painted instead of the solid [background] (still used as the
  /// fallback fill under the gradient).
  final Gradient? gradient;

  final Color text;
  final Color attribution;
  final Color rule;

  /// Colour of the "endar" wordmark suffix.
  final Color wordmark;

  /// Colour of the "Read" wordmark prefix — the brand primary on light cards,
  /// a legible paper tone on the saturated / dark ones.
  final Color wordmarkPrefix;
}

/// The gradient for one of the reused banner presets.
Gradient _preset(String id) => bannerPresetOrDefault(id).gradient!;

QuoteCardPalette paletteFor(QuoteCardStyle style) => switch (style) {
  // Warm cream paper, soft grey rule.
  QuoteCardStyle.lightElegant => const QuoteCardPalette(
    background: ReadendarTokens.paper100,
    text: ReadendarTokens.ink900,
    attribution: ReadendarTokens.paper700,
    rule: ReadendarTokens.paper400,
    wordmark: ReadendarTokens.ink700,
    wordmarkPrefix: ReadendarTokens.periwinkle600,
  ),
  // Stark white, bold periwinkle accent rule (reads cooler than lightElegant).
  QuoteCardStyle.minimal => const QuoteCardPalette(
    background: ReadendarTokens.paper50,
    text: ReadendarTokens.ink900,
    attribution: ReadendarTokens.paper600,
    rule: ReadendarTokens.periwinkle500,
    wordmark: ReadendarTokens.ink700,
    wordmarkPrefix: ReadendarTokens.periwinkle600,
  ),
  // Near-black with periwinkle brand mark.
  QuoteCardStyle.dark => const QuoteCardPalette(
    background: ReadendarTokens.ink900,
    text: ReadendarTokens.paper100,
    attribution: ReadendarTokens.paper500,
    rule: ReadendarTokens.paper800,
    wordmark: ReadendarTokens.paper300,
    wordmarkPrefix: ReadendarTokens.periwinkle400,
  ),
  // Text sits on a dark scrim over the blurred cover.
  QuoteCardStyle.coverGradient => const QuoteCardPalette(
    background: ReadendarTokens.periwinkle900,
    text: ReadendarTokens.paper50,
    attribution: ReadendarTokens.paper300,
    rule: ReadendarTokens.paper300,
    wordmark: ReadendarTokens.paper200,
    wordmarkPrefix: ReadendarTokens.paper50,
  ),
  // Wine → amber heat.
  QuoteCardStyle.gradientSunset => QuoteCardPalette(
    background: ReadendarTokens.wine500,
    gradient: _preset('sunset'),
    text: ReadendarTokens.paper50,
    attribution: ReadendarTokens.paper200,
    rule: ReadendarTokens.paper200,
    wordmark: ReadendarTokens.paper200,
    wordmarkPrefix: ReadendarTokens.paper50,
  ),
  // Teal → sage canopy.
  QuoteCardStyle.gradientForest => QuoteCardPalette(
    background: ReadendarTokens.teal500,
    gradient: _preset('forest'),
    text: ReadendarTokens.paper50,
    attribution: ReadendarTokens.paper200,
    rule: ReadendarTokens.paper200,
    wordmark: ReadendarTokens.paper200,
    wordmarkPrefix: ReadendarTokens.paper50,
  ),
  // Periwinkle → teal cool water.
  QuoteCardStyle.gradientOcean => QuoteCardPalette(
    background: ReadendarTokens.periwinkle500,
    gradient: _preset('ocean'),
    text: ReadendarTokens.paper50,
    attribution: ReadendarTokens.paper200,
    rule: ReadendarTokens.paper200,
    wordmark: ReadendarTokens.paper200,
    wordmarkPrefix: ReadendarTokens.paper50,
  ),
  // Periwinkle → wine twilight.
  QuoteCardStyle.gradientDusk => QuoteCardPalette(
    background: ReadendarTokens.periwinkle500,
    gradient: _preset('dusk'),
    text: ReadendarTokens.paper50,
    attribution: ReadendarTokens.paper200,
    rule: ReadendarTokens.paper200,
    wordmark: ReadendarTokens.paper200,
    wordmarkPrefix: ReadendarTokens.paper50,
  ),
  // Warm papyrus scroll (not a saturated gradient).
  QuoteCardStyle.parchment => const QuoteCardPalette(
    background: ReadendarTokens.paperCanvas,
    text: ReadendarTokens.ink900,
    attribution: ReadendarTokens.ink400,
    rule: ReadendarTokens.amber600,
    wordmark: ReadendarTokens.ink600,
    wordmarkPrefix: ReadendarTokens.wine600,
  ),
  // Soft lavender wash, dark ink type.
  QuoteCardStyle.mist => const QuoteCardPalette(
    background: ReadendarTokens.periwinkle100,
    text: ReadendarTokens.ink800,
    attribution: ReadendarTokens.periwinkle700,
    rule: ReadendarTokens.periwinkle500,
    wordmark: ReadendarTokens.ink600,
    wordmarkPrefix: ReadendarTokens.periwinkle700,
  ),
  // Deep teal solid (forest without the sage fade).
  QuoteCardStyle.pine => const QuoteCardPalette(
    background: ReadendarTokens.teal800,
    text: ReadendarTokens.paper50,
    attribution: ReadendarTokens.teal200,
    rule: ReadendarTokens.teal400,
    wordmark: ReadendarTokens.teal100,
    wordmarkPrefix: ReadendarTokens.paper50,
  ),
  // Soft honey paper, dark type (warm light, not ember heat).
  QuoteCardStyle.honey => const QuoteCardPalette(
    background: ReadendarTokens.amber100,
    text: ReadendarTokens.ink900,
    attribution: ReadendarTokens.amber800,
    rule: ReadendarTokens.amber700,
    wordmark: ReadendarTokens.ink700,
    wordmarkPrefix: ReadendarTokens.amber800,
  ),
  // Cinematic wine-black + gold (not the plain ink dark).
  QuoteCardStyle.noirGold => const QuoteCardPalette(
    background: ReadendarTokens.wine900,
    text: ReadendarTokens.paper100,
    attribution: ReadendarTokens.paper400,
    rule: ReadendarTokens.amberStar,
    wordmark: ReadendarTokens.paper300,
    wordmarkPrefix: ReadendarTokens.amberStar,
  ),
};
