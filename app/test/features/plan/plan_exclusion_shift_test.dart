import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';
import 'package:readendar/features/plan/domain/replan.dart';

DateTime d(int day) => DateTime(2024, 1, day);

void main() {
  test('replan shifts through its own event slots without filling gaps', () {
    final result = shiftPendingEventsForward(
      [
        PlannedEvent(
          date: d(1),
          type: EventType.pageMilestone,
          targetPage: 20,
        ),
        PlannedEvent(
          date: d(5),
          type: EventType.pageMilestone,
          targetPage: 40,
        ),
        PlannedEvent(
          date: d(7),
          type: EventType.pageMilestone,
          targetPage: 60,
        ),
        PlannedEvent(date: d(9), type: EventType.finish),
      ],
      excludedDates: {d(7)},
    );

    expect(result.events.map((e) => e.date).toList(), [
      d(1),
      d(5), // the existing gap before the exclusion is untouched
      d(9), // reuse the next plan event slot, not the empty day 8
      d(10),
    ]);
  });

  test('July 21-August 5 exclusion appends after the plan, not July 24', () {
    final result = shiftPendingEventsForward(
      [
        PlannedEvent(
          date: DateTime(2026, 7, 21),
          type: EventType.chapterMilestone,
          targetChapter: 1,
        ),
        PlannedEvent(
          date: DateTime(2026, 7, 22),
          type: EventType.chapterMilestone,
          targetChapter: 2,
        ),
        PlannedEvent(
          date: DateTime(2026, 7, 23),
          type: EventType.chapterMilestone,
          targetChapter: 3,
        ),
        PlannedEvent(
          date: DateTime(2026, 7, 26),
          type: EventType.chapterMilestone,
          targetChapter: 4,
        ),
        PlannedEvent(date: DateTime(2026, 8, 5), type: EventType.finish),
      ],
      excludedDates: {DateTime(2026, 7, 22)},
    );

    expect(result.events.map((e) => e.date).toList(), [
      DateTime(2026, 7, 21),
      DateTime(2026, 7, 23),
      DateTime(2026, 7, 26),
      DateTime(2026, 8, 5),
      DateTime(2026, 8, 6),
    ]);
    expect(
      result.events.any((e) => e.date == DateTime(2026, 7, 24)),
      isFalse,
    );
  });

  test('a completed deadline moves with the shifted event tail', () {
    final result = shiftPendingEventsForward(
      [
        PlannedEvent(
          date: DateTime(2026, 7, 14),
          type: EventType.pageMilestone,
          targetPage: 40,
        ),
        PlannedEvent(
          date: DateTime(2026, 7, 15),
          type: EventType.deadline,
        ),
        PlannedEvent(
          date: DateTime(2026, 7, 16),
          type: EventType.pageMilestone,
          targetPage: 60,
        ),
      ],
      excludedDates: {DateTime(2026, 7, 14)},
    );

    expect(result.events.map((e) => e.date).toList(), [
      DateTime(2026, 7, 15),
      DateTime(2026, 7, 16),
      DateTime(2026, 7, 17),
    ]);
  });

  test('completed milestone anchors remain occupied while the tail moves', () {
    final result = shiftPendingEventsForward(
      [
        PlannedEvent(
          date: DateTime(2026, 7, 14),
          type: EventType.pageMilestone,
          targetPage: 40,
        ),
        PlannedEvent(
          date: DateTime(2026, 7, 16),
          type: EventType.pageMilestone,
          targetPage: 60,
        ),
      ],
      excludedDates: {DateTime(2026, 7, 14)},
      occupiedDates: {DateTime(2026, 7, 15)},
    );

    expect(result.events.map((e) => e.date).toList(), [
      DateTime(2026, 7, 16),
      DateTime(2026, 7, 17),
    ]);
  });

  test('forward-only shifting stays stable across years with 600 events', () {
    final start = DateTime(2026);
    final pending = [
      for (var i = 0; i < 600; i++)
        PlannedEvent(
          date: start.add(Duration(days: i)),
          type: EventType.pageMilestone,
          targetPage: i + 1,
        ),
    ];
    final excluded = pending[550].date;

    final result = shiftPendingEventsForward(
      pending,
      excludedDates: {excluded},
    );

    DateTime dayOf(DateTime value) =>
        DateTime(value.year, value.month, value.day);
    expect(result.events[549].date, dayOf(pending[549].date));
    expect(
      result.events[550].date,
      dayOf(pending[550].date).add(const Duration(days: 1)),
    );
    expect(
      result.events.last.date,
      dayOf(pending.last.date).add(const Duration(days: 1)),
    );
    expect(result.events.last.date.year, 2027);
  });

  test('replan shifting never duplicates a day at the autumn DST change', () {
    final pending = [
      for (var i = 0; i < 15; i++)
        PlannedEvent(
          date: DateTime(2026, 10, 20 + i),
          type: EventType.pageMilestone,
          targetPage: i + 1,
        ),
    ];

    final result = shiftPendingEventsForward(
      pending,
      excludedDates: {DateTime(2026, 10, 23)},
    );
    final dayKeys = result.events.map(
      (e) => '${e.date.year}-${e.date.month}-${e.date.day}',
    );

    expect(dayKeys.toSet().length, result.events.length);
  });

  test('deadline replan exclusion never stacks events on the end day', () {
    final result = redistributePending(
      ReplanInputs(
        mode: PlanMode.deadline,
        unit: PlanUnit.pages,
        anchorDate: d(1),
        startUnit: 0,
        total: 100,
        endDate: d(4),
        pendingTargets: const [25, 50, 75],
        excludedDates: {d(2)},
      ),
    );

    expect(result.events.map((e) => e.date).toList(), [
      d(1),
      d(3),
      d(4),
      d(5),
    ]);
    expect(result.events.map((e) => e.date).toSet().length, 4);
  });

  test(
    'short deadline replan extends instead of duplicating the final day',
    () {
      final result = redistributePending(
        ReplanInputs(
          mode: PlanMode.deadline,
          unit: PlanUnit.pages,
          anchorDate: d(1),
          startUnit: 0,
          total: 100,
          endDate: d(2),
          pendingTargets: const [20, 40, 60, 80],
        ),
      );

      expect(result.events.length, 5);
      expect(result.events.map((e) => e.date).toSet().length, 5);
      expect(result.events.last.date, d(5));
    },
  );
}
