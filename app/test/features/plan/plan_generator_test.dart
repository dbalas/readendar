import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/features/plan/domain/plan_generator.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';

void main() {
  final start = DateTime(2026, 6, 8); // a Monday

  List<PlannedEvent> milestones(PlanResult r) => r.events
      .where((e) =>
          e.type == EventType.pageMilestone ||
          e.type == EventType.chapterMilestone)
      .toList();

  group('pace mode', () {
    test('even division: start + milestones + finish', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 200,
        perDay: 20,
      ));
      expect(r.isOk, isTrue);
      // 10 reading days → start + 9 milestones + finish = 11 events.
      expect(r.events.length, 11);
      expect(r.events.first.type, EventType.start);
      expect(r.events.last.type, EventType.finish);
      final ms = milestones(r);
      expect(ms.length, 9);
      expect(ms.map((m) => m.targetPage).toList(),
          [20, 40, 60, 80, 100, 120, 140, 160, 180]);
      // Finish lands on the 10th reading day (consecutive from start).
      expect(r.events.last.date, start.add(const Duration(days: 9)));
    });

    test('uneven: leftover folds into the finish day', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 205,
        perDay: 20,
      ));
      // ceil(205/20) = 11 reading days.
      final ms = milestones(r);
      expect(ms.length, 10);
      expect(ms.last.targetPage, 200); // last milestone below total
      expect(r.events.last.type, EventType.finish);
      expect(r.totalUnits, 205);
    });

    test('starts from current progress', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 200,
        startUnit: 50,
        perDay: 30,
      ));
      // remaining 150 → ceil(150/30) = 5 days.
      final ms = milestones(r);
      expect(ms.first.targetPage, 80); // 50 + 30
      expect(ms.map((m) => m.targetPage).toList(), [80, 110, 140, 170]);
      expect(r.events.last.type, EventType.finish);
      expect(r.totalUnits, 150);
    });

    test('single day: start + finish, no milestones', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 10,
        perDay: 20,
      ));
      expect(r.events.length, 2);
      expect(r.events[0].type, EventType.start);
      expect(r.events[1].type, EventType.finish);
      expect(r.events[0].date, start);
      expect(r.events[1].date, start);
      expect(milestones(r), isEmpty);
    });

    test('chapters unit emits chapter milestones with targets >= 1', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.chapters,
        startDate: start,
        total: 12,
        perDay: 2,
      ));
      final ms = milestones(r);
      expect(ms.every((m) => m.type == EventType.chapterMilestone), isTrue);
      expect(ms.every((m) => m.targetChapter != null && m.targetChapter! >= 1),
          isTrue);
      expect(ms.every((m) => m.targetPage == null), isTrue);
      expect(ms.first.targetChapter, 2);
    });
  });

  group('deadline mode', () {
    test('even split across the window', () {
      final end = start.add(const Duration(days: 9)); // 10 days inclusive
      final r = generatePlan(PlanInputs(
        mode: PlanMode.deadline,
        unit: PlanUnit.pages,
        startDate: start,
        endDate: end,
        total: 100,
      ));
      expect(r.isOk, isTrue);
      expect(r.events.last.type, EventType.finish);
      expect(r.events.last.date, end); // finish/deadline sits on the deadline
      final ms = milestones(r);
      expect(ms.map((m) => m.targetPage).toList(),
          [10, 20, 30, 40, 50, 60, 70, 80, 90]);
    });

    test('beforeEvent uses the same deadline split and capstone', () {
      final end = start.add(const Duration(days: 9));
      final r = generatePlan(PlanInputs(
        mode: PlanMode.beforeEvent,
        unit: PlanUnit.pages,
        startDate: start,
        endDate: end,
        total: 100,
        anchorEventId: 'ev-1',
        anchorEventTitle: 'Fecha límite',
      ));
      expect(r.isOk, isTrue);
      expect(r.events.last.type, EventType.finish);
      expect(r.events.last.date, end);
      expect(PlanMode.beforeEvent.wireName, 'before_event');
      expect(PlanMode.beforeEvent.isDeadlineLike, isTrue);
    });

    test('remainder lands on the earliest days', () {
      final end = start.add(const Duration(days: 9)); // 10 days
      final r = generatePlan(PlanInputs(
        mode: PlanMode.deadline,
        unit: PlanUnit.pages,
        startDate: start,
        endDate: end,
        total: 103,
      ));
      final ms = milestones(r);
      // base 10, rem 3 → first three days read 11, cumulative 11,22,33,43,...
      expect(ms.map((m) => m.targetPage).take(4).toList(), [11, 22, 33, 43]);
    });

    test('more days than units: no duplicate milestones, deadline on last day',
        () {
      final end = start.add(const Duration(days: 9)); // 10 days
      final r = generatePlan(PlanInputs(
        mode: PlanMode.deadline,
        unit: PlanUnit.pages,
        startDate: start,
        endDate: end,
        total: 3,
      ));
      final ms = milestones(r);
      expect(ms.map((m) => m.targetPage).toList(), [1, 2]);
      expect(r.events.last.type, EventType.finish);
      expect(r.events.last.date, end);
    });
  });

  group('reading days', () {
    test('long plans never duplicate a calendar day at the autumn DST change',
        () {
      final autumnStart = DateTime(2026, 10, 20);
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: autumnStart,
        total: 15,
        perDay: 1,
        includeStart: false,
      ));
      final dayKeys =
          r.events.map((e) => '${e.date.year}-${e.date.month}-${e.date.day}');

      expect(dayKeys.toSet().length, r.events.length);
      expect(r.events.last.date, DateTime(2026, 11, 3));
    });

    test('weekday exclusion keeps events off excluded days', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 100,
        perDay: 10,
        excludedWeekdays: {DateTime.saturday, DateTime.sunday},
      ));
      expect(r.isOk, isTrue);
      for (final e in r.events) {
        expect(e.date.weekday == DateTime.saturday, isFalse);
        expect(e.date.weekday == DateTime.sunday, isFalse);
      }
    });

    test('excluding a date (pace) pushes the end out, same event count', () {
      PlanInputs base() => PlanInputs(
            mode: PlanMode.pace,
            unit: PlanUnit.pages,
            startDate: start,
            total: 100,
            perDay: 10,
          );
      final before = generatePlan(base());
      final after = generatePlan(base().copyWith(
        excludedDates: {start.add(const Duration(days: 2))},
      ));
      expect(after.events.length, before.events.length);
      expect(after.endDate!.isAfter(before.endDate!), isTrue);
      // The excluded day carries no event.
      final excluded = start.add(const Duration(days: 2));
      expect(after.events.any((e) => e.date == excluded), isFalse);
    });

    test('excluding a date (deadline) pushes the event tail forward', () {
      final end = start.add(const Duration(days: 9));
      PlanInputs base() => PlanInputs(
            mode: PlanMode.deadline,
            unit: PlanUnit.pages,
            startDate: start,
            endDate: end,
            total: 100,
          );
      final before = generatePlan(base());
      final after = generatePlan(base().copyWith(
        excludedDates: {start.add(const Duration(days: 3))},
      ));
      expect(after.events.length, before.events.length);
      expect(after.perDay, before.perDay);
      expect(after.events[3].date, before.events[3].date);
      expect(after.events[4].date, start.add(const Duration(days: 4)));
      expect(after.events.last.date, end.add(const Duration(days: 1)));
    });
  });

  group('bookend structure', () {
    test('day 1 carries start + first milestone; last day is the finish only',
        () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 100,
        perDay: 10,
      ));
      final day1 = r.events.where((e) => e.date == start).toList();
      expect(day1.length, 2);
      expect(day1[0].type, EventType.start);
      expect(day1[1].type, EventType.pageMilestone);
      final lastDay =
          r.events.where((e) => e.date == r.events.last.date).toList();
      expect(lastDay.length, 1);
      expect(lastDay.single.type, EventType.finish);
    });
  });

  group('issues and caps', () {
    test('needs a total', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.chapters,
        startDate: start,
        perDay: 2,
      ));
      expect(r.issue, PlanIssue.needsTotal);
      expect(r.isEmpty, isTrue);
    });

    test('nothing to read when already past the total', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 100,
        startUnit: 100,
        perDay: 10,
      ));
      expect(r.issue, PlanIssue.nothingToRead);
    });

    test('invalid pace', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 100,
        perDay: 0,
      ));
      expect(r.issue, PlanIssue.invalidPace);
    });

    test('invalid range when deadline is before start or missing', () {
      final missing = generatePlan(PlanInputs(
        mode: PlanMode.deadline,
        unit: PlanUnit.pages,
        startDate: start,
        total: 100,
      ));
      expect(missing.issue, PlanIssue.invalidRange);
      final before = generatePlan(PlanInputs(
        mode: PlanMode.deadline,
        unit: PlanUnit.pages,
        startDate: start,
        endDate: start.subtract(const Duration(days: 1)),
        total: 100,
      ));
      expect(before.issue, PlanIssue.invalidRange);
    });

    test('no reading days when every weekday is excluded', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 100,
        perDay: 10,
        excludedWeekdays: {1, 2, 3, 4, 5, 6, 7},
      ));
      expect(r.issue, PlanIssue.noReadingDays);
    });

    test('over hard cap is blocked with an estimated count', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 10000,
        perDay: 1,
      ));
      expect(r.overHardCap, isTrue);
      expect(r.isEmpty, isTrue);
      expect(r.estimatedCount, greaterThan(planHardCap));
    });

    test('soft cap flags a large but allowed plan', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 300,
        perDay: 1,
      ));
      expect(r.isOk, isTrue);
      expect(r.overSoftCap, isTrue);
      expect(r.overHardCap, isFalse);
    });
  });

  group('bookend toggles', () {
    PlanInputs inputs({bool includeStart = true, bool includeFinish = true}) =>
        PlanInputs(
          mode: PlanMode.pace,
          unit: PlanUnit.pages,
          startDate: start,
          total: 200,
          perDay: 20,
          includeStart: includeStart,
          includeFinish: includeFinish,
        );

    test('removing the start drops only the start event', () {
      final r = generatePlan(inputs(includeStart: false));
      expect(r.events.any((e) => e.type == EventType.start), isFalse);
      expect(r.events.last.type, EventType.finish);
      // 9 milestones + finish = 10 (was 11 with the start).
      expect(r.events.length, 10);
    });

    test('removing the finish turns the last day into a final milestone', () {
      final r = generatePlan(inputs(includeFinish: false));
      expect(r.events.any((e) => e.type == EventType.finish), isFalse);
      expect(r.events.first.type, EventType.start);
      // The last day now carries a milestone reaching the total.
      final last = r.events.last;
      expect(last.type, EventType.pageMilestone);
      expect(last.targetPage, 200);
      expect(last.date, start.add(const Duration(days: 9)));
    });

    test('removing both leaves only milestones', () {
      final r =
          generatePlan(inputs(includeStart: false, includeFinish: false));
      expect(
        r.events.every((e) =>
            e.type == EventType.pageMilestone ||
            e.type == EventType.chapterMilestone),
        isTrue,
      );
      expect(milestones(r).last.targetPage, 200);
    });
  });

  group('derived figures', () {
    test('readingDays reflects pace-mode day count', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 200,
        perDay: 20,
      ));
      expect(r.readingDays, 10); // ceil(200/20)
    });

    test('readingDays reflects deadline-mode window', () {
      final r = generatePlan(PlanInputs(
        mode: PlanMode.deadline,
        unit: PlanUnit.pages,
        startDate: start,
        total: 100,
        endDate: start.add(const Duration(days: 9)), // 10 inclusive days
      ));
      expect(r.readingDays, 10);
    });

    test('isAggressivePace flags a demanding pace', () {
      final fast = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 2000,
        perDay: 200, // > planAggressivePagesPerDay (150)
      ));
      expect(fast.isAggressivePace(PlanUnit.pages), isTrue);

      final calm = generatePlan(PlanInputs(
        mode: PlanMode.pace,
        unit: PlanUnit.pages,
        startDate: start,
        total: 200,
        perDay: 20,
      ));
      expect(calm.isAggressivePace(PlanUnit.pages), isFalse);
    });
  });
}
