// Production-readiness report for mobile apps (full code + platform audit for
// Flutter workspaces; automated platform + policy + secret audits for Expo,
// React Native, Native Android and Native iOS): "what is done, what is
// missing".
//
//   dart run <skill>/scripts/project_report.dart [project_dir]
//        [--out <dir>] [--skip-gates] [--gates-passed] [--skip-play] [--skip-ios]
//        [--no-fail] [--last-version-code <n>] [--last-build-number <n>]
//        [--ci]   signing material and config/prod.json cannot exist on CI:
//                 their absence is a warning instead of a blocker
//
// Writes:
//   <out>/PROJECT_REPORT.md   (default out: <project>/build/reports/flutter-store-ready)
//   <out>/findings.json       (machine-readable, same items)
//
// Exit code 1 when anything is blocking (unless --no-fail).
// Only dart:convert and dart:io: runs on Windows, macOS and Linux without `pub get`.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'dart_scanner.dart';
import 'project_detector.dart';
import 'store_policies.dart';

enum Level { pass, warn, fail, manual }

final class Item {
  Item(this.section, this.title, this.level, this.detail, [this.fix]);

  final String section;
  final String title;
  final Level level;
  final String detail;
  final String? fix;

  Map<String, Object?> toJson() => {
    'section': section,
    'title': title,
    'level': level.name,
    'detail': detail,
    'fix': fix,
  };
}

final class GateResult {
  GateResult(this.name, this.level, this.summary, [this.output]);

  final String name;
  final Level level;
  final String summary;
  final String? output;
}

final _items = <Item>[];
final _gates = <GateResult>[];

void _add(
  String section,
  String title,
  Level level,
  String detail, [
  String? fix,
]) => _items.add(Item(section, title, level, detail, fix));

late final String _root;
late final String _scriptsDir;
late final ProjectProfile _profile;
late final StorePolicies _policies;
late final String _pubspec;
late final String _rootPubspec;
bool _ci = false;

/// Set by [_checkStoreRequirements]: account rules (deletion, reviewer
/// login, legal text) only apply to apps that have sign-in.
bool _hasAccounts = false;

const _sGates = 'Quality gates';
const _sErrors = 'Error handling';
const _sSecurity = 'Security';
const _sUi = 'Responsive & large text';
const _sStore = 'Store requirements';
const _sConfig = 'Production config';
const _sLeftovers = 'Template leftovers';
const _sCode = 'Code health';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final valueFlags = {'--out', '--last-version-code', '--last-build-number'};
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (valueFlags.contains(args[i])) {
      i++;
    } else if (!args[i].startsWith('--')) {
      positional.add(args[i]);
    }
  }
  _root = Directory(
    positional.isEmpty ? Directory.current.path : positional.first,
  ).resolveSymbolicLinksSync();
  _scriptsDir = File.fromUri(Platform.script).parent.path;
  _policies = StorePolicies.load(_scriptsDir);
  _profile = ProjectProfile.detect(_root);

  if (_profile.kind == ProjectKind.unknown) {
    stderr.writeln(
      'No mobile project (pubspec.yaml, app.json, package.json, Android or Xcode project) found in $_root.',
    );
    exitCode = 2;
    return;
  }

  final pubspecFile = File('$_root/pubspec.yaml');
  _rootPubspec = pubspecFile.existsSync() ? pubspecFile.readAsStringSync() : '';
  _pubspec = _profile.pubspec;
  final outDir = opt('--out') ?? '$_root/build/reports/flutter-store-ready';
  _ci = args.contains('--ci');

  if (_profile.isFlutter) {
    if (args.contains('--gates-passed')) {
      for (final name in [
        'Formatting',
        'Static analysis',
        'Forbidden patterns',
        'Tests',
      ]) {
        _gates.add(GateResult(name, Level.pass, 'Passed (verify.dart)'));
        _add(_sGates, name, Level.pass, 'Passed (verify.dart)');
      }
    } else if (!args.contains('--skip-gates')) {
      await _runGates();
    }

    _checkErrorHandling();
    _checkUserFacingErrors();
    _checkSecurity();
    _checkResponsive();
    _checkStoreRequirements();
    _checkStorePolicies();
    _checkNavigationAndPermissions();
    _checkProductionConfig();
    _checkLeftovers();
    _checkCodeHealth();
  } else {
    if (!args.contains('--skip-gates')) {
      await _runNonFlutterGates();
    }
    _checkNonFlutterApp();
  }

  if (!args.contains('--skip-play')) {
    await _runPlayAudit(outDir, opt('--last-version-code'));
  }
  if (!args.contains('--skip-ios')) {
    await _runAppStoreAudit(outDir, opt('--last-build-number'));
  }

  _write(outDir, args.contains('--no-fail'));
}

// --------------------------------------------------------------------- gates

Future<void> _runGates() async {
  final flutter = _which('flutter');
  final dart = Platform.resolvedExecutable;

  Future<void> gate(
    String name,
    String exe,
    List<String> args, {
    // Turns a failure into a different result (e.g. errors only in a
    // vendored package). Returns null to keep the normal failure.
    (Level, String)? Function(String out)? onFailure,
    String Function(String out, bool ok)? summarize,
    // Level for a failing exit code (style gates only warn).
    Level failLevel = Level.fail,
    // Overrides the level from the output (e.g. warnings with exit code 0).
    Level? Function(String out, bool ok)? levelOf,
  }) async {
    final r = await Process.run(
      exe,
      args,
      workingDirectory: _root,
      runInShell: Platform.isWindows,
      // Dart and Flutter tools write UTF-8; the default (system code page)
      // garbles non-ASCII source lines on Windows.
      stdoutEncoding: const Utf8Codec(allowMalformed: true),
      stderrEncoding: const Utf8Codec(allowMalformed: true),
    );
    final out = '${r.stdout}\n${r.stderr}'.trim();
    final ok = r.exitCode == 0;
    final override = ok ? null : onFailure?.call(out);
    final level =
        override?.$1 ?? levelOf?.call(out, ok) ?? (ok ? Level.pass : failLevel);
    _gates.add(
      GateResult(
        name,
        level,
        override?.$2 ??
            summarize?.call(out, ok) ??
            (ok ? 'Passed' : 'Failed (exit code ${r.exitCode})'),
        level == Level.pass ? null : _tail(out, 40),
      ),
    );
  }

  final dirs = [
    'lib',
    'test',
  ].where((d) => Directory('$_root/$d').existsSync());
  await gate(
    'Formatting',
    dart,
    ['format', '--output=none', '--set-exit-if-changed', ...dirs],
    // Style, not a release risk: listed as a recommendation.
    failLevel: Level.warn,
    summarize: (out, ok) {
      if (ok) return 'All files formatted';
      final n = RegExp(r'\((\d+) changed\)').firstMatch(out)?.group(1);
      return '${n ?? 'Some'} file(s) do not follow `dart format`: run `dart format .`';
    },
  );

  if (flutter == null) {
    _gates
      ..add(
        GateResult(
          'Static analysis',
          Level.warn,
          '`flutter` not in PATH, skipped',
        ),
      )
      ..add(GateResult('Tests', Level.warn, '`flutter` not in PATH, skipped'));
  } else {
    await gate(
      'Static analysis',
      flutter,
      ['analyze', '--no-fatal-infos'],
      onFailure: _analyzerErrorsOnlyInNestedPackages,
      summarize: (out, ok) {
        if (ok) return 'No errors or warnings';
        final n = RegExp(r'(\d+) issues? found').firstMatch(out)?.group(1);
        return n == null ? 'Failed' : '$n issue(s) found';
      },
    );
  }

  await gate(
    'Forbidden patterns',
    dart,
    ['$_scriptsDir/check_forbidden.dart', _root],
    // Exit code 1 only for security patterns; print / debugPrint / empty
    // catch are reported as warnings with exit code 0.
    levelOf: (out, ok) {
      if (!ok) return Level.fail;
      return RegExp(r'\b[1-9]\d* warning').hasMatch(out) ? Level.warn : null;
    },
    summarize: (out, ok) {
      final m = RegExp(r'(\d+) blocking, (\d+) warning').firstMatch(out);
      if (m == null) return ok ? 'None found' : 'Some found';
      final blocking = int.parse(m.group(1)!);
      final warnings = int.parse(m.group(2)!);
      return [
        if (blocking > 0)
          '$blocking security pattern(s) (disabled TLS check, http://, secret in code)',
        if (warnings > 0) '$warnings print / debugPrint / empty catch',
      ].join('; ');
    },
  );

  if (flutter != null) {
    if (!Directory('$_root/test').existsSync()) {
      _gates.add(GateResult('Tests', Level.fail, 'No test/ folder'));
    } else {
      await gate(
        'Tests',
        flutter,
        ['test'],
        summarize: (out, ok) {
          final m = RegExp(
            r'\+(\d+)(?: ~(\d+))?(?: -(\d+))?:',
          ).allMatches(out).toList();
          if (m.isEmpty) return ok ? 'Passed' : 'Failed';
          final last = m.last;
          return '${last.group(1)} passed'
              '${last.group(3) != null ? ', ${last.group(3)} FAILED' : ''}'
              '${last.group(2) != null ? ', ${last.group(2)} skipped' : ''}';
        },
      );
    }
  }

  for (final g in _gates) {
    _add(
      _sGates,
      g.name,
      g.level,
      g.summary,
      g.level == Level.fail || g.output != null
          ? 'See "Quality gates" output below.'
          : null,
    );
  }
}

