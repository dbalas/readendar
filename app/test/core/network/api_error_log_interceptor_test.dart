import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/storage/secure_storage.dart';

void main() {
  test(
    'debug API logging reports a failed route without payloads or headers',
    () async {
      final messages = <String>[];
      final api = ApiClient(
        baseUrl: 'https://api.example.test',
        storage: _FakeSecureTokenStorage(),
        localeProvider: () => 'en',
        enableLogging: true,
        apiErrorLogger: messages.add,
      );
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<Object>(
                requestOptions: options,
                statusCode: 500,
                data: const {
                  'refreshToken': 'must-not-appear',
                  'items': ['large response body'],
                },
              ),
            ),
            true,
          ),
        ),
      );

      await expectLater(
        api.dio.get<void>('/v1/books?token=secret'),
        throwsA(isA<DioException>()),
      );

      expect(messages, ['API GET /v1/books failed: HTTP 500 badResponse']);
    },
  );

  test('debug API logging skips connect timeouts', () async {
    final messages = <String>[];
    final api = ApiClient(
      baseUrl: 'https://api.example.test',
      storage: _FakeSecureTokenStorage(),
      localeProvider: () => 'en',
      enableLogging: true,
      apiErrorLogger: messages.add,
    );
    api.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message:
                'The request connection took longer than 0:00:10.000000 '
                'and it was aborted.',
          ),
          true,
        ),
      ),
    );

    await expectLater(
      api.dio.get<void>('/v1/notifications/preferences'),
      throwsA(isA<DioException>()),
    );

    expect(messages, isEmpty);
  });
}

class _FakeSecureTokenStorage extends SecureTokenStorage {
  @override
  Future<String?> getAccess() async => null;
}
