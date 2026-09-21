import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';

/// Theme-native fill for a Reading Chapter story card.
///
/// Mixes the active theme canvas into [ReadendarColors.surface1], then tints
/// with that theme's accent / accent2. Never uses original-theme highlight
/// (amber) so Jade / Ocean / Noir cards don't look like leftover Original.
List<Color> readingChapterCardGradient({
  required String kind,
  required ReadendarColors colors,
  required List<Color> canvasColors,
  required Brightness brightness,
}) {
  final dark = brightness == Brightness.dark;
  final surface = colors.surface1;
  final canvasStart = canvasColors.first;
  final canvasEnd = canvasColors.length > 1 ? canvasColors.last : colors.bg;
  Color grounded(Color tint, double lightAlpha, double darkAlpha) =>
      Color.alphaBlend(
        tint.withValues(alpha: dark ? darkAlpha : lightAlpha),
        Color.alphaBlend(
          canvasStart.withValues(alpha: dark ? 0.48 : 0.32),
          surface,
        ),
      );
  final end = Color.alphaBlend(
    canvasEnd.withValues(alpha: dark ? 0.34 : 0.18),
    surface,
  );
  return switch (kind) {
    'archetype' => [
      colors.accent,
      Color.alphaBlend(colors.accent2.withValues(alpha: 0.48), colors.accent),
    ],
    'taste' || 'formatMix' => [grounded(colors.accent2, 0.20, 0.30), end],
    'reflection' => [grounded(colors.accent, 0.18, 0.26), end],
    _ => [grounded(colors.accent, 0.16, 0.24), end],
  };
}
