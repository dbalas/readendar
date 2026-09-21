// Local notification scheduling (RF-16). One-shot per ReadingEvent, computed
// from the event's wall-clock + tz (spec §6.3, §16).
//
// The service is idempotent: a platform schedule replaces the prior instance
// with the same deterministic id. Direct calls explicitly cancel first so a
// disabled/past reminder removes its old alarm; the bulk reconciler defers
// stale cleanup until every replacement succeeds.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:readendar/features/notifications/notification_background_handler.dart';
import 'package:readendar/features/notifications/notification_content.dart';
import 'package:readendar/features/notifications/notification_payload.dart';
import 'package:readendar/features/notifications/notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Narrow scheduling seam used by the reminder reconciler. Keeping this
/// interface smaller than [LocalNotifications] makes the cancel/schedule order
/// testable without a platform channel or a real device.
abstract interface class EventReminderScheduler {
  int notificationIdForEvent(String ownerUserId, String eventId);

  bool canScheduleEventReminder(
    ReadingEvent event, {
    int allDayReminderHour,
    String? viewerTz,
  });

  Future<int?> scheduleForEvent(
    ReadingEvent event, {
    required String ownerUserId,
    required String notificationChannelName,
    required String notificationChannelDescription,
    required NotificationContent content,
    required AppL10n l,
    int? overrideMinutesBefore,
    int allDayReminderHour,
    String? viewerTz,
    bool skipExplicitCancel,
  });

  Future<void> cancelEventRemindersForUser(String userId);

  Future<Set<int>> pendingEventNotificationIdsForUser(String userId);

  Future<void> cancelEventNotificationIds(
    String userId,
    Set<int> notificationIds,
  );

  Future<void> cancelStaleEventRemindersForUser(
    String userId,
    Map<String, int> expectedIdsByEventId,
    Set<String> retainedEventIds,
  );
}

/// Exact-id migration policy for pending event reminders. Matching only the
/// event id would retain both the current stable id and an older process-hash
/// id, causing duplicate notifications after an app upgrade.
@visibleForTesting
bool shouldKeepPendingEventReminder({
  required int notificationId,
  required String? eventId,
  required Map<String, int> expectedIdsByEventId,
}) => eventId != null && expectedIdsByEventId[eventId] == notificationId;

/// Delivered reminders remain actionable while their event is still live.
/// Notifications for deleted, completed, muted, or disabled events are stale.
@visibleForTesting
bool shouldKeepActiveEventReminder({
  required String? eventId,
  required Set<String> retainedEventIds,
}) => eventId != null && retainedEventIds.contains(eventId);

/// Metadata is useful only for an alarm/tray notification still known to the
/// platform. When active-notification enumeration is unsupported, preserve
/// live-event metadata conservatively so Snooze keeps working.
@visibleForTesting
bool shouldKeepEventNotificationMetadata({
  required int notificationId,
  required String eventId,
  required Set<int> keptPlatformIds,
  required Set<String> retainedEventIds,
  required bool activeNotificationsAvailable,
}) =>
    keptPlatformIds.contains(notificationId) ||
    (!activeNotificationsAvailable && retainedEventIds.contains(eventId));

