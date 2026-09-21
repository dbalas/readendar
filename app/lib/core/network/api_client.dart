import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:readendar/core/network/interceptors/api_error_log_interceptor.dart';
import 'package:readendar/core/network/interceptors/auth_refresh_interceptor.dart';
import 'package:readendar/core/network/interceptors/locale_interceptor.dart';
import 'package:readendar/core/storage/secure_storage.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.storage,
    required this.localeProvider,
    this.onLoggedOut,
    this.skipSessionClear,
    bool enableLogging = false,
    void Function(String)? apiErrorLogger,
  }) {
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        // sendTimeout bounds a stalled request-body upload (cover on a
        // dying connection) — without it the request hangs indefinitely.
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/json',
      ),
    );
    if (enableLogging) {
      refreshDio.interceptors.add(ApiErrorLogInterceptor(log: apiErrorLogger));
    }
    dio =
        Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              contentType: 'application/json',
            ),
          )
          ..interceptors.addAll([
            LocaleInterceptor(localeProvider),
            AuthRefreshInterceptor(
              storage: storage,
              refreshDio: refreshDio,
              onLoggedOut: onLoggedOut,
              skipSessionClear: skipSessionClear,
            ),
            if (enableLogging)
              ApiErrorLogInterceptor(
                log: apiErrorLogger,
              ),
          ]);
  }

  final String baseUrl;
  final SecureTokenStorage storage;
  final String Function() localeProvider;
  final void Function()? onLoggedOut;
  final bool Function()? skipSessionClear;

  late final Dio dio;

  /// SSE client. Cloudflare gzip-buffers `text/event-stream` when the Dart
  /// HttpClient advertises gzip, so photo search never sees pings.
  Dio sseDio() {
    final d = Dio(
      dio.options.copyWith(
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(minutes: 60),
      ),
    );
    d.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.autoUncompress = false;
        return client;
      },
    );
    d.interceptors.addAll(dio.interceptors);
    return d;
  }
}
