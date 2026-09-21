// The Flutter↔native handoff for the home-screen widget.
//
// Native targets render the JSON snapshot the app writes into the shared store
// (App Group on iOS, SharedPreferences on Android) via `home_widget`. Locale,
// theme, and the deep-link scheme go in that store too. Empty leftover token
// keys stay so upgrades do not mix a stale pair.
//
// `buildWidgetPayload` is pure (host-independent) so it can be unit-tested; the
// side-effecting writes go through `writeWidgetPayload`, which is a no-op-safe
// wrapper around the platform plugin.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/features/widget/widget_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iOS App Group id shared between the app and the widget extension. Must match
/// the group configured on both targets' entitlements.
const kWidgetAppGroupId = 'group.com.readendar.readendar';

/// Widget provider names registered natively.
const kWidgetIOSName = 'ReadendarWidget';
const kWidgetAndroidName = 'ReadendarWidgetProvider';

/// The quotes widget (second widget, per-instance native config).
const kQuotesWidgetIOSName = 'ReadendarQuotesWidget';
const kQuotesWidgetAndroidName = 'ReadendarQuotesWidgetProvider';
const kProgressWidgetIOSName = 'ReadendarProgressWidget';
const kProgressWidgetAndroidName = 'ReadendarProgressWidgetProvider';

/// Shared-storage keys the native widget reads. Kept short + stable; renaming
/// requires a matching change in the Swift/Kotlin widget code.
const kWidgetKeyAccess = 'wdg_access';
const kWidgetKeyRefresh = 'wdg_refresh';
const kWidgetKeyUserId = 'wdg_user';
const kWidgetKeyBaseUrl = 'wdg_base_url';
const kWidgetKeyLocale = 'wdg_locale';
const kWidgetKeyTheme = 'wdg_theme'; // 'light' | 'dark' | 'system'
const kWidgetKeyAppTheme = 'wdg_app_theme';
const kWidgetKeyScheme = 'wdg_scheme';
// The last-known summary snapshot native widgets cache. Written by the app
// on syncWidget.
const kWidgetKeyCachedSummary = 'wdg_cached_summary';
// The quotes snapshot the quotes widget renders/rotates from (JSON shape:
// [WidgetQuotesPayload] in widget_models.dart — the single Dart definition
// both native sides mirror). Written by the app after every quote mutation.
const kWidgetKeyQuotesCache = 'wdg_quotes_cache';
// The config the user chose in-app for the quotes widget they're about to add
// ([QuotesWidgetConfig] JSON). Written just before the add is triggered; the
// native side consumes it to seed the new instance's per-instance config
// (Android: the config activity applies it to the fresh appWidgetId then clears
// this; iOS: the AppIntent seeds its defaults from it). Kept short-lived — it's
// a handoff, not durable state.
const kWidgetKeyQuotesPendingConfig = 'wdg_quotes_pending_config';
// iOS ONLY: the single shared quotes-widget config the StaticConfiguration
// widget reads ([QuotesWidgetConfig] JSON). Written by the app on add and on
// tap-to-edit; a reload then updates the widget instantly. (Android stores
// config per-appWidgetId natively and ignores this key.)
const kWidgetKeyQuotesConfig = 'wdg_quotes_config';
const kWidgetKeyPendingOps = 'wdg_pending_ops';

/// The deep-link scheme the widget uses for per-element taps
/// (readendar://book/{id}, readendar://event/{id}).
const kWidgetDeepLinkScheme = 'readendar';

/// App Group / HomeWidgetPreferences key written by the iOS Share Extension
/// (and Android ACTION_SEND handoff) before opening `readendar://share/quote`.
const kSharePendingQuoteTextKey = 'share.pendingQuoteText';

/// Which home-screen widget an add/count operation targets. Each native
/// provider is pinned and counted independently.
enum WidgetKind {
  events,
  quotes,
  progress;

  /// Value passed to the native pin channel (`MainActivity.requestPinWidget`).
  String get pinProviderKey => switch (this) {
    WidgetKind.events => 'events',
    WidgetKind.quotes => 'quotes',
    WidgetKind.progress => 'progress',
  };

  /// iOS WidgetKit kind reported by `getInstalledWidgets`.
  String get iosKind => switch (this) {
    WidgetKind.events => kWidgetIOSName,
    WidgetKind.quotes => kQuotesWidgetIOSName,
    WidgetKind.progress => kProgressWidgetIOSName,
  };

