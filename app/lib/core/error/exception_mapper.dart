import 'package:dio/dio.dart';

import 'package:readendar/core/error/failure.dart';

/// Maps Dio exceptions + server error envelopes into Failures.
Failure mapDioException(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkFailure(e.message);
    }
    final resp = e.response;
    if (resp == null) {
      return const NetworkFailure();
    }
    final body = resp.data;
    var code = 'server';
    String? msg;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        code = (err['code'] as String?) ?? code;
        msg = err['message'] as String?;
      }
    }
    switch (resp.statusCode) {
      case 400:
        return ValidationFailure(code, msg);
      case 401:
        return UnauthorizedFailure(code, msg);
      case 403:
        return ForbiddenFailure(code, msg);
      case 404:
        return NotFoundFailure(code, msg);
      case 409:
        return ConflictFailure(code, msg);
      case 429:
        final retry = int.tryParse(resp.headers.value('Retry-After') ?? '');
        return RateLimitedFailure(retry, msg);
      default:
        return ServerFailure(code, msg);
    }
  }
  return UnknownFailure(e.toString());
}
