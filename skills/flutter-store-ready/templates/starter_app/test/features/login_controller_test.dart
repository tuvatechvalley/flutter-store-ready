import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/errors/app_failure.dart';
import 'package:starter_app/core/providers.dart';
import 'package:starter_app/features/auth/data/auth_repository.dart';
import 'package:starter_app/features/auth/presentation/auth_controller.dart';
import 'package:starter_app/features/auth/presentation/login_controller.dart';

import '../helpers/test_app.dart';

void main() {
  test('successful sign-in stores tokens and authenticates', () async {
    final container = createTestContainer();
    final sub = container.listen(loginControllerProvider, (_, _) {});
    addTearDown(sub.close);

    await container
        .read(loginControllerProvider.notifier)
        .submit(
          email: ' DEMO@example.com ',
          password: FakeAuthRepository.demoPassword,
        );

    expect(container.read(authControllerProvider), isA<Authenticated>());
    expect(container.read(tokenStoreProvider).cachedAccessToken, isNotNull);
    expect(container.read(loginControllerProvider).failure, isNull);
  });

  test('locks the form after 5 wrong passwords, unlocks after 30s', () async {
    var now = DateTime(2026);
    final container = createTestContainer(
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final sub = container.listen(loginControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(loginControllerProvider.notifier);

    for (var i = 0; i < LoginController.maxAttempts; i++) {
      await controller.submit(email: 'demo@example.com', password: 'Wrong1234');
    }
    expect(
      container.read(loginControllerProvider).failure,
      isA<UnauthorizedFailure>(),
    );
    expect(controller.remainingLockSeconds(), greaterThan(0));

    // Submitting while locked does nothing (no request is sent).
    await controller.submit(
      email: 'demo@example.com',
      password: FakeAuthRepository.demoPassword,
    );
    expect(container.read(authControllerProvider), isNot(isA<Authenticated>()));

    now = now.add(LoginController.lockDuration + const Duration(seconds: 1));
    expect(controller.remainingLockSeconds(), 0);
    await controller.submit(
      email: 'demo@example.com',
      password: FakeAuthRepository.demoPassword,
    );
    expect(container.read(authControllerProvider), isA<Authenticated>());
  });

  test('delete account wipes tokens and signs out', () async {
    final container = createTestContainer();
    final sub = container.listen(authControllerProvider, (_, _) {});
    addTearDown(sub.close);
    final auth = container.read(authControllerProvider.notifier);
    await auth.signIn(
      email: FakeAuthRepository.demoEmail,
      password: FakeAuthRepository.demoPassword,
    );
    expect(container.read(authControllerProvider), isA<Authenticated>());

    await auth.deleteAccount();
    expect(container.read(authControllerProvider), isA<Unauthenticated>());
    expect(await container.read(tokenStoreProvider).read(), isNull);
  });
}
