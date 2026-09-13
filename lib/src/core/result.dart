import 'app_failure.dart';

/// The outcome of an operation that can fail: either [Ok] with a value or
/// [Err] with a typed [AppFailure].
///
/// Repositories return `Result<T>` (usually as `Future<Result<T>>`) instead
/// of throwing. Callers handle both arms with a `switch`:
///
/// ```dart
/// switch (await repo.raisePing(...)) {
///   case Ok(:final value): // use value
///   case Err(:final failure): // show failure.userMessage
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// `true` when this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// The value if [Ok], otherwise `null`.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure if [Err], otherwise `null`.
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Transform the value of an [Ok]; an [Err] passes through untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok(transform(value)),
    Err<T>(:final failure) => Err(failure),
  };
}

class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;
}
