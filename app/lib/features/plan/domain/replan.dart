import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';

/// Inputs for re-spacing the **pending tail** of an existing plan ("Replanificar").
///
/// Unlike `generatePlan`, this never invents or revives milestones: the caller
/// passes the targets of the events that actually still exist ([pendingTargets],
/// deletions already applied), and this only re-assigns their dates using the
/// plan's own cadence. Completed events are immutable anchors handled by the
/// caller — they define [anchorDate] (the first reading day for the tail) and
/// [startUnit] (the position already reached). With no exclusions the result
/// reproduces the existing schedule exactly; removing a day shifts that event
/// and every later event onto the next available reading day. A deadline is the
/// original distribution window, not a boundary that compresses shifted events.
/// See `replan-feature-design` and `plan_generator.dart`.
class ReplanInputs {
  const ReplanInputs({
    required this.mode,
    required this.unit,
    required this.anchorDate,
    required this.startUnit,
    required this.total,
    required this.pendingTargets,
    this.configuredStartDate,
    this.perDay,
    this.endDate,
    this.includeFinish = true,
    this.excludedWeekdays = const {},
    this.excludedDates = const {},
  });

  final PlanMode mode;
  final PlanUnit unit;

  /// The first reading day the tail may use (day after the last completed
  /// anchor, or the plan's original start when nothing is completed yet).
  final DateTime anchorDate;

  /// Start date last saved in the plan-run options. [anchorDate] may advance
  /// after completed progress, but Change options must show this exact value.
  final DateTime? configuredStartDate;

  /// Cumulative units already covered at [anchorDate] (last completed milestone
  /// target, or the plan's original start position).
  final int startUnit;

  /// Total pages/chapters of the book — the target of the finish/deadline event.
  final int total;

  /// The fixed cumulative targets of the still-existing pending milestones,
  /// ascending, each strictly between [startUnit] and [total]. Deletions are
  /// already reflected here.
  final List<int> pendingTargets;

  /// Units per reading day (pace mode).
  final int? perDay;

  /// Date-only deadline (deadline mode).
  final DateTime? endDate;

  /// Whether the live plan still carries a finish (pace) / deadline capstone.
  final bool includeFinish;

  final Set<int> excludedWeekdays;
  final Set<DateTime> excludedDates;
}

/// Shifts an existing pending schedule without rebuilding it.
///
/// Dates before the first excluded event are immutable, including intentional
/// gaps left by previous exclusions or deleted milestones. From the excluded
/// event onward, event groups shift through the plan's own later event dates.
/// Empty calendar gaps are never promoted into plan slots; any displaced tail
/// is appended on the first available day after the original last event.
PlanResult shiftPendingEventsForward(
  List<PlannedEvent> pending, {
  Set<int> excludedWeekdays = const {},
  Set<DateTime> excludedDates = const {},
  Set<DateTime> occupiedDates = const {},
  int? perDay,
  int totalUnits = 0,
}) {
  if (pending.isEmpty) {
    return const PlanResult(events: [], issue: PlanIssue.nothingToRead);
  }
  if (excludedWeekdays.length >= 7) {
    return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
  }

  final excluded = excludedDates.map(_dateOnly).toSet();
  final occupied = occupiedDates.map(_dateOnly).toSet();
  bool isRegularReadingDay(DateTime d) => !excludedWeekdays.contains(d.weekday);
  bool isAvailable(DateTime d) =>
      isRegularReadingDay(d) && !excluded.contains(d) && !occupied.contains(d);

  final sorted = coalesceMilestonesPerCivilDay(pending)
    ..sort((a, b) => a.date.compareTo(b.date));
  final groups = <({DateTime date, List<PlannedEvent> events})>[];
  for (final event in sorted) {
    final date = _dateOnly(event.date);
    if (groups.isEmpty || groups.last.date != date) {
      groups.add((date: date, events: [event]));
    } else {
      groups.last.events.add(event);
    }
  }

  // Reuse only dates that already contain this plan's events. In particular,
  // empty July 24/25 dates in a July 21-August 5 plan are not free slots to
  // backfill when July 22 is excluded.
  final slots = [
    for (final group in groups)
      if (isAvailable(group.date)) group.date,
  ];

  var cursor = groups.last.date;
  var scanned = 0;
  final maxScan = groups.length * 7 + 800;
  while (slots.length < groups.length && scanned < maxScan) {
    cursor = _nextDay(cursor);
    if (isAvailable(cursor)) slots.add(cursor);
    scanned++;
  }
  if (slots.length < groups.length) {
    return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
  }

  final shifted = <PlannedEvent>[];
  for (var i = 0; i < groups.length; i++) {
    for (final event in groups[i].events) {
      shifted.add(
        PlannedEvent(
          date: slots[i],
          type: event.type,
          targetPage: event.targetPage,
          targetChapter: event.targetChapter,
        ),
      );
    }
  }

  return PlanResult(
    events: shifted,
    startDate: shifted.first.date,
    endDate: shifted.last.date,
    perDay: perDay,
    totalUnits: totalUnits,
    estimatedCount: shifted.length,
    readingDays: groups.length,
  );
}

