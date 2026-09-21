// Handles a notification ACTION tap. The same logic serves two callers:
//   • the background isolate (app killed / backgrounded) via the top-level
//     [notificationBackgroundHandler] the plugin invokes;
//   • the live app, when the foreground `onDidReceiveNotificationResponse`
//     receives an action (see LocalNotifications._onTap).
//
// Background isolate constraints: no Riverpod, no Dio, no secure storage — only
// SharedPreferences and the notification plugin. So:
//   • Complete → ENQUEUE (PendingActionsStore); the app completes it via the API
//     on next foreground (pending_action_drainer.dart).
//   • Snooze   → re-schedule the reminder in place from the stored NotifMeta.

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:readendar/features/notifications/notification_payload.dart';
import 'package:readendar/features/notifications/notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// The plugin's background-isolate entry point. Must be a top-level function
/// annotated `@pragma('vm:entry-point')` so it survives tree-shaking and can be
/// invoked from a fresh isolate.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(
  NotificationResponse response,
) async {
  // The isolate is fresh: register plugins so SharedPreferences + the
  // notification channel work here.
  DartPluginRegistrant.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings(kNotifSmallIcon),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await handleNotificationAction(response, prefs, plugin);
}

/// Applies a background-style action (complete / snooze). Plain taps are
/// ignored here. [plugin] is the
/// isolate's own instance in the background case, or the app's live instance in
/// the foreground case.
Future<void> handleNotificationAction(
  NotificationResponse response,
  SharedPreferences prefs,
  FlutterLocalNotificationsPlugin plugin,
) async {
  switch (response.actionId) {
    case kActionComplete:
      await _enqueueComplete(response, prefs);
    case kActionSnooze1h:
      await _reschedule(response, prefs, plugin, tonight: false);
    case kActionSnoozeTonight:
      await _reschedule(response, prefs, plugin, tonight: true);
    default:
      break;
  }
}

Future<void> _enqueueComplete(
  NotificationResponse response,
  SharedPreferences prefs,
) async {
  final owner = ownerIdFromNotifPayload(response.payload);
  final eventId = eventIdFromNotifPayload(response.payload);
  if (owner == null || eventId == null) return;
  await PendingActionsStore.enqueue(
    prefs,
    PendingAction(
      action: kActionComplete,
      ownerUserId: owner,
      eventId: eventId,
      ts: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  // The event is done — its meta is no longer needed (and its notification was
  // dismissed by `cancelNotification: true`).
  final id = response.id;
  if (id != null) await NotifMetaStore.remove(prefs, id);
}

Future<void> _reschedule(
  NotificationResponse response,
  SharedPreferences prefs,
  FlutterLocalNotificationsPlugin plugin, {
  required bool tonight,
}) async {
  final notifId = response.id;
  if (notifId == null) return;
  final meta = NotifMetaStore.read(prefs, notifId);
  // Without the stored content we can't rebuild the reminder; the tapped one was
  // already dismissed, so there's nothing more to do.
  if (meta == null) return;

  initializeAppTimeZones();
  // +1h is an absolute instant (correct even if `tz.local` is UTC in this fresh
  // isolate); "tonight" needs the reminder's wall-clock zone, which the
  // scheduler persists as a concrete IANA name in meta.tz (see
  // LocalNotifications._reminderTzName).
  final loc = locationOrLocal(meta.tz);
  final fireAt = tonight
      ? _tonightAt20(loc)
      : tz.TZDateTime.now(loc).add(const Duration(hours: 1));

  // Reuse the same id so a second snooze replaces the first; meta stays valid
  // (same content), so the snoozed reminder can itself be snoozed again. Match
  // the foreground scheduler: exact when the OS allows it (so the snoozed
  // reminder fires on time even in Doze), falling back to inexact when the
  // exact-alarm permission is revoked (which would otherwise throw).
  await plugin.zonedSchedule(
    id: notifId,
    title: meta.title,
    body: meta.body,
    scheduledDate: fireAt,
    notificationDetails: buildReminderDetails(
      channelName: meta.channelName,
      channelDescription: meta.channelDescription,
      categoryId: meta.categoryId,
      actions: meta.androidActions,
    ),
    androidScheduleMode: await resolveAndroidScheduleMode(plugin),
    payload: meta.payload,
  );
}

/// The Android alarm mode to use: exact after the user grants alarm scheduling,
/// else inexact so an absent or revoked permission degrades gracefully instead
/// of throwing. Non-Android
/// platforms ignore the mode. Shared by the foreground scheduler and the
/// background snooze so both behave identically.
Future<AndroidScheduleMode> resolveAndroidScheduleMode(
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return AndroidScheduleMode.exactAllowWhileIdle;
  }
  try {
    final impl = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canExact = await impl?.canScheduleExactNotifications() ?? false;
    return androidScheduleModeForExactCapability(canExact: canExact);
  } on Object catch (error, stackTrace) {
    // A vendor/plugin failure while querying special access must not prevent
    // the alarm from being armed at all. Inexact + allow-while-idle is less
    // precise, but it is a valid, durable fallback.
    debugPrint(
      'Exact-alarm capability check failed; scheduling inexactly: '
      '$error\n$stackTrace',
    );
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }
}

/// Pure capability-to-mode mapping kept separate from the platform query so
/// exact access remains an explicit user choice while scheduling always has a
/// tested inexact fallback.
AndroidScheduleMode androidScheduleModeForExactCapability({
  required bool canExact,
}) => canExact
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle;

/// The next 20:00 in [loc]: today if it's still upcoming, otherwise tomorrow.
tz.TZDateTime _tonightAt20(tz.Location loc) {
  final now = tz.TZDateTime.now(loc);
  final today = tz.TZDateTime(loc, now.year, now.month, now.day, 20);
  if (today.isAfter(now)) return today;
  final tomorrow = now.add(const Duration(days: 1));
  return tz.TZDateTime(loc, tomorrow.year, tomorrow.month, tomorrow.day, 20);
}
