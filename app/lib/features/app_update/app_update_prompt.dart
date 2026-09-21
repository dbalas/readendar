import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/app_update/app_update_eligibility.dart';
import 'package:readendar/features/app_update/app_update_installed.dart';
import 'package:readendar/features/app_update/app_update_lookup.dart';
import 'package:readendar/features/app_update/app_update_play.dart';
import 'package:readendar/features/app_update/app_update_storefront.dart';
import 'package:readendar/features/app_update/itunes_lookup_client.dart';
import 'package:url_launcher/url_launcher.dart';

const appUpdateResumeCooldown = Duration(hours: 24);

bool _coldStartDone = false;
Future<bool>? _inFlight;

@visibleForTesting
void resetAppUpdatePromptGuard() {
  _coldStartDone = false;
  _inFlight = null;
}

/// Soft store-update prompt. Fail closed. Never blocks boot.
///
/// [fromResume] uses the 24h last-check stamp. Cold start runs once per isolate
/// unless a prior attempt was skipped for visibility / legal / intro.
Future<bool> maybeShowAppUpdatePrompt(
  BuildContext context,
  WidgetRef ref, {
  Duration settle = const Duration(milliseconds: 900),
  bool Function()? stillVisible,
  bool fromResume = false,
  DateTime? now,
  TargetPlatform? platform,
  PlayUpdateChecker? playChecker,
  ItunesLookup? lookup,
  InstalledVersionReader? installedVersion,
  Future<bool> Function(Uri uri)? launch,
}) {
  final existing = _inFlight;
  if (existing != null) return existing;
  final future = _run(
    context,
    ref,
    settle: settle,
    stillVisible: stillVisible,
    fromResume: fromResume,
    now: now,
    platform: platform,
    playChecker: playChecker,
    lookup: lookup,
    installedVersion: installedVersion,
    launch: launch,
  );
  _inFlight = future;
  return future.whenComplete(() {
    if (identical(_inFlight, future)) _inFlight = null;
  });
}

Future<bool> _run(
  BuildContext context,
  WidgetRef ref, {
  required Duration settle,
  required bool Function()? stillVisible,
  required bool fromResume,
  required DateTime? now,
  required TargetPlatform? platform,
  required PlayUpdateChecker? playChecker,
  required ItunesLookup? lookup,
  required InstalledVersionReader? installedVersion,
  required Future<bool> Function(Uri uri)? launch,
}) async {
  if (!fromResume && _coldStartDone) return false;
  if (!context.mounted) return false;

  final prefs = ref.read(prefsStorageProvider);
  if (!_isPromptableSurface(ref, prefs)) return false;
  if (!_canShowNow(context, stillVisible: stillVisible)) return false;

  final clock = now ?? DateTime.now();
  if (fromResume && !_resumeCooldownElapsed(prefs, clock)) {
    return false;
  }

  if (settle > Duration.zero) {
    await Future<void>.delayed(settle);
    if (!context.mounted) return false;
    if (!_isPromptableSurface(ref, prefs)) return false;
    if (!_canShowNow(context, stillVisible: stillVisible)) return false;
  }

  final resolvedPlatform = platform ?? Theme.of(context).platform;
  final locale = ref.read(localeProvider) ?? const Locale('es');
  final localeTag = localeToTag(locale);
  final country = itunesCountryForLocaleTag(localeTag);

  var play = PlayUpdateInfo.unavailable;
  ItunesLookupResult? store;
  var installed = '';
  try {
    if (resolvedPlatform == TargetPlatform.android) {
      play = await (playChecker ?? checkPlayUpdate)();
      if (!play.available) {
        await _markChecked(prefs, clock, coldStartDone: !fromResume);
        return false;
      }
      store = await (lookup ?? lookupItunes)(country: country);
    } else {
      final checks = await Future.wait<Object?>([
        (lookup ?? lookupItunes)(country: country),
        (installedVersion ?? readInstalledVersion)(),
      ]);
      store = checks[0] as ItunesLookupResult?;
      installed = (checks[1] as String?)?.trim() ?? '';
    }
    if (resolvedPlatform == TargetPlatform.android) {
      installed = (await (installedVersion ?? readInstalledVersion)()).trim();
    }
  } catch (_) {
    await _markChecked(prefs, clock, coldStartDone: !fromResume);
    return false;
  }

  if (installed.isEmpty) {
    await _markChecked(prefs, clock, coldStartDone: !fromResume);
    return false;
  }

  final offer = decideAppUpdate(
    platform: resolvedPlatform,
    installedVersion: installed,
    play: play,
    lookup: store,
    snoozedToken: prefs.getAppUpdateSnoozedVersion(),
    lookupNotesTrusted: itunesNotesTrustedForLocaleTag(localeTag),
  );

  if (offer == null) {
    await _markChecked(prefs, clock, coldStartDone: !fromResume);
    return false;
  }

  if (!context.mounted) return false;
  if (!_isPromptableSurface(ref, prefs)) return false;
  if (!_canShowNow(context, stillVisible: stillVisible)) return false;

  final l = AppL10n.of(context);
  final shouldUpdate = await showAppUpdateConfirmDialog(
    context,
    releaseNotes: offer.releaseNotes,
  );

  await prefs.setAppUpdateSnoozedVersion(offer.snoozeToken);
  await _markChecked(prefs, clock, coldStartDone: true);

  if (!shouldUpdate) return true;
  if (!context.mounted) return true;

  final messenger = ScaffoldMessenger.maybeOf(context);
  final opener =
      launch ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication);
  final ok = await opener(offer.updateUri);
  if (!ok && context.mounted) {
    showRdToast(
      context,
      tone: RdToastTone.error,
      message: l.storeReviewOpenFailed,
      messenger: messenger,
    );
  }
  return true;
}

