// Regression tests for the audit scripts.
//
//   dart run tests/run.dart [fixture ...]
//
// Each folder in tests/fixtures/ is a tiny project with planted problems and
// decoys (things that look like a problem and are not), plus an
// expected.json:
//
//   args         extra flags for project_report.dart
//   must         findings that have to be there: title, level, and optionally
//                section_contains / detail_contains / detail_not_contains
//   must_not     findings that must be absent (or absent at the given levels)
//   forbidden    exact counts check_forbidden.dart has to report
//
// "must" measures recall, "must_not" and the decoys measure false positives.
// The fixtures are not compiled: the audit only reads text.
//
// Exit code 1 when anything differs. Only dart:io.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final scripts = '$root/skills/flutter-store-ready/scripts';
  final fixtures =
      Directory(
          '$root/tests/fixtures',
        ).listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  var failed = 0;
  var checks = 0;
  for (final dir in fixtures) {
    final name = dir.path.split(RegExp(r'[\\/]')).last;
    if (args.isNotEmpty && !args.contains(name)) continue;
    final expected =
        jsonDecode(File('${dir.path}/expected.json').readAsStringSync())
            as Map<String, Object?>;
    final problems = <String>[];
    final out = Directory.systemTemp.createTempSync('fp_$name');
    try {
      final r = await Process.run(
        Platform.resolvedExecutable,
        [
          '$scripts/project_report.dart',
          dir.path,
          '--skip-gates',
          '--no-fail',
          '--out',
          out.path,
          ...((expected['args'] as List?) ?? const []).cast<String>(),
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      final findings = File('${out.path}/findings.json');
      if (!findings.existsSync()) {
        problems.add(
          'project_report.dart wrote no findings.json:\n${r.stderr}',
        );
      } else {
        final items =
            ((jsonDecode(findings.readAsStringSync()) as Map)['items'] as List)
                .cast<Map<String, Object?>>();
        List<Map<String, Object?>> named(Map<String, Object?> e) => items
            .where(
              (i) =>
                  i['title'] == e['title'] &&
                  (e['section_contains'] == null ||
                      '${i['section']}'.contains('${e['section_contains']}')),
            )
            .toList();

        for (final e
            in ((expected['must'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          checks++;
          final label =
              '"${e['title']}"${e['section_contains'] == null ? '' : ' in ${e['section_contains']}'}';
          final found = named(e);
          if (found.isEmpty) {
            problems.add('missing: $label (expected ${e['level']})');
            continue;
          }
          final match = found
              .where((i) => i['level'] == e['level'])
              .firstOrNull;
          if (match == null) {
            problems.add(
              'wrong level: $label is ${found.map((i) => i['level']).join('/')}, expected ${e['level']}',
            );
            continue;
          }
          final detail = '${match['detail']}';
          if (e['detail_contains'] case final String want
              when !detail.contains(want)) {
            problems.add('$label does not mention "$want": $detail');
          }
          if (e['detail_not_contains'] case final String decoy
              when detail.contains(decoy)) {
            problems.add('false positive: $label mentions "$decoy": $detail');
          }
        }

        for (final e
            in ((expected['must_not'] as List?) ?? const [])
                .cast<Map<String, Object?>>()) {
          checks++;
          final levels = (e['levels'] as List?)?.cast<String>();
          final found = named(
            e,
          ).where((i) => levels == null || levels.contains(i['level']));
          if (found.isNotEmpty) {
            problems.add(
              'false positive: "${e['title']}" reported as ${found.map((i) => i['level']).join('/')}: ${found.first['detail']}',
            );
          }
        }
      }

      if (expected['forbidden'] case final Map<String, Object?> want) {
        checks++;
        final f = await Process.run(Platform.resolvedExecutable, [
          '$scripts/check_forbidden.dart',
          dir.path,
        ], stdoutEncoding: utf8);
        final m = RegExp(
          r'(\d+) blocking, (\d+) warning',
        ).firstMatch('${f.stdout}');
        final got = {
          'blocking': int.parse(m?.group(1) ?? '0'),
          'warnings': int.parse(m?.group(2) ?? '0'),
        };
        if (got['blocking'] != want['blocking'] ||
            got['warnings'] != want['warnings']) {
          problems.add(
            'check_forbidden: got $got, expected $want\n${f.stdout}'.trim(),
          );
        }
      }
    } finally {
      out.deleteSync(recursive: true);
    }

    if (problems.isEmpty) {
      print('PASS  $name');
    } else {
      failed++;
      print('FAIL  $name');
      for (final p in problems) {
        print('      - ${p.replaceAll('\n', '\n        ')}');
      }
    }
  }

  if (args.isEmpty || args.contains('skills')) {
    final problems = _checkSkillFiles('$root/skills');
    checks++;
    if (problems.isEmpty) {
      print('PASS  skills');
    } else {
      failed++;
      print('FAIL  skills');
      for (final p in problems) {
        print('      - $p');
      }
    }
  }

  if (args.isEmpty || args.contains('install')) {
    checks++;
    final problem = await _installMergesWindowsPubspec(scripts);
    if (problem == null) {
      print('PASS  install');
    } else {
      failed++;
      print('FAIL  install\n      - $problem');
    }
  }

  print(
    '\n$checks checks, ${failed == 0 ? 'everything passes' : '$failed test(s) failed'}.',
  );
  if (failed > 0) exitCode = 1;
}

/// `install.dart --starter` on a project whose pubspec.yaml has Windows line
/// endings (what `flutter create` writes on Windows) must replace the
/// dependency sections, not append a second copy.
Future<String?> _installMergesWindowsPubspec(String scripts) async {
  final dir = Directory.systemTemp.createTempSync('fp_install');
  try {
    File('${dir.path}/pubspec.yaml').writeAsStringSync(
      [
        'name: sample_app',
        'description: "A new Flutter project."',
        'version: 1.0.0+1',
        '',
        'environment:',
        '  sdk: ^3.8.0',
        '',
        'dependencies:',
        '  flutter:',
        '    sdk: flutter',
        '  cupertino_icons: ^1.0.8',
        '',
        'dev_dependencies:',
        '  flutter_test:',
        '    sdk: flutter',
        '',
        'flutter:',
        '  uses-material-design: true',
        '',
      ].join('\r\n'),
    );
    Directory('${dir.path}/lib').createSync();
    File(
      '${dir.path}/lib/main.dart',
    ).writeAsStringSync('void main() {} // _incrementCounter');
    // --force: the starter's Flutter version gate is not what is tested here.
    final r = await Process.run(
      Platform.resolvedExecutable,
      ['$scripts/install.dart', dir.path, '--starter', '--force'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (r.exitCode != 0) return 'install.dart failed:\n${r.stderr}';
    final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
    for (final key in ['environment', 'dependencies', 'dev_dependencies']) {
      final n = RegExp('^$key:', multiLine: true).allMatches(pubspec).length;
      if (n != 1) return 'pubspec.yaml has $n "$key:" sections after install';
    }
    if (!pubspec.contains('name: sample_app')) return 'package name was lost';
    if (!pubspec.contains('go_router')) return 'starter dependencies missing';
    if (pubspec.contains('cupertino_icons')) return 'old dependencies kept';
    if (!File('${dir.path}/lib/bootstrap.dart').existsSync()) {
      return 'starter lib/ was not copied';
    }
    if (!File('${dir.path}/AGENTS.md').existsSync()) return 'AGENTS.md missing';
    for (final helper in [
      'dart_scanner.dart',
      'project_detector.dart',
      'store_policies.dart',
      'store_policies.json',
    ]) {
      if (!File('${dir.path}/tool/flutter_store_ready/$helper').existsSync()) {
        return 'tool/flutter_store_ready/$helper was not installed';
      }
    }
    return null;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Every skill folder: a SKILL.md whose front matter follows the Agent Skills
/// format (name = folder name, a description of at most 1024 characters), and
/// every file it points to exists — in its own folder, or in the
/// flutter-store-ready kit (`<kit>/…`) that the store skills share.
List<String> _checkSkillFiles(String skillsDir) {
  final problems = <String>[];
  final kit = '$skillsDir/flutter-store-ready';
  final policiesFile = File('$kit/scripts/store_policies.json');
  if (!policiesFile.existsSync()) {
    problems.add('flutter-store-ready/scripts/store_policies.json is missing');
  } else {
    try {
      final decoded =
          jsonDecode(policiesFile.readAsStringSync()) as Map<String, Object?>;
      for (final section in ['googlePlay', 'appStore', 'flutter']) {
        if (decoded[section] is! Map) {
          problems.add('store_policies.json missing "$section" object');
        }
      }
    } on Object catch (e) {
      problems.add('store_policies.json invalid JSON: $e');
    }
  }
  for (final dir in Directory(skillsDir).listSync().whereType<Directory>()) {
    final name = dir.path.split(RegExp(r'[\\/]')).last;
    final skill = File('${dir.path}/SKILL.md');
    if (!skill.existsSync()) {
      problems.add('$name: no SKILL.md');
      continue;
    }
    final text = skill.readAsStringSync().replaceAll('\r\n', '\n');
    final front = RegExp(r'^---\n([\s\S]*?)\n---\n').firstMatch(text)?.group(1);
    if (front == null) {
      problems.add('$name: SKILL.md has no front matter');
      continue;
    }
    final declared = RegExp(
      r'^name:\s*(.+)$',
      multiLine: true,
    ).firstMatch(front)?.group(1)?.trim();
    if (declared != name) {
      problems.add('$name: front matter name is "$declared"');
    }
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(name) ||
        name.length > 64) {
      problems.add('$name: name must be lowercase letters, digits, hyphens');
    }
    final description = RegExp(
      r'^description:\s*(.+)$',
      multiLine: true,
    ).firstMatch(front)?.group(1)?.trim();
    if (description == null || description.isEmpty) {
      problems.add('$name: no description');
    } else if (description.length > 1024) {
      problems.add(
        '$name: description is ${description.length} chars (max 1024)',
      );
    }

    // File references in every Markdown file of the skill.
    for (final md in dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.md'),
    )) {
      final mdName = md.path.split(RegExp(r'[\\/]')).last;
      final body = md.readAsStringSync();
      for (final m in RegExp(r'<kit>/([\w./-]+)').allMatches(body)) {
        final target = m.group(1)!.replaceAll(RegExp(r'[.,;:]+$'), '');
        if (!File('$kit/$target').existsSync() &&
            !Directory('$kit/$target').existsSync()) {
          problems.add('$name/$mdName: <kit>/$target does not exist');
        }
      }
      for (final m in RegExp(r'`([A-Z][A-Z0-9-]+\.md)`').allMatches(body)) {
        final target = m.group(1)!;
        if (!File('${dir.path}/$target').existsSync() &&
            !File('$kit/$target').existsSync() &&
            !const {
              'PROJECT_REPORT.md',
              'PLAY_READINESS.md',
              'APP_STORE_READINESS.md',
              'STORE_FORMS.md',
              'REJECTION_RESPONSE.md',
              'SKILL.md',
              'CHANGELOG.md',
              'AGENTS.md',
              'CLAUDE.md',
            }.contains(target)) {
          problems.add('$name/$mdName: `$target` does not exist');
        }
      }
    }
  }
  return problems;
}
