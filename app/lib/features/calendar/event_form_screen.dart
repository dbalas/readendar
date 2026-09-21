// P-08 — Crear / editar evento (spec §6, §9.4).
//
// Full-screen form. For quick creation from a book detail, callers pass
// `bookId` + `defaultType`; the user can still change everything before saving.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/date_format.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/reminder_offset.dart';
import 'package:readendar/core/widgets/book_cover.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/form_save_action.dart';
import 'package:readendar/core/widgets/form_section.dart';
import 'package:readendar/core/widgets/option_selector.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/book_picker_screen.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_content.dart';
import 'package:readendar/features/widget/widget_sync.dart';
import 'package:uuid/uuid.dart';

/// Applies the post-save local-reminder decision without coupling the policy to
/// platform channels. Disabled event reminders, global-off, and a denied OS
/// permission all cancel the previous alarm; only the fully-enabled path
/// schedules.
@visibleForTesting
Future<void> reconcileSavedEventReminder({
  required ReadingEvent event,
  required Future<bool> Function() loadGlobalEnabled,
  required Future<void> Function() cancel,
  required Future<bool> Function() requestPermission,
  required Future<void> Function() schedule,
}) async {
  if (!event.reminderEnabled || event.reminderMinutesBefore == null) {
    await cancel();
    return;
  }
  if (!await loadGlobalEnabled()) {
    await cancel();
    return;
  }
  if (!await requestPermission()) {
    await cancel();
    return;
  }
  await schedule();
}