/// Confirm chrome for the store-update prompt. Preview-safe: no prefs, no store.
Future<bool> showAppUpdateConfirmDialog(
  BuildContext context, {
  String? releaseNotes,
}) {
  final l = AppL10n.of(context);
  return showConfirmDialog(
    context: context,
    icon: LucideIcons.download,
    confirmIcon: LucideIcons.download,
    title: l.appUpdateTitle,
    message: releaseNotes ?? l.appUpdateBody,
    confirmLabel: l.appUpdateCta,
    cancelLabel: l.appUpdateLater,
    barrierDismissible: false,
  );
}

/// Login is idle enough to show the update prompt. Typing, keyboard, or the
/// code step skips without burning the cold-start guard.
bool appUpdateLoginSurfaceIdle({
  required bool codeStep,
  required bool loading,
  required bool hasEmailText,
  required bool hasCodeText,
  required bool keyboardOpen,
}) {
  if (codeStep || loading) return false;
  if (hasEmailText || hasCodeText || keyboardOpen) return false;
  return true;
}

Future<void> _markChecked(
  PrefsStorage prefs,
  DateTime clock, {
  required bool coldStartDone,
}) async {
  await prefs.setAppUpdateLastCheckMs(clock.millisecondsSinceEpoch);
  if (coldStartDone) _coldStartDone = true;
}

bool _resumeCooldownElapsed(PrefsStorage prefs, DateTime clock) {
  final last = prefs.getAppUpdateLastCheckMs();
  if (last <= 0) return true;
  return clock.millisecondsSinceEpoch - last >=
      appUpdateResumeCooldown.inMilliseconds;
}

bool _isPromptableSurface(WidgetRef ref, PrefsStorage prefs) {
  if (!prefs.isIntroSeen()) return false;
  final session = ref.read(sessionProvider);
  if (session.recoverableAuthFailure) return false;
  final user = session.user;
  if (user == null) return true;
  if (user.onboardingCompletedAt == null) return false;
  if (user.termsVersion != currentTermsVersion) return false;
  return true;
}

bool _canShowNow(
  BuildContext context, {
  bool Function()? stillVisible,
}) {
  if (!context.mounted) return false;
  if (stillVisible != null && !stillVisible()) return false;
  if (!(ModalRoute.of(context)?.isCurrent ?? false)) return false;
  return true;
}
