// FailureException wraps a Failure in an Exception so it can be re-thrown
// from a FutureProvider and surfaced via AsyncError.error.toString().
//
// Used wherever a `Result<T>` value needs to be lifted into the async-throw
// channel that Riverpod's FutureProvider expects.

import 'package:readendar/core/error/failure.dart';

class FailureException implements Exception {
  const FailureException(this.failure);
  final Failure failure;

  @override
  String toString() => failure.message ?? failure.code;
}
