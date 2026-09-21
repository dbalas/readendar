// Single AppLinks owner for Universal/App Links and custom-scheme opens.
// Feature modules register handlers; only this hub calls getInitialLink /
// uriLinkStream so cold start is not fan-out × N.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Called for every inbound URI. Handlers no-op when the URI is not theirs.
typedef AppDeepLinkHandler = FutureOr<void> Function(Uri uri);

final appDeepLinkHubProvider = Provider<AppDeepLinkHub>((_) => AppDeepLinkHub());

class AppDeepLinkHub {
  final _appLinks = AppLinks();
  final _handlers = <AppDeepLinkHandler>[];
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  void register(AppDeepLinkHandler handler) {
    if (_handlers.contains(handler)) return;
    _handlers.add(handler);
  }

  /// Call once at boot after all feature handlers are registered.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final initial = await _appLinks.getInitialLink();
    if (initial != null) await _dispatch(initial);
    _sub ??= _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_dispatch(uri)),
      onError: (Object e, StackTrace _) {
        if (kDebugMode) debugPrint('app deep-link hub error: $e');
      },
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
    _handlers.clear();
  }

  Future<void> _dispatch(Uri uri) async {
    for (final handler in List<AppDeepLinkHandler>.of(_handlers)) {
      try {
        await handler(uri);
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('app deep-link handler error: $e\n$st');
        }
      }
    }
  }
}
