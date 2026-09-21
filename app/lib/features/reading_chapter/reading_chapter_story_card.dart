import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/features/library/book_format_display.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_card_art.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_archetype_icon.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';

class ReadingChapterStoryCard extends StatelessWidget {
  const ReadingChapterStoryCard({
    required this.card,
    required this.periodKind,
    required this.periodKey,
    super.key,
    this.compact = false,
    this.storyBooks = const [],
    this.concealSpoilers = false,
  });

  final ReadingChapterCard card;
  final ReadingChapterKind periodKind;
  final String periodKey;
  final bool compact;
  final List<ReadingChapterBook> storyBooks;
  final bool concealSpoilers;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;
    final radius = BorderRadius.circular(
      compact ? ReadendarTokens.radiusLg : ReadendarTokens.radiusSheet,
    );
    final inverted = card.kind == 'archetype';
    return Semantics(
      label: _cardTitle(AppL10n.of(context), card),
      container: true,
      child: DecoratedBox(
        key: Key('reading-chapter-card-${card.kind}'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: readingChapterCardGradient(
              kind: card.kind,
              colors: colors,
              canvasColors: context.readendarTheme.background.colors,
              brightness: brightness,
            ),
          ),
          borderRadius: radius,
          border: Border.all(
            color: inverted
                ? colors.accent.withValues(alpha: 0.5)
                : colors.line,
          ),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.all(compact ? 18 : 26),
            child: compact
                ? _content(context)
                : CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _content(context),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) => switch (card.kind) {
    'coverMosaic' => _OpeningCard(
      card: card,
      kind: periodKind,
      periodKey: periodKey,
    ),
    'totals' => _TotalsCard(card: card),
    'rhythm' => _RhythmCard(card: card),
    'comparison' => _ComparisonCard(card: card, kind: periodKind),
    'journey' => _JourneyCard(card: card),
    'formatMix' => _FormatCard(card: card),
    'taste' => _TasteCard(card: card),
    'ratings' => _RatingsCard(card: card),
    'archetype' => _ArchetypeCard(card: card),
    'reflection' => _ReflectionCard(
      card: card,
      storyBooks: storyBooks,
      concealSpoilers: concealSpoilers,
    ),
    'summary' => _SummaryCard(
      card: card,
      kind: periodKind,
      periodKey: periodKey,
    ),
    _ => _SummaryCard(card: card, kind: periodKind, periodKey: periodKey),
  };
}

String _cardTitle(AppL10n l, ReadingChapterCard card) =>
    readingChapterCardKindLabel(l, card.kind);

class _OpeningCard extends StatelessWidget {
  const _OpeningCard({
    required this.card,
    required this.kind,
    required this.periodKey,
  });

  final ReadingChapterCard card;
  final ReadingChapterKind kind;
  final String periodKey;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          readingChapterOpeningHeading(l, context, kind, periodKey),
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const Spacer(),
        Center(child: _CoverConstellation(books: card.books)),
        const Spacer(),
        Text(
          l.readingChapterOpeningBody(card.books.length),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.colors.fg2),
        ),
      ],
    );
  }
}

class _CoverConstellation extends StatelessWidget {
  const _CoverConstellation({required this.books});

  final List<ReadingChapterBook> books;

