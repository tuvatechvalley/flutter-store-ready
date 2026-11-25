// Production-readiness report for ANY Flutter app: "what is done, what is
// missing".
//
//   dart run <skill>/scripts/project_report.dart [project_dir]
//        [--out <dir>] [--skip-gates] [--gates-passed] [--skip-play] [--no-fail]
//
// Checks quality gates (format, analyze, forbidden patterns, tests), global
// error handling, security, responsive & large-text support, store-required
// features, production config, leftovers from `flutter create`, code health,
// iOS settings and the full Google Play audit. Writes:
//
//   <out>/PROJECT_REPORT.md   (default out: <project>/build/reports/flutter-production)
//   <out>/findings.json       (machine-readable, same items)
//
// Exit code 1 when anything is blocking (unless --no-fail).
// Only dart:io: runs on Windows, macOS and Linux without `pub get`.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

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
late final String _pubspec;

const _sGates = 'Quality gates';
const _sErrors = 'Error handling';
const _sSecurity = 'Security';
const _sUi = 'Responsive & large text';
const _sStore = 'Store requirements';
const _sConfig = 'Production config';
const _sLeftovers = 'Template leftovers';
const _sCode = 'Code health';
const _sIos = 'iOS';

Future<void> main(List<String> args) async {
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final valueFlags = {'--out', '--last-version-code'};
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

  final pubspecFile = File('$_root/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('No pubspec.yaml in $_root: not a Flutter project.');
    exitCode = 2;
    return;
  }
  _pubspec = pubspecFile.readAsStringSync();
  final outDir = opt('--out') ?? '$_root/build/reports/flutter-production';

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
  _checkSecurity();
  _checkResponsive();
  _checkStoreRequirements();
  _checkProductionConfig();
  _checkLeftovers();
  _checkCodeHealth();
  _checkIos();
  if (!args.contains('--skip-play')) {
    await _runPlayAudit(outDir, opt('--last-version-code'));
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
    String Function(String out, bool ok)? summarize,
  }) async {
    final r = await Process.run(
      exe,
      args,
      workingDirectory: _root,
      runInShell: Platform.isWindows,
    );
    final out = '${r.stdout}\n${r.stderr}'.trim();
    final ok = r.exitCode == 0;
    _gates.add(
      GateResult(
        name,
        ok ? Level.pass : Level.fail,
        summarize?.call(out, ok) ??
            (ok ? 'Passed' : 'Failed (exit code ${r.exitCode})'),
        ok ? null : _tail(out, 25),
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
    summarize: (out, ok) =>
        ok ? 'All files formatted' : 'Unformatted files: run `dart format .`',
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
    summarize: (out, ok) => ok
        ? 'None found'
        : '${RegExp(r'(\d+) forbidden').firstMatch(out)?.group(1) ?? 'Some'} found',
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
          final m = RegExp(r'\+(\d+)(?: ~(\d+))?(?: -(\d+))?:')
              .allMatches(out)
              .toList();
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
      g.level == Level.fail ? 'See "Quality gates" output below.' : null,
    );
  }
}

// ------------------------------------------------------------ error handling

