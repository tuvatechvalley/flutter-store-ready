import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../config/env.dart';
import '../logging/app_logger.dart';
import '../logging/redactor.dart';
import 'certificate_pinner.dart';

/// Builds the single [Dio] instance used for the app's backend.
///
/// Security properties:
/// * TLS only (enforced by [Env]); invalid certificates are always rejected.
/// * SPKI pinning for the API host when pins are configured.
/// * Strict timeouts so a dead network never hangs the UI forever.
/// * Request logging only in debug builds, always redacted.
Dio createApiDio({required Env env, required AppLogger logger}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: env.apiBaseUrl.toString(),
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: {HttpHeaders.acceptHeader: 'application/json'},
      // Do not silently follow redirects to other hosts with our headers.
      followRedirects: false,
      maxRedirects: 0,
    ),
  );

  final pinner = CertificatePinner(env.certificatePins);
  final pinnedHost = env.apiBaseUrl.host;

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient()
      ..idleTimeout = const Duration(seconds: 15)
      // Never accept a certificate the OS trust store rejected.
      ..badCertificateCallback = (_, _, _) => false,
    validateCertificate: pinner.isEnabled
        ? (certificate, host, port) {
            if (host != pinnedHost) return true;
            if (certificate == null) return false;
            final ok = pinner.matches(certificate.der);
            if (!ok) logger.warning('Certificate pin mismatch for $host');
            return ok;
          }
        : null,
  );

  if (!env.isProd) {
    dio.interceptors.add(_RedactedLogInterceptor(logger));
  }
  return dio;
}

final class _RedactedLogInterceptor extends Interceptor {
  _RedactedLogInterceptor(this._logger);

  final AppLogger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _logger.debug('→ ${options.method} ${Redactor.redactUrl(options.uri)}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final o = response.requestOptions;
    _logger.debug(
      '← ${response.statusCode} ${o.method} ${Redactor.redactUrl(o.uri)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final o = err.requestOptions;
    _logger.debug(
      '✕ ${err.type.name} ${err.response?.statusCode ?? ''} '
      '${o.method} ${Redactor.redactUrl(o.uri)}',
    );
    handler.next(err);
  }
}
