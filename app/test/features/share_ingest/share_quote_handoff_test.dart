import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/share_ingest/share_quote_handoff.dart';
import 'package:readendar/features/widget/widget_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('share pending key matches native writers', () {
    expect(kSharePendingQuoteTextKey, 'share.pendingQuoteText');
  });

  test('take/stage stay crash-safe without a home_widget channel', () async {
    await stagePendingShareQuoteText('quote body');
    // Without a mock channel this is null; must not throw.
    final text = await takePendingShareQuoteText();
    expect(text, isNull);
  });

  group('takePendingShareQuoteText', () {
    const home = MethodChannel('home_widget');
    const secrets = MethodChannel('readendar/widget_secrets');
    final calls = <MethodCall>[];
    String? pending;
    var clearOk = true;

    setUp(() {
      calls.clear();
      pending = '  a quoted line  ';
      clearOk = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(home, (call) async {
            calls.add(call);
            switch (call.method) {
              case 'getWidgetData':
                return pending;
              case 'saveWidgetData':
                pending = (call.arguments as Map)['data'] as String?;
                return true;
              default:
                return true;
            }
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            calls.add(call);
            if (call.method == 'clearShared') {
              if (!clearOk) return false;
              pending = null;
              return true;
            }
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(home, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('Android clears the pending key via saveWidgetData(null)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await takePendingShareQuoteText(), 'a quoted line');
      final save = calls.singleWhere((c) => c.method == 'saveWidgetData');
      expect((save.arguments as Map)['id'], kSharePendingQuoteTextKey);
      expect((save.arguments as Map)['data'], isNull);
      expect(calls.where((c) => c.method == 'clearShared'), isEmpty);
    });

    test('iOS clears via native removeObject, never NSNull', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await takePendingShareQuoteText(), 'a quoted line');
      expect(
        calls.where((c) => c.method == 'saveWidgetData'),
        isEmpty,
        reason: 'iOS must not pass null to saveWidgetData (NSNull crash)',
      );
      final clear = calls.singleWhere((c) => c.method == 'clearShared');
      expect((clear.arguments as Map)['keys'], [kSharePendingQuoteTextKey]);
    });

    test('iOS keeps the pending quote when native delete fails', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      clearOk = false;
      expect(await takePendingShareQuoteText(), isNull);
      expect(pending, '  a quoted line  ');
    });
  });
}
