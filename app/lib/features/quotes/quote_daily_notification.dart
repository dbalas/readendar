// Opt-in "quote of the day" local notification.
//
// Repeating notifications can't vary their content, so the next
// [kQuoteDailyWindowDays] days are scheduled individually via zonedSchedule.
// The pick is deterministic — `dailyRotationIndex` (local epoch day % count)
// over the newest-first quote-category list, the SAME formula the quotes
// widget's daily cadence uses. It rotates over Quotes only, so it matches a
// quotes widget in the default "rotate all" daily mode; a widget instance
// configured to rotate favorites / one book (a filtered subset) intentionally
// picks from its own candidate list and can show a different quote that day.
//
// Managed independently of the event reminders: resyncLocalNotifications now
// sweeps only `event:` payloads (cancelEventRemindersForUser), so it no longer
// wipes this window — the daily quotes survive a reminder resync. This is
// re-armed on resume (main.dart) and when the setting/hour changes; the
// window is fully cleared on logout by cancelAllForUser (which clears every
// owner-namespaced notification, quotes included).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_payload.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/widget/quotes_widget_preview.dart'
    show dailyRotationIndex;
import 'package:timezone/timezone.dart' as tz;

const kQuoteDailyWindowDays = 14;

/// Deterministic per-day notification id: user + local calendar day. Pure so
/// the cancel sweep can recompute the same window without persisted state.
int quoteDailyNotificationId(String userId, DateTime day) =>
    dailyQuoteNotificationId(
      userId,
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}',
    );

/// (Re)schedules the daily quote-of-the-day window for [user]. A replacement
/// window is armed before old/legacy pending notifications are removed.
Future<void> resyncDailyQuoteNotifications(
  WidgetRef ref,
  AppL10n l,
  AppUser user, {
  bool requestPermission = false,
}) async {
  bool isCurrentUser() => ref.read(sessionProvider).user?.id == user.id;
  if (!isCurrentUser()) return;
  try {
    final storage = ref.read(prefsStorageProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final notifPrefs = await loadNotificationPreferencesForResync(
      ProviderScope.containerOf(ref.context, listen: false),
    );
    if (!isCurrentUser()) return;
    final shouldArm =
        storage.getQuoteDailyEnabled(user.id) && notifPrefs.globalEnabled;

    // Resolve the quotes we'd arm from BEFORE cancelling anything — a transient
    // fetch failure must leave the already-armed window intact (retry next
    // resync) rather than silently wiping it on a network blip.
    List<Quote>? quotes;
    if (shouldArm) {
      quotes = ref.read(quotesControllerProvider).value;
      if (quotes == null) {
        final r = await ref.read(quoteRepoProvider).listMine();
        if (!isCurrentUser()) return;
        if (r.failure != null) return; // transient error → keep existing window
        quotes = r.value;
      }
      quotes = quotes
          ?.where((q) => q.category == AnnotationCategory.quote)
          .toList();
    }

    if (!shouldArm || quotes == null || quotes.isEmpty) {
      await LocalNotifications.I.cancelQuoteNotificationsForUser(user.id);
      return;
    }

    // Ask only after proving that global + quote settings are enabled and a
    // known-good quote set exists. A denial preserves the previous window for a
    // later retry instead of cancelling it first.
    if (requestPermission &&
        !await LocalNotifications.I.ensurePermission(requestIfNeeded: true)) {
      return;
    }
    if (!isCurrentUser()) return;

    final booksById = ref.read(booksByIdProvider);
    final hour = storage.getQuoteDailyHour(user.id);
    final preexistingIds = await LocalNotifications.I
        .pendingQuoteNotificationIdsForUser(user.id);
    if (!isCurrentUser()) return;
    final requests =
        <
          ({
            int id,
            String title,
            String body,
            tz.TZDateTime fireAt,
            String payload,
          })
        >[];
    for (var d = 0; d < kQuoteDailyWindowDays; d++) {
      final day = today.add(Duration(days: d));
      final fireAt = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        hour,
      );
      final quote = quotes[dailyRotationIndex(quotes.length, fireAt)];
      final notificationId = quoteDailyNotificationId(user.id, day);
      final book = booksById[quote.bookId];
      final body = [
        '«${quote.text}»',
        if (book != null) '— ${book.title}',
      ].join(' ');
      requests.add(
        (
          id: notificationId,
          title: l.quoteDailyNotifTitle,
          body: body,
          fireAt: fireAt,
          payload: buildQuoteNotifPayload(user.id, quote.id),
        ),
      );
    }

    try {
      final scheduled = await scheduleNotificationsFailureSafely(
        items: requests,
        preexistingIds: preexistingIds,
        notificationIdFor: (request) => request.id,
        ensureCanSchedule: () {
          if (!isCurrentUser()) throw const _QuoteNotificationSyncAborted();
        },
        schedule: (request) async {
          final armed = await LocalNotifications.I.scheduleSimple(
            id: request.id,
            title: request.title,
            body: request.body,
            fireAt: request.fireAt,
            payload: request.payload,
            channelName: l.notificationChannelName,
            channelDescription: l.notificationChannelDescription,
          );
          return armed ? request.id : null;
        },
        rollbackIntroduced: LocalNotifications.I.cancelByIds,
      );
      // Only after the complete replacement window succeeds do we remove old
      // dates and legacy process-hash ids by owner/payload.
      await LocalNotifications.I.cancelStaleQuoteNotificationsForUser(
        user.id,
        scheduled.values.toSet(),
      );
    } on _QuoteNotificationSyncAborted {
      return;
    }
  } finally {
    if (!isCurrentUser()) {
      await LocalNotifications.I.cancelAllForUser(user.id);
    }
  }
}

class _QuoteNotificationSyncAborted implements Exception {
  const _QuoteNotificationSyncAborted();
}
