import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_card_art.dart';

const _kinds = [
  'coverMosaic',
  'totals',
  'rhythm',
  'comparison',
  'journey',
  'formatMix',
  'taste',
  'ratings',
  'archetype',
  'reflection',
  'summary',
];

void main() {
  test('card fills follow every theme canvas and never original highlight', () {
    for (final id in ReadendarThemeId.values) {
      for (final brightness in Brightness.values) {
        final definition = ReadendarThemes.byId(id);
        final colors = definition.colors(brightness);
        final canvas = definition.background(brightness).colors;
        final originalHighlight = ReadendarColors.of(brightness).highlightSoft;
        for (final kind in _kinds) {
          final fill = readingChapterCardGradient(
            kind: kind,
            colors: colors,
            canvasColors: canvas,
            brightness: brightness,
          );
          expect(fill, hasLength(2), reason: '$id $brightness $kind');
          expect(
            fill.contains(originalHighlight),
            isFalse,
            reason: '$id $brightness $kind leaked original highlight',
          );
          if (kind == 'archetype') {
            expect(fill.first, colors.accent, reason: '$id archetype accent');
          }
        }
      }
    }
  });

  test('jade and ocean fills differ from original on the same card kind', () {
    const kind = 'reflection';
    final original = readingChapterCardGradient(
      kind: kind,
      colors: ReadendarThemes.original.colors(Brightness.light),
      canvasColors: ReadendarThemes.original.lightBackground.colors,
      brightness: Brightness.light,
    );
    final jade = readingChapterCardGradient(
      kind: kind,
      colors: ReadendarThemes.jade.colors(Brightness.light),
      canvasColors: ReadendarThemes.jade.lightBackground.colors,
      brightness: Brightness.light,
    );
    final ocean = readingChapterCardGradient(
      kind: kind,
      colors: ReadendarThemes.ocean.colors(Brightness.light),
      canvasColors: ReadendarThemes.ocean.lightBackground.colors,
      brightness: Brightness.light,
    );
    expect(jade, isNot(original));
    expect(ocean, isNot(original));
    expect(jade, isNot(ocean));
  });
}
