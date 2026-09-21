import 'package:flutter/material.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/app_motion.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/cover_badge.dart';
import 'package:readendar/core/widgets/event_icon.dart';

/// Maps the books referenced by a set of events, so rows/markers can resolve an
/// event's book by id without a lookup per widget. Shared by the calendar
/// screen and the reading-plan preview.
class EventRenderContext {
  EventRenderContext({required List<Book> personalBooks})
    : personalBooksById = {for (final b in personalBooks) b.id: b};

  final Map<String, Book> personalBooksById;

  Book? bookFor(ReadingEvent event) {
    final bookId = event.bookId;
    if (bookId == null) return null;
    return personalBooksById[bookId];
  }
}

/// A single month grid: a locale-first-weekday header plus the day cells, each with
/// an event marker. Self-contained and stateless — the caller supplies the
/// events for the month and handles day taps. Used both inside the calendar
/// screen (wrapped with a search field + events list) and the plan preview.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.events,
    required this.eventContext,
    required this.onOpenDay,
    this.dimmedDays = const {},
    this.disabledDays = const {},
    this.showMilestoneTargets = false,
    super.key,
  });

  final DateTime month;
  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final void Function(DateTime day, List<ReadingEvent> events) onOpenDay;

  /// Day-of-month numbers whose markers render at reduced opacity (e.g. reading
  /// days the user removed from a plan preview but can tap to restore).
  final Set<int> dimmedDays;

  /// Day-of-month numbers that render disabled and cannot be opened.
  final Set<int> disabledDays;

  /// When true (plan preview), each day shows the milestone page/chapter
  /// number under the cover so the schedule is readable at a glance.
  final bool showMilestoneTargets;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Leading blank cells before day 1, in a grid whose first column is the
    // locale's first weekday (Monday in Europe, Sunday in the US/Canada).
    final firstDow = firstDayOfWeekFor(context);
    final startWeekday = leadingWeekdayOffset(first, firstDow);
    final cells = startWeekday + daysInMonth;
    final rows = (cells / 7).ceil();
    final byDay = <int, List<ReadingEvent>>{};
    for (final e in events) {
      if (e.dateLocal.year == month.year && e.dateLocal.month == month.month) {
        byDay.putIfAbsent(e.dateLocal.day, () => []).add(e);
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _WeekdayHeader(),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                _buildDayCell(
                  context,
                  row,
                  col,
                  startWeekday,
                  daysInMonth,
                  byDay,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    int row,
    int col,
    int startWeekday,
    int daysInMonth,
    Map<int, List<ReadingEvent>> byDay,
  ) {
    final dayNum = row * 7 + col - startWeekday + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      return Expanded(
        child: Container(height: 84, margin: const EdgeInsets.all(2)),
      );
    }
    return Expanded(
      child: CalendarDayCell(
        date: DateTime(month.year, month.month, dayNum),
        events: byDay[dayNum] ?? const [],
        eventContext: eventContext,
        onOpenDay: onOpenDay,
        dimmed: dimmedDays.contains(dayNum),
        disabled: disabledDays.contains(dayNum),
        showMilestoneTarget: showMilestoneTargets,
      ),
    );
  }
}

