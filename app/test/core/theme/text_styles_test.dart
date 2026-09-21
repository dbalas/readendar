import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/text_styles.dart';
import 'package:readendar/core/theme/tokens.dart';

void main() {
  group('ReadendarTextStyles editorial hierarchy', () {
    const fg = Color(0xFF101014);
    const fg2 = Color(0xFF404040);

    test('content titles share the Newsreader headline roles', () {
      final theme = ReadendarTextStyles.build(fg: fg, fg2: fg2);

      expect(theme.displayLarge?.fontWeight, FontWeight.w600);
      expect(theme.displaySmall?.fontFamily, ReadendarTokens.fontDisplay);
      expect(theme.displaySmall?.fontWeight, FontWeight.w600);
      expect(theme.headlineLarge?.fontFamily, ReadendarTokens.fontDisplay);
      expect(theme.headlineLarge?.fontWeight, FontWeight.w600);
      expect(theme.headlineSmall?.fontFamily, ReadendarTokens.fontDisplay);
      expect(theme.headlineSmall?.fontSize, 26);
      expect(theme.headlineSmall?.fontWeight, FontWeight.w600);
      expect(theme.headlineSmall?.height, 1.15);
    });

    test('section labels use one tracked uppercase-ready UI style', () {
      final style = ReadendarTextStyles.sectionLabel(color: fg);

      expect(style.fontFamily, ReadendarTokens.fontUi);
      expect(style.fontSize, 11.5);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 1.4);
      expect(style.color, fg);
    });

    test('long-form editorial content shares the Newsreader body role', () {
      final style = ReadendarTextStyles.editorialBody(color: fg);

      expect(style.fontFamily, ReadendarTokens.fontDisplay);
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.height, 1.55);
      expect(style.color, fg);
    });
  });
}
