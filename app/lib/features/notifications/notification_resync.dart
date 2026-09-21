import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_content.dart';
import 'package:readendar/features/notifications/notification_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads [provider], refetching when a previous attempt is cached as an error.
///
/// Session-scoped `keepAlive` providers otherwise keep a timeout forever, and
/// Riverpod 3's `.future` can hang on that AsyncError instead of rethrowing.
Future<T> readFreshProviderFuture<T>(
  ProviderContainer container,
  FutureProvider<T> provider,
) {
  final current = container.read(provider);
  if (current.hasError) {
    container.invalidate(provider);
  }
  return container.read(provider.future);
}

/// Backoff for Gate's notification-sync retry: 3s, 6s, 12s, 24s, 48s, then 60s.
Duration notificationSyncRetryDelay(int consecutiveFailures) {
  if (consecutiveFailures <= 0) return Duration.zero;
  final shift = (consecutiveFailures - 1).clamp(0, 5);
  final seconds = (3 * (1 << shift)).clamp(3, 60);
  return Duration(seconds: seconds);
}

/// Timeouts, 5xx, and rate limits are worth another attempt. Authz/validation
/// will not heal by polling `/v1/notifications/preferences`.
bool shouldRetryNotificationSync(Object error) {
  if (error is FailureException) {
    return switch (error.failure) {
      NetworkFailure() || ServerFailure() || RateLimitedFailure() => true,
      UnknownFailure() => true,
      _ => false,
    };
  }
  return true;
}

/// Log label without Dio's "raise connectTimeout" essay.
String notificationSyncFailureSummary(Object error) {
  if (error is FailureException) return error.failure.code;
  return error.toString();
}

/// Loads reminder prefs for background resync without poisoning
/// [notificationPrefsProvider] on a connect timeout.
///
/// Gate's first sync is often the first touch of that provider. A throw there
/// caches AsyncError for the session (keepAlive) and dumps Dio's timeout essay
/// through `.future`. Use a warm cache when present; otherwise hit the repo.
Future<NotificationPreferences> loadNotificationPreferencesForResync(
  ProviderContainer container,
) async {
  if (container.exists(notificationPrefsProvider)) {
    final current = container.read(notificationPrefsProvider);
    if (current.hasValue) return current.requireValue;
  }
  final result = await container.read(notificationRepoProvider).get();
  return result.fold((v) => v, (f) => throw FailureException(f));
}

Future<void> resyncLocalNotifications(
  WidgetRef ref,
  AppL10n l,
  AppUser user, {
  bool requestPermission = false,
}) {
  // Reconciliation spans provider/network/platform awaits and may finish after
  // the initiating screen has closed. Use the app-level container so lazy
  // provider loads and account checks never dereference a disposed WidgetRef.
  return resyncLocalNotificationsFromContainer(
    ProviderScope.containerOf(ref.context, listen: false),
    l,
    user,
    requestPermission: requestPermission,
  );
}

/// Same as [resyncLocalNotifications] when the caller already has the app
/// container (e.g. after popping the screen that owned the [WidgetRef]).
Future<void> resyncLocalNotificationsFromContainer(
  ProviderContainer container,
  AppL10n l,
  AppUser user, {
  bool requestPermission = false,
}) async {
  bool isCurrentUser() => container.read(sessionProvider).user?.id == user.id;
  try {
    await reconcileEventReminders(
      l: l,
      user: user,
      scheduler: LocalNotifications.I,
      sharedPreferences: container.read(sharedPreferencesProvider),
      loadPreferences: () => loadNotificationPreferencesForResync(container),
      loadEvents: () =>
          readFreshProviderFuture(container, upcomingEventsProvider),
      loadBooks: () => readFreshProviderFuture(container, booksProvider),
      requestNotificationPermission: requestPermission
          ? () => LocalNotifications.I.ensurePermission(requestIfNeeded: true)
          : null,
      shouldContinue: isCurrentUser,
    );
  } on _NotificationReconcileAborted {
    // Logout/account switch raced the sync. The finally block below removes any
    // alarm that may have crossed the platform boundary before cancellation.
  } finally {
    if (!isCurrentUser()) {
      await LocalNotifications.I.cancelAllForUser(user.id);
    }
  }
}

