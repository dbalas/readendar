// P-09 — Detalle de evento (spec §9.3).
//
// Compact bottom-sheet with all event info + completion / edit / navigate
// actions.

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/completed_badge.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_checkbox.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/calendar/event_form_screen.dart';
import 'package:readendar/features/library/book_detail_screen.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/plan/domain/replan.dart';
import 'package:readendar/features/plan/presentation/plan_screen.dart';
import 'package:readendar/features/store_review/store_review_eligibility.dart';
import 'package:readendar/features/store_review/store_review_prompt.dart';
import 'package:readendar/features/widget/widget_sync.dart';

void showEventDetailSheet(
  BuildContext context,
  ReadingEvent event, {
  Book? book,

  /// When set, the sheet is read-only and shows a select CTA instead of
  /// complete / edit actions. Used by the plan "before an event" picker.
  ValueChanged<ReadingEvent>? onPlanUntilHere,
}) {
  showRdModalSheet<void>(
    context: context,
    builder: (_) => EventDetailSheet(
      event: event,
      book: book,
      onPlanUntilHere: onPlanUntilHere,
    ),
  );
}

class EventDetailSheet extends ConsumerStatefulWidget {
  const EventDetailSheet({
    required this.event,
    super.key,
    this.book,
    this.onPlanUntilHere,
  });
  final ReadingEvent event;
  final Book? book;
  final ValueChanged<ReadingEvent>? onPlanUntilHere;

  bool get selectionMode => onPlanUntilHere != null;

