// Receives leftover magic-link deep links during the cloud-import window
// (until 15 October 2026), in two forms:
//   - https://api.readendar.com/auth/m/<token> — Universal/App Link from email
//     (plus https://readendar.com/auth/m/<token> for the browser fallback).
//   - readendar://m/<token> — custom scheme the fallback page's "Open in
//     Readendar" button uses (a same-domain https link tapped inside a browser
//     will not hand off to the app).
//
// Without this, the deep link routes the URL to the app but the app has nowhere
// to consume the token — the user has to paste it manually.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/utils/app_deep_link_hub.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/offline/cloud_import_auth.dart';

/// Set when a magic-link deep link fails to verify (expired/invalid token,
/// network error). The login screen reads + clears it to explain why the tap
/// didn't sign the user in — otherwise the failure is invisible (spec §4.2
/// links expire in 15 min, so this is a common path).
final magicLinkFailureProvider = StateProvider<Failure?>((_) => null);

/// Bumped when a magic-link deep link saves tokens. The login screen pops
/// back to Home so the download card can import. Local guest identity stays.
final magicLinkSignedInTickProvider = StateProvider<int>((_) => 0);

/// Exposes the deep-link consumer as a Riverpod provider so it can grab a
/// real `Ref` (vs. WidgetRef) and outlive any single widget. _Gate calls
/// `.attach()` once at app boot (shared [AppDeepLinkHub]).
final magicLinkDeepLinkProvider = Provider<MagicLinkDeepLink>(
  MagicLinkDeepLink.new,
);

class MagicLinkDeepLink {
  MagicLinkDeepLink(this._ref);
  final Ref _ref;
  bool _attached = false;

  /// Registers with the shared hub. Safe to call once at boot.
  void attach() {
    if (_attached) return;
    _attached = true;
    _ref.read(appDeepLinkHubProvider).register(handle);
  }

  Future<void> handle(Uri uri) async {
    final webHost = Uri.tryParse(_ref.read(webBaseUrlProvider))?.host;
    final apiHost = Uri.tryParse(_ref.read(apiBaseUrlProvider))?.host;
    final token = extractMagicLinkToken(
      uri,
      allowedHosts: {
        ?webHost,
        ?apiHost,
      }.where((h) => h.isNotEmpty).toSet(),
    );
    if (token == null) return;
    final status = await probeCloudImportToken(
      storage: _ref.read(secureStorageProvider),
      users: _ref.read(userRepoProvider),
    );
    if (status == CloudImportTokenStatus.valid) {
      // A usable leftover JWT is already in storage. Verifying would consume
      // the one-time email token for no gain. Stale/missing tokens must still
      // verify so the restored login can finish.
      return;
    }
    final locale = localeToTag(_ref.read(localeProvider) ?? const Locale('es'));
    final result = await _ref
        .read(authRepoProvider)
        .verifyMagicLink(token: token, locale: locale);
    result.fold(
      (_) => _ref.read(magicLinkSignedInTickProvider.notifier).state++,
      (f) => _ref.read(magicLinkFailureProvider.notifier).state = f,
    );
  }
}

/// Pull `<token>` out of a magic-link deep link, in either form:
///   - `readendar://m/<token>` — custom scheme used by the web fallback's "Open
///     in Readendar" button (a same-domain https link tapped inside the browser
///     won't hand off to the app). Ours by definition, so no host gate applies.
///   - `https://<host>/auth/m/<token>` — the Universal/App Link tapped from the
///     email (or anywhere outside a browser page).
///
/// For the https form, release builds require [allowedHosts] (API host for
/// emailed links, web host for the browser-fallback URL). Defense-in-depth
/// beyond the Android intent filter and the iOS Universal Links equivalent, so
/// a link delivered to some other domain can never feed a token into the auth
/// flow. Debug builds stay permissive because the host legitimately varies
/// locally (localhost vs 10.0.2.2 vs a tunnel).
String? extractMagicLinkToken(
  Uri uri, {
  Set<String>? allowedHosts,
}) {
  if (uri.scheme == 'readendar') {
    if (uri.host != 'm') return null;
    final segs = uri.pathSegments;
    if (segs.isEmpty) return null;
    final t = segs.first.trim();
    return t.isEmpty ? null : t;
  }
  if (uri.scheme != 'https' && !(kDebugMode && uri.scheme == 'http')) {
    return null;
  }
  final hosts = {...?allowedHosts}.where((h) => h.isNotEmpty).toSet();
  if (!kDebugMode && hosts.isNotEmpty && !hosts.contains(uri.host)) {
    return null;
  }
  final segs = uri.pathSegments;
  if (segs.length < 3) return null;
  if (segs[0] != 'auth' || segs[1] != 'm') return null;
  final t = segs[2].trim();
  return t.isEmpty ? null : t;
}
