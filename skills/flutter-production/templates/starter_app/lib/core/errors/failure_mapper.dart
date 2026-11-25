import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import 'app_failure.dart';

/// Converts any thrown object into an [AppFailure]. Single source of truth.
AppFailure mapToFailure(Object error, [StackTrace? stackTrace]) {
  final trace = stackTrace ?? StackTrace.current;
  return switch (error) {
    AppFailure() => error,
    DioException() => _fromDio(error, trace),
    TimeoutException() => TimeoutFailure(cause: error, stackTrace: trace),
    HandshakeException() ||
    TlsException() => SecurityFailure(cause: error, stackTrace: trace),
    SocketException() ||
    HttpException() => NetworkFailure(cause: error, stackTrace: trace),
    FormatException() ||
    TypeError() => DataFormatFailure(cause: error, stackTrace: trace),
    PlatformException() => UnexpectedFailure(cause: error, stackTrace: trace),
    _ => UnexpectedFailure(cause: error, stackTrace: trace),
  };
}

/// Runs [action] and rethrows any error as an [AppFailure].
///
/// Use at repository boundaries so that controllers and widgets only ever see
/// typed failures.
Future<T> guardFailures<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on Object catch (error, stackTrace) {
    // Converting, not swallowing: the typed failure is rethrown.
    throw mapToFailure(error, stackTrace);
  }
}

AppFailure _fromDio(DioException e, StackTrace trace) {
  final inner = e.error;
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return TimeoutFailure(cause: e, stackTrace: trace);
    case DioExceptionType.badCertificate:
      return SecurityFailure(cause: e, stackTrace: trace);
    case DioExceptionType.cancel:
      return CancelledFailure(cause: e, stackTrace: trace);
    case DioExceptionType.connectionError:
      if (inner is HandshakeException || inner is TlsException) {
        return SecurityFailure(cause: e, stackTrace: trace);
      }
      return NetworkFailure(cause: e, stackTrace: trace);
    case DioExceptionType.badResponse:
      return _fromResponse(e, trace);
    case DioExceptionType.unknown:
      if (inner is AppFailure) return inner;
      if (inner is HandshakeException || inner is TlsException) {
        return SecurityFailure(cause: e, stackTrace: trace);
      }
      if (inner is SocketException || inner is HttpException) {
        return NetworkFailure(cause: e, stackTrace: trace);
      }
      if (inner is FormatException) {
        return DataFormatFailure(cause: e, stackTrace: trace);
      }
      return UnexpectedFailure(cause: e, stackTrace: trace);
  }
}

AppFailure _fromResponse(DioException e, StackTrace trace) {
  final response = e.response;
  final status = response?.statusCode ?? 0;
  return switch (status) {
    400 || 422 => ValidationFailure(
      fieldErrors: _fieldErrors(response?.data),
      serverMessage: _serverMessage(response?.data),
      cause: e,
      stackTrace: trace,
    ),
    401 => UnauthorizedFailure(cause: e, stackTrace: trace),
    403 => ForbiddenFailure(cause: e, stackTrace: trace),
    404 || 410 => NotFoundFailure(cause: e, stackTrace: trace),
    408 => TimeoutFailure(cause: e, stackTrace: trace),
    429 => RateLimitedFailure(
      retryAfter: parseRetryAfter(response?.headers.value('retry-after')),
      cause: e,
      stackTrace: trace,
    ),
    >= 500 && < 600 => ServerFailure(
      statusCode: status,
      cause: e,
      stackTrace: trace,
    ),
    _ => UnexpectedFailure(cause: e, stackTrace: trace),
  };
}

/// Parses `Retry-After` (seconds form). Caps absurd values at 10 minutes.
Duration? parseRetryAfter(String? header) {
  final seconds = int.tryParse(header?.trim() ?? '');
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds.clamp(0, 600));
}

/// Expected backend shape: `{"message": "...", "errors": {"field": "msg"}}`.
Map<String, String> _fieldErrors(Object? data) {
  if (data is! Map) return const {};
  final errors = data['errors'];
  if (errors is! Map) return const {};
  final result = <String, String>{};
  for (final MapEntry(:key, :value) in errors.entries) {
    if (key is String && value is String && value.length <= 300) {
      result[key] = value;
    }
  }
  return result;
}

String? _serverMessage(Object? data) {
  if (data is! Map) return null;
  final message = data['message'];
  if (message is! String || message.isEmpty || message.length > 300) {
    return null;
  }
  return message;
}
