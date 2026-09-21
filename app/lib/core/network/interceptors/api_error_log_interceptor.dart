import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only, payload-free API error reporting.
///
/// Network responses can contain a library, events, user data, or auth details.
/// Logging those bodies makes debug builds noticeably slower and risks exposing
/// sensitive data in device/IDE logs. Keep only the method, route, HTTP status,
/// and Dio failure category needed to diagnose a failed request.
class ApiErrorLogInterceptor extends Interceptor {
  ApiErrorLogInterceptor({void Function(String)? log})
    : _log = log ?? debugPrint;

  final void Function(String) _log;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isTransientTransportFailure(err.type)) {
      handler.next(err);
      return;
    }
    final request = err.requestOptions;
    final status = err.response?.statusCode;
    final statusSuffix = status == null ? '' : ' HTTP $status';
    _log(
      'API ${request.method} ${request.uri.path} failed:'
      '$statusSuffix ${err.type.name}',
    );
    handler.next(err);
  }
}

bool _isTransientTransportFailure(DioExceptionType type) => switch (type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.connectionError => true,
  _ => false,
};
