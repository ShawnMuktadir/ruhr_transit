import 'package:ruhr_transit/core/error/failure.dart';

/// The outcome of an operation that can fail: either [Ok] with a value or
/// [Err] with a [Failure].
///
/// Repositories return this instead of throwing, so callers handle errors
/// with an exhaustive `switch`:
///
/// ```dart
/// switch (await repository.searchStops('Bochum')) {
///   case Ok(:final value): emit(Loaded(value));
///   case Err(:final failure): emit(Failed(failure));
/// }
/// ```
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
