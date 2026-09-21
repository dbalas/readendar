import 'package:flutter/foundation.dart';
import 'package:readendar/core/store/store_urls.dart';
import 'package:readendar/features/app_update/app_update_lookup.dart';
import 'package:readendar/features/app_update/app_update_play.dart';
import 'package:readendar/features/app_update/app_update_version.dart';

/// Outcome of the store-availability + notes decision. Null means stay silent.
class AppUpdateOffer {
  const AppUpdateOffer({
    required this.snoozeToken,
    required this.updateUri,
    this.releaseNotes,
  });

  /// Persisted so this version is not asked again until the store moves on.
  final String snoozeToken;

  /// Store listing to open on Update. iOS prefers Lookup `trackViewUrl`.
  final Uri updateUri;

  /// Fastlane What's New from iTunes when it matches the available version.
  /// Null means the generic ARB body (lookup failed or Play is ahead of App Store).
  final String? releaseNotes;
}

/// Decides whether to prompt. Pure: no I/O.
AppUpdateOffer? decideAppUpdate({
  required TargetPlatform platform,
  required String installedVersion,
  required PlayUpdateInfo play,
  required ItunesLookupResult? lookup,
  required String? snoozedToken,
  bool lookupNotesTrusted = true,
}) {
  final onAndroid = platform == TargetPlatform.android;
  if (onAndroid) {
    if (!play.available) return null;
    return _androidOffer(
      installedVersion: installedVersion,
      play: play,
      lookup: lookup,
      snoozedToken: snoozedToken,
      lookupNotesTrusted: lookupNotesTrusted,
    );
  }

  if (lookup == null || lookup.version.isEmpty) return null;
  if (!isNewerVersion(lookup.version, installedVersion)) return null;
  final token = lookup.version;
  if (snoozedToken == token) return null;
  return AppUpdateOffer(
    snoozeToken: token,
    updateUri: _iosUri(lookup),
    releaseNotes: lookupNotesTrusted ? _usableNotes(lookup.releaseNotes) : null,
  );
}

AppUpdateOffer? _androidOffer({
  required String installedVersion,
  required PlayUpdateInfo play,
  required ItunesLookupResult? lookup,
  required String? snoozedToken,
  required bool lookupNotesTrusted,
}) {
  final itunes = lookup;
  final lookupNewer =
      itunes != null &&
      itunes.version.isNotEmpty &&
      isNewerVersion(itunes.version, installedVersion);
  final token = lookupNewer
      ? itunes.version
      : (play.availableVersionCode != null
            ? 'play:${play.availableVersionCode}'
            : 'play');
  if (snoozedToken == token) return null;
  return AppUpdateOffer(
    snoozeToken: token,
    updateUri: Uri.parse(googlePlayStoreUrl),
    releaseNotes: lookupNewer && lookupNotesTrusted
        ? _usableNotes(itunes.releaseNotes)
        : null,
  );
}

Uri _iosUri(ItunesLookupResult lookup) {
  final raw = lookup.trackViewUrl?.trim();
  if (raw != null && raw.isNotEmpty) {
    final uri = Uri.tryParse(raw);
    if (uri != null && isTrustedAppStoreUri(uri)) return uri;
  }
  return Uri.parse(appStoreSearchUrl);
}

/// App Store listing hosts only. Lookup `trackViewUrl` is otherwise discarded.
bool isTrustedAppStoreUri(Uri uri) {
  if (uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return host == 'apps.apple.com' ||
      host == 'itunes.apple.com' ||
      host.endsWith('.apps.apple.com') ||
      host.endsWith('.itunes.apple.com');
}

String? _usableNotes(String? notes) {
  final trimmed = notes?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
