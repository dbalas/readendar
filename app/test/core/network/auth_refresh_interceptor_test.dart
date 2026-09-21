import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:readendar/core/network/interceptors/auth_refresh_interceptor.dart';
import 'package:readendar/core/storage/secure_storage.dart';

class _MockStorage extends Mock implements SecureTokenStorage {}

class _MockDio extends Mock implements Dio {}

class _MockErrorHandler extends Mock implements ErrorInterceptorHandler {}

class _MockRequestHandler extends Mock implements RequestInterceptorHandler {}

void main() {
  late _MockStorage storage;
  late _MockDio refreshDio;
  late _MockErrorHandler handler;
  late int loggedOutCalls;
  late AuthRefreshInterceptor interceptor;

  late RequestOptions apiOptions;
  late RequestOptions refreshOptions;

  DioException unauthorized() => DioException(
    requestOptions: apiOptions,
    response: Response(requestOptions: apiOptions, statusCode: 401),
  );

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: '/'));
    registerFallbackValue(
      DioException(requestOptions: RequestOptions(path: '/')),
    );
    registerFallbackValue(
      Response<dynamic>(requestOptions: RequestOptions(path: '/')),
    );
  });

  setUp(() {
    apiOptions = RequestOptions(path: '/v1/books');
    refreshOptions = RequestOptions(path: '/v1/auth/refresh');
    storage = _MockStorage();
    refreshDio = _MockDio();
    handler = _MockErrorHandler();
    loggedOutCalls = 0;
    interceptor = AuthRefreshInterceptor(
      storage: storage,
      refreshDio: refreshDio,
      onLoggedOut: () => loggedOutCalls++,
    );
    when(() => storage.getRefresh()).thenAnswer((_) async => 'refresh-1');
    when(() => handler.next(any())).thenReturn(null);
    when(() => handler.resolve(any())).thenReturn(null);
  });

  void stubRefreshFailure(DioException e) {
    when(
      () => refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: any(named: 'data'),
      ),
    ).thenThrow(e);
  }

  test('refresh rejected with 401 logs the user out', () async {
    stubRefreshFailure(
      DioException(
        requestOptions: refreshOptions,
        response: Response(requestOptions: refreshOptions, statusCode: 401),
      ),
    );

    await interceptor.onError(unauthorized(), handler);

    expect(loggedOutCalls, 1);
    verify(() => handler.next(any())).called(1);
  });

  test('network failure during refresh does NOT log the user out', () async {
    final refreshErr = DioException(
      requestOptions: refreshOptions,
      type: DioExceptionType.connectionTimeout,
    );
    stubRefreshFailure(refreshErr);

    await interceptor.onError(unauthorized(), handler);

    expect(loggedOutCalls, 0);
    final captured =
        verify(() => handler.next(captureAny())).captured.single
            as DioException;
    expect(captured.type, DioExceptionType.connectionTimeout);
    expect(captured.response?.statusCode, isNull);
    verifyNever(
      () => storage.saveTokens(
        access: any(named: 'access'),
        refresh: any(named: 'refresh'),
      ),
    );
  });

  test('rate-limited (429) refresh does NOT log the user out', () async {
    stubRefreshFailure(
      DioException(
        requestOptions: refreshOptions,
        response: Response(requestOptions: refreshOptions, statusCode: 429),
      ),
    );

    await interceptor.onError(unauthorized(), handler);

    expect(loggedOutCalls, 0);
    final captured =
        verify(() => handler.next(captureAny())).captured.single
            as DioException;
    expect(captured.response?.statusCode, 429);
  });

  test(
    'server error (503) during refresh keeps session and surfaces 503 not 401',
    () async {
      stubRefreshFailure(
        DioException(
          requestOptions: refreshOptions,
          response: Response(requestOptions: refreshOptions, statusCode: 503),
        ),
      );

      await interceptor.onError(unauthorized(), handler);

      expect(loggedOutCalls, 0);
      final captured =
          verify(() => handler.next(captureAny())).captured.single
              as DioException;
      // Must not re-emit the original 401: that maps to UnauthorizedFailure /
      // "session expired" and can make bootstrap wipe a still-valid session.
      expect(captured.response?.statusCode, 503);
    },
  );

  test(
    'malformed refresh body keeps session and surfaces a transient server error',
    () async {
      when(
        () => refreshDio.post<Map<String, dynamic>>(
          '/v1/auth/refresh',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: refreshOptions,
          statusCode: 200,
          data: <String, dynamic>{},
        ),
      );

      await interceptor.onError(unauthorized(), handler);

      expect(loggedOutCalls, 0);
      final captured =
          verify(() => handler.next(captureAny())).captured.single
              as DioException;
      expect(captured.response?.statusCode, 503);
      expect(captured.response?.statusCode, isNot(401));
    },
  );
  test('missing local refresh token logs the user out', () async {
    when(() => storage.getRefresh()).thenAnswer((_) async => null);

    await interceptor.onError(unauthorized(), handler);

    expect(loggedOutCalls, 1);
    verify(() => handler.next(any())).called(1);
  });

  test(
    'skipSessionClear keeps a leftover 401 from logging the user out',
    () async {
      interceptor = AuthRefreshInterceptor(
        storage: storage,
        refreshDio: refreshDio,
        onLoggedOut: () => loggedOutCalls++,
        skipSessionClear: () => true,
      );
      when(() => storage.getRefresh()).thenAnswer((_) async => null);

      await interceptor.onError(unauthorized(), handler);

      expect(loggedOutCalls, 0);
      verifyNever(
        () => refreshDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ),
      );
      verify(() => handler.next(any())).called(1);
    },
  );

  test(
    'skipSessionClear still refreshes a leftover JWT and replays the request',
    () async {
      interceptor = AuthRefreshInterceptor(
        storage: storage,
        refreshDio: refreshDio,
        onLoggedOut: () => loggedOutCalls++,
        skipSessionClear: () => true,
      );
      when(
        () => refreshDio.post<Map<String, dynamic>>(
          '/v1/auth/refresh',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: refreshOptions,
          statusCode: 200,
          data: {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
        ),
      );
      when(
        () => storage.saveTokens(
          access: any(named: 'access'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async {});
      when(() => storage.getAccess()).thenAnswer((_) async => 'access-2');
      when(() => refreshDio.fetch<dynamic>(any())).thenAnswer(
        (_) async => Response(requestOptions: apiOptions, statusCode: 200),
      );

      await interceptor.onError(unauthorized(), handler);

      expect(loggedOutCalls, 0);
      verify(
        () => storage.saveTokens(access: 'access-2', refresh: 'refresh-2'),
      ).called(1);
      verify(() => handler.resolve(any())).called(1);
      verifyNever(() => handler.next(any()));
    },
  );

  test('successful refresh saves tokens and replays the request', () async {
    when(
      () => refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: refreshOptions,
        statusCode: 200,
        data: {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
      ),
    );
    when(
      () => storage.saveTokens(
        access: any(named: 'access'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.getAccess()).thenAnswer((_) async => 'access-2');
    when(() => refreshDio.fetch<dynamic>(any())).thenAnswer(
      (_) async => Response(requestOptions: apiOptions, statusCode: 200),
    );

    await interceptor.onError(unauthorized(), handler);

    expect(loggedOutCalls, 0);
    verify(
      () => storage.saveTokens(access: 'access-2', refresh: 'refresh-2'),
    ).called(1);
    verify(() => handler.resolve(any())).called(1);
    verifyNever(() => handler.next(any()));
  });

  test(
    'replay 500 after successful refresh keeps session and surfaces 500',
    () async {
      when(
        () => refreshDio.post<Map<String, dynamic>>(
          '/v1/auth/refresh',
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: refreshOptions,
          statusCode: 200,
          data: {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
        ),
      );
      when(
        () => storage.saveTokens(
          access: any(named: 'access'),
          refresh: any(named: 'refresh'),
        ),
      ).thenAnswer((_) async {});
      when(() => storage.getAccess()).thenAnswer((_) async => 'access-2');
      final replayErr = DioException(
        requestOptions: apiOptions,
        response: Response(requestOptions: apiOptions, statusCode: 500),
      );
      when(() => refreshDio.fetch<dynamic>(any())).thenThrow(replayErr);

      await interceptor.onError(unauthorized(), handler);

      expect(loggedOutCalls, 0);
      verify(() => refreshDio.fetch<dynamic>(any())).called(1);
      final captured =
          verify(() => handler.next(captureAny())).captured.single
              as DioException;
      expect(captured.response?.statusCode, 500);
      verifyNever(() => handler.resolve(any()));
    },
  );

  test('successful refresh clones a finalized multipart body', () async {
    final original = FormData.fromMap({
      'kind': 'cover',
      'file': MultipartFile.fromBytes(
        [1, 2, 3, 4],
        filename: 'cover.png',
      ),
    });
    await original.finalize().drain<void>();
    final uploadOptions = RequestOptions(
      path: '/v1/uploads/books/book-1/cover',
      method: 'POST',
      data: original,
    );
    final upload401 = DioException(
      requestOptions: uploadOptions,
      response: Response(requestOptions: uploadOptions, statusCode: 401),
    );
    when(
      () => refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: any(named: 'data'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: refreshOptions,
        statusCode: 200,
        data: {'accessToken': 'access-2', 'refreshToken': 'refresh-2'},
      ),
    );
    when(
      () => storage.saveTokens(
        access: any(named: 'access'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.getAccess()).thenAnswer((_) async => 'access-2');
    FormData? replayed;
    when(() => refreshDio.fetch<dynamic>(any())).thenAnswer((invocation) async {
      final options = invocation.positionalArguments.single as RequestOptions;
      replayed = options.data as FormData;
      await replayed!.finalize().drain<void>();
      return Response(requestOptions: options, statusCode: 200);
    });

    await interceptor.onError(upload401, handler);

    expect(replayed, isNotNull);
    expect(replayed, isNot(same(original)));
    expect(replayed!.fields, original.fields);
    expect(replayed!.files.single.value.length, 4);
    verify(() => handler.resolve(any())).called(1);
  });

  test('import-session mint does not attach a leftover access token', () async {
    final requestHandler = _MockRequestHandler();
    when(() => requestHandler.next(any())).thenReturn(null);
    when(() => storage.getAccess()).thenAnswer((_) async => 'stored-token');
    final options = RequestOptions(path: '/v1/debug/import-session');

    await interceptor.onRequest(options, requestHandler);

    expect(options.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.getAccess());
    verify(() => requestHandler.next(options)).called(1);
  });

  test('oauth sign-in does not attach a leftover access token', () async {
    final requestHandler = _MockRequestHandler();
    when(() => requestHandler.next(any())).thenReturn(null);
    when(() => storage.getAccess()).thenAnswer((_) async => 'stored-token');
    final options = RequestOptions(path: '/v1/auth/oauth/google');

    await interceptor.onRequest(options, requestHandler);

    expect(options.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.getAccess());
    verify(() => requestHandler.next(options)).called(1);
  });

  test('magic-link verify does not attach a leftover access token', () async {
    final requestHandler = _MockRequestHandler();
    when(() => requestHandler.next(any())).thenReturn(null);
    when(() => storage.getAccess()).thenAnswer((_) async => 'stored-token');
    final options = RequestOptions(path: '/v1/auth/magic-link/verify');

    await interceptor.onRequest(options, requestHandler);

    expect(options.headers.containsKey('Authorization'), isFalse);
    verifyNever(() => storage.getAccess());
    verify(() => requestHandler.next(options)).called(1);
  });

  test(
    'explicit Authorization header is not overwritten from storage',
    () async {
      final requestHandler = _MockRequestHandler();
      when(() => requestHandler.next(any())).thenReturn(null);
      when(() => storage.getAccess()).thenAnswer((_) async => 'stored-token');
      final options = RequestOptions(
        path: '/v1/auth/widget-session',
        headers: {'Authorization': 'Bearer captured-token'},
      );

      await interceptor.onRequest(options, requestHandler);

      expect(options.headers['Authorization'], 'Bearer captured-token');
      verifyNever(() => storage.getAccess());
      verify(() => requestHandler.next(options)).called(1);
    },
  );
}