  /// Android provider short class name reported by `getInstalledWidgets`.
  String get androidClassName => switch (this) {
    WidgetKind.events => kWidgetAndroidName,
    WidgetKind.quotes => kQuotesWidgetAndroidName,
    WidgetKind.progress => kProgressWidgetAndroidName,
  };

  /// Fully-qualified provider class name for `HomeWidget.updateWidget`.
  /// Short `androidName` is prefixed with the package; passing the qualified
  /// name avoids Class.forName misses when the two disagree.
  String get androidQualifiedName =>
      'com.readendar.readendar.$androidClassName';
}

/// The theme name the widget stores/reads: 'light' | 'dark' | 'system'.
String themeModeName(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'light',
  ThemeMode.dark => 'dark',
  ThemeMode.system => 'system',
};

/// Builds the flat string map handed to the native widget. Pure + testable.
Map<String, String> buildWidgetPayload({
  required String accessToken,
  required String refreshToken,
  required String userId,
  required String apiBaseUrl,
  required String locale,
  required String themeMode,
  required String appTheme,
}) => {
  kWidgetKeyAccess: accessToken,
  kWidgetKeyRefresh: refreshToken,
  kWidgetKeyUserId: userId,
  kWidgetKeyBaseUrl: apiBaseUrl,
  kWidgetKeyLocale: locale,
  kWidgetKeyTheme: themeMode,
  kWidgetKeyAppTheme: appTheme,
  kWidgetKeyScheme: kWidgetDeepLinkScheme,
};

/// Writes the compact summary snapshot native widgets render from. The app
/// pushes this after bootstrap, resume, and reading/progress/event mutations.
Future<void> writeWidgetSummaryCache(WidgetSummary summary) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await HomeWidget.saveWidgetData<String>(
      kWidgetKeyCachedSummary,
      jsonEncode(summary.toJson()),
    );
  } catch (e) {
    debugPrint('writeWidgetSummaryCache failed: $e');
  }
}

/// Writes [payload] into the shared store and reloads summary-backed widgets.
/// Best-effort: a widget-store hiccup never breaks app flow.
///
/// iOS bearer tokens go to the shared Keychain (`AfterFirstUnlockThisDeviceOnly`)
/// and are scrubbed from App Group defaults. Android still uses private prefs
/// with backup exclusions. Unsigned/free-team iOS falls back to defaults.
Future<bool> writeWidgetPayload(Map<String, String> payload) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    final iosSecrets = defaultTargetPlatform == TargetPlatform.iOS;
    for (final entry in payload.entries) {
      final isSecret =
          entry.key == kWidgetKeyAccess || entry.key == kWidgetKeyRefresh;
      if (iosSecrets && isSecret) continue;
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
    }
    if (iosSecrets) {
      final stored = await writeIosWidgetSecrets(
        access: payload[kWidgetKeyAccess] ?? '',
        refresh: payload[kWidgetKeyRefresh] ?? '',
      );
      if (!stored) {
        final cleared = await clearIosWidgetSecrets();
        if (!cleared) return false;
        await HomeWidget.saveWidgetData<String>(
          kWidgetKeyAccess,
          payload[kWidgetKeyAccess],
        );
        await HomeWidget.saveWidgetData<String>(
          kWidgetKeyRefresh,
          payload[kWidgetKeyRefresh],
        );
      } else {
        // home_widget 0.9.3 turns Dart null into NSNull; iOS then aborts
        // in `_CFPrefsValidateValueForKey`. Drop keys natively instead.
        final scrubbed = await removeWidgetData(const [
          kWidgetKeyAccess,
          kWidgetKeyRefresh,
        ]);
        if (!scrubbed) return false;
      }
    }
    await reloadWidget();
    await reloadProgressWidget();
    return true;
  } catch (e) {
    debugPrint('writeWidgetPayload failed: $e');
    return false;
  }
}

const kWidgetSecretsChannel = MethodChannel('readendar/widget_secrets');