  @override
  Widget build(BuildContext context) {
    final visible = books.take(7).toList();
    if (visible.isEmpty) {
      return Icon(
        LucideIcons.bookOpen,
        size: 84,
        color: context.colors.accent,
      );
    }
    return SizedBox(
      width: 286,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < visible.length; index++)
            Transform.translate(
              offset: _coverOffset(index, visible.length),
              child: Transform.rotate(
                angle: ((index % 3) - 1) * 0.055,
                child: RepaintBoundary(
                  child: BookCover(
                    title: visible[index].title,
                    author: visible[index].primaryAuthor,
                    coverUrl: visible[index].coverUrl,
                    width: index == 0 ? 104 : 78,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Offset _coverOffset(int index, int count) {
    if (index == 0) return const Offset(0, -6);
    final angle = (index - 1) * (math.pi * 2 / math.max(1, count - 1));
    return Offset(math.cos(angle) * 94, math.sin(angle) * 66 + 8);
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.card});
  final ReadingChapterCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final totals = card.totals;
    if (totals == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterTotalsTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const Spacer(),
        _HeroNumber(
          value: readingChapterNumber(context, totals.uniqueWorks),
          label: l.readingChapterUniqueWorks,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _Stat(
                value: readingChapterNumber(
                  context,
                  totals.readingOccurrences,
                ),
                label: l.readingChapterOccurrences,
                icon: LucideIcons.repeat2,
              ),
            ),
            Expanded(
              child: _Stat(
                value: readingChapterNumber(context, totals.knownPages),
                label: l.readingChapterPages,
                icon: LucideIcons.files,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (totals.pageTotalCount > 0) ...[
          _CoverageBar(value: totals.pageCoverage),
          const SizedBox(height: 8),
          Text(
            l.readingChapterPageCoverage(
              totals.pageKnownCount,
              totals.pageTotalCount,
            ),
            style: TextStyle(color: context.colors.fg2),
          ),
        ],
      ],
    );
  }
}

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.card});
  final ReadingChapterCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final maximum = card.rhythm.fold<int>(
      1,
      (value, point) => math.max(value, math.max(point.count, point.pages)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterRhythmTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const SizedBox(height: 12),
        Text(
          l.readingChapterRhythmBody,
          style: TextStyle(color: context.colors.fg2),
        ),
        const Spacer(),
        SizedBox(
          height: 268,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final point in card.rhythm)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          readingChapterNumber(
                            context,
                            point.pages > 0 ? point.pages : point.count,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 420),
                          height:
                              18 +
                              170 *
                                  (math.max(point.count, point.pages) /
                                      maximum),
                          decoration: BoxDecoration(
                            color: context.colors.accent,
                            borderRadius: BorderRadius.circular(
                              ReadendarTokens.radiusPill,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 34,
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              readingChapterRhythmLabel(context, point.key),
                              maxLines: 1,
                              softWrap: false,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: context.colors.fg3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.card, required this.kind});
  final ReadingChapterCard card;
  final ReadingChapterKind kind;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final comparison = card.comparison;
    if (comparison == null) return const SizedBox.shrink();
    final previousLabel = readingChapterPeriodLabel(
      context,
      kind,
      comparison.previousPeriodKey,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterComparisonTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const SizedBox(height: 8),
        Text(
          previousLabel,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: context.colors.fg2),
        ),
        const Spacer(),
        _ComparisonRow(
          label: l.readingChapterUniqueWorks,
          before: comparison.previousUniqueWorks,
          now: comparison.uniqueWorks,
        ),
        const SizedBox(height: 28),
        _ComparisonRow(
          label: l.readingChapterPages,
          before: comparison.previousKnownPages,
          now: comparison.knownPages,
        ),
        const Spacer(),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.before,
    required this.now,
  });

  final String label;
  final int before;
  final int now;

  @override
  Widget build(BuildContext context) {
    final up = now >= before;
    final numberStyle = Theme.of(context).textTheme.headlineLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                readingChapterNumber(context, before),
                textAlign: TextAlign.center,
                style: numberStyle,
              ),
            ),
            _TrendArrow(
              up: up,
              color: up ? context.colors.success : context.colors.warning,
            ),
            Expanded(
              child: Text(
                readingChapterNumber(context, now),
                textAlign: TextAlign.center,
                style: numberStyle?.copyWith(color: context.colors.accent),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Vector arrows. Lucide font glyphs can render as iOS tofu (□?).
class _TrendArrow extends StatelessWidget {
  const _TrendArrow({required this.up, required this.color});

  final bool up;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        key: Key(up ? 'readingChapterTrendUp' : 'readingChapterTrendDown'),
        size: const Size(34, 34),
        painter: _TrendArrowPainter(up: up, color: color),
      ),
    );
  }
}

