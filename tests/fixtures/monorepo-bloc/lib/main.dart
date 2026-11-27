import 'dart:ui';
import 'package:flutter/material.dart';

/*
  Block comment decoys — must NEVER trigger forbidden or audit checks:
  print('leaked secret');
  final badUrl = 'http://evil.example.com/v1';
  TextScaler.noScaling;
  final flag = isTestFlight;
*/

void main() {
  FlutterError.onError = (details) {};
  PlatformDispatcher.instance.onError = (error, stack) {
    // Unbalanced parens inside string literal must not corrupt bracket walking:
    _log('caught ) ) ) Text(((', '$error');
    return true;
  };
  ErrorWidget.builder = (_) => const SizedBox.shrink();
  // Inline comment decoy: print('should be ignored');
  runApp(const SafeArea(child: SizedBox.shrink()));
}

void _log(String tag, String detail) {}
