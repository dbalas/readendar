import 'package:flutter/material.dart';

import 'package:readendar/core/theme/tokens.dart';

/// Brightness-resolved **semantic** colors — a 1:1 port of the semantic token
/// layer in `design/colors_and_type.css` (`--fg-1`, `--surface-1`, `--accent`,
/// `--danger-*`, …).
///
/// This is the single source of truth for any color that must differ between
/// light and dark. Widgets read `context.colors.fg2` instead of hard-coding a
/// raw palette token such as `ReadendarTokens.ink500`, so there is exactly one
/// definition per role and dark mode comes for free — no duplicated widgets,
/// no per-screen `if (isDark)` branches.
///
/// Raw palette tokens (`ReadendarTokens.periwinkle500`, spacing, radii, fonts)
/// still live in `tokens.dart`; use those for brightness-independent values and
/// for the brand hues that intentionally stay constant.
@immutable
class ReadendarColors {
  const ReadendarColors({
    required this.bg,
    required this.surface1,
    required this.surface2,
    required this.surfaceInv,
    required this.fg1,
    required this.fg2,
    required this.fg3,
    required this.fgFaint,
    required this.fgDisabled,
    required this.fgOnAccent,
    required this.fgLink,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentHover,
    required this.accentPress,
    required this.accentSoftBg,
    required this.accentSoftFg,
    required this.accent2,
    required this.accent2SoftBg,
    required this.accent2SoftFg,
    required this.highlight,
    required this.highlightSoft,
    required this.success,
    required this.successSoftBg,
    required this.successSoftFg,
    required this.warning,
    required this.warningSoftBg,
    required this.warningSoftFg,
    required this.danger,
    required this.dangerSoftBg,
    required this.dangerSoftFg,
  });

  // ─── Surfaces ──────────────────────────────────────────────
  /// App background (scaffold).
  final Color bg;

  /// Primary card / panel surface.
  final Color surface1;

  /// Nested / recessed surface.
  final Color surface2;

  /// Inverted surface (e.g. a dark chip on a light bg).
  final Color surfaceInv;

  // ─── Foreground (text + icons) ─────────────────────────────
  /// Primary text.
  final Color fg1;

  /// Secondary text.
  final Color fg2;

  /// Tertiary text.
  final Color fg3;

  /// Faintest text (hints, timestamps).
  final Color fgFaint;

  /// Disabled foreground.
  final Color fgDisabled;

  /// Text/icon sitting on top of [accent] (filled accent buttons).
  final Color fgOnAccent;

  /// Inline link color.
  final Color fgLink;

  // ─── Lines ─────────────────────────────────────────────────
  /// Hairline border / divider.
  final Color line;

  /// Stronger border.
  final Color lineStrong;

  // ─── Accent (periwinkle) ───────────────────────────────────
  final Color accent;
  final Color accentHover;
  final Color accentPress;

  /// Soft accent fill (chips, tinted cards).
  final Color accentSoftBg;

  /// Text/icon on top of [accentSoftBg].
  final Color accentSoftFg;

  // ─── Accent 2 (teal) ───────────────────────────────────────
  final Color accent2;
  final Color accent2SoftBg;
  final Color accent2SoftFg;

  // ─── Highlight (amber) ─────────────────────────────────────
  final Color highlight;
  final Color highlightSoft;

  // ─── Status: success / warning / danger ────────────────────
  final Color success;
  final Color successSoftBg;
  final Color successSoftFg;

  final Color warning;
  final Color warningSoftBg;
  final Color warningSoftFg;

  final Color danger;
  final Color dangerSoftBg;
  final Color dangerSoftFg;

