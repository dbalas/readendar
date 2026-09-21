import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/quotes/kindle/kindle_clippings.dart';
import 'package:readendar/features/quotes/kindle/kindle_match.dart';

import 'quotes_test_utils.dart';

KindleClipping _clip(String title, {String? author, String text = 'x'}) =>
    KindleClipping(title: title, author: author, text: text);

void main() {
  group('matchKindleClippings ordering', () {
    test('matched books sort above unmatched, more highlights first', () {
      final library = [
        testBook(title: 'Dune'),
      ];
      final clippings = <KindleClipping>[
        // Unmatched title with 3 highlights.
        _clip('Some Unknown Book', text: 'a'),
        _clip('Some Unknown Book', text: 'b'),
        _clip('Some Unknown Book', text: 'c'),
        // Matched title (Dune) with 1 highlight.
        _clip('Dune', author: 'Frank Herbert', text: 'fear'),
      ];

      final groups = matchKindleClippings(clippings, library);

      expect(groups, hasLength(2));
      // Matched group floats to the top even though it has fewer highlights.
      expect(groups.first.sourceTitle, 'Dune');
      expect(groups.first.match, isNotNull);
      expect(groups.last.sourceTitle, 'Some Unknown Book');
      expect(groups.last.match, isNull);
    });

    test('within the matched bucket, more highlights come first', () {
      final library = [
        testBook(title: 'Dune'),
        testBook(id: 'b2'),
      ];
      final clippings = <KindleClipping>[
        _clip('Dune', text: 'one'),
        _clip('Cien años de soledad', text: 'a'),
        _clip('Cien años de soledad', text: 'b'),
      ];

      final groups = matchKindleClippings(clippings, library);

      expect(groups.map((g) => g.sourceTitle).toList(), [
        'Cien años de soledad',
        'Dune',
      ]);
      expect(groups.every((g) => g.match != null), isTrue);
    });
  });
}
