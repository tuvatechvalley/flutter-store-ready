import 'package:flutter/foundation.dart';

/// Every error that reaches the UI is converted into one of these types.
///
/// Rules:
/// * Repositories never leak raw `DioException`, `SocketException`,
///   `PlatformException` etc. — they map them with `mapToFailure`.
/// * The UI never shows `toString()` of an exception to users (it can leak
///   URLs, tokens or stack details). It shows a localized message chosen by
///   failure type instead.
@immutable
sealed class AppFailure implements Exception {
  const AppFailure({this.cause, this.stackTrace});

  /// Original error, for logging and crash reports only. Never show to users.
  final Object? cause;
  final StackTrace? stackTrace;

  /// Whether retrying the same operation can reasonably succeed.
  bool get isRetryable => false;

  /// Whether this failure is worth sending to crash reporting.
  /// Expected business outcomes (404, validation, offline) are not.
  bool get shouldReport => false;

  @override
  String toString() => '$runtimeType(cause: ${cause.runtimeType})';
}

/// No connection, DNS failure, connection refused/reset.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.cause, super.stackTrace});

  @override
  bool get isRetryable => true;
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.cause, super.stackTrace});

  @override
  bool get isRetryable => true;
}

/// TLS failure or certificate pin mismatch. Possible man-in-the-middle.
final class SecurityFailure extends AppFailure {
  const SecurityFailure({super.cause, super.stackTrace});

  @override
  bool get shouldReport => true;
}

/// 401 that could not be fixed by refreshing the session.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({super.cause, super.stackTrace});
}

/// 403.
final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({super.cause, super.stackTrace});
}

/// 404.
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.cause, super.stackTrace});
}

/// 400 / 422 with optional per-field messages from the server.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.fieldErrors = const {},
    this.serverMessage,
    super.cause,
    super.stackTrace,
  });

  final Map<String, String> fieldErrors;

  /// Message provided by *our own* backend. Only safe to display because the
  /// backend contract guarantees it is user-facing text.
  final String? serverMessage;
}

/// 429.
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({this.retryAfter, super.cause, super.stackTrace});

  final Duration? retryAfter;

  @override
  bool get isRetryable => true;
}

/// 5xx.
final class ServerFailure extends AppFailure {
  const ServerFailure({
    required this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int statusCode;

  @override
  bool get isRetryable => true;

  @override
  bool get shouldReport => true;
}

/// Response did not match the expected contract (bad JSON, missing fields).
final class DataFormatFailure extends AppFailure {
  const DataFormatFailure({super.cause, super.stackTrace});

  @override
  bool get shouldReport => true;
}

/// The request was cancelled on purpose; never shown to the user.
final class CancelledFailure extends AppFailure {
  const CancelledFailure({super.cause, super.stackTrace});
}

/// Anything we did not anticipate. Always reported.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.cause, super.stackTrace});

  @override
  bool get isRetryable => true;

  @override
  bool get shouldReport => true;
}
