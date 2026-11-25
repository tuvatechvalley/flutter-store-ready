// Installs the flutter-store-ready toolkit into a Flutter project.
//
//   dart run <skill>/scripts/install.dart <project_dir> [--starter] [--force]
//
// Always:
//   * tool/flutter_store_ready/  ← verify, report, Play audit, hardening, checks
//   * analysis_options.yaml      ← strict analyzer (old one kept as .bak)
//   * .github/workflows/flutter_store_ready.yml ← CI gates
//   * .gitignore / .gitattributes ← secrets and line endings
//   * android/ios hardening       (if the native projects exist)
//
// With --starter (fresh `flutter create` app, or --force):
//   * lib/, test/, config/ from the production starter (error handling,
//     security, responsive + large text, TR/EN, auth, settings, tests)
//   * pubspec dependencies merged, package imports renamed to your app
//
// Only dart:io: works on Windows, macOS and Linux.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

late final String _skillDir;
late final String _project;
final _done = <String>[];
final _skipped = <String>[];
final _notes = <String>[];

void main(List<String> args) {
  _skillDir = File.fromUri(Platform.script).parent.parent.path;
  final positional = args.where((a) => !a.startsWith('--')).toList();
  if (positional.isEmpty) {
    stderr.writeln(
      'Usage: dart run <skill>/scripts/install.dart <project_dir> [--starter] [--force]',
    );
    exitCode = 2;
    return;
  }
  if (!Directory(positional.first).existsSync()) {
    stderr.writeln('Folder not found: ${positional.first}');
    exitCode = 2;
    return;
  }
  _project = Directory(positional.first).resolveSymbolicLinksSync();
  final pubspec = File('$_project/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('No pubspec.yaml in $_project: run `flutter create` first.');
    exitCode = 2;
    return;
  }
  final force = args.contains('--force');
  final appName = RegExp(
    r'^name:\s*(\w+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync())?.group(1);
  if (appName == null) {
    stderr.writeln('Could not read the package name from pubspec.yaml.');
    exitCode = 2;
    return;
  }

  _installTools();
  _warnIfDart2(pubspec.readAsStringSync());
  _installAnalysisOptions(force: force);
  _installCi();
  _installGitFiles();

  if (args.contains('--starter')) {
    final main = File('$_project/lib/main.dart');
    final isFresh =
        !main.existsSync() ||
        main.readAsStringSync().contains('_incrementCounter') ||
        main.readAsStringSync().trim().length < 400;
    final tooOld = _starterNeedsNewerFlutter();
    if (!isFresh && !force) {
      stderr.writeln(
        '\nlib/main.dart is not the default counter app. Refusing to overwrite '
        'your code with the starter. Re-run with --force if you really want to.',
      );
      exitCode = 1;
    } else if (tooOld != null && !force) {
      stderr.writeln(
        '\n$tooOld\nThe starter was NOT installed (the toolkit was). Run '
        '`flutter upgrade` and re-run with --starter, or pass --force to '
        'install it anyway (`flutter pub get` will fail until you upgrade).',
      );
      exitCode = 1;
    } else {
      _installStarter(appName);
    }
  }

  if (Directory('$_project/android').existsSync() ||
      Directory('$_project/ios').existsSync()) {
    final r = Process.runSync(Platform.resolvedExecutable, [
      '$_skillDir/scripts/harden_platforms.dart',
      _project,
    ]);
    stdout.write(r.stdout);
    _done.add('android/ios hardened (see changes above)');
  }

  print('\nInstalled into $_project:');
  for (final d in _done) {
    print('  + $d');
  }
  for (final s in _skipped) {
    print('  = $s');
  }
  for (final n in _notes) {
    print('  ! $n');
  }
  print('''

Next:
  flutter pub get
  dart run tool/flutter_store_ready/verify.dart
  → build/reports/flutter-store-ready/PROJECT_REPORT.md''');
}

/// The starter needs the Flutter version in its pubspec (`material_ui`,
/// Riverpod 3...). Returns a message when the installed Flutter is older,
/// null when it is new enough or cannot be determined.
String? _starterNeedsNewerFlutter() {
  final required = RegExp(r'flutter:\s*">=\s*([0-9.]+)"')
      .firstMatch(
        File(
          '$_skillDir/templates/starter_app/pubspec.yaml',
        ).readAsStringSync(),
      )
      ?.group(1);
  final installed = _installedFlutterVersion();
  if (required == null || installed == null) return null;
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final need = parts(required);
  final have = parts(installed);
  for (var i = 0; i < need.length; i++) {
    final h = i < have.length ? have[i] : 0;
    if (h > need[i]) return null;
    if (h < need[i]) {
      return 'The starter needs Flutter >= $required, but Flutter $installed is installed.';
    }
  }
  return null;
}

String? _installedFlutterVersion() {
  // Set by Flutter's `dart` wrapper; avoids starting the flutter tool.
  if (Platform.environment['FLUTTER_ROOT'] case final root?) {
    final json = File('$root/bin/cache/flutter.version.json');
    if (json.existsSync()) {
      final v = RegExp(
        r'"frameworkVersion":\s*"([0-9.]+)',
      ).firstMatch(json.readAsStringSync())?.group(1);
      if (v != null) return v;
    }
  }
  try {
    final r = Process.runSync('flutter', [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);
    if (r.exitCode != 0) return null;
    final out = '${r.stdout}';
    final start = out.indexOf('{');
    if (start < 0) return null;
    final data = jsonDecode(out.substring(start)) as Map<String, Object?>;
    final v = '${data['frameworkVersion'] ?? ''}'.split('-').first;
    return v.isEmpty ? null : v;
  } on Object {
    return null;
  }
}

/// The tools use Dart 3 syntax and, once copied into tool/, are compiled
/// with the project's own language version. A project that still allows
/// Dart 2 cannot compile them there.
void _warnIfDart2(String pubspec) {
  final m = RegExp(
    r'''^\s+sdk:\s*['"]?\s*(?:>=\s*|\^)?(\d+)\.\d+''',
    multiLine: true,
  ).firstMatch(pubspec);
  final major = int.tryParse(m?.group(1) ?? '');
  if (major == null || major >= 3) return;
  _notes.add(
    'pubspec.yaml still allows Dart $major (environment: sdk). The tools in '
    'tool/flutter_store_ready/ need Dart 3 and will not compile from there. '
    'Either raise the constraint to ^3.0.0, or run them from the skill '
    'folder: dart run <skill>/scripts/project_report.dart .',
  );
}

void _installTools() {
  final target = Directory('$_project/tool/flutter_store_ready')
    ..createSync(recursive: true);
  for (final name in [
    'verify.dart',
    'project_report.dart',
    'play_readiness.dart',
    'app_store_readiness.dart',
    'check_forbidden.dart',
    'harden_platforms.dart',
  ]) {
    File('$_skillDir/scripts/$name').copySync('${target.path}/$name');
  }
  _done.add(
    'tool/flutter_store_ready/ (verify, report, Play + App Store audits, checks)',
  );
}

void _installAnalysisOptions({required bool force}) {
  final file = File('$_project/analysis_options.yaml');
  final template = File(
    '$_skillDir/templates/starter_app/analysis_options.yaml',
  );
  if (file.existsSync()) {
    final text = file.readAsStringSync();
    if (text.contains('strict-casts') && !force) {
      _skipped.add('analysis_options.yaml already strict');
      return;
    }
    file.copySync('${file.path}.bak');
  }
  template.copySync(file.path);
  _done.add('analysis_options.yaml (strict; previous saved as .bak)');
}

void _installCi() {
  final target = File('$_project/.github/workflows/flutter_store_ready.yml');
  if (target.existsSync()) {
    _skipped.add('.github/workflows/flutter_store_ready.yml exists');
    return;
  }
  target.parent.createSync(recursive: true);
  File(
    '$_skillDir/templates/starter_app/.github/workflows/ci.yml',
  ).copySync(target.path);
  final dependabot = File('$_project/.github/dependabot.yml');
  if (!dependabot.existsSync()) {
    File(
      '$_skillDir/templates/starter_app/.github/dependabot.yml',
    ).copySync(dependabot.path);
  }
  _done.add('.github/workflows/flutter_store_ready.yml + dependabot.yml');
}

void _installGitFiles() {
  const ignore = [
    '# flutter-store-ready: secrets and build output (never commit)',
    'build/',
    '.dart_tool/',
    'android/key.properties',
    '*.jks',
    '*.keystore',
    '*.p12',
    '*.pem',
    '*.mobileprovision',
    'config/prod.json',
    'config/*.local.json',
    '.env',
    '.env.*',
  ];
  final gitignore = File('$_project/.gitignore');
  final existing = gitignore.existsSync() ? gitignore.readAsStringSync() : '';
  final present = existing.split(RegExp(r'\r?\n')).map((l) => l.trim()).toSet();
  final missing = ignore.where((l) => !present.contains(l)).toList();
  if (missing.isNotEmpty) {
    gitignore.writeAsStringSync(
      '${existing.trimRight()}\n\n${missing.join('\n')}\n',
    );
    _done.add('.gitignore: secrets & build output');
  }
  final attributes = File('$_project/.gitattributes');
  if (!attributes.existsSync()) {
    attributes.writeAsStringSync(
      '* text=auto eol=lf\n*.bat text eol=crlf\n*.ps1 text eol=crlf\n'
      '*.png binary\n*.jpg binary\n*.jks binary\n*.keystore binary\n',
    );
    _done.add('.gitattributes (LF line endings)');
  }
}

void _installStarter(String appName) {
  final starter = '$_skillDir/templates/starter_app';
  // Remove the counter demo and its test.
  for (final path in ['lib/main.dart', 'test/widget_test.dart']) {
    final f = File('$_project/$path');
    if (f.existsSync()) f.deleteSync();
  }
  for (final dir in ['lib', 'test', 'config']) {
    _copyTree(Directory('$starter/$dir'), Directory('$_project/$dir'), appName);
  }
  // Project rules for coding agents: AGENTS.md is read by most of them
  // (Codex, Cursor, Gemini CLI, Copilot …), CLAUDE.md by Claude Code.
  for (final name in ['AGENTS.md', 'CLAUDE.md']) {
    final rules = File('$_project/$name');
    if (!rules.existsSync()) File('$starter/$name').copySync(rules.path);
  }
  _mergePubspec(appName);
  _done.add(
    'starter: lib/, test/, config/, AGENTS.md + CLAUDE.md, pubspec dependencies (imports renamed to package:$appName)',
  );
}

void _copyTree(Directory from, Directory to, String appName) {
  for (final entity in from.listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = entity.path.substring(from.path.length + 1);
    final out = File('${to.path}/$rel')..parent.createSync(recursive: true);
    if (entity.path.endsWith('.dart')) {
      out.writeAsStringSync(
        _sortImports(
          entity.readAsStringSync().replaceAll(
            'package:starter_app/',
            'package:$appName/',
          ),
        ),
      );
    } else {
      entity.copySync(out.path);
    }
  }
}

/// Renaming the package changes alphabetical order, so the leading block of
/// single-line imports is re-sorted (dart:, package:, relative), matching the
/// `directives_ordering` lint.
String _sortImports(String source) {
  final lines = source.split('\n');
  var start = -1;
  var end = -1;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trim();
    final isImport = l.startsWith('import ') && l.endsWith(';');
    if (isImport) {
      if (start < 0) start = i;
      end = i;
    } else if (start >= 0 && l.isNotEmpty) {
      break;
    }
  }
  if (start < 0) return source;
  final imports = lines
      .sublist(start, end + 1)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (imports.any((l) => !l.trim().endsWith(';'))) return source;
  int group(String l) => l.contains("'dart:")
      ? 0
      : l.contains("'package:")
      ? 1
      : 2;
  String uri(String l) => RegExp("'([^']+)'").firstMatch(l)?.group(1) ?? l;
  final sorted = <String>[];
  for (var g = 0; g < 3; g++) {
    final part = imports.where((l) => group(l) == g).toList()
      ..sort((a, b) => uri(a).compareTo(uri(b)));
    if (part.isEmpty) continue;
    if (sorted.isNotEmpty) sorted.add('');
    sorted.addAll(part);
  }
  return [
    ...lines.sublist(0, start),
    ...sorted,
    ...lines.sublist(end + 1),
  ].join('\n');
}

/// Replaces environment / dependencies / dev_dependencies / flutter sections
/// with the starter's, keeping name, description and version.
void _mergePubspec(String appName) {
  final file = File('$_project/pubspec.yaml');
  // `flutter create` writes CRLF on Windows; the section matcher below
  // works on LF. Without this the sections are appended a second time and
  // the pubspec has duplicate keys.
  final mine = file.readAsStringSync().replaceAll('\r\n', '\n');
  final theirs = File(
    '$_skillDir/templates/starter_app/pubspec.yaml',
  ).readAsStringSync().replaceAll('\r\n', '\n');
  String? section(String text, String key) => RegExp(
    '^$key:\\n(?:(?:[ \\t].*)?\\n)*',
    multiLine: true,
  ).firstMatch('$text\n')?.group(0);

  var merged = mine;
  for (final key in [
    'environment',
    'dependencies',
    'dev_dependencies',
    'flutter',
  ]) {
    final replacement = section(theirs, key);
    if (replacement == null) continue;
    final current = section(merged, key);
    merged = current == null
        ? '${merged.trimRight()}\n\n$replacement'
        : merged.replaceFirst(current, replacement);
  }
  file
    ..copySync('${file.path}.bak')
    ..writeAsStringSync(merged);
}
