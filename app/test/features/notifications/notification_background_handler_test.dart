import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/notifications/notification_background_handler.dart';

void main() {
  test('exact capability selects exact allow-while-idle scheduling', () {
    expect(
      androidScheduleModeForExactCapability(canExact: true),
      AndroidScheduleMode.exactAllowWhileIdle,
    );
  });

  test('missing exact capability falls back to inexact allow-while-idle', () {
    expect(
      androidScheduleModeForExactCapability(canExact: false),
      AndroidScheduleMode.inexactAllowWhileIdle,
    );
  });
}