/// Re-spaces [ReplanInputs.pendingTargets] across reading days, returning the
/// pending events to persist. Pure and deterministic; reuses [PlanResult] so the
/// existing preview (list/calendar) can render it unchanged.
PlanResult redistributePending(ReplanInputs input) {
  final total = input.total;
  if (total <= 0) {
    return const PlanResult(events: [], issue: PlanIssue.needsTotal);
  }
  if (input.excludedWeekdays.length >= 7) {
    return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
  }

  final start = _dateOnly(input.anchorDate);
  final excluded = input.excludedDates.map(_dateOnly).toSet();
  bool isRegularReadingDay(DateTime d) =>
      !input.excludedWeekdays.contains(d.weekday);
  bool isReadingDay(DateTime d) =>
      isRegularReadingDay(d) && !excluded.contains(d);

  final isChapters = input.unit == PlanUnit.chapters;
  final targets = [...input.pendingTargets]
    ..removeWhere((t) => t <= input.startUnit || t >= total)
    ..sort();

  final events = <PlannedEvent>[];

  PlannedEvent milestone(DateTime date, int target) => PlannedEvent(
    date: date,
    type: isChapters ? EventType.chapterMilestone : EventType.pageMilestone,
    targetChapter: isChapters ? target : null,
    targetPage: isChapters ? null : target,
  );

  if (input.mode == PlanMode.pace) {
    final perDay = input.perDay ?? 0;
    if (perDay < 1) {
      return const PlanResult(events: [], issue: PlanIssue.invalidPace);
    }
    // Reading-day index (0-based) on which cumulative reading reaches [t].
    int dayIndexFor(int t) =>
        ((t - input.startUnit + perDay - 1) ~/ perDay) - 1;

    final lastTarget = input.includeFinish
        ? total
        : (targets.isEmpty ? input.startUnit : targets.last);
    final daysNeeded = dayIndexFor(lastTarget) + 1;
    if (daysNeeded > planHardCap) {
      return PlanResult(
        events: const [],
        issue: PlanIssue.overHardCap,
        estimatedCount: daysNeeded,
      );
    }
    final days = _firstReadingDays(start, daysNeeded, isReadingDay);
    if (days.isEmpty) {
      return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
    }
    final clampMax = days.length - 1;
    for (final t in targets) {
      events.add(milestone(days[dayIndexFor(t).clamp(0, clampMax)], t));
    }
    if (input.includeFinish) {
      events.add(
        PlannedEvent(
          date: days[dayIndexFor(total).clamp(0, clampMax)],
          type: EventType.finish,
        ),
      );
    }
  } else {
    final end = input.endDate == null ? null : _dateOnly(input.endDate!);
    if (end == null || end.isBefore(start)) {
      return const PlanResult(events: [], issue: PlanIssue.invalidRange);
    }
    final originalDays = _readingDaysInRange(
      start,
      end,
      isRegularReadingDay,
      planHardCap + 1,
    );
    final originalDayCount = originalDays.length;
    if (originalDayCount == 0) {
      return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
    }
    // Positions: one per pending milestone plus the capstone (which always
    // lands on the last reading day). When there are more live events than days
    // in the original window, extend the schedule rather than stacking several
    // events on its last day.
    final positions = targets.length + (input.includeFinish ? 1 : 0);
    if (positions == 0) {
      return const PlanResult(events: [], issue: PlanIssue.nothingToRead);
    }
    final scheduleDayCount = originalDayCount > positions
        ? originalDayCount
        : positions;
    if (scheduleDayCount > planHardCap) {
      return PlanResult(
        events: const [],
        issue: PlanIssue.overHardCap,
        estimatedCount: scheduleDayCount,
      );
    }
    // Specific preview exclusions preserve the slot count and push the affected
    // tail forward. This can move the capstone past the original deadline.
    final readingDays = _firstReadingDays(
      start,
      scheduleDayCount,
      isReadingDay,
    );
    if (readingDays.length < scheduleDayCount) {
      return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
    }
    var lastIdx = -1;
    for (var j = 0; j < targets.length; j++) {
      // ceil((j+1) * scheduleDayCount / positions) - 1.
      var idx = (((j + 1) * scheduleDayCount + positions - 1) ~/ positions) - 1;
      idx = idx.clamp(0, scheduleDayCount - 1);
      if (idx <= lastIdx) idx = lastIdx + 1;
      lastIdx = idx;
      events.add(milestone(readingDays[idx], targets[j]));
    }
    if (input.includeFinish) {
      final idx = scheduleDayCount - 1;
      events.add(
        PlannedEvent(date: readingDays[idx], type: EventType.finish),
      );
    }
  }

  final coalescedEvents = coalesceMilestonesPerCivilDay(events);
  if (coalescedEvents.isEmpty) {
    return const PlanResult(events: [], issue: PlanIssue.nothingToRead);
  }

  return PlanResult(
    events: coalescedEvents,
    startDate: coalescedEvents.first.date,
    endDate: coalescedEvents.last.date,
    perDay: input.perDay,
    totalUnits: total - input.startUnit,
    estimatedCount: coalescedEvents.length,
    readingDays: coalescedEvents
        .map((event) => _dateOnly(event.date))
        .toSet()
        .length,
  );
}

