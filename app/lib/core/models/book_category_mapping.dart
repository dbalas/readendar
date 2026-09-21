import 'package:readendar/core/l10n/book_categories.dart';

/// Maps arbitrary provider subjects to the stable taxonomy. Mirrors
/// Canonical category codes shared with catalog search.
List<String> canonicalCategoryCodes(Iterable<String> subjects) {
  if (subjects.isEmpty) return const [];

  final matched = <String>{};
  var hasSubject = false;
  for (final raw in subjects) {
    final s = _normalizeCategorySubject(raw);
    if (s.isEmpty) continue;
    if (_categoryNoise.contains(s)) continue;
    hasSubject = true;

    if (_exactAny(s, const [
          'fiction',
          'genre fiction',
          'literature fiction',
          'contemporary',
          'short stories',
          'southern',
          'urban life',
          'ficcion',
          'novela',
          'novelas',
        ]) ||
        _containsAny(s, const ['general fiction', 'fiction general'])) {
      matched.add('fiction');
    }
    if (_containsAny(s, const ['literary', 'literaria', 'ficcion literaria']) ||
        _containsPrefixAny(s, const ['classic', 'clasico'])) {
      matched.add('literary_classics');
    }
    if (_containsAny(s, const [
          'fantasy',
          'fantasies',
          'fantasia',
          'fantastico',
          'gamelit',
          'lit rpg',
          'litrpg',
        ]) ||
        _containsPrefixAny(s, const ['magic'])) {
      matched.add('fantasy');
    }
    if (_containsAny(s, const [
      'science fiction',
      'scifi',
      'sci fi',
      'space opera',
      'dystopian',
      'dystopia',
      'distopia',
      'distopico',
      'distopica',
      'alien contact',
      'ciencia ficcion',
      'fantasia cientifica',
    ])) {
      matched.add('science_fiction');
    }
    if (_containsAny(s, const ['romance', 'romances']) ||
        _containsPrefixAny(s, const ['romantic'])) {
      matched.add('romance');
    }
    if (_containsAny(s, const [
      'mystery',
      'mysteries',
      'misterio',
      'crimen',
      'crime',
      'crimes',
      'detective',
      'detectives',
      'policiaca',
      'novela negra',
    ])) {
      matched.add('mystery_crime');
    }
    if (_containsAny(s, const [
      'thriller',
      'thrillers',
      'suspense',
      'suspenso',
      'intriga',
    ])) {
      matched.add('thriller');
    }
    if (_containsAny(s, const [
      'adventure',
      'adventures',
      'adventurous',
      'aventura',
      'aventuras',
      'action',
      'actions',
      'accion',
    ])) {
      matched.add('adventure');
    }
    final isHistoricalFiction = _containsAny(s, const [
      'historical fiction',
      'alternate history',
      'ficcion historica',
      'novela historica',
      'historica',
    ]);
    if (isHistoricalFiction) {
      matched.add('historical_fiction');
    }
    if (_containsAny(s, const [
      'horror',
      'horrors',
      'terror',
      'paranormal',
      'occult',
      'occultism',
    ])) {
      matched.add('horror_paranormal');
    }
    if (_containsAny(s, const [
      'humor',
      'humorous',
      'satire',
      'satira',
      'comedy',
      'comedies',
      'comedia',
      'comic strips cartoons',
    ])) {
      matched.add('humor_satire');
    }
    if (_containsAny(s, const [
      'comic',
      'comics',
      'graphic novel',
      'graphic novels',
      'novela grafica',
      'manga',
    ])) {
      matched.add('comics_manga');
    }
    if (_containsAny(s, const [
      'poetry',
      'poem',
      'poems',
      'poesia',
      'teatro',
      'play',
      'plays',
    ])) {
      matched.add('poetry_drama');
    }
    if (_containsAny(s, const [
      'juvenile',
      'juvenil',
      'children',
      'infantil',
      'young adult',
      'family',
      'early learning',
      'activity books',
      'basic concepts',
      'imagination play',
      'growing up',
      'friendship social skills',
      'social themes',
      'emotions feelings',
      'family life',
      'familia',
      'farm animals',
      'jungle animals',
      'marine life',
      'sounds',
      'size shape',
      'readers',
      'bears',
      'dogs',
      'butterflies',
      'turtles',
      'cars trucks',
      'railroads trains',
      'boats ships underwater craft',
    ])) {
      matched.add('children_young_adult');
    }
    if (_containsAny(s, const [
      'nonfiction',
      'non fiction',
      'no ficcion',
      'ensayo',
      'documentary',
      'documental',
    ])) {
      matched.add('nonfiction');
    }
    if (_containsAny(s, const ['memoir', 'memoirs', 'memorias']) ||
        _containsPrefixAny(s, const [
          'biograph',
          'autobiograph',
          'biograf',
          'autobiograf',
        ])) {
      matched.add('biography_memoir');
    }
    if (_containsAny(s, const [
          'history',
          'historical',
          'historia',
          'united states',
        ]) &&
        !_containsPrefixAny(s, const ['fiction', 'ficcion']) &&
        !isHistoricalFiction) {
      matched.add('history');
    }
    if (_containsAny(s, const [
          'personality',
          'personalities',
          'dream',
          'dreams',
          'transactional analysis',
        ]) ||
        _containsPrefixAny(s, const ['psycholog', 'psicolog', 'trauma'])) {
      matched.add('psychology');
    }
    if (_containsAny(s, const [
      'self help',
      'personal development',
      'autoayuda',
    ])) {
      matched.add('self_help');
    }
    if (_containsAny(s, const ['fitness', 'medicine', 'salud', 'bienestar']) ||
        _containsPrefixAny(s, const ['health', 'diet', 'medic', 'counsel'])) {
      matched.add('health_wellness');
    }
    if (_containsAny(s, const [
          'new age',
          'divination',
          'occultism',
          'espiritualidad',
        ]) ||
        _containsPrefixAny(s, const ['religio', 'spiritu'])) {
      matched.add('religion_spirituality');
    }
    if (_containsPrefixAny(s, const ['philosoph', 'filosof'])) {
      matched.add('philosophy');
    }
    if (_containsAny(s, const [
          'science nature',
          'ciencia y naturaleza',
          'ciencias naturales',
          'naturaleza',
          'animal',
          'animals',
          'marine life',
          'farm animals',
          'jungle animals',
          'dogs',
          'bears',
          'butterflies',
          'turtles',
        ]) ||
        _exactAny(s, const ['ciencia', 'ciencias']) ||
        _containsPrefixAny(s, const ['environment'])) {
      matched.add('science_nature');
    }
    if (_containsAny(s, const [
      'political',
      'politics',
      'politica',
      'politicas',
      'society',
      'sociedad',
      'social science',
      'violence in society',
      'ciencias politicas',
    ])) {
      matched.add('politics_society');
    }
    if (_containsAny(s, const [
          'reference',
          'references',
          'referencia',
          'concept',
          'concepts',
          'early learning',
        ]) ||
        _containsPrefixAny(s, const ['educat'])) {
      matched.add('education_reference');
    }
    if (_containsAny(s, const [
          'art',
          'arts',
          'arte',
          'artes',
          'arts entertainment',
          'arte y entretenimiento',
          'entertainment',
          'entretenimiento',
          'performing arts',
          'media tie in',
          'tv movie video game adaptations',
        ]) ||
        _containsPrefixAny(s, const ['music'])) {
      matched.add('arts_entertainment');
    }
    if (_containsAny(s, const [
          'business',
          'management',
          'marketing',
          'negocios',
          'empresa',
        ]) ||
        _containsPrefixAny(s, const ['econom', 'financ'])) {
      matched.add('business_economics');
    }
    if (_containsAny(s, const [
          'computer',
          'computers',
          'computer science',
          'programming',
          'engineering',
          'informatica',
        ]) ||
        _containsPrefixAny(s, const ['technolog', 'tecnolog'])) {
      matched.add('technology');
    }
    if (_containsAny(s, const [
      'activities crafts games',
      'house home',
      'lifestyle',
      'lifestyles',
      'lifestyle leisure',
      'estilo de vida',
      'leisure',
      'ocio',
      'sport',
      'sports',
      'deporte',
      'deportes',
      'travel',
      'viaje',
      'viajes',
      'cocina',
      'transportation',
      'farm ranch life',
      'cars trucks',
      'railroads trains',
      'boats ships underwater craft',
    ])) {
      matched.add('lifestyle_leisure');
    }
  }

  if (matched.isEmpty && hasSubject) {
    matched.add('other');
  }
  return [
    for (final code in bookCategoryTaxonomy)
      if (matched.contains(code)) code,
  ];
}

