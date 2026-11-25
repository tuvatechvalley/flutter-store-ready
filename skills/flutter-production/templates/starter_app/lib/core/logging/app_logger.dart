import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../errors/app_failure.dart';
import 'crash_reporter.dart';
import 'redactor.dart';

enum LogLevel { debug, info, warning, error }

/// The only logging entry point in the app. `print` is banned by lint.
///
/// * Every message is redacted before it leaves this class.
/// * debug/info never reach release device logs.
/// * warnings become crash-report breadcrumbs, errors become reports
///   (unless they are expected failures such as "offline").
final class AppLogger {
  AppLogger({required this._crashReporter, bool? verbose})
    : _verbose = verbose ?? !kReleaseMode;

  final CrashReporter _crashReporter;
  final bool _verbose;

  void debug(String message) => _log(LogLevel.debug, message);

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message, [Object? error]) =>
      _log(LogLevel.warning, message, error);

  void error(
    String message,
    Object error, [
    StackTrace? stackTrace,
    bool fatal = false,
  ]) {
    _log(LogLevel.error, message, error, stackTrace);
    final shouldReport = error is! AppFailure || error.shouldReport;
    if (shouldReport || fatal) {
      _crashReporter.recordError(
        error is AppFailure ? (error.cause ?? error) : error,
        stackTrace ?? (error is AppFailure ? error.stackTrace : null),
        reason: Redactor.redact(message),
        fatal: fatal,
      );
    }
  }

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    final safeMessage = Redactor.redact(message);
    if (level.index >= LogLevel.warning.index) {
      _crashReporter.addBreadcrumb('[${level.name}] $safeMessage');
    }
    if (!_verbose && level.index < LogLevel.warning.index) return;
    developer.log(
      safeMessage,
      name: 'app',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error == null ? null : Redactor.redact(error.toString()),
      stackTrace: _verbose ? stackTrace : null,
    );
  }
}
