import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

import 'redactor.dart';

/// Abstraction over crash reporting so it can be swapped (Sentry, Crashlytics)
/// and faked in tests.
abstract interface class CrashReporter {
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  });

  void addBreadcrumb(String message);

  void setUserId(String? userId);
}

/// Used in dev builds and tests: crash reports are only logged locally.
final class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {}

  @override
  void addBreadcrumb(String message) {}

  @override
  void setUserId(String? userId) {}
}

final class SentryCrashReporter implements CrashReporter {
  const SentryCrashReporter();

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) async {
          if (reason != null) await scope.setTag('reason', reason);
          scope.level = fatal ? SentryLevel.fatal : SentryLevel.error;
        },
      ),
    );
  }

  @override
  void addBreadcrumb(String message) {
    unawaited(Sentry.addBreadcrumb(Breadcrumb(message: message)));
  }

  @override
  void setUserId(String? userId) {
    // Only an opaque id: never e-mail, name or phone number.
    final result = Sentry.configureScope(
      (scope) => scope.setUser(userId == null ? null : SentryUser(id: userId)),
    );
    if (result is Future<void>) unawaited(result);
  }
}

/// Privacy-preserving Sentry configuration shared by bootstrap.
void configureSentry(
  SentryFlutterOptions options, {
  required String dsn,
  required String environment,
}) {
  options
    ..dsn = dsn
    ..environment = environment
    ..sendDefaultPii = false
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..tracesSampleRate = 0.1
    ..beforeBreadcrumb = _scrubBreadcrumb;
}

Breadcrumb? _scrubBreadcrumb(Breadcrumb? crumb, Hint hint) {
  if (crumb == null) return null;
  final message = crumb.message;
  final data = crumb.data;
  final url = data?['url'];
  if (url is String) {
    final uri = Uri.tryParse(url);
    data!['url'] = uri == null ? Redactor.mask : Redactor.redactUrl(uri);
  }
  if (message != null) crumb.message = Redactor.redact(message);
  return crumb;
}