  @override
  ConsumerState<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends ConsumerState<EventDetailSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted || widget.selectionMode || widget.event.seenAt != null)
        return;
      await ref.read(eventRepoProvider).markSeen(widget.event.id);
      ref
        ..invalidate(upcomingEventsProvider)
        ..invalidateCalendarEvents();
    });
  }

  // Pop the sheet, then push the detail screen onto the underlying navigator so
  // the back button returns the user to wherever they opened the event from.
  void _openBook(Book book) {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      rdPageRoute<void>(
        context,
        builder: (_) => BookDetailScreen(bookId: book.id),
      ),
    );
  }

  void _openEdit() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      rdPageRoute<void>(
        context,
        builder: (_) => EventFormScreen(existing: widget.event),
      ),
    );
  }

  /// Replan the plan THIS event belongs to (shown only when `event.planId` is
  /// set). Loads the plan's live events, derives the replan state, and opens the
  /// planner in replan mode for the event's own book. The run, if it's in
  /// history, is passed for richer metadata; otherwise the cadence is inferred.
  Future<void> _openReplan(Book book, String planId) async {
    final l = AppL10n.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final res = await ref.read(eventRepoProvider).listAllForBook(book.id);
    if (!mounted) return;
    setState(() => _busy = false);
    final events = res.value;
    if (events == null) {
      showRdToast(
        context,
        messenger: messenger,
        tone: RdToastTone.error,
        message: l.planFailed,
      );
      return;
    }
    final planEvents = events
        .where((e) => e.planId == planId)
        .toList(growable: false);
    final run = ref
        .read(bookPlansProvider(book.id))
        .value
        ?.where((r) => r.id == planId)
        .firstOrNull;
    final state = buildReplanState(
      planEvents,
      book: book,
      now: DateTime.now(),
      run: run,
    );
    if (state == null) {
      showRdToast(
        context,
        messenger: messenger,
        message: l.planReplanNothing,
      );
      return;
    }
    nav.pop();
    unawaited(
      nav.push(
        rdPageRoute<void>(
          context,
          builder: (_) => PlanScreen(
            book: book,
            progress: ref.read(progressProvider(book.id)).value,
            replan: ReplanLaunch(
              planId: planId,
              state: state,
              allBookEvents: events,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markCompleted() async {
    setState(() => _busy = true);
    final r = await ref.read(eventRepoProvider).complete(widget.event.id);
    if (!mounted) return;
    await r.fold((_) async {
      // Fire-and-forget: the platform call must not gate the UI flow (and an
      // await would hang widget tests, where the channel has no handler).
      unawaited(HapticFeedback.mediumImpact());
      ref
        ..invalidate(upcomingEventsProvider)
        ..invalidateCalendarEvents();
      // Completing a milestone advances the book's progress server-side
      // (spec §6.6); refresh the views that show it.
      final bookId = widget.event.bookId;
      if (bookId != null) {
        ref.invalidate(progressProvider(bookId));
        ref.invalidate(eventsForBookProvider(bookId));
      }
      ref.invalidatePersonalStats();
      // Best-effort: keep the home-screen widget's snapshot fresh instead of
      // waiting for the native poll (up to 30 min) to reflect this completion.
      unawaited(syncWidget(ref).catchError((Object _) => false));
      // A completed event must not fire its reminder — drop the pending one.
      final user = ref.read(sessionProvider).user;
      if (user != null) {
        await LocalNotifications.I.cancelForEvent(user.id, widget.event.id);
      }
      if (!mounted) return;
      // A chapter milestone advances the chapter but can't derive the page;
      // offer a quick, optional prompt to update the reader's page (spec §6.6).
      final type = EventType.fromString(widget.event.type);
      var showedChapterPrompt = false;
      if (type == EventType.chapterMilestone &&
          bookId != null &&
          !ref.read(prefsStorageProvider).isChapterPromptHidden(bookId)) {
        await _promptChapterProgress(bookId);
        showedChapterPrompt = true;
        if (!mounted) return;
      }
      // Habit trigger: 7th personal reading session — skip if we just stacked
      // the chapter-progress dialog on this same completion.
      if (!showedChapterPrompt) {
        await _maybePromptStoreReviewAfterSession(type);
        if (!mounted) return;
      }
      Navigator.of(context).pop();
    }, (f) async => setState(() => _busy = false));
  }

  Future<void> _maybePromptStoreReviewAfterSession(EventType? type) async {
    final isMilestone =
        type == EventType.chapterMilestone || type == EventType.pageMilestone;
    if (!isMilestone) return;
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    final count = await ref
        .read(prefsStorageProvider)
        .incrementStoreReviewSessionCount(user.id);
    if (!StoreReviewEligibility.sessionsOpportunity(count)) return;
    if (!mounted) return;
    await maybeShowStoreReviewPrompt(
      context,
      ref,
      trigger: StoreReviewTrigger.sessions,
      completedSessions: count,
    );
  }

  Future<void> _markUncompleted() async {
    setState(() => _busy = true);
    final r = await ref.read(eventRepoProvider).uncomplete(widget.event.id);
    if (!mounted) return;
    await r.fold((_) async {
      ref
        ..invalidate(upcomingEventsProvider)
        ..invalidateCalendarEvents();
      final bookId = widget.event.bookId;
      if (bookId != null) {
        ref.invalidate(eventsForBookProvider(bookId));
      }
      // Reopening can make a future event eligible for its reminder again.
      final user = ref.read(sessionProvider).user;
      if (user != null) {
        await resyncLocalNotifications(
          ref,
          AppL10n.of(context),
          user,
          requestPermission: true,
        );
      }
      unawaited(syncWidget(ref).catchError((Object _) => false));
      if (mounted) Navigator.of(context).pop();
    }, (_) async => setState(() => _busy = false));
  }

  // Shows the brief, optional "update your page?" prompt after a chapter
  // milestone is completed. Dismissing it (back / tap-outside) skips silently.
  Future<void> _promptChapterProgress(String bookId) async {
    final result = await showDialog<_ChapterProgressResult>(
      context: context,
      builder: (_) => const _ChapterProgressDialog(),
    );
    if (result == null) return;
    if (result.dontShowAgain) {
      await ref.read(prefsStorageProvider).setChapterPromptHidden(bookId);
    }
    final page = result.page;
    if (page != null && page > 0) {
      await ref.read(progressRepoProvider).update(bookId, page: page);
      if (mounted) {
        ref
          ..invalidate(progressProvider(bookId))
          ..invalidatePersonalStats();
        // The completion-time syncWidget already fired before this prompt —
        // re-push so the widget shows the corrected page/%.
        unawaited(syncWidget(ref).catchError((Object _) => false));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final e = widget.event;
    final type = EventType.fromString(e.type) ?? EventType.deadline;
    final book = widget.book ?? _bookFromProvider(e.bookId);
    final selecting = widget.selectionMode;
    final canEdit = !selecting && e.ownerType == 'user';
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final eventDay = DateTime(
      e.dateLocal.year,
      e.dateLocal.month,
      e.dateLocal.day,
    );
    final canSelect = selecting && !eventDay.isBefore(today);
    final completionButton = selecting
        ? null
        : e.isCompletable && e.status == EventStatus.active
        ? RdButton.primary(
            icon: LucideIcons.check,
            label: l.actionMarkCompleted,
            onPressed: _busy ? null : _markCompleted,
          )
        : e.isCompletable && e.status == EventStatus.completed
        ? RdButton.secondary(
            icon: LucideIcons.rotateCcw,
            label: l.actionMarkUncompleted,
            onPressed: _busy ? null : _markUncompleted,
          )
        : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type.icon, color: type.colorOf(context)),
                const SizedBox(width: 10),
                Text(
                  type.label(l),
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize:
                        (Theme.of(context).textTheme.titleLarge?.fontSize ??
                            22) -
                        2,
                  ),
                ),
                if (e.status == EventStatus.completed) ...[
                  const SizedBox(width: 8),
                  const CompletedBadge(size: 24),
                ],
                const Spacer(),
                if (!selecting && book != null && e.planId != null)
                  RdIconButton.compact(
                    icon: LucideIcons.calendarSync,
                    tooltip: l.planReplanCta,
                    color: context.colors.accent,
                    onPressed: _busy
                        ? null
                        : () => _openReplan(book, e.planId!),
                  ),
                if (canEdit)
                  RdIconButton.compact(
                    icon: LucideIcons.edit,
                    tooltip: l.actionEdit,
                    onPressed: _busy ? null : _openEdit,
                  ),
              ],
            ),
            if (book != null) ...[
              const SizedBox(height: 12),
              _BookSummary(
                book,
                onTap: selecting ? null : () => _openBook(book),
              ),
            ],
            const SizedBox(height: 12),
            // Date / time / page metadata on the left, with the primary
            // Completion action sharing the row on the right so completing or
            // reopening is reachable without scrolling past the metadata.
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(LucideIcons.calendar, _formatDate(e.dateLocal)),
                      if (e.timeLocal != null)
                        _row(LucideIcons.clock, _formatTimeWithTz(e)),
                      if (e.targetChapter != null)
                        _row(
                          LucideIcons.bookmark,
                          l.progressChapterValue(e.targetChapter!),
                        ),
                      if (e.targetPage != null)
                        _row(LucideIcons.fileText, 'p. ${e.targetPage}'),
                    ],
                  ),
                ),
                if (completionButton != null) ...[
                  const SizedBox(width: 12),
                  completionButton,
                ],
              ],
            ),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(e.description),
            ],
            if (selecting) ...[
              const SizedBox(height: 20),
              RdButton.primary(
                icon: LucideIcons.flag,
                label: l.planUntilHere,
                expand: true,
                onPressed: canSelect
                    ? () {
                        final select = widget.onPlanUntilHere!;
                        Navigator.of(context).pop();
                        select(e);
                      }
                    : null,
              ),
              if (!canSelect) ...[
                const SizedBox(height: 8),
                Text(
                  l.planUntilHerePastHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: context.colors.fg3),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: context.colors.fg2),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  String _formatDate(DateTime d) => formatMediumDate(context, d);

  String _formatTimeWithTz(ReadingEvent e) {
    final user = ref.read(sessionProvider).user;
    final showTz = e.tz != null && user != null && e.tz != user.timezone;
    return showTz ? '${e.timeLocal} (${e.tz})' : (e.timeLocal ?? '');
  }

  Book? _bookFromProvider(String? bookId) {
    if (bookId == null) return null;
    return ref.watch(booksByIdProvider)[bookId];
  }
}

