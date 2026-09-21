import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/event_card_compact.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/month_calendar.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/auto_status_events.dart';
import 'package:readendar/features/library/progress_editor.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/plan/domain/plan_generator.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';
import 'package:readendar/features/plan/domain/replan.dart';
import 'package:readendar/features/plan/presentation/plan_event_picker_screen.dart';
import 'package:readendar/features/plan/presentation/plan_wizard.dart';
import 'package:readendar/features/store_review/store_review_prompt.dart';
import 'package:readendar/features/widget/widget_sync.dart';
import 'package:uuid/uuid.dart';

/// Full-screen plan / replan flow. Linear wizard (goal → agenda → options),
/// then a calculated Events preview. Draft applies only on Calculate /
/// Recalculate from scratch; day exclusions on the preview redistribute live.
/// Saving bulk-inserts with progress + rollback, then a completion screen.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({
    required this.book,
    this.progress,
    this.replan,
    super.key,
  });

  final Book book;
  final Progress? progress;

  /// When set, opens in replan mode: wizard is seeded from the live plan, and
  /// create REPLACES old pending events — see `replan.dart`.
  final ReplanLaunch? replan;

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

enum _Phase { form, creating, done }

class _PlanScreenState extends ConsumerState<PlanScreen> {
  /// Last applied plan params (preview + create). Day exclusions live here.
  late PlanInputs _inputs;

  /// Wizard draft — does not touch Events until recalculate-from-scratch.
  late PlanInputs _draft;

  PlanResult _result = PlanResult.empty;
  PlanResult _previewBaseline = PlanResult.empty;

  /// After [generatePlan] / catch-up recalc, day exclusions must honor standing
  /// weekday skips. Replan's live baseline must not — inferred weekdays are for
  /// the wizard only until the user recalculates from scratch.
  bool _baselineHonorsWeekdays = false;

  /// Wizard step: 0 = goal, 1 = agenda, 2 = options, 3 = events preview.
  int _wizardStep = 0;

  /// Flips on the first successful calculate / replan seed.
  bool _computed = false;

  // While the freshly-requested plan is being generated (deferred so the
  // spinner can paint before the synchronous build work).
  bool _calculating = false;

  // The calendar is the default preview (spec: most people plan visually).
  bool _calendarView = true;
  // The visible calendar month. A ValueNotifier (not a plain field behind
  // setState) so paging ‹ › / swiping repaints ONLY the calendar grid via a
  // ValueListenableBuilder, instead of rebuilding the whole screen.
  late final ValueNotifier<DateTime> _previewMonth;

  late final TextEditingController _totalCtrl;
  late final TextEditingController _startUnitCtrl;
  late final TextEditingController _perDayCtrl;

  // Save-flow state (create for a new plan, update for a replan).
  _Phase _phase = _Phase.form;
  int _processed = 0;
  int _total = 0;
  bool _cancelled = false;
  bool _rollingBack = false;
  bool _updatingProgress = false;
  bool _progressCatchUpApplied = false;
  bool _progressCatchUpDismissed = false;
  bool _recalculatedFromOptions = false;
  final Set<String> _progressCompletedEventIds = {};
  Progress? _currentProgress;
  int _doneCount = 0;
  DateTime? _doneStart;
  DateTime? _doneEnd;
  String? _donePlanId;
  bool _undoingDone = false;
  bool _undoingReplan = false;

  bool get _onPreview => _wizardStep >= kPlanWizardStepCount;

  bool get _isReplan => widget.replan != null;

  /// AppBar list/calendar (and exclusion reset) only while a workable preview
  /// is on screen.
  bool get _showPreviewChrome =>
      _phase == _Phase.form &&
      _onPreview &&
      _computed &&
      !_calculating &&
      _result.isOk &&
      !_result.overHardCap;

  void _togglePreviewView() {
    setState(() => _calendarView = !_calendarView);
    final first = _result.startDate;
    if (_calendarView && first != null) {
      _previewMonth.value = DateTime(first.year, first.month);
    }
  }

