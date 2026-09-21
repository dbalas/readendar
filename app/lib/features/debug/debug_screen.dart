import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/store/store_urls.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/data/local/local_book_repository.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/app_update/app_update_prompt.dart';
import 'package:readendar/features/product_feedback/product_feedback_modal.dart';
import 'package:readendar/features/debug/local_dev_seed.dart';
import 'package:readendar/features/debug/reading_chapter_archetype_preview_screen.dart';
import 'package:readendar/features/notifications/notification_schedule_screen.dart';
import 'package:readendar/features/onboarding/onboarding_tour_screen.dart';
import 'package:readendar/features/store_review/store_review_modal.dart';
import 'package:readendar/features/widget/widget_sync.dart';
import 'package:url_launcher/url_launcher.dart';

/// Debug-only maintenance screen. Reachable only from the debug button on the
/// profile screen (guarded by `kDebugMode`). Library wipes hit the local
/// SQLite store. Cloud-import JWT restore still talks to the hosted API
/// until 15 October 2026.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

enum _Busy { none, events, books, seed, importSession }

class _DebugScreenState extends ConsumerState<DebugScreen> {
  _Busy _busy = _Busy.none;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final running = _busy != _Busy.none;
    return Scaffold(
      appBar: AppBar(title: Text(l.debugTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            RdCard(
              backgroundColor: context.colors.warningSoftBg,
              child: Row(
                children: [
                  Icon(
                    LucideIcons.alertTriangle,
                    color: context.colors.warningSoftFg,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.debugWarning)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugOpenOnboardingHint,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openOnboarding,
                    icon: const Icon(LucideIcons.eye, size: 18),
                    label: Text(l.debugOpenOnboardingAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DebugAction(
              icon: LucideIcons.database,
              title: l.debugSeedLocalAction,
              hint: l.debugSeedLocalHint,
              busy: _busy == _Busy.seed,
              running: running,
              onPressed: _seedLocalLibrary,
            ),
            const SizedBox(height: 12),
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugScheduledRemindersHint,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _openNotificationSchedule,
                    icon: const Icon(LucideIcons.calendarClock, size: 18),
                    label: Text(l.debugScheduledRemindersAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugStoreReviewHint,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _previewStoreReview,
                    icon: const Icon(LucideIcons.star, size: 18),
                    label: Text(l.debugStoreReviewAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugProductFeedbackHint,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _previewProductFeedback,
                    icon: const Icon(LucideIcons.messageCircle, size: 18),
                    label: Text(l.debugProductFeedbackAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugAppUpdateHint,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _previewAppUpdate(generic: false),
                    icon: const Icon(LucideIcons.download, size: 18),
                    label: Text(l.debugAppUpdateAction),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _previewAppUpdate(generic: true),
                    icon: const Icon(LucideIcons.fileText, size: 18),
                    label: Text(l.debugAppUpdateGenericAction),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugArchetypePreviewHint,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  RdButton.primary(
                    expand: true,
                    onPressed: _openArchetypePreview,
                    icon: LucideIcons.orbit,
                    label: l.debugArchetypePreviewAction,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _DebugAction(
              icon: LucideIcons.calendarX,
              title: l.debugDeleteAllEventsAction,
              hint: l.debugDeleteAllEventsHint,
              busy: _busy == _Busy.events,
              running: running,
              onPressed: _deleteAllEvents,
            ),
            const SizedBox(height: 12),
            _DebugAction(
              icon: LucideIcons.bookX,
              title: l.debugDeleteAllBooksAction,
              hint: l.debugDeleteAllBooksHint,
              busy: _busy == _Busy.books,
              running: running,
              onPressed: _deleteAllBooks,
            ),
            const SizedBox(height: 12),
            RdCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.debugRestoreCloudImportHint,
                    style: TextStyle(color: context.colors.fg2),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: running ? null : _restoreCloudImportSession,
                    icon: _busy == _Busy.importSession
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: RdProgress(
                              color: context.colors.fgOnAccent,
                            ),
                          )
                        : const Icon(LucideIcons.key, size: 18),
                    label: Text(l.debugRestoreCloudImportAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Previews the first-run feature tour without touching any state — handy for
  /// iterating on the carousel after onboarding has already been completed.
  void _openOnboarding() {
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (ctx) =>
            OnboardingTourScreen(onFinish: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  void _openNotificationSchedule() {
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (_) => const NotificationScheduleScreen(),
      ),
    );
  }

  void _openArchetypePreview() {
    Navigator.of(context).push(
      rdPageRoute<void>(
        context,
        builder: (_) => const ReadingChapterArchetypePreviewScreen(),
      ),
    );
  }

  /// Preview-only: opens the soft store-review modal without writing decline /
  /// completed prefs, so debug iteration does not burn the real ask.
  Future<void> _previewStoreReview() async {
    final result = await showStoreReviewModal(context);
    if (result != StoreReviewModalResult.review || !mounted) return;
    final uri = storeReviewUri(platform: Theme.of(context).platform);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      final l = AppL10n.of(context);
      showRdToast(
        context,
        tone: RdToastTone.error,
        message: l.storeReviewOpenFailed,
      );
    }
  }

  /// Preview-only: same confirm chrome as launch, no snooze / store lookup.
  Future<void> _previewAppUpdate({required bool generic}) async {
    final l = AppL10n.of(context);
    await showAppUpdateConfirmDialog(
      context,
      releaseNotes: generic ? null : l.debugAppUpdateSampleNotes,
    );
  }

  /// Preview-only: opens the in-app feedback modal without writing
  /// visit / decline / completed prefs, so debug iteration does not burn the
  /// real ask. CTA mails hello@readendar.com, same as the production prompt.
  Future<void> _previewProductFeedback() async {
    await showProductFeedbackModalAndMail(context);
  }

  Future<void> _seedLocalLibrary() async {
    final l = AppL10n.of(context);
    final ok = await showConfirmDialog(
      context: context,
      icon: LucideIcons.database,
      title: l.debugSeedLocalConfirmTitle,
      message: l.debugSeedLocalConfirmBody,
      confirmLabel: l.debugSeedLocalAction,
      confirmIcon: LucideIcons.database,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = _Busy.seed);
    try {
      final summary = await seedLocalDevLibrary(ref.read(localStoreProvider));
      try {
        await ref.read(prefsStorageProvider).setDataPlane(DataPlane.local.name);
        ref.read(dataPlaneTickProvider.notifier).state++;
      } on Object {
        // Widget tests often omit SharedPreferences. Production always has it.
      }
      if (!mounted) return;
      setState(() => _busy = _Busy.none);
      ref
        ..invalidate(booksProvider)
        ..invalidate(upcomingEventsProvider)
        ..invalidateCalendarEvents()
        ..invalidatePersonalStats();
      unawaited(syncWidget(ref).catchError((Object _) => false));
      showRdToast(
        context,
        tone: RdToastTone.success,
        message: l.debugSeedLocalSuccess(summary.books, summary.events),
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = _Busy.none);
      showRdFailureToast(context, UnknownFailure(e.toString()));
    }
  }

  /// TEMP: restores leftover JWT for the debug import email so the download
  /// modal and card show again after a local wipe. Remove after cloud-import QA.
  Future<void> _restoreCloudImportSession() async {
    final l = AppL10n.of(context);
    setState(() => _busy = _Busy.importSession);
    final repo = ref.read(debugRepoProvider);
    if (repo == null) {
      if (mounted) setState(() => _busy = _Busy.none);
      return;
    }
    final result = await repo.issueCloudImportSession();
    if (!mounted) return;
    if (!result.isOk) {
      setState(() => _busy = _Busy.none);
      final failure = result.failure!;
      if (failure is NotFoundFailure) {
        showRdToast(
          context,
          tone: RdToastTone.error,
          message: l.debugRestoreCloudImportMissing,
        );
      } else {
        showRdFailureToast(context, failure);
      }
      return;
    }
    final session = result.value!;
    try {
      await ref
          .read(secureStorageProvider)
          .saveTokens(
            access: session.accessToken,
            refresh: session.refreshToken,
          );
      ref.read(cloudImportAvailableProvider.notifier).state = true;
      await ref.read(prefsStorageProvider).setMigrationPromptDismissed(false);
      await ref.read(prefsStorageProvider).setMigrationBannerHidden(false);
      try {
        ref.read(tabIndexProvider.notifier).state = 0;
      } on Object {
        // Widget tests may omit the tab provider.
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = _Busy.none);
      showRdFailureToast(context, UnknownFailure(e.toString()));
      return;
    }
    if (!mounted) return;
    setState(() => _busy = _Busy.none);
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (!mounted) return;
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: l.debugRestoreCloudImportSuccess,
    );
  }

  Future<void> _deleteAllEvents() async {
    final l = AppL10n.of(context);
    final ok = await showConfirmDialog(
      context: context,
      icon: LucideIcons.trash2,
      title: l.debugConfirmEventsTitle,
      message: l.debugConfirmEventsBody,
      confirmLabel: l.debugDeleteAllEventsAction,
      confirmIcon: LucideIcons.trash2,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = _Busy.events);
    try {
      final store = ref.read(localStoreProvider);
      final rows = await store.list(LocalCollections.events);
      for (final row in rows) {
        final id = row['id'] as String?;
        if (id != null && id.isNotEmpty) {
          await store.delete(LocalCollections.events, id);
        }
      }
      if (!mounted) return;
      setState(() => _busy = _Busy.none);
      _handleResult(Ok(rows.length), l.debugDeletedEvents);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = _Busy.none);
      showRdFailureToast(context, UnknownFailure(e.toString()));
    }
  }

  Future<void> _deleteAllBooks() async {
    final l = AppL10n.of(context);
    final ok = await showConfirmDialog(
      context: context,
      icon: LucideIcons.trash2,
      title: l.debugConfirmBooksTitle,
      message: l.debugConfirmBooksBody,
      confirmLabel: l.debugDeleteAllBooksAction,
      confirmIcon: LucideIcons.trash2,
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = _Busy.books);
    try {
      final store = ref.read(localStoreProvider);
      final books = LocalBookRepository(store);
      final listed = await books.listMine();
      final rows = listed.value ?? const [];
      for (final book in rows) {
        await books.delete(book.id);
      }
      if (!mounted) return;
      setState(() => _busy = _Busy.none);
      _handleResult(Ok(rows.length), l.debugDeletedBooks);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = _Busy.none);
      showRdFailureToast(context, UnknownFailure(e.toString()));
    }
  }

  /// Refreshes the library/calendar caches and reports the outcome.
  void _handleResult(Result<int> result, String Function(int n) success) {
    final messenger = ScaffoldMessenger.of(context);
    result.fold(
      (count) {
        // Both wipes can affect the calendar; a book wipe cascades its events.
        ref
          ..invalidate(booksProvider)
          ..invalidate(upcomingEventsProvider)
          ..invalidateCalendarEvents()
          ..invalidatePersonalStats();
        showRdToast(
          context,
          messenger: messenger,
          tone: RdToastTone.success,
          message: success(count),
        );
      },
      (f) => showRdFailureToast(context, f, messenger: messenger),
    );
  }
}

class _DebugAction extends StatelessWidget {
  const _DebugAction({
    required this.icon,
    required this.title,
    required this.hint,
    required this.busy,
    required this.running,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool busy;

  /// True while any action is in flight — disables the button (only one wipe
  /// runs at a time, so the busy action is also `running`).
  final bool running;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hint, style: TextStyle(color: c.fg2)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: running ? null : onPressed,
            style: FilledButton.styleFrom(backgroundColor: c.danger),
            icon: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: RdProgress(
                      color: c.fgOnAccent,
                    ),
                  )
                : Icon(icon, size: 18),
            label: Text(title),
          ),
        ],
      ),
    );
  }
}
