import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers.dart';
import '../domain/user.dart';

@immutable
sealed class AuthState {
  const AuthState();
}

/// Restoring the session from secure storage (splash).
final class AuthUnknown extends AuthState {
  const AuthUnknown();
}

final class Unauthenticated extends AuthState {
  const Unauthenticated({this.sessionExpired = false});

  /// True when we were logged out by the server (shows a message).
  final bool sessionExpired;
}

final class Authenticated extends AuthState {
  const Authenticated(this.user);

  final User user;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(_restore());
    return const AuthUnknown();
  }

  Future<void> _restore() async {
    final tokens = ref.read(tokenStoreProvider);
    final logger = ref.read(loggerProvider);
    try {
      await tokens.clearIfFreshInstall();
      final stored = await tokens.read();
      if (stored == null) {
        _resolveRestore(const Unauthenticated());
        return;
      }
      final user = await ref.read(authRepositoryProvider).currentUser();
      _resolveRestore(Authenticated(user));
    } on UnauthorizedFailure {
      await tokens.clear();
      _resolveRestore(const Unauthenticated(sessionExpired: true));
    } on AppFailure catch (failure) {
      // Offline at startup etc.: fail closed, user can sign in again.
      logger.warning('Session restore failed', failure);
      _resolveRestore(const Unauthenticated());
    } on Object catch (error, stackTrace) {
      logger.error('Session restore crashed', error, stackTrace);
      _resolveRestore(const Unauthenticated());
    }
  }

  /// Restore must never overwrite a newer state (e.g. a sign-in that
  /// finished while the restore request was still in flight).
  void _resolveRestore(AuthState next) {
    if (ref.mounted && state is AuthUnknown) state = next;
  }

  /// Throws [AppFailure] so the login form can show the reason.
  Future<void> signIn({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
    await ref.read(tokenStoreProvider).save(session.tokens);
    ref.read(crashReporterProvider).setUserId(session.user.id);
    _set(Authenticated(session.user));
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    await _clearLocalSession();
    _set(const Unauthenticated());
  }

  /// Deletes the account on the server, then wipes everything local.
  /// Throws [AppFailure] (nothing is cleared if the server call fails).
  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    await _clearLocalSession();
    await ref.read(secureStoreProvider).deleteAll();
    _set(const Unauthenticated());
  }

  /// Called by the network layer when the refresh token is rejected.
  Future<void> onSessionExpired() async {
    if (state is! Authenticated) return;
    await _clearLocalSession();
    _set(const Unauthenticated(sessionExpired: true));
  }

  Future<void> _clearLocalSession() async {
    await ref.read(tokenStoreProvider).clear();
    ref.read(crashReporterProvider).setUserId(null);
  }

  void _set(AuthState next) {
    if (ref.mounted) state = next;
  }
}