  /// Every personal replan asks for current progress before rebuilding the
  /// pending tail. The value is only contextual copy; the shared editor owns
  /// the actual page/chapter/percentage mutation.
  int? get _progressUpdateValue {
    if (!_isReplan) return null;
    final total = _inputs.total;
    final recorded = _inputs.unit == PlanUnit.pages
        ? (_currentProgress?.currentPage ?? 0)
        : (_currentProgress?.currentChapter ?? 0);
    if (_progressCatchUpDismissed ||
        _progressCatchUpApplied ||
        (total != null && total > 0 && recorded >= total)) {
      return null;
    }
    return recorded;
  }

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.progress;
    final today = _dateOnly(DateTime.now());
    _previewMonth = ValueNotifier(DateTime(today.year, today.month));
    final replan = widget.replan;
    if (replan != null) {
      // Replan: seed draft+applied from the existing plan and open on the
      // preview (last step). Wizard steps use Continue/Back; preview Back exits.
      final i = replan.state.inputs;
      final saved = replan.state.savedRun;
      final live = [
        ...replan.state.lockedEvents,
        ...replan.state.pending,
        ...replan.state.completedCapstones,
      ];
      // Pace needs a concrete daily target. Deadline-like modes deliberately
      // persist no pace because it is derived from their date window; seeding a
      // default here silently changed the saved options before the user touched
      // the wizard.
      final perDay = i.mode == PlanMode.pace
          ? (i.perDay ?? planDefaultPerDay(i.unit))
          : i.perDay;
      final remindersOn =
          saved?.remindersOn ??
          (live.isEmpty || live.any((e) => e.reminderEnabled));
      _inputs = PlanInputs(
        mode: i.mode,
        unit: i.unit,
        startDate: i.configuredStartDate ?? i.anchorDate,
        total: i.total,
        startUnit: saved?.startUnit ?? i.startUnit,
        endDate: i.endDate,
        perDay: perDay,
        excludedWeekdays: i.excludedWeekdays,
        remindersOn: remindersOn,
        includeStart: saved?.includeStart ?? replan.state.includeStart,
        includeFinish: saved?.includeFinish ?? i.includeFinish,
        anchorEventId: saved?.anchorEventId,
        anchorEventTitle: saved?.anchorEventTitle,
      );
      _draft = _inputs;
      _perDayCtrl = TextEditingController(text: perDay?.toString() ?? '');
      _computed = true;
      _baselineHonorsWeekdays = false;
      _wizardStep = kPlanWizardStepCount;
      _result = _replanInitialResult(replan.state);
      _previewBaseline = _result;
      final first = _result.startDate;
      if (first != null) {
        _previewMonth.value = DateTime(first.year, first.month);
      }
    } else {
      final userId = ref.read(sessionProvider).user?.id;
      final savedUnit = userId == null
          ? null
          : ref.read(prefsStorageProvider).getPlanUnit(userId);
      final savedMode = userId == null
          ? null
          : ref.read(prefsStorageProvider).getPlanMode(userId);
      final preferPages =
          savedUnit == 'pages' ||
          (!(savedUnit == 'chapters') &&
              (widget.book.pageCount != null && widget.book.pageCount! > 0));
      final unit = preferPages ? PlanUnit.pages : PlanUnit.chapters;
      final total = preferPages
          ? widget.book.pageCount
          : widget.book.chapterCount;
      final startUnit = preferPages
          ? (widget.progress?.currentPage ?? 0)
          : (widget.progress?.currentChapter ?? 0);
      final perDay = planDefaultPerDay(unit);
      final mode = PlanMode.fromWire(savedMode);
      _inputs = PlanInputs(
        mode: mode,
        unit: unit,
        startDate: today,
        total: total,
        startUnit: startUnit,
        endDate: mode == PlanMode.deadline
            ? DateTime(today.year, today.month, today.day + 30)
            : null,
        perDay: perDay,
      );
      _draft = _inputs;
      _perDayCtrl = TextEditingController(text: perDay.toString());
    }
    _totalCtrl = TextEditingController(text: _draft.total?.toString() ?? '');
    _startUnitCtrl = TextEditingController(text: _draft.startUnit.toString());
    // No autofocus on open: the form should stay fully visible so the user can
    // scan every field before deciding what to edit.
  }

  @override
  void dispose() {
    _previewMonth.dispose();
    _totalCtrl.dispose();
    _startUnitCtrl.dispose();
    _perDayCtrl.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Draft vs applied schedule params (ignores live day exclusions on preview).
  bool get _draftDirty => !_samePlanParams(_draft, _inputs);

  static bool _samePlanParams(PlanInputs a, PlanInputs b) {
    bool sameDates(DateTime? x, DateTime? y) {
      if (x == null && y == null) return true;
      if (x == null || y == null) return false;
      return x.year == y.year && x.month == y.month && x.day == y.day;
    }

    bool sameSet(Set<int> x, Set<int> y) =>
        x.length == y.length && x.containsAll(y);

    return a.mode == b.mode &&
        a.unit == b.unit &&
        sameDates(a.startDate, b.startDate) &&
        a.total == b.total &&
        a.startUnit == b.startUnit &&
        sameDates(a.endDate, b.endDate) &&
        a.perDay == b.perDay &&
        sameSet(a.excludedWeekdays, b.excludedWeekdays) &&
        a.remindersOn == b.remindersOn &&
        a.includeStart == b.includeStart &&
        a.includeFinish == b.includeFinish &&
        a.anchorEventId == b.anchorEventId;
  }

  /// Whether the draft can produce a plan (drives recalculate button emphasis).
  /// Mirrors `generatePlan`'s validity checks without building events.
  bool get _canCalculate {
    final total = _draft.total;
    if (total == null || total <= 0) return false;
    if (_draft.startUnit.clamp(0, total) >= total) return false;
    if (_draft.excludedWeekdays.length >= 7) return false;
    if (_draft.mode == PlanMode.pace) return (_draft.perDay ?? 0) >= 1;
    // beforeEvent uses the same window math as deadline; the anchor id is only
    // for display / re-pick. Replan seeds endDate without an anchor id.
    final end = _draft.endDate;
    return end != null && !end.isBefore(_dateOnly(_draft.startDate));
  }

  /// Why Calculate is disabled — prefer a specific issue over a generic prompt.
  String _calcDisabledHint(AppL10n l) {
    final total = _draft.total;
    if (total == null || total <= 0) return l.planCalcNeedsFields;
    if (_draft.startUnit.clamp(0, total) >= total) {
      return l.planIssueNothingToRead;
    }
    if (_draft.excludedWeekdays.length >= 7) return l.planIssueNoReadingDays;
    if (_draft.mode == PlanMode.pace && (_draft.perDay ?? 0) < 1) {
      return l.planCalcNeedsFields;
    }
    if (_draft.mode.isDeadlineLike) {
      final end = _draft.endDate;
      if (end == null || end.isBefore(_dateOnly(_draft.startDate))) {
        return _draft.mode == PlanMode.beforeEvent && end == null
            ? l.planCalcNeedsEvent
            : l.planIssueInvalidRange;
      }
    }
    return l.planCalcNeedsFields;
  }

  /// Apply wizard draft from scratch (clears per-day exclusions), then open preview.
  void _calculate() {
    if (_calculating || _updatingProgress) return;
    setState(() {
      _inputs = _draft.copyWith(excludedDates: const {});
      _draft = _inputs;
      _computed = true;
      _baselineHonorsWeekdays = true;
      _calculating = true;
      _wizardStep = kPlanWizardStepCount;
      _progressCatchUpDismissed = false;
      _recalculatedFromOptions = true;
    });
    // Hold the spinner briefly so the loading state is perceptible rather than
    // a one-frame flash; generation itself is cheap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final result = generatePlan(_inputs);
        setState(() {
          _result = result;
          _previewBaseline = result;
          _calculating = false;
        });
        // Open the calendar on the plan's first month so a future-dated plan
        // isn't hidden behind an empty current month.
        final first = result.startDate;
        if (first != null) {
          _previewMonth.value = DateTime(first.year, first.month);
        }
      });
    });
  }

  /// Opens the shared progress form, completes milestones reached by the saved
  /// value, then recalculates the unread tail from tomorrow.
  Future<void> _updateProgressAndRecalculate() async {
    if (_updatingProgress || _calculating) return;
    final today = _dateOnly(DateTime.now());
    final newStart = DateTime(today.year, today.month, today.day + 1);
    // Free deadline plans may stretch endDate so the window stays valid.
    // beforeEvent must keep the event's day fixed — refuse catch-up when that
    // would leave no valid range (don't write progress first).
    var endDate = _draft.endDate;
    if (_draft.mode == PlanMode.deadline &&
        endDate != null &&
        endDate.isBefore(newStart)) {
      final priorSpan = endDate.difference(_dateOnly(_draft.startDate)).inDays;
      endDate = priorSpan > 0
          ? newStart.add(Duration(days: priorSpan))
          : newStart;
    }
    if (_draft.mode == PlanMode.beforeEvent &&
        endDate != null &&
        endDate.isBefore(newStart)) {
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: AppL10n.of(context).planIssueInvalidRange,
      );
      return;
    }

    final updated = await showRdModalSheet<Progress>(
      context: context,
      builder: (sheetContext) => SingleChildScrollView(
        child: ProgressEditorForm(
          book: widget.book,
          initial: _currentProgress,
          onProgressSaved: (progress) =>
              Navigator.of(sheetContext).pop(progress),
        ),
      ),
    );
    if (!mounted || updated == null) return;
    final updatedUnit = _inputs.unit == PlanUnit.pages
        ? (updated.currentPage ?? 0)
        : (updated.currentChapter ?? 0);
    setState(() {
      _updatingProgress = true;
      _currentProgress = updated;
    });
    if (!await _completeReachedProgressEvents(updatedUnit)) {
      if (!mounted) return;
      setState(() => _updatingProgress = false);
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: AppL10n.of(context).planUpdateFailed,
      );
      return;
    }
    // Preserve other draft fields (reminders, weekdays, bookends); only advance
    // the catch-up start position (and stretched deadline endDate when needed).
    _startUnitCtrl.text = updatedUnit.toString();
    _draft = _draft.copyWith(
      startUnit: updatedUnit,
      startDate: newStart,
      endDate: endDate,
    );
    _inputs = _draft.copyWith(excludedDates: const {});
    _progressCatchUpApplied = true;
    _calculateWithTodayProgress(updatedUnit);
  }

  Future<bool> _completeReachedProgressEvents(int progress) async {
    if (!_isReplan || progress <= 0) return true;
    final repo = ref.read(eventRepoProvider);
    var completedAny = false;
    var failed = false;
    final events = [
      ...widget.replan!.state.lockedEvents,
      ...widget.replan!.state.pending,
    ];
    for (final event in events) {
      if (event.status == EventStatus.completed ||
          _progressCompletedEventIds.contains(event.id)) {
        continue;
      }
      final target = _inputs.unit == PlanUnit.pages
          ? event.targetPage
          : event.targetChapter;
      if (target == null || target > progress) continue;
      final result = await repo.complete(event.id);
      if (result.isErr) {
        failed = true;
        break;
      }
      _progressCompletedEventIds.add(event.id);
      completedAny = true;
    }
    if (completedAny) {
      ref
        ..invalidate(upcomingEventsProvider)
        ..invalidateCalendarEvents()
        ..invalidate(eventsForBookProvider(widget.book.id))
        ..invalidate(bookEventsHistoryProvider(widget.book.id));
      final user = ref.read(sessionProvider).user;
      if (user != null) {
        if (!mounted) return false;
        try {
          await resyncLocalNotifications(ref, AppL10n.of(context), user);
        } catch (_) {
          // Completion is durable; cold-start resync repairs notifications.
        }
      }
    }
    return !failed;
  }

  void _calculateWithTodayProgress(int progress) {
    setState(() {
      _inputs = _draft.copyWith(excludedDates: const {});
      _draft = _inputs;
      _computed = true;
      _baselineHonorsWeekdays = true;
      _calculating = true;
      _updatingProgress = false;
      _wizardStep = kPlanWizardStepCount;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final tail = generatePlan(
          _inputs.copyWith(includeStart: _shouldGenerateStartBookend),
        );
        final today = _dateOnly(DateTime.now());
        final result = tail.isOk
            ? PlanResult(
                events: [
                  PlannedEvent(
                    date: today,
                    type: _inputs.unit == PlanUnit.pages
                        ? EventType.pageMilestone
                        : EventType.chapterMilestone,
                    targetPage: _inputs.unit == PlanUnit.pages
                        ? progress
                        : null,
                    targetChapter: _inputs.unit == PlanUnit.chapters
                        ? progress
                        : null,
                  ),
                  ...tail.events,
                ],
                startDate: today,
                endDate: tail.endDate,
                perDay: tail.perDay,
                totalUnits: tail.totalUnits,
                estimatedCount: tail.estimatedCount + 1,
                readingDays: tail.readingDays + 1,
              )
            : tail;
        setState(() {
          _result = result;
          _previewBaseline = result;
          _calculating = false;
        });
        _previewMonth.value = DateTime(today.year, today.month);
      });
    });
  }

  /// A wizard-field change. Until the first calculate, the draft IS the applied
  /// params (no dirty banner). After that, Events stays stale until recalculate.
  void _updateDraft(PlanInputs next) {
    setState(() {
      _draft = next;
      if (!_computed) {
        _inputs = next.copyWith(excludedDates: const {});
      }
    });
  }

  void _wizardBack() {
    if (_wizardStep <= 0) return;
    setState(() => _wizardStep -= 1);
  }

  void _wizardContinue() {
    if (_onPreview) return;
    if (_wizardStep < kPlanWizardStepCount - 1) {
      setState(() => _wizardStep += 1);
      return;
    }
    // Last form step always regenerates from the values shown in the wizard.
    // Replan options are authoritative even when their value happens to compare
    // equal to the opening snapshot; returning a stale preview here makes
    // structural start/finish markers and inferred options disagree with it.
    if (!_canCalculate) return;
    _calculate();
  }

  /// AppBar / system back: leave the plan or replan flow.
  void _exitPlan() {
    if (_phase == _Phase.creating) return;
    Navigator.of(context).maybePop();
  }

  void _handleSystemBack() => _exitPlan();

  bool get _allowsRoutePop {
    if (_phase == _Phase.creating) return false;
    return true;
  }

  void _backToForm({int? step}) {
    setState(() => _wizardStep = step ?? (kPlanWizardStepCount - 1));
  }

  /// Preview secondary action: return to the last wizard step (create and replan).
  void _leavePreview() {
    _backToForm();
  }

  /// A preview-tab change (removing/restoring a day): shift through the dates
  /// that already contain this plan's events. Empty calendar gaps are not slots;
  /// the displaced tail is appended after the baseline's final event.
  void _refreshPreview(PlanInputs next) {
    setState(() {
      _inputs = next;
      _result = shiftPendingEventsForward(
        _previewBaseline.events,
        // Live replan baseline keeps intentional gaps; inferred weekdays only
        // apply after a from-scratch generatePlan (see [_baselineHonorsWeekdays]).
        excludedWeekdays: _baselineHonorsWeekdays
            ? next.excludedWeekdays
            : const {},
        excludedDates: next.excludedDates,
        occupiedDates: {
          if (_isReplan)
            for (final event in widget.replan!.state.lockedEvents)
              _dateOnly(event.dateLocal),
        },
        perDay: _previewBaseline.perDay,
        totalUnits: _previewBaseline.totalUnits,
      );
    });
  }

  /// The opening Preview state for a replan: the plan's existing pending events,
  /// shown exactly as they are ("tal cual estaba", deletions respected) before
  /// the user touches anything.
  PlanResult _replanInitialResult(ReplanState s) {
    final rawEvents = [
      ...s.pending,
      ...s.completedCapstones,
    ].map(_plannedFromEvent).toList()..sort((a, b) => a.date.compareTo(b.date));
    final events = coalesceMilestonesPerCivilDay(rawEvents);
    if (events.isEmpty) return PlanResult.empty;
    return PlanResult(
      events: events,
      startDate: events.first.date,
      endDate: events.last.date,
      perDay: s.inputs.perDay,
      totalUnits: (s.inputs.total - s.inputs.startUnit).clamp(
        0,
        s.inputs.total,
      ),
      estimatedCount: events.length,
      readingDays: events.length,
    );
  }

  PlannedEvent _plannedFromEvent(ReadingEvent e) => PlannedEvent(
    date: _dateOnly(e.dateLocal),
    type: EventType.fromString(e.type) ?? EventType.chapterMilestone,
    targetChapter: e.targetChapter,
    targetPage: e.targetPage,
  );

  void _applyUnit(PlanUnit unit) {
    if (unit == _draft.unit) return;
    final isCh = unit == PlanUnit.chapters;
    final total = isCh ? widget.book.chapterCount : widget.book.pageCount;
    final startUnit =
        (isCh
            ? _currentProgress?.currentChapter
            : _currentProgress?.currentPage) ??
        0;
    _totalCtrl.text = total?.toString() ?? '';
    _startUnitCtrl.text = startUnit.toString();
    // Reseed the pace with the new unit's sensible default — 2 chapters/day is
    // not a meaningful page pace, so don't carry it across the unit switch.
    final perDay = planDefaultPerDay(unit);
    _perDayCtrl.text = perDay.toString();
    _updateDraft(
      _draft.copyWith(
        unit: unit,
        total: total,
        startUnit: startUnit,
        perDay: perDay,
      ),
    );
    final userId = ref.read(sessionProvider).user?.id;
    if (userId != null) {
      unawaited(
        ref
            .read(prefsStorageProvider)
            .setPlanUnit(userId, isCh ? 'chapters' : 'pages'),
      );
    }
  }

  void _applyMode(PlanMode mode) {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId != null) {
      unawaited(
        ref.read(prefsStorageProvider).setPlanMode(userId, mode.wireName),
      );
    }
    if (mode == _draft.mode) return;
    var next = _draft.copyWith(mode: mode);
    if (mode == PlanMode.deadline && next.endDate == null) {
      next = next.copyWith(
        endDate: next.startDate.add(const Duration(days: 30)),
        anchorEventId: null,
        anchorEventTitle: null,
      );
    }
    if (mode == PlanMode.beforeEvent) {
      next = next.copyWith(
        endDate: null,
        perDay: null,
        // Fresh pick required — clear any prior deadline/anchor.
        anchorEventId: null,
        anchorEventTitle: null,
      );
    }
    if (mode == PlanMode.pace && next.perDay == null) {
      final perDay = planDefaultPerDay(next.unit);
      _perDayCtrl.text = perDay.toString();
      next = next.copyWith(
        perDay: perDay,
        anchorEventId: null,
        anchorEventTitle: null,
      );
    }
    if (mode == PlanMode.pace || mode == PlanMode.deadline) {
      next = next.copyWith(anchorEventId: null, anchorEventTitle: null);
    }
    _updateDraft(next);
  }

  Future<void> _pickAnchorEvent() async {
    final selected = await Navigator.of(context).push<ReadingEvent>(
      rdPageRoute(context, builder: (_) => const PlanEventPickerScreen()),
    );
    if (!mounted || selected == null) return;
    final day = _dateOnly(selected.dateLocal);
    final today = _dateOnly(DateTime.now());
    final l = AppL10n.of(context);
    if (day.isBefore(today)) {
      showRdToast(context, message: l.planUntilHerePastHint);
      return;
    }
    final type = EventType.fromString(selected.type) ?? EventType.deadline;
    final title = selected.title.trim().isNotEmpty
        ? selected.title.trim()
        : type.label(l);
    _updateDraft(
      _draft.copyWith(
        mode: PlanMode.beforeEvent,
        endDate: day,
        anchorEventId: selected.id,
        anchorEventTitle: title,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return PopScope(
      canPop: _allowsRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isReplan ? l.planReplanTitle : l.planTitle),
          leading: _phase == _Phase.creating
              ? null
              : RdIconButton(
                  icon: LucideIcons.x,
                  tooltip: l.actionCancel,
                  onPressed: _exitPlan,
                ),
          actions: [
            if (_showPreviewChrome) ...[
              if (_inputs.excludedDates.isNotEmpty)
                RdIconButton(
                  icon: LucideIcons.rotateCcw,
                  tooltip: l.planReset,
                  onPressed: () => _refreshPreview(
                    _inputs.copyWith(excludedDates: const {}),
                  ),
                ),
              RdIconButton(
                icon: _calendarView ? LucideIcons.list : LucideIcons.calendar,
                tooltip: _calendarView ? l.planListView : l.planCalendarView,
                onPressed: _togglePreviewView,
              ),
            ],
            if (_isReplan && _phase == _Phase.form)
              _undoingReplan
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: RdProgress(),
                      ),
                    )
                  : RdIconButton(
                      tooltip: l.planUndo,
                      onPressed: _calculating || _updatingProgress
                          ? null
                          : _undoReplanPlan,
                      icon: LucideIcons.trash2,
                      color: context.colors.danger,
                    ),
          ],
        ),
        // Footer owns the bottom inset; avoid double SafeArea padding.
        body: SafeArea(bottom: false, child: _body(l)),
      ),
    );
  }

  Widget _body(AppL10n l) {
    switch (_phase) {
      case _Phase.creating:
        return _ProgressView(
          updating: _isReplan,
          processed: _processed,
          total: _total,
          rollingBack: _rollingBack,
          onCancel: () => setState(() => _cancelled = true),
        );
      case _Phase.done:
        return _DoneView(
          updated: _isReplan,
          count: _doneCount,
          start: _doneStart,
          end: _doneEnd,
          undoing: _undoingDone,
          onCalendar: () => unawaited(_leaveDoneView(toCalendar: true)),
          // Replan reuses the plan id — plan-level undo would wipe locked
          // anchors too. Only offer undo after a fresh create.
          onUndo: _isReplan ? null : _undoCreatedPlan,
          onDone: () => unawaited(_leaveDoneView(toCalendar: false)),
        );
      case _Phase.form:
        return Column(
          children: [
            Expanded(
              child: _onPreview ? _previewTab(l) : _formTab(),
            ),
            const Divider(height: 1),
            _footer(l),
          ],
        );
    }
  }

  /// Jump back to the goal step so the user can rebuild the plan from scratch
  /// without leaving replan (seeded draft stays until they recalculate).
  void _restartReplanWizard() {
    unawaited(RdHaptics.selection());
    setState(() => _wizardStep = 0);
  }

  // ── Wizard form steps ──────────────────────────────────────────────────────

  Widget _formTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: PlanWizardForm(
        step: _wizardStep,
        draft: _draft,
        totalCtrl: _totalCtrl,
        startUnitCtrl: _startUnitCtrl,
        perDayCtrl: _perDayCtrl,
        onDraftChanged: _updateDraft,
        onUnitChanged: _applyUnit,
        onModeChanged: _applyMode,
        onPickAnchorEvent: _pickAnchorEvent,
      ),
    );
  }

  // ── Events preview ─────────────────────────────────────────────────────────

  Widget _previewTab(AppL10n l) {
    if (!_computed) {
      return EmptyState(
        icon: LucideIcons.calendarDays,
        message: l.planPreviewHint,
        action: RdButton.secondary(
          label: l.planWizardBack,
          icon: LucideIcons.slidersHorizontal,
          onPressed: _backToForm,
        ),
      );
    }
    if (_calculating) return _loading();
    final r = _result;
    if (r.overHardCap) {
      return EmptyState(
        icon: LucideIcons.calendarX,
        message: l.planTooMany(r.estimatedCount),
        action: RdButton.secondary(
          label: l.planWizardBack,
          icon: LucideIcons.slidersHorizontal,
          onPressed: _backToForm,
        ),
      );
    }
    if (!r.isOk) {
      // The user's day exclusions can break an otherwise-valid plan (e.g.
      // removing every reading day inside a deadline window). Don't strand them
      // on a bare hint with no controls — explain it and offer a one-tap reset.
      if (_inputs.excludedDates.isNotEmpty) {
        return _exclusionBlockedView(l, _issueHint(l, r.issue));
      }
      return EmptyState(
        icon: LucideIcons.info,
        message: _issueHint(l, r.issue),
        action: RdButton.secondary(
          label: l.planWizardBack,
          icon: LucideIcons.slidersHorizontal,
          onPressed: _backToForm,
        ),
      );
    }
    // Plan-level warnings (large plan, exclusion-tightened pace) live in the
    // pinned footer advice, so the preview itself stays uncluttered.
    final progressCatchUp = _progressUpdateValue;
    return Column(
      children: [
        _previewTopPanel(l, progressCatchUp: progressCatchUp),
        if (_calendarView) _calendarTapHintPanel(l),
        Expanded(
          child: _calendarView ? _calendarPreview(l, r) : _listPreview(l, r),
        ),
      ],
    );
  }

  Widget _previewChromeCard(
    Widget child, {
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 10, 16, 0),
  }) => Padding(
    padding: margin,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ),
  );

  /// Catch-up banner above the preview when the user is ahead of milestones.
  Widget _previewTopPanel(AppL10n l, {int? progressCatchUp}) {
    if (progressCatchUp == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _progressCatchUpContent(l, progressCatchUp),
    );
  }

  Widget _calendarTapHintPanel(AppL10n l) => _previewChromeCard(
    _calendarTapHintRow(l),
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
  );

  Widget _calendarTapHintRow(AppL10n l) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(
          LucideIcons.mousePointerClick,
          size: 16,
          color: context.colors.accent,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          l.planCalendarTapHint,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: context.colors.fg2,
          ),
        ),
      ),
    ],
  );

  Widget _progressCatchUpContent(AppL10n l, int suggestedPage) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.warningSoftBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.trendingUp,
              size: 18,
              color: context.colors.warningSoftFg,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.planProgressAheadTitle,
                style: TextStyle(
                  color: context.colors.warningSoftFg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            RdIconButton.compact(
              icon: LucideIcons.x,
              size: 18,
              color: context.colors.fg3,
              tooltip: l.actionClose,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => setState(() => _progressCatchUpDismissed = true),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l.planProgressAheadMessage(suggestedPage),
          style: TextStyle(fontSize: 12.5, color: context.colors.fg2),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: RdButton.secondary(
            onPressed: (_updatingProgress || _calculating)
                ? null
                : _updateProgressAndRecalculate,
            icon: LucideIcons.refreshCw,
            label: l.planProgressAheadAction,
            compact: true,
          ),
        ),
      ],
    ),
  );

  Widget _listPreview(AppL10n l, PlanResult r) {
    final replacedTodayId = _todayProgressReplacement(r.events)?.original.id;
    final replacedLockedBookendIds = _lockedBookendIdsSupersededByOptions();
    // Active events plus the user's removed days (kept visible, disabled), sorted
    // by date and split into months.
    final items = <_PreviewItem>[
      for (final e in r.events) _PreviewItem(e.date, e),
      for (final d in _inputs.excludedDates) _PreviewItem(d, null),
      // Replan: past/completed events stay as locked, dimmed anchors among the
      // mutable tail so the schedule reads as one continuous plan.
      if (_isReplan)
        for (final c in widget.replan!.state.lockedEvents)
          if (c.id != replacedTodayId &&
              !replacedLockedBookendIds.contains(c.id))
            _PreviewItem(
              _dateOnly(c.dateLocal),
              _plannedFromEvent(c),
              locked: true,
            ),
    ]..sort(_comparePreviewItems);

    final rows = <_Row>[];
    int? lastMonthKey;
    for (final it in items) {
      final key = it.date.year * 100 + it.date.month;
      if (key != lastMonthKey) {
        rows.add(_Row.header(it.date));
        lastMonthKey = key;
      }
      rows.add(_Row.item(it));
    }
    final removedType = _inputs.unit == PlanUnit.chapters
        ? EventType.chapterMilestone
        : EventType.pageMilestone;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row.header != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              _fmtMonth(row.header!),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: context.colors.fg2),
            ),
          );
        }
        final item = row.item!;
        final e = item.event;
        final removed = e == null;
        final locked = item.locked;
        // Milestones (and removed days) carry a checkbox; the structural
        // start/finish/deadline markers — and completed (locked) anchors —
        // don't (a lock or blank gutter keeps alignment).
        final canToggle = !locked && (removed || !e.isBookend);
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: locked
                    ? Icon(
                        LucideIcons.lock,
                        size: 16,
                        color: context.colors.fgFaint,
                      )
                    : canToggle
                    ? RdCheckbox(
                        value: !removed,
                        onChanged: (v) => (v ?? false)
                            ? _includeDate(item.date)
                            : _excludeDate(item.date),
                      )
                    : null,
              ),
              Expanded(
                child: Opacity(
                  opacity: removed ? 0.4 : 1,
                  child: EventCardCompact(
                    enabled: !locked && !removed,
                    title: removed ? l.planRemovedDay : _eventTitle(e, l),
                    type: removed ? removedType : e.type,
                    subtitle: formatDayMonth(context, item.date),
                    bookTitle: widget.book.title,
                    bookAuthor: widget.book.authors.firstOrNull,
                    bookCoverUrl: widget.book.coverUrl,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _calendarPreview(AppL10n l, PlanResult r) {
    final replacedTodayId = _todayProgressReplacement(r.events)?.original.id;
    final replacedLockedBookendIds = _lockedBookendIdsSupersededByOptions();
    final events = <ReadingEvent>[
      for (var i = 0; i < r.events.length; i++)
        _toPreviewEvent(r.events[i], l, i),
      for (final d in _inputs.excludedDates) _removedPreviewEvent(d, l),
      // Replan: show immutable anchors on their days (visible, not removable).
      if (_isReplan)
        ...widget.replan!.state.lockedEvents.where(
          (event) =>
              event.id != replacedTodayId &&
              !replacedLockedBookendIds.contains(event.id),
        ),
    ]..sort(_comparePreviewReadingEvents);
    final ctx = EventRenderContext(personalBooks: [widget.book]);
    void onOpenDay(DateTime day, List<ReadingEvent> dayEvents) {
      final d = _dateOnly(day);
      // An immutable event day is locked — tapping it does nothing.
      if (_isReplan &&
          widget.replan!.state.lockedEvents.any(
            (c) =>
                c.id != replacedTodayId &&
                !replacedLockedBookendIds.contains(c.id) &&
                _dateOnly(c.dateLocal) == d,
          )) {
        return;
      }
      // Tapping a removed day restores it; tapping a removable reading day
      // takes it out — bookend-only days stay put.
      if (_inputs.excludedDates.contains(d)) {
        _includeDate(day);
        return;
      }
      final removable = dayEvents.any((e) {
        final t = EventType.fromString(e.type);
        return t == EventType.chapterMilestone || t == EventType.pageMilestone;
      });
      if (removable) _excludeDate(day);
    }

    // Only the month label + grid depend on the visible month, so a page change
    // rebuilds just this subtree (not the form/footer/advice above).
    return ValueListenableBuilder<DateTime>(
      valueListenable: _previewMonth,
      builder: (context, month, _) {
        final dimmed = <int>{
          for (final d in _inputs.excludedDates)
            if (d.year == month.year && d.month == month.month) d.day,
        };
        final disabled = <int>{
          for (final event
              in widget.replan?.state.lockedEvents ?? const <ReadingEvent>[])
            if (event.id != replacedTodayId &&
                !replacedLockedBookendIds.contains(event.id) &&
                event.dateLocal.year == month.year &&
                event.dateLocal.month == month.month)
              event.dateLocal.day,
        };
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RdIconButton(
                  icon: LucideIcons.chevronLeft,
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).previousMonthTooltip,
                  onPressed: () => _previewMonth.value = DateTime(
                    month.year,
                    month.month - 1,
                  ),
                ),
                Expanded(
                  child: Text(
                    _capitalize(_fmtMonth(month)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                RdIconButton(
                  icon: LucideIcons.chevronRight,
                  tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
                  onPressed: () => _previewMonth.value = DateTime(
                    month.year,
                    month.month + 1,
                  ),
                ),
              ],
            ),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity;
                  if (v == null || v == 0) return;
                  _previewMonth.value = DateTime(
                    month.year,
                    month.month + (v < 0 ? 1 : -1),
                  );
                },
                child: SingleChildScrollView(
                  child: MonthGrid(
                    month: month,
                    events: events,
                    eventContext: ctx,
                    dimmedDays: dimmed,
                    disabledDays: disabled,
                    onOpenDay: onOpenDay,
                    showMilestoneTargets: true,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _excludeDate(DateTime date) {
    unawaited(RdHaptics.selection());
    final d = _dateOnly(date);
    _refreshPreview(
      _inputs.copyWith(excludedDates: {..._inputs.excludedDates, d}),
    );
  }

  void _includeDate(DateTime date) {
    unawaited(RdHaptics.selection());
    final d = _dateOnly(date);
    _refreshPreview(
      _inputs.copyWith(excludedDates: {..._inputs.excludedDates}..remove(d)),
    );
  }

  /// A specific, actionable message for each blocking [PlanIssue] (instead of one
  /// generic "adjust the settings" hint), so the user knows exactly what to fix.
  String _issueHint(AppL10n l, PlanIssue? issue) {
    switch (issue) {
      case PlanIssue.needsTotal:
        return _inputs.unit == PlanUnit.chapters
            ? l.planNeedChapters
            : l.planNeedPages;
      case PlanIssue.nothingToRead:
        return l.planIssueNothingToRead;
      case PlanIssue.invalidPace:
        return l.planIssueInvalidPace;
      case PlanIssue.invalidRange:
        return l.planIssueInvalidRange;
      case PlanIssue.noReadingDays:
        return l.planIssueNoReadingDays;
      case PlanIssue.overHardCap:
      case null:
        return l.planAdjustHint;
    }
  }

  Widget _loading() => Center(
    child: RdProgress(color: context.colors.accent),
  );

  /// Shown when day exclusions leave no workable plan. Replaces the dead-end
  /// hint with the reason plus a prominent reset.
  Widget _exclusionBlockedView(AppL10n l, String reason) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.calendarX,
            size: 40,
            color: context.colors.warning,
          ),
          const SizedBox(height: 16),
          Text(
            l.planExclusionsBlocked,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.fg3),
          ),
          const SizedBox(height: 20),
          RdButton.secondary(
            icon: LucideIcons.rotateCcw,
            label: l.planReset,
            onPressed: () =>
                _refreshPreview(_inputs.copyWith(excludedDates: const {})),
          ),
        ],
      ),
    ),
  );

  // ── Footer (advice + CTAs) + flow ──────────────────────────────────────────

  /// Always two equal-width buttons: secondary (Cancel/Back) + primary
  /// (Continue / Create / Update / Recalculate), each with an icon.
  Widget _footer(AppL10n l) {
    final dirty = _computed && _draftDirty;
    final busy = _calculating || _updatingProgress;
    final onLastStep = !_onPreview && _wizardStep >= kPlanWizardStepCount - 1;
    final ready =
        _computed && _result.isOk && !_result.overHardCap && !dirty && !busy;
    final showAdvice = _onPreview ? (_computed && !dirty) : _wizardStep >= 1;
    final adviceInputs = _onPreview ? _inputs : _draft;
    final showReplanRestart = _isReplan && _wizardStep > 0 && _onPreview;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showAdvice) ...[
              _PlanAdvice(
                inputs: adviceInputs,
                compact: dirty && onLastStep,
                applied: _onPreview && !dirty ? _result : null,
              ),
              const SizedBox(height: 8),
            ] else if (!showReplanRestart)
              const SizedBox(height: 4),
            if (showReplanRestart) ...[
              RdButton.secondary(
                icon: LucideIcons.listRestart,
                label: l.planReplanFromStart,
                onPressed: _restartReplanWizard,
                expand: true,
              ),
              const SizedBox(height: 8),
            ],
            if (!_onPreview)
              _formFooter(l)
            else
              _previewFooter(l, ready: ready),
          ],
        ),
      ),
    );
  }

  /// Shared equal-width button row used on every wizard/preview footer.
  Widget _pairButtons({
    required String secondaryLabel,
    required IconData secondaryIcon,
    required VoidCallback? onSecondary,
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback? onPrimary,
    bool primaryLoading = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null) ...[
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.colors.fg3),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: RdButton.secondary(
                icon: secondaryIcon,
                label: secondaryLabel,
                onPressed: onSecondary,
                expand: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RdButton.primary(
                icon: primaryIcon,
                label: primaryLabel,
                onPressed: onPrimary,
                loading: primaryLoading,
                expand: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _formFooter(AppL10n l) {
    final busy = _calculating || _updatingProgress;
    final onLastStep = _wizardStep >= kPlanWizardStepCount - 1;
    final atStart = _wizardStep <= 0;

    final VoidCallback? onPrimary;
    if (!onLastStep) {
      onPrimary = _wizardContinue;
    } else if (!_canCalculate || busy) {
      onPrimary = null;
    } else {
      onPrimary = _wizardContinue;
    }

    return _pairButtons(
      secondaryLabel: atStart ? l.actionCancel : l.planWizardBack,
      secondaryIcon: atStart ? LucideIcons.x : LucideIcons.arrowLeft,
      onSecondary: atStart
          ? () => Navigator.of(context).maybePop()
          : _wizardBack,
      primaryLabel: l.planWizardContinue,
      primaryIcon: LucideIcons.arrowRight,
      onPrimary: onPrimary,
      primaryLoading: _calculating,
      hint: onLastStep && !_canCalculate ? _calcDisabledHint(l) : null,
    );
  }

  Widget _previewFooter(AppL10n l, {required bool ready}) {
    final busy = _calculating || _updatingProgress;
    final primaryLabel = _isReplan ? l.planUpdate : l.planCreate;

    return _pairButtons(
      secondaryLabel: l.planWizardBack,
      secondaryIcon: LucideIcons.arrowLeft,
      onSecondary: busy ? null : _leavePreview,
      primaryLabel: primaryLabel,
      primaryIcon: LucideIcons.calendarCheck,
      onPrimary: ready ? () => _confirmAndCreate(l) : null,
      primaryLoading: busy && _updatingProgress,
    );
  }

  Future<void> _confirmAndCreate(AppL10n l) async {
    // Defense in depth: never persist a stale applied plan while the draft differs.
    if (_draftDirty ||
        !_computed ||
        !_result.isOk ||
        _result.overHardCap ||
        _calculating ||
        _updatingProgress) {
      return;
    }
    final markReading = ValueNotifier<bool>(
      !_inputs.startDate.isAfter(_dateOnly(DateTime.now())) &&
          widget.book.status == 'pending',
    );
    final overlap = _overlapCount();
    final r = _result;
    final bool confirmed;
    final bool mark;
    try {
      confirmed = await showConfirmDialog(
        context: context,
        icon: _isReplan ? LucideIcons.refreshCw : LucideIcons.calendarCheck,
        title: _isReplan ? l.planUpdateConfirmTitle : l.planConfirmTitle,
        confirmLabel: _isReplan ? l.planUpdate : l.planCreate,
        confirmIcon: _isReplan
            ? LucideIcons.refreshCw
            : LucideIcons.calendarCheck,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isReplan
                  ? l.planUpdateConfirmMessage(
                      r.count,
                      _fmt(r.startDate!),
                      _fmt(r.endDate!),
                    )
                  : l.planConfirmMessage(
                      r.count,
                      _fmt(r.startDate!),
                      _fmt(r.endDate!),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              l.planConfirmReassurance,
              style: TextStyle(color: context.colors.fg3),
            ),
            if (overlap > 0) ...[
              const SizedBox(height: 8),
              Text(
                l.planConfirmOverlap(overlap),
                style: TextStyle(color: context.colors.warning),
              ),
            ],
            const SizedBox(height: 4),
            if (widget.book.status == 'pending')
              ValueListenableBuilder<bool>(
                valueListenable: markReading,
                builder: (context, value, _) => RdCheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  value: value,
                  onChanged: (v) => markReading.value = v ?? false,
                  title: Text(l.planConfirmMarkReading),
                ),
              ),
          ],
        ),
      );
      mark = markReading.value;
    } finally {
      markReading.dispose();
    }
    if (!confirmed || !mounted) return;
    await _runCreate(mark);
  }

  int _overlapCount() {
    final existing = ref.read(eventsForBookProvider(widget.book.id)).value;
    if (existing == null || existing.isEmpty) return 0;
    final start = _result.startDate;
    final end = _result.endDate;
    if (start == null || end == null) return 0;
    // In replan mode the plan's own events are about to be replaced, so they
    // aren't a real "overlap" — don't warn about them.
    final replanId = widget.replan?.planId;
    return existing
        .where(
          (e) =>
              (replanId == null || e.planId != replanId) &&
              !_dateOnly(e.dateLocal).isBefore(start) &&
              !_dateOnly(e.dateLocal).isAfter(end),
        )
        .length;
  }

  Future<void> _runCreate(bool markReading) async {
    final l = AppL10n.of(context);
    // Persistence is the final invariant boundary. Even if a future generator
    // or an old plan supplies several targets for one day, save only the
    // furthest milestone for that book/civil date.
    final allEvents = coalesceMilestonesPerCivilDay(_result.events);
    final completedMoves = _completedCapstoneMoves(allEvents);
    final todayReplacement = _todayProgressReplacement(allEvents);
    final movedEvents = {
      for (final move in completedMoves) move.shifted,
      if (todayReplacement != null) todayReplacement.replacement,
    };
    final eventsToReconcile =
        allEvents.where((event) => !movedEvents.contains(event)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final plannedMilestoneDays = eventsToReconcile
        .map(_plannedMilestoneDayKey)
        .whereType<String>()
        .toSet();
    final todayReplacementDay = todayReplacement == null
        ? null
        : _plannedMilestoneDayKey(todayReplacement.replacement);
    if (todayReplacementDay != null) {
      plannedMilestoneDays.add(todayReplacementDay);
    }
    final externalSameDayMilestones = _isReplan
        ? widget.replan!.allBookEvents.where(
            (event) =>
                event.planId != widget.replan!.planId &&
                event.id != todayReplacement?.original.id &&
                plannedMilestoneDays.contains(_readingMilestoneDayKey(event)),
          )
        : const Iterable<ReadingEvent>.empty();
    // Completed milestones are reusable rows, not immutable obstacles. If the
    // authoritative preview still needs that milestone (possibly on another
    // day or with another target), update the existing row and reopen it rather
    // than creating a parallel active event. Unused completed history remains
    // untouched unless it directly conflicts with a preview milestone day.
    final reusableCompletedMilestones = _isReplan
        ? widget.replan!.allBookEvents.where(
            (event) =>
                event.id != todayReplacement?.original.id &&
                event.status == EventStatus.completed &&
                _readingMilestoneDayKey(event) != null,
          )
        : const Iterable<ReadingEvent>.empty();
    final lockedBookendsToReconcile = _isReplan
        ? widget.replan!.state.lockedEvents.where(
            (event) =>
                _lockedBookendIdsSupersededByOptions().contains(event.id),
          )
        : const Iterable<ReadingEvent>.empty();
    final existingToReconcile = _isReplan
        ? (<ReadingEvent>[
                ...widget.replan!.state.pending.where(
                  (event) => event.id != todayReplacement?.original.id,
                ),
                ...lockedBookendsToReconcile,
                ...externalSameDayMilestones,
                ...reusableCompletedMilestones,
              ]
              .fold(<String, ReadingEvent>{}, (byId, event) {
                byId[event.id] = event;
                return byId;
              })
              .values
              .toList()
            ..sort((a, b) => a.dateLocal.compareTo(b.dateLocal)))
        : <ReadingEvent>[];
    final replacements =
        <({ReadingEvent original, PlannedEvent replacement})>[];
    final unmatchedExisting = [...existingToReconcile];
    final events = <PlannedEvent>[];
    for (final planned in eventsToReconcile) {
      // Catch-up (and any replan that is not regenerating bookends from
      // Change options) must keep the historical start row. generatePlan
      // would otherwise open the unread tail with a second start.
      if (planned.type == EventType.start && _preserveLockedStartBookend) {
        continue;
      }
      if (unmatchedExisting.isEmpty) {
        events.add(planned);
        continue;
      }
      final sameDayIndex = unmatchedExisting.indexWhere((existing) {
        final type = EventType.fromString(existing.type);
        final typeMatches =
            type == planned.type ||
            (type != null && _capstoneTypesEquivalent(type, planned.type)) ||
            (type != null && _milestoneTypesEquivalent(type, planned.type));
        return typeMatches &&
            _dateOnly(existing.dateLocal) == _dateOnly(planned.date);
      });
      final sameTypeIndex = unmatchedExisting.indexWhere((existing) {
        final type = EventType.fromString(existing.type);
        final sameType =
            type == planned.type ||
            (type != null && _capstoneTypesEquivalent(type, planned.type));
        return sameType &&
            existing.targetPage == planned.targetPage &&
            existing.targetChapter == planned.targetChapter;
      });
      final compatibleTypeIndex = unmatchedExisting.indexWhere((existing) {
        final type = EventType.fromString(existing.type);
        return type == planned.type ||
            (type != null && _capstoneTypesEquivalent(type, planned.type));
      });
      final index = sameDayIndex >= 0
          ? sameDayIndex
          : (sameTypeIndex >= 0 ? sameTypeIndex : compatibleTypeIndex);
      // No semantic match means this preview row is genuinely new. Never
      // consume an arbitrary existing row: doing so can leave the displaced
      // milestone unmatched and delete it as "surplus" after an exclusion.
      if (index < 0) {
        events.add(planned);
        continue;
      }
      replacements.add(
        (original: unmatchedExisting.removeAt(index), replacement: planned),
      );
    }
    final pendingIds = _isReplan
        ? widget.replan!.state.pending.map((event) => event.id).toSet()
        : const <String>{};
    final conflictingExternalIds = externalSameDayMilestones
        .map((event) => event.id)
        .toSet();
    final supersededBookendIds = lockedBookendsToReconcile
        .map((event) => event.id)
        .toSet();
    final oldEventsToDelete = unmatchedExisting
        .where(
          (event) =>
              pendingIds.contains(event.id) ||
              conflictingExternalIds.contains(event.id) ||
              supersededBookendIds.contains(event.id),
        )
        .toList(growable: false);
    final mutationSourceIds = <String>[
      for (final move in replacements) move.original.id,
      for (final move in completedMoves) move.original.id,
      if (todayReplacement != null) todayReplacement.original.id,
    ];
    if (mutationSourceIds.toSet().length != mutationSourceIds.length) {
      // One persisted row may back exactly one preview row. Failing before the
      // first request is safer than attempting compensation after two branches
      // mutate the same source event in different ways.
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: l.planUpdateFailed,
      );
      return;
    }
    final doneStart = _result.startDate;
    final doneEnd = _result.endDate;
    setState(() {
      _phase = _Phase.creating;
      _processed = 0;
      _total =
          events.length +
          replacements.length +
          completedMoves.length +
          (todayReplacement == null ? 0 : 1);
      _cancelled = false;
      _rollingBack = false;
    });

    final repo = ref.read(eventRepoProvider);
    // Group every event under one plan-run id so the run can be recorded for
    // history and undone later (spec §6.9). In replan mode we REUSE the existing
    // plan's id so the completed anchors and the new tail stay one coherent plan;
    // otherwise a fresh id tags this run.
    final planId = widget.replan?.planId ?? const Uuid().v4();
    // Plan reminders use the offset configured in the user's notification
    // settings (§16.4), not a fixed at-time value. Fall back to the spec
    // default if the prefs can't be loaded (offline/error).
    var reminderMinutes = 1440;
    if (_inputs.remindersOn) {
      try {
        final prefs = await ref.read(notificationPrefsProvider.future);
        reminderMinutes = prefs.defaultReminderMinutesBefore;
      } catch (_) {
        // Keep the default offset.
      }
    }
    final bodies = [
      for (final e in events) _eventBody(e, l, planId, reminderMinutes),
    ];
    const chunkSize = 50;
    final chunks = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < bodies.length; i += chunkSize) {
      chunks.add(bodies.sublist(i, math.min(i + chunkSize, bodies.length)));
    }

    final createdIds = <String>[];
    final mutatedOriginals = <ReadingEvent>[];
    final reopenedOriginalIds = <String>{};
    var failed = false;
    var nextChunk = 0;
    // A replan intentionally reuses the planId, but it must never reuse the
    // original creation's idempotency keys (`planId:chunk`). Doing so replays
    // the original response instead of inserting the replacements; deleting
    // the old rows afterward then empties the calendar history.
    // Keep one fresh operation id for this save so only its in-process retries
    // share keys.
    final replanOperationId = _isReplan ? const Uuid().v4() : null;

    Future<void> worker() async {
      while (!_cancelled && !failed) {
        final idx = nextChunk++;
        if (idx >= chunks.length) return;
        final chunk = chunks[idx];
        // Stable per-chunk key, reused across this chunk's retries so a blind
        // retry after a landed-but-lost response replays the original per-row
        // result instead of re-inserting the events (backend Idempotency mw).
        final idemKey = replanOperationId == null
            ? '$planId:$idx'
            : '$planId:replan:$replanOperationId:$idx';
        var res = await repo.createBatch(chunk, idempotencyKey: idemKey);
        var attempt = 0;
        while (res.isErr && attempt < 2 && !_cancelled) {
          attempt++;
          await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
          if (_cancelled) break;
          res = await repo.createBatch(chunk, idempotencyKey: idemKey);
        }
        if (res.isErr) {
          failed = true;
          return;
        }
        for (final row in res.value!) {
          if (row.isCreated && row.id.isNotEmpty) {
            createdIds.add(row.id);
          } else {
            failed = true;
          }
        }
        if (mounted) setState(() => _processed += chunk.length);
      }
    }

    final workers = math.min(3, chunks.length);
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    if (!mounted) return;

    // Replan mutates existing rows in place. This keeps event identity stable
    // and prevents the create-then-delete window that could leave duplicate
    // events on the same day when deletion or a retry failed.
    if (!_cancelled && !failed) {
      for (final move in replacements) {
        if (_cancelled) break;
        final res = await repo.update(
          move.original.id,
          _replanEventUpdateBody(
            move.original,
            move.replacement,
            reminderMinutes,
          ),
        );
        if (res.isErr) {
          failed = true;
          break;
        }
        mutatedOriginals.add(move.original);
        // Updating progress may have completed this pending milestone moments
        // before the preview was rebuilt. If the authoritative preview reuses
        // that row for a future target, restore its active status as well as
        // its date/target; otherwise Calendar keeps showing the old completed
        // milestone even though it no longer exists in the preview.
        if (_progressCompletedEventIds.contains(move.original.id) ||
            (move.original.status == EventStatus.completed &&
                (move.replacement.type == EventType.pageMilestone ||
                    move.replacement.type == EventType.chapterMilestone ||
                    (move.replacement.type == EventType.start &&
                        _dateOnly(move.replacement.date).isAfter(
                          _dateOnly(DateTime.now()),
                        ))))) {
          final reopen = await repo.uncomplete(move.original.id);
          if (reopen.isErr) {
            failed = true;
            break;
          }
          reopenedOriginalIds.add(move.original.id);
        }
        if (mounted) setState(() => _processed++);
      }
    }

    // Completed finish/deadline events are historical records, so move the
    // existing row instead of replacing it with a new active event.
    if (!_cancelled && !failed) {
      for (final move in completedMoves) {
        if (_cancelled) break;
        final res = await repo.update(
          move.original.id,
          _completedCapstoneUpdateBody(move.original, move.shifted),
        );
        if (res.isErr) {
          failed = true;
          break;
        }
        mutatedOriginals.add(move.original);
        if (mounted) setState(() => _processed++);
      }
    }

    // Catch-up replans reuse today's existing milestone instead of creating a
    // duplicate. A completed milestone is reopened so the reader can complete
    // the updated target normally after saving the plan.
    if (!_cancelled && !failed && todayReplacement != null) {
      final move = todayReplacement;
      final update = await repo.update(
        move.original.id,
        _todayProgressUpdateBody(move.original, move.replacement),
      );
      if (update.isErr) {
        failed = true;
      } else {
        mutatedOriginals.add(move.original);
        if (move.original.status == 'completed' ||
            _progressCompletedEventIds.contains(move.original.id)) {
          final reopen = await repo.uncomplete(move.original.id);
          if (reopen.isErr) {
            failed = true;
          } else {
            reopenedOriginalIds.add(move.original.id);
          }
        }
      }
      if (mounted) setState(() => _processed++);
    }

    if (_cancelled || failed) {
      // Updates happen before surplus deletion. Restore every row already
      // changed when a later request fails or the user cancels, so returning to
      // Preview never hides a partially-applied calendar behind an error.
      final restored = await _restoreReplanEvents(
        repo,
        mutatedOriginals,
        reopenedOriginalIds,
      );
      if (createdIds.isNotEmpty) {
        setState(() => _rollingBack = true);
        if (!await _rollback(repo, createdIds)) failed = true;
      }
      if (!mounted) return;
      final showError = (failed && !_cancelled) || !restored;
      setState(() {
        _phase = _Phase.form;
        _rollingBack = false;
      });
      if (showError) {
        showRdToast(
          context,
          tone: RdToastTone.error,
          message: _isReplan ? l.planUpdateFailed : l.planFailed,
        );
      }
      return;
    }

    // Success — the events are created. Refresh the views first (synchronous,
    // can't throw) so the calendar/book detail reflect the new events even if a
    // best-effort step below fails.
    // Delete only surplus rows after every replacement/create has succeeded.
    // Reached-progress events are completed historical records, never surplus.
    if (_isReplan) {
      final oldIds = oldEventsToDelete.map((e) => e.id).toList(growable: false);
      if (oldIds.isNotEmpty && !await _rollback(repo, oldIds)) {
        // Batch deletion is atomic server-side. If it fails, none of the
        // surplus rows were removed, so restore the rows updated earlier and
        // remove any newly-created rows. Preview remains the only truth: we
        // either apply all of it or return the calendar to its opening state.
        final restored = await _restoreReplanEvents(
          repo,
          mutatedOriginals,
          reopenedOriginalIds,
        );
        final creationsRemoved =
            createdIds.isEmpty || await _rollback(repo, createdIds);
        if (!restored || !creationsRemoved) {
          debugPrint(
            'Replan compensation was incomplete after surplus deletion failed.',
          );
        }
        if (!mounted) return;
        setState(() => _phase = _Phase.form);
        showRdToast(
          context,
          tone: RdToastTone.error,
          message: l.planUpdateFailed,
        );
        return;
      }
    }

    ref
      ..invalidate(upcomingEventsProvider)
      ..invalidateCalendarEvents()
      ..invalidate(booksProvider)
      ..invalidate(bookProvider(widget.book.id))
      ..invalidate(eventsForBookProvider(widget.book.id))
      ..invalidate(bookEventsHistoryProvider(widget.book.id))
      ..invalidate(bookPlansProvider(widget.book.id));
    // Recording the plan run, the status flip, totals persistence and
    // notification rescheduling are all best-effort: a failure here (e.g. the
    // resync refetch erroring, or the plan-run record failing) must never trap
    // the user on the progress view — the events themselves already exist.
    try {
      // The plan-run record is what makes the plan undoable as a group in history.
      // If it fails to persist while the events already exist, the plan becomes an
      // "orphan" the user can't undo in one tap — so retry a few times on error
      // (the backend now also reconstructs orphans defensively, but landing the
      // real row keeps the richer mode/pace metadata). Idempotent on the server:
      // the row carries the client-supplied planId.
      final planRepo = ref.read(planRepoProvider);
      // In replan mode the run spans every retained row plus the new tail, so
      // the recorded count + start reflect the whole plan (the backend upserts
      // the run on the reused planId).
      final retained =
          widget.replan?.state.retainedEvents ?? const <ReadingEvent>[];
      final replacedOriginalIds = replacements
          .map((move) => move.original.id)
          .toSet();
      final runEventCount =
          createdIds.length +
          replacements.length +
          retained
              .where(
                (event) =>
                    event.id != todayReplacement?.original.id &&
                    !replacedOriginalIds.contains(event.id),
              )
              .length +
          (todayReplacement == null ? 0 : 1);
      var runRes = await planRepo.createPlanRun(
        id: planId,
        bookId: widget.book.id,
        eventCount: runEventCount,
        mode: _inputs.mode.wireName,
        unit: _inputs.unit.name,
        perDay: _inputs.perDay,
        // The computed span (doneStart/doneEnd) — not _inputs, whose endDate
        // is null in pace mode and whose startDate may precede the first
        // actual reading day — so history shows a real date range in both modes.
        startDate: _inputs.startDate,
        endDate: doneEnd,
        total: _inputs.total,
        startUnit: _inputs.startUnit,
        excludedWeekdays: _inputs.excludedWeekdays,
        remindersOn: _inputs.remindersOn,
        includeStart: _inputs.includeStart,
        includeFinish: _inputs.includeFinish,
        anchorEventId: _inputs.anchorEventId,
        anchorEventTitle: _inputs.anchorEventTitle,
      );
      var runAttempt = 0;
      while (runRes.isErr && runAttempt < 2) {
        runAttempt++;
        await Future<void>.delayed(Duration(milliseconds: 400 * runAttempt));
        runRes = await planRepo.createPlanRun(
          id: planId,
          bookId: widget.book.id,
          eventCount: runEventCount,
          mode: _inputs.mode.wireName,
          unit: _inputs.unit.name,
          perDay: _inputs.perDay,
          startDate: _inputs.startDate,
          endDate: doneEnd,
          total: _inputs.total,
          startUnit: _inputs.startUnit,
          excludedWeekdays: _inputs.excludedWeekdays,
          remindersOn: _inputs.remindersOn,
          includeStart: _inputs.includeStart,
          includeFinish: _inputs.includeFinish,
          anchorEventId: _inputs.anchorEventId,
          anchorEventTitle: _inputs.anchorEventTitle,
        );
      }
      ref.invalidate(bookPlansProvider(widget.book.id));
      if (runRes.isOk) {
        unawaited(
          ref
              .read(analyticsProvider)
              .logPlanCreated(mode: _inputs.mode.wireName),
        );
      }
      final bookRepo = ref.read(bookRepoProvider);
      if (markReading && widget.book.status == 'pending') {
        await bookRepo.changeStatus(widget.book.id, 'reading');
        if (mounted) {
          await maybeAutoCreateStatusEvents(
            ref: ref,
            context: context,
            book: widget.book.copyWith(status: BookStatus.reading),
            previousStatus: BookStatus.pending,
            newStatus: BookStatus.reading,
            l: l,
          );
        }
      }
      await _persistTotals(bookRepo);
      final user = ref.read(sessionProvider).user;
      if (user != null) {
        await resyncLocalNotifications(
          ref,
          l,
          user,
          // Creating a plan with reminders enabled is an explicit reminder
          // action, so Android 13+ gets its runtime permission prompt here too
          // (single-event creation already does the same).
          requestPermission: _inputs.remindersOn,
        );
      }
    } on Object catch (error, stackTrace) {
      // Best-effort; the plan itself succeeded.
      debugPrint(
        'Plan $planId saved but post-create reminder sync failed: '
        '$error\n$stackTrace',
      );
    }
    // Best-effort: keep the home-screen widget's snapshot fresh instead of
    // waiting for the native poll (up to 30 min) to reflect the new plan.
    unawaited(syncWidget(ref).catchError((Object _) => false));

    if (!mounted) return;
    unawaited(RdHaptics.medium());
    setState(() {
      _phase = _Phase.done;
      _doneCount =
          createdIds.length +
          replacements.length +
          completedMoves.length +
          (todayReplacement == null ? 0 : 1);
      _doneStart = doneStart;
      _doneEnd = doneEnd;
      _donePlanId = planId;
    });
  }

  /// Deletes the created events to roll back a cancelled/failed plan, retrying a
  /// couple of times so a transient error (or a rate-limit blip) doesn't strand
  /// orphaned events.
  Future<bool> _rollback(EventRepository repo, List<String> ids) async {
    var res = await repo.deleteBatch(ids);
    var attempt = 0;
    while (res.isErr && attempt < 2) {
      attempt++;
      await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      res = await repo.deleteBatch(ids);
    }
    return res.isOk;
  }

  Future<bool> _restoreReplanEvents(
    EventRepository repo,
    List<ReadingEvent> originals,
    Set<String> reopenedOriginalIds,
  ) async {
    var restored = true;
    for (final original in originals.reversed) {
      var update = await repo.update(
        original.id,
        _originalEventUpdateBody(original),
      );
      var attempt = 0;
      while (update.isErr && attempt < 2) {
        attempt++;
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
        update = await repo.update(
          original.id,
          _originalEventUpdateBody(original),
        );
      }
      if (update.isErr) {
        restored = false;
        continue;
      }
      if (reopenedOriginalIds.contains(original.id) &&
          original.status == EventStatus.completed) {
        final complete = await repo.complete(original.id);
        if (complete.isErr) restored = false;
      }
    }
    return restored;
  }

  Future<void> _persistTotals(BookRepository bookRepo) async {
    final total = _inputs.total;
    if (total == null) return;
    final isCh = _inputs.unit == PlanUnit.chapters;
    if (isCh && total != widget.book.chapterCount) {
      await bookRepo.updateTotals(widget.book.id, chapterCount: total);
    } else if (!isCh && total != widget.book.pageCount) {
      await bookRepo.updateTotals(widget.book.id, pageCount: total);
    }
  }

  void _goToCalendar() {
    final first = _doneStart;
    ref.read(tabIndexProvider.notifier).state = 2;
    if (first != null) {
      ref.read(calendarFocusProvider.notifier).state = first;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Soft store-review ask for engaged users creating a personal plan, then
  /// leave the Done view. Replans skip the ask.
  Future<void> _leaveDoneView({required bool toCalendar}) async {
    if (!_isReplan && mounted) {
      await maybeShowStoreReviewPrompt(
        context,
        ref,
        trigger: StoreReviewTrigger.plan,
      );
    }
    if (!mounted) return;
    if (toCalendar) {
      _goToCalendar();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Undo the plan that was just created, straight from the completion screen
  /// (so the user doesn't have to dig into plan history to reverse a misfire).
  /// On success, the events disappear and we pop back to the book detail.
  Future<void> _undoCreatedPlan() async {
    final planId = _donePlanId;
    if (planId == null) return;
    setState(() => _undoingDone = true);
    await _undoPlan(planId);
    if (mounted) setState(() => _undoingDone = false);
  }

  /// Drop the whole plan while replanning (same confirm + API as plan history).
  Future<void> _undoReplanPlan() async {
    final planId = widget.replan?.planId;
    if (planId == null) return;
    await _undoPlan(planId);
  }

  Future<void> _undoPlan(String planId) async {
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

    final showReplanLoading = _isReplan && _phase == _Phase.form;
    if (showReplanLoading) setState(() => _undoingReplan = true);
    try {
      final res = await ref.read(planRepoProvider).undoPlan(planId);
      if (!mounted) return;

      if (res.isErr) {
        showRdToast(
          context,
          tone: RdToastTone.error,
          message: l.planUndoFailed,
        );
        return;
      }
      final deleted = res.value ?? 0;
      ref
        ..invalidate(upcomingEventsProvider)
        ..invalidateCalendarEvents(removedPlanId: planId)
        ..invalidate(booksProvider)
        ..invalidate(bookProvider(widget.book.id))
        ..invalidate(eventsForBookProvider(widget.book.id))
        ..invalidate(bookEventsHistoryProvider(widget.book.id))
        ..invalidate(bookPlansProvider(widget.book.id));
      final user = ref.read(sessionProvider).user;
      if (user != null) {
        try {
          await resyncLocalNotifications(ref, l, user);
        } catch (_) {
          // Best-effort; the cold-start resync covers it.
        }
      }
      unawaited(syncWidget(ref).catchError((Object _) => false));
      if (!mounted) return;
      showRdToast(
        context,
        tone: RdToastTone.success,
        message: l.planUndone(deleted),
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted && showReplanLoading) {
        setState(() => _undoingReplan = false);
      }
    }
  }

  // ── Mapping helpers ──────────────────────────────────────────────────────

  String get _eventOwnerType => 'user';

  String get _eventOwnerId => ref.read(sessionProvider).user?.id ?? '';

  Map<String, dynamic> _eventBody(
    PlannedEvent e,
    AppL10n l,
    String planId,
    int reminderMinutes,
  ) => {
    'ownerType': _eventOwnerType,
    'type': e.type.backendValue,
    'title': _eventTitle(e, l),
    'dateLocal': _ymd(e.date),
    'bookId': widget.book.id,
    'planId': planId,
    'reminderEnabled': _inputs.remindersOn,
    if (e.targetPage != null) 'targetPage': e.targetPage,
    if (e.targetChapter != null) 'targetChapter': e.targetChapter,
    if (_inputs.remindersOn) 'reminderMinutesBefore': reminderMinutes,
  };

  List<({ReadingEvent original, PlannedEvent shifted})> _completedCapstoneMoves(
    List<PlannedEvent> events,
  ) {
    if (!_isReplan) return const [];
    final moves = <({ReadingEvent original, PlannedEvent shifted})>[];
    for (final original in widget.replan!.state.completedCapstones) {
      final type = EventType.fromString(original.type);
      if (type == null) continue;
      for (final shifted in events) {
        if (_capstoneTypesEquivalent(type, shifted.type)) {
          moves.add((original: original, shifted: shifted));
          break;
        }
      }
    }
    return moves;
  }

  ({ReadingEvent original, PlannedEvent replacement})?
  _todayProgressReplacement(List<PlannedEvent> events) {
    if (!_isReplan || !_progressCatchUpApplied) return null;
    final today = _dateOnly(DateTime.now());
    final milestoneType = _inputs.unit == PlanUnit.pages
        ? EventType.pageMilestone
        : EventType.chapterMilestone;
    final replacement = events.cast<PlannedEvent?>().firstWhere(
      (event) =>
          event?.type == milestoneType && _dateOnly(event!.date) == today,
      orElse: () => null,
    );
    if (replacement == null) return null;
    final candidates =
        [
          ...widget.replan!.state.lockedEvents,
          ...widget.replan!.state.pending,
        ].where(
          (event) =>
              EventType.fromString(event.type) == milestoneType &&
              _dateOnly(event.dateLocal) == today,
        );
    if (candidates.isEmpty) return null;
    int target(ReadingEvent event) => _inputs.unit == PlanUnit.pages
        ? (event.targetPage ?? 0)
        : (event.targetChapter ?? 0);
    final original = candidates.reduce(
      (a, b) => target(a) >= target(b) ? a : b,
    );
    return (original: original, replacement: replacement);
  }

  Map<String, dynamic> _replanEventUpdateBody(
    ReadingEvent original,
    PlannedEvent replacement,
    int reminderMinutes,
  ) => {
    'ownerType': original.ownerType,
    'ownerId': original.ownerId,
    if (original.bookId != null) 'bookId': original.bookId,
    'type': replacement.type.backendValue,
    'title': _eventTitle(replacement, AppL10n.of(context)),
    'description': original.description,
    'dateLocal': _ymd(replacement.date),
    'timeLocal': original.timeLocal,
    'tz': original.tz,
    'targetPage': replacement.targetPage,
    'targetChapter': replacement.targetChapter,
    'reminderEnabled': _inputs.remindersOn,
    'reminderMinutesBefore': _inputs.remindersOn ? reminderMinutes : null,
    // A reused row now belongs to this authoritative replan, even when it came
    // from an older completed plan. Keeping its former plan id would hide it
    // from the next replan and allow the duplicate to return.
    'planId': widget.replan!.planId,
  };

  Map<String, dynamic> _originalEventUpdateBody(ReadingEvent original) => {
    'ownerType': original.ownerType,
    'ownerId': original.ownerId,
    if (original.bookId != null) 'bookId': original.bookId,
    'type': original.type,
    'title': original.title,
    'description': original.description,
    'dateLocal': _ymd(original.dateLocal),
    'timeLocal': original.timeLocal,
    'tz': original.tz,
    'targetPage': original.targetPage,
    'targetChapter': original.targetChapter,
    'reminderEnabled': original.reminderEnabled,
    'reminderMinutesBefore': original.reminderMinutesBefore,
    if (original.planId != null) 'planId': original.planId,
  };

  Map<String, dynamic> _todayProgressUpdateBody(
    ReadingEvent original,
    PlannedEvent replacement,
  ) => {
    'ownerType': original.ownerType,
    'ownerId': original.ownerId,
    if (original.bookId != null) 'bookId': original.bookId,
    'type': replacement.type.backendValue,
    'title': _eventTitle(replacement, AppL10n.of(context)),
    'description': original.description,
    'dateLocal': _ymd(replacement.date),
    'timeLocal': original.timeLocal,
    'tz': original.tz,
    'targetPage': replacement.targetPage,
    'targetChapter': replacement.targetChapter,
    'reminderEnabled': original.reminderEnabled,
    'reminderMinutesBefore': original.reminderMinutesBefore,
    if (original.planId != null) 'planId': original.planId,
  };

  Map<String, dynamic> _completedCapstoneUpdateBody(
    ReadingEvent original,
    PlannedEvent shifted,
  ) => {
    'ownerType': original.ownerType,
    'ownerId': original.ownerId,
    if (original.bookId != null) 'bookId': original.bookId,
    'type': original.type,
    'title': original.title,
    'description': original.description,
    'dateLocal': _ymd(shifted.date),
    'timeLocal': original.timeLocal,
    'tz': original.tz,
    'targetChapter': original.targetChapter,
    'targetPage': original.targetPage,
    'reminderEnabled': original.reminderEnabled,
    'reminderMinutesBefore': original.reminderMinutesBefore,
    if (original.planId != null) 'planId': original.planId,
  };

  ReadingEvent _toPreviewEvent(PlannedEvent e, AppL10n l, int index) =>
      ReadingEvent(
        id: 'preview-$index',
        ownerType: _eventOwnerType,
        ownerId: _eventOwnerId,
        bookId: widget.book.id,
        type: e.type.backendValue,
        title: _eventTitle(e, l),
        dateLocal: e.date,
        status: _isCompletedCapstone(e) ? 'completed' : 'active',
        targetChapter: e.targetChapter,
        targetPage: e.targetPage,
      );

  bool _isCompletedCapstone(PlannedEvent event) =>
      _isReplan &&
      widget.replan!.state.completedCapstones.any((completed) {
        final type = EventType.fromString(completed.type);
        return type != null && _capstoneTypesEquivalent(type, event.type);
      });

  static bool _capstoneTypesEquivalent(EventType a, EventType b) {
    if (a == b) return true;
    return (a == EventType.finish || a == EventType.deadline) &&
        (b == EventType.finish || b == EventType.deadline);
  }

  static bool _milestoneTypesEquivalent(EventType a, EventType b) =>
      (a == EventType.pageMilestone || a == EventType.chapterMilestone) &&
      (b == EventType.pageMilestone || b == EventType.chapterMilestone);

  String? _plannedMilestoneDayKey(PlannedEvent event) {
    if (event.type != EventType.pageMilestone &&
        event.type != EventType.chapterMilestone) {
      return null;
    }
    return _ymd(event.date);
  }

  String? _readingMilestoneDayKey(ReadingEvent event) {
    final type = EventType.fromString(event.type);
    if (type == null ||
        (type != EventType.pageMilestone &&
            type != EventType.chapterMilestone)) {
      return null;
    }
    return _ymd(event.dateLocal);
  }

  Set<String> _lockedBookendIdsSupersededByOptions() {
    if (!_isReplan || !_recalculatedFromOptions) return const {};
    return {
      for (final event in widget.replan!.state.lockedEvents)
        if (_isReadingBookend(event)) event.id,
    };
  }

  bool get _hasLockedStartBookend {
    if (!_isReplan) return false;
    return widget.replan!.state.lockedEvents.any(
      (event) => EventType.fromString(event.type) == EventType.start,
    );
  }

  /// Catch-up rebuilds the unread tail. The existing start bookend (even a
  /// past one) stays put unless Change options is regenerating markers.
  bool get _preserveLockedStartBookend =>
      _hasLockedStartBookend && !_recalculatedFromOptions;

  bool get _shouldGenerateStartBookend {
    if (!_inputs.includeStart) return false;
    return !_preserveLockedStartBookend;
  }

  bool _isReadingBookend(ReadingEvent event) {
    final type = EventType.fromString(event.type);
    return type == EventType.start ||
        type == EventType.finish ||
        type == EventType.deadline;
  }

  int _comparePreviewItems(_PreviewItem a, _PreviewItem b) {
    final dateOrder = a.date.compareTo(b.date);
    if (dateOrder != 0) return dateOrder;
    return planPreviewTypePriority(a.event?.type).compareTo(
      planPreviewTypePriority(b.event?.type),
    );
  }

  int _comparePreviewReadingEvents(ReadingEvent a, ReadingEvent b) {
    final dateOrder = a.dateLocal.compareTo(b.dateLocal);
    if (dateOrder != 0) return dateOrder;
    return planPreviewTypePriority(EventType.fromString(a.type)).compareTo(
      planPreviewTypePriority(EventType.fromString(b.type)),
    );
  }

  /// A marker for a removed reading day, so it still shows (dimmed) on the
  /// calendar and can be tapped to restore.
  ReadingEvent _removedPreviewEvent(DateTime date, AppL10n l) => ReadingEvent(
    id: 'removed-${_ymd(date)}',
    ownerType: _eventOwnerType,
    ownerId: _eventOwnerId,
    bookId: widget.book.id,
    type:
        (_inputs.unit == PlanUnit.chapters
                ? EventType.chapterMilestone
                : EventType.pageMilestone)
            .backendValue,
    title: l.planRemovedDay,
    dateLocal: date,
    status: 'active',
  );

  String _eventTitle(PlannedEvent e, AppL10n l) => switch (e.type) {
    EventType.start => l.planEventStart,
    EventType.finish => l.planEventFinish,
    EventType.deadline => l.planEventDeadline,
    EventType.chapterMilestone => l.planMilestoneChapter(e.targetChapter ?? 0),
    _ => l.planMilestonePage(e.targetPage ?? 0),
  };

  String _fmt(DateTime d) =>
      MaterialLocalizations.of(context).formatShortDate(d);
  String _fmtMonth(DateTime d) =>
      MaterialLocalizations.of(context).formatMonthYear(d);
  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// A preview entry: an active event, or (when [event] is null) a day the user
/// removed but kept visible/disabled.
class _PreviewItem {
  _PreviewItem(this.date, this.event, {this.locked = false});
  final DateTime date;
  final PlannedEvent? event;

  /// A completed event in replan mode: shown dimmed, can't be toggled off.
  final bool locked;
}

class _Row {
  _Row.header(this.header) : item = null;
  _Row.item(this.item) : header = null;
  final DateTime? header;
  final _PreviewItem? item;
}

/// Standing plan advice pinned in the footer: implied finish (pace) or needed
/// pace (deadline), plus soft warnings. Uses [inputs] so Adjust can show the
/// draft estimate while Events shows the applied plan (incl. exclusions).
/// When [applied] is set (Events, clean draft), prefer that result so the card
/// matches the visible calendar/list (replan seed + live exclusions).
class _PlanAdvice extends StatelessWidget {
  const _PlanAdvice({
    required this.inputs,
    this.applied,
    this.compact = false,
  });
  final PlanInputs inputs;
  final PlanResult? applied;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ml = MaterialLocalizations.of(context);
    final preview = (applied != null && applied!.isOk)
        ? applied!
        : generatePlan(inputs);

    final IconData primaryIcon;
    final String primaryText;
    if (preview.isOk) {
      if (inputs.mode == PlanMode.pace) {
        primaryIcon = LucideIcons.calendarClock;
        primaryText = l.planDerivedFinish(
          ml.formatShortDate(preview.endDate!),
          preview.readingDays,
        );
      } else {
        final unit = inputs.unit == PlanUnit.chapters
            ? l.planPerDayChapters
            : l.planPerDayPages;
        primaryIcon = LucideIcons.gauge;
        final pace = preview.perDay;
        primaryText = pace != null
            ? l.planDerivedPace(pace, unit)
            : (inputs.mode == PlanMode.beforeEvent
                  ? l.planHistorySummaryBeforeEvent
                  : l.planHistorySummaryDeadline);
      }
    } else {
      primaryIcon = LucideIcons.info;
      primaryText = switch (preview.issue) {
        PlanIssue.nothingToRead => l.planIssueNothingToRead,
        PlanIssue.invalidPace => l.planIssueInvalidPace,
        PlanIssue.invalidRange => l.planIssueInvalidRange,
        PlanIssue.noReadingDays => l.planIssueNoReadingDays,
        PlanIssue.needsTotal =>
          inputs.unit == PlanUnit.chapters
              ? l.planNeedChapters
              : l.planNeedPages,
        PlanIssue.overHardCap || null => l.planAdvicePending,
      };
    }

    final warnings = <String>[];
    if (preview.isOk && preview.isAggressivePace(inputs.unit)) {
      warnings.add(
        inputs.excludedDates.isNotEmpty
            ? l.planExclusionsTight
            : l.planPaceAggressive,
      );
    }
    final today = _PlanScreenState._dateOnly(DateTime.now());
    if (_PlanScreenState._dateOnly(inputs.startDate).isBefore(today)) {
      warnings.add(l.planStartInPast);
    }
    if (preview.isOk && preview.overSoftCap) {
      warnings.add(l.planManyWarning(preview.count));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: context.colors.accentSoftBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.line),
          ),
          child: _line(primaryIcon, primaryText, context.colors.accentSoftFg),
        ),
        for (final w in warnings) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _line(LucideIcons.alertTriangle, w, context.colors.warning),
          ),
        ],
      ],
    );
  }

  Widget _line(IconData icon, String text, Color color) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

