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

The UI maps failure type → localized message (`AppLocalizations.failureMessage`). Never `Text(e.toString())`: it leaks URLs and tokens and means nothing to users (section 3).

## 3. Messages users can understand

The reader is not a developer. An error message says **what happened** and **what to do next**, in the user's language, in one or two short sentences.

Never on screen (the audit blocks the first two):

| Never show | Example | Show instead |
|---|---|---|
| Exception text | `Text('$e')`, `e.toString()`, `snapshot.error`, `e.message`, `runtimeType`, stack traces | the localized message of the mapped failure |
| HTTP status / response body | `'Error ${response.statusCode}'`, `response.data` | "Something went wrong on our side. Please try again in a few minutes." |
| Server text passed through | `Text(data['message'])` | your own message chosen by the server's error **code**; server text only for field validation the backend already localizes |
| Developer wording | "SocketException", "HTTP 500", "Internal Server Error", "status code", "null" | "Could not connect. Check your internet and try again." |

One message per failure type, in every language (`AppLocalizations.failureMessage`). Suggested wording:

| Failure | English | Türkçe |
|---|---|---|
| `NetworkFailure` | Could not connect. Check your internet and try again. | Bağlanılamadı. İnternetini kontrol edip tekrar dene. |
| `TimeoutFailure` | This is taking too long. Please try again. | İşlem çok uzun sürdü. Lütfen tekrar dene. |
| `ServerFailure` (5xx) | Something went wrong on our side. Please try again in a few minutes. | Bizden kaynaklı bir sorun oluştu. Birkaç dakika sonra tekrar dene. |
| `UnauthorizedFailure` | Your session has ended. Please sign in again. | Oturumun sona erdi. Lütfen tekrar giriş yap. |
| `ForbiddenFailure` | You do not have permission to do this. | Bu işlem için yetkin yok. |
| `NotFoundFailure` | We could not find what you were looking for. | Aradığın şeyi bulamadık. |
| `RateLimitedFailure` | Too many attempts. Please wait a moment and try again. | Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene. |
| `ValidationFailure` | the field's own message, next to the field | alanın kendi mesajı, alanın yanında |
| anything else | Something went wrong. Please try again. | Bir şeyler ters gitti. Lütfen tekrar dene. |

Rules:

- No blame ("invalid input", "you entered wrong data"), no jargon, no ALL CAPS, no "Error:" prefix, no exclamation marks.
- Offer the action: "Try again" when `isRetryable`, "Sign in" for an expired session, "Open settings" for a missing permission.
- The technical detail (status code, exception, stack) goes to the logger and the crash reporter — never into the message. If support needs a reference, show a short neutral code ("Code: A-102"), not the status code.
- Unknown errors still get a friendly sentence; never an empty screen, a spinner that never ends, or "null".
- The same rule for every place text reaches the user: notifications written by background services, web builds ("Failed to fetch", "Unexpected token …" are browser messages, not ours), and validation messages that come from the server (they must arrive in the user's language, or be mapped by code).
- No codes in brackets — "Something went wrong (500)" is still a status code.
- Offline is a state, not an error dialog: show "No connection" with "Try again", and keep what the user typed in the form.
- Errors are announced to screen readers (`Semantics(liveRegion: true)`).

The audit (`project_report.dart`) checks this: exception text or status codes on screen are **blocking**; server text passed through and developer wording (also in `.arb` files) are warnings. A deliberate exception is marked on its line with `// forbidden:allow`.

## 4. Four states on every data screen

`AsyncValueView(value:, data:, onRetry:, isEmpty:, empty:)` renders loading, error with "Try again" (only when `isRetryable`), empty and data; refreshing keeps the previous data (`skipLoadingOnRefresh`). Pagination: a failed "load more" shows an inline retry under the list and keeps the loaded items. Pull-to-refresh works on empty lists too (`AlwaysScrollableScrollPhysics`). Pagination is triggered when the footer becomes visible (works even when the first page does not fill the screen).

## 5. Network

- Timeouts (connect 15 s, send/receive 20 s). Retry only idempotent methods (GET/PUT/DELETE) on timeouts, connection errors, 408/429/502/503/504, with exponential backoff + jitter and `Retry-After`. Never retry TLS errors.
- Token refresh in a `QueuedInterceptor`: parallel 401s → exactly one refresh. Replay and refresh with a **separate Dio without the interceptor** — otherwise a failing replay deadlocks the queue. Rejected refresh → sign out with a "session expired" message; network error during refresh → keep the session.
- Cancel in-flight requests when a screen is disposed (`CancelToken` + `ref.onDispose`).

## 6. Small things that crash apps

- `fromJson` validates types and throws `FormatException` (mapped to `DataFormatFailure`); optional fields get defaults instead of failing the whole page.
- After every `await` in a widget/notifier: `if (!mounted) return;` / `if (!ref.mounted) return;` — to protect **UI updates** only. It must never skip the action itself: a menu or dialog is already unmounted when its `await` returns, so "Sign out" started there silently does nothing. Capture the notifier before the await and act through it (`NAVIGATION-AND-LIFECYCLE.md`, section 3).
- Async session restore must not overwrite a newer state (e.g. a sign-in that finished first).
- No empty `catch`; every catch converts, logs or explains in a comment why it is safe to ignore.
- Riverpod 3 retries failing providers automatically; disable it when the UI has its own retry.
- Strict analyzer: `strict-casts`, `strict-inference`, `strict-raw-types`, `unawaited_futures`, `discarded_futures`, `use_build_context_synchronously` as errors (`templates/starter_app/analysis_options.yaml`).