class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({
    super.key,
    this.existing,
    this.defaultBookId,
    this.defaultType,
    this.defaultDate,
  });

  /// Edit mode if non-null.
  final ReadingEvent? existing;
  final String? defaultBookId;
  final EventType? defaultType;
  final DateTime? defaultDate;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  late EventType _type;
  late TextEditingController _description;
  late TextEditingController _targetPage;
  late TextEditingController _targetChapter;
  late DateTime _date;
  TimeOfDay? _time;
  String? _tz;
  late String? _bookId;
  bool _reminderEnabled = true;
  int? _reminderMinutes = 1440;
  // Set once the user picks an offset, so an async prefs load doesn't clobber
  // a deliberate choice on a brand-new event.
  bool _reminderTouched = false;
  bool _saving = false;
  // Stable Idempotency-Key for create mode, generated once per form instance and
  // reused across save attempts so a retry after a landed-but-lost response
  // replays the original event instead of creating a duplicate. Null in edit mode.
  late final String? _idempotencyKey;
  String? _error;
  String? _bookError;
  String? _targetPageError;
  String? _targetChapterError;
  String? _reminderError;
  // Per-section collapse state (mirrors the book form's sections).
  bool _detailsOpen = true;
  bool _scheduleOpen = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idempotencyKey = e == null ? const Uuid().v4() : null;
    _type = e != null
        ? (EventType.fromString(e.type) ?? EventType.deadline)
        : (widget.defaultType ?? EventType.chapterMilestone);
    _description = TextEditingController(text: e?.description ?? '');
    _targetPage = TextEditingController(text: e?.targetPage?.toString() ?? '');
    _targetChapter = TextEditingController(
      text: e?.targetChapter?.toString() ?? '',
    );
    _date = e?.dateLocal ?? widget.defaultDate ?? DateTime.now();
    _bookId = e?.bookId ?? widget.defaultBookId;
    if (e?.timeLocal != null) {
      final parts = e!.timeLocal!.split(':');
      _time = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    _tz = e?.tz;
    _reminderEnabled = e?.reminderEnabled ?? true;
    if (e != null) {
      _reminderMinutes = e.reminderMinutesBefore ?? 1440;
    } else {
      // New event: seed the offset from the user's configured default (§16.4),
      // not a hard-coded 1440. Use the cached value if the prefs are warm;
      // otherwise fetch and apply it as long as the user hasn't picked since.
      final cached = ref.read(notificationPrefsProvider).value;
      _reminderMinutes = cached?.defaultReminderMinutesBefore ?? 1440;
      if (cached == null) {
        unawaited(
          ref
              .read(notificationPrefsProvider.future)
              .then((p) {
                if (mounted && !_reminderTouched) {
                  setState(
                    () => _reminderMinutes = p.defaultReminderMinutesBefore,
                  );
                }
              })
              .catchError((Object _) {
                // Prefs unavailable (offline/error) — keep the 1440 fallback.
              }),
        );
      }
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _targetPage.dispose();
    _targetChapter.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final user = ref.read(sessionProvider).user;
    if (user == null) {
      return;
    }
    const requiresBook = true;
    final targetPage = _maybeInt(_targetPage.text);
    final targetChapter = _maybeInt(_targetChapter.text);
    final valid = _validate(l, requiresBook, targetPage, targetChapter);
    if (!valid) {
      // _validate already painted the inline field error, but that can sit
      // below the fold (e.g. after switching the type to a milestone, whose
      // target field is empty). Surface a SnackBar too so saving never looks
      // like it silently did nothing.
      final msg =
          _bookError ??
          _targetChapterError ??
          _targetPageError ??
          _reminderError;
      if (msg != null) {
        showRdToast(context, message: msg);
      }
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final bookId = _bookId;
    final ownerId = user.id;

    final timeStr = _time != null
        ? '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'
        : null;
    final tz = _time != null ? (_tz ?? user.timezone) : null;
    final eventTitle = _type.label(l);
    final repo = ref.read(eventRepoProvider);
    final res = widget.existing == null
        ? await repo.create(
            ownerType: OwnerType.user,
            ownerId: ownerId,
            type: _type.backendValue,
            title: eventTitle,
            dateLocal: _date,
            description: _description.text.trim(),
            bookId: bookId,
            timeLocal: timeStr,
            tz: tz,
            targetChapter: _type == EventType.chapterMilestone
                ? targetChapter
                : null,
            targetPage: targetPage,
            reminderEnabled: _reminderEnabled,
            reminderMinutesBefore: _reminderEnabled ? _reminderMinutes : null,
            idempotencyKey: _idempotencyKey,
          )
        : await repo.update(widget.existing!.id, {
            'type': _type.backendValue,
            'title': eventTitle,
            'description': _description.text.trim(),
            'dateLocal':
                '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
            'timeLocal': timeStr,
            'tz': tz,
            'targetChapter': _type == EventType.chapterMilestone
                ? targetChapter
                : null,
            'targetPage': targetPage,
            'reminderEnabled': _reminderEnabled,
            'reminderMinutesBefore': _reminderEnabled ? _reminderMinutes : null,
          });

    if (!mounted) return;
    await res.fold(
      (ev) async {
        ref
          ..invalidate(upcomingEventsProvider)
          ..invalidateCalendarEvents()
          ..invalidate(booksProvider);
        // Keep the home-screen widget snapshot fresh after a create/edit.
        unawaited(syncWidget(ref).catchError((Object _) => false));
        // Reminder reconciliation is best-effort: a denied permission or a
        // scheduling error must never strand the user on the form. Run it for
        // BOTH branches so disabling a reminder/global notifications removes a
        // previously armed alarm instead of leaving stale state behind.
        try {
          // Capture messenger + copy before any await so a dispose mid-reconcile
          // can still surface the past-fire warning after pop.
          final messenger = ScaffoldMessenger.of(context);
          final l10n = AppL10n.of(context);
          final viewerTz = ref.read(sessionProvider).user?.timezone;
          NotificationPreferences? prefs;
          try {
            prefs = await _reconcileSavedReminder(ev);
          } on Object catch (error, stackTrace) {
            debugPrint(
              'Event ${ev.id} saved but reminder scheduling failed: '
              '$error\n$stackTrace',
            );
          }
          final warnMessage = _reminderCannotFireMessage(
            ev,
            prefs,
            l: l10n,
            viewerTz: viewerTz,
          );
          if (!mounted) {
            final messengerContext = messenger.context;
            if (warnMessage != null && messengerContext.mounted) {
              showRdToast(
                messengerContext,
                message: warnMessage,
                messenger: messenger,
              );
            }
            return;
          }
          Navigator.of(context).pop(true);
          // Toast after pop on the root messenger context — the form route's
          // messenger is torn down with the route.
          if (warnMessage != null) {
            showRdToast(
              messenger.context,
              message: warnMessage,
              messenger: messenger,
            );
          }
        } on Object catch (error, stackTrace) {
          debugPrint(
            'Event ${ev.id} saved but post-save UI failed: '
            '$error\n$stackTrace',
          );
          if (mounted) Navigator.of(context).pop(true);
        }
      },
      (f) async {
        setState(() {
          _saving = false;
          _error = localizedFailureMessage(AppL10n.of(context), f);
        });
      },
    );
  }

  Future<NotificationPreferences?> _reconcileSavedReminder(
    ReadingEvent ev,
  ) async {
    final user = ref.read(sessionProvider).user;
    if (user == null) return null;
    final l = AppL10n.of(context);
    NotificationPreferences? prefs;
    await reconcileSavedEventReminder(
      event: ev,
      loadGlobalEnabled: () async {
        // Resolve actual prefs so global-off is authoritative and a cold-start
        // doesn't silently fall back to the hardcoded all-day hour.
        prefs = await ref.read(notificationPrefsProvider.future);
        return prefs!.globalEnabled;
      },
      cancel: () => LocalNotifications.I.cancelForEvent(user.id, ev.id),
      requestPermission: () =>
          LocalNotifications.I.ensurePermission(requestIfNeeded: true),
      schedule: () {
        // Resolve the book title so the reminder body carries context.
        final content = notificationContentFor(
          ev,
          bookTitle: _resolveBookTitle(ev.bookId),
          l: l,
        );
        return LocalNotifications.I.scheduleForEvent(
          ev,
          ownerUserId: user.id,
          content: content,
          l: l,
          allDayReminderHour: prefs!.allDayReminderHour,
          viewerTz: user.timezone,
          notificationChannelName: l.notificationChannelName,
          notificationChannelDescription: l.notificationChannelDescription,
        );
      },
    );
    return prefs;
  }

  /// Returns the localized warning when a saved reminder cannot fire, using the
  /// same prefs hour that scheduling just used (never a stale default of 9).
  String? _reminderCannotFireMessage(
    ReadingEvent ev,
    NotificationPreferences? prefs, {
    required AppL10n l,
    required String? viewerTz,
  }) {
    if (!ev.reminderEnabled || ev.reminderMinutesBefore == null) return null;
    if (viewerTz == null) return null;
    if (LocalNotifications.I.canScheduleEventReminder(
      ev,
      allDayReminderHour: prefs?.allDayReminderHour ?? 9,
      viewerTz: viewerTz,
    )) {
      return null;
    }
    return l.eventReminderCannotFire;
  }

  /// Look up the selected book's title for the notification subtitle.
  String? _resolveBookTitle(String? bookId) {
    if (bookId == null) return null;
    final books = ref.read(booksProvider).value ?? const <Book>[];
    return books.where((b) => b.id == bookId).firstOrNull?.title;
  }

  int? _maybeInt(String s) => int.tryParse(s.trim());

  bool _validate(
    AppL10n l,
    bool requiresBook,
    int? targetPage,
    int? targetChapter,
  ) {
    final pageText = _targetPage.text.trim();
    final chapterText = _targetChapter.text.trim();
    setState(() {
      _error = null;
      _bookError = requiresBook && (_bookId == null || _bookId!.isEmpty)
          ? l.eventBookRequired
          : null;
      _targetPageError = null;
      _targetChapterError = null;
      _reminderError = _reminderEnabled && _reminderMinutes == null
          ? l.errFieldRequired
          : null;

      if (_type == EventType.chapterMilestone) {
        _targetChapterError = chapterText.isEmpty
            ? l.eventTargetChapterRequired
            : targetChapter == null || targetChapter <= 0
            ? l.eventTargetChapterInvalid
            : null;
      }

      if (_type == EventType.pageMilestone) {
        _targetPageError = pageText.isEmpty
            ? l.eventTargetPageRequired
            : targetPage == null || targetPage <= 0
            ? l.eventTargetPageInvalid
            : null;
      }
    });
    return _bookError == null &&
        _targetPageError == null &&
        _targetChapterError == null &&
        _reminderError == null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isEdit = widget.existing != null;
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final selectedBook = _bookId == null
        ? null
        : books.where((b) => b.id == _bookId).firstOrNull;
    final createsEvent = widget.existing == null;
    final showBookField = createsEvent;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l.eventEditTitle : l.eventCreateTitle),
        actions: [
          FormSaveAction(
            saving: _saving,
            onPressed: _save,
            tooltip: l.actionSave,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormSection(
              title: l.eventSectionDetails,
              open: _detailsOpen,
              onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
              children: [
                OptionSelector<EventType>(
                  label: l.eventTypeLabel,
                  hideLabel: true,
                  value: _type,
                  items: EventType.values
                      .map(
                        (t) => OptionSelectorItem<EventType>(
                          value: t,
                          label: t.label(l),
                          icon: t.icon,
                          color: t.colorOf(context),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _type = v;
                    _targetPageError = null;
                    _targetChapterError = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (showBookField) ...[
                  _BookField(
                    label: l.eventBookLabel,
                    required: true,
                    placeholder: l.eventBookPlaceholder,
                    book: selectedBook,
                    errorText: _bookError,
                    onTap: _showBookPicker,
                  ),
                ],
                if (_type == EventType.chapterMilestone) ...[
                  const SizedBox(height: 12),
                  RdTextField(
                    controller: _targetChapter,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      context,
                      label: l.eventTargetChapterLabel,
                      error: _targetChapterError,
                      required: true,
                    ),
                    // Live re-validation: once a save surfaced an error, typing a
                    // valid value clears it immediately instead of waiting for the
                    // next save attempt.
                    onChanged: (text) {
                      if (_targetChapterError == null) return;
                      final v = _maybeInt(text);
                      setState(
                        () => _targetChapterError = v != null && v > 0
                            ? null
                            : _targetChapterError,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '* ',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        TextSpan(text: l.chapterArbitraryHint),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.fg3,
                    ),
                  ),
                ],
                if (_type == EventType.pageMilestone) ...[
                  const SizedBox(height: 12),
                  RdTextField(
                    controller: _targetPage,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      context,
                      label: l.eventTargetPageLabel,
                      error: _targetPageError,
                      required: true,
                    ),
                    onChanged: (text) {
                      if (_targetPageError == null) return;
                      final v = _maybeInt(text);
                      setState(
                        () => _targetPageError = v != null && v > 0
                            ? null
                            : _targetPageError,
                      );
                    },
                  ),
                ],
                // Notes stays last in General for every event type.
                const SizedBox(height: 12),
                RdTextField(
                  controller: _description,
                  decoration: _inputDecoration(
                    context,
                    label: l.eventDescriptionLabel,
                    hint: l.bookOptionalHint,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            const SizedBox(height: 8),
            FormSection(
              title: l.eventSectionSchedule,
              open: _scheduleOpen,
              onToggle: () => setState(() => _scheduleOpen = !_scheduleOpen),
              children: [
                RdFormSelectField(
                  leading: const Icon(LucideIcons.calendar),
                  valueText: formatMediumDate(context, _date),
                  onTap: () async {
                    final picked = await showRdDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(_date.year - 2),
                      lastDate: DateTime(_date.year + 5),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 12),
                RdFormSelectField(
                  leading: const Icon(LucideIcons.clock),
                  valueText: _time == null
                      ? l.eventAllDayLabel
                      : _time!.format(context),
                  trailing: _time == null
                      ? null
                      : RdIconButton.compact(
                          icon: LucideIcons.x,
                          tooltip: l.actionClear,
                          onPressed: () => setState(() => _time = null),
                        ),
                  onTap: () async {
                    final picked = await _pickTime(context, _time);
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
                const SizedBox(height: 8),
                RdSwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.eventReminderLabel),
                  value: _reminderEnabled,
                  onChanged: (v) => setState(() => _reminderEnabled = v),
                ),
                if (_reminderEnabled) ...[
                  const SizedBox(height: 8),
                  OptionSelector<int>(
                    label: l.eventReminderOffsetLabel,
                    required: true,
                    value: _reminderMinutes ?? reminderOffsetPresets.first,
                    errorText: _reminderError,
                    items: reminderOffsetPresets
                        .map(
                          (m) => OptionSelectorItem<int>(
                            value: m,
                            label: reminderOffsetLabel(l, m),
                            icon: LucideIcons.bell,
                            color: context.colors.accent,
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _reminderTouched = true;
                      _reminderMinutes = v;
                    }),
                  ),
                ],
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: context.colors.danger),
              ),
            ],
            const SizedBox(height: 24),
            if (isEdit)
              RdButton.destructive(
                key: const ValueKey('eventFormDelete'),
                expand: true,
                icon: LucideIcons.trash2,
                label: l.actionDelete,
                onPressed: _saving
                    ? null
                    : () async {
                        final ok = await showConfirmDialog(
                          context: context,
                          message: l.eventConfirmDelete,
                          confirmLabel: l.actionDelete,
                          destructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        setState(() => _saving = true);
                        final r = await ref
                            .read(eventRepoProvider)
                            .delete(widget.existing!.id);
                        if (!context.mounted) return;
                        await r.fold(
                          (_) async {
                            unawaited(HapticFeedback.mediumImpact());
                            // Drop the pending reminder now; otherwise it keeps
                            // firing until the next cold-start resync.
                            final user = ref.read(sessionProvider).user;
                            if (user != null) {
                              await LocalNotifications.I.cancelForEvent(
                                user.id,
                                widget.existing!.id,
                              );
                            }
                            ref
                              ..invalidate(upcomingEventsProvider)
                              ..invalidateCalendarEvents();
                            // Refresh the widget after a delete too.
                            unawaited(
                              syncWidget(ref).catchError((Object _) => false),
                            );
                            if (!context.mounted) return;
                            showRdToast(
                              context,
                              tone: RdToastTone.success,
                              message: l.eventDeleteSuccess,
                            );
                            Navigator.of(context).pop(true);
                          },
                          (f) async {
                            if (!context.mounted) return;
                            setState(() => _saving = false);
                            showRdFailureToast(context, f);
                          },
                        );
                      },
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    String? error,
    bool required = false,
  }) => RdFormFieldLabel.decoration(
    context,
    labelText: label,
    required: required,
    decoration: InputDecoration(
      hintText: hint,
      errorText: error,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintStyle: TextStyle(color: context.colors.fgFaint),
    ),
  );

  Future<void> _showBookPicker() async {
    final selected = await Navigator.of(context).push<String>(
      rdPageRoute<String>(
        context,
        builder: (_) => BookPickerScreen(selectedBookId: _bookId),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _bookId = selected;
        _bookError = null;
      });
    }
  }

  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay? current) async {
    final initial = current ?? const TimeOfDay(hour: 19, minute: 0);
    if (usesCupertinoChrome(context)) {
      return showRdTimePicker(context: context, initialTime: initial);
    }
    return showRdModalSheet<TimeOfDay>(
      context: context,
      builder: (_) {
        var hour = initial.hour;
        var minute = initial.minute;
        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 188,
                  child: Row(
                    children: [
                      Expanded(
                        child: _NumberWheel(
                          value: hour,
                          count: 24,
                          onChanged: (v) {
                            setSheetState(() {
                              hour = v;
                            });
                          },
                        ),
                      ),
                      Text(
                        String.fromCharCode(58), // :
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: _NumberWheel(
                          value: minute,
                          count: 60,
                          onChanged: (v) {
                            setSheetState(() {
                              minute = v;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                RdButton.primary(
                  expand: true,
                  onPressed: () => Navigator.pop(
                    context,
                    TimeOfDay(hour: hour, minute: minute),
                  ),
                  label: AppL10n.of(context).actionConfirm,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookField extends StatelessWidget {
  const _BookField({
    required this.placeholder,
    required this.book,
    required this.onTap,
    this.label,
    this.required = false,
    this.errorText,
  });

  final String? label;
  final bool required;
  final String placeholder;
  final Book? book;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasError = errorText != null && errorText!.isNotEmpty;
    final tile = ListTile(
      leading: book == null
          ? const Icon(LucideIcons.bookOpen)
          : BookCover(
              title: book!.title,
              author: book!.authors.firstOrNull,
              coverUrl: book!.coverUrl,
              size: BookCoverSize.xs,
            ),
      title: Text(
        book?.title ?? placeholder,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: book == null ? context.colors.fgFaint : cs.onSurface,
        ),
      ),
      subtitle: book?.authors.isEmpty ?? true
          ? null
          : Text(
              book!.authors.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.colors.fgFaint),
            ),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
    );

    final field = usesCupertinoChrome(context)
        ? RdFormFieldShell(
            hasError: hasError,
            onTap: onTap,
            child: tile,
          )
        : RdCard(
            padding: EdgeInsets.zero,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: hasError
                    ? Border.all(color: cs.error, width: 1.2)
                    : null,
                borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
              ),
              child: tile,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          RdFormFieldLabel(
            text: label!,
            required: required,
            hasError: hasError,
          ),
          const SizedBox(height: 8),
        ],
        field,
        if (hasError) ...[
          const SizedBox(height: 6),
          RdFormFieldCaption(text: errorText!, isError: true),
        ],
      ],
    );
  }
}

class _NumberWheel extends StatelessWidget {
  const _NumberWheel({
    required this.value,
    required this.count,
    required this.onChanged,
  });

  final int value;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: FixedExtentScrollController(initialItem: value),
      itemExtent: 38,
      diameterRatio: 1.3,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) => Center(
          child: Text(
            index.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: ReadendarTokens.fontMono,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
