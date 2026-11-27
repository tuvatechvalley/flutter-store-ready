// Zero-dependency structural scanner for Dart source files and multi-package
// workspaces.
//
// Replaces fragile line/window regexes with a single-pass Dart lexer that:
//   1. Masks single-line (`//`) and nested multi-line (`/* ... */`) comments
//      and string contents while keeping `${...}` interpolation expressions
//      intact — so parentheses or keywords inside strings/comments never
//      corrupt call-tree, scope or argument analysis.
//   2. Parses call argument lists (`inspectCall`) to verify `.when(error:)`,
//      `BlocBuilder`/`BlocConsumer` states, and fixed-height `SizedBox` /
//      `Container` subtrees around text accurately.
//   3. Discovers project-defined UI text/dialog wrappers, loading widgets and
//      error widgets across `lib/` and workspace `packages/*/lib/`.

import 'dart:io';

final class CallArg {
  const CallArg({required this.name, required this.start, required this.end});

  final String? name;
  final int start;
  final int end;
}

final class CallNode {
  const CallNode({
    required this.callee,
    required this.openParen,
    required this.closeParen,
    required this.args,
  });

  final String callee;
  final int openParen;
  final int closeParen;
  final List<CallArg> args;

  bool hasNamed(String name) => args.any((a) => a.name == name);

  CallArg? named(String name) {
    for (final a in args) {
      if (a.name == name) return a;
    }
    return null;
  }
}

final class StringSpan {
  const StringSpan(this.start, this.end);

  final int start;
  final int end;
}

final class DartSource {
  DartSource._(this.raw, this.codeOnly, this._commentMask, this.stringLiterals);

  /// Original file text.
  final String raw;

  /// Same length and newlines as [raw], with comments replaced by spaces and
  /// non-interpolated string characters replaced by `_` (quotes preserved).
  final String codeOnly;

  final List<bool> _commentMask;

  /// Non-comment string literal spans in [raw] (for developer-wording checks).
  final List<StringSpan> stringLiterals;

