import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/di/quote_spoiler_refresh.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/widget/widget_sync.dart';

/// Deletes a personal library book after confirmation.
///
/// Shared by book detail and list swipe / long-press.
/// Returns `true` when the durable mutation succeeded.
///
/// When [popOnSuccess] is true (detail route), pops before invalidating so a
/// 404 does not flash on the still-mounted detail watchers.
Future<bool> deletePersonalBook({
  required BuildContext context,
  required WidgetRef ref,
  required Book book,
  bool popOnSuccess = false,
}) async {
  final l = AppL10n.of(context);
  final ok = await showConfirmDialog(
    context: context,
    icon: LucideIcons.trash2,
    message: l.bookConfirmDelete,
    confirmLabel: l.actionDelete,
    confirmIcon: LucideIcons.trash2,
    destructive: true,
  );
  if (!ok || !context.mounted) return false;

  final repo = ref.read(bookRepoProvider);
  final err = (await repo.delete(book.id)).failure;
  if (!context.mounted) return false;
  if (err != null) {
    showRdFailureToast(context, err);
    return false;
  }

  unawaited(RdHaptics.medium());
  notifyPersonalBookSpoilerEligibilityMutation(ref, before: book);
  final container = ProviderScope.containerOf(context, listen: false);
  final user = container.read(sessionProvider).user;
  showRdToast(
    context,
    tone: RdToastTone.success,
    message: l.bookDeleteSuccess,
  );

  if (popOnSuccess) {
    // Leave before list/progress refetch. Invalidating while this route still
    // watches book/progress turns a 404 into the generic error body. Record the
    // removal after pop so this route does not rebuild into a second pop.
    Navigator.pop(context);
    rememberRemovedPersonalBookIn(container, book.id);
    container
      ..invalidate(booksProvider)
      ..invalidate(bookProvider(book.id))
      ..invalidate(upcomingEventsProvider)
      ..invalidate(calendarEventsProvider)
      ..invalidate(progressProvider(book.id))
      ..invalidate(userStatsProvider)
      ..invalidate(userPageStatsProvider);
  } else {
    rememberRemovedPersonalBook(ref, book.id);
    ref
      ..invalidate(booksProvider)
      ..invalidate(bookProvider(book.id))
      ..invalidate(upcomingEventsProvider)
      ..invalidateCalendarEvents()
      ..invalidate(progressProvider(book.id))
      ..invalidatePersonalStats();
  }
  if (user != null) {
    unawaited(
      resyncLocalNotificationsFromContainer(container, l, user).catchError(
        (Object _) {},
      ),
    );
  }
  unawaited(
    syncWidgetFromContainer(container, user).catchError((Object _) => false),
  );
  return true;
}

/// Localized destructive label for list / menu delete of [book].
String personalBookDeleteLabel(AppL10n l, Book book) {
  return l.actionDelete;
}
