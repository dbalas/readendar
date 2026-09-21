import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:readendar/features/app_update/app_update_lookup.dart';

/// Play In-App Updates availability for this install.
class PlayUpdateInfo {
  const PlayUpdateInfo({required this.available, this.availableVersionCode});

  final bool available;
  final int? availableVersionCode;

  static const unavailable = PlayUpdateInfo(available: false);
}

typedef PlayUpdateChecker = Future<PlayUpdateInfo> Function();

const playAppUpdateChannel = MethodChannel('readendar/play_app_update');

/// On-device Play Core check. Non-Android and any failure / timeout → unavailable.
Future<PlayUpdateInfo> checkPlayUpdate({
  Duration timeout = appUpdateCheckTimeout,
  Future<dynamic> Function()? invoke,
}) async {
  if (invoke == null && defaultTargetPlatform != TargetPlatform.android) {
    return PlayUpdateInfo.unavailable;
  }
  try {
    final pending =
        invoke?.call() ?? playAppUpdateChannel.invokeMethod<dynamic>('check');
    final raw = await pending.timeout(timeout);
    return parsePlayUpdateInfo(raw);
  } catch (_) {
    return PlayUpdateInfo.unavailable;
  }
}

@visibleForTesting
PlayUpdateInfo parsePlayUpdateInfo(dynamic raw) {
  if (raw is Map) {
    final available = raw['available'] == true;
    final code = raw['availableVersionCode'];
    final parsed = code is int ? code : int.tryParse('$code');
    return PlayUpdateInfo(
      available: available,
      availableVersionCode: (parsed == null || parsed == 0) ? null : parsed,
    );
  }
  if (raw == true) return const PlayUpdateInfo(available: true);
  return PlayUpdateInfo.unavailable;
}