  static DartSource parse(String source) {
    final len = source.length;
    final code = List<int>.filled(len, 0x20);
    final inComment = List<bool>.filled(len, false);
    final strings = <StringSpan>[];

    for (var k = 0; k < len; k++) {
      code[k] = source.codeUnitAt(k);
    }

    void blankComment(int from, int to) {
      for (var k = from; k < to && k < len; k++) {
        inComment[k] = true;
        if (source.codeUnitAt(k) != 0x0A && source.codeUnitAt(k) != 0x0D) {
          code[k] = 0x20;
        }
      }
    }

    void maskChar(int k) {
      if (source.codeUnitAt(k) != 0x0A && source.codeUnitAt(k) != 0x0D) {
        code[k] = 0x5F; // '_'
      }
    }

    // Stack of brace depths for `${ ... }` interpolations: when a `}` closes
    // the interpolation's `0`-depth brace, resume scanning the enclosing string.
    final interpStack = <_InterpState>[];
    var i = 0;

    int scanString(
      int start, {
      required int quote,
      required bool triple,
      required bool isRaw,
    }) {
      final quoteLen = triple ? 3 : 1;
      var p = start + (isRaw ? 1 : 0) + quoteLen;
      while (p < len) {
        final cu = source.codeUnitAt(p);
        if (!isRaw && cu == 0x5C /* \ */ ) {
          if (p + 1 < len) {
            maskChar(p);
            maskChar(p + 1);
            p += 2;
            continue;
          }
        }
        if (triple) {
          if (p + 2 < len &&
              cu == quote &&
              source.codeUnitAt(p + 1) == quote &&
              source.codeUnitAt(p + 2) == quote) {
            strings.add(StringSpan(start, p + 3));
            return p + 3;
          }
        } else {
          if (cu == quote || cu == 0x0A || cu == 0x0D) {
            final end = cu == quote ? p + 1 : p;
            strings.add(StringSpan(start, end));
            return end;
          }
        }
        if (!isRaw && cu == 0x24 /* $ */ && p + 1 < len) {
          final next = source.codeUnitAt(p + 1);
          if (next == 0x7B /* { */ ) {
            // Leave `${` as code (`_(` equivalent: keep `{` so brace depth works)
            code[p] = 0x20;
            interpStack.add(
              _InterpState(
                quote: quote,
                triple: triple,
                stringStart: start,
                braceDepth: 1,
              ),
            );
            return p + 2;
          }
          if (_isIdentStart(next)) {
            // Keep `$ident` visible in codeOnly? No, inside a string `$e` is an
            // expression, so keep `$ident` unmasked in codeOnly? Wait: keeping
            // `$ident` unmasked is safe because identifiers have no brackets!
            var endIdent = p + 2;
            while (endIdent < len &&
                _isIdentPart(source.codeUnitAt(endIdent))) {
              endIdent++;
            }
            p = endIdent;
            continue;
          }
        }
        maskChar(p);
        p++;
      }
      strings.add(StringSpan(start, len));
      return len;
    }

    while (i < len) {
      final cu = source.codeUnitAt(i);
      final next = i + 1 < len ? source.codeUnitAt(i + 1) : -1;

      // Line comment `//`
      if (cu == 0x2F && next == 0x2F) {
        var end = i + 2;
        while (end < len && source.codeUnitAt(end) != 0x0A) {
          end++;
        }
        blankComment(i, end);
        i = end;
        continue;
      }

      // Nested block comment `/* ... */`
      if (cu == 0x2F && next == 0x2A) {
        var depth = 1;
        var end = i + 2;
        while (end < len && depth > 0) {
          final a = source.codeUnitAt(end);
          final b = end + 1 < len ? source.codeUnitAt(end + 1) : -1;
          if (a == 0x2F && b == 0x2A) {
            depth++;
            end += 2;
          } else if (a == 0x2A && b == 0x2F) {
            depth--;
            end += 2;
          } else {
            end++;
          }
        }
        blankComment(i, end);
        i = end;
        continue;
      }

      // Track braces when inside `${ ... }` string interpolation.
      if (interpStack.isNotEmpty) {
        if (cu == 0x7B /* { */ ) {
          interpStack.last.braceDepth++;
          i++;
          continue;
        }
        if (cu == 0x7D /* } */ ) {
          final state = interpStack.last;
          state.braceDepth--;
          if (state.braceDepth == 0) {
            interpStack.removeLast();
            // Resume scanning the rest of the string right after `}`.
            i = _resumeString(
              source,
              code,
              strings,
              interpStack,
              i + 1,
              state,
              maskChar,
            );
            continue;
          }
          i++;
          continue;
        }
      }

      // Raw string `r'...'` or `r"..."`
      if (cu == 0x72 /* r */ && (next == 0x27 || next == 0x22)) {
        final triple =
            i + 3 < len &&
            source.codeUnitAt(i + 2) == next &&
            source.codeUnitAt(i + 3) == next;
        code[i] = 0x20;
        i = scanString(i, quote: next, triple: triple, isRaw: true);
        continue;
      }

      // Normal string `'...'` or `"..."`
      if (cu == 0x27 || cu == 0x22) {
        final triple =
            i + 2 < len &&
            source.codeUnitAt(i + 1) == cu &&
            source.codeUnitAt(i + 2) == cu;
        i = scanString(i, quote: cu, triple: triple, isRaw: false);
        continue;
      }

      i++;
    }

    return DartSource._(source, String.fromCharCodes(code), inComment, strings);
  }

  static int _resumeString(
    String source,
    List<int> code,
    List<StringSpan> strings,
    List<_InterpState> interpStack,
    int from,
    _InterpState state,
    void Function(int) maskChar,
  ) {
    final len = source.length;
    final quote = state.quote;
    var p = from;
    while (p < len) {
      final cu = source.codeUnitAt(p);
      if (cu == 0x5C /* \ */ ) {
        if (p + 1 < len) {
          maskChar(p);
          maskChar(p + 1);
          p += 2;
          continue;
        }
      }
      if (state.triple) {
        if (p + 2 < len &&
            cu == quote &&
            source.codeUnitAt(p + 1) == quote &&
            source.codeUnitAt(p + 2) == quote) {
          strings.add(StringSpan(state.stringStart, p + 3));
          return p + 3;
        }
      } else {
        if (cu == quote || cu == 0x0A || cu == 0x0D) {
          final end = cu == quote ? p + 1 : p;
          strings.add(StringSpan(state.stringStart, end));
          return end;
        }
      }
      if (cu == 0x24 /* $ */ && p + 1 < len) {
        final next = source.codeUnitAt(p + 1);
        if (next == 0x7B /* { */ ) {
          code[p] = 0x20;
          interpStack.add(
            _InterpState(
              quote: quote,
              triple: state.triple,
              stringStart: state.stringStart,
              braceDepth: 1,
            ),
          );
          return p + 2;
        }
        if (_isIdentStart(next)) {
          var endIdent = p + 2;
          while (endIdent < len && _isIdentPart(source.codeUnitAt(endIdent))) {
            endIdent++;
          }
          p = endIdent;
          continue;
        }
      }
      maskChar(p);
      p++;
    }
    strings.add(StringSpan(state.stringStart, len));
    return len;
  }

