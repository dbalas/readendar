// Reading-plan history + undo (spec §6.9). Lists recent plan runs for a book
// (backend caps at 10); each can be undone, which soft-deletes the still-live
// events that plan created and removes the run.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/gradient_button.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_refresh.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/plan/presentation/plan_history_empty_art.dart';
import 'package:readendar/features/plan/presentation/plan_screen.dart';
import 'package:readendar/features/plan/presentation/replan_launch.dart';
import 'package:readendar/features/widget/widget_sync.dart';

class PlanHistoryScreen extends ConsumerStatefulWidget {
  const PlanHistoryScreen({
    required this.bookId,
    super.key,
    this.book,
    this.progress,
  });
  final String bookId;

  /// The book + its planning context, passed through so the empty placeholder
  /// can offer the same "Planificar lectura" launcher as the book detail. Null
  /// when the screen is opened without that context (the placeholder then shows
  /// the message only, no CTA).
  final Book? book;
  final Progress? progress;

  @override
  ConsumerState<PlanHistoryScreen> createState() => _PlanHistoryScreenState();
}

/// First-page size for plan history; mirrors the backend default page size.
const int _kPlansPageSize = 20;

class _PlanHistoryScreenState extends ConsumerState<PlanHistoryScreen> {
  final _scroll = ScrollController();
  final List<PlanRun> _runs = [];
  int _offset = 0;
  bool _loading = false;
  bool _done = false;
  Object? _error;
  // Bumped on every reset (pull-to-refresh) so an in-flight stale page load is
  // discarded instead of being appended.
  int _gen = 0;

  /// The plan run id currently being undone (so only that row spins).
  String? _undoing;

  /// The plan run id whose replan is being loaded (so that row's button spins).
  String? _replanning;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    final gen = _gen;
    setState(() => _loading = true);
    final repo = ref.read(planRepoProvider);
    final r = await repo.listPlans(
      widget.bookId,
      offset: _offset,
    );
    if (!mounted || gen != _gen) return;
    r.fold(
      (page) => setState(() {
        _runs.addAll(page);
        _offset += page.length;
        // A short page means we've reached the end.
        _done = page.length < _kPlansPageSize;
        _loading = false;
        _error = null;
      }),
      (f) => setState(() {
        _loading = false;
        _error = f;
      }),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _gen++;
      _runs.clear();
      _offset = 0;
      _done = false;
      _loading = false;
      _error = null;
    });
    // Keep the book-detail caption / any provider consumer in sync.
    _invalidatePlanList();
    await _loadMore();
  }

  void _invalidatePlanList() {
    ref.invalidate(bookPlansProvider(widget.bookId));
  }

  Future<void> _undo(PlanRun run) async {
    final l = AppL10n.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      icon: LucideIcons.trash2,
      title: l.planUndoConfirmTitle,
      message: l.planUndoConfirmMessage,
      confirmLabel: l.planUndo,
      confirmIcon: LucideIcons.undo2,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _undoing = run.id);
    final res = await ref.read(planRepoProvider).undoPlan(run.id);
    if (!mounted) return;

    res.fold(
      (deleted) {
        // Drop the row locally (the page is paginated; a full reload would jump
        // scroll position) and refresh every view that could show the now-deleted
        // events so they disappear consistently.
        setState(() {
          _runs.removeWhere((p) => p.id == run.id);
          if (_offset > 0) _offset--;
          _undoing = null;
        });
        _invalidatePlanList();
        ref
          ..invalidate(upcomingEventsProvider)
          ..invalidateCalendarEvents(removedPlanId: run.id)
          ..invalidate(bookProvider(widget.bookId))
          ..invalidate(eventsForBookProvider(widget.bookId));
        // The plan's reminders die with its events — resync so they don't keep
        // firing for deleted events, and refresh the home-screen widget.
        final user = ref.read(sessionProvider).user;
        if (user != null) {
          unawaited(
            resyncLocalNotifications(ref, l, user).catchError((Object _) {}),
          );
        }
        unawaited(syncWidget(ref).catchError((Object _) => false));
        showRdToast(
          context,
          tone: RdToastTone.success,
          message: l.planUndone(deleted),
        );
      },
      (_) {
        setState(() => _undoing = null);
        showRdToast(
          context,
          tone: RdToastTone.error,
          message: l.planUndoFailed,
        );
      },
    );
  }

  Future<void> _replan(PlanRun run) async {
    final book = widget.book;
    if (book == null) return;
    setState(() => _replanning = run.id);
    await openReplan(
      context,
      ref,
      book: book,
      run: run,
      progress: widget.progress,
    );
    if (!mounted) return;
    setState(() => _replanning = null);
    // The replan may have replaced this run's pending events — refresh the list
    // so the card's count/range reflect reality on return.
    unawaited(_refresh());
  }

  Widget _emptyState(AppL10n l) {
    final book = widget.book;
    return EmptyState(
      illustration: const PlanHistoryEmptyArt(),
      message: l.planHistoryEmpty,
      action: book == null
          ? null
          : SizedBox(
              width: 280,
              child: GradientButton(
                label: l.planButton,
                icon: LucideIcons.calendarRange,
                onPressed: () => Navigator.of(context).push(
                  rdPageRoute<void>(
                    context,
                    builder: (_) => PlanScreen(
                      book: book,
                      progress: widget.progress,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);

    Widget body;
    if (_runs.isEmpty && _error != null) {
      body = RdRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 420,
              child: ErrorRetry(error: _error!, onRetry: _refresh),
            ),
          ],
        ),
      );
    } else if (_runs.isEmpty && _loading) {
      body = RdProgress.centered();
    } else if (_runs.isEmpty) {
      // Empty (or all undone) — pull-to-refresh still needs a scrollable.
      body = RdRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: 420, child: _emptyState(l))],
        ),
      );
    } else {
      body = RdRefresh(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: _runs.length + (_loading ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= _runs.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: RdProgress.centered(),
              );
            }
            return Padding(
              padding: EdgeInsets.only(bottom: i == _runs.length - 1 ? 0 : 12),
              child: _PlanRunCard(
                run: _runs[i],
                undoing: _undoing == _runs[i].id,
                replanning: _replanning == _runs[i].id,
                // Disable other rows' actions while one is in flight.
                busy: _undoing != null || _replanning != null,
                onUndo: () => _undo(_runs[i]),
                // Replan needs the book (for its total fallback); hidden without.
                onReplan: widget.book == null ? null : () => _replan(_runs[i]),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.planHistoryTitle)),
      body: SafeArea(top: false, child: body),
    );
  }
}

