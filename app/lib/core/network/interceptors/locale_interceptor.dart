import 'package:dio/dio.dart';

/// Injects Accept-Language from a provider callback.
class LocaleInterceptor extends Interceptor {
  LocaleInterceptor(this.localeProvider);
  final String Function() localeProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['Accept-Language'] = localeProvider();
    handler.next(options);
  }
}
