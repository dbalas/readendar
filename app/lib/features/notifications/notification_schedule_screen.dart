import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/error_retry.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_content.dart';

/// Dev-only screen (reached from the debug screen) that lists every reminder
/// queued for the next 2 days — computed from the same logic that schedules
/// them ([LocalNotifications.plannedReminderFor]) — and fires the exact
/// notification on tap, so a developer can see what a real reminder will look
/// like without waiting for it to come due.
class NotificationScheduleScreen extends ConsumerWidget {
  const NotificationScheduleScreen({super.key});

  static const _horizon = Duration(days: 2);

  // High id range so manual fires never collide with scheduled-event ids
  // (hash-derived) or the preview screen's range (990000+).
  static const _baseId = 980000;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final eventsAsync = ref.watch(upcomingEventsProvider);
    final prefs = ref.watch(notificationPrefsProvider).value;
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final user = ref.watch(sessionProvider).user;

    return Scaffold(
      appBar: AppBar(title: Text(l.debugScheduledRemindersTitle)),
      body: SafeArea(
        top: false,
        child: eventsAsync.when(
          loading: RdProgress.centered,
          error: (e, _) => ErrorRetry(
            error: e,
            onRetry: () => ref.invalidate(upcomingEventsProvider),
          ),
          data: (events) {
            final reminders = _buildReminders(
              events,
              books,
              prefs,
              user,
              l,
            );
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                RdCard(
                  child: Text(
                    l.debugScheduledRemindersIntro,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                ),
                const SizedBox(height: 12),
                if (reminders.isEmpty)
                  RdCard(
                    child: Text(
                      l.debugScheduledRemindersEmpty,
                      style: TextStyle(color: context.colors.fg2),
                    ),
                  )
                else
                  RdCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, r) in reminders.indexed)
                          _ReminderRow(
                            reminder: r,
                            noBookLabel: l.debugScheduledRemindersNoBook,
                            onTap: () => _fire(context, l, i, r),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Compute the queued reminders for the next 2 days, mirroring
  /// [resyncLocalNotifications]: muted events and a globally-disabled
  /// preference produce nothing, book titles come from the personal library.
  List<PlannedReminder> _buildReminders(
    List<ReadingEvent> events,
    List<Book> books,
    NotificationPreferences? prefs,
    AppUser? user,
    AppL10n l,
  ) {
    if (prefs == null || !prefs.globalEnabled || user == null) {
      return const [];
    }
    final titlesById = {for (final b in books) b.id: b.title};
    final now = DateTime.now();
    final cutoff = now.add(_horizon);
    final out = <PlannedReminder>[];
    for (final event in events) {
      if (event.muted) continue;
      final reminder = LocalNotifications.I.plannedReminderFor(
        event,
        content: notificationContentFor(
          event,
          bookTitle: event.bookId == null ? null : titlesById[event.bookId],
          l: l,
        ),
        allDayReminderHour: prefs.allDayReminderHour,
        viewerTz: user.timezone,
      );
      if (reminder == null) continue;
      // fireAt is a TZDateTime; isAfter/isBefore compare absolute instants, so
      // the zone is handled correctly against a local `now`.
      if (reminder.fireAt.isBefore(now)) continue;
      if (reminder.fireAt.isAfter(cutoff)) continue;
      out.add(reminder);
    }
    out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return out;
  }

  Future<void> _fire(
    BuildContext context,
    AppL10n l,
    int index,
    PlannedReminder reminder,
  ) async {
    await LocalNotifications.I.showSample(
      id: _baseId + index,
      title: reminder.title,
      body: reminder.body,
      channelName: l.notificationChannelName,
      channelDescription: l.notificationChannelDescription,
    );
    if (!context.mounted) return;
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.debugNotifPreviewSent,
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.noBookLabel,
    required this.onTap,
  });

  final PlannedReminder reminder;
  final String noBookLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fireAt = reminder.fireAt;
    return ListTile(
      leading: const Icon(LucideIcons.bell, size: 20),
      title: Text(reminder.title),
      subtitle: Text(
        reminder.body ?? noBookLabel,
        style: TextStyle(color: context.colors.fg2),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _date(fireAt),
            style: TextStyle(
              color: context.colors.fg2,
              fontSize: 12,
            ),
          ),
          Text(
            _time(fireAt),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _date(DateTime d) => '${_two(d.day)}/${_two(d.month)}';
  String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
}
