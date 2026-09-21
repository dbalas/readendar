import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/auth/google_auth.dart';

void main() {
  test('server client id defaults to the production web OAuth client', () {
    expect(
      kGoogleServerClientId,
      '724407297440-ntu5jglbivracdthm7fdpbgptrhq6lbv.apps.googleusercontent.com',
    );
  });

  test('iOS client id defaults match Info.plist GIDClientID', () {
    expect(
      kGoogleIosClientId,
      '724407297440-vtub67r9dkr4ksv6l5lkj0coi79qe84e.apps.googleusercontent.com',
    );
    final appDirectory = Directory.current.path.endsWith('/app')
        ? Directory.current
        : Directory('${Directory.current.path}/app');
    final plist = File(
      '${appDirectory.path}/ios/Runner/Info.plist',
    ).readAsStringSync();
    expect(plist, contains(kGoogleIosClientId));
    expect(plist, contains(kGoogleServerClientId));
  });

  test('iOS and server client ids are distinct audiences', () {
    // Regression: initializing with only serverClientId on iOS drops the
    // native GIDConfiguration (plugin requires clientId), so Google mints a
    // token for the iOS client and the backend rejects audience.
    expect(kGoogleIosClientId, isNot(kGoogleServerClientId));
    expect(defaultTargetPlatform, isNotNull);
  });
}
