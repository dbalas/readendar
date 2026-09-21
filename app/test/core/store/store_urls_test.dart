import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/store/store_urls.dart';

void main() {
  test('iOS and macOS resolve to the App Store search URL', () {
    expect(
      storeReviewUri(platform: TargetPlatform.iOS).toString(),
      appStoreSearchUrl,
    );
    expect(storeReviewUsesAppStore(platform: TargetPlatform.macOS), isTrue);
  });

  test('Android resolves to the Play Store listing', () {
    expect(
      storeReviewUri(platform: TargetPlatform.android).toString(),
      googlePlayStoreUrl,
    );
    expect(storeReviewUsesAppStore(platform: TargetPlatform.android), isFalse);
  });
}
