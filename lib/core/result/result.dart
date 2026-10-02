import 'package:partilha/core/errors/failure.dart';

/// The outcome of an operation that can fail with a typed [Failure].
///
/// Replaces `dartz`/`fpdart`, which `AGENTS.md` §14 explicitly rejects, and
/// replaces throwing across layer boundaries (`AGENTS.md` §15).
///
/// The hierarchy is `sealed`, so a caller that switches over it will not
/// compile until it handles both cases. That is the point: a `Result` forces
/// the failure path to be visible at the call site instead of being discovered
/// in production.
///
/// ```dart
/// final Result<Settings, Failure> result = await loadSettings();
///
/// return switch (result) {
///   Success(:final value) => value,
///   Err(:final error) => Settings.defaults(reason: error),
/// };
/// ```
sealed class Result<T, E extends Failure> {
  const Result();

  /// Wraps a successful value.
  const factory Result.success(T value) = Success<T, E>;

  /// Wraps a typed failure.
  const factory Result.failure(E error) = Err<T, E>;

  /// Whether this result carries a value.
  bool get isSuccess => this is Success<T, E>;

  /// Whether this result carries a failure.
  bool get isFailure => this is Err<T, E>;

  /// The value, or `null` when this is a failure.
  ///
  /// Convenient for the common case where the caller has already decided it
  /// can tolerate absence. Code that must distinguish "absent" from "failed"
  /// should pattern match instead of reading this.
  T? get valueOrNull => switch (this) {
    Success<T, E>(:final value) => value,
    Err<T, E>() => null,
  };

  /// The failure, or `null` when this is a success.
  E? get errorOrNull => switch (this) {
    Success<T, E>() => null,
    Err<T, E>(:final error) => error,
  };

  /// Collapses both branches into a single value.
  ///
  /// Use this to leave a `Result` without unwrapping it at the boundary.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) => switch (this) {
    Success<T, E>(:final value) => onSuccess(value),
    Err<T, E>(:final error) => onFailure(error),
  };

  /// Transforms the success value, leaving a failure untouched.
  ///
  /// [transform] runs at most once and only on the success path, so it is safe
  /// for work with side effects.
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Success<T, E>(:final value) => Success<R, E>(transform(value)),
    Err<T, E>(:final error) => Err<R, E>(error),
  };

  /// Transforms the failure, leaving a success untouched.
  ///
  /// Lets a layer widen or narrow the error type without leaking the concrete
  /// subclass it happens to know about.
  Result<T, F> mapError<F extends Failure>(F Function(E error) transform) =>
      switch (this) {
        Success<T, E>(:final value) => Success<T, F>(value),
        Err<T, E>(:final error) => Err<T, F>(transform(error)),
      };
}

/// The successful branch of a [Result].
final class Success<T, E extends Failure> extends Result<T, E> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Success($value)';
}

/// The failed branch of a [Result].
final class Err<T, E extends Failure> extends Result<T, E> {
  const Err(this.error);

  final E error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Err<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => Object.hash(runtimeType, error);

  @override
  String toString() => 'Err($error)';
}

/// Runs [action] and captures any thrown object as an [UnknownFailure].
///
/// For the boundary where infrastructure code is called and its exceptions
/// have not yet been converted (`AGENTS.md` §15). Prefer converting to a
/// specific failure type at the data layer; this exists so an unexpected
/// exception cannot escape as an unhandled error, and so it surfaces as
/// something the UI can render (`AGENTS.md` §83).
Future<Result<T, Failure>> guardAsync<T>(
  Future<T> Function() action, {
  Map<String, Object?> context = const <String, Object?>{},
}) async {
  try {
    return Success<T, Failure>(await action());
  } on Object catch (cause, stackTrace) {
    return Err<T, Failure>(
      UnknownFailure(
        userMessage: 'Something went wrong.',
        cause: cause,
        context: <String, Object?>{
          ...context,
          'stackTrace': stackTrace.toString(),
        },
      ),
    );
  }
}

/// Synchronous counterpart of [guardAsync].
Result<T, Failure> guard<T>(
  T Function() action, {
  Map<String, Object?> context = const <String, Object?>{},
}) {
  try {
    return Success<T, Failure>(action());
  } on Object catch (cause, stackTrace) {
    return Err<T, Failure>(
      UnknownFailure(
        userMessage: 'Something went wrong.',
        cause: cause,
        context: <String, Object?>{
          ...context,
          'stackTrace': stackTrace.toString(),
        },
      ),
    );
  }
}
