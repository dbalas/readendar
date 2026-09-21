import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/app_timezone.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:uuid/uuid.dart';

/// Which calendar event (if any) the opt-in auto-create preference should emit
/// for a personal status transition.
EventType? autoStatusEventType({
  required bool enabled,
  required String? previousStatus,
  required String newStatus,
}) {
  if (!enabled) return null;
  if (previousStatus == newStatus) return null;
  if (newStatus == BookStatus.reading) return EventType.start;
  if (newStatus == BookStatus.read) return EventType.finish;
  return null;
}

/// True when [existing] already has a non-cancelled event of [type] on [day]
/// (civil date-only comparison on [ReadingEvent.dateLocal]).
bool hasActiveAutoStatusEventOnDay(
  Iterable<ReadingEvent> existing,
  EventType type,
  DateTime day,
) {
  final wanted = type.backendValue;
  return existing.any((e) {
    if (e.type != wanted || e.status == EventStatus.cancelled) return false;
    return e.dateLocal.year == day.year &&
        e.dateLocal.month == day.month &&
        e.dateLocal.day == day.day;
  });
}

/// Civil "today" in [timezone] (falls back to device local when unknown).
DateTime civilTodayInAppTimeZone(String timezone, {DateTime? nowUtc}) {
  final local = inAppTimeZone(nowUtc ?? DateTime.now().toUtc(), timezone);
  return DateTime(local.year, local.month, local.day);
}

/// After a successful personal status change, optionally creates a start/finish
/// event for today when the server-backed user flag is on. Best-effort: status
/// already persisted; failures surface a toast and never roll back the book.
Future<void> maybeAutoCreateStatusEvents({
  required WidgetRef ref,
  required BuildContext context,
  required Book book,
  required String? previousStatus,
  required String newStatus,
  required AppL10n l,
  ScaffoldMessengerState? messenger,
}) async {
  final user = ref.read(sessionProvider).user;
  if (user == null) return;

  final type = autoStatusEventType(
    enabled: user.autoCreateStatusEvents,
    previousStatus: previousStatus,
    newStatus: newStatus,
  );
  if (type == null) return;

  final listed = await ref.read(eventRepoProvider).listForBook(book.id);
  if (!context.mounted) return;
  if (!listed.isOk) {
    showRdFailureToast(context, listed.failure!, messenger: messenger);
    return;
  }
  final today = civilTodayInAppTimeZone(user.timezone);
  if (hasActiveAutoStatusEventOnDay(listed.value!, type, today)) return;

  final created = await ref
      .read(eventRepoProvider)
      .create(
        ownerType: OwnerType.user,
        ownerId: user.id,
        type: type.backendValue,
        title: type.label(l),
        dateLocal: today,
        bookId: book.id,
        reminderEnabled: false,
        idempotencyKey: const Uuid().v4(),
      );
  if (!context.mounted) return;
  if (!created.isOk) {
    showRdFailureToast(context, created.failure!, messenger: messenger);
    return;
  }
  ref
    ..invalidate(eventsForBookProvider(book.id))
    ..invalidateCalendarEvents()
    ..invalidate(upcomingEventsProvider);
}
