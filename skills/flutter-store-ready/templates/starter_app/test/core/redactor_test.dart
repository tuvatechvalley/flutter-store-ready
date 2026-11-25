import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/logging/redactor.dart';

void main() {
  test('removes secrets and personal data', () {
    final out = Redactor.redact(
      'Authorization: Bearer abc.def-123 user=ali@x.com '
      '{"password":"hunter2","token": "t0k"} api_key=K3Y '
      'card 4111 1111 1111 1234 '
      'jwt eyJhbGciOiJIUzI1.eyJzdWIiOiIxMjM0.c2lnbmF0dXJlMTIz',
    );
    for (final secret in [
      'abc.def-123',
      'ali@x.com',
      'hunter2',
      't0k',
      'K3Y',
      '4111 1111',
      'eyJzdWIiOiIxMjM0',
    ]) {
      expect(out, isNot(contains(secret)), reason: secret);
    }
    expect(out, contains('1234'), reason: 'last 4 digits are kept');
  });

  test('redactUrl keeps only scheme, host, port and path', () {
    expect(
      Redactor.redactUrl(Uri.parse('https://a.com/x?token=1#f')),
      'https://a.com/x',
    );
    expect(
      Redactor.redactUrl(Uri.parse('https://u:p@a.com:8443/y')),
      'https://a.com:8443/y',
    );
  });
}