  static bool _isIdentStart(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;

  static bool _isIdentPart(int c) =>
      _isIdentStart(c) || (c >= 0x30 && c <= 0x39);

  bool isInComment(int offset) =>
      offset >= 0 && offset < _commentMask.length && _commentMask[offset];

  /// True when the line (or immediately preceding comment line) carries
  /// `forbidden:allow`.
  bool isAllowed(int offset) {
    if (isInComment(offset)) return true;
    final start = raw.lastIndexOf('\n', offset > 0 ? offset - 1 : 0) + 1;
    final end = raw.indexOf('\n', offset);
    final line = raw.substring(start, end < 0 ? raw.length : end);
    if (line.contains('forbidden:allow')) return true;
    if (start > 1) {
      final prevStart = raw.lastIndexOf('\n', start - 2) + 1;
      final prevLine = raw.substring(prevStart, start - 1);
      if (prevLine.contains('forbidden:allow')) return true;
    }
    return false;
  }

  int lineOf(int offset) =>
      '\n'.allMatches(raw.substring(0, offset.clamp(0, raw.length))).length + 1;

  /// Enclosing call names around [offset], innermost first, walked over
  /// comment/string-masked [codeOnly].
  List<String> enclosingCalls(int offset, [int max = 8]) {
    final calls = <String>[];
    var depth = 0;
    for (
      var i = offset - 1;
      i >= 0 && calls.length < max && offset - i < 4000;
      i--
    ) {
      final c = codeOnly[i];
      if (c == ')' || c == ']' || c == '}') {
        depth++;
      } else if (c == '(' || c == '[' || c == '{') {
        if (depth > 0) {
          depth--;
          continue;
        }
        if (c == '(') {
          final before = codeOnly.substring((i - 100).clamp(0, i), i);
          final m = RegExp(
            r'([\w.]+)\s*(?:<[\w\s,<>?]*>)?\s*$',
          ).firstMatch(before);
          if (m != null) calls.add(m.group(1)!.split('.').last);
        }
      }
    }
    return calls;
  }

  /// Inspects a call whose `(` is at [openParen] and extracts its top-level
  /// positional and named arguments.
  CallNode? inspectCallAt(int openParen, {String callee = ''}) {
    if (openParen < 0 ||
        openParen >= codeOnly.length ||
        codeOnly[openParen] != '(') {
      return null;
    }
    final args = <CallArg>[];
    var depth = 1;
    var argStart = openParen + 1;
    var i = openParen + 1;
    while (i < codeOnly.length && depth > 0) {
      final c = codeOnly[i];
      if (c == '(' || c == '[' || c == '{') {
        depth++;
      } else if (c == ')' || c == ']' || c == '}') {
        depth--;
        if (depth == 0) {
          _pushArg(args, argStart, i);
          return CallNode(
            callee: callee,
            openParen: openParen,
            closeParen: i,
            args: args,
          );
        }
      } else if (c == ',' && depth == 1) {
        _pushArg(args, argStart, i);
        argStart = i + 1;
      }
      i++;
    }
    return null;
  }

  void _pushArg(List<CallArg> into, int start, int end) {
    final slice = codeOnly.substring(start, end);
    if (slice.trim().isEmpty) return;
    final m = RegExp(r'^\s*(\w+)\s*:(?!=)').firstMatch(slice);
    into.add(CallArg(name: m?.group(1), start: start, end: end));
  }

  static const _builtInUiCalls = {
    'Text',
    'SelectableText',
    'RichText',
    'TextSpan',
    'SnackBar',
    'AlertDialog',
    'SimpleDialog',
    'CupertinoAlertDialog',
    'showDialog',
    'showAdaptiveDialog',
    'showCupertinoDialog',
    'showGeneralDialog',
    'showModalBottomSheet',
    'Tooltip',
    'MaterialBanner',
    'showSnackBar',
    'showToast',
    'show',
    'zonedSchedule',
  };

  static const _builtInUiLabels = {
    'errorText',
    'content',
    'title',
    'message',
    'subtitle',
    'label',
    'helperText',
    'text',
    'body',
    'semanticsLabel',
  };

  static final _exceptionConstructor = RegExp(
    r'^[A-Z]\w*(?:Exception|Error|Failure)$',
  );

  static final _nonUiSink = RegExp(
    r'log|print|report|capture|sentry|crashlytics|assert|debug|trace|recordError',
    caseSensitive: false,
  );

  /// Structural version of user-visible expression detection: walks [codeOnly]
  /// brackets and recognizes both built-in widgets and project-defined UI
  /// wrappers discovered by [ProjectSemantics].
  bool shownToUser(int offset, {Set<String> customUiCalls = const {}}) {
    final calls = <String>[];
    final labels = <String>[];
    var depth = 0;
    var argumentStartSeen = false;
    for (
      var i = offset - 1;
      i >= 0 && calls.length < 6 && offset - i < 2000;
      i--
    ) {
      final c = codeOnly[i];
      if (c == ')' || c == ']' || c == '}') {
        depth++;
        continue;
      }
      final opens = c == '(' || c == '[' || c == '{';
      if (depth == 0 && !argumentStartSeen && (c == ',' || opens)) {
        argumentStartSeen = true;
        final label = RegExp(
          r'^\s*(\w+)\s*:',
        ).firstMatch(codeOnly.substring(i + 1, offset))?.group(1);
        if (label != null) labels.add(label);
      }
      if (!opens) continue;
      if (depth > 0) {
        depth--;
        continue;
      }
      final before = codeOnly.substring((i - 100).clamp(0, i), i);
      final m = RegExp(
        r'(?:(\w+)\s*:\s*)?(?:const\s+|new\s+)?([\w.]*)\s*(?:<[\w\s,<>?]*>)?\s*$',
      ).firstMatch(before);
      if (m?.group(1) case final label?) labels.add(label);
      final callee = (m?.group(2) ?? '').split('.').last;
      if (callee.isNotEmpty) calls.add(callee);
      argumentStartSeen = false;
    }
    for (final call in calls) {
      if (_exceptionConstructor.hasMatch(call)) return false;
      final lower = call.toLowerCase();
      if (!_builtInUiCalls.contains(call) &&
          !customUiCalls.contains(call) &&
          !lower.endsWith('dialog') &&
          !lower.endsWith('catalog') &&
          _nonUiSink.hasMatch(call)) {
        return false;
      }
    }
    return calls.any(
          (c) => _builtInUiCalls.contains(c) || customUiCalls.contains(c),
        ) ||
        labels.any(_builtInUiLabels.contains);
  }

  /// True when [name] is bound by an enclosing `catch`, `catchError`,
  /// `onError:`, `error:` or `errorBuilder:` handler over [codeOnly].
  bool boundAsError(int offset, String name) {
    final before = codeOnly.substring((offset - 4000).clamp(0, offset), offset);
    final binding = RegExp(
      '(?:catch|catchError|onError\\s*:|error\\s*:|errorBuilder\\s*:)'
      '\\s*\\(+[^)]*\\b${RegExp.escape(name)}\\b[^)]*\\)',
    );
    for (final m in binding.allMatches(before).toList().reversed) {
      final rest = before.substring(m.end);
      if (RegExp(r'^\s*=>').hasMatch(rest)) {
        // Expression body (`error: (e, _) => ...`): ends at `;` or `,` at
        // depth 0.
        var depth = 0;
        var ended = false;
        for (var i = 0; i < rest.length; i++) {
          final c = rest[i];
          if (c == '(' || c == '[' || c == '{') {
            depth++;
          } else if (c == ')' || c == ']' || c == '}') {
            if (depth == 0) {
              ended = true;
              break;
            }
            depth--;
          } else if (depth == 0 && (c == ';' || c == ',')) {
            ended = true;
            break;
          }
        }
        if (!ended) return true;
        continue;
      }
      var depth = 0;
      var opened = false;
      var closed = false;
      for (var i = 0; i < rest.length && !closed; i++) {
        if (rest[i] == '{') {
          depth++;
          opened = true;
        } else if (rest[i] == '}') {
          depth--;
          closed = opened && depth == 0;
        }
      }
      if (opened && !closed) return true;
    }
    return false;
  }
}

final class _InterpState {
  _InterpState({
    required this.quote,
    required this.triple,
    required this.stringStart,
    required this.braceDepth,
  });

