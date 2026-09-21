// Personal reading-statistics dashboard: overview plus activity and taste
// sections. Local plane computes from SQLite; API plane uses GET /v1/me/stats.

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/book_categories.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/rd_segmented_control.dart';
import 'package:readendar/core/widgets/revalidate_on_enter.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/stats/stats_kit.dart';

class UserStatsScreen extends ConsumerWidget {
  const UserStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final async = ref.watch(userStatsProvider);
    return RevalidateOnEnter(
      providers: [userStatsProvider],
      child: Scaffold(
        appBar: AppBar(title: Text(l.myStatsTitle)),
        body: SafeArea(
          top: false,
          child: async.when(
            loading: RdProgress.centered,
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(userStatsProvider),
            ),
            data: (stats) => RdRefresh(
              onRefresh: () async => ref.invalidate(userStatsProvider),
              child: _StatsHome(stats: stats),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Home: overview + section navigation list ────────────────────

class _StatsHome extends StatelessWidget {
  const _StatsHome({required this.stats});
  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final s = stats.summary;
    final o = stats.overview;
    final sections = _statSections();
    final number = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    );
    final year = o.available ? o.year : DateTime.now().year;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        StatSection(
          icon: LucideIcons.bookMarked,
          title: l.myStatsSummary,
          subtitle: '$year · ${l.myStatsThisYear}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MetricGrid([
                StatTile(
                  l.myStatsFinishedYear,
                  '${o.finishedBooks}',
                  tone: StatTone.primary,
                ),
                StatTile(
                  l.myStatsLoggedPages,
                  number.format(o.loggedPages),
                  tone: o.loggedPages > 0 ? StatTone.primary : StatTone.neutral,
                ),
                StatTile(l.myStatsActiveDays, '${o.activeDays}'),
                StatTile(
                  l.myStatsCurrentDayStreak,
                  '${o.currentDayStreak}',
                  unit: l.myStatsUnitDays,
                  tone: o.currentDayStreak > 0
                      ? StatTone.good
                      : StatTone.neutral,
                ),
              ]),
              if (o.changePercent != null) ...[
                const SizedBox(height: ReadendarTokens.sp4),
                InfoPanel(
                  icon: o.changePercent! >= 0
                      ? LucideIcons.trendingUp
                      : LucideIcons.trendingDown,
                  label: l.myStatsComparedPreviousYear,
                  value:
                      '${_signedPercent(o.changePercent!)} · ${l.myStatsPagesPreview(o.previousYearPages)}',
                  tone: statSignTone(o.changePercent!),
                ),
              ],
              if (o.monthly.isNotEmpty) ...[
                const SizedBox(height: ReadendarTokens.sp4),
                ChartPanel(
                  label: l.myStatsYearEvolution,
                  height: 210,
                  child: BooksPagesTrendChart(
                    pages: [for (final month in o.monthly) month.pages],
                    books: [for (final month in o.monthly) month.books],
                    labels: [
                      for (final month in o.monthly)
                        _shortMonthLabel(context, month.month),
                    ],
                    pagesLabel: l.myStatsLoggedPages,
                    booksLabel: l.myStatsBooksSeries,
                  ),
                ),
              ],
              const SizedBox(height: ReadendarTokens.sp4),
              DistributionPanel(
                label: l.myStatsLibraryMix,
                colors: const [
                  ReadendarTokens.periwinkle500,
                  ReadendarTokens.teal400,
                  ReadendarTokens.amber500,
                  ReadendarTokens.wine500,
                  ReadendarTokens.sage500,
                ],
                items: [
                  DistributionData(
                    label: l.myStatsBooksRead,
                    value: s.booksRead,
                  ),
                  DistributionData(
                    label: l.myStatsBooksReading,
                    value: s.booksReading,
                  ),
                  DistributionData(
                    label: l.myStatsBooksQueued,
                    value: s.booksQueued,
                  ),
                  DistributionData(
                    label: l.myStatsBooksWanted,
                    value: s.booksWanted,
                  ),
                  DistributionData(
                    label: l.myStatsBooksAbandoned,
                    value: s.booksAbandoned,
                  ),
                ],
              ),
              if (s.finishedBookPages > 0) ...[
                const SizedBox(height: ReadendarTokens.sp3),
                InfoPanel(
                  icon: LucideIcons.bookOpen,
                  label: l.myStatsFinishedBookPages,
                  value: number.format(s.finishedBookPages),
                ),
              ],
              if (s.readingSince != null) ...[
                const SizedBox(height: ReadendarTokens.sp3),
                HintText(
                  l.myStatsReadingSince(
                    formatMediumDate(context, s.readingSince!),
                  ),
                ),
              ],
            ],
          ),
        ),
        SectionList(
          children: [
            for (final sec in sections)
              SectionRow(
                icon: sec.icon,
                title: sec.title(l),
                preview: sec.preview(l, stats),
                onTap: () => Navigator.of(context).push(
                  rdPageRoute<void>(
                    context,
                    builder: (ctx) => sec.isPageActivity
                        ? UserPageActivityScreen(initialStats: stats)
                        : sec.isTaste
                        ? UserTasteStatsScreen(initialStats: stats)
                        : StatSectionDetailScreen(
                            title: sec.title(l),
                            child: sec.body(ctx, AppL10n.of(ctx), stats),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Section descriptors ─────────────────────────────────────────

class _StatSection {
  const _StatSection({
    required this.icon,
    required this.title,
    required this.preview,
    required this.body,
    this.isPageActivity = false,
    this.isTaste = false,
  });
  final IconData icon;
  final String Function(AppL10n) title;
  final StatPreview? Function(AppL10n, UserStats) preview;
  final Widget Function(BuildContext, AppL10n, UserStats) body;
  final bool isPageActivity;
  final bool isTaste;
}

List<_StatSection> _statSections() => [
  _StatSection(
    icon: LucideIcons.flame,
    isPageActivity: true,
    title: (l) => l.myStatsActivity,
    preview: (l, s) => s.pageActivity.available
        ? StatPreview(
            l.myStatsPagesPreview(s.pageActivity.totalPages),
            s.pageActivity.totalPages > 0 ? StatTone.good : StatTone.neutral,
          )
        : const StatPreview('—', StatTone.neutral),
    body: _activityBody,
  ),
  _StatSection(
    icon: LucideIcons.sparkles,
    isTaste: true,
    title: (l) => l.myStatsTaste,
    preview: (l, s) {
      final t = s.taste;
      if (t.avgRating != null) {
        return StatPreview(
          '${t.avgRating!.toStringAsFixed(1)}★',
          StatTone.primary,
        );
      }
      return t.topGenres.isNotEmpty
          ? StatPreview('${t.topGenres.length}', StatTone.neutral)
          : const StatPreview('—', StatTone.neutral);
    },
    body: _tasteBody,
  ),
];

class UserPageActivityScreen extends ConsumerStatefulWidget {
  const UserPageActivityScreen({required this.initialStats, super.key});
  final UserStats initialStats;

  @override
  ConsumerState<UserPageActivityScreen> createState() =>
      _UserPageActivityScreenState();
}

class _UserPageActivityScreenState
    extends ConsumerState<UserPageActivityScreen> {
  PageActivityQuery _query = const PageActivityQuery();
  // The home response may have been cached before the period semantics were
  // changed. Refetch the current month when entering the detail screen so the
  // selector cannot display a stale rolling range. Keep the unavailable
  // fallback for older servers that omit pageActivity altogether.
  bool _useInitial = true;
  UserPageActivity? _shownActivity;

  @override
  void initState() {
    super.initState();
    _useInitial = !widget.initialStats.pageActivity.available;
  }

  void _retainShownActivity() {
    final stats = _useInitial
        ? widget.initialStats
        : ref.read(userPageStatsProvider(_query)).asData?.value;
    final activity = stats?.pageActivity;
    if (activity?.available == true) _shownActivity = activity;
  }

  void _setQuery(PageActivityQuery query) {
    _retainShownActivity();
    setState(() {
      _query = query;
      _useInitial = false;
    });
  }

  Future<void> _refresh() async {
    _retainShownActivity();
    setState(() => _useInitial = false);
    ref.invalidate(userPageStatsProvider(_query));
    await ref.read(userPageStatsProvider(_query).future);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final async = _useInitial
        ? AsyncValue<UserStats>.data(widget.initialStats)
        : ref.watch(userPageStatsProvider(_query));
    final hasPageActivity =
        async.asData?.value.pageActivity.available ??
        widget.initialStats.pageActivity.available;
    final fetchedActivity = async.asData?.value.pageActivity;
    final activity = fetchedActivity?.available == true
        ? fetchedActivity
        : _shownActivity;
    final content = activity == null
        ? async.when(
            loading: () => SizedBox(
              key: const ValueKey('page-activity-loading'),
              height: 430,
              child: RdProgress.centered(),
            ),
            error: (e, _) => SizedBox(
              key: const ValueKey('page-activity-error'),
              height: 430,
              child: ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(userPageStatsProvider(_query)),
              ),
            ),
            data: (_) => NotePanel(
              key: const ValueKey('page-activity-unavailable'),
              l.myStatsPageActivityUnavailable,
            ),
          )
        : _PageActivityPeriodPanel(
            key: ValueKey(
              '${activity.granularity.apiValue}:${activity.offset}:${activity.from.toIso8601String()}',
            ),
            activity: activity,
            onPrevious:
                _query.granularity == PageGranularity.all ||
                    _query.offset <= -24
                ? null
                : () => _setQuery(_query.copyWith(offset: _query.offset - 1)),
            onNext:
                _query.granularity == PageGranularity.all || _query.offset == 0
                ? null
                : () => _setQuery(_query.copyWith(offset: _query.offset + 1)),
          );
    return Scaffold(
      appBar: AppBar(title: Text(l.myStatsActivity)),
      body: RdRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            if (hasPageActivity)
              _PageActivityGranularitySelector(
                query: _query,
                onChanged: (granularity) => _setQuery(
                  PageActivityQuery(granularity: granularity),
                ),
              ),
            if (hasPageActivity) const SizedBox(height: ReadendarTokens.sp4),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                // Only the entering period is kept in the layout. The default
                // AnimatedSwitcher stacks its departing child underneath the
                // new one, which briefly looked like a second panel on top of
                // the chart while a request was resolving.
                layoutBuilder: (currentChild, _) =>
                    currentChild ?? const SizedBox.shrink(),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: content,
              ),
            ),
            const SizedBox(height: ReadendarTokens.sp6),
            // Other activity metrics do not depend on the selected page period.
            _activityBody(context, l, widget.initialStats),
          ],
        ),
      ),
    );
  }
}

class _PageActivityGranularitySelector extends StatelessWidget {
  const _PageActivityGranularitySelector({
    required this.query,
    required this.onChanged,
  });