/// The derived starting point of a replan: the live events split into immutable
/// [lockedEvents] and editable [pending] events, plus the [inputs] that seed both
/// the form and [redistributePending]. Built purely from the plan's live events
/// (and its [PlanRun] when present) so it works for orphan plans too.
class ReplanState {
  const ReplanState({
    required this.completed,
    required this.lockedEvents,
    required this.pending,
    required this.inputs,
    required this.includeStart,
    this.savedRun,
  });

  /// Completed events, sorted by date. Kept separately to derive reading
  /// progress even when a completed capstone remains movable.
  final List<ReadingEvent> completed;

  /// Events that a replan must never mutate: every event before today,
  /// a start bookend dated today, and completed non-capstone milestones.
  final List<ReadingEvent> lockedEvents;

  /// Mutable active events dated today or later, sorted by date. A start
  /// bookend dated today is excluded because recalculation must preserve it.
  /// The initial review shows these as-is ("tal cual estaba"); redistribution
  /// starts only on edits.
  final List<ReadingEvent> pending;

  final ReplanInputs inputs;

  /// Whether the live plan still carries a (pending) start bookend.
  final bool includeStart;

  /// Exact persisted generator options. Null for reconstructed orphan plans.
  final PlanRun? savedRun;

  List<ReadingEvent> get completedCapstones => completed
      .where(_isCapstone)
      .where((event) => !lockedEvents.any((locked) => locked.id == event.id))
      .toList(growable: false);

  /// Existing rows retained by the replan, including movable completed
  /// capstones (which are updated in place instead of recreated).
  List<ReadingEvent> get retainedEvents =>
      [...lockedEvents, ...completedCapstones]
        ..sort((a, b) => a.dateLocal.compareTo(b.dateLocal));

  bool get hasPending => pending.isNotEmpty;
}

/// Hands the plan screen everything it needs to re-plan: the existing plan's
/// [planId] (reused so retained events + the new tail stay one plan) and the
/// derived [state]. See `replan-feature-design`.
class ReplanLaunch {
  const ReplanLaunch({
    required this.planId,
    required this.state,
    this.allBookEvents = const [],
  });
  final String planId;
  final ReplanState state;

  /// Full book-event snapshot loaded when replanning opened. The save boundary
  /// uses it to reconcile same-day milestones that belong to older plan runs
  /// instead of creating a second event beside them.
  final List<ReadingEvent> allBookEvents;
}

