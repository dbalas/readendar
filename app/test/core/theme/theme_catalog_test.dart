import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';

void main() {
  test('catalog has nineteen unique themes with Original first', () {
    expect(ReadendarThemes.all, hasLength(19));
    expect(ReadendarThemes.standard, hasLength(10));
    expect(ReadendarThemes.premium, hasLength(9));
    expect(ReadendarThemes.all.first.id, ReadendarThemeId.original);
    expect(
      ReadendarThemes.all.map((theme) => theme.id).toSet(),
      hasLength(19),
    );
    expect(
      ReadendarThemes.all.map((theme) => theme.id.wire),
      containsAll(<String>['celestial', 'velvet', 'jade', 'sapphire']),
    );
    expect(
      ReadendarThemes.all.map((theme) => theme.id.wire),
      isNot(contains(anyOf('forest', 'sepia', 'ember', 'sakura', 'copper'))),
    );
  });

  test('premium catalog owns nine complete animated identities', () {
    expect(ReadendarThemes.premium.map((theme) => theme.id), [
      ReadendarThemeId.ethereal,
      ReadendarThemeId.stormbound,
      ReadendarThemeId.evercourt,
      ReadendarThemeId.neonMoon,
      ReadendarThemeId.trail,
      ReadendarThemeId.serpents,
      ReadendarThemeId.thornCrown,
      ReadendarThemeId.iridescent,
      ReadendarThemeId.lastLight,
    ]);
    expect(
      ReadendarThemes.premium
          .map((theme) => theme.lightBackground.effect)
          .toSet(),
      {
        ReadendarBackgroundEffect.ethereal,
        ReadendarBackgroundEffect.stormbound,
        ReadendarBackgroundEffect.evercourt,
        ReadendarBackgroundEffect.neonMoon,
        ReadendarBackgroundEffect.trail,
        ReadendarBackgroundEffect.serpents,
        ReadendarBackgroundEffect.thornCrown,
        ReadendarBackgroundEffect.iridescent,
        ReadendarBackgroundEffect.lastLight,
      },
    );
    expect(
      ReadendarThemes.standard,
      isNot(contains(anyOf(ReadendarThemes.premium))),
    );
    final identity = ReadendarThemes.ethereal.identity;
    expect(identity.effect, ReadendarIdentityEffect.ethereal);
    expect(identity.readerReactive, isTrue);
    expect(identity.nativeArtwork, isTrue);
    expect(identity.fantasy, contains('celestial manuscript'));
    expect(
      ReadendarThemes.premium.map((theme) => theme.identity.effect).toSet(),
      hasLength(ReadendarThemes.premium.length),
    );
    expect(
      ReadendarThemes.premium.map((theme) => theme.identity.material).toSet(),
      hasLength(ReadendarThemes.premium.length),
    );
    for (final theme in ReadendarThemes.premium) {
      expect(theme.identity.effect, isNot(ReadendarIdentityEffect.none));
      expect(theme.identity.readerReactive, isTrue);
      expect(theme.identity.nativeArtwork, isTrue);
    }
  });

  test('Evercourt describes the three-star mountain identity', () {
    final identity = ReadendarThemes.evercourt.identity;

    expect(identity.fantasy, contains('mountain peak'));
    expect(identity.material, contains('moonlit stone'));
    expect(identity.motion, contains('three stars'));
    expect(identity.motion, contains('breathing slowly'));
    expect(identity.motion, contains('outer ridge'));
  });

  test('standard themes do not claim premium identity capabilities', () {
    for (final theme in ReadendarThemes.standard) {
      expect(theme.identity.effect, ReadendarIdentityEffect.none);
      expect(theme.identity.readerReactive, isFalse);
      expect(theme.identity.nativeArtwork, isFalse);
    }
  });

  test('unknown or removed persisted theme falls back to Original', () {
    expect(ReadendarThemeId.fromWire(null), ReadendarThemeId.original);
    expect(
      ReadendarThemeId.fromWire('retired-theme'),
      ReadendarThemeId.original,
    );
    for (final removed in [
      'forest',
      'sepia',
      'ember',
      'sakura',
      'copper',
      'solstice',
      'abyss',
      'illuminated',
      'ashen_crown',
      'cats',
      'dogs',
      'whisper',
    ]) {
      expect(
        ReadendarThemeId.fromWire(removed),
        ReadendarThemeId.original,
        reason: '$removed is no longer an offered theme',
      );
    }
  });

  test('Sapphire is chromatically distinct from Velvet', () {
    final sapphire = ReadendarThemes.sapphire;
    final velvet = ReadendarThemes.velvet;

    expect(sapphire.light.accent.b, greaterThan(sapphire.light.accent.r));
    expect(sapphire.dark.accent.b, greaterThan(sapphire.dark.accent.r));
    expect(velvet.light.accent.r, greaterThan(velvet.light.accent.b));
    expect(velvet.dark.accent.r, greaterThan(velvet.dark.accent.b));
  });

  test('every theme provides distinct light and dark semantic palettes', () {
    for (final definition in ReadendarThemes.all) {
      final light = buildLightTheme(themeId: definition.id);
      final dark = buildDarkTheme(themeId: definition.id);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.extension<ReadendarThemeSpec>()?.id, definition.id);
      expect(dark.extension<ReadendarThemeSpec>()?.id, definition.id);
      expect(light.extension<ReadendarColorsTheme>(), isNotNull);
      expect(dark.extension<ReadendarColorsTheme>(), isNotNull);
      expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
    }
  });

  test('Original preserves the canonical semantic colors', () {
    final light = buildLightTheme();
    final dark = buildDarkTheme();
    expect(
      light.extension<ReadendarColorsTheme>()?.colors.accentSoftBg,
      ReadendarColors.light.accentSoftBg,
    );
    expect(
      dark.extension<ReadendarColorsTheme>()?.colors.success,
      ReadendarColors.dark.success,
    );
  });

  test('semantic text and control pairs meet accessible contrast', () {
    for (final definition in ReadendarThemes.all) {
      for (final brightness in Brightness.values) {
        final colors = definition.colors(brightness);
        expect(
          _contrast(colors.fg1, colors.bg),
          greaterThanOrEqualTo(4.5),
          reason: '${definition.id.name} ${brightness.name}: fg1 on bg',
        );
        expect(
          _contrast(colors.fg2, colors.surface1),
          greaterThanOrEqualTo(4.5),
          reason: '${definition.id.name} ${brightness.name}: fg2 on surface',
        );
        expect(
          _contrast(colors.fgOnAccent, colors.accent),
          greaterThanOrEqualTo(3),
          reason: '${definition.id.name} ${brightness.name}: accent control',
        );
      }
    }
  });

  test('theme depth stays flat and restrained', () {
    for (final definition in ReadendarThemes.all) {
      expect(
        definition.style.overlayElevation,
        lessThanOrEqualTo(6),
        reason: '${definition.id.name}: overlay elevation',
      );
      expect(
        definition.style.cardShadow,
        isEmpty,
        reason: '${definition.id.name}: custom card shadows',
      );
    }
  });

  test('theme extensions interpolate colors, grain, and radii', () {
    final from = buildLightTheme(themeId: ReadendarThemeId.jade);
    final to = buildLightTheme(themeId: ReadendarThemeId.aurora);
    final middle = ThemeData.lerp(from, to, 0.25);
    final fromSpec = from.extension<ReadendarThemeSpec>()!;
    final toSpec = to.extension<ReadendarThemeSpec>()!;
    final middleSpec = middle.extension<ReadendarThemeSpec>()!;
    final middleStyle = middle.extension<ReadendarComponentStyle>()!;

    expect(
      middleSpec.background.colors.first,
      isNot(fromSpec.background.colors.first),
    );
    expect(
      middleSpec.background.colors.first,
      isNot(toSpec.background.colors.first),
    );
    expect(middleSpec.background.grainOpacity, closeTo(0.01, 0.0001));
    expect(middleStyle.cardRadius, closeTo(19.5, 0.0001));
  });

  test('themes fall back to system fonts for missing glyphs', () {
    for (final theme in [
      buildLightTheme(),
      buildDarkTheme(),
      buildLightTheme(themeId: ReadendarThemeId.jade),
    ]) {
      expect(
        theme.textTheme.bodyLarge?.fontFamilyFallback,
        ReadendarTokens.fontFamilyFallback,
      );
      expect(
        theme.textTheme.headlineSmall?.fontFamilyFallback,
        ReadendarTokens.fontFamilyFallback,
      );
    }
  });
}

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
