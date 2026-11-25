// Fails CI when dangerous patterns appear in app code.
//
//   dart run <skill>/scripts/check_forbidden.dart [project_dir]
//
// ignore_for_file: avoid_print

import 'dart:io';

final _rules = <(RegExp, String)>[
  (
    RegExp(r'\bprint\('),
    'print() leaks data to device logs: use a redacting logger that is silent in release.',
  ),
  (
    RegExp(r'debugPrint\('),
    'debugPrint() leaks data to device logs: use a redacting logger.',
  ),
  (
    RegExp(
      r'badCertificateCallback\s*=\s*\([^)]*\)\s*(=>\s*true|\{\s*return\s+true)',
    ),
    'Never accept invalid TLS certificates.',
  ),
  (
    RegExp(r'validateCertificate:\s*\([^)]*\)\s*=>\s*true'),
    'Never disable certificate validation.',
  ),
  (
    RegExp(r'''['"]http://(?!localhost|127\.0\.0\.1|10\.0\.2\.2)'''),
    'Plain HTTP URL in app code.',
  ),
  (
    RegExp(
      r'SharedPreferences[^\n]*(token|password|secret)',
      caseSensitive: false,
    ),
    'Secrets belong in secure storage (Keychain/Keystore), not SharedPreferences.',
  ),
  (
    RegExp(
      r'''set(?:String|StringList)\(\s*['"][^'"]*(?:token|password|passwd|secret|jwt|session|api[_-]?key)''',
      caseSensitive: false,
    ),
    'Secret written to plain preferences: use flutter_secure_storage.',
  ),
  (
    RegExp(
      r'''(api[_-]?key|secret|password|private[_-]?key)\s*[:=]\s*['"][A-Za-z0-9_\-]{16,}['"]''',
      caseSensitive: false,
    ),
    'Hard-coded secret. Secrets must never ship inside the app.',
  ),
  (RegExp(r'-----BEGIN (RSA |EC )?PRIVATE KEY-----'), 'Private key in source.'),
  (RegExp(r'catch\s*\(\s*_\s*\)\s*\{\s*\}'), 'Empty catch swallows errors.'),
  (
    RegExp(r'on\s+Object\s+catch\s*\([^)]*\)\s*\{\s*\}'),
    'Empty catch swallows errors.',
  ),
];

void main(List<String> args) {
  final project = Directory(
    args.where((a) => !a.startsWith('--')).firstOrNull ?? '.',
  ).resolveSymbolicLinksSync();
  var violations = 0;
  for (final dir in ['lib']) {
    final root = Directory('$project/$dir');
    if (!root.existsSync()) continue;
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue;
        if (line.contains('forbidden:allow')) continue;
        for (final (pattern, message) in _rules) {
          if (pattern.hasMatch(line)) {
            violations++;
            final rel = file.path
                .substring(project.length + 1)
                .replaceAll(r'\', '/');
            print('$rel:${i + 1}: $message\n    ${line.trim()}');
          }
        }
      }
    }
  }
  if (violations > 0) {
    print('\n$violations forbidden pattern(s) found.');
    exitCode = 1;
  } else {
    print('No forbidden patterns found.');
  }
}
