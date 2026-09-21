import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/data/catalog/catalog_title.dart';

void main() {
  test('cleanTitle strips format suffixes and keeps series', () {
    const cases = <(String, String)>[
      ('Nieve (EBOOK)', 'Nieve'),
      ('Nieve (eBook)', 'Nieve'),
      ('Nieve [EBOOK]', 'Nieve'),
      ('Nieve (EPUB)', 'Nieve'),
      ('Nieve (Kindle)', 'Nieve'),
      ('Nieve (Edición Kindle)', 'Nieve'),
      ('Nieve (Audiolibro)', 'Nieve'),
      ('Nieve - EBOOK', 'Nieve'),
      ('Nieve / EPUB', 'Nieve'),
      ('Nieve EBOOK', 'Nieve'),
      ('Nieve (EBOOK) (EPUB)', 'Nieve'),
      ('Nieve (Tapa dura)', 'Nieve'),
      ('Sanguinaria (El Corazón 1)', 'Sanguinaria (El Corazón 1)'),
      ('Nieve', 'Nieve'),
      ('  Nieve (Kindle)  ', 'Nieve'),
      ('', ''),
      ('Cambiar (E-book)', 'Cambiar'),
      (
        'Anna Karénina (edición especial en tapa dura)',
        'Anna Karénina',
      ),
      (
        'Crímenes ilustrados - ¿Quién es el asesino? (Edición tapa blanda)',
        'Crímenes ilustrados - ¿Quién es el asesino?',
      ),
      (
        'El inversor inteligente (Edición tapa dura)',
        'El inversor inteligente',
      ),
      (
        'Inmune a ti (Kiss Me 3 - Off Campus 3) - Edición especial en tapa dura con cantos pintados',
        'Inmune a ti (Kiss Me 3 - Off Campus 3)',
      ),
      (
        'Una corona de huesos dorados - Edición Especial Limitada',
        'Una corona de huesos dorados',
      ),
      (
        'AVATAR 5 - La leyenda de Aang. Norte y sur - Edición en español',
        'AVATAR 5 - La leyenda de Aang. Norte y sur',
      ),
      (
        '50 lugares mágicos de Extremadura - edición ampliada',
        '50 lugares mágicos de Extremadura',
      ),
      ('Nieve (nueva edición)', 'Nieve'),
      ('Nieve (NOVA EDICIÓ)', 'Nieve'),
      ('Nieve (edición limitada · Black Friday)', 'Nieve'),
      ('Nieve (edición oficial en español)', 'Nieve'),
      ('HAIKYÛ!! (CATALÀ) Nº 19/45 (EBOOK)', 'HAIKYÛ!! Nº 19/45'),
      ('Doraemon nº 07/15 (català)', 'Doraemon nº 07/15'),
      (
        'Nausicaa Edició Col·leccionista (Català)',
        'Nausicaa Edició Col·leccionista',
      ),
      ('Nieve (edición ilustrada)', 'Nieve (edición ilustrada)'),
      ('Nieve (edición Luna)', 'Nieve (edición Luna)'),
      ('Nieve (Shônen)', 'Nieve (Shônen)'),
      ('Nieve (Novela gráfica)', 'Nieve (Novela gráfica)'),
      ('Nieve (6a Ed)', 'Nieve'),
      (
        "AMOR EN EL CAOS (THE DEVIL'S SONS 3) (EBOOK)",
        "AMOR EN EL CAOS (THE DEVIL'S SONS 3)",
      ),
    ];
    for (final (input, want) in cases) {
      expect(cleanTitle(input), want, reason: input);
    }
  });

  test('foldKey strips accents and punctuation', () {
    expect(foldKey('Peter Pan: Los inéditos'), 'peterpanlosineditos');
    expect(foldKey('J. M. Barrie'), 'jmbarrie');
  });
}