EventType? _typeOf(ReadingEvent e) => EventType.fromString(e.type);
bool _isCapstone(ReadingEvent e) {
  final t = _typeOf(e);
  return t == EventType.finish || t == EventType.deadline;
}

bool _isMilestone(ReadingEvent e) {
  final t = _typeOf(e);
  return t == EventType.chapterMilestone || t == EventType.pageMilestone;
}

int? _targetOf(ReadingEvent e) => e.targetChapter ?? e.targetPage;

/// Builds the [ReplanState] for one plan from its live events (those tagged with
/// the plan id and not cancelled) plus its [run] (nullable for orphan plans) and
/// the [book] (total fallback). Pure — injected [now] only matters when the plan
/// has no usable start date. Events strictly before [now]'s civil date, plus a
/// start bookend on today's civil date, are always locked and excluded from
/// recalculation. Returns null when there's nothing mutable to replan (no
/// pending milestones AND no pending capstone).
ReplanState? buildReplanState(
  List<ReadingEvent> events, {
  required Book book,
  required DateTime now,
  PlanRun? run,
}) {
  final live = events.where((e) => e.status != EventStatus.cancelled).toList()
    ..sort((a, b) => a.dateLocal.compareTo(b.dateLocal));
  final completed = live
      .where((e) => e.status == EventStatus.completed)
      .toList();
  final today = _dateOnly(now);
  bool isLocked(ReadingEvent event) {
    final eventDate = _dateOnly(event.dateLocal);
    return eventDate.isBefore(today) ||
        (_typeOf(event) == EventType.start && eventDate == today) ||
        (event.status == EventStatus.completed && !_isCapstone(event));
  }

  final lockedEvents = live.where(isLocked).toList(growable: false);
  final pending = live
      .where(
        (event) => event.status == EventStatus.active && !isLocked(event),
      )
      .toList(growable: false);

  final pendingMilestones = pending.where(_isMilestone).toList();
  // Bookend toggles describe the saved plan configuration, not whether the
  // marker happens to be pending today. Past/completed bookends still need to
  // reappear selected when the user opens Change options.
  final includeFinish = run?.includeFinish ?? live.any(_isCapstone);
  final includeStart =
      run?.includeStart ?? live.any((e) => _typeOf(e) == EventType.start);
  if (pendingMilestones.isEmpty && !pending.any(_isCapstone)) return null;

  // Unit: prefer the run's, else infer from the events' targets.
  final PlanUnit unit;
  if (run?.unit == PlanUnit.pages.name) {
    unit = PlanUnit.pages;
  } else if (run?.unit == PlanUnit.chapters.name) {
    unit = PlanUnit.chapters;
  } else if (live.any((e) => e.targetPage != null && e.targetChapter == null)) {
    unit = PlanUnit.pages;
  } else {
    unit = PlanUnit.chapters;
  }

  // Mode: prefer the run's, else infer (a deadline capstone ⇒ deadline plan).
  final PlanMode mode;
  if (run?.mode != null) {
    mode = PlanMode.fromWire(run!.mode);
  } else {
    mode = live.any((e) => _typeOf(e) == EventType.deadline)
        ? PlanMode.deadline
        : PlanMode.pace;
  }

  // Total: the run's, else the book's, else the largest target seen.
  final targets = live.map(_targetOf).whereType<int>().toList()..sort();
  final total =
      run?.total ??
      (unit == PlanUnit.chapters ? book.chapterCount : book.pageCount) ??
      (targets.isEmpty ? 0 : targets.last);

  // startUnit + anchor: after the last completed milestone, else the plan start.
  final completedTargets = completed.map(_targetOf).whereType<int>().toList()
    ..sort();
  final int startUnit;
  final DateTime anchorDate;
  if (completedTargets.isNotEmpty) {
    startUnit = completedTargets.last;
    final lastCompletedDay = completed
        .map((e) => _dateOnly(e.dateLocal))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final afterCompleted = _nextDay(lastCompletedDay);
    anchorDate = afterCompleted.isBefore(today) ? today : afterCompleted;
  } else {
    final originalAnchor = _dateOnly(
      run?.startDate ?? (live.isEmpty ? now : live.first.dateLocal),
    );
    anchorDate = originalAnchor.isBefore(today) ? today : originalAnchor;
    // Infer the plan's original start position from the first milestone target.
    final firstTarget = pendingMilestones.isEmpty
        ? 0
        : (_targetOf(pendingMilestones.first) ?? 0);
    final perDayGuess = run?.perDay ?? _inferPerDay(targets);
    startUnit = (firstTarget - perDayGuess).clamp(0, total);
  }

  // Pace: the run's perDay, else inferred from milestone target gaps.
  final perDay = mode == PlanMode.pace
      ? (run?.perDay ?? _inferPerDay(targets))
      : null;

  // Deadline / before-event: the run's endDate, else the last live event's day.
  final endDate = mode.isDeadlineLike
      ? _dateOnly(run?.endDate ?? (live.isEmpty ? now : live.last.dateLocal))
      : null;

  final pendingTargets =
      pendingMilestones
          .map(_targetOf)
          .whereType<int>()
          .where((t) => t > startUnit && t < total)
          .toList()
        ..sort();

  return ReplanState(
    completed: completed,
    lockedEvents: lockedEvents,
    pending: pending,
    includeStart: includeStart,
    savedRun: run,
    inputs: ReplanInputs(
      mode: mode,
      unit: unit,
      anchorDate: anchorDate,
      configuredStartDate: run?.startDate == null
          ? anchorDate
          : _dateOnly(run!.startDate!),
      startUnit: startUnit,
      total: total,
      pendingTargets: pendingTargets,
      perDay: perDay,
      endDate: endDate,
      includeFinish: includeFinish,
      excludedWeekdays: run?.excludedWeekdays ?? _inferExcludedWeekdays(live),
    ),
  );
}

