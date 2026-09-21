import 'dart:async';

import 'package:dio/dio.dart';

import 'package:readendar/core/storage/secure_storage.dart';

enum _RefreshOutcome { success, rejected, transient }

class _RefreshAttempt {
  const _RefreshAttempt(this.outcome, [this.error]);

  final _RefreshOutcome outcome;

  /// Set on [transient] so callers can surface the refresh failure (5xx /
  /// network) instead of the original 401. Null when we synthesized the
  /// outcome without a DioException (malformed body, unexpected throw).
  final DioException? error;
}

/// AuthRefreshInterceptor attaches the access token + auto-refreshes on 401.
///
/// On a 401:
///   1. queue subsequent failures
///   2. POST /v1/auth/refresh once
///   3. on success: save tokens, replay all queued requests
///   4. rejected by the server (401/403): log out, surface a 401
///   5. transient failure (network, 5xx, 429): surface THAT error and KEEP the
///      session — never re-emit the original 401 (that would show "session
///      expired" and let bootstrap wipe a still-valid refresh token).
class AuthRefreshInterceptor extends Interceptor {
  AuthRefreshInterceptor({
    required this.storage,
    required this.refreshDio,
    this.onLoggedOut,
    this.skipSessionClear,
  });

  final SecureTokenStorage storage;
  final Dio refreshDio; // shouldn't loop through this interceptor
  final void Function()? onLoggedOut;

  /// Local-first sessions must not wipe the guest when leftover API tokens
  /// cannot refresh. Refresh still runs so cloud export can complete.
  final bool Function()? skipSessionClear;

  Completer<_RefreshAttempt>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthPath(options.path)) {
      handler.next(options);
      return;
    }
    if (options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }
    final access = await storage.getAccess();
    if (access != null) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        _isAuthPath(req.path) ||
        req.extra['retried'] == true) {
      handler.next(err);
      return;
    }
    final attempt = await _refreshOnce();
    if (attempt.outcome != _RefreshOutcome.success) {
      if (attempt.outcome == _RefreshOutcome.rejected) {
        // Local-first leftover JWTs must still refresh so /v1/me/export can
        // run. Only skip wiping the guest session when refresh is dead.
        if (skipSessionClear?.call() != true) {
          onLoggedOut?.call();
        }
        handler.next(err);
        return;
      }
      // Transient: keep tokens, show network/server error + retry — not
      // "session expired".
      handler.next(attempt.error ?? _syntheticTransientRefreshError(req));
      return;
    }
    // Replay
    final access = await storage.getAccess();
    req.headers['Authorization'] = 'Bearer $access';
    req.extra['retried'] = true;
    // Dio FormData and MultipartFile streams are one-shot. The original 401
    // already finalized them, so replay must use a deep clone rather than the
    // consumed RequestOptions.data instance.
    final data = req.data;
    if (data is FormData) req.data = data.clone();
    try {
      final response = await refreshDio.fetch<dynamic>(req);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isAuthPath(String path) =>
      path.contains('/v1/auth/refresh') ||
      path.contains('/v1/auth/logout') ||
      path.contains('/v1/auth/magic-link') ||
      // Import login (Google/Apple) must not send a leftover expired JWT.
      path.contains('/v1/auth/oauth') ||
      // Unauthenticated DevMode mint. A leftover expired JWT must not ride
      // along or trigger refresh/logout on 401.
      path.contains('/v1/debug/import-session');

  Future<_RefreshAttempt> _refreshOnce() async {
    final inflight = _refreshing;
    if (inflight != null) {
      return inflight.future;
    }
    final c = Completer<_RefreshAttempt>();
    _refreshing = c;
    _RefreshAttempt done(_RefreshAttempt o) {
      c.complete(o);
      return o;
    }

    try {
      final refresh = await storage.getRefresh();
      if (refresh == null) {
        // No refresh token at all — the session is genuinely gone.
        return done(const _RefreshAttempt(_RefreshOutcome.rejected));
      }
      final r = await refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final body = r.data;
      final access = body?['accessToken'] as String?;
      final newRefresh = body?['refreshToken'] as String?;
      if (access == null || newRefresh == null) {
        return done(const _RefreshAttempt(_RefreshOutcome.transient));
      }
      await storage.saveTokens(access: access, refresh: newRefresh);
      return done(const _RefreshAttempt(_RefreshOutcome.success));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Only an explicit rejection by the auth server invalidates the session.
      // Timeouts, connection errors, 5xx and 429 leave the tokens intact.
      if (status == 401 || status == 403) {
        return done(_RefreshAttempt(_RefreshOutcome.rejected, e));
      }
      return done(_RefreshAttempt(_RefreshOutcome.transient, e));
    } catch (_) {
      return done(const _RefreshAttempt(_RefreshOutcome.transient));
    } finally {
      _refreshing = null;
    }
  }

  /// Maps to [ServerFailure] via [mapDioException] when refresh failed without
  /// a concrete DioException (malformed 200 body, unexpected throw).
  DioException _syntheticTransientRefreshError(RequestOptions original) {
    final opts = RequestOptions(
      path: '/v1/auth/refresh',
      baseUrl: original.baseUrl,
    );
    return DioException(
      requestOptions: opts,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(requestOptions: opts, statusCode: 503),
      message: 'token refresh temporarily unavailable',
    );
  }
}
