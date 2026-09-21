import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// Opens the OS in-app review sheet (StoreKit / Play In-App Review).
///
/// Injectable for tests. Returns whether the native API reported availability
/// and accepted the request — the OS may still suppress the UI.
typedef InAppReviewRequester = Future<bool> Function();

/// Default production requester via [InAppReview].
Future<bool> requestNativeStoreReview() async {
  final review = InAppReview.instance;
  if (!await review.isAvailable()) return false;
  await review.requestReview();
  return true;
}

/// Whether this platform should prefer the native in-app review sheet over the
/// branded modal + store URL. Mobile Apple/Android only.
bool prefersNativeInAppReview({TargetPlatform? platform}) {
  final p = platform ?? defaultTargetPlatform;
  return p == TargetPlatform.iOS ||
      p == TargetPlatform.android ||
      p == TargetPlatform.macOS;
}
