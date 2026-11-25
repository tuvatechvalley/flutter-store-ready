import 'dart:async';

import 'package:dio/dio.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/security/token_store.dart';
import '../domain/user.dart';

abstract interface class AuthRepository {
  /// Throws [UnauthorizedFailure] / [ValidationFailure] on bad credentials.
  Future<Session> signIn({required String email, required String password});

  /// Throws on rejected refresh tokens (caller must sign the user out).
  Future<AuthTokens> refresh(String refreshToken);

  Future<User> currentUser();

  /// Best effort: revokes the token server-side. Never throws.
  Future<void> signOut();

  /// Permanently deletes the account and its data on the server.
  /// Required by Google Play (and App Store) for apps with sign-up.
  Future<void> deleteAccount();
}

final class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository(this._dio);

  final Dio _dio;

  @override
  Future<Session> signIn({required String email, required String password}) =>
      guardFailures(() async {
        final response = await _dio.post<Object?>(
          '/auth/login',
          data: {'email': email, 'password': password},
          options: Options(extra: {skipAuthKey: true}),
        );
        final body = response.data;
        if (body is! Map) throw const FormatException('Invalid login response');
        return Session(
          user: User.fromJson(body['user']),
          tokens: _tokens(body),
        );
      });

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    // Errors are intentionally NOT mapped: AuthInterceptor needs the raw
    // DioException status code to decide between "logout" and "retry later".
    final response = await _dio.post<Object?>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: Options(extra: {skipAuthKey: true}),
    );
    final body = response.data;
    if (body is! Map) throw const FormatException('Invalid refresh response');
    return _tokens(body);
  }

  @override
  Future<User> currentUser() => guardFailures(() async {
    final response = await _dio.get<Object?>('/me');
    return User.fromJson(response.data);
  });

  @override
  Future<void> signOut() async {
    try {
      await _dio.post<Object?>('/auth/logout');
    } on DioException {
      // Local sign-out must always succeed, even offline.
    }
  }

  @override
  Future<void> deleteAccount() =>
      guardFailures(() => _dio.delete<Object?>('/me'));

  static AuthTokens _tokens(Map<Object?, Object?> body) {
    final access = body['access_token'];
    final refresh = body['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const FormatException('Missing tokens');
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }
}

/// Offline fake backend for demos and tests. Accepts one demo account.
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = const Duration(milliseconds: 600)});

  static const demoEmail = 'demo@example.com';
  static const demoPassword = 'Demo1234';
  static const _user = User(id: 'u_1', email: demoEmail, name: 'Demo User');

  final Duration latency;
  int _counter = 0;

  @override
  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (email.toLowerCase() != demoEmail || password != demoPassword) {
      throw const UnauthorizedFailure();
    }
    return Session(user: _user, tokens: _issue());
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    await Future<void>.delayed(latency);
    return _issue();
  }

  @override
  Future<User> currentUser() async {
    await Future<void>.delayed(latency);
    return _user;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(latency);
  }

  AuthTokens _issue() {
    _counter++;
    return AuthTokens(
      accessToken: 'fake-access-$_counter',
      refreshToken: 'fake-refresh-$_counter',
    );
  }
}
