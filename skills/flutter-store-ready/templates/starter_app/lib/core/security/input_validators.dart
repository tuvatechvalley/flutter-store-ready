/// Client-side validation is for UX only. The server MUST validate again:
/// anything running on the device can be bypassed.
enum ValidationError {
  required,
  invalidEmail,
  tooShort,
  tooLong,
  weakPassword,
  invalidCharacters,
}

abstract final class InputValidators {
  static const int maxEmailLength = 254;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxFreeTextLength = 500;

  static final RegExp _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  /// C0/C1 control characters and zero-width/bidi override characters that
  /// can be used for spoofing (e.g. "Trojan Source" style text).
  static final RegExp _unsafeChars = RegExp(
    '[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F'
    '\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );

  /// Trims and strips invisible/control characters from user text.
  static String sanitize(String input) =>
      input.replaceAll(_unsafeChars, '').trim();

  static ValidationError? email(String? value) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return ValidationError.required;
    if (v.length > maxEmailLength) return ValidationError.tooLong;
    if (!_email.hasMatch(v)) return ValidationError.invalidEmail;
    return null;
  }

  /// Passwords are NOT trimmed or sanitized: spaces can be intentional.
  static ValidationError? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return ValidationError.required;
    if (v.length < minPasswordLength) return ValidationError.tooShort;
    if (v.length > maxPasswordLength) return ValidationError.tooLong;
    if (_unsafeChars.hasMatch(v)) return ValidationError.invalidCharacters;
    final hasLetter = v.contains(RegExp('[A-Za-z]'));
    final hasDigit = v.contains(RegExp('[0-9]'));
    if (!hasLetter || !hasDigit) return ValidationError.weakPassword;
    return null;
  }

  static ValidationError? freeText(
    String? value, {
    bool required = true,
    int maxLength = maxFreeTextLength,
  }) {
    final v = sanitize(value ?? '');
    if (v.isEmpty) return required ? ValidationError.required : null;
    if (v.length > maxLength) return ValidationError.tooLong;
    return null;
  }

  /// IDs coming from deep links / URLs are untrusted input.
  static bool isSafeId(String? value) =>
      value != null && RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value);

  /// Prevents open redirects: only same-app relative paths are allowed.
  static bool isSafeInternalPath(String? value) {
    if (value == null || value.isEmpty || value.length > 512) return false;
    if (!value.startsWith('/') || value.startsWith('//')) return false;
    if (value.contains(r'\') || value.contains(_unsafeChars)) return false;
    final uri = Uri.tryParse(value);
    return uri != null && !uri.hasScheme && !uri.hasAuthority;
  }
}
