// P-12 — Ajustes de notificaciones (spec §16).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/reminder_offset.dart';
import 'package:readendar/core/widgets/option_selector.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/revalidate_on_enter.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/notification_reliability_card.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/quotes/quote_daily_notification.dart';

/// Rebuild tick for the quote-of-the-day rows: PrefsStorage isn't reactive, so
/// toggling invalidates this to re-read the flags.
final StateProvider<int> _quoteDailyTickProvider =
    StateProvider.autoDispose<int>((_) => 0);

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final prefsAsync = ref.watch(notificationPrefsProvider);
    final chapterPref = ref.watch(
      readingChapterNotificationPreferenceProvider,
    );
    return RevalidateOnEnter(
      providers: [notificationPrefsProvider],
      child: Scaffold(
        appBar: AppBar(title: Text(l.notifSettingsTitle)),
        body: SafeArea(
          top: false,
          child: Builder(
            builder: (context) {
              if (prefsAsync.isLoading && !prefsAsync.hasValue) {
                return RdProgress.centered();
              }
              final p =
                  prefsAsync.value ??
                  NotificationPreferences(
                    globalEnabled: true,
                    defaultReminderMinutesBefore: 1440,
                    allDayReminderHour: 9,
                  );
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const NotificationReliabilityCard(),
                  RdSwitchListTile(
                    title: Text(l.notifGlobalLabel),
                    subtitle: Text(l.notifGlobalSubtitle),
                    value: p.globalEnabled,
                    onChanged: (v) async {
                      await ref
                          .read(notificationRepoProvider)
                          .update(globalEnabled: v);
                      ref.invalidate(notificationPrefsProvider);
                      await _resync(ref, l, requestPermission: v);
                    },
                  ),
                  _ReadingChapterNotificationSetting(preference: chapterPref),
                  const Divider(),
                  ListTile(
                    title: Text(l.notifDefaultOffsetLabel),
                    subtitle: Text(
                      reminderOffsetLabel(l, p.defaultReminderMinutesBefore),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final v = await _pickMinutes(
                        context,
                        l,
                        p.defaultReminderMinutesBefore,
                      );
                      if (v != null) {
                        await ref
                            .read(notificationRepoProvider)
                            .update(defaultReminderMinutesBefore: v);
                        ref.invalidate(notificationPrefsProvider);
                        await _resync(ref, l);
                      }
                    },
                  ),
                  ListTile(
                    title: Text(l.notifAllDayHourLabel),
                    subtitle: Text(
                      l.notifAllDayHourValue('${p.allDayReminderHour}:00'),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final v = await showOptionSelectorSheet<int>(
                        context: context,
                        label: l.notifAllDayHourLabel,
                        value: p.allDayReminderHour,
                        items: List.generate(
                          24,
                          (h) => OptionSelectorItem<int>(
                            value: h,
                            label: '${h.toString().padLeft(2, '0')}:00',
                            icon: LucideIcons.clock,
                            color: context.colors.accent,
                          ),
                        ),
                      );
                      if (v != null) {
                        await ref
                            .read(notificationRepoProvider)
                            .update(allDayReminderHour: v);
                        ref.invalidate(notificationPrefsProvider);
                        await _resync(ref, l);
                      }
                    },
                  ),
                  const Divider(),
                  // Quote of the day (opt-in, local-only pref — see
                  // quote_daily_notification.dart). Rebuilt via the tick provider
                  // below since PrefsStorage isn't reactive.
                  Consumer(
                    builder: (context, ref, _) {
                      final user = ref.read(sessionProvider).user;
                      ref.watch(_quoteDailyTickProvider);
                      final storage = ref.read(prefsStorageProvider);
                      final enabled =
                          user != null && storage.getQuoteDailyEnabled(user.id);
                      final hour = user == null
                          ? 9
                          : storage.getQuoteDailyHour(user.id);
                      return Column(
                        children: [
                          RdSwitchListTile(
                            title: Text(l.quoteDailySettingTitle),
                            subtitle: Text(l.quoteDailySettingSubtitle),
                            value: enabled,
                            onChanged: user == null
                                ? null
                                : (v) async {
                                    await storage.setQuoteDailyEnabled(
                                      user.id,
                                      v,
                                    );
                                    // Bump — do not invalidate. invalidate()
                                    // recreates the tick at 0; Riverpod skips
                                    // notifying when the new value equals the
                                    // previous 0, so the Switch stayed visually
                                    // stuck while the pref flipped underneath.
                                    ref
                                        .read(
                                          _quoteDailyTickProvider.notifier,
                                        )
                                        .state++;
                                    await resyncDailyQuoteNotifications(
                                      ref,
                                      l,
                                      user,
                                      requestPermission: v,
                                    );
                                  },
                          ),
                          if (enabled)
                            ListTile(
                              title: Text(l.quoteDailyHourLabel),
                              subtitle: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () async {
                                final v = await showOptionSelectorSheet<int>(
                                  context: context,
                                  label: l.quoteDailyHourLabel,
                                  value: hour,
                                  items: List.generate(
                                    24,
                                    (h) => OptionSelectorItem<int>(
                                      value: h,
                                      label:
                                          '${h.toString().padLeft(2, '0')}:00',
                                      icon: LucideIcons.clock,
                                      color: context.colors.accent,
                                    ),
                                  ),
                                );
                                if (v != null) {
                                  await storage.setQuoteDailyHour(user.id, v);
                                  ref
                                      .read(
                                        _quoteDailyTickProvider.notifier,
                                      )
                                      .state++;
                                  if (context.mounted) {
                                    await resyncDailyQuoteNotifications(
                                      ref,
                                      l,
                                      user,
                                      requestPermission: true,
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      );
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      l.notifPermissionHint,
                      style: TextStyle(
                        color: context.colors.fg2,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _resync(
    WidgetRef ref,
    AppL10n l, {
    bool requestPermission = false,
  }) async {
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    await resyncLocalNotifications(
      ref,
      l,
      user,
      requestPermission: requestPermission,
    );
    // Reminder resyncs no longer touch quote-of-the-day notifications, so keep
    // them consistent with the current prefs here too: turning global
    // notifications OFF must stop the daily quote window immediately (not only
    // at the next app resume), and turning it back ON re-arms it.
    await resyncDailyQuoteNotifications(
      ref,
      l,
      user,
      requestPermission: requestPermission,
    );
  }

  Future<int?> _pickMinutes(
    BuildContext context,
    AppL10n l,
    int current,
  ) async {
    return showOptionSelectorSheet<int>(
      context: context,
      label: l.notifDefaultOffsetLabel,
      value: current,
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
    );
  }
}

class _ReadingChapterNotificationSetting extends ConsumerStatefulWidget {
  const _ReadingChapterNotificationSetting({required this.preference});

  final AsyncValue<bool> preference;

  @override
  ConsumerState<_ReadingChapterNotificationSetting> createState() =>
      _ReadingChapterNotificationSettingState();
}

class _ReadingChapterNotificationSettingState
    extends ConsumerState<_ReadingChapterNotificationSetting> {
  bool _saving = false;

  Future<void> _save(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await ref
        .read(readingChapterRepoProvider)
        .saveNotificationPreference(enabled);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isErr) {
      showRdFailureToast(context, result.failure!);
      return;
    }
    ref.invalidate(readingChapterNotificationPreferenceProvider);
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: AppL10n.of(context).readingChapterNotificationsSaved,
    );
  }

  Widget _errorTile(AppL10n l, Object error) {
    return ListTile(
      key: const Key('readingChapterNotifError'),
      title: Text(l.readingChapterNotificationsTitle),
      subtitle: Text(localizedErrorMessage(l, error)),
      trailing: RdButton.secondary(
        label: l.actionRetry,
        icon: LucideIcons.refreshCw,
        onPressed: () =>
            ref.invalidate(readingChapterNotificationPreferenceProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final preference = widget.preference;
    if (preference.hasError) return _errorTile(l, preference.error!);
    return preference.when(
      loading: () => RdSwitchListTile(
        title: Text(l.readingChapterNotificationsTitle),
        subtitle: Text(l.readingChapterNotificationsBody),
        value: false,
        onChanged: null,
      ),
      error: (e, _) => _errorTile(l, e),
      data: (enabled) => RdSwitchListTile(
        title: Text(l.readingChapterNotificationsTitle),
        subtitle: Text(l.readingChapterNotificationsBody),
        value: enabled,
        onChanged: _saving ? null : _save,
      ),
    );
  }
}
