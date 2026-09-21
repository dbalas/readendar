import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/reading_chapter.dart';

void main() {
  test(
    'private story parses optional cards and deduplicates books by entry',
    () {
      final story = ReadingChapterStory.fromJson(const {
        'schemaVersion': 1,
        'archetypeRuleVersion': 1,
        'sourceRevision': '9-3',
        'period': {
          'kind': 'year',
          'key': '2025',
          'timezone': 'UTC',
          'startsAt': '2025-01-01T00:00:00Z',
          'endsAt': '2026-01-01T00:00:00Z',
        },
        'reader': {
          'displayName': 'Ada',
          'locale': 'en',
        },
        'meaningful': true,
        'cards': [
          {
            'id': 'opening',
            'kind': 'coverMosaic',
            'books': [
              {
                'entryId': 'entry-1',
                'workKey': 'isbn:9780000000001',
                'title': 'The Book',
                'primaryAuthor': 'Writer',
                'coverUrl': 'https://images.example/book.png',
                'format': 'physical',
                'categories': ['Ficción'],
                'categoryCodes': ['fiction'],
                'occurrences': 2,
              },
            ],
          },
          {
            'id': 'reflection-favorite',
            'kind': 'reflection',
            'books': [
              {
                'entryId': 'entry-1',
                'title': 'The Book',
                'occurrences': 2,
              },
            ],
            'reflection': {
              'prompt': 'favorite',
              'bookEntryId': 'entry-1',
              'excerpt': 'A private thought',
              'attribution': 'Chapter 3',
              'spoiler': true,
            },
          },
        ],
        'readiness': [
          {'kind': 'missingPages', 'bookEntryId': 'entry-1', 'count': 1},
        ],
        'curation': <Object>[],
      });

      expect(story.period.kind, ReadingChapterKind.year);
      expect(story.books, hasLength(1));
      expect(story.books.single.occurrences, 2);
      expect(story.cards.last.reflection?.spoiler, isTrue);
      expect(story.readiness.single.kind, 'missingPages');
    },
  );

  test('archetype json keeps scale and defaults missing scale to swift', () {
    final withScale = ReadingChapterArchetype.fromJson(const {
      'name': 'scholar',
      'breadthAxis': 'anchored',
      'cadenceAxis': 'steady',
      'noveltyAxis': 'explore',
      'scaleAxis': 'tome',
      'genreCoverage': 0.9,
      'novelWorkShare': 0.7,
      'evidenceGenres': [
        {'key': 'fiction', 'count': 80},
      ],
      'evidenceAuthors': <Object>[],
    });
    expect(withScale.name, 'scholar');
    expect(withScale.scaleAxis, 'tome');

    final legacy = ReadingChapterArchetype.fromJson(const {
      'name': 'curator',
      'breadthAxis': 'anchored',
      'cadenceAxis': 'steady',
      'noveltyAxis': 'explore',
      'genreCoverage': 0.9,
      'novelWorkShare': 0.7,
      'evidenceGenres': <Object>[],
      'evidenceAuthors': <Object>[],
    });
    expect(legacy.scaleAxis, 'swift');
  });
}
