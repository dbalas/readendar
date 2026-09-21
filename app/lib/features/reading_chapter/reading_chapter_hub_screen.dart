import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/rd_scaffold.dart';
import 'package:readendar/core/widgets/rd_segmented_control.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/skeleton.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_format.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_story_screen.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_vector_icon.dart';

enum _ChapterFilter { all, month, year }

@visibleForTesting
bool readingChapterArchiveRequestIsCurrent({
  required int requestGeneration,
  required int currentGeneration,
  required String requestFilter,
  required String currentFilter,
}) => requestGeneration == currentGeneration && requestFilter == currentFilter;

class ReadingChapterHubScreen extends ConsumerStatefulWidget {
  const ReadingChapterHubScreen({super.key});

  @override
  ConsumerState<ReadingChapterHubScreen> createState() =>
      _ReadingChapterHubScreenState();
}

class _ReadingChapterHubScreenState
    extends ConsumerState<ReadingChapterHubScreen> {
  _ChapterFilter _filter = _ChapterFilter.all;
  late final PageController _pages;

  String get _wire => switch (_filter) {
    _ChapterFilter.all => 'all',
    _ChapterFilter.month => 'month',
    _ChapterFilter.year => 'year',
  };

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _selectFilter(_ChapterFilter value) {
    if (_filter == value) return;
    setState(() => _filter = value);
    final index = value.index;
    if (_pages.hasClients && _pages.page?.round() != index) {
      _pages.jumpToPage(index);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(readingChapterArchiveProvider(_wire));
    ref.invalidate(readingChapterLatestProvider);
    if (_wire != 'all') {
      ref.invalidate(readingChapterArchiveProvider('all'));
    }
    await ref.read(readingChapterArchiveProvider(_wire).future);
  }

  void _open(ReadingChapterRequest request) {
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (_) => ReadingChapterStoryScreen(request: request),
      ),
    );
  }

  void _precacheArchive(ReadingChapterArchive archive) {
    precacheReadingChapterCoverUrls(
      context,
      archive.items.expand((item) => item.coverUrls.take(3)),
      displayWidth: 52,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final heroArchive = ref.watch(readingChapterLatestProvider);
    ref.listen(readingChapterLatestProvider, (_, next) {
      final archive = next.asData?.value;
      if (archive != null) _precacheArchive(archive);
    });
    return RdScaffold(
      title: Text(l.readingChapterTitle),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: heroArchive.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              skipError: true,
              data: (value) => _HubHero(
                archive: value,
                onOpenLatest: value.items.isEmpty
                    ? null
                    : () => _open(value.items.first.request),
              ),
              loading: () => const _HubHeroSkeleton(),
              error: (error, _) => ErrorRetry(
                error: error,
                onRetry: () =>
                    ref.invalidate(readingChapterLatestProvider),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: RdSegmentedControl<_ChapterFilter>(
              key: const Key('readingChapterHubTabs'),
              selected: _filter,
              onChanged: _selectFilter,
              segments: [
                RdSegment(
                  value: _ChapterFilter.all,
                  label: l.readingChapterAll,
                ),
                RdSegment(
                  value: _ChapterFilter.month,
                  label: l.readingChapterMonths,
                ),
                RdSegment(
                  value: _ChapterFilter.year,
                  label: l.readingChapterYears,
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              key: const Key('readingChapterHubPages'),
              controller: _pages,
              itemCount: _ChapterFilter.values.length,
              onPageChanged: (index) {
                final next = _ChapterFilter.values[index];
                if (_filter == next) return;
                setState(() => _filter = next);
              },
              itemBuilder: (context, index) {
                final filter = _ChapterFilter.values[index];
                return _ArchivePane(
                  key: PageStorageKey('reading-chapter-archive-$filter'),
                  kind: switch (filter) {
                    _ChapterFilter.all => 'all',
                    _ChapterFilter.month => 'month',
                    _ChapterFilter.year => 'year',
                  },
                  onOpen: _open,
                  onRefresh: _refresh,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivePane extends ConsumerStatefulWidget {
  const _ArchivePane({
    required this.kind,
    required this.onOpen,
    required this.onRefresh,
    super.key,
  });

  final String kind;
  final ValueChanged<ReadingChapterRequest> onOpen;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_ArchivePane> createState() => _ArchivePaneState();
}

class _ArchivePaneState extends ConsumerState<_ArchivePane> {
  final _additionalItems = <ReadingChapterArchiveItem>[];
  final _scroll = ScrollController();
  String? _additionalCursor;
  bool _loadingMore = false;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter > 320) return;
    final archive = ref
        .read(readingChapterArchiveProvider(widget.kind))
        .asData
        ?.value;
    if (archive != null) unawaited(_loadMore(archive));
  }

  Future<void> _refresh() async {
    setState(() {
      _additionalItems.clear();
      _additionalCursor = null;
      _requestGeneration++;
    });
    await widget.onRefresh();
  }

  Future<void> _loadMore(ReadingChapterArchive archive) async {
    if (_loadingMore) return;
    final cursor = _additionalCursor ?? archive.nextCursor;
    if (cursor.isEmpty) return;
    setState(() => _loadingMore = true);
    final generation = _requestGeneration;
    final result = await ref
        .read(readingChapterRepoProvider)
        .fetchArchive(kind: widget.kind, after: cursor);
    if (!mounted) return;
    if (!readingChapterArchiveRequestIsCurrent(
      requestGeneration: generation,
      currentGeneration: _requestGeneration,
      requestFilter: widget.kind,
      currentFilter: widget.kind,
    )) {
      return;
    }
    setState(() => _loadingMore = false);
    if (result.isErr) {
      showRdFailureToast(context, result.failure!);
      return;
    }
    final page = result.value!;
    setState(() {
      final seen = {
        for (final item in [...archive.items, ..._additionalItems])
          '${item.kind.wire}:${item.periodKey}',
      };
      _additionalItems.addAll(
        page.items.where(
          (item) => seen.add('${item.kind.wire}:${item.periodKey}'),
        ),
      );
      _additionalCursor = page.nextCursor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final archive = ref.watch(readingChapterArchiveProvider(widget.kind));
    ref.listen(readingChapterArchiveProvider(widget.kind), (_, next) {
      final value = next.asData?.value;
      if (value == null) return;
      precacheReadingChapterCoverUrls(
        context,
        value.items.expand((item) => item.coverUrls.take(3)),
        displayWidth: 52,
      );
    });
    return RdRefresh(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: SectionHeader(
                    l.readingChapterArchiveTitle,
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
                  ),
                ),
                ..._archiveSlivers(archive),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _archiveSlivers(AsyncValue<ReadingChapterArchive> archive) {
    return archive.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      skipError: true,
      data: (value) {
        final items = [...value.items, ..._additionalItems];
        if (items.isEmpty) {
          return [SliverToBoxAdapter(child: _ArchiveEmpty(kind: widget.kind))];
        }
        final hasMore = (_additionalCursor ?? value.nextCursor).isNotEmpty;
        return [
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == items.length) {
                  if (!_loadingMore) unawaited(_loadMore(value));
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: RdProgress()),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArchiveCard(
                    item: items[index],
                    onTap: () => widget.onOpen(items[index].request),
                  ),
                );
              },
              childCount: items.length + (hasMore ? 1 : 0),
            ),
          ),
        ];
      },
      loading: () => [
        const SliverToBoxAdapter(
          child: _ArchiveListSkeleton(key: Key('readingChapterArchiveLoading')),
        ),
      ],
      error: (error, _) => [
        SliverToBoxAdapter(
          child: ErrorRetry(
            error: error,
            onRetry: () => unawaited(_refresh()),
          ),
        ),
      ],
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({required this.archive, required this.onOpenLatest});
  final ReadingChapterArchive archive;
  final VoidCallback? onOpenLatest;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final colors = context.colors;
    final latest = archive.items.isEmpty ? null : archive.items.first;
    return Semantics(
      button: onOpenLatest != null,
      label: latest == null
          ? l.readingChapterHeroTitle
          : readingChapterPeriodLabel(
              context,
              latest.kind,
              latest.periodKey,
            ),
      child: RdCard(
        onTap: onOpenLatest,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        gradient: readingChapterThemeWash(colors),
        borderColor: readingChapterThemeWashBorder(colors),
        child: Row(
          children: [
            if (latest == null)
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.accentSoftBg,
                  borderRadius: BorderRadius.circular(
                    ReadendarTokens.radiusCard,
                  ),
                ),
                child: Icon(
                  LucideIcons.bookHeart,
                  color: colors.accent,
                  size: 26,
                ),
              )
            else
              _CoverFan(urls: latest.coverUrls),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.readingChapterTitle,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: colors.accentSoftFg,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ),
                      if (archive.hasUnread) const ReadingChapterUnreadBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latest == null
                        ? l.readingChapterHeroTitle
                        : readingChapterPeriodLabel(
                            context,
                            latest.kind,
                            latest.periodKey,
                          ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.fg1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latest == null
                        ? l.readingChapterHeroBody
                        : l.readingChapterArchiveWorks(latest.uniqueWorks),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.fg2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ReadingChapterChevron(color: colors.fg3, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HubHeroSkeleton extends StatelessWidget {
  const _HubHeroSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonPulse(
    child: Row(
      children: [
        SkeletonBox(width: 66, height: 86, radius: 8),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 92, height: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 160, height: 16),
              SizedBox(height: 8),
              SkeletonBox(width: 110, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ArchiveListSkeleton extends StatelessWidget {
  const _ArchiveListSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const SkeletonPulse(
    child: Column(
      children: [
        _ArchiveRowSkeleton(),
        SizedBox(height: 12),
        _ArchiveRowSkeleton(),
        SizedBox(height: 12),
        _ArchiveRowSkeleton(),
      ],
    ),
  );
}

class _ArchiveRowSkeleton extends StatelessWidget {
  const _ArchiveRowSkeleton();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      SkeletonBox(width: 66, height: 86, radius: 8),
      SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 150, height: 16),
            SizedBox(height: 8),
            SkeletonBox(width: 90, height: 12),
          ],
        ),
      ),
    ],
  );
}

class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({required this.item, required this.onTap});
  final ReadingChapterArchiveItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return RdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _CoverFan(urls: item.coverUrls),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        readingChapterPeriodLabel(
                          context,
                          item.kind,
                          item.periodKey,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (!item.seen)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: context.colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l.readingChapterArchiveWorks(item.uniqueWorks),
                  style: TextStyle(color: context.colors.fg2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ReadingChapterChevron(color: context.colors.fg3),
        ],
      ),
    );
  }
}

class _CoverFan extends StatelessWidget {
  const _CoverFan({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        width: 66,
        height: 86,
        decoration: BoxDecoration(
          color: context.colors.accentSoftBg,
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
        ),
        child: Icon(LucideIcons.bookOpen, color: context.colors.accent),
      );
    }
    return SizedBox(
      width: 76,
      height: 90,
      child: Stack(
        children: [
          for (var index = urls.take(3).length - 1; index >= 0; index--)
            Positioned(
              left: index * 9,
              top: index * 2,
              child: Transform.rotate(
                angle: (index - 1) * 0.05,
                child: BookCover(
                  title: '',
                  coverUrl: urls[index],
                  width: 52,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArchiveEmpty extends StatelessWidget {
  const _ArchiveEmpty({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
    child: Column(
      children: [
        Icon(
          LucideIcons.libraryBig,
          size: 54,
          color: context.colors.accent,
        ),
        const SizedBox(height: 14),
        Text(
          AppL10n.of(context).readingChapterArchiveEmptyTitle(kind),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}
