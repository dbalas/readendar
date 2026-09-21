import 'package:flutter/material.dart';

import 'package:readendar/core/theme/tokens.dart';

class ReadendarTextStyles {
  ReadendarTextStyles._();

  static const _fallback = ReadendarTokens.fontFamilyFallback;

  static TextTheme build({required Color fg, required Color fg2}) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: ReadendarTokens.fontDisplay,
        fontFamilyFallback: _fallback,
        fontSize: 60,
        fontWeight: FontWeight.w600,
        height: 1.1,
        letterSpacing: -1.2,
        color: fg,
      ),
      displayMedium: TextStyle(
        fontFamily: ReadendarTokens.fontDisplay,
        fontFamilyFallback: _fallback,
        fontSize: 44,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.9,
        color: fg,
      ),
      displaySmall: TextStyle(
        fontFamily: ReadendarTokens.fontDisplay,
        fontFamilyFallback: _fallback,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.7,
        color: fg,
      ),
      headlineLarge: TextStyle(
        fontFamily: ReadendarTokens.fontDisplay,
        fontFamilyFallback: _fallback,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.6,
        color: fg,
      ),
      headlineMedium: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: fg,
      ),
      headlineSmall: TextStyle(
        fontFamily: ReadendarTokens.fontDisplay,
        fontFamilyFallback: _fallback,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.15,
        letterSpacing: -0.3,
        color: fg,
      ),
      titleLarge: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: fg,
      ),
      titleMedium: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
      titleSmall: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
      bodyLarge: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 17,
        height: 1.6,
        color: fg,
      ),
      bodyMedium: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 15,
        height: 1.45,
        color: fg,
      ),
      bodySmall: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 13,
        height: 1.45,
        color: fg2,
      ),
      labelLarge: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
      labelMedium: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.4,
        color: fg2,
      ),
      labelSmall: TextStyle(
        fontFamily: ReadendarTokens.fontUi,
        fontFamilyFallback: _fallback,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
        color: fg2,
      ),
    );
  }

  /// Shared label for grouped app content. Callers own layout, not typography.
  static TextStyle sectionLabel({required Color color}) => TextStyle(
    fontFamily: ReadendarTokens.fontUi,
    fontFamilyFallback: _fallback,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 1.4,
    color: color,
  );

  /// Shared long-form reading voice for synopsis and excerpt content.
  static TextStyle editorialBody({required Color color}) => TextStyle(
    fontFamily: ReadendarTokens.fontDisplay,
    fontFamilyFallback: _fallback,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: color,
  );
}
