import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/cover_image.dart';

Gradient readingChapterThemeWash(ReadendarColors colors) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color.alphaBlend(colors.accent.withValues(alpha: 0.22), colors.surface1),
    Color.alphaBlend(colors.accent2.withValues(alpha: 0.16), colors.surface1),
  ],
);

Color readingChapterThemeWashBorder(ReadendarColors colors) =>
    colors.accent.withValues(alpha: 0.38);

/// Compact unread marker for hub/profile. Visible copy is the short NEW chip;
/// [readingChapterNewAvailable] stays on the semantics label.
class ReadingChapterUnreadBadge extends StatelessWidget {
  const ReadingChapterUnreadBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;
    return Semantics(
      label: l.readingChapterNewAvailable,
      child: Container(
        key: const Key('readingChapterUnreadBadge'),
        padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: colors.fgOnAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              l.readingChapterNew,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.fgOnAccent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String readingChapterOpeningHeading(
  AppL10n l,
  BuildContext context,
  ReadingChapterKind kind,
  String periodKey,
) {
  final period = readingChapterPeriodLabel(context, kind, periodKey);
  return kind == ReadingChapterKind.year
      ? l.readingChapterOpeningYear(period)
      : l.readingChapterOpeningMonth(period);
}

String readingChapterPeriodLabel(
  BuildContext context,
  ReadingChapterKind kind,
  String key,
) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  if (kind == ReadingChapterKind.year) {
    final year = int.tryParse(key);
    return year == null ? key : DateFormat.y(locale).format(DateTime(year));
  }
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null || month < 1 || month > 12) return key;
  return DateFormat.yMMMM(locale).format(DateTime(year, month));
}

String readingChapterNumber(BuildContext context, num value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);

String readingChapterDecimal(BuildContext context, num value) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toLanguageTag(),
      decimalDigits: 1,
    ).format(value);

List<ReadingChapterCard> readingChapterVisibleCards(
  Iterable<ReadingChapterCard> cards,
) => [
  for (final card in cards)
    if (card.kind != 'totals') card,
];

List<ReadingChapterReadinessIssue> readingChapterVisibleReadiness(
  Iterable<ReadingChapterReadinessIssue> issues,
) => issues.toList();

List<String> readingChapterGroupingPeerIds(
  ReadingChapterReadinessIssue issue,
  Iterable<ReadingChapterBook> books,
) {
  final seed = readingChapterBookFor(issue.bookEntryId, books);
  if (seed == null) {
    return issue.bookEntryId.isEmpty ? const [] : [issue.bookEntryId];
  }
  final title = seed.title.trim().toLowerCase();
  final author = seed.primaryAuthor.trim().toLowerCase();
  return [
    for (final book in books)
      if (book.title.trim().toLowerCase() == title &&
          book.primaryAuthor.trim().toLowerCase() == author)
        book.entryId,
  ];
}

ReadingChapterBook? readingChapterBookFor(
  String entryId,
  Iterable<ReadingChapterBook> books,
) {
  if (entryId.isEmpty) return null;
  for (final book in books) {
    if (book.entryId == entryId) return book;
  }
  return null;
}

String readingChapterPromptLabel(AppL10n l, String prompt) => switch (prompt) {
  'favorite' => l.readingChapterPromptFavorite,
  'biggest_surprise' => l.readingChapterPromptSurprise,
  'comfort_read' => l.readingChapterPromptComfort,
  'challenged_me' => l.readingChapterPromptChallenged,
  'best_cover' => l.readingChapterPromptBestCover,
  'memorable_passage' => l.readingChapterPromptPassage,
  'favorite_return' => l.readingChapterPromptReturn,
  'unfinished_unforgettable' => l.readingChapterPromptUnfinished,
  _ => l.readingChapterReflectionTitle,
};

String readingChapterCardKindLabel(AppL10n l, String kind) => switch (kind) {
  'coverMosaic' => l.readingChapterOpeningTitle,
  'totals' => l.readingChapterTotalsTitle,
  'rhythm' => l.readingChapterRhythmTitle,
  'comparison' => l.readingChapterComparisonTitle,
  'journey' => l.readingChapterJourneyTitle,
  'formatMix' => l.readingChapterFormatsTitle,
  'taste' => l.readingChapterTasteTitle,
  'ratings' => l.readingChapterRatingsTitle,
  'archetype' => l.readingChapterArchetypeTitle,
  'reflection' => l.readingChapterReflectionTitle,
  _ => l.readingChapterSummaryTitle,
};

String readingChapterShareCardPrimaryLabel(
  AppL10n l,
  ReadingChapterCard card,
) {
  if (card.kind != 'reflection') {
    return readingChapterCardKindLabel(l, card.kind);
  }
  return readingChapterPromptLabel(l, card.reflection?.prompt ?? '');
}

String? readingChapterShareCardBookTitle(
  ReadingChapterCard card,
  Iterable<ReadingChapterBook> storyBooks,
) {
  if (card.kind != 'reflection') return null;
  final book = readingChapterBookFor(
    card.reflection?.bookEntryId ?? '',
    [...card.books, ...storyBooks],
  );
  final title = book?.title.trim() ?? '';
  return title.isEmpty ? null : title;
}

String readingChapterShareCardLabel(
  AppL10n l,
  ReadingChapterCard card,
  Iterable<ReadingChapterBook> storyBooks,
) {
  final primary = readingChapterShareCardPrimaryLabel(l, card);
  final bookTitle = readingChapterShareCardBookTitle(card, storyBooks);
  if (bookTitle == null) return primary;
  return '$primary · $bookTitle';
}

String readingChapterArchetypeBody(AppL10n l, String name) => switch (name) {
  'keeper' => l.readingChapterArchetypeKeeperBody,
  'curator' => l.readingChapterArchetypeCuratorBody,
  'hearth' => l.readingChapterArchetypeHearthBody,
  'spark' => l.readingChapterArchetypeSparkBody,
  'cartographer' => l.readingChapterArchetypeCartographerBody,
  'constellation' => l.readingChapterArchetypeConstellationBody,
  'comet' => l.readingChapterArchetypeCometBody,
  'vault' => l.readingChapterArchetypeVaultBody,
  'scholar' => l.readingChapterArchetypeScholarBody,
  'oak' => l.readingChapterArchetypeOakBody,
  'forge' => l.readingChapterArchetypeForgeBody,
  'beacon' || 'lantern' => l.readingChapterArchetypeBeaconBody,
  'atlas' => l.readingChapterArchetypeAtlasBody,
  'nebula' => l.readingChapterArchetypeNebulaBody,
  'leviathan' => l.readingChapterArchetypeLeviathanBody,
  _ => l.readingChapterArchetypeBody,
};

String readingChapterGenreLabel(AppL10n l, String key) =>
    bookCategoryLabel(l, key);

void precacheReadingChapterCoverUrls(
  BuildContext context,
  Iterable<String> urls, {
  double displayWidth = 88,
}) {
  precacheCoverUrls(
    context,
    urls,
    tier: coverTierForWidth(displayWidth),
  );
}

String readingChapterRhythmLabel(BuildContext context, String key) {
  if (key.startsWith('week-')) {
    final week = int.tryParse(key.substring('week-'.length));
    if (week != null) return AppL10n.of(context).readingChapterWeekShort(week);
  }
  final parts = key.split('-');
  if (parts.length == 2) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year != null && month != null && month >= 1 && month <= 12) {
      return DateFormat.MMM(
        Localizations.localeOf(context).toLanguageTag(),
      ).format(DateTime(year, month));
    }
  }
  return key;
}
