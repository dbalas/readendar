import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';

void main() {
  group('LocalNotifications.eventIdFromPayload', () {
    test('extracts the event id from the current payload format', () {
      expect(
        LocalNotifications.eventIdFromPayload('owner:user-1|event:evt-9'),
        'evt-9',
      );
    });

    test('returns null for a legacy owner-only payload', () {
      expect(LocalNotifications.eventIdFromPayload('owner:user-1'), isNull);
    });

    test('returns null for null / empty / malformed payloads', () {
      expect(LocalNotifications.eventIdFromPayload(null), isNull);
      expect(LocalNotifications.eventIdFromPayload(''), isNull);
      expect(LocalNotifications.eventIdFromPayload('owner:u|event:'), isNull);
    });

    test('is independent of segment order', () {
      expect(
        LocalNotifications.eventIdFromPayload('event:evt-7|owner:user-2'),
        'evt-7',
      );
    });
  });
}
