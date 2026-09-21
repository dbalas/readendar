import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/quotes/quote_daily_notification.dart';
import 'package:readendar/features/widget/quotes_widget_preview.dart';

void main() {
  group('quoteDailyNotificationId', () {
    test('is deterministic and non-negative', () {
      final day = DateTime(2026, 7, 2);
      final id1 = quoteDailyNotificationId('u1', day);
      final id2 = quoteDailyNotificationId('u1', DateTime(2026, 7, 2, 23));
      expect(id1, id2, reason: 'same user + calendar day → same slot');
      expect(id1, greaterThanOrEqualTo(0));
    });

    test('is namespaced per user and per day', () {
      final day = DateTime(2026, 7, 2);
      expect(
        quoteDailyNotificationId('u1', day),
        isNot(quoteDailyNotificationId('u2', day)),
      );
      expect(
        quoteDailyNotificationId('u1', day),
        isNot(quoteDailyNotificationId('u1', DateTime(2026, 7, 3))),
      );
    });
  });

  group('daily pick alignment', () {
    test('notification pick uses the same local-day bucket as the widget', () {
      // Two instants of the same local day agree; the next local day advances
      // by exactly one — the widget/notification "cita del día" contract.
      final morning = DateTime(2026, 7, 2, 9);
      final night = DateTime(2026, 7, 2, 23, 59);
      final tomorrow = DateTime(2026, 7, 3, 0, 1);
      expect(
        dailyRotationIndex(7, morning),
        dailyRotationIndex(7, night),
      );
      expect(
        dailyRotationIndex(7, tomorrow),
        (dailyRotationIndex(7, morning) + 1) % 7,
      );
    });
  });
}
