import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/app_timezone.dart';

void main() {
  test('converts instants with the shared IANA database', () {
    final madrid = inAppTimeZone(
      DateTime.parse('2026-07-19T22:30:00Z'),
      'Europe/Madrid',
    );

    expect(madrid.year, 2026);
    expect(madrid.month, 7);
    expect(madrid.day, 20);
    expect(madrid.hour, 0);
    expect(appTimeZoneNames(), contains('Europe/Madrid'));
  });

  test('sameCivilDateInAppTimeZone compares viewer civil days', () {
    // 22:30 UTC 19 Jul = 00:30 Madrid 20 Jul.
    final lateUtc = DateTime.parse('2026-07-19T22:30:00Z');
    final nextMadridMorning = DateTime.parse('2026-07-20T08:00:00Z');
    final priorMadridDay = DateTime.parse('2026-07-19T10:00:00Z');

    expect(
      sameCivilDateInAppTimeZone(lateUtc, nextMadridMorning, 'Europe/Madrid'),
      isTrue,
    );
    expect(
      sameCivilDateInAppTimeZone(lateUtc, priorMadridDay, 'Europe/Madrid'),
      isFalse,
    );
  });

  test('resolves a source civil date in the account IANA timezone', () {
    final instant = civilDateStartInAppTimeZone(
      DateTime.utc(2026),
      'America/Los_Angeles',
    );

    expect(instant, DateTime.parse('2026-01-01T08:00:00Z'));
    expect(
      inAppTimeZone(instant, 'America/Los_Angeles').day,
      1,
    );
  });
}
