// Finds dangerous patterns in app code.
//
//   dart run <skill>/scripts/check_forbidden.dart [project_dir]
//
// Two severities:
//   blocking  security holes (disabled TLS checks, plain http://, secrets in
//             code or in plain preferences). Exit code 1.
//   warning   bad habits that do not stop a release (print / debugPrint,
//             empty catch). Listed, exit code 0.
//
// A deliberate exception is marked on its line with `// forbidden:allow`.
// ignore_for_file: avoid_print

import 'dart:io';

const _blocking = true;
const _warning = false;

final _rules = <(RegExp, String, bool)>[
  (
    RegExp(r'\bprint\('),
    'print() leaks data to device logs: use a redacting logger that is silent in release.',
    _warning,
  ),
  (
    RegExp(r'debugPrint\('),
    'debugPrint() also prints in release builds: use a redacting logger.',
    _warning,
  ),
  (
    RegExp(
      r'badCertificateCallback\s*=\s*\([^)]*\)\s*(=>\s*true|\{\s*return\s+true)',
    ),
    'Never accept invalid TLS certificates.',
    _blocking,
  ),
  (
    RegExp(r'validateCertificate:\s*\([^)]*\)\s*=>\s*true'),
    'Never disable certificate validation.',
    _blocking,
  ),
  (
    RegExp(r'''['"]http://(?!localhost|127\.0\.0\.1|10\.0\.2\.2)'''),
    'Plain HTTP URL in app code.',
    _blocking,
  ),
  (
    RegExp(
      r'SharedPreferences[^\n]*(token|password|secret)',
      caseSensitive: false,
    ),
    'Secrets belong in secure storage (Keychain/Keystore), not SharedPreferences.',
    _blocking,
  ),
  (
    RegExp(
      r'''set(?:String|StringList)\(\s*['"][^'"]*(?:token|password|passwd|secret|jwt|session|api[_-]?key)''',
      caseSensitive: false,
    ),
    'Secret written to plain preferences: use flutter_secure_storage.',
    _blocking,
  ),
  (
    RegExp(
      r'''(api[_-]?key|secret|password|private[_-]?key)\s*[:=]\s*['"][A-Za-z0-9_\-]{16,}['"]''',
      caseSensitive: false,
    ),
    'Hard-coded secret. Secrets must never ship inside the app.',
    _blocking,
  ),
  (
    RegExp(r'-----BEGIN (RSA |EC )?PRIVATE KEY-----'),
    'Private key in source.',
    _blocking,
  ),
  (
    RegExp(r'catch\s*\(\s*_\s*\)\s*\{\s*\}'),
    'Empty catch swallows errors: handle it, log it, or say in a comment why it is safe to ignore.',
    _warning,
  ),
  (
    RegExp(r'on\s+Object\s+catch\s*\([^)]*\)\s*\{\s*\}'),
    'Empty catch swallows errors: handle it, log it, or say in a comment why it is safe to ignore.',
    _warning,
  ),
];

/// Keys that are meant to ship inside the app and identify the project,
/// not authorize it: Firebase / Google API keys (restricted in the console),
/// Stripe publishable keys, Supabase anon keys, RevenueCat public SDK keys.
bool _isPublicKey(String path, String line) =>
    path.endsWith('firebase_options.dart') ||
    RegExp(
      r'''['"](?:AIza[0-9A-Za-z_\-]{20,}|pk_(?:live|test)_\w+|appl_\w+|goog_\w+)['"]''',
    ).hasMatch(line) ||
    RegExp(
      r'publishable|anon_?[Kk]ey|public_?[Kk]ey',
      caseSensitive: false,
    ).hasMatch(line);

void main(List<String> args) {
  final project = Directory(
    args.where((a) => !a.startsWith('--')).firstOrNull ?? '.',
  ).resolveSymbolicLinksSync();
  var blocking = 0;
  var warnings = 0;
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
        for (final (pattern, message, isBlocking) in _rules) {
          if (pattern.hasMatch(line)) {
            if (message.startsWith('Hard-coded secret') &&
                _isPublicKey(file.path, line)) {
              continue;
            }
            isBlocking ? blocking++ : warnings++;
            final rel = file.path
                .substring(project.length + 1)
                .replaceAll(r'\', '/');
            print(
              '$rel:${i + 1}: [${isBlocking ? 'blocking' : 'warning'}] $message\n    ${line.trim()}',
            );
          }
        }
      }
    }
  }
  if (blocking + warnings == 0) {
    print('No forbidden patterns found.');
    return;
  }
  // project_report.dart parses this line.
  print('\n$blocking blocking, $warnings warning(s) found.');
  if (blocking > 0) exitCode = 1;
}