class _PlanRunCard extends StatelessWidget {
  const _PlanRunCard({
    required this.run,
    required this.undoing,
    required this.replanning,
    required this.busy,
    required this.onUndo,
    required this.onReplan,
  });

  final PlanRun run;
  final bool undoing;
  final bool replanning;
  final bool busy;
  final VoidCallback onUndo;

  /// Null when the screen lacks the book context replan needs.
  final VoidCallback? onReplan;

  /// "By pace · 2 ch/day" — the run's mode + pace, without the date range (which
  /// gets its own line so it never truncates). Uses existing plan l10n keys.
  String _params(AppL10n l) {
    final parts = <String>[
      if (run.mode == 'deadline')
        l.planHistorySummaryDeadline
      else if (run.mode == 'before_event')
        l.planHistorySummaryBeforeEvent
      else
        l.planHistorySummaryPace,
    ];
    final perDay = run.perDay;
    if (perDay != null && perDay > 0) {
      parts.add(
        run.unit == 'chapters'
            ? l.planHistoryPerDayChapters(perDay)
            : l.planHistoryPerDayPages(perDay),
      );
    }
    return parts.join(' · ');
  }

  /// "8 Jun – 20 Jun" — the plan's span, shown on its own line so it's never cut.
  String? _dateRange(BuildContext context, AppL10n l) {
    final start = run.startDate;
    final end = run.endDate;
    if (start == null || end == null) return null;
    final ml = MaterialLocalizations.of(context);
    return l.planRange(
      ml.formatShortDate(start.toLocal()),
      ml.formatShortDate(end.toLocal()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final theme = Theme.of(context);
    final createdStr = MaterialLocalizations.of(
      context,
    ).formatShortDate(run.createdAt.toLocal());
    final dateRange = _dateRange(context, l);
    return RdCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading marker keeps the row visually anchored.
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.accentSoftBg,
            ),
            child: Icon(
              LucideIcons.calendarClock,
              size: 20,
              color: context.colors.accentSoftFg,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.planEventsCount(run.eventCount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _params(l),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colors.fg2,
                  ),
                ),
                // The plan's span lives on its own line so it's never truncated.
                if (dateRange != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateRange,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.fg2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          // The run date sits hard-right, above the undo control.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                createdStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.fg3,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onReplan != null)
                    replanning
                        ? const SizedBox(
                            width: 44,
                            height: 44,
                            child: Padding(
                              padding: EdgeInsets.all(11),
                              child: RdProgress(),
                            ),
                          )
                        : RdIconButton(
                            tooltip: l.planReplanCta,
                            onPressed: busy ? null : onReplan,
                            size: 22,
                            color: context.colors.accent,
                            icon: LucideIcons.calendarSync,
                          ),
                  if (undoing)
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: Padding(
                        padding: EdgeInsets.all(11),
                        child: RdProgress(),
                      ),
                    )
                  else
                    RdIconButton(
                      tooltip: l.planUndo,
                      onPressed: busy ? null : onUndo,
                      size: 24,
                      color: context.colors.danger,
                      icon: LucideIcons.undo2,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
