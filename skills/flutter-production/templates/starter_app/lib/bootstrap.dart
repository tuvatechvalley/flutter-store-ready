import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/crash_reporter.dart';
import 'core/network/connectivity_service.dart';
import 'core/providers.dart';
import 'core/storage/preferences_store.dart';
import 'core/storage/secure_store.dart';
import 'core/widgets/app_error_widget.dart';

/// Starts the app with every error path covered:
///
/// 1. Configuration is validated before anything runs (fail closed).
/// 2. Framework errors      → FlutterError.onError
/// 3. Async / platform errs → PlatformDispatcher.instance.onError
/// 4. Errors in isolates    → Isolate.current.addErrorListener
/// 5. Widget build errors   → ErrorWidget.builder (friendly placeholder)
/// 6. Provider errors       → ProviderObserver.providerDidFail
/// 7. Crash reporting (Sentry) wraps 2–4 when a DSN is configured.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Env env;
  try {
    env = Env.fromEnvironment();
  } on ConfigException catch (e) {
    runApp(_ConfigErrorApp(message: kReleaseMode ? null : e.message));
    return;
  }

  final reporter = env.crashReportingEnabled
      ? const SentryCrashReporter()
      : const NoopCrashReporter();
  final logger = AppLogger(crashReporter: reporter);

  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
    logger.warning('Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.warning('Uncaught async error: ${error.runtimeType}');
    return true; // handled: do not crash the app
  };
  final isolateErrors = RawReceivePort((Object? pair) {
    logger.warning('Isolate error: $pair');
  });
  Isolate.current.addErrorListener(isolateErrors.sendPort);
  ErrorWidget.builder = (details) => AppErrorWidget(details: details);

  void startApp() => runApp(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(env),
        crashReporterProvider.overrideWithValue(reporter),
        loggerProvider.overrideWithValue(logger),
        secureStoreProvider.overrideWithValue(FlutterSecureStore()),
        preferencesStoreProvider.overrideWithValue(SharedPreferencesStore()),
        connectivityServiceProvider.overrideWithValue(
          PlusConnectivityService(),
        ),
      ],
      observers: [ErrorLoggingObserver(logger)],
      // Riverpod 3 retries failed providers automatically. Network retries
      // already happen in Dio; the UI offers an explicit "Try again".
      retry: (retryCount, error) => null,
      child: const App(),
    ),
  );

  if (env.crashReportingEnabled) {
    // Sentry installs its own FlutterError / PlatformDispatcher handlers and
    // chains to the ones above, so local logging keeps working.
    await SentryFlutter.init(
      (options) => configureSentry(
        options,
        dsn: env.sentryDsn,
        environment: env.flavor.name,
      ),
      appRunner: startApp,
    );
  } else {
    startApp();
  }
}

/// Logs every provider failure in one place.
final class ErrorLoggingObserver extends ProviderObserver {
  ErrorLoggingObserver(this._logger);

  final AppLogger _logger;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _logger.error(
      'Provider failed: ${context.provider.name ?? context.provider.runtimeType}',
      error,
      stackTrace,
    );
  }
}

/// Shown when the build was produced with an unsafe/invalid configuration.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message ?? 'Configuration error (code CFG-1).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
}