  final PageActivityQuery query;
  final ValueChanged<PageGranularity> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return SizedBox(
      width: double.infinity,
      child: RdSegmentedControl<PageGranularity>(
        selected: query.granularity,
        onChanged: onChanged,
        segments: [
          RdSegment(
            value: PageGranularity.week,
            label: l.myStatsGranularityWeek,
          ),
          RdSegment(
            value: PageGranularity.month,
            label: l.myStatsGranularityMonth,
          ),
          RdSegment(
            value: PageGranularity.year,
            label: l.myStatsGranularityYear,
          ),
          RdSegment(
            value: PageGranularity.all,
            label: l.myStatsGranularityAll,
          ),
        ],
      ),
    );
  }
}

class _PageActivityPeriodPanel extends StatelessWidget {
  const _PageActivityPeriodPanel({
    required this.activity,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final UserPageActivity activity;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat.decimalPattern(locale);
    final values = [for (final b in activity.buckets) b.pages.toDouble()];
    final labels = [
      for (final b in activity.buckets)
        _pageBucketAxisLabel(b, activity.granularity, locale),
    ];
    final mutedIndices = <int>{
      for (var i = 0; i < activity.buckets.length; i++)
        if (activity.buckets[i].isFuture) i,
    };
    final isAll = activity.granularity == PageGranularity.all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          key: const ValueKey('page-activity-period-navigation'),
          height: kMinInteractiveDimension,
          child: Row(
            children: [
              if (isAll)
                const SizedBox(width: kMinInteractiveDimension)
              else
                RdIconButton(
                  tooltip: l.myStatsPreviousPeriod,
                  onPressed: onPrevious,
                  icon: LucideIcons.chevronLeft,
                ),
              Expanded(
                child: Text(
                  _pagePeriodLabel(context, activity),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (isAll)
                const SizedBox(width: kMinInteractiveDimension)
              else
                RdIconButton(
                  tooltip: l.myStatsNextPeriod,
                  onPressed: onNext,
                  icon: LucideIcons.chevronRight,
                ),
            ],
          ),
        ),
        const SizedBox(height: ReadendarTokens.sp3),
        MetricGrid(
          [
            StatTile(
              l.sectionToday,
              number.format(activity.todayPages),
              tone: activity.todayPages > 0 ? StatTone.good : StatTone.neutral,
            ),
            StatTile(
              l.myStatsPagesInRange,
              number.format(activity.totalPages),
              tone: activity.totalPages > 0
                  ? StatTone.primary
                  : StatTone.neutral,
            ),
            StatTile(
              l.myStatsReadingDays,
              number.format(activity.activeDays),
            ),
            StatTile(
              l.myStatsAverage,
              number.format(activity.averagePages.round()),
              unit: _averageUnit(l, activity.granularity),
            ),
          ],
          maxColumns: 2,
        ),
        if (activity.previousPages != null) ...[
          const SizedBox(height: ReadendarTokens.sp3),
          InfoPanel(
            icon: activity.totalPages >= activity.previousPages!
                ? LucideIcons.trendingUp
                : LucideIcons.trendingDown,
            label: l.myStatsPreviousPeriod,
            value:
                '${_periodChange(activity.totalPages, activity.previousPages!)} · ${l.myStatsPagesPreview(activity.previousPages!)}',
            tone: statSignTone(activity.totalPages - activity.previousPages!),
          ),
        ],
        const SizedBox(height: ReadendarTokens.sp4),
        ChartPanel(
          label: l.myStatsPageChart,
          height: 190,
          child: BarTrendChart(
            values: values,
            labels: labels,
            showYAxis: true,
            barWidth: _pageChartBarWidth(activity.granularity, values.length),
            labelInterval: _pageChartLabelInterval(
              activity.granularity,
              values.length,
            ),
            mutedIndices: mutedIndices,
            tooltipForIndex: (index, value) {
              final bucket = activity.buckets[index];
              if (bucket.isFuture) return null;
              final range = bucket.startDate == bucket.endDate
                  ? formatMediumDate(context, bucket.startDate)
                  : '${formatMediumDate(context, bucket.startDate)} – ${formatMediumDate(context, bucket.endDate)}';
              return '$range\n${l.myStatsPagesPreview(value.round())}';
            },
          ),
        ),
        if (activity.granularity == PageGranularity.month &&
            activity.buckets.isNotEmpty) ...[
          const SizedBox(height: ReadendarTokens.sp3),
          ChartPanel(
            label: l.myStatsConsistency,
            // Height follows the number of calendar rows, avoiding both a
            // six-week-month overflow and unused space in shorter months.
            child: SizedBox(
              width: double.infinity,
              child: ReadingHeatmap(
                days: [
                  for (final bucket in activity.buckets)
                    ReadingHeatmapDay(
                      date: bucket.startDate,
                      value: bucket.pages,
                      label:
                          '${formatMediumDate(context, bucket.startDate)} · ${l.myStatsPagesPreview(bucket.pages)}',
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _pagePeriodLabel(BuildContext context, UserPageActivity activity) {
  final locale = Localizations.localeOf(context).toString();
  return switch (activity.granularity) {
    // A day is one calendar date, never a range.
    PageGranularity.day => formatMediumDate(context, activity.from),
    // Weeks always represent the complete locale-aware calendar week.
    PageGranularity.week =>
      '${formatMediumDate(context, activity.from)} – ${formatMediumDate(context, activity.to)}',
    // Month and year navigation advance exactly one calendar unit at a time.
    PageGranularity.month => DateFormat.yMMMM(locale).format(activity.from),
    PageGranularity.year => DateFormat.y(locale).format(activity.from),
    PageGranularity.all =>
      activity.from.year == activity.to.year
          ? DateFormat.y(locale).format(activity.from)
          : '${DateFormat.y(locale).format(activity.from)} – ${DateFormat.y(locale).format(activity.to)}',
  };
}

String _pageBucketAxisLabel(
  UserPageBucket bucket,
  PageGranularity granularity,
  String locale,
) => switch (granularity) {
  PageGranularity.day => DateFormat.Md(locale).format(bucket.startDate),
  PageGranularity.week => DateFormat.E(locale).format(bucket.startDate),
  PageGranularity.month => DateFormat.d(locale).format(bucket.startDate),
  PageGranularity.year => DateFormat.MMM(locale).format(bucket.startDate),
  PageGranularity.all => DateFormat.y(locale).format(bucket.startDate),
};

double _pageChartBarWidth(PageGranularity granularity, int count) =>
    switch (granularity) {
      PageGranularity.day => 32,
      PageGranularity.week => 18,
      PageGranularity.month => 7,
      PageGranularity.year => 14,
      PageGranularity.all => count > 12 ? 9 : 16,
    };

int _pageChartLabelInterval(PageGranularity granularity, int count) =>
    switch (granularity) {
      PageGranularity.day || PageGranularity.week => 1,
      PageGranularity.month => 5,
      PageGranularity.year => 1,
      PageGranularity.all => count > 12 ? 2 : 1,
    };

// ─── Section bodies ──────────────────────────────────────────────

// Actividad: cuánto y con qué constancia lee el usuario a lo largo del tiempo
// (acabados recientes, racha de meses, mejor mes, libros/mes).
Widget _activityBody(BuildContext context, AppL10n l, UserStats stats) {
  final a = stats.activity;
  final hasChart = a.monthly.any((m) => m.count > 0);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MetricGrid([
        StatTile(
          l.myStatsFinished30,
          '${a.finished30}',
          tone: a.finished30 > 0 ? StatTone.good : StatTone.neutral,
        ),
        StatTile(
          l.myStatsFinishedYear,
          '${a.finishedYear}',
          tone: StatTone.primary,
        ),
        StatTile(l.myStatsAdded30, '${a.added30}'),
        StatTile(
          l.myStatsCurrentStreak,
          '${a.currentStreak}',
          unit: l.myStatsUnitMonths,
          tone: a.currentStreak > 0 ? StatTone.good : StatTone.neutral,
        ),
        StatTile(
          l.myStatsLongestStreak,
          '${a.longestStreak}',
          unit: l.myStatsUnitMonths,
        ),
      ]),
      if (a.bestMonth.isNotEmpty) ...[
        const SizedBox(height: ReadendarTokens.sp4),
        InfoPanel(
          icon: LucideIcons.flame,
          label: l.myStatsBestMonth,
          value: '${_monthLabel(context, a.bestMonth)} · ${a.bestMonthCount}',
          tone: StatTone.primary,
        ),
      ],
      if (hasChart) ...[
        const SizedBox(height: ReadendarTokens.sp4),
        ChartPanel(
          label: l.myStatsFinishedChart,
          height: 150,
          child: BarTrendChart(
            values: [for (final m in a.monthly) m.count.toDouble()],
            labels: [for (final m in a.monthly) m.month.split('-').last],
          ),
        ),
      ],
    ],
  );
}

class UserTasteStatsScreen extends ConsumerStatefulWidget {
  const UserTasteStatsScreen({required this.initialStats, super.key});
  final UserStats initialStats;

  @override
  ConsumerState<UserTasteStatsScreen> createState() =>
      _UserTasteStatsScreenState();
}

class _UserTasteStatsScreenState extends ConsumerState<UserTasteStatsScreen> {
  TasteScope _scope = TasteScope.year;
  bool _useInitial = true;

  PageActivityQuery get _query => PageActivityQuery(tasteScope: _scope);

  Future<void> _refresh() async {
    setState(() => _useInitial = false);
    ref.invalidate(userPageStatsProvider(_query));
    await ref.read(userPageStatsProvider(_query).future);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final async = _useInitial
        ? AsyncValue<UserStats>.data(widget.initialStats)
        : ref.watch(userPageStatsProvider(_query));
    return Scaffold(
      appBar: AppBar(title: Text(l.myStatsTaste)),
      body: RdRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            RdSegmentedControl<TasteScope>(
              selected: _scope,
              onChanged: (scope) => setState(() {
                _scope = scope;
                _useInitial = false;
              }),
              segments: [
                RdSegment(value: TasteScope.year, label: l.myStatsBooksRead),
                RdSegment(value: TasteScope.all, label: l.myStatsAllTime),
              ],
            ),
            const SizedBox(height: ReadendarTokens.sp5),
            async.when(
              loading: () =>
                  SizedBox(height: 420, child: RdProgress.centered()),
              error: (e, _) => ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(userPageStatsProvider(_query)),
              ),
              data: (stats) => _tasteBody(context, l, stats),
            ),
          ],
        ),
      ),
    );
  }
}

// Taste is deliberately scoped to finished books, so unfinished backlog never
// distorts genre, author, rating, or format preferences.
Widget _tasteBody(BuildContext context, AppL10n l, UserStats stats) {
  final t = stats.taste;
  if (t.completedCount == 0) return NotePanel(l.myStatsNoTaste);
  final maxGenre = maxOf(t.topGenres.map((g) => g.count));
  final maxAuthor = maxOf(t.topAuthors.map((a) => a.count));
  final hasRatings = t.ratingDistribution.any((bucket) => bucket.count > 0);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MetricGrid([
        StatTile(
          l.myStatsAvgRating,
          t.avgRating?.toStringAsFixed(1) ?? '—',
          unit: t.avgRating == null ? null : '★',
          tone: t.avgRating == null ? StatTone.neutral : StatTone.primary,
        ),
        StatTile(
          l.myStatsTopGenres,
          '${t.topGenres.length}',
          tone: t.topGenres.isEmpty ? StatTone.neutral : StatTone.primary,
        ),
        StatTile(
          l.myStatsHighRatings,
          '${t.highRatingPercent}%',
          tone: t.highRatingPercent >= 60 ? StatTone.good : StatTone.neutral,
        ),
        StatTile(
          l.myStatsRepeatAuthors,
          '${t.topAuthors.length}',
          tone: t.topAuthors.isEmpty ? StatTone.neutral : StatTone.primary,
        ),
      ], maxColumns: 2),
      if (hasRatings) ...[
        const SizedBox(height: ReadendarTokens.sp4),
        ChartPanel(
          label: l.myStatsRatingDistribution,
          height: 160,
          child: BarTrendChart(
            values: [
              for (final bucket in t.ratingDistribution)
                bucket.count.toDouble(),
            ],
            labels: [
              for (final bucket in t.ratingDistribution) '${bucket.rating}★',
            ],
            showYAxis: true,
          ),
        ),
      ],
      if (t.topGenres.isNotEmpty) ...[
        const SizedBox(height: ReadendarTokens.sp3),
        BarPanel(
          label: l.myStatsGenreAffinity,
          barColor: ReadendarTokens.teal400,
          rows: [
            for (final g in t.topGenres)
              BarData(
                label: bookCategoryLabel(l, g.code),
                fraction: g.count / maxGenre,
                trailing:
                    '${g.count}${g.avgRating == null ? '' : ' · ${g.avgRating!.toStringAsFixed(1)}★'}',
              ),
          ],
        ),
      ],
      if (t.topAuthors.isNotEmpty) ...[
        const SizedBox(height: ReadendarTokens.sp3),
        BarPanel(
          label: l.myStatsRepeatAuthors,
          rows: [
            for (final a in t.topAuthors)
              BarData(
                label: a.author,
                fraction: a.count / maxAuthor,
                trailing:
                    '${a.count}${a.avgRating == null ? '' : ' · ${a.avgRating!.toStringAsFixed(1)}★'}',
              ),
          ],
        ),
      ],
      if (t.formats.isNotEmpty) ...[
        const SizedBox(height: ReadendarTokens.sp3),
        DonutDistributionPanel(
          label: l.myStatsFormats,
          items: [
            for (final format in t.formats)
              DistributionData(
                label: _formatLabel(l, format.format),
                value: format.count,
              ),
          ],
        ),
      ],
    ],
  );
}

/// "2026-06" → a localized "Jun 2026"; falls back to the raw key if unparseable.
String _monthLabel(BuildContext context, String key) {
  final d = DateTime.tryParse('$key-01');
  if (d == null) return key;
  return DateFormat.yMMM(Localizations.localeOf(context).toString()).format(d);
}

String _shortMonthLabel(BuildContext context, String key) {
  final d = DateTime.tryParse('$key-01');
  if (d == null) return key;
  return DateFormat.MMM(Localizations.localeOf(context).toString()).format(d);
}

String _signedPercent(num value) => '${value >= 0 ? '+' : ''}${value.round()}%';

String _periodChange(int current, int previous) {
  if (previous == 0) return current == 0 ? '0%' : '+100%';
  return _signedPercent((current - previous) * 100 / previous);
}

String _averageUnit(AppL10n l, PageGranularity granularity) =>
    switch (granularity) {
      PageGranularity.day ||
      PageGranularity.week ||
      PageGranularity.month => l.myStatsUnitPagesPerDay,
      PageGranularity.year => l.myStatsUnitPagesPerMonth,
      PageGranularity.all => l.myStatsUnitPagesPerYear,
    };

String _formatLabel(AppL10n l, String format) => switch (format) {
  'physical' => l.myStatsFormatPhysical,
  'ebook' => l.myStatsFormatEbook,
  'audiobook' => l.myStatsFormatAudiobook,
  _ => l.myStatsFormatOther,
};
