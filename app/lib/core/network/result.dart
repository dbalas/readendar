import 'package:readendar/core/error/failure.dart';

/// `Result<T>` is a typed success/failure for repository methods.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get value => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failure => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  R fold<R>(R Function(T value) onOk, R Function(Failure f) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);
  @override
  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);
  @override
  final Failure failure;
}
