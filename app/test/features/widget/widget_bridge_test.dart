import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildWidgetPayload maps every field to its shared-storage key', () {
    final p = buildWidgetPayload(
      accessToken: 'acc',
      refreshToken: 'ref',
      userId: 'u1',
      apiBaseUrl: 'https://api.readendar.com',
      locale: 'ca',
      themeMode: 'dark',
      appTheme: 'forest',
    );
    expect(p[kWidgetKeyAccess], 'acc');
    expect(p[kWidgetKeyRefresh], 'ref');
    expect(p[kWidgetKeyUserId], 'u1');
    expect(p[kWidgetKeyBaseUrl], 'https://api.readendar.com');
    expect(p[kWidgetKeyLocale], 'ca');
    expect(p[kWidgetKeyTheme], 'dark');
    expect(p[kWidgetKeyAppTheme], 'forest');
    expect(p[kWidgetKeyScheme], kWidgetDeepLinkScheme);
  });

  test('themeModeName maps ThemeMode to the stored string', () {
    expect(themeModeName(ThemeMode.light), 'light');
    expect(themeModeName(ThemeMode.dark), 'dark');
    expect(themeModeName(ThemeMode.system), 'system');
  });

  group('pushWidgetTheme', () {
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('writes only wdg_theme and reloads events/progress/quotes', () async {
      final ok = await pushWidgetTheme(ThemeMode.dark);
      expect(ok, isTrue);

      expect(calls.first.method, 'setAppGroupId');
      final saves = calls.where((c) => c.method == 'saveWidgetData').toList();
      expect(saves, hasLength(1));
      expect((saves.single.arguments as Map)['id'], kWidgetKeyTheme);
      expect((saves.single.arguments as Map)['data'], 'dark');

      final updates = calls.where((c) => c.method == 'updateWidget').toList();
      expect(
        updates.map((c) => (c.arguments as Map)['ios'] as String?),
        [
          kWidgetIOSName,
          kProgressWidgetIOSName,
          kQuotesWidgetIOSName,
        ],
      );
      expect(
        updates.map((c) => (c.arguments as Map)['qualifiedAndroidName']),
        [
          WidgetKind.events.androidQualifiedName,
          WidgetKind.progress.androidQualifiedName,
          WidgetKind.quotes.androidQualifiedName,
        ],
      );
    });

    test('swallows platform failures instead of throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'boom');
          });
      expect(await pushWidgetTheme(ThemeMode.light), isFalse);
    });
  });

  group('pushWidgetAppTheme', () {
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('writes palette and reloads every widget family', () async {
      expect(await pushWidgetAppTheme(ReadendarThemeId.aurora), isTrue);
      final saves = calls.where((c) => c.method == 'saveWidgetData').toList();
      expect(saves, hasLength(1));
      expect((saves.single.arguments as Map)['id'], kWidgetKeyAppTheme);
      expect((saves.single.arguments as Map)['data'], 'aurora');
      expect(calls.where((c) => c.method == 'updateWidget'), hasLength(3));
    });

    test('reports platform write failure', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'boom');
          });
      expect(await pushWidgetAppTheme(ReadendarThemeId.noir), isFalse);
    });
  });

  test('progress widget kind maps to both native registrations', () {
    expect(WidgetKind.progress.pinProviderKey, 'progress');
    expect(WidgetKind.progress.iosKind, kProgressWidgetIOSName);
    expect(
      WidgetKind.progress.androidClassName,
      kProgressWidgetAndroidName,
    );
    expect(
      WidgetKind.progress.androidQualifiedName,
      'com.readendar.readendar.$kProgressWidgetAndroidName',
    );
  });

  test('writeWidgetSummaryCache stores GET /v1/widget/summary JSON', () async {
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await writeWidgetSummaryCache(
      const WidgetSummary(
        readingBooks: [
          WidgetBook(id: 'b1', title: 'Dune', author: 'Herbert', coverUrl: ''),
        ],
        events: [],
      ),
    );

    expect(calls.first.method, 'setAppGroupId');
    final save = calls.singleWhere((c) => c.method == 'saveWidgetData');
    expect((save.arguments as Map)['id'], kWidgetKeyCachedSummary);
    expect((save.arguments as Map)['data'], contains('"id":"b1"'));
  });

  group('writeWidgetPayload', () {
    const home = MethodChannel('home_widget');
    const secrets = MethodChannel('readendar/widget_secrets');
    final calls = <MethodCall>[];
    var writeOk = true;
    var clearOk = true;

    setUp(() {
      calls.clear();
      writeOk = true;
      clearOk = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(home, (call) async {
            calls.add(call);
            return true;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            calls.add(call);
            if (call.method == 'clear') return clearOk;
            if (call.method == 'write') return writeOk;
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

    Map<String, String> payload() => buildWidgetPayload(
      accessToken: 'acc',
      refreshToken: 'ref',
      userId: 'u1',
      apiBaseUrl: 'https://api.readendar.com',
      locale: 'es',
      themeMode: 'system',
      appTheme: 'original',
    );

    test('Android still writes bearer tokens into shared prefs', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(await writeWidgetPayload(payload()), isTrue);
      final saved = calls
          .where((c) => c.method == 'saveWidgetData')
          .map((c) => (c.arguments as Map)['id'])
          .toSet();
      expect(saved, containsAll([kWidgetKeyAccess, kWidgetKeyRefresh]));
      expect(calls.where((c) => c.method == 'write'), isEmpty);
    });

    test(
      'iOS stores tokens on the secrets channel and scrubs defaults',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        expect(await writeWidgetPayload(payload()), isTrue);

        final write = calls.singleWhere((c) => c.method == 'write');
        expect((write.arguments as Map)['access'], 'acc');
        expect((write.arguments as Map)['refresh'], 'ref');

        final saves = calls.where((c) => c.method == 'saveWidgetData').toList();
        final secretSaves = saves.where((c) {
          final id = (c.arguments as Map)['id'];
          return id == kWidgetKeyAccess || id == kWidgetKeyRefresh;
        });
        expect(
          secretSaves,
          isEmpty,
          reason: 'iOS must not pass null to saveWidgetData (NSNull crash)',
        );
        expect(
          saves.every((c) => (c.arguments as Map)['data'] != null),
          isTrue,
        );

        final methods = calls.map((c) => c.method).toList();
        expect(methods, contains('flushDefaults'));
        expect(
          methods.indexOf('flushDefaults'),
          lessThan(methods.indexOf('updateWidget')),
        );
        expect(methods, contains('clearShared'));
        final clearShared = calls.singleWhere((c) => c.method == 'clearShared');
        expect(
          (clearShared.arguments as Map)['keys'],
          [kWidgetKeyAccess, kWidgetKeyRefresh],
        );
      },
    );

    test(
      'iOS Keychain success with shared-key scrub failure is not success',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secrets, (call) async {
              calls.add(call);
              if (call.method == 'clearShared') return false;
              if (call.method == 'write') return writeOk;
              return true;
            });
        expect(await writeWidgetPayload(payload()), isFalse);
        expect(calls.where((c) => c.method == 'updateWidget'), isEmpty);
      },
    );

    test('iOS falls back to defaults after clearing Keychain', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      writeOk = false;
      expect(await writeWidgetPayload(payload()), isTrue);
      expect(calls.where((c) => c.method == 'clear'), hasLength(1));
      final saves = {
        for (final c in calls.where((c) => c.method == 'saveWidgetData'))
          (c.arguments as Map)['id']: (c.arguments as Map)['data'],
      };
      expect(saves[kWidgetKeyAccess], 'acc');
      expect(saves[kWidgetKeyRefresh], 'ref');
    });

    test('iOS Keychain write+clear failure does not claim success', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      writeOk = false;
      clearOk = false;
      expect(await writeWidgetPayload(payload()), isFalse);
    });
  });

  group('readWidgetSecrets', () {
    const home = MethodChannel('home_widget');
    const secrets = MethodChannel('readendar/widget_secrets');
    final store = <String, Object?>{};
    var keychain = <String, Object?>{};

    setUp(() {
      store.clear();
      keychain = {};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(home, (call) async {
            switch (call.method) {
              case 'getWidgetData':
                return store[(call.arguments as Map)['id'] as String];
              default:
                return true;
            }
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            if (call.method == 'read') return keychain;
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

    test('uses a complete Keychain pair', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      keychain = {'access': 'kc-a', 'refresh': 'kc-r'};
      store[kWidgetKeyAccess] = 'def-a';
      store[kWidgetKeyRefresh] = 'def-r';
      final pair = await readWidgetSecrets();
      expect(pair.access, 'kc-a');
      expect(pair.refresh, 'kc-r');
    });

    test('ignores an incomplete Keychain pair and uses defaults', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      keychain = {'access': 'kc-a'};
      store[kWidgetKeyAccess] = 'def-a';
      store[kWidgetKeyRefresh] = 'def-r';
      final pair = await readWidgetSecrets();
      expect(pair.access, 'def-a');
      expect(pair.refresh, 'def-r');
    });

    test('returns nulls when neither store has a complete pair', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      keychain = {'access': 'kc-a'};
      store[kWidgetKeyRefresh] = 'def-r';
      final pair = await readWidgetSecrets();
      expect(pair.access, isNull);
      expect(pair.refresh, isNull);
    });
  });

  group('clearWidgetData', () {
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('clears account keys, resets app palette, then reloads', () async {
      expect(await clearWidgetData(), isTrue);

      final saveCalls = calls
          .where((c) => c.method == 'saveWidgetData')
          .toList();
      final clearedIds = saveCalls
          .where((c) => (c.arguments as Map)['data'] == null)
          .map((c) => (c.arguments as Map)['id'] as String)
          .toSet();
      expect(clearedIds, {
        kWidgetKeyAccess,
        kWidgetKeyRefresh,
        kWidgetKeyUserId,
        kWidgetKeyBaseUrl,
        kWidgetKeyLocale,
        kWidgetKeyScheme,
        // Also drops the cached summary + quotes cache so a signed-out widget
        // can't fall back to the previous account's last-known snapshot, and
        // the pending quotes-widget config handoff.
        kWidgetKeyCachedSummary,
        kWidgetKeyQuotesCache,
        kWidgetKeyQuotesPendingConfig,
        kWidgetKeyQuotesConfig,
        kSharePendingQuoteTextKey,
      });
      expect(clearedIds, isNot(contains(kWidgetKeyTheme)));
      expect(clearedIds, isNot(contains(kWidgetKeyAppTheme)));
      final appThemeWrite = saveCalls.singleWhere(
        (c) => (c.arguments as Map)['id'] == kWidgetKeyAppTheme,
      );
      expect(
        (appThemeWrite.arguments as Map)['data'],
        ReadendarThemeId.original.wire,
      );
      expect(
        calls.any((c) => c.method == 'updateWidget'),
        isTrue,
        reason: 'clearing must also reload the widget to the logged-out state',
      );
    });

    test(
      'preserves a caller-resolved standard palette across logout',
      () async {
        expect(
          await clearWidgetData(appTheme: ReadendarThemeId.jade),
          isTrue,
        );

        final appThemeWrite = calls
            .where((c) => c.method == 'saveWidgetData')
            .singleWhere(
              (c) => (c.arguments as Map)['id'] == kWidgetKeyAppTheme,
            );
        expect((appThemeWrite.arguments as Map)['data'], 'jade');
      },
    );

    test('reports a platform failure without throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'boom');
          });

      // Must not throw — clearWidgetData is called from logout, which can't be
      // allowed to fail because of a platform-channel hiccup.
      expect(await clearWidgetData(), isFalse);
    });
  });

  group('clearWidgetData iOS Keychain', () {
    const home = MethodChannel('home_widget');
    const secrets = MethodChannel('readendar/widget_secrets');
    final calls = <MethodCall>[];
    var secretsOk = true;
    var secretsThrow = false;

    setUp(() {
      calls.clear();
      secretsOk = true;
      secretsThrow = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(home, (call) async {
            calls.add(call);
            return true;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            calls.add(call);
            if (secretsThrow) {
              throw PlatformException(code: 'keychain-clear-failed');
            }
            return secretsOk;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(home, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('clears Keychain tokens before wiping prefs or reloading', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await clearWidgetData(), isTrue);
      final methods = calls.map((c) => c.method).toList();
      expect(methods.indexOf('clear'), greaterThanOrEqualTo(0));
      expect(
        methods.indexOf('clear'),
        lessThan(methods.indexOf('saveWidgetData')),
      );
      expect(methods, contains('clearShared'));
      expect(
        methods.indexOf('clearShared'),
        lessThan(methods.indexOf('updateWidget')),
      );
      expect(methods, contains('flushDefaults'));
      expect(calls.where((c) => c.method == 'updateWidget'), isNotEmpty);
      expect(
        calls.where(
          (c) =>
              c.method == 'saveWidgetData' &&
              (c.arguments as Map)['data'] == null,
        ),
        isEmpty,
        reason: 'iOS must not pass null to saveWidgetData (NSNull crash)',
      );
    });

    test('fails closed when App Group dual-key clear returns false', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            calls.add(call);
            if (call.method == 'clearShared') return false;
            return true;
          });
      expect(await clearWidgetData(), isFalse);
      expect(calls.where((c) => c.method == 'updateWidget'), isEmpty);
    });

    test('fails closed when Keychain clear returns false', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      secretsOk = false;
      expect(await clearWidgetData(), isFalse);
      expect(calls.where((c) => c.method == 'saveWidgetData'), isEmpty);
      expect(calls.where((c) => c.method == 'updateWidget'), isEmpty);
    });

    test('fails closed when Keychain clear throws', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      secretsThrow = true;
      expect(await clearWidgetData(), isFalse);
      expect(calls.where((c) => c.method == 'saveWidgetData'), isEmpty);
      expect(calls.where((c) => c.method == 'updateWidget'), isEmpty);
    });
  });

  group('removeWidgetData', () {
    const home = MethodChannel('home_widget');
    const secrets = MethodChannel('readendar/widget_secrets');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(home, (call) async {
            calls.add(call);
            return true;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            calls.add(call);
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

    test('Android deletes via saveWidgetData(null)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        await removeWidgetData(const [kWidgetKeyAccess, kWidgetKeyRefresh]),
        isTrue,
      );
      final saves = calls.where((c) => c.method == 'saveWidgetData').toList();
      expect(saves, hasLength(2));
      expect(
        saves.map((c) => (c.arguments as Map)['id']),
        [kWidgetKeyAccess, kWidgetKeyRefresh],
      );
      expect(saves.every((c) => (c.arguments as Map)['data'] == null), isTrue);
      expect(calls.where((c) => c.method == 'clearShared'), isEmpty);
    });

    test('iOS deletes via native removeObject, never NSNull', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(
        await removeWidgetData(const [kWidgetKeyAccess, kWidgetKeyRefresh]),
        isTrue,
      );
      expect(calls.where((c) => c.method == 'saveWidgetData'), isEmpty);
      final clear = calls.singleWhere((c) => c.method == 'clearShared');
      expect(
        (clear.arguments as Map)['keys'],
        [kWidgetKeyAccess, kWidgetKeyRefresh],
      );
    });

    test('iOS reports a native delete failure', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            calls.add(call);
            if (call.method == 'clearShared') return false;
            return true;
          });
      expect(await removeWidgetData(const [kWidgetKeyCachedSummary]), isFalse);
    });

    test('iOS reports a native delete throw', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secrets, (call) async {
            throw PlatformException(code: 'boom');
          });
      expect(await removeWidgetData(const [kWidgetKeyCachedSummary]), isFalse);
    });

    test('empty key list is a no-op success', () async {
      expect(await removeWidgetData(const []), isTrue);
      expect(calls, isEmpty);
    });
  });
}
