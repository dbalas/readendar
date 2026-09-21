import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/quotes/ocr/ocr_capture.dart';
import 'package:readendar/features/quotes/ocr/ocr_compose.dart';

OcrLine _l(int index, String text) =>
    OcrLine(index: index, text: text, rect: Rect.zero);

void main() {
  group('composeOcrSelection', () {
    test('joins selected lines in reading order with spaces', () {
      final lines = [_l(0, 'El mundo era'), _l(1, 'tan reciente'), _l(2, 'ruido')];
      expect(
        composeOcrSelection(lines, {1, 0}),
        'El mundo era tan reciente',
      );
    });

    test('selection order does not matter, traversal index rules', () {
      final lines = [_l(0, 'primera'), _l(1, 'segunda'), _l(2, 'tercera')];
      expect(
        composeOcrSelection(lines, {2, 0, 1}),
        'primera segunda tercera',
      );
    });

    test('merges end-of-line hyphenation without a space', () {
      final lines = [_l(0, 'muchas cosas care-'), _l(1, 'cían de nombre')];
      expect(
        composeOcrSelection(lines, {0, 1}),
        'muchas cosas carecían de nombre',
      );
    });

    test('keeps a real hyphen when the line is the last selected', () {
      final lines = [_l(0, 'un guion final-')];
      expect(composeOcrSelection(lines, {0}), 'un guion final-');
    });

    test('skips empty/whitespace lines and trims', () {
      final lines = [_l(0, '  hola  '), _l(1, '   '), _l(2, 'mundo')];
      expect(composeOcrSelection(lines, {0, 1, 2}), 'hola mundo');
    });

    test('unselected lines are excluded', () {
      final lines = [_l(0, 'a'), _l(1, 'b'), _l(2, 'c')];
      expect(composeOcrSelection(lines, {0, 2}), 'a c');
    });

    test('empty selection yields an empty string', () {
      expect(composeOcrSelection([_l(0, 'x')], {}), '');
    });
  });

  group('normalizedBoxToPixels', () {
    test('scales a full-frame box to image pixels', () {
      expect(
        normalizedBoxToPixels(const Rect.fromLTRB(0, 0, 1, 1), 200, 100),
        const Rect.fromLTWH(0, 0, 200, 100),
      );
    });

    test('scales a partial box from top-left origin', () {
      expect(
        normalizedBoxToPixels(
          const Rect.fromLTWH(0.1, 0.2, 0.5, 0.25),
          1000,
          800,
        ),
        const Rect.fromLTWH(100, 160, 500, 200),
      );
    });
  });

  group('buildOcrLines', () {
    test('assigns traversal indices and pixel rects', () {
      final lines = buildOcrLines(
        lines: const [
          ('first', Rect.fromLTWH(0, 0, 1, 0.1)),
          ('second', Rect.fromLTWH(0, 0.1, 1, 0.1)),
        ],
        width: 100,
        height: 200,
      );
      expect(lines, hasLength(2));
      expect(lines[0].index, 0);
      expect(lines[0].text, 'first');
      expect(lines[0].rect, const Rect.fromLTWH(0, 0, 100, 20));
      expect(lines[1].index, 1);
      expect(lines[1].text, 'second');
      expect(lines[1].rect, const Rect.fromLTWH(0, 20, 100, 20));
    });
  });

  group('preferredOcrLanguages', () {
    test('puts the app language first and dedupes by language code', () {
      expect(
        preferredOcrLanguages(const Locale('fr', 'CA')).map((l) => l.languageCode),
        ['fr', 'es', 'ca', 'en', 'de', 'it', 'pt', 'nl', 'pl', 'tr', 'sv', 'da', 'nb', 'fi'],
      );
    });
  });
}
