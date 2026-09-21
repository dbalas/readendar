import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_content.dart';
import 'package:timezone/data/latest.dart' as tzdata;

ReadingEvent _event({
  String status = EventStatus.active,
  bool reminderEnabled = true,
  int? reminderMinutesBefore = 30,
  String? timeLocal = '18:00',
  String? tz = 'Europe/Madrid',
  String? bookId,
  DateTime? dateLocal,
}) => ReadingEvent(
  id: 'e1',
  ownerType: OwnerType.user,
  ownerId: 'u1',
  type: 'chapterMilestone',
  title: 'Chapter 5',
  dateLocal: dateLocal ?? DateTime.utc(2026, 6, 10),
  status: status,
  bookId: bookId,
  timeLocal: timeLocal,
  tz: tz,
  reminderEnabled: reminderEnabled,
  reminderMinutesBefore: reminderMinutesBefore,
);

void main() {
  setUpAll(tzdata.initializeTimeZones);

  final svc = LocalNotifications.I;

  const content = NotificationContent(
    title: 'Chapter 5',
    body: 'Pedro Páramo',
  );

  test('computes fire time and echoes the supplied content', () {
    final r = svc.plannedReminderFor(_event(), content: content);
    expect(r, isNotNull);
    expect(r!.title, 'Chapter 5');
    expect(r.body, 'Pedro Páramo');
    // 18:00 Madrid minus 30 min reminder = 17:30 local.
    expect(r.fireAt.hour, 17);
    expect(r.fireAt.minute, 30);
  });

  test('body is null when the content has none', () {
    final r = svc.plannedReminderFor(
      _event(),
      content: const NotificationContent(title: 'Chapter 5'),
    );
    expect(r!.body, isNull);
  });

  test('returns null when the reminder is disabled', () {
    expect(
      svc.plannedReminderFor(_event(reminderEnabled: false), content: content),
      isNull,
    );
  });

  test('returns null with no reminder offset', () {
    expect(
      svc.plannedReminderFor(
        _event(reminderMinutesBefore: null),
        content: content,
      ),
      isNull,
    );
  });

  test('returns null for a completed event', () {
    expect(
      svc.plannedReminderFor(
        _event(status: EventStatus.completed),
        content: content,
      ),
      isNull,
    );
  });

  test('all-day event fires at the configured hour', () {
    final r = svc.plannedReminderFor(
      _event(timeLocal: null, reminderMinutesBefore: 0),
      content: content,
    );
    expect(r!.fireAt.hour, 9);
    expect(r.fireAt.minute, 0);
  });

  test('permission preflight accepts an enabled future reminder', () {
    final future = DateTime.now().toUtc().add(const Duration(days: 7));
    expect(
      svc.canScheduleEventReminder(
        _event(dateLocal: DateTime.utc(future.year, future.month, future.day)),
        viewerTz: 'Europe/Madrid',
      ),
      isTrue,
    );
  });

  test('permission preflight rejects an already-past reminder', () {
    expect(
      svc.canScheduleEventReminder(
        _event(dateLocal: DateTime.utc(2020)),
        viewerTz: 'Europe/Madrid',
      ),
      isFalse,
    );
  });

  test('today event with 1440 min offset cannot schedule', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(
      svc.canScheduleEventReminder(
        _event(
          dateLocal: today,
          reminderMinutesBefore: 1440,
        ),
        viewerTz: 'Europe/Madrid',
      ),
      isFalse,
    );
  });

  test('legacy duplicate id is removed while the stable event id is kept', () {
    const stableId = 101;
    const expected = {'e1': stableId};

    expect(
      shouldKeepPendingEventReminder(
        notificationId: stableId,
        eventId: 'e1',
        expectedIdsByEventId: expected,
      ),
      isTrue,
    );
    expect(
      shouldKeepPendingEventReminder(
        notificationId: 202,
        eventId: 'e1',
        expectedIdsByEventId: expected,
      ),
      isFalse,
    );
  });

  test('only delivered notifications for live events are retained', () {
    expect(
      shouldKeepActiveEventReminder(
        eventId: 'e1',
        retainedEventIds: const {'e1'},
      ),
      isTrue,
    );
    expect(
      shouldKeepActiveEventReminder(
        eventId: 'deleted',
        retainedEventIds: const {'e1'},
      ),
      isFalse,
    );
  });

  test('orphan metadata is pruned when active notifications are queryable', () {
    expect(
      shouldKeepEventNotificationMetadata(
        notificationId: 101,
        eventId: 'e1',
        keptPlatformIds: const {},
        retainedEventIds: const {'e1'},
        activeNotificationsAvailable: true,
      ),
      isFalse,
    );
    expect(
      shouldKeepEventNotificationMetadata(
        notificationId: 101,
        eventId: 'e1',
        keptPlatformIds: const {},
        retainedEventIds: const {'e1'},
        activeNotificationsAvailable: false,
      ),
      isTrue,
    );
  });
}
