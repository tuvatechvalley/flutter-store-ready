import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/providers.dart';
import '../../../core/security/input_validators.dart';
import 'auth_controller.dart';

@immutable
final class LoginState {
  const LoginState({
    this.isSubmitting = false,
    this.failure,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final bool isSubmitting;
  final AppFailure? failure;
  final int failedAttempts;
  final DateTime? lockedUntil;

  LoginState copyWith({
    bool? isSubmitting,
    AppFailure? Function()? failure,
    int? failedAttempts,
    DateTime? Function()? lockedUntil,
  }) => LoginState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failure: failure != null ? failure() : this.failure,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: lockedUntil != null ? lockedUntil() : this.lockedUntil,
  );
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, LoginState>(
      LoginController.new,
    );

/// Form state + client-side brute-force friction.
///
/// The lockout is a UX speed bump only. Real protection (rate limiting,
/// account lockout, CAPTCHA) MUST live on the server.
final class LoginController extends Notifier<LoginState> {
  static const int maxAttempts = 5;
  static const Duration lockDuration = Duration(seconds: 30);

  @override
  LoginState build() => const LoginState();

  /// Seconds left until the lockout ends, or 0.
  int remainingLockSeconds() {
    final until = state.lockedUntil;
    if (until == null) return 0;
    final left = until.difference(ref.read(clockProvider)()).inSeconds;
    return left > 0 ? left + 1 : 0;
  }

  Future<void> submit({required String email, required String password}) async {
    if (state.isSubmitting || remainingLockSeconds() > 0) return;
    state = state.copyWith(isSubmitting: true, failure: () => null);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(email: InputValidators.sanitize(email), password: password);
      if (ref.mounted) state = const LoginState();
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) return;
      final failure = mapToFailure(error, stackTrace);
      ref
          .read(loggerProvider)
          .warning('Sign-in failed: ${failure.runtimeType}');
      final badCredentials =
          failure is UnauthorizedFailure || failure is ValidationFailure;
      final attempts = badCredentials
          ? state.failedAttempts + 1
          : state.failedAttempts;
      final lock = attempts >= maxAttempts;
      state = state.copyWith(
        isSubmitting: false,
        failure: () => failure,
        failedAttempts: lock ? 0 : attempts,
        lockedUntil: () =>
            lock ? ref.read(clockProvider)().add(lockDuration) : null,
      );
    }
  }
}
