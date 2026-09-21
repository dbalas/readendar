import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';
import 'package:readendar/features/plan/domain/replan.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

Book _book({int? chapterCount, int? pageCount}) => Book(
  id: 'b1',
  ownerType: 'user',
  ownerId: 'u1',
  title: 'T',
  authors: const ['A'],
  status: 'reading',
  chapterCount: chapterCount,
  pageCount: pageCount,
);

ReadingEvent _ev({
  required String type,
  required DateTime date,
  required String status,
  int? chapter,
  int? page,
  String planId = 'p1',
}) => ReadingEvent(
  id: 'e-${date.millisecondsSinceEpoch}-$type',
  ownerType: 'user',
  ownerId: 'u1',
  bookId: 'b1',
  type: type,
  title: type,
  dateLocal: date,
  status: status,
  targetChapter: chapter,
  targetPage: page,
  planId: planId,
);

void main() {
  test('plan run decodes the exact saved wizard options', () {
    final run = PlanRun.fromJson({
      'id': 'p1',
      'bookId': 'b1',
      'eventCount': 3,
      'mode': 'deadline',
      'unit': 'pages',
      'startDate': '2026-08-14',
      'endDate': '2026-08-30',
      'total': 300,
      'startUnit': 80,
      'excludedWeekdays': [6, 7],
      'remindersOn': false,
      'includeStart': true,
      'includeFinish': false,
      'anchorEventId': 'event-1',
      'anchorEventTitle': 'Deadline',
      'createdAt': '2026-08-12T10:00:00Z',
    });

    expect(run.startUnit, 80);
    expect(run.excludedWeekdays, {6, 7});
    expect(run.remindersOn, isFalse);
    expect(run.includeStart, isTrue);
    expect(run.includeFinish, isFalse);
    expect(run.anchorEventId, 'event-1');
    expect(run.anchorEventTitle, 'Deadline');
  });

  test('preview prioritizes milestones over same-day bookends', () {
    expect(
      planPreviewTypePriority(EventType.chapterMilestone),
      lessThan(planPreviewTypePriority(EventType.start)),
    );
    expect(
      planPreviewTypePriority(EventType.pageMilestone),
      lessThan(planPreviewTypePriority(EventType.finish)),
    );
    expect(
      planPreviewTypePriority(EventType.pageMilestone),
      lessThan(planPreviewTypePriority(EventType.deadline)),
    );
  });

  test('coalesces page and chapter milestones on the same civil day', () {
    final events = coalesceMilestonesPerCivilDay([
      PlannedEvent(
        date: d(2024, 1, 1),
        type: EventType.pageMilestone,
        targetPage: 50,
      ),
      PlannedEvent(
        date: d(2024, 1, 1),
        type: EventType.chapterMilestone,
        targetChapter: 4,
      ),
    ]);

    expect(events, hasLength(1));
    expect(events.single.type, EventType.chapterMilestone);
  });

  group('redistributePending — pace', () {
    test('keeps only the furthest milestone when pace maps two to one day', () {
      final r = redistributePending(
        ReplanInputs(
          mode: PlanMode.pace,
          unit: PlanUnit.chapters,
          anchorDate: d(2024, 1, 1),
          startUnit: 0,
          total: 10,
          perDay: 5,
          pendingTargets: const [2, 4, 8],
        ),
      );

      final milestones = r.events
          .where((event) => event.type == EventType.chapterMilestone)
          .toList();
      expect(milestones, hasLength(2));
      expect(milestones[0].date, d(2024, 1, 1));
      expect(milestones[0].targetChapter, 4);
      expect(milestones[1].date, d(2024, 1, 2));
      expect(milestones[1].targetChapter, 8);
    });

    test('no exclusions reproduces the canonical pace dates, deleted targets '
        'left as gaps (never revived)', () {
      // start Mon 2024-01-01, 2 ch/day, total 10. Canonical milestone days:
      // Jan1→2, Jan2→4, Jan3→6, Jan4→8, Jan5→finish(10).
      // The ch6 (Jan3) milestone was deleted upstream: pending = [2,4,8].
      final r = redistributePending(
        ReplanInputs(
          mode: PlanMode.pace,
          unit: PlanUnit.chapters,
          anchorDate: d(2024, 1, 1),
          startUnit: 0,
          total: 10,
          perDay: 2,
          pendingTargets: const [2, 4, 8],
        ),
      );

      expect(r.isOk, isTrue);
      // 3 milestones + finish.
      expect(r.events.length, 4);
      expect(r.events[0].targetChapter, 2);
      expect(r.events[0].date, d(2024, 1, 1));
      expect(r.events[1].targetChapter, 4);
      expect(r.events[1].date, d(2024, 1, 2));
      expect(r.events[2].targetChapter, 8);
      expect(r.events[2].date, d(2024, 1, 4)); // Jan3 gap where ch6 was deleted
      expect(r.events[3].type, EventType.finish);
      expect(r.events[3].date, d(2024, 1, 5));
      // No resurrected ch6.
      expect(r.events.any((e) => e.targetChapter == 6), isFalse);
    });

    test('removing a reading day shifts the later pending milestones later', () {
      // Same plan, but the user removes Jan2 in the review. Reading days become
      // Jan1, Jan3, Jan4, Jan5, Jan6. ch4 (day index 1) → Jan3, ch8 (index 3) →
      // Jan5, finish(index 4) → Jan6.
      final r = redistributePending(
        ReplanInputs(
          mode: PlanMode.pace,
          unit: PlanUnit.chapters,
          anchorDate: d(2024, 1, 1),
          startUnit: 0,
          total: 10,
          perDay: 2,
          pendingTargets: const [2, 4, 8],
          excludedDates: {d(2024, 1, 2)},
        ),
      );

      expect(r.events[0].date, d(2024, 1, 1)); // ch2 unaffected
      expect(r.events[1].date, d(2024, 1, 3)); // ch4 shifted off Jan2
      expect(r.events[2].date, d(2024, 1, 5)); // ch8
      expect(r.events[3].date, d(2024, 1, 6)); // finish
    });

    test('honours a completed anchor: pending tail starts after it', () {
      // ch2 + ch4 already completed (anchor at unit 4, anchored on Jan3). The
      // tail re-spaces from there.
      final r = redistributePending(
        ReplanInputs(
          mode: PlanMode.pace,
          unit: PlanUnit.chapters,
          anchorDate: d(2024, 1, 3),
          startUnit: 4,
          total: 10,
          perDay: 2,
          pendingTargets: const [6, 8],
        ),
      );
      expect(r.events[0].targetChapter, 6);
      expect(r.events[0].date, d(2024, 1, 3));
      expect(r.events[1].targetChapter, 8);
      expect(r.events[1].date, d(2024, 1, 4));
      expect(r.events[2].type, EventType.finish);
      expect(r.events[2].date, d(2024, 1, 5));
    });
  });

  group('redistributePending — deadline', () {
    test(
      'spreads the live milestones evenly, capstone on the last reading day',
      () {
        // start Jan1, deadline Jan11 (11 reading days, no weekday exclusions).
        // 3 live milestones + deadline capstone → 4 positions over 11 days.
        final r = redistributePending(
          ReplanInputs(
            mode: PlanMode.deadline,
            unit: PlanUnit.pages,
            anchorDate: d(2024, 1, 1),
            startUnit: 0,
            total: 100,
            endDate: d(2024, 1, 11),
            pendingTargets: const [25, 50, 75],
          ),
        );

        expect(r.isOk, isTrue);
        expect(r.events.length, 4);
        // strictly increasing dates.
        for (var i = 1; i < r.events.length; i++) {
          expect(r.events[i].date.isAfter(r.events[i - 1].date), isTrue);
        }
        // capstone lands on the deadline (last reading day).
        expect(r.events.last.type, EventType.finish);
        expect(r.events.last.date, d(2024, 1, 11));
        expect(
          r.events.first.date.isAfter(d(2024, 1, 1)) ||
              r.events.first.date == d(2024, 1, 1),
          isTrue,
        );
      },
    );
  });

  group('redistributePending — edge cases', () {
    test('empty pending with finish yields just the capstone', () {
      final r = redistributePending(
        ReplanInputs(
          mode: PlanMode.pace,
          unit: PlanUnit.chapters,
          anchorDate: d(2024, 1, 1),
          startUnit: 8,
          total: 10,
          perDay: 2,
          pendingTargets: const [],
        ),
      );
      expect(r.events.length, 1);
      expect(r.events.single.type, EventType.finish);
    });

    test('all weekdays excluded is a noReadingDays issue', () {
      final r = redistributePending(
        ReplanInputs(
          mode: PlanMode.pace,
          unit: PlanUnit.chapters,
          anchorDate: d(2024, 1, 1),
          startUnit: 0,
          total: 10,
          perDay: 2,
          pendingTargets: const [2, 4],
          excludedWeekdays: {1, 2, 3, 4, 5, 6, 7},
        ),
      );
      expect(r.isOk, isFalse);
      expect(r.issue, PlanIssue.noReadingDays);
    });
  });

  group('buildReplanState', () {
    test(
      'splits completed anchors from pending, seeds tail after the anchor',
      () {
        // ch2 done; ch4/ch6 pending; finish pending. perDay from run = 2.
        final events = [
          _ev(
            type: 'chapter_milestone',
            date: d(2024, 1, 1),
            status: 'completed',
            chapter: 2,
          ),
          _ev(
            type: 'chapter_milestone',
            date: d(2024, 1, 2),
            status: 'active',
            chapter: 4,
          ),
          _ev(
            type: 'chapter_milestone',
            date: d(2024, 1, 3),
            status: 'active',
            chapter: 6,
          ),
          _ev(type: 'finish', date: d(2024, 1, 4), status: 'active'),
        ];
        final run = PlanRun(
          id: 'p1',
          bookId: 'b1',
          eventCount: 4,
          mode: 'pace',
          unit: 'chapters',
          perDay: 2,
          startDate: d(2024, 1, 1),
          endDate: d(2024, 1, 4),
          total: 8,
          createdAt: d(2024, 1, 1),
        );
        final s = buildReplanState(
          events,
          run: run,
          book: _book(chapterCount: 8),
          now: d(2024, 1, 1),
        );

        expect(s, isNotNull);
        expect(s!.completed.length, 1);
        expect(s.pending.length, 3);
        expect(s.inputs.startUnit, 2); // last completed target
        expect(s.inputs.anchorDate, d(2024, 1, 2)); // day after completed
        expect(s.inputs.pendingTargets, [4, 6]);
        expect(s.inputs.includeFinish, isTrue);
        expect(s.inputs.total, 8);
        expect(s.inputs.mode, PlanMode.pace);
        expect(s.inputs.perDay, 2);
      },
    );

    test('orphan plan (no run) infers mode/unit/pace from the events', () {
      final events = [
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 1),
          status: 'active',
          chapter: 3,
        ),
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 2),
          status: 'active',
          chapter: 6,
        ),
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 3),
          status: 'active',
          chapter: 9,
        ),
      ];
      final s = buildReplanState(
        events,
        book: _book(chapterCount: 12),
        now: d(2024, 1, 1),
      );

      expect(s, isNotNull);
      expect(s!.inputs.mode, PlanMode.pace);
      expect(s.inputs.unit, PlanUnit.chapters);
      expect(s.inputs.perDay, 3); // inferred gap
      expect(s.inputs.total, 12);
      expect(s.inputs.pendingTargets, [3, 6, 9]);
    });

    test('returns null when nothing is pending', () {
      final events = [
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 1),
          status: 'completed',
          chapter: 2,
        ),
        _ev(type: 'finish', date: d(2024, 1, 2), status: 'completed'),
      ];
      final s = buildReplanState(
        events,
        book: _book(chapterCount: 2),
        now: d(2024, 1, 1),
      );
      expect(s, isNull);
    });

    test('locks every past event and only replans today and the future', () {
      final events = [
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 1),
          status: 'active',
          chapter: 2,
        ),
        _ev(
          type: 'deadline',
          date: d(2024, 1, 2),
          status: 'completed',
        ),
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 3),
          status: 'active',
          chapter: 4,
        ),
        _ev(
          type: 'finish',
          date: d(2024, 1, 4),
          status: 'active',
        ),
      ];

      final s = buildReplanState(
        events,
        book: _book(chapterCount: 8),
        now: d(2024, 1, 3),
      );

      expect(s, isNotNull);
      expect(
        s!.lockedEvents.map((event) => event.dateLocal),
        [d(2024, 1, 1), d(2024, 1, 2)],
      );
      expect(
        s.pending.map((event) => event.dateLocal),
        [d(2024, 1, 3), d(2024, 1, 4)],
      );
      expect(s.completedCapstones, isEmpty);
      expect(s.inputs.anchorDate, d(2024, 1, 3));
      expect(s.inputs.pendingTargets, [4]);
    });

    test(
      'locks a start event dated today while replanning the future tail',
      () {
        final events = [
          _ev(
            type: 'start',
            date: d(2024, 1, 3),
            status: 'active',
          ),
          _ev(
            type: 'chapter_milestone',
            date: d(2024, 1, 4),
            status: 'active',
            chapter: 2,
          ),
          _ev(
            type: 'finish',
            date: d(2024, 1, 5),
            status: 'active',
          ),
        ];

        final s = buildReplanState(
          events,
          book: _book(chapterCount: 4),
          now: DateTime(2024, 1, 3, 18),
        );

        expect(s, isNotNull);
        expect(s!.lockedEvents.map((event) => event.type), ['start']);
        expect(
          s.pending.map((event) => event.type),
          ['chapter_milestone', 'finish'],
        );
        expect(s.includeStart, isTrue);
        expect(s.inputs.anchorDate, d(2024, 1, 3));
      },
    );

    test('infers excluded weekdays from gaps in the live span', () {
      // Mon Wed Fri only across one week → Tue/Thu/Sat/Sun excluded.
      final events = [
        _ev(type: 'start', date: d(2024, 1, 1), status: 'active'), // Mon
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 3),
          status: 'active',
          chapter: 2,
        ), // Wed
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 5),
          status: 'active',
          chapter: 4,
        ), // Fri
        _ev(type: 'finish', date: d(2024, 1, 5), status: 'active'),
      ];
      final s = buildReplanState(
        events,
        book: _book(chapterCount: 4),
        now: DateTime(2023, 12, 31),
      );
      expect(s, isNotNull);
      expect(
        s!.inputs.excludedWeekdays,
        {
          DateTime.tuesday,
          DateTime.thursday,
          DateTime.saturday,
          DateTime.sunday,
        },
      );
    });

    test('skips weekday inference for sparse deadline-like spans', () {
      // Three milestones over a month — gaps are spacing, not off-days.
      final events = [
        _ev(type: 'start', date: d(2024, 1, 1), status: 'active'),
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 15),
          status: 'active',
          chapter: 2,
        ),
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 30),
          status: 'active',
          chapter: 4,
        ),
        _ev(type: 'deadline', date: d(2024, 1, 30), status: 'active'),
      ];
      final s = buildReplanState(
        events,
        book: _book(chapterCount: 4),
        now: DateTime(2023, 12, 31),
      );
      expect(s, isNotNull);
      expect(s!.inputs.excludedWeekdays, isEmpty);
    });

    test('before_event run mode is restored with endDate', () {
      final events = [
        _ev(
          type: 'chapter_milestone',
          date: d(2024, 1, 2),
          status: 'active',
          chapter: 4,
        ),
        _ev(type: 'deadline', date: d(2024, 1, 10), status: 'active'),
      ];
      final run = PlanRun(
        id: 'p1',
        bookId: 'b1',
        eventCount: 2,
        mode: 'before_event',
        unit: 'chapters',
        startDate: d(2024, 1, 1),
        endDate: d(2024, 1, 10),
        total: 8,
        createdAt: d(2024, 1, 1),
      );
      final s = buildReplanState(
        events,
        run: run,
        book: _book(chapterCount: 8),
        now: d(2024, 1, 1),
      );
      expect(s, isNotNull);
      expect(s!.inputs.mode, PlanMode.beforeEvent);
      expect(s.inputs.endDate, d(2024, 1, 10));
      expect(PlanMode.beforeEvent.wireName, 'before_event');
    });

    test('restores saved start option separately from completed anchor', () {
      final run = PlanRun(
        id: 'p1',
        bookId: 'b1',
        eventCount: 3,
        mode: 'pace',
        unit: 'chapters',
        perDay: 2,
        startDate: d(2024, 1, 2),
        total: 10,
        createdAt: d(2024, 1, 1),
      );
      final s = buildReplanState(
        [
          _ev(
            type: 'chapter_milestone',
            date: d(2024, 1, 4),
            status: 'completed',
            chapter: 4,
          ),
          _ev(
            type: 'chapter_milestone',
            date: d(2024, 1, 6),
            status: 'active',
            chapter: 6,
          ),
          _ev(type: 'finish', date: d(2024, 1, 8), status: 'active'),
        ],
        run: run,
        book: _book(chapterCount: 10),
        now: d(2024, 1, 5),
      );

      expect(s, isNotNull);
      expect(s!.inputs.anchorDate, d(2024, 1, 5));
      expect(s.inputs.configuredStartDate, d(2024, 1, 2));
    });
  });

  group('PlanMode wire', () {
    test('round-trips before_event', () {
      expect(PlanMode.fromWire('before_event'), PlanMode.beforeEvent);
      expect(PlanMode.beforeEvent.isDeadlineLike, isTrue);
      expect(PlanMode.deadline.isDeadlineLike, isTrue);
      expect(PlanMode.pace.isDeadlineLike, isFalse);
    });
  });
}
