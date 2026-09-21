// Shared "add this widget to the home screen" orchestration, used by both the
// events add button (WidgetAddButton) and the quotes widget config screen.
//
// The flow, and why it's stateful:
//  1. For the quotes widget, write the in-app config as the pending config, so
//     the native side seeds the new instance from it (local prefs, no HTTP).
//  2. Android: fire the system one-tap pin prompt FIRST, before any HTTP.
//     ColorOS/Realme drop `requestPinAppWidget` once the tap's user-gesture
//     token expires across a network await. `requestPinWidget` only confirms
//     the OS *showed* its dialog; real completion arrives later via the native
//     successCallback (WidgetPinReceiver → consumeWidgetPinSuccess).
//  3. Provision the dedicated widget session + push the snapshot in parallel
//     (syncWidget / syncQuotesWidget) so a freshly added widget has a token.
//     Session bootstrap already mints this in the common case; a mint hiccup
//     must not block the pin dialog behind a generic error toast.
//  4. iOS (and Android launchers without the pin API): show the how-to sheet
//     and infer the add from a rise in this kind's installed count vs the
//     baseline captured when the sheet opened.
//
// Host requirement: mix into a `State` that also mixes in
// `WidgetsBindingObserver`, and call [initWidgetInstaller] / [disposeWidgetInstaller]
// from initState/dispose.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_sync.dart';

