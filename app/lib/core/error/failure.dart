/// Failures bubble up from the data layer; UI maps them to localized messages.
sealed class Failure {
  const Failure(this.code, [this.message]);
  final String code;
  final String? message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([String? message]) : super('network', message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.code, [super.message]);
}

class UnauthorizedFailure extends Failure {
  // Carries the server error code so callers can distinguish
  // leftover API 401s from a real expired session.
  const UnauthorizedFailure([super.code = 'unauthorized', super.message]);
}

class ForbiddenFailure extends Failure {
  // Carries a server error code when present so callers can distinguish
  // specific 403s; defaults to the generic 'forbidden'.
  const ForbiddenFailure([super.code = 'forbidden', super.message]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.code = 'not_found', super.message]);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.code, [super.message]);
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.code, [super.message]);
}

class RateLimitedFailure extends Failure {
  const RateLimitedFailure([this.retryAfterSeconds, String? message])
    : super('rate_limited', message);
  final int? retryAfterSeconds;
}

class UnknownFailure extends Failure {
  const UnknownFailure([String? message]) : super('unknown', message);
}