  final int quote;
  final bool triple;
  final int stringStart;
  int braceDepth;
}

/// Project-wide semantic symbols discovered across all workspace packages.
final class ProjectSemantics {
  const ProjectSemantics({
    required this.customUiCalls,
    required this.customLoadingWidgets,
    required this.customErrorWidgets,
  });

  /// Project helper functions or wrapper widgets that forward text to screen
  /// (e.g. `AppText(...)`, `showAppSnackBar(context, msg)`).
  final Set<String> customUiCalls;

  /// Project widgets that wrap a progress/skeleton indicator.
  final Set<String> customLoadingWidgets;

  /// Project widgets that wrap an error/retry state.
  final Set<String> customErrorWidgets;

  static ProjectSemantics analyze(Map<String, DartSource> sources) {
    final uiCalls = <String>{};
    final loadingWidgets = <String>{};
    final errorWidgets = <String>{};

    final widgetClass = RegExp(
      r'class\s+([A-Z]\w*)\s+extends\s+(?:Stateless|Stateful|Consumer|ConsumerStateful|Hook|HookConsumer)Widget\b',
    );
    final helperFn = RegExp(
      r'(?:Future<[^>]+>|void|Widget)\s+([a-z]\w*)\s*\(([^)]{0,240})\)',
    );
    final rendersText = RegExp(
      r'\b(?:Text|SelectableText|RichText|SnackBar|AlertDialog|CupertinoAlertDialog|showSnackBar|showDialog|MaterialBanner)\s*\(',
    );
    final rendersLoading = RegExp(
      r'\b(?:CircularProgressIndicator|LinearProgressIndicator|CupertinoActivityIndicator|Shimmer|Skeleton)\b',
    );
    final rendersError = RegExp(
      r'\b(?:onRetry|tryAgain|tekrarDene|Icons\.error|Icons\.warning|ErrorView)\b|[Rr]etry|[Tt]ry again|[Tt]ekrar [Dd]ene',
    );

    for (final src in sources.values) {
      final code = src.codeOnly;
      for (final m in widgetClass.allMatches(code)) {
        final name = m.group(1)!;
        if (name.endsWith('Page') || name.endsWith('Screen')) continue;
        final bodyEnd = _classBodyEnd(code, m.end);
        final body = src.raw.substring(m.start, bodyEnd);
        if (RegExp(
              r'Text|Banner|Toast|Alert|Dialog|Chip|Badge',
            ).hasMatch(name) &&
            rendersText.hasMatch(body)) {
          uiCalls.add(name);
        }
        if (rendersLoading.hasMatch(body)) {
          loadingWidgets.add(name);
        }
        if (rendersError.hasMatch(body)) {
          errorWidgets.add(name);
        }
      }
      for (final m in helperFn.allMatches(code)) {
        final fnName = m.group(1)!;
        final params = m.group(2)!;
        if (DartSource._nonUiSink.hasMatch(fnName)) continue;
        if (!RegExp(r'\bString\??\s+\w+').hasMatch(params)) continue;
        final bodyEnd = _statementOrBlockEnd(code, m.end);
        final body = code.substring(m.end, bodyEnd);
        if (rendersText.hasMatch(body)) {
          uiCalls.add(fnName);
        }
      }
    }

    return ProjectSemantics(
      customUiCalls: uiCalls,
      customLoadingWidgets: loadingWidgets,
      customErrorWidgets: errorWidgets,
    );
  }

