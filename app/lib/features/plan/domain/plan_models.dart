import 'package:readendar/core/widgets/event_icon.dart';

/// Whether the plan is driven by a daily amount, a free deadline date, or an
/// existing calendar event as the finish day. See spec §6.9.
enum PlanMode {
  pace,
  deadline,
  beforeEvent;

  /// API / plan-run history wire value.
  String get wireName => switch (this) {
    PlanMode.pace => 'pace',
    PlanMode.deadline => 'deadline',
    PlanMode.beforeEvent => 'before_event',
  };

  static PlanMode fromWire(String? value) => switch (value) {
    'deadline' => PlanMode.deadline,
    'before_event' => PlanMode.beforeEvent,
    _ => PlanMode.pace,
  };

  /// Deadline and before-event both split remaining content across a date window.
  bool get isDeadlineLike =>
      this == PlanMode.deadline || this == PlanMode.beforeEvent;
}

/// The unit the plan distributes: pages (total from `book.pageCount`) or chapters
/// (total from the manually-entered/cached `book.chapterCount`).
enum PlanUnit { pages, chapters }

/// A plan above [planSoftCap] events shows a gentle warning; above [planHardCap]
/// it is blocked from creation.
const int planSoftCap = 200;
const int planHardCap = 730;

/// A derived reading pace above these per-day values is flagged as "demanding"
/// (a soft warning, never a block). Pages tolerate a higher daily count than
/// chapters since a chapter is the larger unit.
const int planAggressivePagesPerDay = 150;
const int planAggressiveChaptersPerDay = 15;

/// Default reading pace (units/day) seeded when starting a pace plan or switching
/// units. A chapter is the larger unit, so pages default to a higher daily count.
const int planDefaultPagesPerDay = 25;
const int planDefaultChaptersPerDay = 2;

/// The sensible starting pace for [unit].
int planDefaultPerDay(PlanUnit unit) => unit == PlanUnit.chapters
    ? planDefaultChaptersPerDay
    : planDefaultPagesPerDay;

/// Why a plan couldn't be generated (or shouldn't be created). `null` ⇒ ok.
enum PlanIssue {
  needsTotal, // the unit total is unknown / non-positive
  nothingToRead, // the start position is already at/after the total
  invalidPace, // pace mode with perDay < 1
  invalidRange, // deadline missing or before the start date
  noReadingDays, // every day is excluded
  overHardCap, // too many events to create
}

/// The user's planning inputs. Immutable; the screen recomputes the plan from a
/// fresh copy when the user runs "Calculate"/"Update".
class PlanInputs {
  const PlanInputs({
    required this.mode,
    required this.unit,
    required this.startDate,
    this.total,
    this.startUnit = 0,
    this.endDate,
    this.perDay,
    this.excludedWeekdays = const {},
    this.excludedDates = const {},
    this.remindersOn = true,
    this.includeStart = true,
    this.includeFinish = true,
    this.anchorEventId,
    this.anchorEventTitle,
  });

  final PlanMode mode;
  final PlanUnit unit;

  /// Date-only; the plan starts on or after this day.
  final DateTime startDate;

  /// Total pages or chapters of the book. `null` ⇒ unknown (preview held).
  final int? total;

  /// Units already read (page/chapter position to start from). 0 = from the top.
  final int startUnit;

  /// Date-only deadline (deadline / before-event modes).
  final DateTime? endDate;

  /// Units per reading day (pace mode only).
  final int? perDay;

  /// Weekdays to skip, using `DateTime.weekday` (1=Mon … 7=Sun).
  final Set<int> excludedWeekdays;

  /// Specific calendar days the user removed from the preview (date-only).
  final Set<DateTime> excludedDates;

  final bool remindersOn;

  /// Whether to emit the bookend events. With [includeFinish] off, the final
  /// reading day carries a plain milestone (target = total) instead.
  final bool includeStart;
  final bool includeFinish;

  /// Calendar event chosen in before-event mode (display + dirty tracking).
  final String? anchorEventId;
  final String? anchorEventTitle;