/// Reconciles the desired event reminders with what is already armed.
///
/// Reliability invariant: all network-backed inputs are resolved and every
/// desired reminder is scheduled/replaced before stale reminders are removed.
/// A transient provider or platform failure therefore leaves the previous
/// schedule intact for a later retry instead of cancelling everything first.
Future<void> reconcileEventReminders({
  required AppL10n l,
  required AppUser user,
  required EventReminderScheduler scheduler,
  required SharedPreferences sharedPreferences,
  required Future<NotificationPreferences> Function() loadPreferences,
  required Future<List<ReadingEvent>> Function() loadEvents,
  required Future<List<Book>> Function() loadBooks,
  Future<bool> Function()? requestNotificationPermission,
  bool Function()? shouldContinue,
}) async {
  void ensureCurrent() {
    if (!(shouldContinue?.call() ?? true)) {
      throw const _NotificationReconcileAborted();
    }
  }

  ensureCurrent();
  final prefs = await loadPreferences();
  ensureCurrent();
  // The raw prefs store, so the per-event meta writes below coalesce into one
  // flush instead of one disk commit per reminder (see NotifMetaStore.runBatched).

  // Cancel-only shortcut: nothing to schedule, so don't fetch the naming
  // sources. Covers both "notifications off" and "no schedulable events" — and
  // keeps resync a cheap cancel + return when the calendar is empty (also why a
  // widget test only needs to stub upcomingEventsProvider, not books).
  Future<void> cancelOnly() => NotifMetaStore.runBatched(
    sharedPreferences,
    () => scheduler.cancelEventRemindersForUser(user.id),
  );

  if (!prefs.globalEnabled) {
    await cancelOnly();
    return;
  }

  final events = await loadEvents();
  ensureCurrent();
  final retainedCandidates = [
    for (final event in events)
      // A cancelled (or already-completed) event must not keep its reminder
      // (§0.4); the backend resolves the canonical/overlay status, so any
      // non-active or muted event drops out here on the next resync.
      if (!event.muted &&
          event.status == EventStatus.active &&
          event.reminderEnabled &&
          event.reminderMinutesBefore != null)
        event,
  ];
  if (retainedCandidates.isEmpty) {
    await cancelOnly();
    return;
  }

  final retained = retainedCandidates;
  if (retained.isEmpty) {
    await cancelOnly();
    return;
  }
  final retainedEventIds = {for (final event in retained) event.id};
  final desired = [
    for (final event in retained)
      if (scheduler.canScheduleEventReminder(
        event,
        allDayReminderHour: prefs.allDayReminderHour,
        viewerTz: user.timezone,
      ))
        event,
  ];
  if (desired.isEmpty) {
    await NotifMetaStore.runBatched(
      sharedPreferences,
      () => scheduler.cancelStaleEventRemindersForUser(
        user.id,
        const <String, int>{},
        retainedEventIds,
      ),
    );
    return;
  }

  // There's something to schedule — now resolve book titles client-side (events
  // only carry ids) so each reminder can name the book. Await before touching
  // the existing OS schedule: a temporary API failure must not erase reminders
  // that were already armed.
  final books = await loadBooks();
  ensureCurrent();
  final titlesById = {for (final b in books) b.id: b.title};

  // Ask only after proving there is at least one reminder that can actually be
  // armed. A denial returns before any platform mutation, preserving whatever
  // schedule was already installed for a later retry.
  if (requestNotificationPermission != null &&
      !await requestNotificationPermission()) {
    return;
  }
  ensureCurrent();

  final preexistingIds = await scheduler.pendingEventNotificationIdsForUser(
    user.id,
  );
  ensureCurrent();
  await NotifMetaStore.runBatched(sharedPreferences, () async {
    final scheduledIds = await scheduleNotificationsFailureSafely<ReadingEvent>(
      items: desired,
      preexistingIds: preexistingIds,
      notificationIdFor: (event) =>
          scheduler.notificationIdForEvent(user.id, event.id),
      ensureCanSchedule: ensureCurrent,
      schedule: (event) {
        final content = notificationContentFor(
          event,
          bookTitle: event.bookId == null ? null : titlesById[event.bookId],
          l: l,
        );
        return scheduler.scheduleForEvent(
          event,
          ownerUserId: user.id,
          notificationChannelName: l.notificationChannelName,
          notificationChannelDescription: l.notificationChannelDescription,
          content: content,
          l: l,
          allDayReminderHour: prefs.allDayReminderHour,
          viewerTz: user.timezone,
          // zonedSchedule replaces an existing alarm with the same deterministic
          // id. Avoid cancelling first so a later failure cannot wipe reminders
          // that have not been reconciled yet.
          skipExplicitCancel: true,
        );
      },
      rollbackIntroduced: (ids) =>
          scheduler.cancelEventNotificationIds(user.id, ids),
    );
    final expectedIdsByEventId = {
      for (final entry in scheduledIds.entries) entry.key.id: entry.value,
    };

    // Reached only after every desired schedule succeeded. Now remove deleted,
    // completed, muted, disabled, and past reminders that are no longer wanted.
    await scheduler.cancelStaleEventRemindersForUser(
      user.id,
      expectedIdsByEventId,
      retainedEventIds,
    );
  });
}

