import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';

/// Matches `annotation.MaxBodyLen`.
const _annotationMaxBodyLen = 250000;

String localizedFailureMessage(AppL10n l, Failure failure) {
  return switch (failure) {
    RateLimitedFailure(:final retryAfterSeconds) => localizedRateLimitedMessage(
      l,
      retryAfterSeconds,
    ),
    NetworkFailure() => l.errorNetwork,
    UnauthorizedFailure(:final code) when code != 'unauthorized' => l.errorGeneric,
    UnauthorizedFailure() => l.errorUnauthorized,
    ValidationFailure(code: 'feedback_message_too_short') =>
      l.feedbackMessageTooShort,
    ValidationFailure(code: 'invalid_email') => l.errInvalidEmail,
    ValidationFailure(code: 'push_permission_denied') => l.pushPermissionDenied,
    ValidationFailure(code: 'push_token_unavailable') => l.pushTokenUnavailable,
    ValidationFailure(code: 'annotation_body_too_long') =>
      l.annotationBodyTooLong(_annotationMaxBodyLen),
    ValidationFailure(:final message) => message ?? l.errorValidation,
    _ => failure.message ?? l.errorGeneric,
  };
}

/// Builds the user-facing "too many requests" message, naming the concrete
/// wait time when the server told us one (via the `Retry-After` header).
String localizedRateLimitedMessage(AppL10n l, int? retryAfterSeconds) {
  if (retryAfterSeconds == null || retryAfterSeconds <= 0) {
    return l.errorRateLimited;
  }
  if (retryAfterSeconds < 60) {
    return l.errorRateLimitedSeconds(retryAfterSeconds);
  }
  return l.errorRateLimitedMinutes((retryAfterSeconds + 59) ~/ 60);
}

String localizedErrorMessage(AppL10n l, Object error) {
  return switch (error) {
    FailureException(:final failure) => localizedFailureMessage(l, failure),
    Failure() => localizedFailureMessage(l, error),
    _ => l.errorGeneric,
  };
}