/// When every analyzer error or warning is inside a nested package (a
/// folder with its own pubspec.yaml, such as a vendored `third_party/hive`),
/// the app itself is fine: report a warning that says where they are.
(Level, String)? _analyzerErrorsOnlyInNestedPackages(String out) {
  final files = [
    for (final m in RegExp(
      r'^\s*(?:error|warning) - .* - ([^:\s]+\.dart):\d+:\d+',
      multiLine: true,
    ).allMatches(out))
      m.group(1)!.replaceAll(r'\', '/'),
  ];
  if (files.isEmpty) return null;
  String? nestedRoot(String file) {
    final parts = file.split('/');
    for (var i = parts.length - 1; i > 0; i--) {
      final dir = parts.sublist(0, i).join('/');
      if (File('$_root/$dir/pubspec.yaml').existsSync()) return dir;
    }
    return null;
  }

  final roots = files.map(nestedRoot).toSet();
  if (roots.contains(null)) return null; // at least one error is in the app
  return (
    Level.warn,
    '${files.length} error(s), all inside nested package(s) ${roots.join(', ')} — none in the app. '
        '`flutter analyze` still fails for anyone who runs it: exclude the folder in analysis_options.yaml '
        '(analyzer: exclude: [${roots.map((r) => '"$r/**"').join(', ')}]).',
  );
}

// ------------------------------------------------------------ error handling

void _checkErrorHandling() {
  final all = _allCodeOnly();
  final flutterError = all.contains('FlutterError.onError');
  final asyncErrors =
      all.contains('PlatformDispatcher.instance.onError') ||
      all.contains('runZonedGuarded') ||
      all.contains('SentryFlutter.init') ||
      all.contains('FirebaseCrashlytics.instance.recordError');
  _add(
    _sErrors,
    'Global error handlers',
    flutterError && asyncErrors ? Level.pass : Level.fail,
    flutterError && asyncErrors
        ? 'Framework and async errors are caught centrally.'
        : 'Missing: ${[if (!flutterError) 'FlutterError.onError', if (!asyncErrors) 'PlatformDispatcher.instance.onError'].join(', ')}. Uncaught errors crash or vanish silently.',
    flutterError && asyncErrors
        ? null
        : 'Add a bootstrap() like templates/starter_app/lib/bootstrap.dart (ERROR-HANDLING.md; for BLoC/Provider see EXISTING-PROJECTS.md).',
  );

  final errorWidget = all.contains('ErrorWidget.builder');
  _add(
    _sErrors,
    'Friendly build-error widget',
    errorWidget ? Level.pass : Level.warn,
    errorWidget
        ? 'ErrorWidget.builder is customized.'
        : 'A widget that throws shows a grey box (release) or red screen (debug).',
    errorWidget ? null : 'Set ErrorWidget.builder to a calm placeholder.',
  );

  final crash = RegExp(
    r'^\s+(sentry_flutter|firebase_crashlytics|bugsnag_flutter|datadog_flutter_plugin|instabug_flutter):',
    multiLine: true,
  ).hasMatch(_pubspec);
  _add(
    _sErrors,
    'Crash reporting',
    crash ? Level.pass : Level.warn,
    crash
        ? 'A crash reporting SDK is installed.'
        : 'No crash reporting: you will not know when the app crashes for users.',
    crash ? null : 'Add sentry_flutter or firebase_crashlytics.',
  );

  final unhandledBuilders = <String>[];
  final whenWithoutError = <String>[];
  for (final MapEntry(key: path, value: parsed) in _parsedLib().entries) {
    final code = parsed.codeOnly;
    if ((code.contains('FutureBuilder') || code.contains('StreamBuilder')) &&
        !code.contains('hasError')) {
      unhandledBuilders.add(path);
    }
    for (final m in RegExp(r'\.when\s*\(').allMatches(code)) {
      final openParen = m.end - 1;
      final call = parsed.inspectCallAt(openParen, callee: 'when');
      if (call != null && !call.hasNamed('error')) {
        whenWithoutError.add('$path:${parsed.lineOf(m.start)}');
      }
    }
  }
  _add(
    _sErrors,
    'Loading / error / empty states',
    unhandledBuilders.isEmpty && whenWithoutError.isEmpty
        ? Level.pass
        : Level.warn,
    unhandledBuilders.isEmpty && whenWithoutError.isEmpty
        ? 'Async widgets handle the error state.'
        : 'Error state not handled: ${_list([...unhandledBuilders.map((p) => '$p (FutureBuilder/StreamBuilder without hasError)'), ...whenWithoutError])}',
    unhandledBuilders.isEmpty && whenWithoutError.isEmpty
        ? null
        : 'Every data screen needs loading, error + retry, empty and data states.',
  );
  _checkScreenStates();
}

/// Screen by screen: a screen that fetches data when it opens must show a
/// loading indicator, and a screen that talks to the server must tell the
/// user when that fails. Recognizes Riverpod, BLoC/Cubit, Provider/Listenable
/// and custom project loading/error widgets discovered by [ProjectSemantics].
void _checkScreenStates() {
  final semantics = _semantics();
  final screenFile = RegExp(
    r'class\s+[A-Z]\w*(?:Page|Screen)\s+extends\s+(?!State<)\w+',
  );
  final serverCall = RegExp(
    r'''\.(?:get|post|put|patch|delete)(?:<[^>]*>)?\(\s*['"]/|\bhttps?\.(?:get|post|put|delete)\('''
    r'''|await\s+[^;\n]{0,80}(?:Api\b|Api\.|Api\(|ApiClient|Repository|\bdio\b|Firestore|supabase|graphql)'''
    r'''|\bBloc(?:Builder|Consumer)<|\bcontext\.(?:read|watch)<\w*(?:Bloc|Cubit|Notifier|ViewModel)>''',
  );
  final loadsOnOpen = RegExp(
    r'initState\s*\(|FutureBuilder|StreamBuilder|BlocBuilder|BlocConsumer',
  );
  final extraLoading = [
    for (final w in semantics.customLoadingWidgets) '\\b${RegExp.escape(w)}\\b',
  ];
  final extraError = [
    for (final w in semantics.customErrorWidgets) '\\b${RegExp.escape(w)}\\b',
  ];
  final loadingUi = RegExp(
    [
      r'CircularProgressIndicator|LinearProgressIndicator|RefreshProgressIndicator',
      r'CupertinoActivityIndicator|Shimmer|Skeleton|[Ll]oading|[Yy]ukleniyor|[Yy]ükleniyor',
      r'isBusy|ConnectionState\.waiting|\.when\(|AsyncValueView',
      ...extraLoading,
    ].join('|'),
  );
  final errorUi = RegExp(
    [
      r'hasError|Error(?:View|Widget|State|Message|Text)|\berror\s*[:=]|_error\b',
      r'[Rr]etry|[Tt]ekrar [Dd]ene|[Tt]ry again|AsyncValueView|showSnackBar',
      r'\.when\(|[Hh]ata\b|\bFailure\b',
      ...extraError,
    ].join('|'),
  );
  final noLoading = <String>[];
  final noError = <String>[];
  var dataScreens = 0;
  for (final MapEntry(key: path, value: parsed) in _parsedLib().entries) {
    final code = parsed.codeOnly;
    final src = parsed.raw;
    if (!screenFile.hasMatch(code) || !serverCall.hasMatch(src)) continue;
    dataScreens++;
    if (loadsOnOpen.hasMatch(code) && !loadingUi.hasMatch(src)) {
      noLoading.add(path);
    }
    if (!errorUi.hasMatch(src)) noError.add(path);
  }
  if (dataScreens == 0) return;
  _add(
    _sErrors,
    'Screens show a loading state while data loads',
    noLoading.isEmpty ? Level.pass : Level.warn,
    noLoading.isEmpty
        ? 'All $dataScreens screens that fetch data have a loading indicator.'
        : 'These screens fetch data when they open but have no loading indicator, so the user sees a blank or half-empty page: ${_list(noLoading)}',
    noLoading.isEmpty
        ? null
        : 'Show a progress indicator or skeleton until the first data arrives (ERROR-HANDLING.md, "Four states").',
  );
  _add(
    _sErrors,
    'Screens tell the user when the server call fails',
    noError.isEmpty ? Level.pass : Level.warn,
    noError.isEmpty
        ? 'All $dataScreens screens that call the server have an error message or retry.'
        : 'These screens call the server but show nothing when it fails (the page stays empty or the button seems to do nothing): ${_list(noError)}',
    noError.isEmpty
        ? null
        : 'Show a friendly message with "Try again"; never swallow the error silently.',
  );
}

// ------------------------------------------------ messages users can read

final _rawExceptionText = RegExp(
  r'\b(?:e|err|error|exception|ex|failure|\w+\.error)\.toString\(\)'
  r'|\$(?:e|err|error|exception|ex|stackTrace|stack|st)\b'
  r'|\$\{(?:e|err|error|exception|ex|snapshot|stackTrace|stack|st)\b[^}]*\}'
  r'|\.runtimeType\b',
);
final _statusOrPayload = RegExp(
  r'\bstatusCode\b|\bstatusMessage\b|\bresponse\??\.(?:data|body)\b',
);
final _serverText = RegExp(
  r'''\[\s*['"](?:message|error|detail|msg|errors|error_description)['"]\s*\]''',
);
final _developerWording = RegExp(
  r'\b[A-Z]\w+(?:Exception|Error)\b|\bException\b|\bHTTP \d{3}\b'
  r'|\b[Ee]rror \d{3}\b|\b[Hh]ata \d{3}\b|\bstatus ?code\b|\bdurum kodu\b'
  r'|\bstack ?trace\b|\bInternal Server Error\b|\bBad Request\b'
  r'|\bBad Gateway\b|\bUnauthorized\b|\berrno\b|\bnull pointer\b'
  r'|\bFailed to fetch\b|\bUnexpected token\b|\bXMLHttpRequest\b'
  r'|\bConnection refused\b|\bis not a subtype of\b|\([45]\d{2}\)',
);

void _checkUserFacingErrors() {
  final raw = <String>{};
  final status = <String>{};
  final server = <String>{};
  final wording = <String>{};
  final customUi = _semantics().customUiCalls;

  for (final MapEntry(key: path, value: parsed) in _parsedLib().entries) {
    final src = parsed.raw;
    bool shown(int offset) =>
        !parsed.isAllowed(offset) &&
        parsed.shownToUser(offset, customUiCalls: customUi);

    for (final m in _rawExceptionText.allMatches(src)) {
      if (!shown(m.start)) continue;
      final name = RegExp(r'^\$?\{?(e|ex|err)\b').firstMatch(m.group(0)!);
      if (name != null && !parsed.boundAsError(m.start, name.group(1)!)) {
        continue;
      }
      raw.add('$path:${parsed.lineOf(m.start)}');
    }
    for (final m in _statusOrPayload.allMatches(src)) {
      if (!shown(m.start)) continue;
      status.add('$path:${parsed.lineOf(m.start)}');
    }
    for (final m in _serverText.allMatches(src)) {
      if (!shown(m.start)) continue;
      final before = parsed.codeOnly.substring(
        (m.start - 60).clamp(0, m.start),
        m.start,
      );
      if (!RegExp(
        r'response|error|exception|\b(?:e|ex|err)\b[?!]?\.',
        caseSensitive: false,
      ).hasMatch(before)) {
        continue;
      }
      server.add('$path:${parsed.lineOf(m.start)}');
    }
    for (final span in parsed.stringLiterals) {
      if (!shown(span.start)) continue;
      final literal = src.substring(span.start, span.end);
      final hit = _developerWording.firstMatch(literal);
      if (hit != null) {
        wording.add('$path:${parsed.lineOf(span.start)} ("${hit.group(0)}")');
      }
    }
  }

  // Translation files are user-facing by definition.
  for (final dir in [
    'lib',
    'l10n',
    'assets',
    for (final pkg in workspacePackageDirs(_root)) '$pkg/lib',
  ]) {
    final d = Directory('$_root/$dir');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.arb')) continue;
      final rel = f.path.substring(_root.length + 1).replaceAll(r'\', '/');
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final value = RegExp(
          r'^\s*"[^@"][^"]*"\s*:\s*"(.*)"',
        ).firstMatch(lines[i])?.group(1);
        final hit = value == null ? null : _developerWording.firstMatch(value);
        if (hit != null) wording.add('$rel:${i + 1} ("${hit.group(0)}")');
      }
    }
  }

  _add(
    _sErrors,
    'No raw exception text shown to users',
    raw.isEmpty ? Level.pass : Level.fail,
    raw.isEmpty
        ? 'No exception objects, `e.toString()` or stack traces are put on screen.'
        : 'Exception text is shown to users (unreadable for them, and it can leak URLs and tokens): ${_list(raw.toList())}',
    raw.isEmpty
        ? null
        : 'Map the error to a typed failure and show a localized sentence that says what happened and what to do (ERROR-HANDLING.md, "Messages users can understand").',
  );
  _add(
    _sErrors,
    'No status codes or server responses shown to users',
    status.isEmpty ? Level.pass : Level.fail,
    status.isEmpty
        ? 'No HTTP status code or response body is put on screen.'
        : 'HTTP status code / response body shown to users: ${_list(status.toList())}',
    status.isEmpty
        ? null
        : 'Translate the status into a failure type (404 → "not found", 5xx → "something went wrong on our side") and show its localized message. Log the code instead.',
  );
  _add(
    _sErrors,
    'Server error text is not passed straight to users',
    server.isEmpty ? Level.pass : Level.warn,
    server.isEmpty
        ? 'No `data[\'message\']` style server text is put on screen.'
        : 'Text from the server response is shown as-is (often English, technical, or not in the user\'s language): ${_list(server.toList())}',
    server.isEmpty
        ? null
        : 'Show your own localized message chosen by an error code from the server. Server text is acceptable only for field validation the backend already localizes.',
  );
  _add(
    _sErrors,
    'Error wording is plain language',
    wording.isEmpty ? Level.pass : Level.warn,
    wording.isEmpty
        ? 'No developer wording (exception names, "HTTP 500", "status code") in user-facing strings.'
        : 'Developer wording in user-facing text: ${_list(wording.toList())}',
    wording.isEmpty
        ? null
        : 'Rewrite for a non-technical reader: what happened + what to do next ("Could not connect. Check your internet and try again.").',
  );
}

