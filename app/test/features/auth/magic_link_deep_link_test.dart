import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/auth/magic_link_deep_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final appDirectory = Directory.current.path.endsWith('/app')
      ? Directory.current
      : Directory('${Directory.current.path}/app');

  group('extractMagicLinkToken', () {
    test('pulls the token from /auth/m/<token> on the web host', () {
      final t = extractMagicLinkToken(
        Uri.parse('https://readendar.com/auth/m/abc123'),
        allowedHosts: {'readendar.com'},
      );
      expect(t, 'abc123');
    });

    test('ignores a locale query on the web fallback URL', () {
      final t = extractMagicLinkToken(
        Uri.parse('https://readendar.com/auth/m/abc123?locale=fr'),
        allowedHosts: {'readendar.com'},
      );
      expect(t, 'abc123');
    });

    test('accepts legacy API-host magic links', () {
      final t = extractMagicLinkToken(
        Uri.parse('https://api.readendar.com/auth/m/abc123'),
        allowedHosts: {'readendar.com', 'api.readendar.com'},
      );
      expect(t, 'abc123');
    });

    test('rejects a non-/auth/m/ path', () {
      expect(
        extractMagicLinkToken(
          Uri.parse('https://readendar.com/c/abc123'),
          allowedHosts: {'readendar.com'},
        ),
        isNull,
      );
    });

    test('rejects an empty https token', () {
      expect(
        extractMagicLinkToken(
          Uri.parse('https://readendar.com/auth/m/'),
          allowedHosts: {'readendar.com'},
        ),
        isNull,
      );
    });

    test('pulls the token from the readendar://m/<token> custom scheme', () {
      expect(
        extractMagicLinkToken(Uri.parse('readendar://m/tok9')),
        'tok9',
      );
    });

    test(
      'rejects a custom scheme that is not the magic-link path',
      () {
        expect(
          extractMagicLinkToken(Uri.parse('readendar://c/tok9')),
          isNull,
        );
      },
    );

    test('rejects an empty custom-scheme token', () {
      expect(
        extractMagicLinkToken(Uri.parse('readendar://m/')),
        isNull,
      );
    });

    // Tests run in debug mode (kDebugMode == true), where the https host gate is
    // intentionally permissive; assert that, not the release-only rejection.
    test('debug mode is permissive about the https host', () {
      expect(
        extractMagicLinkToken(
          Uri.parse('https://evil.example/auth/m/abc123'),
          allowedHosts: {'readendar.com'},
        ),
        'abc123',
      );
    });
  });

  test('native shells delegate deep links exclusively to app_links', () {
    String source(String path) =>
        File('${appDirectory.path}/$path').readAsStringSync();

    final android = source('android/app/src/main/AndroidManifest.xml');
    expect(
      android,
      contains('android:name="flutter_deeplinking_enabled"'),
    );
    expect(android, contains('android:value="false"'));

    final ios = source('ios/Runner/Info.plist');
    expect(ios, contains('<key>FlutterDeepLinkingEnabled</key>'));
    expect(ios, contains('<false/>'));
  });

  group('MagicLinkDeepLink.handle', () {
    Future<ProviderContainer> container({
      required SecureTokenStorage storage,
      required UserRepository users,
      required _TrackingAuth auth,
    }) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureStorageProvider.overrideWithValue(storage),
          userRepoProvider.overrideWithValue(users),
          authRepoProvider.overrideWithValue(auth),
        ],
      );
    }

    test('stale leftover JWT still verifies the email token', () async {
      final auth = _TrackingAuth();
      final c = await container(
        storage: _HandleStorage(access: 'stale'),
        users: _HandleUsers(const Err(UnauthorizedFailure())),
        auth: auth,
      );
      addTearDown(c.dispose);

      await c
          .read(magicLinkDeepLinkProvider)
          .handle(
            Uri.parse('readendar://m/tok9'),
          );

      expect(auth.verifyCount, 1);
      expect(c.read(magicLinkSignedInTickProvider), 1);
    });

    test('valid leftover JWT does not consume the email token', () async {
      final auth = _TrackingAuth();
      final c = await container(
        storage: _HandleStorage(access: 'valid'),
        users: _HandleUsers(
          Ok(
            AppUser(
              id: 'cloud-1',
              email: 'a@b.c',
              displayName: 'Ada',
              preferredLocale: 'es',
              timezone: 'Europe/Madrid',
              onboardingCompletedAt: DateTime.utc(2026),
              termsVersion: currentTermsVersion,
            ),
          ),
        ),
        auth: auth,
      );
      addTearDown(c.dispose);

      await c
          .read(magicLinkDeepLinkProvider)
          .handle(
            Uri.parse('readendar://m/tok9'),
          );

      expect(auth.verifyCount, 0);
      expect(c.read(magicLinkSignedInTickProvider), 0);
    });
  });
}

class _HandleStorage extends SecureTokenStorage {
  _HandleStorage({this.access});

  final String? access;

  @override
  Future<String?> getAccess() async => access;

  @override
  Future<String?> getRefresh() async => null;
}

class _HandleUsers extends ApiUserRepository {
  _HandleUsers(this.me)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _HandleStorage(),
          localeProvider: () => 'es',
        ),
      );

  final Result<AppUser> me;

  @override
  Future<Result<AppUser>> getMe() async => me;
}

class _TrackingAuth implements AuthRepository {
  int verifyCount = 0;

  @override
  Future<Result<MagicLinkRequestResult>> requestMagicLink({
    required String email,
    required String locale,
  }) async => const Err(UnknownFailure('unused'));

  @override
  Future<Result<AuthSession>> verifyMagicLink({
    required String token,
    required String locale,
  }) async {
    verifyCount += 1;
    return Ok(
      AuthSession(
        user: AppUser(
          id: 'review-1',
          email: 'a@b.c',
          displayName: 'Ada',
          preferredLocale: 'es',
          timezone: 'Europe/Madrid',
          onboardingCompletedAt: DateTime.utc(2026),
          termsVersion: currentTermsVersion,
        ),
        accessToken: 'access',
        refreshToken: 'refresh',
        isNewUser: false,
      ),
    );
  }

  @override
  Future<Result<AuthSession>> signInGoogle({
    required String idToken,
    required String locale,
  }) async => const Err(UnknownFailure('unused'));

  @override
  Future<Result<AuthSession>> signInApple({
    required String idToken,
    required String locale,
    String? name,
  }) async => const Err(UnknownFailure('unused'));

  @override
  Future<Result<void>> logout() async => const Ok(null);
}
