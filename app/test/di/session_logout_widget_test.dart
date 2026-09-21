// Covers SessionNotifier.logout()'s widget clean-up: local shared-storage
// wipe via _clearPrivateSurfaces / clearWidgetData, then authRepo.logout().
// Neither step may fail logout even if widget cache writes error (those
// become a pending cleanup retried at bootstrap).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  final store = <String, Object?>{};
  var failWidgetWrites = false;

  Future<Object?> handler(MethodCall call) async {
    switch (call.method) {
      case 'setAppGroupId':
        return true;
      case 'saveWidgetData':
        if (failWidgetWrites) {
          throw PlatformException(code: 'widget-write-failed');
        }
        final args = call.arguments as Map;
        store[args['id'] as String] = args['data'];
        return true;
      case 'updateWidget':
        return true;
      default:
        return null;
    }
  }

  setUp(() {
    store.clear();
    failWidgetWrites = false;
    SharedPreferences.setMockInitialValues(const {});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, handler);
    // logout() also calls LocalNotifications.I.cancelAllForUser, which reaches
    // the flutter_local_notifications + flutter_timezone plugins. Stub their
    // channels (mirrors profile_editor_screen_test.dart's setup) AND register a
    // minimal mock FlutterLocalNotificationsPlatform.instance — without it,
    // `.initialize()`'s `resolvePlatformSpecificImplementation` throws
    // LateInitializationError reading the unset platform-interface singleton
    // (normally set by real platform plugin registration, which a bare `test()`
    // run never triggers).
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async => call.method == 'pendingNotificationRequests'
          ? <Map<Object?, Object?>>[]
          : null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => {'identifier': 'Europe/Madrid'},
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('logout succeeds, signs out, and clears local widget data', () async {
    final preferences = await SharedPreferences.getInstance();
    final callOrder = <String>[];
    final authRepo = _TrackingAuthRepository(callOrder);

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureStorageProvider.overrideWithValue(_NoopSecureStorage()),
        authRepoProvider.overrideWithValue(authRepo),
        sessionProvider.overrideWith(_TestSession.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(sessionProvider.notifier) as _TestSession;
    notifier.forceState(_user('user-1'));
    store[kWidgetKeyAccess] = 'widget-access';
    store[kWidgetKeyRefresh] = 'widget-refresh';

    final result = await notifier.logout();

    expect(result.isOk, isTrue);
    expect(callOrder, ['auth.logout']);
    expect(store[kWidgetKeyAccess], isNull);
    expect(store[kWidgetKeyRefresh], isNull);
    expect(container.read(sessionProvider).user, isNull);
  });

  test('logout downgrades a persisted premium widget palette', () async {
    SharedPreferences.setMockInitialValues(const {
      'theme_preset': 'ethereal',
    });
    final preferences = await SharedPreferences.getInstance();
    final callOrder = <String>[];
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        secureStorageProvider.overrideWithValue(_NoopSecureStorage()),
        authRepoProvider.overrideWithValue(_TrackingAuthRepository(callOrder)),
        sessionProvider.overrideWith(_TestSession.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(sessionProvider.notifier) as _TestSession;
    notifier.forceState(_user('user-ethereal'));
    store[kWidgetKeyAppTheme] = ReadendarThemeId.ethereal.wire;

    expect((await notifier.logout()).isOk, isTrue);
    expect(store[kWidgetKeyAppTheme], ReadendarThemeId.ethereal.wire);
    expect(
      container.read(readendarThemeProvider),
      ReadendarThemeId.ethereal,
      reason:
          'the device choice remains available after a later premium session',
    );
  });

  test(
    'logout still completes and clears local widget data',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final callOrder = <String>[];
      final authRepo = _TrackingAuthRepository(callOrder);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(_NoopSecureStorage()),
          authRepoProvider.overrideWithValue(authRepo),
          sessionProvider.overrideWith(_TestSession.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(sessionProvider.notifier) as _TestSession;
      notifier.forceState(_user('user-2'));
      store[kWidgetKeyAccess] = 'stale-access';

      final result = await notifier.logout();

      expect(result.isOk, isTrue);
      expect(callOrder, ['auth.logout']);
      expect(store[kWidgetKeyAccess], isNull);
      expect(container.read(sessionProvider).user, isNull);
    },
  );

  test(
    'failed private-surface cleanup is reported and retried at bootstrap',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final callOrder = <String>[];
      failWidgetWrites = true;
      final first = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(_NoopSecureStorage()),
          authRepoProvider.overrideWithValue(
            _TrackingAuthRepository(callOrder),
          ),
          sessionProvider.overrideWith(_TestSession.new),
        ],
      );
      final firstNotifier =
          first.read(sessionProvider.notifier) as _TestSession;
      firstNotifier.forceState(_user('cleanup-retry'));

      final result = await firstNotifier.logout();

      expect(result.isErr, isTrue);
      expect(first.read(sessionProvider).user, isNull);
      expect(
        PrefsStorage(preferences).isWidgetCleanupPending,
        isTrue,
      );
      first.dispose();

      failWidgetWrites = false;
      final retry = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(_NoopSecureStorage()),
          sessionProvider.overrideWith(_TestSession.new),
        ],
      );
      addTearDown(retry.dispose);

      await retry.read(sessionProvider.notifier).bootstrap();

      expect(
        PrefsStorage(preferences).isWidgetCleanupPending,
        isFalse,
      );
    },
  );

  test(
    'iOS Keychain clear failure keeps widget cleanup pending after logout',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('readendar/widget_secrets'),
            (call) async => false,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('readendar/widget_secrets'),
              null,
            );
      });

      final preferences = await SharedPreferences.getInstance();
      final callOrder = <String>[];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(_NoopSecureStorage()),
          authRepoProvider.overrideWithValue(
            _TrackingAuthRepository(callOrder),
          ),
          sessionProvider.overrideWith(_TestSession.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(sessionProvider.notifier) as _TestSession;
      notifier.forceState(_user('keychain-user'));

      final result = await notifier.logout();

      expect(result.isErr, isTrue);
      expect(container.read(sessionProvider).user, isNull);
      expect(PrefsStorage(preferences).isWidgetCleanupPending, isTrue);
    },
  );

  test(
    'auth logout clears local tokens without waiting for the server POST',
    () async {
      final storage = _MemorySecureStorage();
      await storage.saveTokens(access: 'access', refresh: 'refresh');
      final client = ApiClient(
        baseUrl: 'http://127.0.0.1:1',
        storage: storage,
        localeProvider: () => 'es',
      );
      final allowPost = Completer<void>();
      addTearDown(() {
        if (!allowPost.isCompleted) allowPost.complete();
      });
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            await allowPost.future;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
          },
        ),
      );

      final result = await ApiAuthRepository(client, storage).logout();

      expect(result.isOk, isTrue);
      expect(await storage.getAccess(), isNull);
      expect(await storage.getRefresh(), isNull);
      expect(
        allowPost.isCompleted,
        isFalse,
        reason: 'local sign-out must not wait on POST /v1/auth/logout',
      );
    },
  );
}

