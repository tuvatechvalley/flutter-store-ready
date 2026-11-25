import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/items/data/items_repository.dart';
import 'config/env.dart';
import 'logging/app_logger.dart';
import 'logging/crash_reporter.dart';
import 'network/api_client.dart';
import 'network/auth_interceptor.dart';
import 'network/connectivity_service.dart';
import 'network/retry_interceptor.dart';
import 'security/token_store.dart';
import 'storage/preferences_store.dart';
import 'storage/secure_store.dart';

/// Composition root. Infrastructure is overridden in `bootstrap.dart` (real
/// implementations) and in tests (fakes). Providers that must be overridden
/// throw a clear error instead of returning a half-configured object.
Never _mustOverride(String name) =>
    throw UnimplementedError('$name must be overridden in ProviderScope.');

final envProvider = Provider<Env>((ref) => _mustOverride('envProvider'));

final crashReporterProvider = Provider<CrashReporter>(
  (ref) => const NoopCrashReporter(),
);

final loggerProvider = Provider<AppLogger>(
  (ref) => AppLogger(crashReporter: ref.watch(crashReporterProvider)),
);

final secureStoreProvider = Provider<SecureStore>(
  (ref) => _mustOverride('secureStoreProvider'),
);

final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => _mustOverride('preferencesStoreProvider'),
);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => const AlwaysOnlineConnectivityService(),
);

final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).watchOnline(),
);

/// Injectable clock so time-based logic (lockouts) is testable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(
    secureStore: ref.watch(secureStoreProvider),
    preferences: ref.watch(preferencesStoreProvider),
  ),
);

/// Plain pinned client without auth handling: used for token refresh and for
/// replaying requests after a refresh (see [AuthInterceptor]).
final _bareDioProvider = Provider<Dio>((ref) {
  final dio = createApiDio(
    env: ref.watch(envProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

final dioProvider = Provider<Dio>((ref) {
  final env = ref.watch(envProvider);
  final logger = ref.watch(loggerProvider);
  final bare = ref.watch(_bareDioProvider);
  final dio = createApiDio(env: env, logger: logger);
  final refreshRepository = env.useMockApi
      ? FakeAuthRepository()
      : HttpAuthRepository(bare);

  dio.interceptors.insertAll(0, [
    AuthInterceptor(
      tokenStore: ref.watch(tokenStoreProvider),
      replayDio: bare,
      refresh: refreshRepository.refresh,
      onSessionExpired: () =>
          ref.read(authControllerProvider.notifier).onSessionExpired(),
    ),
    RetryInterceptor(dio: dio),
  ]);
  ref.onDispose(dio.close);
  return dio;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final env = ref.watch(envProvider);
  return env.useMockApi
      ? FakeAuthRepository()
      : HttpAuthRepository(ref.watch(dioProvider));
});

final itemsRepositoryProvider = Provider<ItemsRepository>((ref) {
  final env = ref.watch(envProvider);
  return env.useMockApi
      ? FakeItemsRepository()
      : HttpItemsRepository(ref.watch(dioProvider));
});
