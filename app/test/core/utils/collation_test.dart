import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/collation.dart';

void main() {
  test('foldForSort strips diacritics and lowercases', () {
    expect(foldForSort('Ábaco'), 'abaco');
    expect(foldForSort('Ñandú'), 'nandu');
    expect(foldForSort('Über'), 'uber');
    expect(foldForSort('Straße'), 'strasse');
  });

  test('compareLocale orders accented Latin naturally', () {
    final titles = ['Zorro', 'Ábaco', 'Órbita', 'ñandú', 'ana'];
    titles.sort(compareLocale);
    // Ábaco → ana → ñandú → Órbita → Zorro (not code-unit order, which would
    // scatter the accented words to the end).
    expect(titles, ['Ábaco', 'ana', 'ñandú', 'Órbita', 'Zorro']);
  });

  test('compareLocale is stable for same-fold distinct spellings', () {
    expect(compareLocale('cafe', 'café'), isNot(0));
  });
}
