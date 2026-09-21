import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/app_update/itunes_lookup_client.dart';

void main() {
  test('parses version, notes, and store URL', () {
    final row = parseItunesLookup({
      'resultCount': 1,
      'results': [
        {
          'version': '1.1.7',
          'releaseNotes': "What's new in 1.1.7\n\n• Widgets",
          'trackViewUrl': 'https://apps.apple.com/app/id123',
        },
      ],
    });
    expect(row?.version, '1.1.7');
    expect(row?.releaseNotes, contains('Widgets'));
    expect(row?.trackViewUrl, 'https://apps.apple.com/app/id123');
  });

  test('accepts numeric resultCount from JSON', () {
    final row = parseItunesLookup({
      'resultCount': 1.0,
      'results': [
        {'version': '2.0.0'},
      ],
    });
    expect(row?.version, '2.0.0');
  });

  test('returns null for empty or malformed payloads', () {
    expect(parseItunesLookup(null), isNull);
    expect(parseItunesLookup({'resultCount': 0, 'results': []}), isNull);
    expect(
      parseItunesLookup({
        'resultCount': 1,
        'results': [
          {'version': '  '},
        ],
      }),
      isNull,
    );
  });

  test('timeout and invalid payloads fail closed', () async {
    final timeout = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
          },
        ),
      );
    expect(await lookupItunes(country: 'us', dio: timeout), isNull);

    final invalid = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: 'not-json',
              ),
            );
          },
        ),
      );
    expect(await lookupItunes(country: 'es', dio: invalid), isNull);
  });
}
