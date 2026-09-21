// Routes a tapped reminder to its destination, and drains queued "Complete"
// actions.
//
// LocalNotifications parses the event id + intent out of the tapped
// notification and either calls [LocalNotifications.onEventTap] (app alive) or
// stashes it for [LocalNotifications.takePendingTap] (cold start / tap before
// this handler mounted). This widget — wrapping the signed-in shell — drains
// both into [pendingNotificationTapProvider], then opens the Calendar tab + the
// event's month + its detail sheet.
//
// It also registers [LocalNotifications.onCompleteQueued] so a Complete tapped
// while the app is alive replays immediately (see pending_action_drainer), and
// drains any completions queued by the background isolate on mount.
//
// Post-frame initial check + a `ref.listen` for the warm case, a `_busy`
// guard, and clear-up-front so a failure can't loop.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_detail_sheet.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_actions.dart';
import 'package:readendar/features/notifications/notification_payload.dart';
import 'package:readendar/features/notifications/pending_action_drainer.dart';
import 'package:readendar/features/quotes/book_annotations_screen.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_hub_screen.dart';
import 'package:readendar/features/reading_chapter/reading_chapter_story_screen.dart';
import 'package:readendar/features/widget/widget_deep_link.dart';

/// A tapped reminder awaiting a signed-in shell to open it: the event id plus
/// the destination intent. Set by [NotificationTapHandler] (from the
/// LocalNotifications callback or the drained cold-start target), consumed and
/// cleared by the same handler.
final pendingNotificationTapProvider =
    StateProvider<({String eventId, NotifIntent intent})?>((_) => null);

/// Wraps the signed-in shell and opens the event behind any tapped reminder.
class NotificationTapHandler extends ConsumerStatefulWidget {
  const NotificationTapHandler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationTapHandler> createState() =>
      _NotificationTapHandlerState();
}

class _NotificationTapHandlerState
    extends ConsumerState<NotificationTapHandler> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    LocalNotifications.I.onEventTap = _stash;
    LocalNotifications.I.onCompleteQueued = _drainCompletions;
    LocalNotifications.I.onQuoteTap = _stashQuote;
    LocalNotifications.I.onReadingChapterTap = _stashChapter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A tap delivered before this handler registered its callback (cold start
      // or pre-mount) is waiting here — route it now.
      final pending = LocalNotifications.I.takePendingTap();
      if (pending != null) _stash(pending.eventId, pending.intent);
      final pendingQuote = LocalNotifications.I.takePendingQuoteTap();
      if (pendingQuote != null) _stashQuote(pendingQuote);
      final pendingChapter = LocalNotifications.I
          .takePendingReadingChapterTap();
      if (pendingChapter != null) _stashChapter(pendingChapter);
      _open();
      // Replay any "Complete" the background isolate queued while we were away.
      _drainCompletions();
    });
  }

  @override
  void dispose() {
    if (LocalNotifications.I.onEventTap == _stash) {
      LocalNotifications.I.onEventTap = null;
    }
    if (LocalNotifications.I.onCompleteQueued == _drainCompletions) {
      LocalNotifications.I.onCompleteQueued = null;
    }
    if (LocalNotifications.I.onQuoteTap == _stashQuote) {
      LocalNotifications.I.onQuoteTap = null;
    }
    if (LocalNotifications.I.onReadingChapterTap == _stashChapter) {
      LocalNotifications.I.onReadingChapterTap = null;
    }
    super.dispose();
  }

  void _stashChapter(String payload) {
    if (!mounted) return;
    final ownerId = readingChapterOwnerIdFromNotifPayload(payload);
    if (ownerId == null || ownerId != ref.read(sessionProvider).user?.id) {
      return;
    }
    final route = readingChapterRouteFromNotifPayload(payload)!;
    final match = RegExp(
      r'^/reading-chapters/(month|year)/([0-9-]+)$',
    ).firstMatch(route);
    final Widget destination;
    if (match == null) {
      destination = const ReadingChapterHubScreen();
    } else {
      destination = ReadingChapterStoryScreen(
        request: ReadingChapterRequest(
          ReadingChapterKind.fromWire(match.group(1)!),
          match.group(2)!,
        ),
      );
    }
    unawaited(
      Navigator.of(context).push<void>(
        rdPageRoute<void>(context, builder: (_) => destination),
      ),
    );
  }

  /// Quote-of-the-day taps open Mis citas with that quote highlighted — same
  /// landing as a quotes-widget tap. Opens on the next frame via this state's
  /// navigator (plugin callbacks often arrive between frames while the app is
  /// idle; `ensureVisualUpdate` forces that frame).
  void _stashQuote(String quoteId) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openQuote(quoteId);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _openQuote(String quoteId) {
    if (!mounted) return;
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null) {
      // Navigator not ready yet (very early cold start) — fall through the
      // widget deep-link pipeline, which drains once the shell is up.
      ref.read(pendingWidgetDeepLinkProvider.notifier).state = WidgetDeepLink(
        WidgetLinkKind.quote,
        quoteId,
      );
      WidgetsBinding.instance.ensureVisualUpdate();
      return;
    }
    unawaited(_pushAnnotation(navigator, quoteId));
  }

  Future<void> _pushAnnotation(NavigatorState navigator, String id) async {
    Annotation? annotation;
    try {
      annotation = (await ref.read(quoteRepoProvider).get(id)).value;
    } catch (_) {
      annotation = null;
    }
    if (!mounted || annotation == null) return;
    navigator.popUntil((route) => route.isFirst);
    // Use the shared page fade so notification-driven navigation matches
    // in-app navigation without leaving the destination visually stuck.
    unawaited(
      navigator.push(
        rdPageRoute<void>(
          context,
          builder: (_) => BookAnnotationsScreen(
            bookId: annotation!.bookId,
            highlightAnnotationId: annotation.id,
          ),
        ),
      ),
    );
  }

  void _stash(String eventId, NotifIntent intent) {
    if (!mounted) return;
    // Defer the Riverpod write — plugin callbacks can land while an Overlay
    // is building; mutating providers mid-build dirties UncontrolledProviderScope.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(pendingNotificationTapProvider.notifier).state = (
        eventId: eventId,
        intent: intent,
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _drainCompletions() {
    if (!mounted) return;
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    unawaited(drainAndNotify(ref, context, user));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<({String eventId, NotifIntent intent})?>(
      pendingNotificationTapProvider,
      (_, next) {
        if (next != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _open());
        }
      },
    );
    return widget.child;
  }

  Future<void> _open() async {
    if (_busy || !mounted) return;
    final pending = ref.read(pendingNotificationTapProvider);
    if (pending == null) return;
    // Wait for a session — a tap on the lock screen can launch the app before
    // bootstrap restores the user; the listener re-fires once one exists.
    if (ref.read(sessionProvider).user == null) return;
    _busy = true;
    // Clear up-front so a deleted/expired event (or a re-fired listener) can't
    // loop on the same id.
    ref.read(pendingNotificationTapProvider.notifier).state = null;

    ReadingEvent? event;
    try {
      event = await ref.read(eventProvider(pending.eventId).future);
    } catch (_) {
      // Event no longer exists (deleted/completed) — fall through and just land
      // the user on the calendar.
      event = null;
    }
    _busy = false;
    if (!mounted) return;

    ref.read(tabIndexProvider.notifier).state = 2; // Calendar tab.
    if (event == null) return;
    ref.read(calendarFocusProvider.notifier).state = event.dateLocal;
    // This handler sits under the MaterialApp's navigator, so its context can
    // host the modal sheet. No await between the mounted check above and here.
    showEventDetailSheet(context, event);
  }
}
