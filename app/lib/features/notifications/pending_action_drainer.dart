// Replays notification "Complete" taps the background isolate could only
// enqueue (it has no Dio/auth). Runs in the app on startup and every foreground
// return (main.dart), and immediately when a Complete is tapped while the app is
// alive (LocalNotifications.onCompleteQueued → notification_tap_handler).
//
// Returns the number of reminders actually completed so the caller can show a
// confirmation. On the API plane only the signed-in user's entries are drained
// (a shared device may hold a second account's queued actions). Local plane
// replays every queued Complete regardless of legacy owner ids.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:readendar/features/notifications/notification_store.dart';
import 'package:readendar/features/widget/widget_sync.dart';

/// A queued action older than this is dropped unattempted — bounds retries of a
/// completion whose event was since deleted server-side (a persistent 4xx).
const _maxPendingAge = Duration(days: 7);

/// Coalesces concurrent drains (startup, resume, and onCompleteQueued can all
/// fire near-simultaneously) so the same queued completion isn't sent twice.
bool _draining = false;

/// Set when a drain is requested while one is already in flight. The active
/// drain re-runs once more before releasing the guard so a Complete tapped
/// mid-drain is still replayed (and counted in the in-flight caller's total)
/// this session, instead of silently waiting for the next foreground return.
bool _drainAgain = false;

Future<int> drainPendingCompletions(WidgetRef ref, AppUser user) async {
  if (_draining) {
    _drainAgain = true;
    return 0;
  }
  // The drain starts from a lifecycle/UI callback but can finish after that
  // widget has been removed. Keep provider work attached to the app-level
  // scope instead of retaining a WidgetRef that becomes unsafe after unmount.
  final container = ProviderScope.containerOf(ref.context, listen: false);
  _draining = true;
  var total = 0;
  try {
    do {
      _drainAgain = false;
      total += await _drain(container, user);
    } while (_drainAgain);
  } finally {
    _draining = false;
  }
  return total;
}

Future<int> _drain(ProviderContainer container, AppUser user) async {
  final prefs = container.read(sharedPreferencesProvider);
  // The main-isolate SharedPreferences cache won't see writes made by the
  // background isolate until reloaded.
  await prefs.reload();

  final all = PendingActionsStore.readAll(prefs);
  if (all.isEmpty) return 0;

  final now = DateTime.now().millisecondsSinceEpoch;
  final plane = container.read(dataPlaneProvider);
  final repo = container.read(eventRepoProvider);
  final completedBookIds = <String>{};
  // Entries we've resolved and should delete (completed, terminal-failed, or
  // stale). Everything else — other accounts, transient-retry, and anything
  // enqueued concurrently — is left in place.
  final toRemove = <PendingAction>{};
  var completed = 0;

  for (final a in all) {
    if (a.action != kActionComplete) continue;
    // Local library is single-user; queued actions may still carry pre-migration
    // cloud owner ids from notification payloads.
    if (plane != DataPlane.local && a.ownerUserId != user.id) continue;
    if (now - a.ts > _maxPendingAge.inMilliseconds) {
      toRemove.add(a); // stale → drop
      continue;
    }

    final r = await repo.complete(a.eventId);
    r.fold(
      (event) {
        completed++;
        if (event.bookId != null) completedBookIds.add(event.bookId!);
        toRemove.add(a);
      },
      // Terminal (already completed / deleted / rejected) → drop; transient
      // (offline / 5xx / rate-limited) → keep and retry on the next drain.
      (f) => switch (f) {
        NotFoundFailure() ||
        ConflictFailure() ||
        ValidationFailure() ||
        ForbiddenFailure() => toRemove.add(a),
        _ => null,
      },
    );
  }

  if (toRemove.isNotEmpty) {
    // Remove only action-specific preference keys. This cannot overwrite a
    // Complete enqueued by the notification background isolate while the API
    // calls above were in flight.
    await PendingActionsStore.remove(prefs, toRemove);
  }

  if (completed > 0) {
    container
      ..invalidate(upcomingEventsProvider)
      ..invalidate(calendarEventsProvider)
      ..invalidate(userStatsProvider)
      ..invalidate(userPageStatsProvider);
    for (final bookId in completedBookIds) {
      container
        ..invalidate(progressProvider(bookId))
        ..invalidate(eventsForBookProvider(bookId));
    }
    // The completions changed what the home widget shows. The resume-time
    // syncWidget (main.dart) usually races AHEAD of this drain and snapshots
    // the pre-drain state, so re-push here once the completions have landed.
    unawaited(
      syncWidgetFromContainer(
        container,
        user,
      ).catchError((Object _) => false),
    );
  }
  return completed;
}

/// Drains the queue and, if anything completed, shows a confirmation snackbar.
/// The thin UI wrapper the app calls; [drainPendingCompletions] stays pure for
/// tests.
Future<void> drainAndNotify(
  WidgetRef ref,
  BuildContext context,
  AppUser user,
) async {
  final completed = await drainPendingCompletions(ref, user);
  if (completed == 0 || !context.mounted) return;
  final l = AppL10n.of(context);
  showRdToast(
    context,
    tone: RdToastTone.success,
    message: l.notifActionCompletedSnack(completed),
  );
}
