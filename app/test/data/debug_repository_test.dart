import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/data/api_repositories.dart';

void main() {
  late List<String> paths;
  late DebugRepository repo;

  setUp(() {
    paths = <String>[];
  });

  DebugRepository repoWith(
    Response<Map<String, dynamic>> Function(RequestOptions) reply, {
    String? cloudImportEmail,
  }) {
    final api = ApiClient(
      baseUrl: 'http://localhost',
      storage: _FakeSecureTokenStorage(),
      localeProvider: () => 'es',
    );
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add(options.path);
          try {
            final response = reply(options);
            handler.resolve(response);
          } on DioException catch (e) {
            handler.reject(e);
          }
        },
      ),
    );
    return DebugRepository(
      api,
      cloudImportEmail:
          cloudImportEmail ?? DebugRepository.defaultCloudImportEmail,
    );
  }

  test('uses debug import-session when the route exists', () async {
    repo = repoWith((options) {
      expect(options.path, '/v1/debug/import-session');
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: _sessionJson(),
      );
    });

    final result = await repo.issueCloudImportSession();

    expect(result.isOk, isTrue);
    expect(result.value?.accessToken, 'access-qa');
    expect(paths, ['/v1/debug/import-session']);
  });

  test('falls back to magic-link when import-session is missing', () async {
    repo = repoWith((options) {
      if (options.path == '/v1/debug/import-session') {
        throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        );
      }
      if (options.path == '/v1/auth/magic-link/request') {
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: const {'sent': true, 'devCode': 'ABCD1234'},
        );
      }
      expect(options.path, '/v1/auth/magic-link/verify');
      expect((options.data as Map)['token'], 'ABCD1234');
      expect((options.data as Map)['expectedEmail'], 'qa@example.com');
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: _sessionJson(),
      );
    });

    final result = await repo.issueCloudImportSession();

    expect(result.isOk, isTrue);
    expect(result.value?.refreshToken, 'refresh-qa');
    expect(paths, [
      '/v1/debug/import-session',
      '/v1/auth/magic-link/request',
      '/v1/auth/magic-link/verify',
    ]);
  });

  test('magic-link fallback uses a caller-supplied import email', () async {
    repo = repoWith((options) {
      if (options.path == '/v1/debug/import-session') {
        throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        );
      }
      if (options.path == '/v1/auth/magic-link/request') {
        expect((options.data as Map)['email'], 'other@example.com');
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: const {'sent': true, 'devCode': 'ABCD1234'},
        );
      }
      expect((options.data as Map)['expectedEmail'], 'other@example.com');
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: _sessionJson(),
      );
    }, cloudImportEmail: 'other@example.com');

    final result = await repo.issueCloudImportSession();

    expect(result.isOk, isTrue);
  });

  test('does not fall back when import-session fails with 500', () async {
    repo = repoWith((options) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 500),
        type: DioExceptionType.badResponse,
      );
    });

    final result = await repo.issueCloudImportSession();

    expect(result.isOk, isFalse);
    expect(result.failure, isA<ServerFailure>());
    expect(paths, ['/v1/debug/import-session']);
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

class _FakeSecureTokenStorage extends Fake implements SecureTokenStorage {}
