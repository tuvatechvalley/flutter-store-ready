// One command for every gate + the final report.
//
//   dart run tool/flutter_store_ready/verify.dart [--release] [--config <json>]
//            [--last-version-code <n>] [--last-build-number <n>] [--ci]
//            [--skip-ios-build] [--skip-ios] [--skip-play]
//
// --skip-ios / --skip-play: the app ships on one store only.
//
// --ci: for pipelines. The upload key and config/prod.json are not on the
// CI machine, so their absence is reported as a warning, not a blocker.
//
// 1. flutter pub get
// 2. (--release) flutter build appbundle --release --obfuscate
//    --split-debug-info=build/symbols --dart-define-from-file=<config>
//    On macOS with an ios/ folder also: flutter build ipa --release
//    --obfuscate --split-debug-info=build/symbols-ios (other systems
//    cannot build iOS: the report says so).
// 3. project_report.dart: format, analyze, forbidden patterns, tests,
//    error handling, security, large text, store rules, Google Play and
//    App Store audits
//    → build/reports/flutter-store-ready/PROJECT_REPORT.md
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

    final hasIos = Directory('$project/ios').existsSync();
    if (hasIos && !args.contains('--skip-ios-build')) {
      if (!Platform.isMacOS) {
        print(
          '\n(iOS archive skipped: `flutter build ipa` needs a Mac with Xcode. '
          'The App Store audit below still checks the project files.)',
        );
      } else {
        final ios = await run('Release iOS archive (obfuscated)', flutter, [
          'build',
          'ipa',
          '--release',
          '--obfuscate',
          '--split-debug-info=build/symbols-ios',
          if (hasConfig) '--dart-define-from-file=$config',
        ]);
        if (ios != 0) {
          print('\n✘ iOS release build failed.');
          exitCode = 1;
          return;
        }
      }
    }
  }

  final code = await run(
    'Production readiness report',
    Platform.resolvedExecutable,
    [
      '$scripts/project_report.dart',
      project,
      for (final flag in ['--ci', '--skip-ios', '--skip-play'])
        if (args.contains(flag)) flag,
      if (opt('--last-version-code') case final v?) ...[
        '--last-version-code',
        v,
      ],
      if (opt('--last-build-number') case final v?) ...[
        '--last-build-number',
        v,
      ],
    ],
  );
  exitCode = code;
}
