import 'dart:math';

import 'package:dio/dio.dart';

/// Retries transient failures with exponential backoff + jitter.
///
/// Only idempotent methods are retried automatically. Retrying a POST can
/// create duplicate orders/payments; opt in per request with
/// `extra: {'retryable': true}` only when the backend supports idempotency
/// keys.
final class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this._dio,
    this.maxRetries = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    Random? random,
  }) : _random = random ?? Random();

  static const String retryableKey = 'retryable';
  static const String _attemptKey = 'retryAttempt';
  static const _idempotent = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};
  static const _retryStatus = {408, 429, 502, 503, 504};

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;
  final Random _random;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    if (attempt >= maxRetries || !_shouldRetry(err)) {
      return handler.next(err);
    }

    await Future<void>.delayed(_delayFor(attempt, err.response));
    options.extra[_attemptKey] = attempt + 1;
    try {
      final response = await _dio.fetch<Object?>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      return handler.next(retryError);
    }
  }

  bool _shouldRetry(DioException err) {
    final options = err.requestOptions;
    final methodOk =
        _idempotent.contains(options.method.toUpperCase()) ||
        options.extra[retryableKey] == true;
    if (!methodOk) return false;
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => _retryStatus.contains(
        err.response?.statusCode,
      ),
      // Never retry TLS/pinning failures or cancellations.
      DioExceptionType.badCertificate ||
      DioExceptionType.cancel ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.transformTimeout ||
      DioExceptionType.unknown => false,
    };
  }

  Duration _delayFor(int attempt, Response<Object?>? response) {
    final retryAfter = int.tryParse(
      response?.headers.value('retry-after') ?? '',
    );
    if (retryAfter != null && retryAfter >= 0 && retryAfter <= 30) {
      return Duration(seconds: retryAfter);
    }
    final exponential = baseDelay.inMilliseconds * pow(2, attempt);
    final jitter = _random.nextInt(baseDelay.inMilliseconds);
    return Duration(milliseconds: exponential.toInt() + jitter);
  }
}
