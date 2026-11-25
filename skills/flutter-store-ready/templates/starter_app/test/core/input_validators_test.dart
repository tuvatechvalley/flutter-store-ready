import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/security/input_validators.dart';

void main() {
  group('email', () {
    test(
      'valid',
      () => expect(InputValidators.email(' user@mail.com '), isNull),
    );
    test(
      'required',
      () => expect(InputValidators.email('  '), ValidationError.required),
    );
    test('invalid', () {
      for (final v in [
        'user@',
        '@mail.com',
        'a b@c.com',
        'user@mail',
        'u@-x.com',
      ]) {
        expect(
          InputValidators.email(v),
          ValidationError.invalidEmail,
          reason: v,
        );
      }
    });
    test('too long', () {
      final long = '${'a' * 250}@x.com';
      expect(InputValidators.email(long), ValidationError.tooLong);
    });
  });

  group('password', () {
    test('valid', () => expect(InputValidators.password('Demo1234'), isNull));
    test(
      'too short',
      () => expect(InputValidators.password('ab1'), ValidationError.tooShort),
    );
    test(
      'weak',
      () => expect(
        InputValidators.password('abcdefgh'),
        ValidationError.weakPassword,
      ),
    );
    test('bidi override rejected', () {
      expect(
        InputValidators.password('Demo1234\u202E'),
        ValidationError.invalidCharacters,
      );
    });
  });

  test('sanitize removes control and zero-width characters', () {
    expect(InputValidators.sanitize(' a\u200Bb\u0007\uFEFF '), 'ab');
  });

  test('isSafeId', () {
    expect(InputValidators.isSafeId('item_12'), isTrue);
    for (final v in [null, '', '../etc', 'a/b', 'x' * 65, 'id%2F']) {
      expect(InputValidators.isSafeId(v), isFalse, reason: '$v');
    }
  });

  test('isSafeInternalPath blocks open redirects', () {
    expect(InputValidators.isSafeInternalPath('/items/1?x=2'), isTrue);
    for (final v in [
      null,
      '',
      'items',
      '//evil.com',
      'https://evil.com',
      r'/\evil.com',
      '/a\u202E',
    ]) {
      expect(InputValidators.isSafeInternalPath(v), isFalse, reason: '$v');
    }
  });
}
