import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';

void main() {
  late List<String> paths;
  late Map<String, String> stored;

  ApiAuthRepository repoWith(
    Response<Map<String, dynamic>> Function(RequestOptions) reply,
  ) {
    stored = {};
    final storage = _MemoryTokens(stored);
    final api = ApiClient(
      baseUrl: 'http://localhost',
      storage: storage,
      localeProvider: () => 'es',
    );
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add(options.path);
          try {
            handler.resolve(reply(options));
          } on Object catch (e) {
            handler.reject(
              DioException(requestOptions: options, error: e),
            );
          }
        },
      ),
    );
    return ApiAuthRepository(api, storage);
  }

  setUp(() {
    paths = <String>[];
  });

  test('requestMagicLink posts email and locale', () async {
    final repo = repoWith((options) {
      expect(options.data, {'email': 'a@b.c', 'locale': 'es'});
      return Response(
        requestOptions: options,
        data: {'sent': true, 'devCode': 'ABC234XY'},
        statusCode: 200,
      );
    });

    final result = await repo.requestMagicLink(email: 'a@b.c', locale: 'es');
    expect(result.isOk, isTrue);
    expect(result.value?.devCode, 'ABC234XY');
    expect(paths, ['/v1/auth/magic-link/request']);
  });

  test('verifyMagicLink persists tokens', () async {
    final repo = repoWith((options) {
      return Response(
        requestOptions: options,
        data: _sessionJson(),
        statusCode: 200,
      );
    });

    final result = await repo.verifyMagicLink(token: 'ABC234XY', locale: 'es');
    expect(result.isOk, isTrue);
    expect(stored['access'], 'access-qa');
    expect(stored['refresh'], 'refresh-qa');
    expect(paths, ['/v1/auth/magic-link/verify']);
  });

  test('signInGoogle persists tokens', () async {
    final repo = repoWith((options) {
      expect(options.data, {'idToken': 'gid', 'locale': 'es'});
      return Response(
        requestOptions: options,
        data: _sessionJson(),
        statusCode: 200,
      );
    });

    final result = await repo.signInGoogle(idToken: 'gid', locale: 'es');
    expect(result.isOk, isTrue);
    expect(stored['access'], 'access-qa');
    expect(paths, ['/v1/auth/oauth/google']);
  });

  test('signInApple sends an optional name', () async {
    final repo = repoWith((options) {
      expect(options.data, {
        'idToken': 'aid',
        'locale': 'es',
        'name': 'Ada',
      });
      return Response(
        requestOptions: options,
        data: _sessionJson(),
        statusCode: 200,
      );
    });

    final result = await repo.signInApple(
      idToken: 'aid',
      locale: 'es',
      name: 'Ada',
    );
    expect(result.isOk, isTrue);
    expect(paths, ['/v1/auth/oauth/apple']);
  });
}

Map<String, dynamic> _sessionJson() => {
  'user': {
    'id': 'user-1',
    'email': 'qa@example.com',
    'displayName': 'QA',
  },
  'accessToken': 'access-qa',
  'refreshToken': 'refresh-qa',
  'isNewUser': false,
};

class _MemoryTokens extends SecureTokenStorage {
  _MemoryTokens(this.store);
  final Map<String, String> store;

  @override
  Future<String?> getAccess() async => store['access'];

  @override
  Future<String?> getRefresh() async => store['refresh'];

  @override
  Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    store['access'] = access;
    store['refresh'] = refresh;
  }
}
