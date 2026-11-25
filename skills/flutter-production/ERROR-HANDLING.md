# Error handling

Reference implementation: `templates/starter_app/lib/bootstrap.dart`, `lib/core/errors/`, `lib/core/widgets/state_views.dart`.

## 1. Close every error path at startup

```dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Env.fromEnvironment();          // throws ConfigException → show a config error screen
  FlutterError.onError = (d) { /* log + report */ };          // framework errors
  PlatformDispatcher.instance.onError = (e, s) { /* log */ return true; }; // async errors
  Isolate.current.addErrorListener(port.sendPort);           // isolate errors
  ErrorWidget.builder = (d) => AppErrorWidget(details: d);   // calm placeholder, no red/grey screen
  runApp(ProviderScope(observers: [ErrorLoggingObserver(logger)], retry: (_, _) => null, child: App()));
}
```

With Sentry, call `SentryFlutter.init(..., appRunner: startApp)` after setting the handlers; Sentry chains to them. Use `sendDefaultPii = false`, no screenshots, scrub breadcrumb URLs.

## 2. Typed failures, one mapping point

A sealed `AppFailure` hierarchy: `NetworkFailure`, `TimeoutFailure`, `SecurityFailure` (TLS/pinning), `UnauthorizedFailure`, `ForbiddenFailure`, `NotFoundFailure`, `ValidationFailure(fieldErrors)`, `RateLimitedFailure(retryAfter)`, `ServerFailure(status)`, `DataFormatFailure`, `CancelledFailure`, `UnexpectedFailure`. Each knows `isRetryable` and `shouldReport` (offline / 404 / validation are expected and not reported).

`mapToFailure(error, stack)` converts `DioException` (every `DioExceptionType`, including `transformTimeout`), `SocketException`, `HandshakeException`, `TimeoutException`, `FormatException`, `TypeError`, `PlatformException`. Repositories wrap every call in `guardFailures(() async { ... })`, so controllers and widgets only see `AppFailure`.

The UI maps failure type → localized message (`AppLocalizations.failureMessage`). Never `Text(e.toString())`: it leaks URLs and tokens and means nothing to users.

## 3. Four states on every data screen

`AsyncValueView(value:, data:, onRetry:, isEmpty:, empty:)` renders loading, error with "Try again" (only when `isRetryable`), empty and data; refreshing keeps the previous data (`skipLoadingOnRefresh`). Pagination: a failed "load more" shows an inline retry under the list and keeps the loaded items. Pull-to-refresh works on empty lists too (`AlwaysScrollableScrollPhysics`). Pagination is triggered when the footer becomes visible (works even when the first page does not fill the screen).

## 4. Network

- Timeouts (connect 15 s, send/receive 20 s). Retry only idempotent methods (GET/PUT/DELETE) on timeouts, connection errors, 408/429/502/503/504, with exponential backoff + jitter and `Retry-After`. Never retry TLS errors.
- Token refresh in a `QueuedInterceptor`: parallel 401s → exactly one refresh. Replay and refresh with a **separate Dio without the interceptor** — otherwise a failing replay deadlocks the queue. Rejected refresh → sign out with a "session expired" message; network error during refresh → keep the session.
- Cancel in-flight requests when a screen is disposed (`CancelToken` + `ref.onDispose`).

## 5. Small things that crash apps

- `fromJson` validates types and throws `FormatException` (mapped to `DataFormatFailure`); optional fields get defaults instead of failing the whole page.
- After every `await` in a widget/notifier: `if (!mounted) return;` / `if (!ref.mounted) return;`.
- Async session restore must not overwrite a newer state (e.g. a sign-in that finished first).
- No empty `catch`; every catch converts, logs or explains in a comment why it is safe to ignore.
- Riverpod 3 retries failing providers automatically; disable it when the UI has its own retry.
- Strict analyzer: `strict-casts`, `strict-inference`, `strict-raw-types`, `unawaited_futures`, `discarded_futures`, `use_build_context_synchronously` as errors (`templates/starter_app/analysis_options.yaml`).