/// True when codes would vanish from every real category filter: empty or only
/// `other`. Mirrors backend NeedsCategoryEnrich.
bool needsCategoryEnrich(Iterable<String> codes) {
  for (final c in codes) {
    final code = resolveBookCategoryCode(c);
    if (code.isNotEmpty &&
        code != 'other' &&
        bookCategoryCodes.contains(code)) {
      return false;
    }
  }
  return true;
}

const _categoryNoise = {
  'arborist merchandising root',
  'categories',
  'form',
  'kindle ebooks',
  'kindle store',
  'self service',
  'subjects',
};

final _letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);

String _normalizeCategorySubject(String raw) {
  final buf = StringBuffer();
  var space = true;
  for (final rune in raw.trim().toLowerCase().runes) {
    final ch = _foldCategoryRune(String.fromCharCode(rune));
    if (_letterOrNumber.hasMatch(ch)) {
      buf.write(ch);
      space = false;
      continue;
    }
    if (!space) {
      buf.write(' ');
      space = true;
    }
  }
  return buf.toString().trim();
}

String _foldCategoryRune(String ch) {
  switch (ch) {
    case 'á' || 'à' || 'ä' || 'â':
      return 'a';
    case 'é' || 'è' || 'ë' || 'ê':
      return 'e';
    case 'í' || 'ì' || 'ï' || 'î':
      return 'i';
    case 'ó' || 'ò' || 'ö' || 'ô':
      return 'o';
    case 'ú' || 'ù' || 'ü' || 'û':
      return 'u';
    case 'ñ':
      return 'n';
    case 'ç':
      return 'c';
    default:
      return ch;
  }
}

bool _containsAny(String value, List<String> needles) {
  final padded = ' $value ';
  for (final needle in needles) {
    if (padded.contains(' $needle ')) return true;
  }
  return false;
}

bool _containsPrefixAny(String value, List<String> prefixes) {
  final padded = ' $value';
  for (final prefix in prefixes) {
    if (padded.contains(' $prefix')) return true;
  }
  return false;
}

bool _exactAny(String value, List<String> candidates) {
  for (final candidate in candidates) {
    if (value == candidate) return true;
  }
  return false;
}
