import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/features/quotes/kindle/kindle_clippings.dart';
import 'package:readendar/features/quotes/kindle/kindle_match.dart';

import 'quotes_test_utils.dart';

const _sep = '==========';

String _entry(String header, String meta, String body) =>
    '$header\r\n$meta\r\n\r\n$body\r\n$_sep\r\n';

void main() {
  group('parseKindleClippings', () {
    test('parses Spanish + English highlights with page numbers', () {
      final content =
          '\u{FEFF}'
          '${_entry('Cien años de soledad (Gabriel García Márquez)', '- Tu subrayado en la página 9 | posición 120-122 | Añadido el lunes, 1 de enero de 2026', 'El mundo era tan reciente, que muchas cosas carecían de nombre.')}'
          '${_entry('Dune (Frank Herbert)', '- Your Highlight on page 45 | location 680-682 | Added on Monday, January 1, 2026', 'Fear is the mind-killer.')}';
      final r = parseKindleClippings(content);
      expect(r.clippings, hasLength(2));
      expect(r.clippings[0].title, 'Cien años de soledad');
      expect(r.clippings[0].author, 'Gabriel García Márquez');
      expect(r.clippings[0].page, 9);
      expect(
        r.clippings[0].text,
        'El mundo era tan reciente, que muchas cosas carecían de nombre.',
      );
      expect(r.clippings[1].page, 45);
    });

    test('location-only highlights import without a page', () {
      final content = _entry(
        'Rayuela (Julio Cortázar)',
        '- Tu subrayado en la posición 1520-1522 | Añadido el martes, 2 de enero de 2026',
        'Andábamos sin buscarnos pero sabiendo que andábamos para encontrarnos.',
      );
      final r = parseKindleClippings(content);
      expect(r.clippings.single.page, isNull);
    });

    test('notes import as note category; bookmarks are skipped', () {
      final content =
          '${_entry('Dune (Frank Herbert)', '- Your Note on page 45 | Added on Monday, January 1, 2026', 'my own thought')}'
          '${_entry('Dune (Frank Herbert)', '- Tu nota en la página 50 | Añadido el lunes', 'otra nota')}'
          '${'Dune (Frank Herbert)\n- Your Bookmark on page 12 | Added on Monday\n\n$_sep\n'}'
          '${_entry('Dune (Frank Herbert)', '- Ihre Markierung auf Seite 5 | Hinzugefügt am Montag', 'Die Angst tötet das Bewusstsein.')}';
      final r = parseKindleClippings(content);
      expect(r.skippedBookmarks, 1);
      expect(
        r.clippings.where((c) => c.category == AnnotationCategory.note),
        hasLength(2),
      );
      final highlight = r.clippings.singleWhere(
        (c) => c.category == AnnotationCategory.quote,
      );
      // German "Markierung" is a HIGHLIGHT, not a bookmark, and Seite → page.
      expect(highlight.text, 'Die Angst tötet das Bewusstsein.');
      expect(highlight.page, 5);
    });

    test('exact duplicates are dropped and counted', () {
      final e = _entry(
        'Dune (Frank Herbert)',
        '- Your Highlight on page 45 | Added on Monday',
        'Fear is the mind-killer.',
      );
      final r = parseKindleClippings(e + e);
      expect(r.clippings, hasLength(1));
      expect(r.duplicatesDropped, 1);
    });

    test('titles containing parentheses keep them (author = LAST group)', () {
      final content = _entry(
        '2666 (edición conmemorativa) (Roberto Bolaño)',
        '- Tu subrayado en la página 439 | Añadido el lunes',
        'Nadie presta atención a estos asesinatos.',
      );
      final c = parseKindleClippings(content).clippings.single;
      expect(c.title, '2666 (edición conmemorativa)');
      expect(c.author, 'Roberto Bolaño');
    });

    test('multi-line highlight bodies collapse to single-space text', () {
      final content = _entry(
        'Dune (Frank Herbert)',
        '- Your Highlight on page 45 | Added on Monday',
        'Fear is the\nmind-killer.',
      );
      expect(
        parseKindleClippings(content).clippings.single.text,
        'Fear is the mind-killer.',
      );
    });

    test('empty / junk input yields an empty result', () {
      expect(parseKindleClippings('').isEmpty, isTrue);
      expect(parseKindleClippings('random text with no separators').isEmpty, isTrue);
    });
  });

  group('matchKindleClippings', () {
    const clip = KindleClipping(
      title: 'Cien Anos de Soledad',
      author: 'Gabriel Garcia Marquez',
      text: 'q',
    );

    test('exact normalized title auto-matches (diacritics-insensitive)', () {
      final lib = [testBook()];
      final groups = matchKindleClippings(const [clip], lib);
      expect(groups.single.match?.id, 'b1');
      expect(groups.single.suggested, isFalse);
    });

    test('prefix title + author surname overlap is a SUGGESTED match', () {
      const c = KindleClipping(
        title: 'Cien años de soledad: edición conmemorativa',
        author: 'García Márquez, Gabriel',
        text: 'q',
      );
      final lib = [testBook()];
      final groups = matchKindleClippings(const [c], lib);
      expect(groups.single.match?.id, 'b1');
      expect(groups.single.suggested, isTrue);
    });

    test('close title WITHOUT author overlap stays unmatched', () {
      const c = KindleClipping(
        title: 'Cien años de soledad: edición conmemorativa',
        author: 'Otra Persona',
        text: 'q',
      );
      final lib = [testBook()];
      expect(matchKindleClippings(const [c], lib).single.match, isNull);
    });

    test('groups by source title, biggest group first', () {
      const c1 = KindleClipping(title: 'A', text: '1');
      const c2 = KindleClipping(title: 'B', text: '2');
      const c3 = KindleClipping(title: 'B', text: '3');
      final groups = matchKindleClippings(const [c1, c2, c3], []);
      expect(groups, hasLength(2));
      expect(groups.first.sourceTitle, 'B');
      expect(groups.first.clippings, hasLength(2));
    });

    test('normalize strips articles + punctuation', () {
      expect(normalizeKindleTitle('El Aleph'), 'aleph');
      expect(normalizeKindleTitle('The Great Gatsby!'), 'great gatsby');
      expect(normalizeKindleTitle('Rayuela'), normalizeKindleTitle('RAYUELA'));
    });

    test('German ß (and full diacritic map) normalize without crashing', () {
      // Regression: the à-è-ì-ò-ù run in the plain map dropped its leading 'a',
      // making ß index one past the end → RangeError on any German title.
      // ß maps 1:1 to 's' — consistency between both sides is what matters for
      // matching, not exact German 'ss' transliteration.
      expect(normalizeKindleTitle('Verwandlung: Straße'), 'verwandlung strase');
      expect(normalizeKindleTitle('Weiß'), 'weis');
      // Every accented char maps to plain ASCII (no throw, no residue).
      expect(
        normalizeKindleTitle('áàäâã éèëê íìïî óòöôõ úùüû ñ ç'),
        'aaaaa eeee iiii ooooo uuuu n c',
      );
    });

    test('a German title matches a library book despite ß', () {
      const c = KindleClipping(title: 'Die Straße', author: 'Kafka', text: 'q');
      final groups = matchKindleClippings(const [c], [
        testBook(title: 'Die Straße'),
      ]);
      expect(groups.single.match?.id, 'b1');
    });
  });
}