mixin WidgetInstaller<T extends StatefulWidget>
    on State<T>, WidgetsBindingObserver {
  // Android one-tap pin: true between showing the system pin dialog and
  // detecting the result. Resolution can't rely on a single lifecycle resume —
  // the launcher's pin dialog doesn't reliably pause/resume us and the native
  // successCallback flag can lag — so we POLL (see [_pinPollTimer]) for the flag
  // OR a rise in the installed count, whichever lands first.
  bool _awaitingAndroidPin = false;
  Timer? _pinPollTimer;

  // How-to-sheet flow (iOS always; Android only when the launcher lacks the pin
  // API): the user leaves the app to add the widget, so we infer success from a
  // rise in this kind's installed count vs this baseline.
  bool _awaitingSheetAdd = false;
  bool _howToOpen = false;
  int _baselineWidgetCount = 0;

  WidgetKind _installKind = WidgetKind.events;
  VoidCallback? _onInstalled;

  void initWidgetInstaller() => WidgetsBinding.instance.addObserver(this);
  void disposeWidgetInstaller() {
    _pinPollTimer?.cancel();
    // Short-circuit any in-flight resume probe so it can't do platform work
    // after the host is gone.
    _awaitingAndroidPin = false;
    _awaitingSheetAdd = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Fast path: on resume, probe immediately instead of waiting for the next
    // poll tick (the pin poll keeps running regardless).
    if (_awaitingAndroidPin) {
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (_awaitingAndroidPin && await _pinWasAdded()) _finishAndroidPin();
      });
    }
    if (_awaitingSheetAdd) {
      Future.delayed(const Duration(milliseconds: 400), _checkSheetAdded);
    }
  }

  /// Polls for the pin outcome independent of lifecycle events: resolves on the
  /// native success flag OR a rise in this kind's installed count. Gives up after
  /// ~1 min (dialog dismissed/ignored) so it never fires a false confirmation.
  void _startPinPolling() {
    _pinPollTimer?.cancel();
    var ticks = 0;
    _pinPollTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!_awaitingAndroidPin) {
        t.cancel();
        return;
      }
      if (await _pinWasAdded()) {
        _finishAndroidPin();
      } else if (++ticks >= 60) {
        t.cancel();
        _awaitingAndroidPin = false;
      }
    });
  }

  /// True once the pin actually completed — the native flag (fast) or, as a
  /// launcher-agnostic fallback, more installed widgets of this kind than before.
  Future<bool> _pinWasAdded() async {
    if (await consumeWidgetPinSuccess()) return true;
    final count = await installedWidgetCount(kind: _installKind);
    return count > _baselineWidgetCount;
  }

  /// Resolves the pin flow exactly once (both the poll tick and the resume probe
  /// can race here; the [_awaitingAndroidPin] flip is synchronous so the loser
  /// no-ops).
  void _finishAndroidPin() {
    if (!_awaitingAndroidPin) return;
    _awaitingAndroidPin = false;
    _pinPollTimer?.cancel();
    _pinPollTimer = null;
    if (mounted) _onAddSucceeded();
  }

  Future<void> _checkSheetAdded() async {
    if (!_awaitingSheetAdd) return;
    // iOS (and Android fallback): no completion callback exists — infer the add
    // from a higher installed count of this kind than when the sheet opened.
    final count = await installedWidgetCount(kind: _installKind);
    if (count <= _baselineWidgetCount) {
      // Not added (yet). If the user *removed* widgets, drop the baseline so a
      // later add is still detected relative to the current state.
      if (count < _baselineWidgetCount) _baselineWidgetCount = count;
      return;
    }
    _awaitingSheetAdd = false;
    // The how-to sheet is still on top; close it so the confirmation is visible.
    if (_howToOpen && mounted) Navigator.of(context).pop();
    if (mounted) _onAddSucceeded();
  }

  void _onAddSucceeded() {
    showRdToast(context, message: AppL10n.of(context).widgetPinnedToast);
    _onInstalled?.call();
  }

  /// Runs the add flow for [kind]. For the quotes widget, [pendingConfigJson]
  /// (the chosen quotes-widget configuration as JSON) is stored so the new instance
  /// adopts it. [onInstalled] fires after the success confirmation (e.g. to pop
  /// the config screen back to where the user was).
  Future<void> installWidget(
    WidgetRef ref,
    WidgetKind kind, {
    String? pendingConfigJson,
    VoidCallback? onInstalled,
  }) async {
    final l = AppL10n.of(context);
    _installKind = kind;
    _onInstalled = onInstalled;

    // Widgets live behind the signed-in shell. A missing session is a real
    // stop, not a "try the pin anyway" case.
    if (ref.read(sessionProvider).user == null) {
      showRdToast(context, tone: RdToastTone.error, message: l.errorGeneric);
      return;
    }

    Future<void> provision() async {
      try {
        await syncWidget(ref);
        if (kind == WidgetKind.quotes) await syncQuotesWidget(ref);
      } on Object catch (_) {}
    }

    Future<void> seedQuotesConfig() async {
      if (kind != WidgetKind.quotes || pendingConfigJson == null) return;
      await _seedQuotesPendingConfig(pendingConfigJson);
    }

    // Android: the pin prompt must be the first platform round-trip from this
    // tap. Awaiting HTTP first (the old provision-then-pin order) made ColorOS
    // / Realme refuse requestPinAppWidget and left the user with only the
    // generic error toast when mint/write hiccuped. Quotes pending-config is
    // written after the prompt is up, still before the user can confirm.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final shown = await requestPinWidget(kind: kind);
      if (!mounted) return;
      unawaited(seedQuotesConfig());
      unawaited(provision());
      if (shown) {
        _baselineWidgetCount = await installedWidgetCount(kind: kind);
        if (!mounted) return;
        _awaitingAndroidPin = true;
        _startPinPolling();
        return;
      }
    } else {
      await provision();
      await seedQuotesConfig();
      if (!mounted) return;
    }

    // iOS (and Android fallback): show the how-to sheet and watch for the add.
    _baselineWidgetCount = await installedWidgetCount(kind: kind);
    if (!mounted) return;
    _awaitingSheetAdd = true;
    _howToOpen = true;
    await _showHowTo(context, l);
    _howToOpen = false;
    _awaitingSheetAdd = false;
  }

  Future<void> _seedQuotesPendingConfig(String pendingConfigJson) async {
    await writeQuotesPendingConfig(pendingConfigJson);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await saveQuotesWidgetInstanceConfig(null, pendingConfigJson);
    }
  }

  Future<void> _showHowTo(BuildContext context, AppL10n l) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return showRdModalSheet<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.layoutGrid, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.widgetHowToTitle,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isAndroid ? l.widgetHowToAndroid : l.widgetHowToIos,
                style: TextStyle(color: c.fg1, height: 1.4),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: RdButton.primary(
                  onPressed: () => Navigator.of(ctx).pop(),
                  label: l.actionClose,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
