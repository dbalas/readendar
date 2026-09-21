import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (
          call,
        ) async {
          switch (call.method) {
            case 'getWidgetData':
            case 'getInstalledWidgets':
              return null;
            default:
              return true;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  test(
    'bootstrap with local store syncs widgets without quotes circular dependency',
    () async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final covers = await Directory.systemTemp.createTemp('rd-guest-wdg');
      addTearDown(() => covers.delete(recursive: true));
      final store = LocalStore.memory(covers);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(_EmptyStorage()),
          localStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      final quotesSub = container.listen(quotesControllerProvider, (_, _) {});
      addTearDown(quotesSub.close);

      await container.read(sessionProvider.notifier).bootstrap();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(sessionProvider).user?.id, localGuestUserId);
      expect(container.read(quotesControllerProvider).hasValue, isTrue);
    },
  );

  test('bootstrap without JWT creates a local guest profile', () async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(_EmptyStorage()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    final user = container.read(sessionProvider).user;
    expect(user?.id, localGuestUserId);
    expect(container.read(dataPlaneProvider), DataPlane.local);
  });

  test('explicit api plane without JWT still bootstraps a local guest', () async {
    SharedPreferences.setMockInitialValues({dataPlanePrefsKey: 'api'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(_EmptyStorage()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(container.read(sessionProvider).user?.id, localGuestUserId);
    expect(container.read(dataPlaneProvider), DataPlane.local);
  });

  test('leftover JWT on the local plane is kept for import while the window is open',
      () async {
    SharedPreferences.setMockInitialValues({dataPlanePrefsKey: 'local'});
    final prefs = await SharedPreferences.getInstance();
    final storage = _LeftoverJwtStorage();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(container.read(sessionProvider).user?.id, localGuestUserId);
    expect(container.read(dataPlaneProvider), DataPlane.local);
    expect(storage.cleared, isFalse);
    expect(container.read(cloudImportAvailableProvider), isTrue);
  });

  test('clear on the local plane re-bootstraps the guest', () async {
    SharedPreferences.setMockInitialValues({dataPlanePrefsKey: 'local'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(_EmptyStorage()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();
    expect(container.read(sessionProvider).user?.id, localGuestUserId);

    await container.read(sessionProvider.notifier).clear();

    expect(container.read(sessionProvider).user?.id, localGuestUserId);
    expect(container.read(dataPlaneProvider), DataPlane.local);
  });

  test('setUser for a server account does not flip the data plane', () async {
    SharedPreferences.setMockInitialValues({dataPlanePrefsKey: 'local'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(_EmptyStorage()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();
    container
        .read(sessionProvider.notifier)
        .setUser(
          AppUser(
            id: 'server-user',
            email: 'a@b.c',
            displayName: 'Ada',
            preferredLocale: 'es',
            timezone: 'Europe/Madrid',
            onboardingCompletedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    await Future<void>.delayed(Duration.zero);

    expect(prefs.getString(dataPlanePrefsKey), 'local');
    expect(container.read(dataPlaneProvider), DataPlane.local);
  });

  test('persistLocalUser writes the guest profile json', () async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(_EmptyStorage()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();
    final next = container
        .read(sessionProvider)
        .user!
        .copyWith(displayName: 'Ada', autoCreateStatusEvents: true);
    await container.read(sessionProvider.notifier).persistLocalUser(next);

    expect(container.read(sessionProvider).user?.displayName, 'Ada');
    expect(
      container.read(sessionProvider).user?.autoCreateStatusEvents,
      isTrue,
    );
    final stored =
        jsonDecode(prefs.getString(localProfilePrefsKey)!)
            as Map<String, dynamic>;
    expect(stored['displayName'], 'Ada');
    expect(stored['id'], localGuestUserId);
  });
}

class _EmptyStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getCachedUser() async => null;

  @override
  Future<void> clear() async {}
}

class _LeftoverJwtStorage extends SecureTokenStorage {
  bool cleared = false;

  @override
  Future<String?> getAccess() async => cleared ? null : 'stale-access';

  @override
  Future<String?> getCachedUser() async => null;

  @override
  Future<void> clear() async {
    cleared = true;
  }
}