/// Standing "no reading" weekdays for reseeding the wizard / recalculate.
///
/// Any weekday that never hosts a live event is treated as excluded — including
/// weekends that fall outside a Mon–Fri span. Sparse schedules (few events over
/// a long window) skip inference: those gaps are usually deadline spacing, not
/// a weekday pattern.
Set<int> _inferExcludedWeekdays(List<ReadingEvent> live) {
  if (live.length < 2) return const {};
  final dates = live.map((e) => _dateOnly(e.dateLocal)).toSet();
  if (dates.length < 2) return const {};
  final sorted = dates.toList()..sort();
  final present = {for (final d in sorted) d.weekday};
  final spanDays = sorted.last.difference(sorted.first).inDays + 1;
  final density = dates.length / spanDays;
  // e.g. MWF in one week ≈ 0.6; three milestones across a month ≈ 0.1.
  if (density < 0.25) return const {};
  return {
    for (var wd = DateTime.monday; wd <= DateTime.sunday; wd++)
      if (!present.contains(wd)) wd,
  };
}

/// A sensible per-day pace inferred from the gaps between sorted [targets].
/// Falls back to 1 when there aren't enough points to tell.
int _inferPerDay(List<int> targets) {
  if (targets.length < 2) return 1;
  var sum = 0;
  for (var i = 1; i < targets.length; i++) {
    sum += targets[i] - targets[i - 1];
  }
  final avg = (sum / (targets.length - 1)).round();
  return avg < 1 ? 1 : avg;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first [n] reading days on/after [start], skipping excluded days. Bounded
/// so a pathological exclusion set can't loop forever. Mirrors the helper in
/// `plan_generator.dart` (kept private there to leave that file untouched).
List<DateTime> _firstReadingDays(
  DateTime start,
  int n,
  bool Function(DateTime) isReadingDay,
) {
  if (n <= 0) return const [];
  final out = <DateTime>[];
  var d = start;
  final maxScan = n * 7 + 800;
  var scanned = 0;
  while (out.length < n && scanned < maxScan) {
    if (isReadingDay(d)) out.add(d);
    d = _nextDay(d);
    scanned++;
  }
  return out;
}

/// Every reading day in [start, end] inclusive, stopping once more than [cap]
/// are found. Mirrors the helper in `plan_generator.dart`.
List<DateTime> _readingDaysInRange(
  DateTime start,
  DateTime end,
  bool Function(DateTime) isReadingDay,
  int cap,
) {
  final out = <DateTime>[];
  var d = start;
  while (!d.isAfter(end)) {
    if (isReadingDay(d)) {
      out.add(d);
      if (out.length > cap) break;
    }
    d = _nextDay(d);
  }
  return out;
}

DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
