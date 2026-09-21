import 'package:flutter/foundation.dart';

/// Google Play listing (stable application id).
const googlePlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.readendar.readendar';

/// App Store search until a stable numeric app id is configured.
const appStoreSearchUrl = 'https://apps.apple.com/us/search?term=Readendar';

/// Store listing URI for the current (or injected) platform.
Uri storeReviewUri({TargetPlatform? platform}) {
  final p = platform ?? defaultTargetPlatform;
  if (p == TargetPlatform.iOS || p == TargetPlatform.macOS) {
    return Uri.parse(appStoreSearchUrl);
  }
  return Uri.parse(googlePlayStoreUrl);
}

bool storeReviewUsesAppStore({TargetPlatform? platform}) {
  final p = platform ?? defaultTargetPlatform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}