void _checkErrorHandling() {
  final all = _libSources().values.join('\n');
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
    flutterError && asyncErrors ? null : 'Add a bootstrap() like templates/starter_app/lib/bootstrap.dart (ERROR-HANDLING.md).',
  );

  final errorWidget = all.contains('ErrorWidget.builder');
  _add(
    _sErrors,
    'Friendly build-error widget',
    errorWidget ? Level.pass : Level.warn,
    errorWidget ? 'ErrorWidget.builder is customized.' : 'A widget that throws shows a grey box (release) or red screen (debug).',
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
    crash ? 'A crash reporting SDK is installed.' : 'No crash reporting: you will not know when the app crashes for users.',
    crash ? null : 'Add sentry_flutter or firebase_crashlytics.',
  );

  final rawErrors = <String>[];
  final unhandledBuilders = <String>[];
  final whenWithoutError = <String>[];
  for (final MapEntry(key: path, value: src) in _libSources().entries) {
    for (final m in RegExp(
      // Text(e.toString()), Text('$error'), Text('Failed: ${snapshot.error}')
      r'''Text\(\s*(?:(?:e|err|error|exception|ex|failure|\w+\.error)\.toString\(\)|['"][^'"\n]*\$\{?(?:e|err|error|exception|ex|\w+\.error|\w+\.message)\}?)''',
    ).allMatches(src)) {
      rawErrors.add('$path:${_line(src, m.start)}');
    }
    if ((src.contains('FutureBuilder') || src.contains('StreamBuilder')) &&
        !src.contains('hasError')) {
      unhandledBuilders.add(path);
    }
    for (final m in RegExp(r'\.when\(').allMatches(src)) {
      final window = src.substring(
        m.start,
        (m.start + 1500).clamp(0, src.length),
      );
      if (!window.contains('error:')) {
        whenWithoutError.add('$path:${_line(src, m.start)}');
      }
    }
  }
  _add(
    _sErrors,
    'No raw error text shown to users',
    rawErrors.isEmpty ? Level.pass : Level.warn,
    rawErrors.isEmpty
        ? 'No `Text(error.toString())` style messages found.'
        : 'Raw exception text in the UI (can leak URLs/tokens, confuses users): ${_list(rawErrors)}',
    rawErrors.isEmpty ? null : 'Map errors to typed failures and show a localized message (ERROR-HANDLING.md).',
  );
  _add(
    _sErrors,
    'Loading / error / empty states',
    unhandledBuilders.isEmpty && whenWithoutError.isEmpty
        ? Level.pass
        : Level.warn,
    unhandledBuilders.isEmpty && whenWithoutError.isEmpty
        ? 'Async widgets handle the error state.'
        : 'Error state not handled: ${_list([...unhandledBuilders.map((p) => '$p (FutureBuilder/StreamBuilder without hasError)'), ...whenWithoutError])}',
    unhandledBuilders.isEmpty && whenWithoutError.isEmpty ? null : 'Every data screen needs loading, error + retry, empty and data states.',
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
    _add(
      _sSecurity,
      'Secure token storage',
      secure || firebaseOnly ? Level.pass : Level.warn,
      secure
          ? 'flutter_secure_storage (Keychain / Keystore) is used.'
          : firebaseOnly
          ? 'Firebase Auth manages its own tokens.'
          : 'The app handles sign-in but has no secure storage dependency: tokens may end up in plain files/SharedPreferences.',
      secure || firebaseOnly
          ? null
          : 'Store tokens only with flutter_secure_storage (SECURITY.md).',
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
      pinning ? 'TLS certificate / public-key pinning is implemented.' : 'No certificate pinning: a malicious Wi-Fi or installed CA can read API traffic.',
      pinning ? null : 'Add SPKI pinning with a backup pin (templates/starter_app/lib/core/network/certificate_pinner.dart).',
    );
    final timeouts = RegExp(r'connectTimeout|receiveTimeout|\.timeout\(')
        .hasMatch(all);
    _add(
      _sSecurity,
      'Network timeouts',
      timeouts ? Level.pass : Level.warn,
      timeouts ? 'Requests have timeouts.' : 'No request timeouts found: a dead network can hang screens forever.',
      timeouts ? null : 'Set connect/receive timeouts on the HTTP client.',
    );
  }

  final logging = RegExp(r'\bprint\(|debugPrint\(').allMatches(all).length;
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
  for (final MapEntry(key: path, value: src) in _libSources().entries) {
    for (final m in RegExp(
      r'class (\w+(?:Page|Screen|View)) extends (?:Stateless|Stateful|Consumer|ConsumerStateful|Hook|HookConsumer)Widget',
    ).allMatches(src)) {
      final name = m.group(1)!;
      // *View only counts in a screens/pages/views folder (EmptyView etc.
      // are widgets, not screens).
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
      untested.isEmpty ? null : 'Add them to a responsive matrix test (5 sizes × 100–300% text × locales), see RESPONSIVE-AND-LARGE-TEXT.md.',
    );
  }

  final largeTextTest = RegExp(
    r'textScaleFactorTestValue|TextScaler\.linear\(\s*[2-3]',
  ).hasMatch(tests);
  _add(
    _sUi,
    'Large-text test (200–300%)',
    largeTextTest ? Level.pass : Level.warn,
    largeTextTest ? 'Tests render screens with enlarged text.' : 'No test renders the app with enlarged text, so overflow at 200% font size goes unnoticed.',
    largeTextTest ? null : 'Copy templates/starter_app/test/responsive_test.dart and large_text_test.dart.',
  );

  final locked = <String>[];
  final fixedHeights = <String>[];
  var usesSafeArea = false;
  var adaptive = false;
  for (final MapEntry(key: path, value: src) in _libSources().entries) {
    usesSafeArea |= src.contains('SafeArea');
    adaptive |= RegExp(
      r'LayoutBuilder|MediaQuery\.sizeOf|MediaQuery\.of\(context\)\.size|WindowSize|NavigationRail|breakpoint',
      caseSensitive: false,
    ).hasMatch(src);
    final lines = src.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.trimLeft().startsWith('//')) continue;
      if (l.contains('TextScaler.noScaling') ||
          RegExp(r'textScaleFactor\s*:\s*1(\.0)?\b').hasMatch(l)) {
        locked.add('$path:${i + 1}');
      }
      final clamp = RegExp(r'maxScaleFactor:\s*([0-9.]+)')
          .firstMatch(l)
          ?.group(1);
      final context = lines
          .sublist((i - 6).clamp(0, lines.length), i + 1)
          .join(' ');
      if (clamp != null &&
          (double.tryParse(clamp) ?? 3) < 2 &&
          !RegExp(
            r'Navigation|Rail|AppBar|TabBar|BottomBar|chrome',
            caseSensitive: false,
          ).hasMatch(context)) {
        locked.add('$path:${i + 1} (capped at ${clamp}x)');
      }
    }
    for (final m in RegExp(
      r'SizedBox\(\s*height:\s*\d+[^)]{0,80}?child:\s*(?:const\s+)?Text\(',
    ).allMatches(src)) {
      fixedHeights.add('$path:${_line(src, m.start)}');
    }
  }
  _add(
    _sUi,
    'Text follows the phone\'s font size',
    locked.isEmpty ? Level.pass : Level.fail,
    locked.isEmpty
        ? 'Text size is never locked or capped below 2x.'
        : 'Text size locked/capped at ${_list(locked)}: users who enlarge text to 200% will not see it bigger.',
    locked.isEmpty ? null : 'Remove TextScaler.noScaling / textScaleFactor: 1 and caps below 2x (only navigation bars may be capped).',
  );
  _add(
    _sUi,
    'No fixed heights around text',
    fixedHeights.isEmpty ? Level.pass : Level.warn,
    fixedHeights.isEmpty
        ? 'No fixed-height boxes around text found.'
        : 'Text in a fixed height is cut off with large text: ${_list(fixedHeights)}',
    fixedHeights.isEmpty ? null : 'Drop the height or compute it with MediaQuery.textScalerOf(context).scale(x).',
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
    adaptive ? 'Layouts react to the available size.' : 'No size-based layout found: tablets and landscape show a stretched phone UI.',
    adaptive ? null : 'Use width breakpoints (compact/medium/expanded) divided by text scale (RESPONSIVE-AND-LARGE-TEXT.md).',
  );
}

