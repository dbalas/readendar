import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/auth/apple_auth.dart';

String _fakeJwt(Map<String, Object?> payload) {
  String b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  final header = b64(utf8.encode('{"alg":"none"}'));
  final body = b64(utf8.encode(jsonEncode(payload)));
  return '$header.$body.sig';
}

void main() {
  test('Apple sign-in UI is iOS-only', () {
    // Widget tests run on the host platform (usually macOS/linux). The product
    // gate must stay false off iOS so Android/web never show the button.
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      expect(kAppleSignInSupportedPlatform, isTrue);
    } else {
      expect(kAppleSignInSupportedPlatform, isFalse);
    }
  });

  test('emailFromIdentityToken reads the email claim', () {
    final token = _fakeJwt({
      'sub': 'apple-uid',
      'email': 'marina@privaterelay.appleid.com',
    });
    expect(
      AppleAuth.emailFromIdentityToken(token),
      'marina@privaterelay.appleid.com',
    );
  });

  test('emailFromIdentityToken returns null when claim missing', () {
    expect(AppleAuth.emailFromIdentityToken(_fakeJwt({'sub': 'x'})), isNull);
    expect(AppleAuth.emailFromIdentityToken('not-a-jwt'), isNull);
  });

  test('store entitlements enable Sign in with Apple on iOS builds', () {
    final appDirectory = Directory.current.path.endsWith('/app')
        ? Directory.current
        : Directory('${Directory.current.path}/app');
    for (final name in [
      'Runner/Runner.entitlements',
      'Runner/Runner.siwa-debug.entitlements',
    ]) {
      final xml = File('${appDirectory.path}/ios/$name').readAsStringSync();
      expect(xml, contains('com.apple.developer.applesignin'));
      expect(xml, contains('<string>Default</string>'));
    }
  });
}
