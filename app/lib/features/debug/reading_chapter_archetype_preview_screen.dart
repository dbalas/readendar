import 'package:flutter/material.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_story_card.dart';

/// Dev-only gallery of every Reading Chapter archetype card, using the live
/// story-card renderer so copy, art, and inverted chrome can be reviewed.
class ReadingChapterArchetypePreviewScreen extends StatelessWidget {
  const ReadingChapterArchetypePreviewScreen({super.key});

  static const _samples = <ReadingChapterArchetype>[
    ReadingChapterArchetype(
      name: 'keeper',
      breadthAxis: 'anchored',
      cadenceAxis: 'steady',
      noveltyAxis: 'return',
      scaleAxis: 'swift',
      genreCoverage: 0.92,
      novelWorkShare: 0.28,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'curator',
      breadthAxis: 'anchored',
      cadenceAxis: 'steady',
      noveltyAxis: 'explore',
      scaleAxis: 'swift',
      genreCoverage: 0.91,
      novelWorkShare: 0.72,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'hearth',
      breadthAxis: 'anchored',
      cadenceAxis: 'tidal',
      noveltyAxis: 'return',
      scaleAxis: 'swift',
      genreCoverage: 0.88,
      novelWorkShare: 0.31,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'spark',
      breadthAxis: 'anchored',
      cadenceAxis: 'tidal',
      noveltyAxis: 'explore',
      scaleAxis: 'swift',
      genreCoverage: 0.9,
      novelWorkShare: 0.68,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'cartographer',
      breadthAxis: 'wide',
      cadenceAxis: 'steady',
      noveltyAxis: 'explore',
      scaleAxis: 'swift',
      genreCoverage: 0.93,
      novelWorkShare: 0.74,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'constellation',
      breadthAxis: 'wide',
      cadenceAxis: 'tidal',
      noveltyAxis: 'return',
      scaleAxis: 'swift',
      genreCoverage: 0.89,
      novelWorkShare: 0.33,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'comet',
      breadthAxis: 'wide',
      cadenceAxis: 'tidal',
      noveltyAxis: 'explore',
      scaleAxis: 'swift',
      genreCoverage: 0.9,
      novelWorkShare: 0.81,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'vault',
      breadthAxis: 'anchored',
      cadenceAxis: 'steady',
      noveltyAxis: 'return',
      scaleAxis: 'tome',
      genreCoverage: 0.92,
      novelWorkShare: 0.27,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'scholar',
      breadthAxis: 'anchored',
      cadenceAxis: 'steady',
      noveltyAxis: 'explore',
      scaleAxis: 'tome',
      genreCoverage: 0.91,
      novelWorkShare: 0.71,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'oak',
      breadthAxis: 'anchored',
      cadenceAxis: 'tidal',
      noveltyAxis: 'return',
      scaleAxis: 'tome',
      genreCoverage: 0.88,
      novelWorkShare: 0.3,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'forge',
      breadthAxis: 'anchored',
      cadenceAxis: 'tidal',
      noveltyAxis: 'explore',
      scaleAxis: 'tome',
      genreCoverage: 0.9,
      novelWorkShare: 0.69,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'beacon',
      breadthAxis: 'wide',
      cadenceAxis: 'steady',
      noveltyAxis: 'return',
      scaleAxis: 'tome',
      genreCoverage: 0.94,
      novelWorkShare: 0.26,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'atlas',
      breadthAxis: 'wide',
      cadenceAxis: 'steady',
      noveltyAxis: 'explore',
      scaleAxis: 'tome',
      genreCoverage: 0.93,
      novelWorkShare: 0.76,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'nebula',
      breadthAxis: 'wide',
      cadenceAxis: 'tidal',
      noveltyAxis: 'return',
      scaleAxis: 'tome',
      genreCoverage: 0.89,
      novelWorkShare: 0.32,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
    ReadingChapterArchetype(
      name: 'leviathan',
      breadthAxis: 'wide',
      cadenceAxis: 'tidal',
      noveltyAxis: 'explore',
      scaleAxis: 'tome',
      genreCoverage: 0.9,
      novelWorkShare: 0.83,
      evidenceGenres: _genres,
      evidenceAuthors: _authors,
    ),
  ];

  static const _genres = [
    ReadingChapterCount(key: 'fiction', count: 42),
    ReadingChapterCount(key: 'mystery', count: 21),
    ReadingChapterCount(key: 'history', count: 17),
  ];
  static const _authors = [ReadingChapterCount(key: 'Sample Author', count: 3)];

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.debugArchetypePreviewTitle)),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: _samples.length + 1,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                l.debugArchetypePreviewIntro,
                style: TextStyle(color: context.colors.fg2),
              );
            }
            final archetype = _samples[index - 1];
            return SizedBox(
              height: 420,
              child: ReadingChapterStoryCard(
                key: Key('debug-archetype-${archetype.name}'),
                compact: true,
                periodKind: ReadingChapterKind.year,
                periodKey: '2025',
                card: ReadingChapterCard(
                  id: 'archetype-${archetype.name}',
                  kind: 'archetype',
                  books: const [],
                  rhythm: const [],
                  formats: const [],
                  archetype: archetype,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
