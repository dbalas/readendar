import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';

/// Builds a reading plan from the user's inputs (spec §6.9). Pure and
/// deterministic — run on demand (the "Calculate"/"Update" action) to drive the
/// preview.
///
/// Structure: day 1 carries a `start` event plus the first milestone; middle
/// reading days carry page/chapter milestones with cumulative targets; the last
/// reading day carries a `finish` event instead of a milestone (reaching the
/// final page IS finishing), in every mode.
///
/// Distribution:
///  - pace mode: each reading day reads `perDay`; the last day takes the leftover.
///  - deadline mode: the remaining content is split evenly across the reading
///    days in the window, with the remainder added to the earliest days.
PlanResult generatePlan(PlanInputs input) {
  final total = input.total;
  if (total == null || total <= 0) {
    return const PlanResult(events: [], issue: PlanIssue.needsTotal);
  }
  final startUnit = input.startUnit.clamp(0, total);
  final remaining = total - startUnit;
  if (remaining <= 0) {
    return const PlanResult(events: [], issue: PlanIssue.nothingToRead);
  }
  if (input.excludedWeekdays.length >= 7) {
    return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
  }

  final start = _dateOnly(input.startDate);
  final excluded = input.excludedDates.map(_dateOnly).toSet();
  bool isRegularReadingDay(DateTime d) =>
      !input.excludedWeekdays.contains(d.weekday);
  bool isReadingDay(DateTime d) =>
      isRegularReadingDay(d) && !excluded.contains(d);

  final List<DateTime> days;
  final List<int> amounts;
  int? userPerDay;

  if (input.mode == PlanMode.pace) {
    final perDay = input.perDay ?? 0;
    if (perDay < 1) {
      return const PlanResult(events: [], issue: PlanIssue.invalidPace);
    }
    userPerDay = perDay;
    final n = (remaining + perDay - 1) ~/ perDay; // ceil
    if (n + 1 > planHardCap) {
      return PlanResult(
        events: const [],
        issue: PlanIssue.overHardCap,
        estimatedCount: n + 1,
      );
    }
    days = _firstReadingDays(start, n, isReadingDay);
    amounts = List<int>.generate(
      n,
      (i) => i < n - 1 ? perDay : remaining - perDay * (n - 1),
    );
  } else {
    // deadline + beforeEvent: split remaining content across the window.
    final end = input.endDate == null ? null : _dateOnly(input.endDate!);
    if (end == null || end.isBefore(start)) {
      return const PlanResult(events: [], issue: PlanIssue.invalidRange);
    }
    // The deadline defines the original number of reading slots. Dates removed
    // later from the preview do not shrink or recompute the plan: they shift
    // that slot and every following slot onto the next available reading day,
    // even when that moves the capstone past the original deadline.
    final originalDays = _readingDaysInRange(
      start,
      end,
      isRegularReadingDay,
      planHardCap + 1,
    );
    final n = originalDays.length;
    if (n == 0) {
      return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
    }
    if (n + 1 > planHardCap) {
      return PlanResult(
        events: const [],
        issue: PlanIssue.overHardCap,
        estimatedCount: n + 1,
      );
    }
    days = _firstReadingDays(start, n, isReadingDay);
    if (days.length < n) {
      return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
    }
    amounts = _evenSplitRemainderEarliest(remaining, n);
  }

  final n = days.length;
  if (n == 0) {
    return const PlanResult(events: [], issue: PlanIssue.noReadingDays);
  }

  final isChapters = input.unit == PlanUnit.chapters;
  final events = <PlannedEvent>[
    // Day 1 opens with a start event (sits alongside the first milestone) unless
    // the user removed it in the form.
    if (input.includeStart)
      PlannedEvent(date: days.first, type: EventType.start),
  ];

  var cumulative = startUnit;
  var lastTarget = startUnit;
  for (var i = 0; i < n - 1; i++) {
    cumulative += amounts[i];
    // Emit a milestone only when progress strictly advances and stays below the
    // total (the finish event covers reaching the total). This skips no-progress
    // days that arise when there are more reading days than units left.
    if (cumulative > lastTarget && cumulative < total) {
      events.add(
        PlannedEvent(
          date: days[i],
          type: isChapters
              ? EventType.chapterMilestone
              : EventType.pageMilestone,
          targetChapter: isChapters ? cumulative : null,
          targetPage: isChapters ? null : cumulative,
        ),
      );
      lastTarget = cumulative;
    }
  }

  // The last reading day is the finish event — or, when the user removed that
  // bookend, a plain milestone for the final read.
  if (input.includeFinish) {
    events.add(
      PlannedEvent(
        date: days.last,
        type: EventType.finish,
      ),
    );
  } else if (total > lastTarget) {
    events.add(
      PlannedEvent(
        date: days.last,
        type: isChapters ? EventType.chapterMilestone : EventType.pageMilestone,
        targetChapter: isChapters ? total : null,
        targetPage: isChapters ? null : total,
      ),
    );
  }

  // Effective pace for the summary: the user's value in pace mode, else the
  // heaviest reading day in deadline mode.
  final perDayEff =
      userPerDay ??
      (amounts.isEmpty ? 0 : amounts.reduce((a, b) => a > b ? a : b));

  return PlanResult(
    events: events,
    startDate: days.first,
    endDate: days.last,
    perDay: perDayEff,
    totalUnits: remaining,
    estimatedCount: events.length,
    readingDays: n,
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// The first [n] reading days on/after [start], skipping excluded days. Bounded
/// so a pathological exclusion set can't loop forever.
List<DateTime> _firstReadingDays(
  DateTime start,
  int n,
  bool Function(DateTime) isReadingDay,
) {
  final out = <DateTime>[];
  var d = start;
  // Generous ceiling: even excluding 6 of 7 weekdays needs ~7 calendar days per
  // reading day, plus slack for excluded dates.
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
/// are found (the caller then reports an over-cap plan).
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

/// Splits [total] across [n] buckets as evenly as possible, adding the remainder
/// to the earliest buckets (so early days read a touch more).
List<int> _evenSplitRemainderEarliest(int total, int n) {
  final base = total ~/ n;
  final rem = total % n;
  return List<int>.generate(n, (i) => base + (i < rem ? 1 : 0));
}

DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