/// Account-scoped App Group keys wiped on logout. Theme keys stay device-local.
const List<String> _kWidgetAccountDataKeys = [
  kWidgetKeyAccess,
  kWidgetKeyRefresh,
  kWidgetKeyUserId,
  kWidgetKeyBaseUrl,
  kWidgetKeyLocale,
  kWidgetKeyScheme,
  kWidgetKeyCachedSummary,
  kWidgetKeyQuotesCache,
  kWidgetKeyQuotesPendingConfig,
  kWidgetKeyQuotesConfig,
  kSharePendingQuoteTextKey,
];

/// Flushes App Group UserDefaults so WidgetKit snapshots see Dart writes.
/// home_widget does not call `synchronize()`; without this, getSnapshot can
/// run against a stale suite.
Future<void> flushIosWidgetDefaults() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;
  try {
    await kWidgetSecretsChannel.invokeMethod<bool>('flushDefaults');
  } catch (e) {
    debugPrint('flushIosWidgetDefaults failed: $e');
  }
}

/// Drops [keys] from the widget shared store without writing NSNull.
///
/// `HomeWidget.saveWidgetData(null)` is the documented Android delete. On iOS
/// the plugin stores NSNull, and CFPreferences abort the host app. iOS uses
/// native `removeObject` for both the unprefixed key and the legacy
/// `flutter.` copy.
Future<bool> removeWidgetData(List<String> keys) async {
  if (keys.isEmpty) return true;
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return clearIosWidgetSharedKeys(keys);
    }
    for (final key in keys) {
      await HomeWidget.saveWidgetData<String?>(key, null);
    }
    return true;
  } catch (e) {
    debugPrint('removeWidgetData failed: $e');
    return false;
  }
}

/// Removes [keys] and their legacy `flutter.` prefixed copies from the App
/// Group suite. Dart `HomeWidget.saveWidgetData(null)` stores NSNull on iOS
/// and crashes; this native path is the only safe iOS delete.
Future<bool> clearIosWidgetSharedKeys(List<String> keys) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return true;
  if (keys.isEmpty) return true;
  try {
    final ok = await kWidgetSecretsChannel.invokeMethod<bool>('clearShared', {
      'keys': keys,
    });
    return ok ?? false;
  } catch (e) {
    debugPrint('clearIosWidgetSharedKeys failed: $e');
    return false;
  }
}

Future<bool> writeIosWidgetSecrets({
  required String access,
  required String refresh,
}) async {
  try {
    final ok = await kWidgetSecretsChannel.invokeMethod<bool>('write', {
      'access': access,
      'refresh': refresh,
    });
    return ok ?? false;
  } catch (e) {
    debugPrint('writeIosWidgetSecrets failed: $e');
    return false;
  }
}

Future<bool> clearIosWidgetSecrets() async {
  try {
    final ok = await kWidgetSecretsChannel.invokeMethod<bool>('clear');
    return ok ?? false;
  } catch (e) {
    debugPrint('clearIosWidgetSecrets failed: $e');
    return false;
  }
}

Future<({String? access, String? refresh})> readIosWidgetSecrets() async {
  try {
    final raw = await kWidgetSecretsChannel.invokeMethod<dynamic>('read');
    if (raw is! Map) return (access: null, refresh: null);
    return (
      access: raw['access'] as String?,
      refresh: raw['refresh'] as String?,
    );
  } catch (e) {
    debugPrint('readIosWidgetSecrets failed: $e');
    return (access: null, refresh: null);
  }
}

/// Widget session tokens from one store. Incomplete Keychain/defaults pairs
/// are ignored so sync never mixes a leftover access with a fallback refresh.
Future<({String? access, String? refresh})> readWidgetSecrets() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final keychain = await readIosWidgetSecrets();
    if (_completeWidgetSecretPair(keychain.access, keychain.refresh)) {
      return keychain;
    }
  }
  final access = await HomeWidget.getWidgetData<String?>(kWidgetKeyAccess);
  final refresh = await HomeWidget.getWidgetData<String?>(kWidgetKeyRefresh);
  if (_completeWidgetSecretPair(access, refresh)) {
    return (access: access, refresh: refresh);
  }
  return (access: null, refresh: null);
}

bool _completeWidgetSecretPair(String? access, String? refresh) =>
    access != null &&
    access.isNotEmpty &&
    refresh != null &&
    refresh.isNotEmpty;

