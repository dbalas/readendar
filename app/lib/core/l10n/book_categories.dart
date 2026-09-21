import 'package:readendar/core/l10n/gen/app_localizations.dart';

/// Taxonomy order. Canonical mapping output follows this list so equivalent
/// provider payloads serialize identically on app and backend.
const List<String> bookCategoryTaxonomy = [
  'fiction',
  'literary_classics',
  'fantasy',
  'science_fiction',
  'romance',
  'mystery_crime',
  'thriller',
  'adventure',
  'historical_fiction',
  'horror_paranormal',
  'humor_satire',
  'comics_manga',
  'poetry_drama',
  'children_young_adult',
  'nonfiction',
  'biography_memoir',
  'history',
  'psychology',
  'self_help',
  'health_wellness',
  'religion_spirituality',
  'philosophy',
  'science_nature',
  'politics_society',
  'education_reference',
  'arts_entertainment',
  'business_economics',
  'technology',
  'lifestyle_leisure',
  'other',
];

const Set<String> bookCategoryCodes = {
  ...bookCategoryTaxonomy,
};

const Map<String, String> _bookCategoryAliasCodes = {
  'mystery': 'mystery_crime',
  'crime': 'mystery_crime',
  'detective': 'mystery_crime',
  'sci_fi': 'science_fiction',
  'scifi': 'science_fiction',
  'memoir': 'biography_memoir',
  'biography': 'biography_memoir',
  'autobiography': 'biography_memoir',
  'selfhelp': 'self_help',
  'young_adult': 'children_young_adult',
  'children': 'children_young_adult',
  'horror': 'horror_paranormal',
  'paranormal': 'horror_paranormal',
  'classics': 'literary_classics',
  'classic': 'literary_classics',
  'comics': 'comics_manga',
  'manga': 'comics_manga',
  'graphic_novel': 'comics_manga',
  'poetry': 'poetry_drama',
  'drama': 'poetry_drama',
  'health': 'health_wellness',
  'wellness': 'health_wellness',
  'religion': 'religion_spirituality',
  'spirituality': 'religion_spirituality',
  'science': 'science_nature',
  'nature': 'science_nature',
  'politics': 'politics_society',
  'society': 'politics_society',
  'reference': 'education_reference',
  'education': 'education_reference',
  'arts': 'arts_entertainment',
  'entertainment': 'arts_entertainment',
  'business': 'business_economics',
  'economics': 'business_economics',
  'tech': 'technology',
  'lifestyle': 'lifestyle_leisure',
  'leisure': 'lifestyle_leisure',
  'non_fiction': 'nonfiction',
};

String resolveBookCategoryCode(String key) {
  final normalized = key
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');
  if (bookCategoryCodes.contains(normalized)) return normalized;
  return _bookCategoryAliasCodes[normalized] ?? normalized;
}

String bookCategoryLabel(AppL10n l, String code) => switch (resolveBookCategoryCode(code)) {
  'fiction' => l.bookCategoryFiction,
  'literary_classics' => l.bookCategoryLiteraryClassics,
  'fantasy' => l.bookCategoryFantasy,
  'science_fiction' => l.bookCategoryScienceFiction,
  'romance' => l.bookCategoryRomance,
  'mystery_crime' => l.bookCategoryMysteryCrime,
  'thriller' => l.bookCategoryThriller,
  'adventure' => l.bookCategoryAdventure,
  'historical_fiction' => l.bookCategoryHistoricalFiction,
  'horror_paranormal' => l.bookCategoryHorrorParanormal,
  'humor_satire' => l.bookCategoryHumorSatire,
  'comics_manga' => l.bookCategoryComicsManga,
  'poetry_drama' => l.bookCategoryPoetryDrama,
  'children_young_adult' => l.bookCategoryChildrenYoungAdult,
  'nonfiction' => l.bookCategoryNonfiction,
  'biography_memoir' => l.bookCategoryBiographyMemoir,
  'history' => l.bookCategoryHistory,
  'psychology' => l.bookCategoryPsychology,
  'self_help' => l.bookCategorySelfHelp,
  'health_wellness' => l.bookCategoryHealthWellness,
  'religion_spirituality' => l.bookCategoryReligionSpirituality,
  'philosophy' => l.bookCategoryPhilosophy,
  'science_nature' => l.bookCategoryScienceNature,
  'politics_society' => l.bookCategoryPoliticsSociety,
  'education_reference' => l.bookCategoryEducationReference,
  'arts_entertainment' => l.bookCategoryArtsEntertainment,
  'business_economics' => l.bookCategoryBusinessEconomics,
  'technology' => l.bookCategoryTechnology,
  'lifestyle_leisure' => l.bookCategoryLifestyleLeisure,
  _ => l.bookCategoryOther,
};

List<String> bookCategoryLabels(
  AppL10n l,
  Iterable<String> codes, {
  bool hasRawCategories = false,
}) {
  final labels = <String>[];
  final seen = <String>{};
  for (final code in codes) {
    final label = bookCategoryLabel(l, code);
    if (seen.add(label)) labels.add(label);
  }
  if (labels.isEmpty && hasRawCategories) {
    labels.add(l.bookCategoryOther);
  }
  return labels;
}
