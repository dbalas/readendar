// Single source of truth for what a reminder *says* — the title (the action,
// with the milestone number inline) and the body (book context). Pure
// function of the event plus the resolved book title, so the
// scheduler ([LocalNotifications]), the dev preview, and the scheduled-reminders
// debug screen all render identical content. Computing this from the event's
// own fields (rather than the persisted `event.title`) fixes three gaps:
//   - hand-created milestones used to read "Page milestone" with no number;
//   - a persisted title froze the locale at creation time.
// See spec §6.9 / RF-16.

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/widgets/event_icon.dart';

/// The two text slots a local notification renders. [body] is null when there
/// is no context to show (the OS hides an empty body line).
class NotificationContent {
  const NotificationContent({required this.title, this.body});
  final String title;
  final String? body;
}

/// Build the reminder title + body for [event].
///
/// [bookTitle] is resolved by the caller (events only carry ids). May be null;
/// the body simply omits the missing part.
NotificationContent notificationContentFor(
  ReadingEvent event, {
  required AppL10n l,
  String? bookTitle,
}) {
  final type = EventType.fromString(event.type);
  return NotificationContent(
    title: _title(type, event, l),
    body: _body(type, event, bookTitle, l),
  );
}

String _title(EventType? type, ReadingEvent event, AppL10n l) {
  switch (type) {
    case EventType.start:
      return l.notifTitleStart;
    case EventType.finish:
      return l.notifTitleFinish;
    case EventType.abandoned:
      return l.notifTitleAbandon;
    case EventType.chapterMilestone:
      // The target number is the most actionable bit, so it leads the title
      // (never truncated, unlike the body). Fall back to the generic label
      // when an event somehow has no target.
      return event.targetChapter != null
          ? l.notifTitleReachChapter(event.targetChapter!)
          : l.eventTypeChapterMilestone;
    case EventType.pageMilestone:
      return event.targetPage != null
          ? l.notifTitleReachPage(event.targetPage!)
          : l.eventTypePageMilestone;
    case EventType.deadline:
      return l.notifTitleDeadline;
    case EventType.bookReturn:
      return l.notifTitleReturn;
    case EventType.release:
      return l.notifTitleRelease;
    case null:
      // Unknown/future type: fall back to whatever title was persisted.
      return event.title;
  }
}

String? _body(
  EventType? type,
  ReadingEvent event,
  String? bookTitle,
  AppL10n l,
) {
  final parts = <String>[
    if (_clean(bookTitle) != null) _clean(bookTitle)!,
    if (type == EventType.deadline && event.targetPage != null)
      l.notifBodyDeadlineTarget(event.targetPage!),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String? _clean(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}
