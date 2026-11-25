/// Removes secrets and personal data from text before it is logged or sent
/// to crash reporting. Logs end up in device logs, CI output and third-party
/// dashboards — treat them as public.
abstract final class Redactor {
  static const String mask = '[REDACTED]';

  static final List<(RegExp, String Function(Match))> _rules = [
    // Authorization: Bearer <token>
    (
      RegExp(r'(bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      (m) => '${m[1]}$mask',
    ),
    // JWTs anywhere in text
    (
      RegExp(r'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}'),
      (_) => mask,
    ),
    // "password": "...", "token": "...", api_key=..., secret=...
    (
      RegExp(
        r'''(["']?(?:password|passwd|pwd|token|access_token|refresh_token|api[_-]?key|secret|authorization|cookie|session)["']?\s*[:=]\s*)(["']?)[^"',&\s}]+\2''',
        caseSensitive: false,
      ),
      (m) => '${m[1]}${m[2]}$mask${m[2]}',
    ),
    // E-mail addresses
    (
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      (_) => '[EMAIL]',
    ),
    // Card-like numbers (13–19 digits, optional spaces/dashes): keep last 4.
    (RegExp(r'\b(?:\d[ -]?){9,15}(\d{4})\b'), (m) => '[CARD ****${m[1]}]'),
  ];

  static String redact(String input) {
    var output = input;
    for (final (pattern, replace) in _rules) {
      output = output.replaceAllMapped(pattern, replace);
    }
    return output;
  }

  /// Keeps only scheme, host, port and path. Query strings, fragments and
  /// user-info often carry tokens or personal data.
  static String redactUrl(Uri uri) {
    if (!uri.hasAuthority) return uri.path;
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port${uri.path}';
  }
}
