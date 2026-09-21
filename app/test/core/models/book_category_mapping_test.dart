import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/models/book_category_mapping.dart';

void main() {
  test('canonicalCategoryCodes matches backend ingest mapping', () {
    const cases = <(String, List<String>, List<String>)>[
      ('empty', [], []),
      (
        'compound',
        ['Science Fiction & Fantasy'],
        ['fantasy', 'science_fiction'],
      ),
      (
        'aliases collapse',
        ['SciFi', 'Science Fiction', 'Space Opera'],
        ['science_fiction'],
      ),
      (
        'multi label deduped',
        ['Fantasy', 'GameLit & LitRPG', 'Interactive Adventures'],
        ['fantasy', 'adventure'],
      ),
      (
        'phrase before generic',
        ['Juvenile Fiction', 'Literary Fiction'],
        ['literary_classics', 'children_young_adult'],
      ),
      (
        'alternate history stays fiction',
        ['Alternate History'],
        ['historical_fiction'],
      ),
      (
        'nonfiction topics',
        ['Psychology & Counseling', 'Health, Fitness & Dieting'],
        ['psychology', 'health_wellness'],
      ),
      ('noise and known', ['Kindle Store', 'Categories', 'Manga'], ['comics_manga']),
      ('noise only', ['Subjects'], []),
      (
        'unknown',
        ['Unmapped Shelf From Provider'],
        ['other'],
      ),
      (
        'words do not match inside other words',
        ['Transactional Analysis', 'Digital Displays'],
        ['psychology'],
      ),
      (
        'hierarchical general fiction',
        ['Fiction / General'],
        ['fiction'],
      ),
      (
        'spanish science fiction',
        ['Ciencia ficción'],
        ['science_fiction'],
      ),
      (
        'spanish science fiction film',
        ['cine de ciencia ficción'],
        ['science_fiction'],
      ),
      (
        'spanish fiction is not sci-fi',
        ['Ficción'],
        ['fiction'],
      ),
      (
        'spanish science nature is not sci-fi',
        ['Ciencia y naturaleza'],
        ['science_nature'],
      ),
      (
        'spanish compound',
        ['Ciencia ficción', 'Fantasía'],
        ['fantasy', 'science_fiction'],
      ),
      (
        'spanish historical fiction',
        ['Ficción histórica'],
        ['historical_fiction'],
      ),
      (
        'spanish nonfiction',
        ['No ficción'],
        ['nonfiction'],
      ),
      ('poc historica bucket', ['histórica'], ['historical_fiction']),
      ('poc literaria bucket', ['literaria'], ['literary_classics']),
      ('poc comedia bucket', ['comedia'], ['humor_satire']),
      ('tmdb comedy english', ['Comedy'], ['humor_satire']),
      ('tmdb family english', ['Family'], ['children_young_adult']),
      ('tmdb documentary', ['Documentary'], ['nonfiction']),
      ('novela negra', ['Novela negra'], ['mystery_crime']),
      ('novela grafica', ['Novela gráfica'], ['comics_manga']),
      ('distopia', ['Distopía'], ['science_fiction']),
      ('deportes', ['Deportes'], ['lifestyle_leisure']),
      ('exact ciencia is nature not sci-fi', ['Ciencia'], ['science_nature']),
      ('ciencias humanas is not nature', ['Ciencias humanas'], ['other']),
      ('drama film is not poetry', ['drama film'], ['other']),
      ('bare drama is not poetry', ['Drama'], ['other']),
      ('play stays poetry', ['Play'], ['poetry_drama']),
      ('space opera film qid subject', ['Space opera'], ['science_fiction']),
    ];
    for (final (name, subjects, want) in cases) {
      expect(
        canonicalCategoryCodes(subjects),
        want,
        reason: name,
      );
    }
  });

  test('english product labels map to their own code', () {
    const labels = {
      'fiction': 'Fiction',
      'literary_classics': 'Literary fiction & classics',
      'fantasy': 'Fantasy',
      'science_fiction': 'Science fiction',
      'romance': 'Romance',
      'mystery_crime': 'Mystery & crime',
      'thriller': 'Thriller',
      'adventure': 'Adventure',
      'historical_fiction': 'Historical fiction',
      'horror_paranormal': 'Horror & paranormal',
      'humor_satire': 'Humor & satire',
      'comics_manga': 'Comics & manga',
      'poetry_drama': 'Poetry & drama',
      'children_young_adult': 'Children & young adult',
      'nonfiction': 'Nonfiction',
      'biography_memoir': 'Biography & memoir',
      'history': 'History',
      'psychology': 'Psychology',
      'self_help': 'Self-help',
      'health_wellness': 'Health & wellness',
      'religion_spirituality': 'Religion & spirituality',
      'philosophy': 'Philosophy',
      'science_nature': 'Science & nature',
      'politics_society': 'Politics & society',
      'education_reference': 'Education & reference',
      'arts_entertainment': 'Arts & entertainment',
      'business_economics': 'Business & economics',
      'technology': 'Technology',
      'lifestyle_leisure': 'Lifestyle & leisure',
      'other': 'Other',
    };
    for (final code in bookCategoryTaxonomy) {
      expect(
        canonicalCategoryCodes([labels[code]!]),
        [code],
        reason: code,
      );
    }
  });

  test('spanish product labels map to their own code', () {
    const labels = {
      'fiction': 'Ficción',
      'literary_classics': 'Ficción literaria y clásicos',
      'fantasy': 'Fantasía',
      'science_fiction': 'Ciencia ficción',
      'romance': 'Romance',
      'mystery_crime': 'Misterio y crimen',
      'thriller': 'Thriller',
      'adventure': 'Aventuras',
      'historical_fiction': 'Ficción histórica',
      'horror_paranormal': 'Terror y paranormal',
      'humor_satire': 'Humor y sátira',
      'comics_manga': 'Cómics y manga',
      'poetry_drama': 'Poesía y teatro',
      'children_young_adult': 'Infantil y juvenil',
      'nonfiction': 'No ficción',
      'biography_memoir': 'Biografía y memorias',
      'history': 'Historia',
      'psychology': 'Psicología',
      'self_help': 'Autoayuda',
      'health_wellness': 'Salud y bienestar',
      'religion_spirituality': 'Religión y espiritualidad',
      'philosophy': 'Filosofía',
      'science_nature': 'Ciencia y naturaleza',
      'politics_society': 'Política y sociedad',
      'education_reference': 'Educación y referencia',
      'arts_entertainment': 'Arte y entretenimiento',
      'business_economics': 'Negocios y economía',
      'technology': 'Tecnología',
      'lifestyle_leisure': 'Estilo de vida y ocio',
      'other': 'Otros',
    };
    for (final code in bookCategoryTaxonomy) {
      expect(
        canonicalCategoryCodes([labels[code]!]),
        [code],
        reason: code,
      );
    }
  });

  test('needsCategoryEnrich is true for empty or only other', () {
    expect(needsCategoryEnrich(const []), isTrue);
    expect(needsCategoryEnrich(const ['other']), isTrue);
    expect(needsCategoryEnrich(const ['', 'other']), isTrue);
    expect(needsCategoryEnrich(const ['science_fiction']), isFalse);
  });
}