class _TrendArrowPainter extends CustomPainter {
  const _TrendArrowPainter({required this.up, required this.color});

  final bool up;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final start = Offset(
      size.width * 0.22,
      up ? size.height * 0.72 : size.height * 0.28,
    );
    final end = Offset(
      size.width * 0.78,
      up ? size.height * 0.28 : size.height * 0.72,
    );
    final head = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
    final dir = Offset(end.dx - start.dx, end.dy - start.dy);
    final len = dir.distance;
    if (len > 0) {
      final u = Offset(dir.dx / len, dir.dy / len);
      const headLen = 9.0;
      final left = Offset(-u.dy, u.dx);
      head
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          end.dx - u.dx * headLen + left.dx * 6,
          end.dy - u.dy * headLen + left.dy * 6,
        )
        ..moveTo(end.dx, end.dy)
        ..lineTo(
          end.dx - u.dx * headLen - left.dx * 6,
          end.dy - u.dy * headLen - left.dy * 6,
        );
    }
    canvas.drawPath(head, stroke);
  }

  @override
  bool shouldRepaint(covariant _TrendArrowPainter oldDelegate) =>
      oldDelegate.up != up || oldDelegate.color != color;
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.card});
  final ReadingChapterCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final journey = card.journey;
    if (journey == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterJourneyTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const SizedBox(height: 14),
        Text(
          l.readingChapterJourneyBody,
          style: TextStyle(color: context.colors.fg2),
        ),
        const Spacer(),
        _JourneyLine(
          value: journey.started,
          label: l.readingChapterStarted,
          icon: LucideIcons.bookOpen,
          color: context.colors.accent,
        ),
        _JourneyLine(
          value: journey.ongoing,
          label: l.readingChapterOngoing,
          icon: LucideIcons.hourglass,
          color: context.colors.accent2,
        ),
        _JourneyLine(
          value: journey.abandoned,
          label: l.readingChapterAbandoned,
          icon: LucideIcons.bookX,
          color: context.colors.warning,
        ),
        const Spacer(),
      ],
    );
  }
}

class _JourneyLine extends StatelessWidget {
  const _JourneyLine({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Text(
          readingChapterNumber(context, value),
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(color: color),
        ),
      ],
    ),
  );
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({required this.card});
  final ReadingChapterCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final total = math.max(
      1,
      card.formats.fold<int>(0, (sum, item) => sum + item.count),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterFormatsTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const Spacer(),
        for (final item in card.formats.take(6)) ...[
          _DistributionRow(
            label: bookFormatDisplayName(l, item.key),
            value: item.count,
            fraction: item.count / total,
          ),
          const SizedBox(height: 16),
        ],
        const Spacer(),
      ],
    );
  }
}

class _TasteCard extends StatelessWidget {
  const _TasteCard({required this.card});
  final ReadingChapterCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final taste = card.taste;
    if (taste == null) return const SizedBox.shrink();
    final genreTotal = math.max(
      1,
      taste.genres.fold<int>(0, (sum, item) => sum + item.count),
    );
    final authorTotal = math.max(
      1,
      taste.authors.fold<int>(0, (sum, item) => sum + item.count),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterTasteTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const Spacer(),
        if (taste.genres.isNotEmpty) ...[
          Text(
            l.readingChapterGenres,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          for (final item in taste.genres.take(4)) ...[
            _DistributionRow(
              label: readingChapterGenreLabel(l, item.key),
              value: item.count,
              fraction: item.count / genreTotal,
            ),
            const SizedBox(height: 12),
          ],
        ],
        const Spacer(),
        if (taste.authors.isNotEmpty) ...[
          Text(
            l.readingChapterAuthors,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          for (final item in taste.authors.take(4)) ...[
            _DistributionRow(
              label: item.key,
              value: item.count,
              fraction: item.count / authorTotal,
            ),
            const SizedBox(height: 12),
          ],
        ],
        const Spacer(),
      ],
    );
  }
}

