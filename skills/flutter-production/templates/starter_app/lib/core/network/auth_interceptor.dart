import 'package:dio/dio.dart';

import '../security/token_store.dart';

/// Marks requests that must not carry a token (login, refresh).
const String skipAuthKey = 'skipAuth';
const String _retriedKey = 'authRetried';

/// Attaches the access token and transparently refreshes it once on 401.
///
/// [QueuedInterceptor] serializes callbacks, so ten parallel requests that
/// all get 401 trigger exactly one refresh; the rest reuse the new token.
final class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this._tokenStore,
    required this._replayDio,
    required this._refresh,
    required this._onSessionExpired,
  });

  final TokenStore _tokenStore;

  /// A Dio WITHOUT this interceptor, used to replay the original request.
  ///
  /// Replaying through the same Dio from inside a [QueuedInterceptor]
  /// deadlocks when the replay fails: its error waits in the queue behind the
  /// handler that is waiting for it.
  final Dio _replayDio;

  /// Exchanges a refresh token for new tokens. Throws if rejected.
  /// Must also use a Dio without this interceptor (same deadlock reason).
  final Future<AuthTokens> Function(String refreshToken) _refresh;

  /// Called when the session cannot be recovered (forces logout).
  final Future<void> Function() _onSessionExpired;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenStore.cachedAccessToken;
    if (options.extra[skipAuthKey] != true && token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    if (!isUnauthorized ||
        request.extra[skipAuthKey] == true ||
        request.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    try {
      final usedToken = _bearer(request.headers['Authorization']);
      var current = _tokenStore.cachedAccessToken;

      // Another queued request already refreshed: just replay with new token.
      if (current == null || current == usedToken) {
        final stored = await _tokenStore.read();
        if (stored == null) {
          await _onSessionExpired();
          return handler.next(err);
        }
        final fresh = await _refresh(stored.refreshToken);
        await _tokenStore.save(fresh);
        current = fresh.accessToken;
      }

      request.extra[_retriedKey] = true;
      request.headers['Authorization'] = 'Bearer $current';
      final response = await _replayDio.fetch<Object?>(request);
      return handler.resolve(response);
    } on DioException catch (refreshError) {
      final status = refreshError.response?.statusCode;
      if (status == 401 || status == 403 || status == 400) {
        await _onSessionExpired();
        return handler.next(err);
      }
      // Network problem during refresh: keep the session, surface the error.
      return handler.next(refreshError);
    }
  }

  static String? _bearer(Object? header) {
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }
}