/// Result of the chapter-completion progress prompt. [page] is null when the
/// user skipped ("Ahora no"); [dontShowAgain] persists the per-book dismissal.
class _ChapterProgressResult {
  const _ChapterProgressResult({required this.dontShowAgain, this.page});
  final int? page;
  final bool dontShowAgain;
}

class _ChapterProgressDialog extends StatefulWidget {
  const _ChapterProgressDialog();

  @override
  State<_ChapterProgressDialog> createState() => _ChapterProgressDialogState();
}

class _ChapterProgressDialogState extends State<_ChapterProgressDialog> {
  final _pageCtrl = TextEditingController();
  bool _dontShowAgain = false;
  String? _pageError;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int? get _parsedPage => int.tryParse(_pageCtrl.text.trim());

  bool get _canSave {
    final page = _parsedPage;
    return page != null && page > 0;
  }

  void _popSkip() {
    Navigator.of(context).pop(
      _ChapterProgressResult(
        dontShowAgain: _dontShowAgain,
      ),
    );
  }

  void _trySave() {
    if (!_canSave) {
      setState(() => _pageError = AppL10n.of(context).errFieldRequired);
      return;
    }
    Navigator.of(context).pop(
      _ChapterProgressResult(
        page: _parsedPage,
        dontShowAgain: _dontShowAgain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final textTheme = Theme.of(context).textTheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.chapterDonePagePrompt),
        const SizedBox(height: 12),
        RdTextField(
          controller: _pageCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.metaPages,
            errorText: _pageError,
          ),
          onChanged: (_) => setState(() => _pageError = null),
          onSubmitted: (_) => _trySave(),
        ),
        const SizedBox(height: 4),
        RdCheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: _dontShowAgain,
          onChanged: (v) => setState(() => _dontShowAgain = v ?? false),
          title: Text(l.chapterDoneDontShowAgain, style: textTheme.bodySmall),
        ),
      ],
    );
    if (usesCupertinoChrome(context)) {
      return CupertinoAlertDialog(
        title: Text(l.chapterDoneTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: content,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: _popSkip,
            child: Text(l.actionNotNow),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: _canSave ? _trySave : null,
            child: Text(l.actionSave),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(l.chapterDoneTitle, style: textTheme.titleMedium),
      content: content,
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        RdButton.plain(
          onPressed: _popSkip,
          label: l.actionNotNow,
        ),
        RdButton.primary(
          onPressed: _canSave ? _trySave : null,
          icon: LucideIcons.save,
          label: l.actionSave,
        ),
      ],
    );
  }
}

class _BookSummary extends StatelessWidget {
  const _BookSummary(this.book, {this.onTap});

  final Book book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
            border: Border.all(color: cs.outline),
          ),
          child: Row(
            children: [
              BookCover(
                title: book.title,
                author: book.authors.firstOrNull,
                coverUrl: book.coverUrl,
                size: BookCoverSize.xs,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (book.authors.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.authors.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.colors.fg2),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: context.colors.fg3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