// ------------------------------------------------------- store requirements

void _checkStoreRequirements() {
  final all = _libSources().values.join('\n');
  final hasAccounts = RegExp(
    r'signUp|register\(|createUserWithEmailAndPassword|signIn|login\(|logIn\(',
  ).hasMatch(all);
  if (hasAccounts) {
    final deletion = RegExp(
      r'deleteAccount|delete_account|deleteUser|user\.delete\(|currentUser\?\.delete\(|removeAccount',
    ).hasMatch(all);
    _add(
      _sStore,
      'In-app account deletion',
      deletion ? Level.pass : Level.fail,
      deletion ? 'Users can delete their account in the app.' : 'The app has accounts but no account deletion (required by Google Play and the App Store).',
      deletion ? null : 'Add "Delete account" in settings: backend call + wipe local data; also publish a web deletion URL.',
    );
  }
  final privacy = RegExp(
    r'privacy[ _-]?policy|privacyPolicy|gizlilik politika',
    caseSensitive: false,
  ).hasMatch(all);
  _add(
    _sStore,
    'Privacy policy link in the app',
    privacy ? Level.pass : Level.warn,
    privacy ? 'Found.' : 'No privacy policy link inside the app.',
    privacy ? null : 'Add a "Privacy policy" item in settings that opens your public policy URL (url_launcher).',
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
      template.existsSync() ? Level.fail : Level.warn,
      'No production configuration file.',
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
  if (_pubspec.contains('description: "A new Flutter project."') ||
      _pubspec.contains(
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

  final oldMaterial = _libSources().entries
      .where((e) => e.value.contains('package:flutter/material.dart'))
      .map((e) => e.key)
      .toList();
  if (oldMaterial.isNotEmpty) {
    _add(
      _sCode,
      'Deprecated Material import',
      Level.warn,
      'package:flutter/material.dart is deprecated since Flutter 3.47 (${oldMaterial.length} file(s)).',
      'Run `flutter pub add material_ui` and `dart fix --apply` (on Flutter >= 3.47).',
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
    strict ? 'Strict analyzer settings enabled.' : 'Only default lints: many crash-prone patterns (dynamic calls, unawaited futures) go unnoticed.',
    strict ? null : 'Use templates/starter_app/analysis_options.yaml (strict-casts, unawaited_futures as error...).',
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

// ------------------------------------------------------------------------ iOS

void _checkIos() {
  final plist = _read('ios/Runner/Info.plist');
  if (plist == null) return;
  if (RegExp(r'<key>NSAllowsArbitraryLoads</key>\s*<true\s*/>')
      .hasMatch(plist)) {
    _add(
      _sIos,
      'App Transport Security',
      Level.fail,
      'NSAllowsArbitraryLoads = true allows plain HTTP.',
      'Remove it from Info.plist.',
    );
  }
  final encryption = plist.contains('ITSAppUsesNonExemptEncryption');
  _add(
    _sIos,
    'Export compliance key',
    encryption ? Level.pass : Level.warn,
    encryption ? 'ITSAppUsesNonExemptEncryption set.' : 'Missing: App Store Connect asks the export-compliance question on every upload.',
    encryption ? null : 'Add ITSAppUsesNonExemptEncryption (false if you only use HTTPS / OS crypto).',
  );
  final manifest = File('$_root/ios/Runner/PrivacyInfo.xcprivacy').existsSync();
  _add(
    _sIos,
    'Privacy manifest',
    manifest ? Level.pass : Level.warn,
    manifest ? 'PrivacyInfo.xcprivacy present.' : 'No app privacy manifest (App Store requires declaring "required reason" APIs).',
    manifest ? null : 'Add ios/Runner/PrivacyInfo.xcprivacy in Xcode (File > New > App Privacy).',
  );
  final usageKeys = {
    'CAMERA': 'NSCameraUsageDescription',
    'image_picker': 'NSPhotoLibraryUsageDescription',
    'geolocator': 'NSLocationWhenInUseUsageDescription',
    'location': 'NSLocationWhenInUseUsageDescription',
    'record': 'NSMicrophoneUsageDescription',
    'local_auth': 'NSFaceIDUsageDescription',
    'contacts_service': 'NSContactsUsageDescription',
  };
  final missing = <String>[];
  for (final MapEntry(key: pkg, value: key) in usageKeys.entries) {
    if (RegExp('^\\s+$pkg:', multiLine: true).hasMatch(_pubspec) &&
        !plist.contains(key)) {
      missing.add('$key (for $pkg)');
    }
  }
  if (missing.isNotEmpty) {
    _add(
      _sIos,
      'Permission usage descriptions',
      Level.fail,
      'Missing in Info.plist: ${missing.join(', ')}. The app crashes when asking for the permission and App Review rejects it.',
      'Add the keys with a clear, user-facing reason.',
    );
  }
}

// ----------------------------------------------------------------- play audit

Future<void> _runPlayAudit(String outDir, String? lastVersionCode) async {
  final hasAndroid = Directory('$_root/android').existsSync();
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
    if (lastVersionCode != null) ...['--last-version-code', lastVersionCode],
  ]);
  final file = File(jsonPath);
  if (r.exitCode != 0 || !file.existsSync()) {
    _add(
      'Google Play',
      'Play audit',
      Level.warn,
      'The Google Play audit could not run: ${_tail('${r.stderr}', 3)}',
    );
    return;
  }
  if (!hasAndroid) {
    _add(
      'Google Play',
      'Android project',
      Level.fail,
      'android/ does not exist.',
      'Run `flutter create --platforms=android,ios .` then scripts/harden_platforms.dart.',
    );
  }
  final list = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, Object?>>();
  for (final c in list) {
    _add(
      'Google Play · ${c['area']}',
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
  final name =
      RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(_pubspec)?.group(1) ??
      _root.split(RegExp(r'[\\/]')).last;
  String clean(String? s) => (s ?? '').replaceAll('\n', ' ');

  final b = StringBuffer()
    ..writeln('# Production readiness report — `$name`')
    ..writeln()
    ..writeln(
      'Generated: ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')} · by the flutter-production skill',
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
  b.writeln('---\nGoogle Play details: `PLAY_READINESS.md` (same folder).');

  Directory(outDir).createSync(recursive: true);
  final report = File('$outDir/PROJECT_REPORT.md')
    ..writeAsStringSync(b.toString());
  File('$outDir/findings.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'project': name,
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
Map<String, String> _libSources() => _libCache ??= _sources('lib');

Map<String, String>? _testCache;
Map<String, String> _testSources() => _testCache ??= _sources('test');

Map<String, String> _sources(String dir) {
  final d = Directory('$_root/$dir');
  if (!d.existsSync()) return const {};
  final result = <String, String>{};
  for (final f in d.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    if (RegExp(r'\.(g|freezed|gr|mocks)\.dart$').hasMatch(f.path)) continue;
    final rel = f.path.substring(_root.length + 1).replaceAll(r'\', '/');
    result[rel] = f.readAsStringSync();
  }
  return result;
}

String? _read(String rel) {
  final f = File('$_root/$rel');
  return f.existsSync() ? f.readAsStringSync() : null;
}

int _line(String src, int offset) =>
    '\n'.allMatches(src.substring(0, offset)).length + 1;

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