  /// Light theme — warm papyrus canvas + white surfaces (CSS `:root`).
  static const light = ReadendarColors(
    bg: ReadendarTokens.paperCanvas,
    surface1: ReadendarTokens.paper50,
    surface2: ReadendarTokens.paper100,
    surfaceInv: ReadendarTokens.ink900,
    fg1: ReadendarTokens.ink900,
    fg2: ReadendarTokens.ink500,
    fg3: ReadendarTokens.ink400,
    fgFaint: ReadendarTokens.ink300,
    fgDisabled: Color(0x610F1014), // ink-900 @ 38%
    fgOnAccent: ReadendarTokens.paper50,
    fgLink: ReadendarTokens.periwinkle600,
    line: ReadendarTokens.paper300,
    lineStrong: ReadendarTokens.paper400,
    accent: ReadendarTokens.periwinkle500,
    accentHover: ReadendarTokens.periwinkle600,
    accentPress: ReadendarTokens.periwinkle700,
    accentSoftBg: ReadendarTokens.periwinkle50,
    accentSoftFg: ReadendarTokens.periwinkle700,
    accent2: ReadendarTokens.teal500,
    accent2SoftBg: ReadendarTokens.teal50,
    accent2SoftFg: ReadendarTokens.teal700,
    highlight: ReadendarTokens.amber500,
    highlightSoft: ReadendarTokens.amber100,
    success: ReadendarTokens.sage500,
    successSoftBg: ReadendarTokens.sage50,
    successSoftFg: ReadendarTokens.sage700,
    warning: ReadendarTokens.amber500,
    warningSoftBg: ReadendarTokens.amber50,
    warningSoftFg: ReadendarTokens.amber700,
    danger: ReadendarTokens.wine500,
    dangerSoftBg: ReadendarTokens.wine50,
    dangerSoftFg: ReadendarTokens.wine700,
  );

  /// Dark theme — deep cool ink, brighter periwinkle accent (CSS dark block).
  ///
  /// Deviations from the CSS dark block are deliberate corrections: `fgOnAccent`
  /// flips to dark ink (the dark accent is a light lavender, so white-on-it
  /// would be illegible — this matches `ColorScheme.dark.onPrimary`), `fgLink`
  /// brightens to periwinkle-300, and the teal/sage soft fills are derived from
  /// their own hue rather than the stray mauve value the CSS carried.
  static const dark = ReadendarColors(
    bg: ReadendarTokens.darkBg,
    surface1: ReadendarTokens.darkSurface1,
    surface2: ReadendarTokens.darkSurface2,
    surfaceInv: ReadendarTokens.paper50,
    fg1: ReadendarTokens.darkFg1,
    fg2: ReadendarTokens.darkFg2,
    fg3: ReadendarTokens.darkFg3,
    fgFaint: ReadendarTokens.darkFg3,
    fgDisabled: Color(0x61F2F2F5), // fg-1 @ 38%
    fgOnAccent: ReadendarTokens.ink900,
    fgLink: ReadendarTokens.periwinkle300,
    line: Color(0x1AF2F2F5), // fg-1 @ 10%
    lineStrong: Color(0x33F2F2F5), // fg-1 @ 20%
    accent: ReadendarTokens.periwinkle300,
    accentHover: ReadendarTokens.periwinkle200,
    accentPress: ReadendarTokens.periwinkle100,
    accentSoftBg: Color(0x29A8ADDD), // periwinkle-300 @ 16%
    accentSoftFg: ReadendarTokens.periwinkle200,
    accent2: ReadendarTokens.teal300,
    accent2SoftBg: Color(0x2964BCAC), // teal-300 @ 16%
    accent2SoftFg: ReadendarTokens.teal200,
    highlight: ReadendarTokens.amber400,
    highlightSoft: Color(0x2EE5A848), // amber-400 @ 18%
    success: ReadendarTokens.sage300,
    successSoftBg: Color(0x2982B373), // sage-300 @ 16%
    successSoftFg: ReadendarTokens.sage200,
    warning: ReadendarTokens.amber400,
    warningSoftBg: Color(0x29E5A848), // amber-400 @ 16%
    warningSoftFg: ReadendarTokens.amber200,
    danger: ReadendarTokens.wine300,
    dangerSoftBg: Color(0x2ED26669), // wine-300 @ 18%
    dangerSoftFg: ReadendarTokens.wine200,
  );

  static ReadendarColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

@immutable
class ReadendarColorsTheme extends ThemeExtension<ReadendarColorsTheme> {
  const ReadendarColorsTheme(this.colors);

  final ReadendarColors colors;

  @override
  ReadendarColorsTheme copyWith({ReadendarColors? colors}) =>
      ReadendarColorsTheme(colors ?? this.colors);

  @override
  ReadendarColorsTheme lerp(
    covariant ReadendarColorsTheme? other,
    double t,
  ) => other == null || t < 0.5 ? this : other;
}

/// `context.colors.fg2` — the ergonomic accessor used throughout the widget tree.
extension ReadendarColorsX on BuildContext {
  ReadendarColors get colors =>
      Theme.of(this).extension<ReadendarColorsTheme>()?.colors ??
      ReadendarColors.of(Theme.of(this).brightness);
}
