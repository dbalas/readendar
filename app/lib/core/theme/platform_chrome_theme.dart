import 'package:flutter/material.dart';

import 'package:readendar/core/theme/icon_fonts.dart';
import 'package:readendar/core/theme/tokens.dart';

/// Applies Apple-platform chrome tweaks on top of the shared brand themes:
/// no Material splash, and pill-shaped button geometry.
///
/// Call after `buildLightTheme` / `buildDarkTheme`. On Android/other platforms
/// this is a no-op so Material shapes stay as authored in those themes.
ThemeData withCupertinoSplashSuppressed(ThemeData theme) {
  final p = theme.platform;
  if (p != TargetPlatform.iOS && p != TargetPlatform.macOS) {
    return theme;
  }

  final cs = theme.colorScheme;
  final pill = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
  );

  return theme.copyWith(
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    actionIconTheme: rdCupertinoActionIconTheme(),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        disabledBackgroundColor: cs.primary.withValues(alpha: 0.35),
        disabledForegroundColor: cs.onPrimary.withValues(alpha: 0.8),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: pill,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        side: BorderSide(color: cs.outline),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: pill,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cs.primary,
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: pill,
      ),
    ),
  );
}
