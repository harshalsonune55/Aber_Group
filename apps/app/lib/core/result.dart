import 'package:flutter/foundation.dart';

/// A failure the UI can reason about.
///
/// The API returns a stable machine-readable `code` on every error; the app
/// branches on that, never on the human-readable message, so changing wording
/// on the server can never break client behaviour.
@immutable
class Failure {
  const Failure({
    required this.code,
    required this.message,
    this.statusCode,
    this.detail = const {},
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> detail;

  /// No connectivity, or the request never reached a server. The sync engine
  /// treats this as "retry later" rather than surfacing an error to the user.
  bool get isNetwork => code == 'network_error' || code == 'timeout';

  /// The record moved on the server. Carries `server_state` and
  /// `conflicting_fields` for the conflicts inbox.
  bool get isConflict => code == 'conflict';

  bool get isUnauthenticated => code == 'unauthenticated' || statusCode == 401;

  factory Failure.fromApi(Map<String, dynamic> body, int? statusCode) {
    return Failure(
      code: body['code'] as String? ?? 'unknown_error',
      message: body['message'] as String? ?? 'Something went wrong.',
      statusCode: statusCode,
      detail: (body['detail'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  @override
  String toString() => 'Failure($code, $message)';
}

/// A minimal success/failure union.
///
/// Repositories return this rather than throwing, so a caller cannot forget to
/// handle the failure path — the type will not let them read the value without
/// deciding what to do when there isn't one.
@immutable
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) ok,
    required R Function(Failure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Result<R>.ok(transform(value)),
    Err<T>(:final failure) => Result<R>.err(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