/// Appearance-picker path: write only `wdg_theme` and reload timelines.
///
/// Deliberately skips session mint / full payload sync so a Light/Dark tap
/// cannot take the heavy `syncWidget` path (App Group reads + createSession)
/// mid-MaterialApp rebuild. Fully try/caught — a WidgetKit hiccup must never
/// kill the host app.
Future<bool> pushWidgetTheme(ThemeMode mode) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await HomeWidget.saveWidgetData<String>(
      kWidgetKeyTheme,
      themeModeName(mode),
    );
    await reloadWidget();
    await reloadProgressWidget();
    // Quotes `auto` style reads wdg_theme; keep it in lockstep.
    await reloadQuotesWidget();
    return true;
  } catch (e) {
    debugPrint('pushWidgetTheme failed: $e');
    return false;
  }
}

/// Theme-picker path: persist the app palette for every native widget.
/// Fixed quote-widget styles deliberately ignore this value; `auto` follows it.
Future<bool> pushWidgetAppTheme(ReadendarThemeId theme) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await HomeWidget.saveWidgetData<String>(kWidgetKeyAppTheme, theme.wire);
    await reloadWidget();
    await reloadProgressWidget();
    await reloadQuotesWidget();
    return true;
  } catch (e) {
    debugPrint('pushWidgetAppTheme failed: $e');
    return false;
  }
}

/// Asks the OS to re-render the EVENTS widget (after summary changes).
Future<bool> reloadWidget() async {
  try {
    await flushIosWidgetDefaults();
    await HomeWidget.updateWidget(
      iOSName: kWidgetIOSName,
      androidName: kWidgetAndroidName,
      qualifiedAndroidName: WidgetKind.events.androidQualifiedName,
    );
    return true;
  } catch (e) {
    debugPrint('reloadWidget failed: $e');
    return false;
  }
}

Future<bool> reloadProgressWidget() async {
  try {
    await flushIosWidgetDefaults();
    await HomeWidget.updateWidget(
      iOSName: kProgressWidgetIOSName,
      androidName: kProgressWidgetAndroidName,
      qualifiedAndroidName: WidgetKind.progress.androidQualifiedName,
    );
    return true;
  } catch (e) {
    debugPrint('reloadProgressWidget failed: $e');
    return false;
  }
}

/// Stores the quotes-widget config the user just chose in-app, so the next
/// added instance adopts it (see [kWidgetKeyQuotesPendingConfig]). Best-effort.
Future<void> writeQuotesPendingConfig(String configJson) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await HomeWidget.saveWidgetData<String>(
      kWidgetKeyQuotesPendingConfig,
      configJson,
    );
  } catch (e) {
    debugPrint('writeQuotesPendingConfig failed: $e');
  }
}

/// Re-renders only the quotes widget (after a quotes-cache push).
Future<bool> reloadQuotesWidget() async {
  try {
    await flushIosWidgetDefaults();
    await HomeWidget.updateWidget(
      iOSName: kQuotesWidgetIOSName,
      androidName: kQuotesWidgetAndroidName,
      qualifiedAndroidName: WidgetKind.quotes.androidQualifiedName,
    );
    return true;
  } catch (e) {
    debugPrint('reloadQuotesWidget failed: $e');
    return false;
  }
}

/// Clears the widget's account data (logout), applies the safe device theme for
/// a signed-out session, and reloads it to the logged-out state. The dedicated
/// widget refresh family is revoked separately via logout.
/// Crucially this also drops the cached summary — otherwise the native widget,
/// finding no token on its next fetch, would fall back to the last-known
/// snapshot and keep showing the signed-out (or previous) account's data.
Future<bool> clearWidgetData({
  ReadendarThemeId appTheme = ReadendarThemeId.original,
}) async {
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final secretsCleared = await clearIosWidgetSecrets();
      if (!secretsCleared) return false;
    }
    final sharedCleared = await removeWidgetData(_kWidgetAccountDataKeys);
    if (!sharedCleared) return false;
    // Brightness and app palette remain device-scoped across sign-out.
    await HomeWidget.saveWidgetData<String>(
      kWidgetKeyAppTheme,
      appTheme.wire,
    );
    // Logout must reload every widget to its signed-out state.
    final eventsReloaded = await reloadWidget();
    final progressReloaded = await reloadProgressWidget();
    final quotesReloaded = await reloadQuotesWidget();
    return eventsReloaded && progressReloaded && quotesReloaded;
  } catch (e) {
    debugPrint('clearWidgetData failed: $e');
    return false;
  }
}

