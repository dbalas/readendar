import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/notifications/notification_payload.dart';

void main() {
  group('stable platform notification ids', () {
    test('event id has a fixed cross-run vector', () {
      expect(eventNotificationId('user-1', 'evt-9'), 1770996909);
    });

    test('daily quote id has a fixed cross-run vector', () {
      expect(
        dailyQuoteNotificationId('user-1', '2026-07-16'),
        156827534,
      );
    });

    test('namespaces separate otherwise identical components', () {
      expect(
        stableNotificationId('event', ['u', 'e']),
        isNot(stableNotificationId('daily-quote', ['u', 'e'])),
      );
    });
  });

  group('buildNotifPayload / parse round-trip', () {
    test('build then parse yields the same owner + event', () {
      final p = buildNotifPayload('user-1', 'evt-9');
      expect(p, 'owner:user-1|event:evt-9');
      expect(ownerIdFromNotifPayload(p), 'user-1');
      expect(eventIdFromNotifPayload(p), 'evt-9');
    });

    test('segment order does not matter', () {
      const p = 'event:evt-7|owner:user-2';
      expect(eventIdFromNotifPayload(p), 'evt-7');
      expect(ownerIdFromNotifPayload(p), 'user-2');
    });

    test('legacy bare owner payload has no event segment', () {
      expect(eventIdFromNotifPayload('owner:user-1'), isNull);
      expect(ownerIdFromNotifPayload('owner:user-1'), 'user-1');
    });

    test('null / empty / empty-segment are null', () {
      expect(eventIdFromNotifPayload(null), isNull);
      expect(eventIdFromNotifPayload(''), isNull);
      expect(eventIdFromNotifPayload('owner:u|event:'), isNull);
    });
  });

  group('payloadBelongsToOwner (logout scoping)', () {
    test('matches current and legacy formats for the owner', () {
      expect(
        payloadBelongsToOwner('owner:u1|event:e1', 'u1'),
        isTrue,
      );
      expect(payloadBelongsToOwner('owner:u1', 'u1'), isTrue);
    });

    test('does not match a different owner or a prefix collision', () {
      expect(payloadBelongsToOwner('owner:u1|event:e1', 'u2'), isFalse);
      // "u1" must not match "u10" via startsWith.
      expect(payloadBelongsToOwner('owner:u10|event:e1', 'u1'), isFalse);
      expect(payloadBelongsToOwner(null, 'u1'), isFalse);
    });
  });

  group('Reading Chapter payloads', () {
    test('round-trips owner-scoped hub, monthly, and yearly routes', () {
      for (final route in const [
        '/reading-chapters',
        '/reading-chapters/month/2026-07',
        '/reading-chapters/year/2025',
      ]) {
        final payload = buildReadingChapterNotifPayload('user-1', route);
        expect(readingChapterRouteFromNotifPayload(payload), route);
        expect(readingChapterOwnerIdFromNotifPayload(payload), 'user-1');
      }
    });

    test('rejects ownerless, malformed, and unrelated routes', () {
      for (final payload in <String?>[
        null,
        '/reading-chapters',
        'owner:user-1|chapter:/reading-chapters/month/2026-7',
        'owner:user-1|chapter:/reading-chapters/month/2026-13',
        'owner:user-1|chapter:/reading-chapters/year/2026-07',
        'owner:user-1|chapter:/reading-chapters/year/0000',
        'owner:user-1|chapter:/reading-chapters/month/9999-01',
        'owner:user-1|chapter:/not-a-chapter',
      ]) {
        expect(readingChapterRouteFromNotifPayload(payload), isNull);
      }
    });
  });
}