  static int _classBodyEnd(String code, int from) {
    final open = code.indexOf('{', from);
    if (open < 0) return from;
    var depth = 1;
    for (var i = open + 1; i < code.length; i++) {
      if (code[i] == '{') {
        depth++;
      } else if (code[i] == '}') {
        depth--;
        if (depth == 0) return i + 1;
      }
    }
    return code.length;
  }

  static int _statementOrBlockEnd(String code, int from) {
    var i = from;
    while (i < code.length &&
        (code[i] == ' ' || code[i] == '\n' || code[i] == '\r')) {
      i++;
    }
    if (i < code.length && code.startsWith('async', i)) {
      i += 5;
      while (i < code.length && (code[i] == ' ' || code[i] == '*')) {
        i++;
      }
    }
    if (i < code.length && code[i] == '{') {
      return _classBodyEnd(code, i);
    }
    var depth = 0;
    for (; i < code.length; i++) {
      final c = code[i];
      if (c == '(' || c == '[' || c == '{') {
        depth++;
      } else if (c == ')' || c == ']' || c == '}') {
        if (depth > 0) depth--;
      } else if (c == ';' && depth == 0) {
        return i + 1;
      }
    }
    return code.length;
  }
}

/// Discovers local workspace package directories (`packages/*`, `modules/*` or
/// Dart `workspace:` entries in `pubspec.yaml`), skipping vendored/third-party
/// folders.
List<String> workspacePackageDirs(String root) {
  final dirs = <String>{};
  final rootPubspec = File('$root/pubspec.yaml');
  if (rootPubspec.existsSync()) {
    final text = rootPubspec.readAsStringSync().replaceAll('\r\n', '\n');
    final ws = RegExp(
      r'^workspace:\s*\n((?:[ \t]+-[ \t]*[^\n]+\n?)+)',
      multiLine: true,
    ).firstMatch(text)?.group(1);
    if (ws != null) {
      for (final m in RegExp(
        r'^\s*-\s*(\S+)',
        multiLine: true,
      ).allMatches(ws)) {
        final rel = m.group(1)!.replaceAll('"', '').replaceAll("'", '');
        if (File('$root/$rel/pubspec.yaml').existsSync()) {
          dirs.add(rel);
        }
      }
    }
  }
  for (final container in ['packages', 'modules']) {
    final d = Directory('$root/$container');
    if (!d.existsSync()) continue;
    for (final sub in d.listSync().whereType<Directory>()) {
      final name = sub.path.split(RegExp(r'[\\/]')).last;
      if (name.startsWith('.') ||
          name == 'third_party' ||
          name == 'vendor' ||
          name == 'build') {
        continue;
      }
      if (File('${sub.path}/pubspec.yaml').existsSync()) {
        dirs.add('$container/$name');
      }
    }
  }
  final sorted = dirs.toList()..sort();
  return sorted;
}

/// Combined `pubspec.yaml` text across the root app and any local workspace
/// packages, so shared dependencies (`flutter_secure_storage`, `dio`, `sentry`)
/// declared in `packages/core/pubspec.yaml` are recognized.
String combinedWorkspacePubspec(String root) {
  final buf = StringBuffer();
  final rootFile = File('$root/pubspec.yaml');
  if (rootFile.existsSync()) buf.writeln(rootFile.readAsStringSync());
  for (final pkg in workspacePackageDirs(root)) {
    final f = File('$root/$pkg/pubspec.yaml');
    if (f.existsSync()) buf.writeln(f.readAsStringSync());
  }
  return buf.toString();
}

/// Reads all non-generated `.dart` files in [subdir] (`lib` or `test`) across
/// the root project and any local monorepo workspace packages.
Map<String, String> collectWorkspaceDartFiles(String root, String subdir) {
  final result = <String, String>{};
  final roots = ['', ...workspacePackageDirs(root)];
  for (final prefix in roots) {
    final relBase = prefix.isEmpty ? subdir : '$prefix/$subdir';
    final d = Directory('$root/$relBase');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (RegExp(r'\.(g|freezed|gr|mocks|config)\.dart$').hasMatch(f.path)) {
        continue;
      }
      final rel = f.path.substring(root.length + 1).replaceAll(r'\', '/');
      if (rel.contains('/third_party/') || rel.contains('/vendor/')) continue;
      result[rel] = f.readAsStringSync();
    }
  }
  return result;
}