class _RatingsCard extends StatelessWidget {
  const _RatingsCard({required this.card});
  final ReadingChapterCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ratings = card.ratings;
    if (ratings == null) return const SizedBox.shrink();
    final total = math.max(1, ratings.ratedCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterRatingsTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const Spacer(),
        if (ratings.average != null)
          Center(
            child: Column(
              children: [
                Icon(
                  LucideIcons.star,
                  size: 48,
                  color: context.colors.highlight,
                ),
                const SizedBox(height: 8),
                Text(
                  readingChapterDecimal(context, ratings.average!),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: context.colors.fg1,
                  ),
                ),
                Text(
                  l.readingChapterAverageRating,
                  style: TextStyle(color: context.colors.fg2),
                ),
              ],
            ),
          ),
        const Spacer(),
        for (final item in ratings.distribution)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DistributionRow(
              label: item.key,
              value: item.count,
              fraction: item.count / total,
            ),
          ),
      ],
    );
  }
}

class _ArchetypeCard extends StatelessWidget {
  const _ArchetypeCard({required this.card});
  final ReadingChapterCard card;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final archetype = card.archetype;
    if (archetype == null) return const SizedBox.shrink();
    final foreground = context.colors.fgOnAccent;
    return DefaultTextStyle.merge(
      style: TextStyle(color: foreground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialTitle(
            l.readingChapterArchetypeTitle,
            color: foreground,
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
          const Spacer(),
          Icon(
            readingChapterArchetypeIcon(archetype.name),
            size: 62,
            color: foreground,
          ),
          const SizedBox(height: 22),
          Text(
            _archetypeName(l, archetype.name),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: foreground,
              height: 0.95,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            readingChapterArchetypeBody(l, archetype.name),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: foreground.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in archetype.evidenceGenres.take(3))
                _DarkChip(
                  label: readingChapterGenreLabel(l, genre.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _archetypeName(AppL10n l, String name) => switch (name) {
  'keeper' => l.readingChapterArchetypeKeeper,
  'curator' => l.readingChapterArchetypeCurator,
  'hearth' => l.readingChapterArchetypeHearth,
  'spark' => l.readingChapterArchetypeSpark,
  'cartographer' => l.readingChapterArchetypeCartographer,
  'constellation' => l.readingChapterArchetypeConstellation,
  'comet' => l.readingChapterArchetypeComet,
  'vault' => l.readingChapterArchetypeVault,
  'scholar' => l.readingChapterArchetypeScholar,
  'oak' => l.readingChapterArchetypeOak,
  'forge' => l.readingChapterArchetypeForge,
  'beacon' || 'lantern' => l.readingChapterArchetypeBeacon,
  'atlas' => l.readingChapterArchetypeAtlas,
  'nebula' => l.readingChapterArchetypeNebula,
  'leviathan' => l.readingChapterArchetypeLeviathan,
  _ => name,
};

String _axis(AppL10n l, String axis) => switch (axis) {
  'anchored' => l.readingChapterAxisAnchored,
  'wide' => l.readingChapterAxisWide,
  'steady' => l.readingChapterAxisSteady,
  'tidal' => l.readingChapterAxisTidal,
  'explore' => l.readingChapterAxisExplore,
  'return' => l.readingChapterAxisReturn,
  'swift' => l.readingChapterAxisSwift,
  'tome' => l.readingChapterAxisTome,
  _ => axis,
};

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: context.colors.fgOnAccent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
      border: Border.all(
        color: context.colors.fgOnAccent.withValues(alpha: 0.24),
      ),
    ),
    child: Text(label, style: TextStyle(color: context.colors.fgOnAccent)),
  );
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.card,
    required this.storyBooks,
    required this.concealSpoilers,
  });
  final ReadingChapterCard card;
  final List<ReadingChapterBook> storyBooks;
  final bool concealSpoilers;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final reflection = card.reflection;
    ReadingChapterBook? book;
    final bookId = reflection?.bookEntryId ?? '';
    for (final candidate in [...card.books, ...storyBooks]) {
      if (candidate.entryId == bookId) {
        book = candidate;
        break;
      }
    }
    if (reflection == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          readingChapterPromptLabel(l, reflection.prompt),
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const Spacer(),
        if (book != null)
          Center(
            child: BookCover(
              title: book.title,
              author: book.primaryAuthor,
              coverUrl: book.coverUrl,
              width: 118,
            ),
          ),
        const SizedBox(height: 20),
        if (book != null) ...[
          Text(
            book.title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (book.primaryAuthor.isNotEmpty)
            Text(
              book.primaryAuthor,
              style: TextStyle(color: context.colors.fg2),
            ),
        ],
        if ((reflection.excerpt.isNotEmpty ||
                reflection.attribution.isNotEmpty) &&
            reflection.spoiler &&
            concealSpoilers) ...[
          const Spacer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.warningSoftBg,
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
              border: Border.all(color: context.colors.warning),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.eyeOff,
                    color: context.colors.warningSoftFg,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.readingChapterSpoilerHiddenPreview,
                      style: TextStyle(color: context.colors.warningSoftFg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (reflection.excerpt.isNotEmpty ||
            reflection.attribution.isNotEmpty) ...[
          const Spacer(),
          if (reflection.excerpt.isNotEmpty)
            Text(
              '“${reflection.excerpt}”',
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: context.colors.fg1,
              ),
            ),
          if (reflection.attribution.isNotEmpty)
            Text(
              reflection.attribution,
              style: TextStyle(color: context.colors.fg2),
            ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.card,
    required this.kind,
    required this.periodKey,
  });
  final ReadingChapterCard card;
  final ReadingChapterKind kind;
  final String periodKey;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final totals = card.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialTitle(
          l.readingChapterSummaryTitle,
          maxLines: null,
          overflow: TextOverflow.visible,
        ),
        const SizedBox(height: 10),
        Text(
          readingChapterPeriodLabel(context, kind, periodKey),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: context.colors.fg2),
        ),
        const Spacer(),
        Center(child: _CoverConstellation(books: card.books)),
        const Spacer(),
        if (totals != null)
          Row(
            children: [
              Expanded(
                child: _Stat(
                  value: readingChapterNumber(context, totals.uniqueWorks),
                  label: l.readingChapterUniqueWorks,
                  icon: LucideIcons.library,
                ),
              ),
              Expanded(
                child: _Stat(
                  value: readingChapterNumber(context, totals.knownPages),
                  label: l.readingChapterPages,
                  icon: LucideIcons.files,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _HeroNumber extends StatelessWidget {
  const _HeroNumber({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: Theme.of(context).textTheme.displayLarge?.copyWith(
          color: context.colors.accent,
          height: 0.9,
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: Theme.of(context).textTheme.titleLarge),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: context.colors.accent),
      const SizedBox(height: 6),
      Text(value, style: Theme.of(context).textTheme.headlineLarge),
      Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.fg2),
      ),
    ],
  );
}

class _CoverageBar extends StatelessWidget {
  const _CoverageBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
    child: LinearProgressIndicator(
      value: value,
      minHeight: 8,
      backgroundColor: context.colors.line,
      color: context.colors.accent,
    ),
  );
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.fraction,
  });

  final String label;
  final int value;
  final double fraction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        flex: 3,
        child: Text(label, maxLines: 2, overflow: TextOverflow.visible),
      ),
      const SizedBox(width: 10),
      Expanded(flex: 5, child: _CoverageBar(value: fraction.clamp(0, 1))),
      const SizedBox(width: 10),
      Text(readingChapterNumber(context, value)),
    ],
  );
}
