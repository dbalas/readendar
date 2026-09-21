import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/di/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (call) async => true,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  test(
    'bootstrap with JWT stays a local guest and keeps the token for import',
    () async {
      final storage = _TokenStorage();
      final container = await _container(storage: storage);
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).bootstrap();

      final state = container.read(sessionProvider);
      expect(state.user?.id, localGuestUserId);
      expect(state.recoverableAuthFailure, isFalse);
      expect(storage.cleared, isFalse);
      expect(container.read(cloudImportAvailableProvider), isTrue);
      expect(container.read(dataPlaneProvider), DataPlane.local);
    },
  );

  test('bootstrap without a token creates a local guest', () async {
    final storage = _TokenStorage(token: null);
    final container = await _container(storage: storage);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(container.read(sessionProvider).user?.id, localGuestUserId);
    expect(container.read(cloudImportAvailableProvider), isTrue);
    expect(container.read(dataPlaneProvider), DataPlane.local);
  });

  test('leftover data_plane=api still uses the local product plane', () async {
    SharedPreferences.setMockInitialValues({'data_plane:v1': 'api'});
    final storage = _TokenStorage();
    final container = await _container(storage: storage);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(container.read(sessionProvider).user?.id, localGuestUserId);
    expect(container.read(dataPlaneProvider), DataPlane.local);
  });

  test('bootstrap hides cloud import after a finished import', () async {
    SharedPreferences.setMockInitialValues({
      'migration_banner_hidden:v1': true,
    });
    final storage = _TokenStorage();
    final container = await _container(storage: storage);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).bootstrap();

    expect(container.read(cloudImportAvailableProvider), isFalse);
    expect(storage.cleared, isTrue);
  });
}

Future<ProviderContainer> _container({
  required _TokenStorage storage,
}) async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      secureStorageProvider.overrideWithValue(storage),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

class _TokenStorage extends SecureTokenStorage {
  _TokenStorage({this.token = 'valid-access-token'});

  String? token;
  bool cleared = false;

  @override
  Future<String?> getAccess() async => token;

  @override
  Future<String?> getCachedUser() async => jsonEncode({
    'id': 'user-1',
    'email': 'a@b.c',
    'displayName': 'Ada',
    'preferredLocale': 'es',
    'timezone': 'Europe/Madrid',
  });

  @override
  Future<void> saveCachedUser(String json) async {}

  @override
  Future<void> clear() async {
    cleared = true;
    token = null;
  }
}