// ------------------------------------------------------------------ security

void _checkSecurity() {
  final all = _libSources().values.join('\n');
  final hasAuth = RegExp(
    r'signIn|logIn\(|login\(|signUp|register\(|FirebaseAuth|accessToken|access_token|Bearer ',
  ).hasMatch(all);
  if (hasAuth) {
    final secure = RegExp(
      r'^\s+(flutter_secure_storage|flutter_secure_storage_x):',
      multiLine: true,
    ).hasMatch(_pubspec);
    final firebaseOnly =
        all.contains('FirebaseAuth') && !all.contains('accessToken');
    // Evidence, not a guess: a file that both opens a plain store and
    // handles access / refresh tokens.
    final plainStore = RegExp(
      r'Hive\.(?:box|openBox)|SharedPreferences|GetStorage\(|\bFile\(',
    );
    final tokenName = RegExp(
      r'''(?:access|refresh|auth|id)_?[Tt]oken|['"](?:access|refresh|token|jwt)['"]''',
    );
    final plainTokenFiles = secure || firebaseOnly
        ? const <String>[]
        : [
            for (final MapEntry(key: path, value: parsed)
                in _parsedLib().entries)
              if (plainStore.hasMatch(parsed.codeOnly) &&
                  tokenName.hasMatch(parsed.raw) &&
                  !parsed.codeOnly.contains('encryptionCipher') &&
                  !parsed.raw.contains('forbidden:allow'))
                path,
          ];
    _add(
      _sSecurity,
      'Secure token storage',
      secure || firebaseOnly
          ? Level.pass
          : (plainTokenFiles.isNotEmpty ? Level.fail : Level.warn),
      secure
          ? 'flutter_secure_storage (Keychain / Keystore) is used.'
          : firebaseOnly
          ? 'Firebase Auth manages its own tokens.'
          : plainTokenFiles.isNotEmpty
          ? 'Sign-in tokens are kept in plain storage (Hive / SharedPreferences / file, no encryption) in ${_list(plainTokenFiles)}. Anyone with a backup, a rooted phone or a stolen unlocked device can copy them and use the account.'
          : 'The app handles sign-in but has no secure storage dependency: tokens may end up in plain files/SharedPreferences.',
      secure || firebaseOnly
          ? null
          : 'Store tokens only with flutter_secure_storage (Keychain / Keystore), or open the Hive box with an encryptionCipher whose key lives in secure storage (SECURITY.md).',
    );
  }

  final usesNetwork = RegExp(
    r'^\s+(dio|http|graphql_flutter|chopper|retrofit):',
    multiLine: true,
  ).hasMatch(_pubspec);
  if (usesNetwork) {
    final pinning = RegExp(
      r'validateCertificate|SecurityContext\(|CertificatePinner|certificate_pinning|ssl_pinning|http_certificate_pinning|secure_pinning',
    ).hasMatch(all + _pubspec);
    _add(
      _sSecurity,
      'Certificate pinning',
      pinning ? Level.pass : Level.warn,
      pinning
          ? 'TLS certificate / public-key pinning is implemented.'
          : 'No certificate pinning: a malicious Wi-Fi or installed CA can read API traffic.',
      pinning
          ? null
          : 'Add SPKI pinning with a backup pin (templates/starter_app/lib/core/network/certificate_pinner.dart).',
    );
    final timeouts = RegExp(
      r'connectTimeout|receiveTimeout|\.timeout\(',
    ).hasMatch(all);
    _add(
      _sSecurity,
      'Network timeouts',
      timeouts ? Level.pass : Level.warn,
      timeouts
          ? 'Requests have timeouts.'
          : 'No request timeouts found: a dead network can hang screens forever.',
      timeouts ? null : 'Set connect/receive timeouts on the HTTP client.',
    );
  }

  final logging = RegExp(
    r'\bprint\(|debugPrint\(',
  ).allMatches(_allCodeOnly()).length;
  _add(
    _sSecurity,
    'No raw print logging',
    logging == 0 ? Level.pass : Level.warn,
    logging == 0
        ? 'No print/debugPrint in lib/.'
        : '$logging print/debugPrint call(s): logs can leak tokens and personal data on devices.',
    logging == 0
        ? null
        : 'Use one logger that redacts secrets and is silent in release.',
  );
}

// ---------------------------------------------------------------- responsive

