import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/exception_mapper.dart';
import 'package:readendar/core/error/failure.dart';

DioException _resp(int status, [Map<String, dynamic>? body]) {
  return DioException(
    requestOptions: RequestOptions(path: '/'),
    response: Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: '/'),
      statusCode: status,
      data:
          body ??
          {
            'error': {
              'kind': 'invalid',
              'code': 'bad_request',
              'message': 'oops',
            },
          },
    ),
  );
}

void main() {
  group('mapDioException', () {
    test('401 → UnauthorizedFailure', () {
      expect(mapDioException(_resp(401)), isA<UnauthorizedFailure>());
    });
    test('401 preserves google_* server code', () {
      final f = mapDioException(
        _resp(401, {
          'error': {
            'kind': 'unauthorized',
            'code': 'google_invalid_audience',
          },
        }),
      );
      expect(f, isA<UnauthorizedFailure>());
      expect(f.code, 'google_invalid_audience');
    });
    test('401 preserves apple_* server code', () {
      final f = mapDioException(
        _resp(401, {
          'error': {
            'kind': 'unauthorized',
            'code': 'apple_missing_email',
          },
        }),
      );
      expect(f, isA<UnauthorizedFailure>());
      expect(f.code, 'apple_missing_email');
    });
    test('403 → ForbiddenFailure', () {
      expect(mapDioException(_resp(403)), isA<ForbiddenFailure>());
    });
    test('404 → NotFoundFailure', () {
      expect(mapDioException(_resp(404)), isA<NotFoundFailure>());
    });
    test('404 preserves server code', () {
      final f = mapDioException(
        _resp(404, {
          'error': {'code': 'not_found_item'},
        }),
      );
      expect(f, isA<NotFoundFailure>());
      expect(f.code, 'not_found_item');
    });
    test('409 → ConflictFailure with code', () {
      final f = mapDioException(
        _resp(409, {
          'error': {'code': 'refresh_reused'},
        }),
      );
      expect(f, isA<ConflictFailure>());
      expect(f.code, 'refresh_reused');
    });
    test('409 preserves custom-field cascade conflict code', () {
      final f = mapDioException(
        _resp(409, {
          'error': {'kind': 'conflict', 'code': 'custom_field_in_use'},
          'affectedBooks': 3,
        }),
      );
      expect(f, isA<ConflictFailure>());
      expect(f.code, 'custom_field_in_use');
    });
    test('429 → RateLimitedFailure', () {
      expect(mapDioException(_resp(429)), isA<RateLimitedFailure>());
    });
    test('500 → ServerFailure', () {
      expect(mapDioException(_resp(500)), isA<ServerFailure>());
    });
    test('connectionError → NetworkFailure', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      expect(mapDioException(e), isA<NetworkFailure>());
    });
  });
}
