import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_scaffold.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_curation_screen.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_share_sheet.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_stage.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_story_card.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_vector_icon.dart';

class ReadingChapterStoryScreen extends ConsumerStatefulWidget {
  const ReadingChapterStoryScreen({required this.request, super.key});

  final ReadingChapterRequest request;

  @override
  ConsumerState<ReadingChapterStoryScreen> createState() =>
      _ReadingChapterStoryScreenState();
}

class _ReadingChapterStoryScreenState
    extends ConsumerState<ReadingChapterStoryScreen> {
  late final PageController _controller;
  int _page = 0;
  bool _viewedSent = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _markViewed() {
    if (_viewedSent) return;
    _viewedSent = true;
    unawaited(
      ref.read(readingChapterRepoProvider).markViewed(widget.request).then((_) {
        ref.invalidate(readingChapterArchiveProvider);
        ref.invalidate(readingChapterLatestProvider);
      }),
    );
  }

  Future<void> _editHighlights(ReadingChapterStory story) async {
    final updated = await Navigator.of(context).push<ReadingChapterStory>(
      rdPageRoute<ReadingChapterStory>(
        context,
        builder: (_) => ReadingChapterCurationScreen(story: story),
      ),
    );
    if (!mounted || updated == null) return;
    ref.invalidate(readingChapterStoryProvider(widget.request));
    ref.invalidate(readingChapterArchiveProvider);
    ref.invalidate(readingChapterLatestProvider);
  }

  Future<void> _openReadinessBook(
    ReadingChapterReadinessIssue issue,
  ) async {
    if (issue.kind == 'reviewGrouping') {
      final story = ref
          .read(readingChapterStoryProvider(widget.request))
          .asData
          ?.value;
      final peers = readingChapterGroupingPeerIds(
        issue,
        story?.books ?? const [],
      );
      if (peers.length >= 2) {
        final result = await ref
            .read(readingChapterRepoProvider)
            .saveGrouping(mode: 'merge', entryIds: peers);
        if (!mounted) return;
        if (result.isErr) {
          showRdFailureToast(context, result.failure!);
          return;
        }
        showRdToast(
          context,
          tone: RdToastTone.success,
          message: AppL10n.of(context).readingChapterReadinessGrouping,
        );
        ref
          ..invalidate(readingChapterStoryProvider(widget.request))
          ..invalidate(readingChapterArchiveProvider)
          ..invalidate(readingChapterLatestProvider);
        return;
      }
    }
    if (issue.bookEntryId.isEmpty) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      rdPageRoute<void>(
        context,
        builder: (_) => BookDetailScreen(bookId: issue.bookEntryId),
      ),
    );
    if (!mounted) return;
    ref
      ..invalidate(readingChapterStoryProvider(widget.request))
      ..invalidate(readingChapterArchiveProvider)
      ..invalidate(readingChapterLatestProvider);
  }

  void _precacheVisibleCovers(ReadingChapterStory story) {
    final mosaic = story.cards
        .where((card) => card.kind == 'coverMosaic')
        .expand((card) => card.books.take(7))
        .map((book) => book.coverUrl);
    precacheReadingChapterCoverUrls(context, mosaic, displayWidth: 104);
    final cards = readingChapterVisibleCards(story.cards);
    if (cards.isEmpty) return;
    final page = _page.clamp(0, cards.length - 1);
    final nearby = <String>[
      ...cards[page].books.map((book) => book.coverUrl),
      if (page + 1 < cards.length)
        ...cards[page + 1].books.map((book) => book.coverUrl),
    ];
    precacheReadingChapterCoverUrls(context, nearby);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final story = ref.watch(readingChapterStoryProvider(widget.request));
    final loaded = story.asData?.value;
    ref.listen(readingChapterStoryProvider(widget.request), (_, next) {
      final value = next.asData?.value;
      if (value == null) return;
      _precacheVisibleCovers(value);
    });
    final canAct =
        loaded != null &&
        loaded.meaningful &&
        readingChapterVisibleCards(loaded.cards).isNotEmpty;
    return RdScaffold(
      title: Text(
        readingChapterPeriodLabel(
          context,
          widget.request.kind,
          widget.request.periodKey,
        ),
      ),
      actions: [
        if (canAct) ...[
          RdIconButton(
            tooltip: l.actionShare,
            onPressed: () =>
                openReadingChapterShareSheet(context, story: loaded),
            icon: LucideIcons.share2,
          ),
          RdIconButton(
            tooltip: l.readingChapterHighlightsTitle,
            onPressed: () => _editHighlights(loaded),
            icon: LucideIcons.sparkles,
          ),
        ],
      ],
      body: story.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        skipError: true,
        data: (value) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markViewed());
          if (!value.meaningful ||
              readingChapterVisibleCards(value.cards).isEmpty) {
            return const _ChapterEmpty();
          }
          return _story(value);
        },
        loading: () => const Center(child: RdProgress()),
        error: (error, _) => ErrorRetry(
          error: error,
          onRetry: () =>
              ref.invalidate(readingChapterStoryProvider(widget.request)),
        ),
      ),
    );
  }

  Widget _story(ReadingChapterStory story) {
    final cards = readingChapterVisibleCards(story.cards);
    final issues = readingChapterVisibleReadiness(story.readiness);
    final page = cards.isEmpty ? 0 : _page.clamp(0, cards.length - 1);
    return ReadingChapterStage(
      child: ReadingChapterStoryPager(
        controller: _controller,
        current: page,
        count: cards.length,
        pageViewKey: const Key('readingChapterStoryPages'),
        aboveCards: issues.isEmpty
            ? null
            : _ReadinessBanner(
                issues: issues,
                onOpen: () => unawaited(_showReadiness()),
              ),
        onPageChanged: (next) {
          if (_page == next) return;
          setState(() => _page = next);
          _precacheVisibleCovers(story);
        },
        itemBuilder: (context, index) => ReadingChapterStoryCard(
          key: ValueKey('reading-chapter-card-${cards[index].id}'),
          card: cards[index],
          periodKind: story.period.kind,
          periodKey: story.period.key,
          storyBooks: story.books,
        ),
      ),
    );
  }

  Future<void> _showReadiness() async {
    await showRdModalSheet<void>(
      context: context,
      builder: (_) => _ReadinessSheet(
        request: widget.request,
        onOpenIssue: (issue) => unawaited(_openReadinessBook(issue)),
      ),
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  const _ReadinessBanner({required this.issues, required this.onOpen});

  final List<ReadingChapterReadinessIssue> issues;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Material(
      color: context.colors.warningSoftBg,
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                LucideIcons.wandSparkles,
                color: context.colors.warningSoftFg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppL10n.of(
                    context,
                  ).readingChapterReadinessBanner(issues.length),
                  style: TextStyle(color: context.colors.warningSoftFg),
                ),
              ),
              ReadingChapterChevron(
                size: 18,
                color: context.colors.warningSoftFg,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReadinessSheet extends ConsumerWidget {
  const _ReadinessSheet({required this.request, required this.onOpenIssue});

  final ReadingChapterRequest request;
  final ValueChanged<ReadingChapterReadinessIssue> onOpenIssue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final story = ref.watch(readingChapterStoryProvider(request)).asData?.value;
    final issues = readingChapterVisibleReadiness(
      story?.readiness ?? const <ReadingChapterReadinessIssue>[],
    );
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight.clamp(0, maxHeight).toDouble()
              : maxHeight;
          return SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorialTitle(l.readingChapterReadinessTitle),
                const SizedBox(height: 12),
                Text(
                  l.readingChapterReadinessBody,
                  style: TextStyle(color: context.colors.fg2),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    key: const Key('readingChapterReadinessList'),
                    itemCount: issues.length,
                    itemBuilder: (context, index) {
                      final issue = issues[index];
                      return _ReadinessIssueRow(
                        issue: issue,
                        bookTitle: _bookTitle(
                          story?.books ?? const [],
                          issue.bookEntryId,
                        ),
                        onOpen:
                            issue.kind == 'reviewGrouping' ||
                                issue.bookEntryId.isNotEmpty
                            ? () => onOpenIssue(issue)
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                RdButton.primary(
                  label: l.actionClose,
                  onPressed: () => Navigator.of(context).pop(),
                  expand: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReadinessIssueRow extends StatelessWidget {
  const _ReadinessIssueRow({
    required this.issue,
    required this.bookTitle,
    required this.onOpen,
  });

  final ReadingChapterReadinessIssue issue;
  final String bookTitle;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox.square(
                  key: Key('readingChapterReadinessIcon-${issue.kind}'),
                  dimension: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.accentSoftBg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _readinessIcon(issue.kind),
                        size: 20,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _readinessLabel(AppL10n.of(context), issue.kind),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (bookTitle.isNotEmpty)
                        Text(
                          bookTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.fg2),
                        ),
                    ],
                  ),
                ),
                if (onOpen != null)
                  ReadingChapterChevron(size: 18, color: colors.fg3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _bookTitle(List<ReadingChapterBook> books, String entryId) {
  for (final book in books) {
    if (book.entryId == entryId) return book.title;
  }
  return '';
}

IconData _readinessIcon(String kind) => switch (kind) {
  'unconfirmedDate' => LucideIcons.calendarClock,
  'missingPages' => LucideIcons.files,
  'missingFormat' => LucideIcons.bookType,
  'missingGenres' => LucideIcons.tags,
  'missingCover' => LucideIcons.imageOff,
  'reviewGrouping' => LucideIcons.combine,
  _ => LucideIcons.circleAlert,
};

String _readinessLabel(AppL10n l, String kind) => switch (kind) {
  'unconfirmedDate' => l.readingChapterReadinessUnconfirmedDate,
  'missingPages' => l.readingChapterReadinessMissingPages,
  'missingFormat' => l.readingChapterReadinessMissingFormat,
  'missingGenres' => l.readingChapterReadinessMissingGenres,
  'missingCover' => l.readingChapterReadinessMissingCover,
  'reviewGrouping' => l.readingChapterReadinessGrouping,
  _ => l.readingChapterReadinessInvalidPick,
};

class _ChapterEmpty extends StatelessWidget {
  const _ChapterEmpty();

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.bookDashed,
              size: 74,
              color: context.colors.accent,
            ),
            const SizedBox(height: 18),
            EditorialTitle(l.readingChapterEmptyTitle),
            const SizedBox(height: 14),
            Text(
              l.readingChapterEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.fg2),
            ),
          ],
        ),
      ),
    );
  }
}