void _checkResponsive() {
  final tests = _testSources().values.join('\n');
  final screens = <String, String>{};
  for (final MapEntry(key: path, value: parsed) in _parsedLib().entries) {
    for (final m in RegExp(
      r'class\s+(\w+(?:Page|Screen|View))\s+extends\s+(?!State<)\w+',
    ).allMatches(parsed.codeOnly)) {
      final name = m.group(1)!;
      final isView = name.endsWith('View');
      if (name.startsWith('_') ||
          (isView && !RegExp(r'/(screens|pages|views)/').hasMatch(path))) {
        continue;
      }
      screens[name] = path;
    }
  }
  if (screens.isNotEmpty) {
    final untested = screens.keys.where((s) => !tests.contains(s)).toList()
      ..sort();
    _add(
      _sUi,
      'Screens covered by widget tests',
      untested.isEmpty ? Level.pass : Level.warn,
      untested.isEmpty
          ? 'All ${screens.length} screens appear in tests.'
          : '${untested.length}/${screens.length} screens never rendered in a test: ${_list(untested.map((s) => '`$s` (${screens[s]})').toList())}',
      untested.isEmpty
          ? null
          : 'Add them to a responsive matrix test (5 sizes × 100–300% text × locales), see RESPONSIVE-AND-LARGE-TEXT.md.',
    );
  }

  final largeTextTest = RegExp(
    r'textScaleFactorTestValue|TextScaler\.linear\(\s*[2-3]',
  ).hasMatch(tests);
  _add(
    _sUi,
    'Large-text test (200–300%)',
    largeTextTest ? Level.pass : Level.warn,
    largeTextTest
        ? 'Tests render screens with enlarged text.'
        : 'No test renders the app with enlarged text, so overflow at 200% font size goes unnoticed.',
    largeTextTest
        ? null
        : 'Copy templates/starter_app/test/responsive_test.dart and large_text_test.dart.',
  );

  final locked = <String>[];
  final lockedLocally = <String>[];
  final fixedHeights = <String>[];
  const textWidgets = {
    'Text',
    'rich',
    'RichText',
    'SelectableText',
    'TextSpan',
  };
  bool widgetLevel(DartSource parsed, int offset) {
    final calls = parsed.enclosingCalls(offset, 6);
    if (calls.any(
      (c) =>
          c == 'MediaQuery' ||
          c == 'MediaQueryData' ||
          c == 'withClampedTextScaling' ||
          c == 'withNoTextScaling',
    )) {
      return false;
    }
    return calls.take(3).any(textWidgets.contains);
  }

  var usesSafeArea = false;
  var adaptive = false;
  final customTextCalls = _semantics().customUiCalls;
  for (final MapEntry(key: path, value: parsed) in _parsedLib().entries) {
    final code = parsed.codeOnly;
    final src = parsed.raw;
    usesSafeArea |= code.contains('SafeArea');
    adaptive |= RegExp(
      r'LayoutBuilder|MediaQuery\.sizeOf|MediaQuery\.of\(context\)\.size|WindowSize|NavigationRail|breakpoint',
      caseSensitive: false,
    ).hasMatch(code);

    for (final m in RegExp(
      r'TextScaler\.noScaling|textScaleFactor\s*:\s*1(?:\.0)?\b',
    ).allMatches(code)) {
      if (parsed.isAllowed(m.start)) continue;
      (widgetLevel(parsed, m.start) ? lockedLocally : locked).add(
        '$path:${parsed.lineOf(m.start)}',
      );
    }

    for (final m in RegExp(
      r'maxScaleFactor\s*:\s*([0-9.]+)',
    ).allMatches(code)) {
      if (parsed.isAllowed(m.start)) continue;
      final clamp = m.group(1)!;
      final window = code.substring((m.start - 250).clamp(0, m.start), m.end);
      if ((double.tryParse(clamp) ?? 3) < 2 &&
          !RegExp(
            r'Navigation|Rail|AppBar|TabBar|BottomBar|chrome',
            caseSensitive: false,
          ).hasMatch(window)) {
        (widgetLevel(parsed, m.start) ? lockedLocally : locked).add(
          '$path:${parsed.lineOf(m.start)} (capped at ${clamp}x)',
        );
      }
    }

    // Structural check for fixed-height SizedBox / Container wrapping text.
    for (final m in RegExp(r'\b(SizedBox|Container)\s*\(').allMatches(code)) {
      if (parsed.isAllowed(m.start)) continue;
      final call = parsed.inspectCallAt(m.end - 1, callee: m.group(1)!);
      if (call == null) continue;
      final hArg = call.named('height');
      final childArg = call.named('child');
      if (hArg == null || childArg == null) continue;
      final hText = src.substring(hArg.start, hArg.end);
      final isLiteralNumber = RegExp(
        r'^\s*height\s*:\s*\d+(?:\.\d+)?\s*$',
      ).hasMatch(hText);
      if (!isLiteralNumber) continue;
      final childCode = code.substring(childArg.start, childArg.end);
      final wrapsText =
          RegExp(
            r'\b(?:Text|RichText|SelectableText)\s*\(',
          ).hasMatch(childCode) ||
          customTextCalls.any(
            (w) => RegExp('\\b${RegExp.escape(w)}\\s*\\(').hasMatch(childCode),
          );
      if (wrapsText) {
        fixedHeights.add('$path:${parsed.lineOf(m.start)}');
      }
    }
  }
  _add(
    _sUi,
    'Text follows the phone\'s font size',
    locked.isEmpty ? Level.pass : Level.fail,
    locked.isEmpty
        ? 'Text size is never locked or capped below 2x.'
        : 'Text size locked/capped at ${_list(locked)}: users who enlarge text to 200% will not see it bigger.',
    locked.isEmpty
        ? null
        : 'Remove TextScaler.noScaling / textScaleFactor: 1 and caps below 2x (only navigation bars may be capped).',
  );
  if (lockedLocally.isNotEmpty) {
    _add(
      _sUi,
      'Text size fixed on single widgets',
      Level.warn,
      'Text that does not follow the font size setting: ${_list(lockedLocally)}. Acceptable for a logo or a fixed-size cell (calendar day, badge) when the same information is readable elsewhere; not for content.',
      'Keep it only where the layout cannot grow; give the element a tooltip / semantics label with the full text.',
    );
  }
  _add(
    _sUi,
    'No fixed heights around text',
    fixedHeights.isEmpty ? Level.pass : Level.warn,
    fixedHeights.isEmpty
        ? 'No fixed-height boxes around text found.'
        : 'Text in a fixed height is cut off with large text: ${_list(fixedHeights)}',
    fixedHeights.isEmpty
        ? null
        : 'Drop the height or compute it with MediaQuery.textScalerOf(context).scale(x).',
  );
  _add(
    _sUi,
    'Safe areas (notch, gesture bar)',
    usesSafeArea ? Level.pass : Level.warn,
    usesSafeArea
        ? 'SafeArea is used.'
        : 'No SafeArea: content can hide under the notch or gesture bar.',
    usesSafeArea
        ? null
        : 'Wrap screen bodies with SafeArea (or use Scaffold app bars).',
  );
  _add(
    _sUi,
    'Adaptive layout (tablet / landscape)',
    adaptive ? Level.pass : Level.warn,
    adaptive
        ? 'Layouts react to the available size.'
        : 'No size-based layout found: tablets and landscape show a stretched phone UI.',
    adaptive
        ? null
        : 'Use width breakpoints (compact/medium/expanded) divided by text scale (RESPONSIVE-AND-LARGE-TEXT.md).',
  );
}

// ------------------------------------------------------- store requirements

void _checkStoreRequirements() {
  final all = _libSources().values.join('\n');
  final hasAccounts = RegExp(
    r'signUp|register\(|createUserWithEmailAndPassword|signIn|login\(|logIn\(',
  ).hasMatch(all);
  _hasAccounts = hasAccounts;
  if (!hasAccounts) {
    _add(
      _sStore,
      'Account rules',
      Level.pass,
      'No sign-in or sign-up found in the code, so the account rules were not applied: in-app account deletion, reviewer test account, deletion described in the privacy policy. If the app does have accounts (e.g. through a web view), apply them by hand.',
    );
  }
  if (hasAccounts) {
    final deletion = RegExp(
      r'deleteAccount|delete_account|deleteUser|user\.delete\(|currentUser\?\.delete\(|removeAccount',
    ).hasMatch(all);
    _add(
      _sStore,
      'In-app account deletion',
      deletion ? Level.pass : Level.fail,
      deletion
          ? 'Users can delete their account in the app.'
          : 'The app has accounts but no account deletion (required by Google Play and the App Store).',
      deletion
          ? null
          : 'Add "Delete account" in settings: backend call + wipe local data; also publish a web deletion URL.',
    );

    // Reviewers cannot test what is behind a login.
    _add(
      _sStore,
      'Test account for store review (the app has sign-in)',
      Level.manual,
      'Create a dedicated reviewer account and give it to both stores: '
          'Google Play Console > App content > App access ("All or some functionality is restricted") and '
          'App Store Connect > App Review Information > Sign-in required. '
          'It must never expire, already contain sample data, need no SMS / e-mail code (or explain how to get one), '
          'and work from abroad. Keep the backend running during review. '
          'A missing or broken reviewer login is one of the most common rejections on both stores.',
      'If parts of the app work without an account, say so in the review notes. If the app sells subscriptions, say how the reviewer reaches the paywall.',
    );

    if (deletion) _checkDeletionIsDocumented();
  }
  final privacy = RegExp(
    r'privacy[ _-]?(?:policy|notice|url)|privacyPolicy|gizlilik|kvkk|datenschutz',
    caseSensitive: false,
  ).hasMatch(all);
  _add(
    _sStore,
    'Privacy policy link in the app',
    privacy ? Level.pass : Level.warn,
    privacy ? 'Found.' : 'No privacy policy link inside the app.',
    privacy
        ? null
        : 'Add a "Privacy policy" item in settings that opens your public policy URL (url_launcher).',
  );
  final l10n =
      _pubspec.contains('flutter_localizations') ||
      _pubspec.contains('material_ui') &&
          all.contains('GlobalMaterialLocalizations') ||
      File('$_root/l10n.yaml').existsSync() ||
      all.contains('AppLocalizations');
  _add(
    _sStore,
    'Localization',
    l10n ? Level.pass : Level.warn,
    l10n
        ? 'Localization is set up.'
        : 'No localization: dates, numbers and system widgets stay in English.',
    l10n ? null : 'Add localization delegates and supportedLocales.',
  );
}