class LocalNotifications implements EventReminderScheduler {
  LocalNotifications._();
  static final LocalNotifications I = LocalNotifications._();
  static const _androidSettingsChannel = MethodChannel(
    'readendar/notification_settings',
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  /// Invoked when the user taps a reminder while the app is alive, with the
  /// event id + the destination [NotifIntent]. Registered by the
  /// notification-tap handler once a signed-in shell is mounted; cleared on
  /// logout. When unset (tap arrives before the handler is ready, or a true
  /// cold start), the target is stashed in [_pendingTap] for the handler to
  /// drain.
  void Function(String eventId, NotifIntent intent)? onEventTap;

  /// Invoked after a "Complete" action is handled while the app is alive, so the
  /// tap handler can drain the pending-action queue immediately instead of
  /// waiting for the next foreground return. Registered alongside [onEventTap].
  void Function()? onCompleteQueued;

  /// Invoked when the user taps a quote-of-the-day notification (payload
  /// carries `quote:<id>` instead of `event:<id>`). Registered by the tap
  /// handler, which routes it through the widget deep-link pipeline.
  void Function(String quoteId)? onQuoteTap;
  void Function(String payload)? onReadingChapterTap;

  ({String eventId, NotifIntent intent})? _pendingTap;
  String? _pendingQuoteTap;
  String? _pendingReadingChapterTap;

  Future<void> init({AppL10n? categoriesL10n}) {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _initialize(
      categoriesL10n: categoriesL10n,
    ).whenComplete(() => _initializing = null);
  }

  Future<void> _initialize({AppL10n? categoriesL10n}) async {
    initializeAppTimeZones();
    // `date_symbol_data_local` populates all bundled Intl symbols
    // synchronously. Do it when notifications first need platform setup, after
    // Flutter has produced its first frame, rather than holding the splash.
    await initializeDateFormatting();
    // `initializeTimeZones()` leaves `tz.local` at UTC. Without this, any
    // fire time that falls back to `tz.local` (event without a tz AND no
    // viewer tz) would be computed in UTC and fire hours off. Resolve the
    // device's IANA zone and make it the local default; the user's configured
    // timezone is still honoured per-call via `viewerTz` (see scheduleForEvent).
    await _setLocalLocation();
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(kNotifSmallIcon),
        // iOS bakes the action-button categories at init time; they persist at
        // the OS level so notifications scheduled from the background isolate
        // (snooze) still show the right buttons. Titles freeze at the locale
        // resolved by `main()` until the next launch (Android is always fresh).
        iOS: DarwinInitializationSettings(
          notificationCategories: categoriesL10n == null
              ? const <DarwinNotificationCategory>[]
              : darwinNotificationCategories(categoriesL10n),
        ),
      ),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    // A tap from a terminated app doesn't fire the callback above — the launch
    // details carry the payload + action instead. Stash it so the handler can
    // route it once the shell is up. (Complete/Snooze run in the background and
    // never launch the app, so a launch is always a body tap.)
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final response = launch!.notificationResponse;
      final id = eventIdFromNotifPayload(response?.payload);
      final intent = intentForAction(response?.actionId);
      if (id != null && intent != null) {
        _pendingTap = (eventId: id, intent: intent);
      } else {
        // Quote-of-the-day cold-start tap: no event segment, a quote one.
        _pendingQuoteTap = quoteIdFromNotifPayload(response?.payload);
        if (readingChapterRouteFromNotifPayload(response?.payload) != null) {
          _pendingReadingChapterTap = response?.payload;
        }
      }
    }
    _initialized = true;
  }

  void _onTap(NotificationResponse response) {
    final actionId = response.actionId;
    // A background-style action (Complete / Snooze) can be delivered to the
    // foreground isolate when the app is alive — apply it here, mirroring the
    // background handler, so behaviour is identical whether the app is up.
    if (actionId == kActionComplete ||
        actionId == kActionSnooze1h ||
        actionId == kActionSnoozeTonight) {
      unawaited(_handleForegroundAction(response));
      return;
    }
    // Otherwise it's a plain body tap — route it to the event.
    final id = eventIdFromNotifPayload(response.payload);
    final intent = intentForAction(actionId);
    if (id == null || intent == null) {
      // Quote-of-the-day taps carry `quote:<id>` instead of an event segment.
      final quoteId = quoteIdFromNotifPayload(response.payload);
      if (quoteId != null) {
        final qcb = onQuoteTap;
        if (qcb != null) {
          qcb(quoteId);
        } else {
          _pendingQuoteTap = quoteId;
        }
      } else if (readingChapterRouteFromNotifPayload(response.payload) !=
          null) {
        final callback = onReadingChapterTap;
        if (callback != null) {
          callback(response.payload!);
        } else {
          _pendingReadingChapterTap = response.payload;
        }
      }
      return;
    }
    final cb = onEventTap;
    if (cb != null) {
      cb(id, intent);
    } else {
      _pendingTap = (eventId: id, intent: intent);
    }
  }

  Future<void> _handleForegroundAction(NotificationResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    await handleNotificationAction(response, prefs, _plugin);
    if (response.actionId == kActionComplete) onCompleteQueued?.call();
  }

  /// Drains a cold-start / early tap target captured before [onEventTap] was
  /// registered. Returns null (and stays null) once consumed.
  ({String eventId, NotifIntent intent})? takePendingTap() {
    final t = _pendingTap;
    _pendingTap = null;
    return t;
  }

  /// Same as [takePendingTap] for a quote-of-the-day tap.
  String? takePendingQuoteTap() {
    final t = _pendingQuoteTap;
    _pendingQuoteTap = null;
    return t;
  }

  String? takePendingReadingChapterTap() {
    final target = _pendingReadingChapterTap;
    _pendingReadingChapterTap = null;
    return target;
  }

  /// Schedule a plain one-shot notification (no action buttons) — the
  /// quote-of-the-day path. Same channel/zonedSchedule machinery as reminders;
  /// past fire times are skipped silently.
  Future<bool> scheduleSimple({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime fireAt,
    required String payload,
    required String channelName,
    required String channelDescription,
  }) async {
    await init();
    if (!fireAt.isAfter(tz.TZDateTime.now(fireAt.location))) return false;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: fireAt,
      notificationDetails: _details(channelName, channelDescription),
      androidScheduleMode: await _androidScheduleMode(),
      payload: payload,
    );
    return true;
  }

  /// Cancel a specific set of notification ids (deterministically derived by
  /// the caller, e.g. the quote-of-the-day window).
  Future<void> cancelByIds(Iterable<int> ids) async {
    await init();
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  Future<void> _setLocalLocation() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Plugin/lookup failure (or an unknown name) — leave tz.local as UTC.
      // Per-event tz and the user's viewerTz still drive scheduling.
    }
  }

  /// Returns whether the OS notification permission was granted. Pass
  /// `requestIfNeeded: true` from the contextual pre-prompt (spec §16.3).
  Future<bool> ensurePermission({bool requestIfNeeded = false}) async {
    await init();
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (impl == null) return false;
      if (requestIfNeeded) {
        return await impl.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (impl == null) return false;
      if (requestIfNeeded) {
        return await impl.requestNotificationsPermission() ?? false;
      }
      return true;
    }
    return false;
  }

  /// Schedule a one-shot local notification for the event, respecting
  /// reminder offset + per-user override. Re-scheduling the same event id
  /// replaces the prior notification.
  ///
  /// `ownerUserId` is stamped into the notification payload so logout can
  /// cancel only this user's reminders even if the device has a second
  /// Readendar account installed (multi-account on shared device).
  @override
  int notificationIdForEvent(String ownerUserId, String eventId) =>
      _idFor(ownerUserId, eventId);

  @override
  bool canScheduleEventReminder(
    ReadingEvent event, {
    int allDayReminderHour = 9,
    String? viewerTz,
  }) =>
      _pendingFireTime(
        event,
        allDayReminderHour: allDayReminderHour,
        viewerTz: viewerTz,
      ) !=
      null;

  @override
  Future<int?> scheduleForEvent(
    ReadingEvent event, {
    required String ownerUserId,
    required String notificationChannelName,
    required String notificationChannelDescription,
    required NotificationContent content,
    required AppL10n l,
    int? overrideMinutesBefore,
    int allDayReminderHour = 9,
    String? viewerTz,
    bool skipExplicitCancel = false,
  }) async {
    await init();
    final id = _idFor(ownerUserId, event.id);
    final prefs = await SharedPreferences.getInstance();
    if (!skipExplicitCancel) {
      // Re-scheduling replaces any prior instance; drop it + its stale meta up
      // front so a bail-out below (completed / disabled) doesn't leave orphan
      // content. The failure-safe reconciler skips this up-front cancel,
      // replaces desired alarms in place, and removes stale ones only after
      // every schedule succeeds.
      await cancelForEvent(ownerUserId, event.id);
    }

    final fireAt = _pendingFireTime(
      event,
      overrideMinutesBefore: overrideMinutesBefore,
      allDayReminderHour: allDayReminderHour,
      viewerTz: viewerTz,
    );
    if (fireAt == null) return null;

    // Pick the action-button set for this event type (see notification_actions).
    final category = categoryForEvent(event);
    final actions = actionsForCategory(category, l);
    final payload = buildNotifPayload(ownerUserId, event.id);

    await _plugin.zonedSchedule(
      id: id,
      // Title + body come from [notificationContentFor]: the title is the
      // action (with the milestone number inline), the body is the book
      // context. The OS already renders the fire time in the tray, so we don't
      // repeat the time/tz here.
      title: content.title,
      body: content.body,
      scheduledDate: fireAt,
      notificationDetails: _details(
        notificationChannelName,
        notificationChannelDescription,
        category: category,
        actions: actions,
      ),
      androidScheduleMode: await _androidScheduleMode(),
      payload: payload,
    );

    // Stash everything the snooze background isolate needs to re-fire this
    // reminder even when the app is killed (see notification_background_handler).
    await NotifMetaStore.write(
      prefs,
      id,
      NotifMeta(
        title: content.title,
        body: content.body,
        channelName: notificationChannelName,
        channelDescription: notificationChannelDescription,
        ownerUserId: ownerUserId,
        eventId: event.id,
        categoryId: category.id,
        androidActions: actions,
        payload: payload,
        tz: _reminderTzName(event, viewerTz),
      ),
    );
    return id;
  }

  /// Returns the future instant that can actually be armed for [event], or
  /// null when there is no pending reminder. The reconciler uses the same
  /// preflight before asking for OS permission, so an account with only
  /// disabled, completed, malformed, or already-past reminders is never
  /// prompted unnecessarily.
  tz.TZDateTime? _pendingFireTime(
    ReadingEvent event, {
    required int allDayReminderHour,
    int? overrideMinutesBefore,
    String? viewerTz,
  }) {
    if (event.status == EventStatus.completed || !event.reminderEnabled) {
      return null;
    }
    final minutes = overrideMinutesBefore ?? event.reminderMinutesBefore;
    if (minutes == null) return null;
    final fireAt = _computeFireTime(
      event,
      minutes,
      allDayReminderHour,
      viewerTz,
    );
    if (fireAt == null) return null;
    if (fireAt.isBefore(tz.TZDateTime.now(fireAt.location))) return null;
    return fireAt;
  }

  /// The concrete IANA zone to persist for the reminder so the snooze background
  /// isolate — where `tz.local` is UTC — can recompute "tonight 20:00" in the
  /// right wall-clock zone. Falls through event tz → viewer tz → the device zone
  /// resolved at [init] (`tz.local`), never null/empty (`??` alone would let an
  /// empty-string tz slip through to the UTC fallback).
  String _reminderTzName(ReadingEvent event, String? viewerTz) {
    final eventTz = event.tz;
    if (eventTz != null && eventTz.isNotEmpty) return eventTz;
    if (viewerTz != null && viewerTz.isNotEmpty) return viewerTz;
    return tz.local.name;
  }

  /// Compute the reminder that [scheduleForEvent] *would* schedule for this
  /// event — same gating, fire-time and body logic — without touching the OS.
  /// Returns null when the event has no pending reminder (completed, reminder
  /// disabled, no offset, or an unparseable time). Used by the dev-only
  /// scheduled-reminders debug screen to list what is queued and let the
  /// developer fire the exact notification on demand.
  PlannedReminder? plannedReminderFor(
    ReadingEvent event, {
    required NotificationContent content,
    int? overrideMinutesBefore,
    int allDayReminderHour = 9,
    String? viewerTz,
  }) {
    if (event.status == EventStatus.completed) return null;
    if (!event.reminderEnabled) return null;
    final minutes = overrideMinutesBefore ?? event.reminderMinutesBefore;
    if (minutes == null) return null;
    final fireAt = _computeFireTime(
      event,
      minutes,
      allDayReminderHour,
      viewerTz,
    );
    if (fireAt == null) return null;
    return PlannedReminder(
      eventId: event.id,
      title: content.title,
      body: content.body,
      fireAt: fireAt,
    );
  }

  /// Immediately display a notification (no scheduling). Used by the dev-only
  /// notification preview screen to review the design straight in the tray.
  Future<void> showSample({
    required int id,
    required String title,
    required String channelName,
    required String channelDescription,
    String? body,
  }) async {
    await init();
    await ensurePermission(requestIfNeeded: true);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _details(channelName, channelDescription),
    );
  }

  NotificationDetails _details(
    String channelName,
    String channelDescription, {
    NotifCategory? category,
    List<NotifAction>? actions,
  }) => buildReminderDetails(
    channelName: channelName,
    channelDescription: channelDescription,
    categoryId: category?.id,
    actions: actions,
  );

  /// Pick the Android alarm mode. SCHEDULE_EXACT_ALARM is user-granted on modern
  /// Android, so timed reminders fire on the dot only after the user enables the
  /// system capability. Inexact alarms can be batched in Doze, but are a safe
  /// fallback while the grant is absent or revoked instead of throwing
  /// `exact_alarms_not_permitted`. The settings screen surfaces the state and
  /// lets the user open the system grant screen.
  /// Shared with the background snooze via [resolveAndroidScheduleMode] so both
  /// paths behave identically.
  Future<AndroidScheduleMode> _androidScheduleMode() =>
      resolveAndroidScheduleMode(_plugin);

  /// Whether the OS will actually display notifications for this app right now.
  /// Unlike [ensurePermission] this never prompts — it reports current state so
  /// the settings screen can surface a fix-it banner. True on platforms without
  /// a queryable status.
  Future<bool> areNotificationsEnabled() async {
    try {
      await init();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final impl = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await impl?.areNotificationsEnabled() ?? true;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        final impl = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final opts = await impl?.checkPermissions();
        return opts?.isEnabled ?? false;
      }
      return true;
    } on Object catch (error, stackTrace) {
      // Fail closed so the reliability card stays visible and actionable even
      // when a vendor/plugin query itself is broken.
      debugPrint(
        'Notification permission status check failed: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  /// Android-only: whether the app may schedule exact alarms. Inexact alarms are
  /// batched in Doze and can miss a timed reminder when the app is killed, so
  /// the settings screen warns when this is false. Always true off Android.
  Future<bool> canScheduleExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      await init();
      final impl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await impl?.canScheduleExactNotifications() ?? false;
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Exact-alarm capability status check failed: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  /// Android-only: open the system "Alarms & reminders" screen so the user can
  /// grant exact-alarm scheduling. No-op on other platforms.
  Future<void> requestExactAlarms() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await init();
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await impl?.requestExactAlarmsPermission();
  }

  /// Opens Android's battery-optimization allowlist. This is intentionally the
  /// standard settings screen, not a direct exemption request: exact
  /// AlarmManager reminders already work within Doze, while OEMs such as
  /// ColorOS may still require the user to relax their vendor battery policy.
  /// Returns false when the platform screen is unavailable so the caller can
  /// fall back to the generic app settings page.
  Future<bool> openBatteryOptimizationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _androidSettingsChannel.invokeMethod<bool>(
            'openBatteryOptimizationSettings',
          ) ??
          false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Could not open battery optimization settings: '
        '$error\n$stackTrace',
      );
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'Battery optimization settings channel unavailable: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }

  Future<void> cancelForEvent(String ownerUserId, String eventId) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    await NotifMetaStore.runBatched(prefs, () async {
      final ids = <int>{_idFor(ownerUserId, eventId)};
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        if (payloadBelongsToOwner(request.payload, ownerUserId) &&
            eventIdFromNotifPayload(request.payload) == eventId) {
          ids.add(request.id);
        }
      }
      final active = await _activeNotificationsOrNull();
      if (active != null) {
        for (final notification in active) {
          final id = notification.id;
          if (id != null &&
              payloadBelongsToOwner(notification.payload, ownerUserId) &&
              eventIdFromNotifPayload(notification.payload) == eventId) {
            ids.add(id);
          }
        }
      }
      for (final id in ids) {
        await _plugin.cancel(id: id);
        await NotifMetaStore.remove(prefs, id);
      }
      final metadata = NotifMetaStore.entriesForOwner(prefs, ownerUserId);
      for (final entry in metadata.entries) {
        if (entry.value.eventId == eventId) {
          await NotifMetaStore.remove(prefs, entry.key);
        }
      }
    });
  }

  /// Cancel only the notifications scheduled by `userId`. Used on logout so a
  /// second Readendar account on the same device keeps its reminders. Clears
  /// EVERY namespaced notification (event reminders AND quote-of-the-day), so
  /// the signed-out account leaves nothing armed.
  Future<void> cancelAllForUser(String userId) async {
    // Match both the current `owner:<id>|event:<id>` format and the legacy
    // bare `owner:<id>` payload, so reminders scheduled before this format
    // change still get cleared on logout.
    await _cancelForOwner(
      userId,
      (_) => true,
      removeEventMetadata: true,
    );
  }

  /// Cancel only this user's EVENT reminders (payloads carrying an `event:`
  /// segment), leaving quote-of-the-day notifications intact. The reminder
  /// resync sweeps + re-schedules reminders on many triggers (settings change,
  /// event edit, plan create); the daily-quote window is
  /// managed on its own schedule, so it must survive a reminder resync — using
  /// [cancelAllForUser] here silently wiped it until the next app resume.
  @override
  Future<void> cancelEventRemindersForUser(String userId) async {
    // Everything this user owns EXCEPT quote-of-the-day payloads — so new
    // `event:` reminders and any legacy bare `owner:` reminders are swept, but
    // the daily-quote window is left untouched.
    await _cancelForOwner(
      userId,
      (payload) => quoteIdFromNotifPayload(payload) == null,
      removeEventMetadata: true,
    );
  }

  @override
  Future<Set<int>> pendingEventNotificationIdsForUser(String userId) async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return {
      for (final request in pending)
        if (payloadBelongsToOwner(request.payload, userId) &&
            quoteIdFromNotifPayload(request.payload) == null)
          request.id,
    };
  }

  @override
  Future<void> cancelEventNotificationIds(
    String userId,
    Set<int> notificationIds,
  ) async {
    if (notificationIds.isEmpty) return;
    await init();
    final prefs = await SharedPreferences.getInstance();
    await NotifMetaStore.runBatched(prefs, () async {
      final metadata = NotifMetaStore.entriesForOwner(prefs, userId);
      for (final id in notificationIds) {
        await _plugin.cancel(id: id);
        if (metadata.containsKey(id)) await NotifMetaStore.remove(prefs, id);
      }
    });
  }

  /// Cancel every quote-of-the-day notification for this user, including
  /// already-delivered tray notifications where the platform exposes them.
  Future<void> cancelQuoteNotificationsForUser(String userId) async {
    await _cancelForOwner(
      userId,
      (payload) => quoteIdFromNotifPayload(payload) != null,
      removeEventMetadata: false,
    );
  }

  /// Removes pending quote notifications that are not one of the newly armed
  /// stable ids. This payload sweep is the migration path for notifications
  /// created by older builds whose `String.hashCode` id cannot be recomputed
  /// reliably after an app/runtime upgrade.
  Future<void> cancelStaleQuoteNotificationsForUser(
    String userId,
    Set<int> keepIds,
  ) async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (!payloadBelongsToOwner(request.payload, userId)) continue;
      if (quoteIdFromNotifPayload(request.payload) == null) continue;
      if (keepIds.contains(request.id)) continue;
      await _plugin.cancel(id: request.id);
    }
  }

  Future<Set<int>> pendingQuoteNotificationIdsForUser(String userId) async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    return {
      for (final request in pending)
        if (payloadBelongsToOwner(request.payload, userId) &&
            quoteIdFromNotifPayload(request.payload) != null)
          request.id,
    };
  }

  /// Removes event reminders that no longer belong to the current desired set.
  ///
  /// Reconciliation schedules/replaces every desired reminder first, then calls
  /// this cleanup. If one platform schedule fails midway, cleanup is never
  /// reached, so reminders that were already armed remain intact instead of a
  /// bulk cancel leaving the user with none.
  @override
  Future<void> cancelStaleEventRemindersForUser(
    String userId,
    Map<String, int> expectedIdsByEventId,
    Set<String> retainedEventIds,
  ) async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    final prefs = await SharedPreferences.getInstance();
    final keptPlatformIds = expectedIdsByEventId.values.toSet();
    for (final request in pending) {
      final payload = request.payload;
      if (!payloadBelongsToOwner(payload, userId)) continue;
      if (quoteIdFromNotifPayload(payload) != null) continue;
      final eventId = eventIdFromNotifPayload(payload);
      // Keep only the exact stable id armed by this reconciliation. An older
      // build may have used a different process-local hash for the same event;
      // matching by event id alone would preserve both alarms.
      if (shouldKeepPendingEventReminder(
        notificationId: request.id,
        eventId: eventId,
        expectedIdsByEventId: expectedIdsByEventId,
      )) {
        continue;
      }
      await _plugin.cancel(id: request.id);
      await NotifMetaStore.remove(prefs, request.id);
    }

    // Pending requests do not include a reminder that has already been posted
    // to the tray. Remove delivered reminders only when their event is no
    // longer current (deleted/completed/muted/disabled); live fired reminders
    // remain actionable and retain their snooze metadata.
    final active = await _activeNotificationsOrNull();
    if (active != null) {
      for (final notification in active) {
        final payload = notification.payload;
        if (!payloadBelongsToOwner(payload, userId)) continue;
        if (quoteIdFromNotifPayload(payload) != null) continue;
        final notificationId = notification.id;
        if (notificationId == null) continue;
        final eventId = eventIdFromNotifPayload(payload);
        if (shouldKeepActiveEventReminder(
          eventId: eventId,
          retainedEventIds: retainedEventIds,
        )) {
          keptPlatformIds.add(notificationId);
          continue;
        }
        await _plugin.cancel(id: notificationId);
        await NotifMetaStore.remove(prefs, notificationId);
      }
    }

    // Prune metadata that has neither a current pending alarm nor a live tray
    // notification. If the platform cannot enumerate active notifications, be
    // conservative for still-current events so their snooze action keeps
    // working; stale events are always safe to remove.
    final metadata = NotifMetaStore.entriesForOwner(prefs, userId);
    for (final entry in metadata.entries) {
      if (shouldKeepEventNotificationMetadata(
        notificationId: entry.key,
        eventId: entry.value.eventId,
        keptPlatformIds: keptPlatformIds,
        retainedEventIds: retainedEventIds,
        activeNotificationsAvailable: active != null,
      )) {
        continue;
      }
      await NotifMetaStore.remove(prefs, entry.key);
    }
  }

  /// Cancels this user's pending notifications whose payload passes [where],
  /// plus delivered notifications when supported. Shared by the logout,
  /// event-only, and quote-only cancellation paths.
  Future<void> _cancelForOwner(
    String userId,
    bool Function(String? payload) where, {
    required bool removeEventMetadata,
  }) async {
    await init();
    final pending = await _plugin.pendingNotificationRequests();
    final cancelledIds = <int>{};
    for (final p in pending) {
      if (payloadBelongsToOwner(p.payload, userId) && where(p.payload)) {
        await _plugin.cancel(id: p.id);
        cancelledIds.add(p.id);
      }
    }
    final active = await _activeNotificationsOrNull();
    if (active != null) {
      for (final notification in active) {
        final notificationId = notification.id;
        if (notificationId == null) continue;
        if (!payloadBelongsToOwner(notification.payload, userId) ||
            !where(notification.payload) ||
            cancelledIds.contains(notificationId)) {
          continue;
        }
        await _plugin.cancel(id: notificationId);
      }
    }
    if (removeEventMetadata) {
      final prefs = await SharedPreferences.getInstance();
      await NotifMetaStore.removeForOwner(prefs, userId);
    }
  }

  Future<List<ActiveNotification>?> _activeNotificationsOrNull() async {
    try {
      return await _plugin.getActiveNotifications();
    } on Object catch (error, stackTrace) {
      if (error is UnimplementedError || error is UnsupportedError) return null;
      debugPrint(
        'Active-notification query failed; preserving live metadata: '
        '$error\n$stackTrace',
      );
      return null;
    }
  }

  /// Cancel literally everything. Reserve for full-reset scenarios.
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Extracts the event id from a notification payload, or null if absent
  /// (legacy bare `owner:<id>` payloads have no event segment). Kept as a static
  /// entry point; delegates to the shared payload helper.
  static String? eventIdFromPayload(String? payload) =>
      eventIdFromNotifPayload(payload);

  // ─── helpers ────────────────────────────────────────────────────

  tz.TZDateTime? _computeFireTime(
    ReadingEvent event,
    int minutesBefore,
    int allDayReminderHour,
    String? viewerTz,
  ) {
    final eventTz = event.tz ?? viewerTz;
    final loc = locationOrLocal(eventTz);
    final d = event.dateLocal;
    final hour = event.isAllDay
        ? allDayReminderHour
        : _parseHour(event.timeLocal);
    final minute = event.isAllDay ? 0 : _parseMinute(event.timeLocal);
    if (hour == null || minute == null) return null;
    final base = tz.TZDateTime(loc, d.year, d.month, d.day, hour, minute);
    return base.subtract(Duration(minutes: minutesBefore));
  }

  int? _parseHour(String? hhmm) {
    if (hhmm == null || hhmm.length < 5) return null;
    return int.tryParse(hhmm.substring(0, 2));
  }

  int? _parseMinute(String? hhmm) {
    if (hhmm == null || hhmm.length < 5) return null;
    return int.tryParse(hhmm.substring(3, 5));
  }

  int _idFor(String ownerUserId, String eventId) {
    return eventNotificationId(ownerUserId, eventId);
  }
}

/// A reminder [LocalNotifications.scheduleForEvent] would queue: the exact
/// title/body that fire, plus the wall-clock fire time. [fireAt] is a
/// `TZDateTime` (a `DateTime` subtype) carrying the event's resolved zone.
class PlannedReminder {
  const PlannedReminder({
    required this.eventId,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  final String eventId;
  final String title;
  final String? body;
  final DateTime fireAt;
}
