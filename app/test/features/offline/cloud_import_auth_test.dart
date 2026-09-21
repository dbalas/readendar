import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/features/offline/cloud_import_auth.dart';

void main() {
  setUp(() => _Users.lastGetMe = false);

  test('missing tokens skip the network probe', () async {
    final status = await probeCloudImportToken(
      storage: _TokenStorage(),
      users: _Users(const Err(NetworkFailure('unused'))),
    );
    expect(status, CloudImportTokenStatus.missing);
    expect(_Users.lastGetMe, isFalse);
  });

  test('refresh-only storage still probes the API', () async {
    _Users.lastGetMe = false;
    final status = await probeCloudImportToken(
      storage: _TokenStorage(refresh: 'refresh'),
      users: _Users(Ok(_user())),
    );
    expect(status, CloudImportTokenStatus.valid);
    expect(_Users.lastGetMe, isTrue);
  });

  test('rejected leftover JWT is unauthorized', () async {
    final status = await probeCloudImportToken(
      storage: _TokenStorage(access: 'stale'),
      users: _Users(const Err(UnauthorizedFailure())),
    );
    expect(status, CloudImportTokenStatus.unauthorized);
  });

  test('transport failure is unreachable not missing', () async {
    final status = await probeCloudImportToken(
      storage: _TokenStorage(access: 'access'),
      users: _Users(const Err(NetworkFailure('offline'))),
    );
    expect(status, CloudImportTokenStatus.unreachable);
  });
}

AppUser _user() => AppUser(
  id: 'cloud-1',
  email: 'a@b.c',
  displayName: 'Ada',
  preferredLocale: 'es',
  timezone: 'Europe/Madrid',
  onboardingCompletedAt: DateTime.utc(2026),
  termsVersion: currentTermsVersion,
);

class _TokenStorage extends SecureTokenStorage {
  _TokenStorage({this.access, this.refresh});

  final String? access;
  final String? refresh;

  @override
  Future<String?> getAccess() async => access;

  @override
  Future<String?> getRefresh() async => refresh;
}

class _Users extends ApiUserRepository {
  _Users(this.me)
    : super(
        ApiClient(
          baseUrl: 'http://localhost',
          storage: _TokenStorage(),
          localeProvider: () => 'es',
        ),
      );

  final Result<AppUser> me;
  static bool lastGetMe = false;

  @override
  Future<Result<AppUser>> getMe() async {
    lastGetMe = true;
    return me;
  }
}