/// The stores require the privacy policy to say that an account can be
/// deleted, how, and what happens to the data. When the legal text ships in
/// the app it can be read; otherwise it is a manual task.
void _checkDeletionIsDocumented() {
  final legalName = RegExp(
    r'legal|privacy|gizlilik|terms|sozlesme|sözleşme|policy|kvkk|kullanim|kullanım',
    caseSensitive: false,
  );
  final texts = <String, String>{
    for (final MapEntry(key: path, value: src) in _libSources().entries)
      if (legalName.hasMatch(path.split('/').last) &&
          src.length > 1500 &&
          (src.contains("'''") || src.contains('"""')))
        path: src,
  };
  final assets = Directory('$_root/assets');
  if (assets.existsSync()) {
    for (final f in assets.listSync(recursive: true).whereType<File>()) {
      final name = f.path.split(RegExp(r'[\\/]')).last;
      if (!RegExp(r'\.(md|txt|html?|json)$').hasMatch(name) ||
          !legalName.hasMatch(name) ||
          f.lengthSync() > 400000) {
        continue;
      }
      texts[f.path.substring(_root.length + 1).replaceAll(r'\', '/')] = f
          .readAsStringSync();
    }
  }
  const title = 'Privacy policy / terms describe account deletion';
  if (texts.isEmpty) {
    _add(
      _sStore,
      title,
      Level.manual,
      'The app lets users delete their account, and the legal text is not shipped in the app, so it could not be read. '
          'Open your privacy policy and terms pages and check they say: that the account can be deleted and where (in-app path + a web address for people who uninstalled), '
          'which data is deleted, what is kept and for how long (e.g. invoices), and whom to contact.',
      'Google Play also asks for the web deletion URL in the Data safety form; App Store Connect asks about it in App Privacy.',
    );
    return;
  }
  final mention = RegExp(
    r'(?:hesab|hesap|account|üyeli|uyeli)[^.\n]{0,160}(?:sil|delet|remov|kapat|erase)'
    r'|(?:sil\w*|delet\w*|remov\w*|eras\w*)[^.\n]{0,160}(?:hesab|hesap|account|üyeli|uyeli)',
    caseSensitive: false,
  );
  final documented = texts.entries
      .where((e) => mention.hasMatch(e.value))
      .map((e) => e.key)
      .toList();
  _add(
    _sStore,
    title,
    documented.isNotEmpty ? Level.pass : Level.warn,
    documented.isNotEmpty
        ? 'Account deletion is described in ${documented.join(', ')}. Keep the public web copy of the policy identical.'
        : 'The app lets users delete their account, but the legal text in ${texts.keys.join(', ')} does not mention it.',
    documented.isNotEmpty
        ? null
        : 'Add a section: how to delete the account (in-app path + web address), which data is deleted, what is kept and for how long, contact. Update the public web page too.',
  );
}

// ----------------------------------------------------------- store policies
//
// Rules that depend on what the app contains (purchases, ads, user content,
// AI, SDKs that collect data). Each block only runs when the feature is
// found. Everything here is a heuristic over pubspec.yaml and lib/, so
// nothing is blocking: see STORE-POLICIES.md.

bool _pkg(String name) =>
    RegExp('^\\s+${RegExp.escape(name)}:', multiLine: true).hasMatch(_pubspec);

List<String> _pkgs(Iterable<String> names) => names.where(_pkg).toList();

/// SDK → what it collects, in the words of the Play Data safety form and
/// Apple's App Privacy labels. A starting point: each SDK publishes its own
/// disclosure page.
const _sdkData = <String, String>{
  'firebase_analytics': 'app interactions, device or other IDs, diagnostics',
  'firebase_crashlytics': 'crash logs, diagnostics, device or other IDs',
  'sentry_flutter': 'crash logs, diagnostics, device or other IDs',
  'firebase_performance': 'performance diagnostics',
  'firebase_messaging': 'device or other IDs (push token)',
  'onesignal_flutter': 'device or other IDs (push token), app interactions',
  'google_mobile_ads':
      'advertising ID, app interactions, approximate location, diagnostics — shared with Google for advertising',
  'facebook_app_events':
      'advertising ID, app interactions, device or other IDs',
  'appsflyer_sdk': 'advertising ID, app interactions, device or other IDs',
  'adjust_sdk': 'advertising ID, app interactions, device or other IDs',
  'firebase_auth':
      'e-mail address, user IDs (name / phone if you ask for them)',
  'google_sign_in': 'e-mail address, name, user IDs',
  'sign_in_with_apple': 'e-mail address, name, user IDs',
  'geolocator': 'precise or approximate location',
  'location': 'precise or approximate location',
  'image_picker': 'photos / videos, if they are uploaded',
  'camera': 'photos / videos, if they are uploaded',
  'record': 'voice or sound recordings, if they are uploaded',
  'flutter_contacts': 'contacts, if they leave the device',
  'contacts_service': 'contacts, if they leave the device',
  'in_app_purchase':
      'purchase history — only if your app or server records purchases (a flag kept on the device is not collected)',
  'purchases_flutter':
      'purchase history, user IDs (RevenueCat stores purchases on its servers)',
  'flutter_stripe': 'payment info (processed by Stripe), purchase history',
  'device_info_plus': 'device or other IDs, if they are sent to your server',
  'health': 'health and fitness data',
};

void _checkStorePolicies() {
  const section = 'Store policy';
  final all = _libSources().values.join('\n');

  // --- in-app purchases
  final iap = _pkgs([
    'in_app_purchase',
    'purchases_flutter',
    'flutter_inapp_purchase',
    'adapty_flutter',
    'qonversion_flutter',
  ]);
  if (iap.isNotEmpty) {
    final restore = RegExp(
      r'restorePurchases\(|restoreTransactions\(|\.restore\w*\(|getAvailablePurchases\(|queryPastPurchases\(',
    ).hasMatch(all);
    _add(
      section,
      'Restore purchases',
      restore ? Level.pass : Level.warn,
      restore
          ? 'The app can restore earlier purchases (${iap.join(', ')}).'
          : 'In-app purchases (${iap.join(', ')}) but no restore call found. Apple rejects apps whose non-consumable purchases or subscriptions cannot be restored (guideline 3.1.1). Not needed when everything is consumable.',
      restore
          ? null
          : 'Add a visible "Restore purchases" button on the paywall or in settings that calls restorePurchases().',
    );
    _add(
      section,
      'Paywall tells the user what they pay',
      Level.manual,
      'Open the purchase screen and check, before the buy button: the price from the store (not hard-coded), what the user gets, '
          'for subscriptions the billing period, that it renews automatically and how to cancel, trial length and the price after it, '
          'and working links to the Terms of use (EULA) and the Privacy policy. The total billed amount must be at least as prominent as a per-month figure.',
      'Missing terms or links on the paywall are a routine rejection on both stores.',
    );
  }

  // --- ads: consent before the SDK starts
  final ads = _pkgs([
    'google_mobile_ads',
    'applovin_max',
    'unity_ads_plugin',
    'facebook_audience_network',
    'ironsource_mediation',
  ]);
  if (ads.isNotEmpty) {
    final consent = RegExp(
      r'ConsentInformation|ConsentForm|requestConsentInfoUpdate|UserMessagingPlatform|ConsentManager|\bconsent\w*\(',
    ).hasMatch(all);
    _add(
      section,
      'Ads: consent before the ad SDK starts',
      consent ? Level.pass : Level.warn,
      consent
          ? 'A consent flow is present (${ads.join(', ')}). Check that the ad SDK is initialized only after it finishes.'
          : 'Ad SDK (${ads.join(', ')}) with no consent flow in the code. For users in the EEA, the UK and Switzerland Google requires consent collected by a certified consent platform (e.g. its UMP SDK) before ads are requested; without it ads are limited or not served there, and it is a policy violation.',
      consent
          ? null
          : 'Run the UMP flow (ConsentInformation.requestConsentInfoUpdate → load and show the form) before MobileAds.initialize(). On iOS show the tracking prompt before as well.',
    );
    _add(
      section,
      'Ads: placement',
      Level.manual,
      'Check on a device: no full-screen ad at app launch or when leaving the app, interstitials only at natural breaks and closable, rewarded ads only when the user chooses them, no ads that look like app buttons, and none in apps for children unless the SDK is certified for families.',
    );
  }

  // --- user-generated content
  final ugcFiles = _libSources().keys
      .where(
        (p) => RegExp(
          // whole words in the file name: `feedback.dart` is not a feed
          r'(^|_)(chat|comments?|forum|feed|messages?|posts?|reviews?|yorum\w*|sohbet)(_|\.dart$)',
          caseSensitive: false,
        ).hasMatch(p.split('/').last),
      )
      .toList();
  final ugcSdk = _pkgs([
    'stream_chat_flutter',
    'flutter_chat_ui',
    'dash_chat_2',
    'sendbird_chat_sdk',
    'cometchat_sdk',
  ]);
  if (ugcFiles.isNotEmpty || ugcSdk.isNotEmpty) {
    final moderation = RegExp(
      r'report|block|flag|şikayet|sikayet|engelle|bildir',
      caseSensitive: false,
    ).hasMatch(all);
    _add(
      section,
      'User content: report and block',
      moderation ? Level.pass : Level.warn,
      moderation
          ? 'Report / block wording found. Check that each piece of user content can be reported and each user blocked.'
          : 'The app seems to show content written by users (${_list([...ugcSdk, ...ugcFiles], 4)}) but has no report or block action. Both stores require: a way to report content, a way to block users, filtering of objectionable material, and a published contact (Apple guideline 1.2, Google Play user-generated content policy).',
      moderation
          ? null
          : 'Add "Report" on every message / post / profile and "Block user"; act on reports quickly. Ignore this if users only see their own content.',
    );
  }

  // --- generative AI
  final aiSdk = _pkgs([
    'google_generative_ai',
    'firebase_ai',
    'firebase_vertexai',
    'dart_openai',
    'openai_dart',
    'anthropic_sdk_dart',
    'langchain',
    'flutter_gemini',
  ]);
  final aiEndpoint = RegExp(
    r'api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis\.com|chat/completions',
  ).hasMatch(all);
  if (aiSdk.isNotEmpty || aiEndpoint) {
    _add(
      section,
      'AI features: disclosure, consent, reporting',
      Level.manual,
      'The app talks to a generative AI service${aiSdk.isEmpty ? '' : ' (${aiSdk.join(', ')})'}. Check: (1) before personal data is sent to a third-party AI the app says who receives it and asks for permission (Apple guideline 5.1.2(i)); '
          '(2) users can report or flag offensive generated content inside the app (Google Play AI-generated content policy); '
          '(3) the privacy policy and the store data forms name the AI provider; (4) the reviewer account can reach every AI feature.',
      'Never ship the provider API key in the app: call the AI service through your own backend.',
    );
  }

  // --- what the SDKs collect
  final collected = [
    if (_hasAccounts)
      'your own sign-in → e-mail address, user IDs (plus every profile field you store)',
    for (final MapEntry(key: pkg, value: data) in _sdkData.entries)
      if (_pkg(pkg)) '$pkg → $data',
  ];
  if (collected.isNotEmpty) {
    _add(
      section,
      'Data your SDKs collect (declare it in both stores)',
      Level.manual,
      'From pubspec.yaml, at least: ${collected.join('; ')}. '
          'Add what the app itself sends to your server (account details, form fields, content). '
          'The Play Data safety form, Apple App Privacy labels and your privacy policy must all say the same thing.',
      'A form that says "no data collected" while an analytics, ads or crash SDK is installed is a common reason for removal.',
    );
  }

  // --- external payment for digital goods (Android side; iOS is in the App Store audit)
  final payments = _pkgs([
    'flutter_stripe',
    'stripe_payment',
    'razorpay_flutter',
    'flutter_paypal',
    'iyzico',
  ]);
  if (payments.isNotEmpty && iap.isEmpty) {
    _add(
      section,
      'Payments outside the store billing',
      Level.manual,
      'Payment SDK (${payments.join(', ')}) and no in-app purchase plugin. Fine for physical goods and real-world services. Digital content, subscriptions and feature unlocks must go through Google Play Billing and Apple in-app purchase (regional exceptions exist; check the current rules for your countries).',
    );
  }

  // --- traces of development
  final devHosts = <String>[];
  final reviewerChecks = <String>[];
  final hostPattern = RegExp(
    r'''['"](?:https?|wss?)://(?:localhost|127\.0\.0\.1|10\.0\.2\.2|192\.168\.\d+\.\d+|[^'"/\s]*(?:staging|ngrok)[^'"/\s]*)''',
  );
  final guard = RegExp(
    r'kDebugMode|kReleaseMode|kProfileMode|fromEnvironment|assert\(|forbidden:allow'
    r'|\b(?:is|in)(?:Release|Debug|Prod|Production|Dev)(?:Mode|Build)?\b',
  );
  for (final MapEntry(key: path, value: parsed) in _parsedLib().entries) {
    final src = parsed.raw;
    for (final m in hostPattern.allMatches(src)) {
      if (parsed.isAllowed(m.start)) continue;
      final before = parsed.codeOnly.substring(
        (m.start - 240).clamp(0, m.start),
        (m.end + 80).clamp(0, parsed.codeOnly.length),
      );
      if (!guard.hasMatch(before)) {
        devHosts.add('$path:${parsed.lineOf(m.start)}');
      }
    }
    for (final m in RegExp(
      r'\b(?:isTestFlight|sandboxReceipt|isReviewer|appleReview|googleReview|reviewMode|isInReview)\b',
    ).allMatches(parsed.codeOnly)) {
      if (parsed.isAllowed(m.start)) continue;
      reviewerChecks.add('$path:${parsed.lineOf(m.start)}');
    }
  }
  _add(
    section,
    'No development servers in release code',
    devHosts.isEmpty ? Level.pass : Level.warn,
    devHosts.isEmpty
        ? 'No localhost / LAN / staging address reaches a release build unguarded.'
        : 'Local or staging addresses that are not limited to debug builds: ${_list(devHosts)}',
    devHosts.isEmpty
        ? null
        : 'Read the address from the build configuration, or guard it with kReleaseMode / kDebugMode.',
  );
  if (reviewerChecks.isNotEmpty) {
    _add(
      section,
      'Behaves the same for reviewers',
      Level.warn,
      'Code that detects review / TestFlight / sandbox: ${_list(reviewerChecks)}. Showing reviewers something different from real users is grounds for removal (Apple guideline 2.3.1).',
      'Remove it, unless it only selects the sandbox purchase environment.',
    );
  }
}

// ------------------------------------------------ navigation & permissions

void _checkNavigationAndPermissions() {
  const section = 'Navigation & permissions';
  final tests = _testSources().values.join('\n');
  final all = _allCodeOnly();

  // Android back button: nested navigation is where it goes wrong.
  final nested = RegExp(
    r'BottomNavigationBar|NavigationBar\(|NavigationRail|IndexedStack|StatefulShellRoute|TabBarView|AutoTabsScaffold|CupertinoTabScaffold',
  ).hasMatch(all);
  if (nested) {
    final tested = RegExp(
      r'handlePopRoute|pageBack\(|maybePop|PopScope|BackButton',
    ).hasMatch(tests);
    _add(
      section,
      'Back button tested (tabs / nested pages)',
      tested ? Level.pass : Level.warn,
      tested
          ? 'A test presses the system back button.'
          : 'The app has tabs or nested navigation and no test presses the Android back button. Typical bug: back on a second-level page closes the app instead of going up.',
      tested
          ? null
          : 'Add a widget test: open a nested page, call `tester.binding.handlePopRoute()`, expect the parent page (NAVIGATION-AND-LIFECYCLE.md).',
    );
  }

  // Permission prompts at launch.
  final request = RegExp(
    r'Permission\.\w+\.request\(|\.requestPermission\(|requestNotificationsPermission\(|requestTrackingAuthorization\(|requestPermissions\(',
  );
  final atLaunch = [
    for (final MapEntry(key: path, value: parsed) in _parsedLib().entries)
      if (RegExp(
            r'(^|/)(main|bootstrap|app|splash\w*)\.dart$',
          ).hasMatch(path) &&
          request.hasMatch(parsed.codeOnly))
        path,
  ];
  if (request.hasMatch(all)) {
    _add(
      section,
      'Permissions are asked when needed, not at launch',
      atLaunch.isEmpty ? Level.pass : Level.warn,
      atLaunch.isEmpty
          ? 'No permission prompt in the start-up files.'
          : 'A permission is requested while the app starts (${_list(atLaunch)}). Users deny prompts they do not understand, and App Review rejects apps that ask before the feature is used.',
      atLaunch.isEmpty
          ? null
          : 'Ask at the moment the feature is used, after a sentence that explains why — and only for the users / roles that need it.',
    );
  }

  // A global full-width button style breaks every Row that holds a button.
  final wideButtons = <String>[];
  for (final MapEntry(key: path, value: parsed) in _parsedLib().entries) {
    if (!RegExp(r'ThemeData\s*\(').hasMatch(parsed.codeOnly)) continue;
    for (final m in RegExp(
      r'minimumSize\s*:\s*(?:const\s+)?(?:Size\.fromHeight\(|Size\(\s*double\.infinity)',
    ).allMatches(parsed.codeOnly)) {
      if (!parsed.enclosingCalls(m.start).any((c) => c.endsWith('ThemeData'))) {
        continue;
      }
      wideButtons.add('$path:${parsed.lineOf(m.start)}');
    }
  }
  if (wideButtons.isNotEmpty) {
    _add(
      _sUi,
      'Theme does not force full-width buttons',
      Level.warn,
      'The theme makes every button as wide as possible (${_list(wideButtons)}). A button placed next to a title in a Row then takes the whole row and the title wraps letter by letter, worst with large text.',
      'Keep the theme at a minimum height only (e.g. Size(64, 48)); make a button full-width where it is used (SizedBox(width: double.infinity) or Expanded).',
    );
  }

  // Two clients sharing one rotating refresh token.
  final background = _pkgs([
    'workmanager',
    'flutter_background_service',
    'background_fetch',
    'flutter_background_geolocation',
    'background_locator_2',
    'flutter_foreground_task',
  ]);
  // Push alone is not background work; a background message handler is.
  if (all.contains('onBackgroundMessage(')) {
    background.add('firebase_messaging background handler');
  }
  if (background.isNotEmpty &&
      RegExp(r'refresh_?[Tt]oken|refreshToken|/refresh').hasMatch(all)) {
    _add(
      section,
      'Background work and the sign-in session',
      Level.manual,
      'The app refreshes its sign-in token and also runs code in the background (${background.join(', ')}). Background code runs in a separate isolate with its own HTTP client: if both refresh the same rotating token at the same moment, the server sees a reused token and signs the user out. '
          'Check that background requests use their own session / token, or never refresh (they skip the request and let the app refresh).',
    );
  }
}

// --------------------------------------------------------- production config

void _checkProductionConfig() {
  final configDir = Directory('$_root/config');
  final prod = File('$_root/config/prod.json');
  final template = File('$_root/config/prod.example.json');
  if (!configDir.existsSync()) {
    _add(
      _sConfig,
      'Environment config',
      Level.manual,
      'No config/ folder. Make sure release builds point to the production API over https and contain no secrets.',
    );
    return;
  }
  if (!prod.existsSync()) {
    _add(
      _sConfig,
      'config/prod.json',
      template.existsSync() && !_ci ? Level.fail : Level.warn,
      _ci
          ? 'No production configuration file (expected on CI: it is git-ignored).'
          : 'No production configuration file.',
      template.existsSync()
          ? 'Copy config/prod.example.json to config/prod.json and fill it in (git-ignored).'
          : 'Create config/prod.json and build with --dart-define-from-file=config/prod.json.',
    );
    return;
  }
  Map<String, Object?> json;
  try {
    json = (jsonDecode(prod.readAsStringSync()) as Map).cast<String, Object?>();
  } on FormatException catch (e) {
    _add(
      _sConfig,
      'config/prod.json',
      Level.fail,
      'Invalid JSON: ${e.message}',
    );
    return;
  }
  String str(String k) => '${json[k] ?? ''}'.trim();
  bool placeholder(String v) =>
      v.isEmpty ||
      v.contains('<') ||
      v.contains('yourdomain') ||
      v.contains('example.com');

  final httpValues = json.entries
      .where((e) => '${e.value}'.startsWith('http://'))
      .map((e) => e.key)
      .toList();
  _add(
    _sConfig,
    'HTTPS only',
    httpValues.isEmpty ? Level.pass : Level.fail,
    httpValues.isEmpty
        ? 'No http:// URLs in production config.'
        : 'Plain http:// in: ${httpValues.join(', ')}',
    httpValues.isEmpty ? null : 'Use https:// for every production URL.',
  );
  final placeholders = json.entries
      .where(
        (e) =>
            e.value is String &&
            placeholder('${e.value}') &&
            '${e.value}'.isNotEmpty,
      )
      .map((e) => e.key)
      .toList();
  _add(
    _sConfig,
    'No placeholder values',
    placeholders.isEmpty ? Level.pass : Level.fail,
    placeholders.isEmpty
        ? 'All values filled in.'
        : 'Placeholders left in: ${placeholders.join(', ')}',
    placeholders.isEmpty ? null : 'Fill in the real production values.',
  );
  if (json.containsKey('USE_MOCK_API')) {
    _add(
      _sConfig,
      'Real backend',
      json['USE_MOCK_API'] == false ? Level.pass : Level.fail,
      json['USE_MOCK_API'] == false
          ? 'USE_MOCK_API = false'
          : 'The release would use the fake demo backend.',
      json['USE_MOCK_API'] == false ? null : 'Set "USE_MOCK_API": false.',
    );
  }
  if (json.containsKey('CERT_PINS')) {
    final pins = str('CERT_PINS')
        .split(',')
        .where(
          (p) => RegExp(r'^(sha256/)?[A-Za-z0-9+/]{43}=$').hasMatch(p.trim()),
        )
        .length;
    _add(
      _sConfig,
      'Certificate pins',
      pins >= 2 ? Level.pass : Level.fail,
      '$pins valid pin(s); at least 2 required (current + backup key).',
      pins >= 2 ? null : 'Generate SPKI pins (SECURITY.md).',
    );
  }
  final git = Process.runSync('git', [
    'ls-files',
    'config/prod.json',
  ], workingDirectory: _root);
  if (git.exitCode == 0 && '${git.stdout}'.trim().isNotEmpty) {
    _add(
      _sConfig,
      'config/prod.json not committed',
      Level.warn,
      'Production config is tracked by git.',
      'Keep it out of git if it contains anything private (git rm --cached config/prod.json).',
    );
  }
}

// ------------------------------------------------------------------ leftovers

void _checkLeftovers() {
  final main = _read('lib/main.dart') ?? '';
  final counter =
      main.contains('_incrementCounter') ||
      main.contains('Flutter Demo Home Page');
  if (counter) {
    _add(
      _sLeftovers,
      'Default counter app',
      Level.fail,
      'lib/main.dart is still the `flutter create` counter demo.',
      'Replace it with the real app (or install the starter: scripts/install.dart --starter).',
    );
  }
  final all = _libSources().values.join('\n');
  if (RegExp(r"title:\s*'Flutter Demo'").hasMatch(all)) {
    _add(
      _sLeftovers,
      'App title',
      Level.warn,
      'MaterialApp title is still "Flutter Demo" (shown in the task switcher).',
      'Set the real app name.',
    );
  }
  if (_rootPubspec.contains('description: "A new Flutter project."') ||
      _rootPubspec.contains(
        'Production-ready, security-hardened Flutter starter',
      )) {
    _add(
      _sLeftovers,
      'pubspec description',
      Level.warn,
      'Still the template description.',
      'Describe your app in pubspec.yaml.',
    );
  }
  // Starter template markers.
  if (RegExp(r"appTitle => 'Starter'").hasMatch(all)) {
    _add(
      _sLeftovers,
      'App title (starter)',
      Level.warn,
      'The app is still called "Starter".',
      'Change appTitle in lib/core/l10n/app_localizations.dart.',
    );
  }
  if (all.contains('seed = Color(0xFF3F51B5)')) {
    _add(
      _sLeftovers,
      'Brand color (starter)',
      Level.warn,
      'Still the starter\'s default seed color.',
      'Set AppTheme.seed to the brand color.',
    );
  }
  if (Directory('$_root/lib/features/items').existsSync() &&
      all.contains('FakeItemsRepository')) {
    _add(
      _sLeftovers,
      'Sample "Items" feature (starter)',
      Level.warn,
      'The demo feature from the starter is still in the app.',
      'Replace it with real features (keep: repository + AsyncValueView + tests).',
    );
  }
}

// ---------------------------------------------------------------- code health

void _checkCodeHealth() {
  final todos = <String>[];
  for (final MapEntry(key: path, value: src) in _libSources().entries) {
    final lines = src.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (RegExp(r'\b(TODO|FIXME|HACK)\b').hasMatch(lines[i])) {
        todos.add('$path:${i + 1}');
      }
    }
  }
  _add(
    _sCode,
    'TODO / FIXME',
    todos.isEmpty ? Level.pass : Level.warn,
    todos.isEmpty ? 'None in lib/.' : '${todos.length}: ${_list(todos)}',
    todos.isEmpty ? null : 'Resolve them or move them to tracked issues.',
  );

  final matSince = _policies.flutter.materialUiStandaloneSince;
  final oldMaterial = _libSources().entries
      .where((e) => e.value.contains('package:flutter/material.dart'))
      .map((e) => e.key)
      .toList();
  if (oldMaterial.isNotEmpty &&
      matSince.length >= 2 &&
      _flutterAtLeast(matSince[0], matSince[1])) {
    _add(
      _sCode,
      'Deprecated Material import',
      Level.warn,
      'package:flutter/material.dart is deprecated since Flutter ${matSince[0]}.${matSince[1]} (${oldMaterial.length} file(s)).',
      'Optional for existing apps: run `flutter pub add material_ui` and `dart fix --apply` when ready (see EXISTING-PROJECTS.md).',
    );
  }

  final options = _read('analysis_options.yaml') ?? '';
  final strict =
      options.contains('strict-casts') ||
      options.contains('very_good_analysis');
  _add(
    _sCode,
    'Strict static analysis',
    strict ? Level.pass : Level.warn,
    strict
        ? 'Strict analyzer settings enabled.'
        : 'Only default lints: many crash-prone patterns (dynamic calls, unawaited futures) go unnoticed.',
    strict
        ? null
        : 'Use templates/starter_app/analysis_options.yaml (strict-casts, unawaited_futures as error...).',
  );

  final testCount = _testSources().length;
  _add(
    _sCode,
    'Tests',
    testCount > 1 ? Level.pass : Level.fail,
    '$testCount test file(s).',
    testCount > 1 ? null : 'Add unit, widget and responsive tests.',
  );

  final git = Process.runSync('git', [
    'ls-files',
    'pubspec.lock',
  ], workingDirectory: _root);
  final isGit = Directory('$_root/.git').existsSync();
  final lockTracked = git.exitCode == 0 && '${git.stdout}'.trim().isNotEmpty;
  if (isGit) {
    _add(
      _sCode,
      'pubspec.lock committed',
      lockTracked ? Level.pass : Level.warn,
      lockTracked
          ? 'Dependency versions are locked.'
          : 'pubspec.lock is not committed: builds are not reproducible.',
      lockTracked ? null : 'Commit pubspec.lock (apps should).',
    );
  }
  final ci =
      Directory('$_root/.github/workflows').existsSync() ||
      File('$_root/codemagic.yaml').existsSync() ||
      File('$_root/bitbucket-pipelines.yml').existsSync() ||
      File('$_root/.gitlab-ci.yml').existsSync();
  _add(
    _sCode,
    'CI pipeline',
    ci ? Level.pass : Level.warn,
    ci
        ? 'CI configuration found.'
        : 'No CI: nothing stops a broken build from shipping.',
    ci ? null : 'Copy templates/starter_app/.github/workflows/ci.yml.',
  );
}

// ------------------------------------------------ non-Flutter mobile projects

Future<void> _runNonFlutterGates() async {
  final r = await Process.run(
    Platform.resolvedExecutable,
    ['$_scriptsDir/check_forbidden.dart', _root],
    stdoutEncoding: const Utf8Codec(allowMalformed: true),
    stderrEncoding: const Utf8Codec(allowMalformed: true),
  );
  final out = '${r.stdout}\n${r.stderr}'.trim();
  final m = RegExp(r'(\d+) blocking, (\d+) warning').firstMatch(out);
  final blocking = int.parse(m?.group(1) ?? '0');
  final warnings = int.parse(m?.group(2) ?? '0');
  final level = r.exitCode != 0
      ? Level.fail
      : (warnings > 0 ? Level.warn : Level.pass);
  final summary = m == null
      ? (r.exitCode == 0 ? 'None found' : 'Some found')
      : [
          if (blocking > 0)
            '$blocking security pattern(s) (http://, secret in code or plain storage)',
          if (warnings > 0) '$warnings warning(s)',
        ].join('; ');
  _gates.add(
    GateResult(
      'Forbidden patterns',
      level,
      summary,
      level == Level.pass ? null : _tail(out, 40),
    ),
  );
  _add(_sGates, 'Forbidden patterns', level, summary);
}

void _checkNonFlutterApp() {
  final files = <String, String>{};
  for (final dir in [
    'src',
    'app',
    if (_profile.iosAppDir != null) _profile.iosAppDir!,
  ]) {
    final d = Directory('$_root/$dir');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final rel = f.path.substring(_root.length + 1).replaceAll(r'\', '/');
      if (rel.contains('/node_modules/') ||
          rel.contains('/Pods/') ||
          rel.contains('/build/')) {
        continue;
      }
      if (!RegExp(r'\.(tsx?|jsx?|kt|java|swift|m)$').hasMatch(rel)) continue;
      files[rel] = f.readAsStringSync();
    }
  }
  final all = files.values.join('\n');
  _hasAccounts = RegExp(
    r'signIn|logIn\(|login\(|signUp|register\(|FirebaseAuth|createUserWithEmailAndPassword|useAuth',
  ).hasMatch(all);
  if (!_hasAccounts) {
    _add(
      _sStore,
      'Account rules',
      Level.pass,
      'No sign-in or sign-up found in the code, so account-deletion and reviewer-login rules were not applied.',
    );
  } else {
    final deletion = RegExp(
      r'deleteAccount|delete_account|deleteUser|removeAccount',
    ).hasMatch(all);
    _add(
      _sStore,
      'In-app account deletion',
      deletion ? Level.pass : Level.fail,
      deletion
          ? 'Account deletion call found in app code.'
          : 'The app has accounts but no in-app account deletion found (required by Google Play and the App Store).',
      deletion
          ? null
          : 'Add in-app account deletion that deletes server data + publish a web deletion URL.',
    );
    _add(
      _sStore,
      'Test account for store review (the app has sign-in)',
      Level.manual,
      'Create a dedicated, non-expiring reviewer account with sample data and no OTP, and enter it in Google Play Console (App access) and App Store Connect (App Review Information).',
    );
  }

  final privacy = RegExp(
    r'privacy[ _-]?(?:policy|notice|url)|privacyPolicy|gizlilik|kvkk|datenschutz',
    caseSensitive: false,
  ).hasMatch(all);
  _add(
    _sStore,
    'Privacy policy link in the app',
    privacy ? Level.pass : Level.warn,
    privacy ? 'Found.' : 'No privacy policy link found inside the app.',
    privacy ? null : 'Add a "Privacy policy" link in settings/profile.',
  );

  // SDK data collection summary across npm / Gradle / CocoaPods.
  final collected = [
    if (_hasAccounts)
      'your own sign-in → e-mail address, user IDs (plus every profile field you store)',
    for (final MapEntry(key: pkg, value: data) in _sdkData.entries)
      if (_profile.matchedPackage(pkg) case final actual?) '$actual → $data',
  ];
  if (collected.isNotEmpty) {
    _add(
      'Store policy',
      'Data your SDKs collect (declare it in both stores)',
      Level.manual,
      'Detected SDKs: ${collected.join('; ')}. '
          'Ensure Google Play Data safety, Apple App Privacy labels and your privacy policy match.',
    );
  }
}

// ----------------------------------------------------------------- play audit

Future<void> _runPlayAudit(String outDir, String? lastVersionCode) async {
  if (!_profile.isFlutter && !_profile.hasAndroid) {
    _add(
      'Google Play',
      'Android project',
      Level.manual,
      'No Android target in this ${_profile.kind.label} project: the Google Play audit was skipped.',
    );
    return;
  }
  final hasAndroid = _profile.hasAndroid;
  final jsonPath = '$outDir/play_readiness.json';
  final r = await Process.run(Platform.resolvedExecutable, [
    '$_scriptsDir/play_readiness.dart',
    _root,
    '--no-fail',
    '--json',
    jsonPath,
    '--report',
    '$outDir/PLAY_READINESS.md',
    if (!hasAndroid) '--manual-only',
    if (_ci) '--ci',
    if (lastVersionCode != null) ...['--last-version-code', lastVersionCode],
  ]);
  final file = File(jsonPath);
  if (r.exitCode != 0 || !file.existsSync()) {
    _add(
      'Google Play',
      'Play audit',
      Level.fail,
      'The Google Play audit could not run, so nothing about Android release was checked: ${_tail('${r.stderr}', 3)}',
      'Run `dart run <skill>/scripts/play_readiness.dart .` and fix the error.',
    );
    return;
  }
  if (!hasAndroid) {
    _add(
      'Google Play',
      'Android project',
      Level.fail,
      'android/ does not exist.',
      'Run `flutter create --platforms=android,ios .`, then `harden_platforms.dart` from the flutter-store-ready skill.',
    );
  }
  final list = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  for (final c in list) {
    if (!_hasAccounts && c['title'] == 'Account deletion') continue;
    _add(
      'Google Play · ${c['area']}',
      c['title']! as String,
      Level.values.byName(c['status']! as String),
      c['detail']! as String,
      c['fix'] as String?,
    );
  }
}

// ------------------------------------------------------------ app store audit

Future<void> _runAppStoreAudit(String outDir, String? lastBuildNumber) async {
  const section = 'App Store';
  if (!_profile.hasIos && !Directory('$_root/ios').existsSync()) {
    _add(
      section,
      'iOS project',
      Level.manual,
      'No iOS target: the App Store audit was skipped.${_profile.isFlutter ? ' Run `flutter create --platforms=ios .` if the app should ship on iPhone.' : ''}',
    );
    return;
  }
  final jsonPath = '$outDir/app_store_readiness.json';
  final r = await Process.run(Platform.resolvedExecutable, [
    '$_scriptsDir/app_store_readiness.dart',
    _root,
    '--no-fail',
    '--json',
    jsonPath,
    '--report',
    '$outDir/APP_STORE_READINESS.md',
    if (_ci) '--ci',
    if (lastBuildNumber != null) ...['--last-build-number', lastBuildNumber],
  ]);
  final file = File(jsonPath);
  if (r.exitCode != 0 || !file.existsSync()) {
    _add(
      section,
      'App Store audit',
      Level.fail,
      'The App Store audit could not run, so nothing about iOS was checked: ${_tail('${r.stderr}', 3)}',
      'Run `dart run <skill>/scripts/app_store_readiness.dart .` and fix the error.',
    );
    return;
  }
  final list = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  for (final c in list) {
    if (!_hasAccounts && c['title'] == 'Account deletion') continue;
    _add(
      '$section · ${c['area']}',
      c['title']! as String,
      Level.values.byName(c['status']! as String),
      c['detail']! as String,
      c['fix'] as String?,
    );
  }
}

// --------------------------------------------------------------------- report

void _write(String outDir, bool noFail) {
  int count(Level l) => _items.where((i) => i.level == l).length;
  final fails = count(Level.fail);
  final warns = count(Level.warn);
  final verdict = fails > 0
      ? '❌ NOT READY — $fails blocking item(s) must be fixed before release.'
      : warns > 0
      ? '⚠️ ALMOST READY — no blockers, $warns recommendation(s) left.'
      : '✅ READY — finish the manual store tasks listed below.';
  final name = _profile.name;
  String clean(String? s) => (s ?? '').replaceAll('\n', ' ');

  final b = StringBuffer()
    ..writeln(
      '# Production readiness report — `$name`${_profile.isFlutter ? '' : ' (${_profile.kind.label})'}',
    )
    ..writeln()
    ..writeln(
      'Generated: ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')} · by the flutter-store-ready skill',
    )
    ..writeln()
    ..writeln('## $verdict')
    ..writeln()
    ..writeln(
      '| ❌ Missing (blocking) | ⚠️ Recommended | 📝 Your manual tasks | ✅ Done |',
    )
    ..writeln('|:-:|:-:|:-:|:-:|')
    ..writeln(
      '| **$fails** | **$warns** | **${count(Level.manual)}** | **${count(Level.pass)}** |',
    )
    ..writeln();

  void list(String heading, Level level) {
    final items = _items.where((i) => i.level == level).toList();
    b.writeln('## $heading\n');
    if (items.isEmpty) {
      b.writeln('_Nothing here._\n');
      return;
    }
    for (final (n, i) in items.indexed) {
      b
        ..writeln('${n + 1}. **${i.title}** _(${i.section})_  ')
        ..writeln('   ${clean(i.detail)}');
      if (i.fix != null) b.writeln('   → **Fix:** ${clean(i.fix)}');
    }
    b.writeln();
  }

  list('❌ Missing — must fix before release', Level.fail);
  list('⚠️ Recommended', Level.warn);
  list('📝 Your manual tasks (outside the code)', Level.manual);

  b.writeln('## ✅ Done\n');
  final done = _items.where((i) => i.level == Level.pass).toList();
  if (done.isEmpty) {
    b.writeln('_Nothing yet._');
  }
  for (final i in done) {
    b.writeln('- **${i.title}** _(${i.section})_ — ${clean(i.detail)}');
  }
  b.writeln();

  if (_gates.isNotEmpty) {
    b
      ..writeln('## Quality gates\n')
      ..writeln('| Gate | Result | Summary |')
      ..writeln('|---|---|---|');
    for (final g in _gates) {
      b.writeln('| ${g.name} | ${_label(g.level)} | ${g.summary} |');
    }
    for (final g in _gates.where((g) => g.output != null)) {
      b
        ..writeln(
          '\n<details><summary>${g.name} output (last lines)</summary>\n',
        )
        ..writeln('```')
        ..writeln(g.output)
        ..writeln('```\n</details>');
    }
    b.writeln();
  } else {
    b.writeln('> Quality gates skipped (`--skip-gates`).\n');
  }
  b.writeln(
    '---\nStore details (same folder): `PLAY_READINESS.md` (Google Play), '
    '`APP_STORE_READINESS.md` (App Store).',
  );

  Directory(outDir).createSync(recursive: true);
  final report = File('$outDir/PROJECT_REPORT.md')
    ..writeAsStringSync(b.toString());
  File('$outDir/findings.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'project': name,
      'projectKind': _profile.kind.name,
      'verdict': fails > 0
          ? 'not_ready'
          : (warns > 0 ? 'almost_ready' : 'ready'),
      'counts': {for (final l in Level.values) l.name: count(l)},
      'items': [for (final i in _items) i.toJson()],
    }),
  );

  print('\n$verdict');
  for (final i in _items.where((i) => i.level == Level.fail)) {
    print('  MISSING  ${i.title} (${i.section}): ${clean(i.detail)}');
  }
  print('\nReport: ${report.path}');
  if (fails > 0 && !noFail) exitCode = 1;
}