/// Talks to MainActivity's own pin-request handler (not the `home_widget`
/// plugin's — that one doesn't wire a successCallback, so it can never tell us
/// whether the user actually completed the system dialog; see
/// [consumeWidgetPinSuccess]).
const _widgetPinChannel = MethodChannel('readendar/widget_pin');

/// Shared-preferences key WidgetPinReceiver (native) sets once the OS confirms
/// the pin actually completed. Prefixed to match the `flutter.` convention the
/// shared_preferences plugin reads/writes under the hood.
const _kWidgetPinSuccessKey = 'wdg_pin_success';

/// Android one-tap "add to home screen" prompt (API 26+, launcher-dependent),
/// targeting [kind]'s provider. Returns false when unsupported so the caller can
/// fall back to a how-to sheet. No-op returning false on iOS (no programmatic
/// add exists there).
Future<bool> requestPinWidget({WidgetKind kind = WidgetKind.events}) async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final shown = await _widgetPinChannel.invokeMethod<bool>(
      'requestPinWidget',
      {'provider': kind.pinProviderKey},
    );
    return shown ?? false;
  } catch (e) {
    debugPrint('requestPinWidget failed: $e');
    return false;
  }
}

/// Persists an edited quotes-widget config and updates the widget immediately.
/// Platform-split, mirroring where each stores config:
///  - Android: per-instance — writes [appWidgetId]'s native prefs + re-renders
///    that instance (via the method channel). Requires a non-null [appWidgetId].
///  - iOS: the single shared config the StaticConfiguration widget reads —
///    writes [kWidgetKeyQuotesConfig] + reloads. [appWidgetId] is ignored.
/// Returns false on a missing id (Android) or any error.
Future<bool> saveQuotesWidgetInstanceConfig(
  int? appWidgetId,
  String configJson,
) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    if (appWidgetId == null) return false;
    try {
      final ok = await _widgetPinChannel.invokeMethod<bool>(
        'saveQuotesWidgetConfig',
        {'appWidgetId': appWidgetId, 'config': configJson},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('saveQuotesWidgetInstanceConfig(android) failed: $e');
      return false;
    }
  }
  // iOS (and any other platform): the single shared config.
  try {
    await HomeWidget.setAppGroupId(kWidgetAppGroupId);
    await HomeWidget.saveWidgetData<String>(kWidgetKeyQuotesConfig, configJson);
    await reloadQuotesWidget();
    return true;
  } catch (e) {
    debugPrint('saveQuotesWidgetInstanceConfig(shared) failed: $e');
    return false;
  }
}

/// Reads + clears the native pin-success flag. Returns true only when the OS
/// broadcast confirming the pin actually completed since the last check —
/// unlike [requestPinWidget]'s return value, this reflects genuine completion,
/// not just that the system dialog was shown.
Future<bool> consumeWidgetPinSuccess() async {
  final prefs = await SharedPreferences.getInstance();
  // WidgetPinReceiver (native) writes the flag straight to the prefs file, which
  // the plugin's in-memory cache (loaded at app start) never sees — reload first
  // or we'd read a stale `false` and miss every completed pin.
  await prefs.reload();
  final done = prefs.getBool(_kWidgetPinSuccessKey) ?? false;
  if (done) await prefs.remove(_kWidgetPinSuccessKey);
  return done;
}

/// Number of [kind] widgets currently placed on the home screen. On iOS (14+)
/// this is the count of installed widget *configurations* of that kind; on
/// Android it's the count of pinned instances of that provider. Best-effort:
/// returns 0 on any error or when the OS can't report it. Used to infer a
/// successful add on iOS, where there's no pin API or completion callback — the
/// caller compares this before/after the user visits the widget gallery.
Future<int> installedWidgetCount({WidgetKind kind = WidgetKind.events}) async {
  try {
    final widgets = await HomeWidget.getInstalledWidgets();
    return widgets.where((w) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return w.iOSKind == kind.iosKind;
      }
      // Android reports the provider's short class name (".ReadendarWidgetProvider").
      return w.androidClassName?.endsWith(kind.androidClassName) ?? false;
    }).length;
  } catch (e) {
    debugPrint('installedWidgetCount failed: $e');
    return 0;
  }
}
