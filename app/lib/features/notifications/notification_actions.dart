// The action buttons a reading reminder carries, and how they map to event
// types. Buttons are baked into each notification at schedule time (Android
// attaches them per-notification; iOS references a pre-registered category), so
// the set is chosen up front from the event via [categoryForEvent].
//
// Layout is "action-first" and stays at two buttons so labels don't truncate:
//   • plan milestone (completable + planId)  → [Complete · Snooze 1h]
//   • completable with a book (no plan)       → [Complete · Snooze 1h]
//   • completable without a book              → [Complete · Snooze 1h]
//   • informational (start / finish / abandon)→ [Snooze 1h · Snooze tonight]
//
// All actions run WITHOUT opening the app (`foreground: false`). Every action
// dismisses its notification (`cancelNotification: true`). A plain body tap
// still opens the event.

import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart'
    show LocalNotifications;
import 'package:timezone/timezone.dart' as tz;

/// Android notification small-icon drawable. MUST be a white-on-transparent
/// silhouette (res/drawable/ic_stat_readendar.xml) — Android draws the small
/// icon from its alpha channel, so a full-colour `@mipmap/ic_launcher` renders
/// as a featureless blob. iOS ignores this and shows the app icon in colour.
const kNotifSmallIcon = 'ic_stat_readendar';

/// Brand periwinkle used to tint the Android small icon + app-name row.
const kNotifAccentColor = Color(0xFF7479D6);

// Action ids — echoed back in NotificationResponse.actionId. Stable strings:
// they are also persisted in the notification meta store, so don't rename
// without a migration.
const kActionComplete = 'complete';
const kActionSnooze1h = 'snooze_1h';
const kActionSnoozeTonight = 'snooze_tonight';

/// Destination for a notification body tap. Action buttons never open the app.
enum NotifIntent { open }

/// Maps a tapped action id to the app destination it should open. Background
/// actions (complete / snooze) return null — they don't open the app. A plain
/// body tap (`null` actionId) opens the event; leftover ids from older
/// schedules (replan / progress) also open the event.
NotifIntent? intentForAction(String? actionId) => switch (actionId) {
  kActionComplete || kActionSnooze1h || kActionSnoozeTonight => null,
  _ => NotifIntent.open,
};

/// The notification categories, one per distinct button set. The id strings are
/// the iOS `categoryIdentifier`s — registered up front in
/// [darwinNotificationCategories] and referenced per-notification. Stable
/// strings: persisted in the meta store, don't rename casually.
enum NotifCategory {
  milestonePlan('rdr_milestone_plan'),
  completable('rdr_completable'),
  completableNoBook('rdr_completable_nobook'),
  informational('rdr_informational');

  const NotifCategory(this.id);
  final String id;

  static NotifCategory? byId(String? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// The button set for an event, chosen from its type / plan / book. Order
/// matters — earlier actions get the visible slots on space-constrained OSes.
NotifCategory categoryForEvent(ReadingEvent e) {
  if (!e.isCompletable) return NotifCategory.informational;
  if (e.planId != null) return NotifCategory.milestonePlan;
  if (e.bookId != null) return NotifCategory.completable;
  return NotifCategory.completableNoBook;
}

/// One reminder action button. [foreground] true → opens the app (iOS
/// `foreground` option / Android `showsUserInterface`).
class NotifAction {
  const NotifAction({
    required this.id,
    required this.title,
    required this.foreground,
  });

  factory NotifAction.fromJson(Map<String, dynamic> j) => NotifAction(
    id: j['id'] as String,
    title: j['t'] as String,
    foreground: (j['fg'] as bool?) ?? false,
  );

  final String id;
  final String title;
  final bool foreground;

  Map<String, dynamic> toJson() => {'id': id, 't': title, 'fg': foreground};
}

/// The localized buttons for [category]. Rebuilt on every schedule (Android) so
/// the labels always follow the current locale; the iOS titles are frozen at
/// category-registration time (see [darwinNotificationCategories]).
List<NotifAction> actionsForCategory(NotifCategory category, AppL10n l) {
  final complete = NotifAction(
    id: kActionComplete,
    title: l.notifActionComplete,
    foreground: false,
  );
  final snooze1h = NotifAction(
    id: kActionSnooze1h,
    title: l.notifActionSnooze1h,
    foreground: false,
  );
  final snoozeTonight = NotifAction(
    id: kActionSnoozeTonight,
    title: l.notifActionSnoozeTonight,
    foreground: false,
  );
  return switch (category) {
    NotifCategory.milestonePlan ||
    NotifCategory.completable ||
    NotifCategory.completableNoBook => [complete, snooze1h],
    NotifCategory.informational => [snooze1h, snoozeTonight],
  };
}

/// Build the Android per-notification action buttons.
List<AndroidNotificationAction> androidNotificationActions(
  List<NotifAction> actions,
) => [
  for (final a in actions)
    AndroidNotificationAction(
      a.id,
      a.title,
      showsUserInterface: a.foreground,
    ),
];

/// The `NotificationDetails` for a reading reminder — one definition shared by
/// the foreground scheduler ([LocalNotifications.scheduleForEvent]) and the
/// background snooze handler (`_reschedule`) so the channel/icon/tint/actions of
/// a snoozed reminder can never drift from the originally-scheduled one. The iOS
/// side references a pre-registered category by [categoryId] (see
/// [darwinNotificationCategories]); pass null for the sample preview.
NotificationDetails buildReminderDetails({
  required String channelName,
  required String channelDescription,
  String? categoryId,
  List<NotifAction>? actions,
}) {
  final androidDetails = AndroidNotificationDetails(
    'readendar_reminders',
    channelName,
    channelDescription: channelDescription,
    importance: Importance.high,
    priority: Priority.high,
    // White-on-transparent brand mark + periwinkle tint (a full-colour icon
    // would render as a blank blob — Android masks the small icon to alpha).
    icon: kNotifSmallIcon,
    color: kNotifAccentColor,
    // Android attaches action buttons per-notification (no OS-level registry).
    actions: actions == null ? null : androidNotificationActions(actions),
  );
  final iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    categoryIdentifier: categoryId,
  );
  return NotificationDetails(android: androidDetails, iOS: iosDetails);
}

/// Resolves an IANA zone [name] to a tz [tz.Location], falling back to `tz.local`
/// when it's null/empty or unknown. Shared by the scheduler and the background
/// snooze so both resolve zones identically. NB: in the background isolate
/// `tz.local` is UTC (it never calls `setLocalLocation`), so callers that need a
/// wall-clock time must persist a concrete zone name rather than rely on this
/// fallback.
tz.Location locationOrLocal(String? name) {
  if (name == null || name.isEmpty) return tz.local;
  try {
    return tz.getLocation(name);
  } catch (_) {
    return tz.local;
  }
}

/// All iOS categories, registered once in `DarwinInitializationSettings`. iOS
/// bakes the action titles at registration, so pass the locale-resolved [l]
/// (see `main()`); the labels won't follow a live in-app language switch until
/// the next launch (Android rebuilds per-notification and is always fresh).
List<DarwinNotificationCategory> darwinNotificationCategories(AppL10n l) => [
  for (final category in NotifCategory.values)
    DarwinNotificationCategory(
      category.id,
      actions: [
        for (final a in actionsForCategory(category, l))
          DarwinNotificationAction.plain(
            a.id,
            a.title,
            options: a.foreground
                ? <DarwinNotificationActionOption>{
                    DarwinNotificationActionOption.foreground,
                  }
                : const <DarwinNotificationActionOption>{},
          ),
      ],
    ),
];