String _label(Level l) => switch (l) {
  Level.pass => '✅ Pass',
  Level.warn => '⚠️ Warning',
  Level.fail => '❌ Fail',
  Level.manual => '📝 Manual',
};

// ---------------------------------------------------------------------- utils

Map<String, String>? _libCache;
Map<String, String> _libSources() =>
    _libCache ??= collectWorkspaceDartFiles(_root, 'lib');

Map<String, DartSource>? _parsedLibCache;
Map<String, DartSource> _parsedLib() => _parsedLibCache ??= {
  for (final MapEntry(:key, :value) in _libSources().entries)
    key: DartSource.parse(value),
};

ProjectSemantics? _semanticsCache;
ProjectSemantics _semantics() =>
    _semanticsCache ??= ProjectSemantics.analyze(_parsedLib());

String _allCodeOnly() => _parsedLib().values.map((p) => p.codeOnly).join('\n');

Map<String, String>? _testCache;
Map<String, String> _testSources() =>
    _testCache ??= collectWorkspaceDartFiles(_root, 'test');

/// False when the installed Flutter is older or its version is unknown.
bool _flutterAtLeast(int major, int minor) {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final file = File('$root/bin/cache/flutter.version.json');
  if (!file.existsSync()) return false;
  final v = RegExp(
    r'"frameworkVersion":\s*"(\d+)\.(\d+)',
  ).firstMatch(file.readAsStringSync());
  if (v == null) return false;
  final a = int.parse(v.group(1)!);
  final b = int.parse(v.group(2)!);
  return a > major || (a == major && b >= minor);
}

String? _read(String rel) {
  final f = File('$_root/$rel');
  return f.existsSync() ? f.readAsStringSync() : null;
}

String _list(List<String> items, [int max = 8]) =>
    items.take(max).join(', ') +
    (items.length > max ? ' … (+${items.length - max})' : '');

String? _which(String cmd) {
  final r = Process.runSync(Platform.isWindows ? 'where' : 'which', [cmd]);
  if (r.exitCode != 0) return null;
  final p = '${r.stdout}'.trim().split(RegExp(r'\r?\n')).first.trim();
  return p.isEmpty ? null : p;
}

String _tail(String text, int lines) {
  final all = const LineSplitter().convert(text);
  return all.skip(all.length > lines ? all.length - lines : 0).join('\n');
}
