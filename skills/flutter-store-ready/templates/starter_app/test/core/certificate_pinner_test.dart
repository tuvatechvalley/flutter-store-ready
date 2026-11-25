import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/network/certificate_pinner.dart';

/// Self-signed EC certificate for CN=api.example.com (test fixture only).
const _certB64 =
    'MIIBiDCCAS+gAwIBAgIUTf/36UqiYsFznh4Q9bgH/l/ZXD4wCgYIKoZIzj0EAwIwGjEYMBYGA1UEAwwPYXBpLmV4YW1wbGUuY29tMB4XDTI2MTEyNTE0MTA0OFoXDTI3MTEyNTE0MTA0OFowGjEYMBYGA1UEAwwPYXBpLmV4YW1wbGUuY29tMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE2a4ZYVnxvtEVW+aQySCIXIXvKY3JZIOfPLtrZDS3MZFji2po0G/HMAy4gccx7vKhc88B+h6uGuVOKReQJb9KzKNTMFEwHQYDVR0OBBYEFLCAHWyhDaa9f1SmtNzQYYrnPGpXMB8GA1UdIwQYMBaAFLCAHWyhDaa9f1SmtNzQYYrnPGpXMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDRwAwRAIgdUAv9mgGmKM9LjSbINQw/RerDwF1cRc0hV7zOp+lqcECIHsbWs20bmgfE2qc07OYYVUM79p04M0/xTwpmYnhPMgz';

/// Computed independently with:
/// openssl x509 -pubkey -noout | openssl pkey -pubin -outform der |
/// openssl dgst -sha256 -binary | base64
const _expectedPin = 'uqJAWHpktj4ILvvbvNEKgmdcjT8dEyVluBSCwW3xtMc=';
const _otherPin = 'kygF0zI+1SEzkcGWkzYEq8jlbMJ6MIyFsjh736Y2/4w=';

void main() {
  final der = base64.decode(_certB64);

  test('SPKI hash matches the value computed by openssl', () {
    final spki = CertificatePinner.extractSubjectPublicKeyInfo(der);
    expect(spki, isNotNull);
    expect(CertificatePinner.pinForSpki(spki!), _expectedPin);
  });

  test('accepts pinned key, with or without sha256/ prefix', () {
    expect(CertificatePinner(['sha256/$_expectedPin']).matches(der), isTrue);
    expect(CertificatePinner([_otherPin, _expectedPin]).matches(der), isTrue);
  });

  test('rejects a certificate whose key is not pinned', () {
    expect(CertificatePinner([_otherPin]).matches(der), isFalse);
  });

  test('never accepts malformed input', () {
    final pinner = CertificatePinner([_expectedPin]);
    expect(pinner.matches(Uint8List(0)), isFalse);
    expect(
      pinner.matches(Uint8List.sublistView(der, 0, der.length ~/ 2)),
      isFalse,
    );
    expect(
      pinner.matches(Uint8List.fromList([0x30, 0x84, 0xff, 0xff, 0xff, 0xff])),
      isFalse,
    );
  });

  test('rejects pins that are not base64 SHA-256 hashes', () {
    expect(
      () => CertificatePinner.normalizePin('not-base64!'),
      throwsFormatException,
    );
    expect(
      () => CertificatePinner.normalizePin(base64.encode([1, 2, 3])),
      throwsFormatException,
    );
  });
}