/// One day cell — today-highlight, event markers, tap-to-open — shared by the
/// [MonthGrid] and the [WeekStrip] so the week view matches the month view.
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    required this.date,
    required this.events,
    required this.eventContext,
    required this.onOpenDay,
    this.height = 84,
    this.dimmed = false,
    this.disabled = false,
    this.showMilestoneTarget = false,
    super.key,
  });

  final DateTime date;
  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final void Function(DateTime day, List<ReadingEvent> events) onOpenDay;
  final double height;
  final bool dimmed;
  final bool disabled;
  final bool showMilestoneTarget;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final isToday =
        now.year == date.year && now.month == date.month && now.day == date.day;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: disabled ? null : () => onOpenDay(date, events),
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Container(
          height: height,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isToday ? context.colors.accentSoftBg : cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday ? context.colors.accent : cs.outline,
              width: isToday ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today's number sits in a filled accent pill so the current day
              // reads at a glance; other days show a plain number.
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.colors.fgOnAccent,
                    ),
                  ),
                )
              else
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              const Spacer(),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : ReadendarMotion.fast,
                switchInCurve: ReadendarMotion.curve,
                switchOutCurve: Curves.easeInCubic,
                // Cover stickers overhang the marker; don't clip them.
                layoutBuilder: (current, previous) => Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [...previous, ?current],
                ),
                child: events.isEmpty
                    ? const SizedBox.shrink(key: ValueKey('no-event-markers'))
                    : Opacity(
                        key: ValueKey(
                          events.map((event) => event.id).join(','),
                        ),
                        opacity: dimmed ? 0.3 : 1.0,
                        child: DayEventMarkers(
                          events: events,
                          eventContext: eventContext,
                          showMilestoneTarget: showMilestoneTarget,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single week: the weekday header + 7 taller day cells. Reuses the
/// month grid's [CalendarDayCell] so the week view is visually consistent with
/// the month view. [weekStart] must be the locale's first day of that week.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.weekStart,
    required this.events,
    required this.eventContext,
    required this.onOpenDay,
    super.key,
  });

  final DateTime weekStart;
  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final void Function(DateTime day, List<ReadingEvent> events) onOpenDay;

  @override
  Widget build(BuildContext context) {
    // Bucket the week's events by day in a single pass (vs a .where per cell).
    final byDay = <int, List<ReadingEvent>>{};
    for (final e in events) {
      byDay.putIfAbsent(_dayKey(e.dateLocal), () => []).add(e);
    }
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _WeekdayHeader(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final d in days)
                Expanded(
                  child: CalendarDayCell(
                    date: d,
                    events: byDay[_dayKey(d)] ?? const [],
                    eventContext: eventContext,
                    onOpenDay: onOpenDay,
                    height: 110,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A stable per-day key (`YYYYMMDD`) for bucketing events by calendar day.
int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Offset (0–6) of [day] from the first column of a week grid whose first
/// weekday is [firstDayOfWeekIndex] (0=Sunday, 1=Monday, … per
/// `MaterialLocalizations.firstDayOfWeekIndex`). Used to place the 1st of the
/// month and to compute the start of a week consistently across the month grid,
/// the week strip, and the calendar screen's paging.
int leadingWeekdayOffset(DateTime day, int firstDayOfWeekIndex) {
  final sundayIndexed = day.weekday % 7; // Dart Mon=1..Sun=7 → Sun=0..Sat=6
  return (sundayIndexed - firstDayOfWeekIndex + 7) % 7;
}

/// The active locale's first weekday index (0=Sunday) for calendar layout.
/// Wraps [MaterialLocalizations.firstDayOfWeekIndex] with one override: our
/// region-less Portuguese `pt` ("Português (Portugal)") is Monday-first per
/// Portuguese convention, whereas Flutter/CLDR maps region-less `pt` to Sunday.
/// Brazilian Portuguese (`pt-BR`) keeps its Sunday-first value.
int firstDayOfWeekFor(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'pt' && locale.countryCode != 'BR') return 1;
  return MaterialLocalizations.of(context).firstDayOfWeekIndex;
}

/// The weekday initials header shared by [MonthGrid] and [WeekStrip]. Labels are
/// the active locale's narrow weekday names, ordered from the locale's first
/// weekday (was hard-coded Spanish "L M X J V S D", Monday-first, shown in every
/// locale). For `es` this reproduces the previous labels exactly.
class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;
    final firstDow = firstDayOfWeekFor(context); // 0=Sunday
    final labels = [for (var i = 0; i < 7; i++) narrow[(firstDow + i) % 7]];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: labels
            .map(
              (d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.fg2,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// A single marker for a day cell — the first event's book cover, a type icon
/// when there is no book, or a type dot as a last resort — plus a "+N" badge
/// when the day holds more.
class DayEventMarkers extends StatelessWidget {
  const DayEventMarkers({
    required this.events,
    required this.eventContext,
    this.showMilestoneTarget = false,
    super.key,
  });

  final List<ReadingEvent> events;
  final EventRenderContext eventContext;
  final bool showMilestoneTarget;

  @override
  Widget build(BuildContext context) {
    final primary = events.first;
    final primaryBook = eventContext.bookFor(primary);
    final extra = events.length - 1;
    final primaryCompleted = primary.status == EventStatus.completed;
    final primaryType =
        EventType.fromString(primary.type) ?? EventType.deadline;
    final targetLabel = showMilestoneTarget
        ? _milestoneTargetLabel(primary)
        : null;

    final Widget marker;
    if (primaryBook != null) {
      marker = BadgedCover(
        coverWidth: 32,
        eventType: primaryType,
        extraCount: extra,
        completed: primaryCompleted,
        cover: _coverSlot(
          targetLabel: targetLabel,
          child: FittedBox(
            fit: BoxFit.cover,
            child: BookCover(
              title: primaryBook.title,
              author: primaryBook.authors.firstOrNull,
              coverUrl: primaryBook.coverUrl,
              size: BookCoverSize.xs,
            ),
          ),
        ),
      );
    } else {
      marker = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: primaryType.colorOf(context),
              shape: BoxShape.circle,
            ),
          ),
          if (extra > 0)
            Positioned(
              top: -4,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: ReadendarTokens.periwinkle600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$extra',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: ReadendarTokens.paper50,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Align(alignment: Alignment.bottomCenter, child: marker);
  }

  /// 32×48 cover slot with an optional bottom black overlay for the target.
  Widget _coverSlot({required Widget child, String? targetLabel}) {
    return SizedBox(
      width: 32,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (targetLabel != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.72),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      targetLabel,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Page or chapter number for a milestone (and finish/deadline targets).
String? _milestoneTargetLabel(ReadingEvent event) {
  final page = event.targetPage;
  if (page != null && page > 0) return '$page';
  final chapter = event.targetChapter;
  if (chapter != null && chapter > 0) return '$chapter';
  return null;
}
