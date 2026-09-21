// Fix-it banner for the notifications settings screen (RF-16). A scheduled
// reminder only fires while the app is closed if the OS lets it: notifications
// must be enabled, and on Android the app needs exact-alarm scheduling +
// (often) a battery-optimisation exemption. This card surfaces what is missing
// and links straight to the right system screen.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/notifications/notification_resync.dart';
import 'package:readendar/features/quotes/quote_daily_notification.dart';

class NotificationReliabilityCard extends ConsumerStatefulWidget {
  const NotificationReliabilityCard({super.key});

  @override
  ConsumerState<NotificationReliabilityCard> createState() =>
      _NotificationReliabilityCardState();
}

class _NotificationReliabilityCardState
    extends ConsumerState<NotificationReliabilityCard>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _notifsEnabled = true;
  bool _exactAllowed = true;
  Future<void>? _resyncFuture;

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when coming back from a system settings screen. If the user
    // granted a capability there, immediately arm reminders that were skipped
    // while it was denied.
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(resyncIfNewlyGranted: true));
    }
  }

  Future<void> _refresh({bool resyncIfNewlyGranted = false}) async {
    final notificationsWereEnabled = _notifsEnabled;
    final exactWasAllowed = _exactAllowed;
    var notifs = false;
    var exact = !_isAndroid;
    try {
      final states = await Future.wait<bool>([
        LocalNotifications.I.areNotificationsEnabled(),
        LocalNotifications.I.canScheduleExactAlarms(),
      ]);
      notifs = states[0];
      exact = states[1];
    } on Object catch (error, stackTrace) {
      // Service-level checks already fail closed, but keep this final guard so
      // a future platform implementation cannot strand the card in loading.
      debugPrint(
        'Notification reliability refresh failed: '
        '$error\n$stackTrace',
      );
    }
    if (!mounted) return;
    setState(() {
      _notifsEnabled = notifs;
      _exactAllowed = exact;
      _loading = false;
    });
    if (resyncIfNewlyGranted &&
        ((!notificationsWereEnabled && notifs) ||
            (!exactWasAllowed && exact))) {
      await _resync();
    }
  }

  Future<void> _enableNotifications() async {
    final granted = await LocalNotifications.I.ensurePermission(
      requestIfNeeded: true,
    );
    if (!granted) await openAppSettings();
    if (granted) await _resync();
    await _refresh();
  }

  Future<void> _allowExactAlarms() async {
    await LocalNotifications.I.requestExactAlarms();
    if (await LocalNotifications.I.canScheduleExactAlarms()) {
      await _resync();
    }
    await _refresh();
  }

  Future<void> _openBatterySettings() async {
    final opened = await LocalNotifications.I.openBatteryOptimizationSettings();
    if (!opened) await openAppSettings();
  }

  Future<void> _resync() async {
    final inFlight = _resyncFuture;
    if (inFlight != null) return inFlight;
    final future = _performResync();
    _resyncFuture = future;
    try {
      await future;
    } finally {
      if (identical(_resyncFuture, future)) _resyncFuture = null;
    }
  }

  Future<void> _performResync() async {
    final user = ref.read(sessionProvider).user;
    if (user == null || !mounted) return;
    final l = AppL10n.of(context);
    try {
      await resyncLocalNotifications(ref, l, user);
      if (mounted) {
        await resyncDailyQuoteNotifications(ref, l, user);
      }
    } on Object catch (error, stackTrace) {
      // The card will refresh its capability state and remain actionable. A
      // transient API failure should not turn a system-settings return into an
      // unhandled UI exception; the normal resume sync retries later.
      debugPrint(
        'Notification resync after permission change failed: '
        '$error\n$stackTrace',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final l = AppL10n.of(context);

    final needsNotifs = !_notifsEnabled;
    final needsExact = _isAndroid && !_exactAllowed;
    // iOS delivers scheduled notifications reliably while killed, so once
    // notifications are on there is nothing left to warn about there.
    if (!needsNotifs && !needsExact && !_isAndroid) {
      return const SizedBox.shrink();
    }

    final c = context.colors;
    final severe = needsNotifs || needsExact;
    final accent = severe ? c.warning : c.fg2;
    final bg = severe ? c.warningSoftBg : Theme.of(context).colorScheme.surface;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                severe ? LucideIcons.triangleAlert : LucideIcons.bellRing,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.notifBgTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.notifBgIntro,
            style: TextStyle(
              color: c.fg2,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (needsNotifs)
            _action(
              icon: LucideIcons.bell,
              label: l.notifBgEnableNotifs,
              filled: true,
              onTap: _enableNotifications,
            ),
          if (needsExact) ...[
            if (needsNotifs) const SizedBox(height: 8),
            _action(
              icon: LucideIcons.alarmClock,
              label: l.notifBgExactAlarms,
              filled: !needsNotifs,
              onTap: _allowExactAlarms,
            ),
          ],
          if (_isAndroid) ...[
            if (needsNotifs || needsExact) const SizedBox(height: 8),
            _action(
              icon: LucideIcons.batteryCharging,
              label: l.notifBgBattery,
              filled: false,
              onTap: _openBatterySettings,
            ),
            const SizedBox(height: 8),
            Text(
              l.notifBgBatteryHint,
              style: TextStyle(
                color: c.fg3,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    final child = filled
        ? RdButton.primary(
            onPressed: onTap,
            icon: icon,
            label: label,
          )
        : RdButton.secondary(
            onPressed: onTap,
            icon: icon,
            label: label,
          );
    return SizedBox(width: double.infinity, child: child);
  }
}