/// Minimal stand-in for the (never-registered-in-tests)
/// FlutterLocalNotificationsPlatform singleton. Doesn't match any concrete
/// platform type (Android/iOS/macOS/Linux), so
/// `resolvePlatformSpecificImplementation` returns null and `.initialize()`
/// short-circuits safely — this only exists to satisfy the `late` field read.
class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => const [];
}

class _TestSession extends SessionNotifier {
  _TestSession(super.ref);
  // Sets session state directly, bypassing setUser's widget sync
  // (irrelevant to logout behaviour, and would otherwise race
  // with home_widget's mocked channel across tests).
  void forceState(AppUser user) => state = SessionState(user: user);
}

class _TrackingAuthRepository extends ApiAuthRepository {
  _TrackingAuthRepository(this._order)
    : super(_fakeClient(), _NoopSecureStorage());

  final List<String> _order;

  @override
  Future<Result<void>> logout() async {
    _order.add('auth.logout');
    return const Ok(null);
  }
}

ApiClient _fakeClient() => ApiClient(
  baseUrl: 'http://localhost',
  storage: _NoopSecureStorage(),
  localeProvider: () => 'es',
);

class _NoopSecureStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;

  @override
  Future<String?> getRefresh() async => null;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {}

  @override
  Future<void> clear() async {}
}

class _MemorySecureStorage extends SecureTokenStorage {
  String? _access;
  String? _refresh;

  @override
  Future<String?> getAccess() async => _access;

  @override
  Future<String?> getRefresh() async => _refresh;

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}

AppUser _user(String id) => AppUser(
  id: id,
  email: '$id@example.com',
  displayName: id,
  preferredLocale: 'es',
  timezone: 'UTC',
  onboardingCompletedAt: null,
);