class _NotificationReconcileAborted implements Exception {
  const _NotificationReconcileAborted();
}

/// Arms stable notification ids without leaving a partial second schedule
/// beside legacy ids when one platform call fails.
///
/// Stable ids that existed before this attempt are replacements and are never
/// rolled back. Only newly introduced ids are cancelled on failure; callers run
/// stale/legacy cleanup after this helper returns successfully.
Future<Map<T, int>> scheduleNotificationsFailureSafely<T>({
  required Iterable<T> items,
  required Set<int> preexistingIds,
  required int Function(T item) notificationIdFor,
  required Future<int?> Function(T item) schedule,
  required Future<void> Function(Set<int> ids) rollbackIntroduced,
  void Function()? ensureCanSchedule,
}) async {
  final introducedIds = <int>{};
  final armedIntroducedIds = <int>{};
  final scheduledIds = <T, int>{};
  try {
    for (final item in items) {
      ensureCanSchedule?.call();
      final candidateId = notificationIdFor(item);
      final candidateWasPreexisting = preexistingIds.contains(candidateId);
      if (!candidateWasPreexisting) {
        introducedIds.add(candidateId);
      }
      final scheduledId = await schedule(item);
      ensureCanSchedule?.call();
      if (scheduledId == null) {
        // A quote whose local fire time passed between preflight and the
        // platform call is a known no-op, not a newly introduced alarm. Do not
        // let a later failure cancel a delivered notification with that id.
        if (!candidateWasPreexisting &&
            !armedIntroducedIds.contains(candidateId)) {
          introducedIds.remove(candidateId);
        }
      } else {
        scheduledIds[item] = scheduledId;
        if (!preexistingIds.contains(scheduledId)) {
          introducedIds.add(scheduledId);
          armedIntroducedIds.add(scheduledId);
        }
        if (scheduledId != candidateId &&
            !candidateWasPreexisting &&
            !armedIntroducedIds.contains(candidateId)) {
          introducedIds.remove(candidateId);
        }
      }
    }
    return scheduledIds;
  } on Object catch (error, stackTrace) {
    try {
      await rollbackIntroduced(introducedIds);
    } on Object catch (rollbackError, rollbackStackTrace) {
      debugPrint(
        'Notification schedule rollback failed: '
        '$rollbackError\n$rollbackStackTrace',
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}
