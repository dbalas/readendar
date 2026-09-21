import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/app_update/app_update_play.dart';

void main() {
  test('parses Play channel payloads', () {
    expect(
      parsePlayUpdateInfo({'available': true, 'availableVersionCode': 9}),
      isA<PlayUpdateInfo>()
          .having((i) => i.available, 'available', isTrue)
          .having((i) => i.availableVersionCode, 'code', 9),
    );
    expect(parsePlayUpdateInfo({'available': false, 'availableVersionCode': 0}).available, isFalse);
    expect(parsePlayUpdateInfo({'available': true, 'availableVersionCode': 0}).availableVersionCode, isNull);
    expect(parsePlayUpdateInfo(true).available, isTrue);
    expect(parsePlayUpdateInfo(null).available, isFalse);
  });

  test('Play check timeout is unavailable', () async {
    final info = await checkPlayUpdate(
      timeout: Duration.zero,
      invoke: () => Completer<dynamic>().future,
    );
    expect(info.available, isFalse);
  });
}