  PlanInputs copyWith({
    PlanMode? mode,
    PlanUnit? unit,
    DateTime? startDate,
    Object? total = _unset,
    int? startUnit,
    Object? endDate = _unset,
    Object? perDay = _unset,
    Set<int>? excludedWeekdays,
    Set<DateTime>? excludedDates,
    bool? remindersOn,
    bool? includeStart,
    bool? includeFinish,
    Object? anchorEventId = _unset,
    Object? anchorEventTitle = _unset,
  }) {
    return PlanInputs(
      mode: mode ?? this.mode,
      unit: unit ?? this.unit,
      startDate: startDate ?? this.startDate,
      total: total == _unset ? this.total : total as int?,
      startUnit: startUnit ?? this.startUnit,
      endDate: endDate == _unset ? this.endDate : endDate as DateTime?,
      perDay: perDay == _unset ? this.perDay : perDay as int?,
      excludedWeekdays: excludedWeekdays ?? this.excludedWeekdays,
      excludedDates: excludedDates ?? this.excludedDates,
      remindersOn: remindersOn ?? this.remindersOn,
      includeStart: includeStart ?? this.includeStart,
      includeFinish: includeFinish ?? this.includeFinish,
      anchorEventId: anchorEventId == _unset
          ? this.anchorEventId
          : anchorEventId as String?,
      anchorEventTitle: anchorEventTitle == _unset
          ? this.anchorEventTitle
          : anchorEventTitle as String?,
    );
  }
}

const Object _unset = Object();

/// One generated, not-yet-persisted event. Mapped to an [EventType] so it can be
/// rendered with the same row/marker widgets as a real event.
class PlannedEvent {
  const PlannedEvent({
    required this.date,
    required this.type,
    this.targetPage,
    this.targetChapter,
  });

  /// Date-only (the event is all-day).
  final DateTime date;
  final EventType type;
  final int? targetPage;
  final int? targetChapter;

  bool get isBookend =>
      type == EventType.start ||
      type == EventType.finish ||
      type == EventType.deadline;
}

/// Enforces the plan invariant that one book has at most one milestone on a
/// civil date. When a faster replan maps several historical targets onto one
/// day, the furthest target is the only useful milestone.
List<PlannedEvent> coalesceMilestonesPerCivilDay(
  Iterable<PlannedEvent> events,
) {
  final result = <PlannedEvent>[];
  final milestoneIndexByDay = <String, int>{};

  for (final event in events) {
    final isMilestone =
        event.type == EventType.pageMilestone ||
        event.type == EventType.chapterMilestone;
    if (!isMilestone) {
      result.add(event);
      continue;
    }

    final date = event.date;
    final key = '${date.year}-${date.month}-${date.day}';
    final existingIndex = milestoneIndexByDay[key];
    if (existingIndex == null) {
      milestoneIndexByDay[key] = result.length;
      result.add(event);
      continue;
    }

    final existing = result[existingIndex];
    final existingTarget = existing.targetPage ?? existing.targetChapter ?? 0;
    final candidateTarget = event.targetPage ?? event.targetChapter ?? 0;
    if (event.type != existing.type || candidateTarget > existingTarget) {
      result[existingIndex] = event;
    }
  }

  return result;
}

/// Visual priority for events sharing a civil date in a plan preview.
/// Milestones lead because their page/chapter target is more useful than a
/// structural start, finish, or deadline marker.
int planPreviewTypePriority(EventType? type) => switch (type) {
  EventType.pageMilestone || EventType.chapterMilestone => 0,
  EventType.start || EventType.finish || EventType.deadline => 1,
  _ => 2,
};

/// The output of `generatePlan`: the events plus summary figures and any issue.
class PlanResult {
  const PlanResult({
    required this.events,
    this.issue,
    this.startDate,
    this.endDate,
    this.perDay,
    this.totalUnits = 0,
    this.estimatedCount = 0,
    this.readingDays = 0,
  });

  final List<PlannedEvent> events;
  final PlanIssue? issue;

  /// First and last event dates (for the summary header).
  final DateTime? startDate;
  final DateTime? endDate;

  /// Effective pace (max units on any reading day) for the summary header.
  final int? perDay;

  /// Units scheduled (remaining content covered).
  final int totalUnits;

  /// Event count even when blocked by the hard cap (events is then empty).
  final int estimatedCount;

  /// Number of reading days in the schedule (for the derived summary, e.g.
  /// "… · N reading days"). 0 when no plan was produced.
  final int readingDays;

  bool get isOk => issue == null && events.isNotEmpty;

  /// Whether the effective daily pace is demanding for the given [unit].
  bool isAggressivePace(PlanUnit unit) {
    final p = perDay;
    if (p == null) return false;
    return p >
        (unit == PlanUnit.chapters
            ? planAggressiveChaptersPerDay
            : planAggressivePagesPerDay);
  }

  bool get isEmpty => events.isEmpty;
  int get count => events.length;
  bool get overSoftCap => count > planSoftCap;
  bool get overHardCap => issue == PlanIssue.overHardCap;

  static const empty = PlanResult(events: []);
}
