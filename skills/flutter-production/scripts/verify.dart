// One command for every gate + the final report.
//
//   dart run tool/flutter_production/verify.dart [--release] [--config <json>]
//            [--last-version-code <n>]
//
// 1. flutter pub get
// 2. (--release) flutter build appbundle --release --obfuscate
//    --split-debug-info=build/symbols --dart-define-from-file=<config>
// 3. project_report.dart: format, analyze, forbidden patterns, tests,
//    error handling, security, large text, store rules, Google Play audit
//    → build/reports/flutter-production/PROJECT_REPORT.md
//
// Exit code 1 when the report has blocking items.
// ignore_for_file: avoid_print

import 'dart:io';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final scripts = File.fromUri(Platform.script).parent.path;
  final project = Directory.current.path;
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';

  Future<int> run(String title, String exe, List<String> a) async {
    print('\n▶ $title');
    final p = await Process.start(
      exe,
      a,
      workingDirectory: project,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    return p.exitCode;
  }

  if (await run('Dependencies', flutter, ['pub', 'get']) != 0) {
    exitCode = 1;
    return;
  }

  if (args.contains('--release')) {
    final config = opt('--config') ?? 'config/prod.json';
    final hasConfig = File('$project/$config').existsSync();
    if (!hasConfig) {
      print('  (no $config: building without --dart-define-from-file)');
    }
    final code = await run('Release app bundle (obfuscated)', flutter, [
      'build',
      'appbundle',
      '--release',
      '--obfuscate',
      '--split-debug-info=build/symbols',
      if (hasConfig) '--dart-define-from-file=$config',
    ]);
    if (code != 0) {
      print('\n✘ Release build failed.');
      exitCode = 1;
      return;
    }
  }

  final code = await run(
    'Production readiness report',
    Platform.resolvedExecutable,
    [
      '$scripts/project_report.dart',
      project,
      if (opt('--last-version-code') case final v?) ...[
        '--last-version-code',
        v,
      ],
    ],
  );
  exitCode = code;
}
