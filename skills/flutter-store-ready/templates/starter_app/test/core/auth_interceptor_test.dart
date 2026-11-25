import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/network/auth_interceptor.dart';
import 'package:starter_app/core/security/token_store.dart';
import 'package:starter_app/core/storage/preferences_store.dart';
import 'package:starter_app/core/storage/secure_store.dart';

/// Fake server: accepts only `Bearer valid-N` where N is the current version.
final class _FakeServer implements HttpClientAdapter {
  int tokenVersion = 1;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final auth = options.headers['Authorization'];
    final ok = auth == 'Bearer valid-$tokenVersion';
    return ResponseBody.fromString(
      jsonEncode({'ok': ok}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _FakeServer server;
  late TokenStore tokens;
  late Dio dio;
  late int refreshCalls;
  late int expiredCalls;
  late bool refreshRejects;
  late bool refreshMalformed;

  setUp(() async {
    server = _FakeServer();
    tokens = TokenStore(
      secureStore: InMemorySecureStore(),
      preferences: InMemoryPreferencesStore(),
    );
    await tokens.save(
      const AuthTokens(accessToken: 'valid-1', refreshToken: 'r'),
    );
    refreshCalls = 0;
    expiredCalls = 0;
    refreshRejects = false;
    refreshMalformed = false;

    final replay = Dio()..httpClientAdapter = server;
    dio = Dio()..httpClientAdapter = server;
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: tokens,
        replayDio: replay,
        refresh: (_) async {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (refreshMalformed) {
            throw const FormatException('Invalid refresh response');
          }
          if (refreshRejects) {
            throw DioException.badResponse(
              statusCode: 401,
              requestOptions: RequestOptions(path: '/auth/refresh'),
              response: Response<Object?>(
                requestOptions: RequestOptions(path: '/auth/refresh'),
                statusCode: 401,
              ),
            );
          }
          server.tokenVersion = 2;
          return const AuthTokens(accessToken: 'valid-2', refreshToken: 'r2');
        },
        onSessionExpired: () async => expiredCalls++,
      ),
    );
  });

  test('attaches the token', () async {
    final res = await dio.get<Object?>('/me');
    expect(res.statusCode, 200);
    expect(refreshCalls, 0);
  });

  test(
    'parallel 401s trigger exactly one refresh, all requests succeed',
    () async {
      server.tokenVersion = 2; // current token became invalid
      final results = await Future.wait([
        for (var i = 0; i < 5; i++) dio.get<Object?>('/items/$i'),
      ]);
      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(refreshCalls, 1);
      expect(tokens.cachedAccessToken, 'valid-2');
    },
  );

  test('rejected refresh token signs the user out', () async {
    server.tokenVersion = 2;
    refreshRejects = true;
    await expectLater(dio.get<Object?>('/me'), throwsA(isA<DioException>()));
    expect(expiredCalls, 1);
  });

  test('a malformed refresh response fails the request without locking the '
      'queue', () async {
    server.tokenVersion = 2;
    refreshMalformed = true;
    await expectLater(
      dio.get<Object?>('/me').timeout(const Duration(seconds: 2)),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<FormatException>(),
        ),
      ),
    );
    expect(expiredCalls, 0, reason: 'a server bug must not sign the user out');

    // The queue is free again: the next request refreshes and succeeds.
    refreshMalformed = false;
    final res = await dio
        .get<Object?>('/me')
        .timeout(const Duration(seconds: 2));
    expect(res.statusCode, 200);
  });

  test('login requests never carry a token', () async {
    server.tokenVersion = 99;
    await expectLater(
      dio.post<Object?>(
        '/auth/login',
        options: Options(extra: {skipAuthKey: true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls, 0, reason: '401 on login must not trigger refresh');
  });
}