// ── Progress + Done views ──────────────────────────────────────────────────

class _ProgressView extends StatelessWidget {
  const _ProgressView({
    required this.updating,
    required this.processed,
    required this.total,
    required this.rollingBack,
    required this.onCancel,
  });

  final bool updating;
  final int processed;
  final int total;
  final bool rollingBack;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final pct = total == 0 ? 0.0 : processed / total;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rollingBack
                ? l.planRollingBack
                : updating
                ? l.planUpdateProgressTitle
                : l.planProgressTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(l.importProgressLabel(processed, total)),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: v, minHeight: 8),
            ),
          ),
          const SizedBox(height: 20),
          if (!rollingBack)
            RdButton.plain(
              onPressed: onCancel,
              label: l.actionCancel,
            ),
        ],
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.updated,
    required this.count,
    required this.start,
    required this.end,
    required this.undoing,
    required this.onCalendar,
    required this.onDone,
    this.onUndo,
  });

  final bool updated;
  final int count;
  final DateTime? start;
  final DateTime? end;
  final bool undoing;
  final VoidCallback onCalendar;
  final VoidCallback? onUndo;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final ml = MaterialLocalizations.of(context);
    final hasRange = start != null && end != null;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.calendarCheck,
            size: 56,
            color: context.colors.success,
          ),
          const SizedBox(height: 16),
          Text(
            updated ? l.planUpdateCompleteTitle : l.planCompleteTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Count on its own line; the date range below it, never truncated.
          Text(
            l.planEventsCount(count),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.fg3),
          ),
          if (hasRange) ...[
            const SizedBox(height: 2),
            Text(
              l.planRange(
                ml.formatShortDate(start!),
                ml.formatShortDate(end!),
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.fg3),
            ),
          ],
          const SizedBox(height: 24),
          RdButton.primary(
            expand: true,
            onPressed: undoing ? null : onCalendar,
            icon: LucideIcons.calendar,
            label: l.planViewInCalendar,
          ),
          if (onUndo != null) ...[
            const SizedBox(height: 8),
            // Fresh create only: undo the whole plan. Hidden after replan
            // because undoPlan would also delete locked/past anchors.
            RdButton.destructive(
              expand: true,
              loading: undoing,
              onPressed: undoing ? null : onUndo,
              icon: LucideIcons.undo2,
              label: l.planUndoCreated,
            ),
          ],
          const SizedBox(height: 8),
          RdButton.plain(
            onPressed: undoing ? null : onDone,
            label: l.importDone,
          ),
        ],
      ),
    );
  }
}
