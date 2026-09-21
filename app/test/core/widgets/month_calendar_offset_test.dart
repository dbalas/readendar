import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/widgets/month_calendar.dart';

void main() {
  // 2026-06-01 is a Monday; 2026-02-01 is a Sunday.
  final monday = DateTime(2026, 6);
  final sunday = DateTime(2026, 2);
  final wednesday = DateTime(2026, 6, 3);

  group('leadingWeekdayOffset', () {
    test('Monday-first grid (firstDayOfWeekIndex = 1, e.g. es/de/nl)', () {
      expect(leadingWeekdayOffset(monday, 1), 0); // Mon in col 0
      expect(leadingWeekdayOffset(wednesday, 1), 2); // Wed in col 2
      expect(leadingWeekdayOffset(sunday, 1), 6); // Sun in col 6 (last)
    });

    test('Sunday-first grid (firstDayOfWeekIndex = 0, e.g. en-US/en-CA)', () {
      expect(leadingWeekdayOffset(sunday, 0), 0); // Sun in col 0
      expect(leadingWeekdayOffset(monday, 0), 1); // Mon in col 1
      expect(leadingWeekdayOffset(wednesday, 0), 3); // Wed in col 3
    });

    test('Saturday-first grid (firstDayOfWeekIndex = 6)', () {
      expect(leadingWeekdayOffset(DateTime(2026, 6, 6), 6), 0); // Sat in col 0
      expect(leadingWeekdayOffset(sunday, 6), 1); // Sun in col 1
    });

    test('offset is always in 0..6', () {
      for (var day = 1; day <= 7; day++) {
        for (var first = 0; first <= 6; first++) {
          final o = leadingWeekdayOffset(DateTime(2026, 6, day), first);
          expect(o, inInclusiveRange(0, 6));
        }
      }
    });
  });
}
