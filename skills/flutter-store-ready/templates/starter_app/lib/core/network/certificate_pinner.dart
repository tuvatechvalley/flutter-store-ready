import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Public-key (SPKI) certificate pinning.
///
/// A pin is `base64(sha256(SubjectPublicKeyInfo))` — the same format used by
/// OkHttp, TrustKit and HPKP. Pinning the public key (not the whole
/// certificate) keeps working when the certificate is renewed with the same
/// key. Always ship at least two pins: the current key and a backup key that
/// is stored offline, otherwise a key rotation bricks every installed app.
///
/// Generate a pin:
/// ```sh
/// openssl s_client -connect api.example.com:443 -servername api.example.com </dev/null \
///   | openssl x509 -pubkey -noout \
///   | openssl pkey -pubin -outform der \
///   | openssl dgst -sha256 -binary | base64
/// ```
final class CertificatePinner {
  CertificatePinner(Iterable<String> pins)
    : _pins = pins.map(normalizePin).toSet();

  final Set<String> _pins;

  bool get isEnabled => _pins.isNotEmpty;

  /// Returns true when the DER-encoded certificate's public key is pinned.
  bool matches(Uint8List certificateDer) {
    final spki = extractSubjectPublicKeyInfo(certificateDer);
    if (spki == null) return false;
    return _pins.contains(pinForSpki(spki));
  }

  static String pinForSpki(Uint8List spki) =>
      base64.encode(sha256.convert(spki).bytes);

  /// Accepts `sha256/<base64>` or bare base64 and validates the hash length.
  static String normalizePin(String raw) {
    var pin = raw.trim();
    if (pin.startsWith('sha256/')) pin = pin.substring('sha256/'.length);
    final Uint8List bytes;
    try {
      bytes = base64.decode(pin);
    } on FormatException {
      throw FormatException('Pin is not valid base64: "$raw"');
    }
    if (bytes.length != 32) {
      throw FormatException('Pin must be a SHA-256 hash (32 bytes): "$raw"');
    }
    return base64.encode(bytes);
  }

  /// Extracts the SubjectPublicKeyInfo element from an X.509 certificate.
  ///
  /// Returns null for anything that is not a well-formed certificate, so a
  /// malformed certificate can never be accepted.
  static Uint8List? extractSubjectPublicKeyInfo(Uint8List der) {
    try {
      final certificate = _readTlv(der, 0);
      if (certificate.tag != _sequence) return null;

      final tbs = _readTlv(der, certificate.contentStart);
      if (tbs.tag != _sequence) return null;
      final tbsEnd = tbs.end;

      var offset = tbs.contentStart;
      var element = _readTlv(der, offset);
      if (element.tag == _explicitVersionTag) {
        offset = element.end;
      }
      // serialNumber, signature, issuer, validity, subject
      for (var i = 0; i < 5; i++) {
        element = _readTlv(der, offset);
        offset = element.end;
        if (offset > tbsEnd) return null;
      }

      final spki = _readTlv(der, offset);
      if (spki.tag != _sequence || spki.end > tbsEnd) return null;
      return Uint8List.sublistView(der, offset, spki.end);
    } on FormatException {
      return null;
    }
  }

  static const int _sequence = 0x30;
  static const int _explicitVersionTag = 0xA0;

  static _Tlv _readTlv(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 2 > bytes.length) {
      throw const FormatException('Truncated DER');
    }
    final tag = bytes[offset];
    final lengthByte = bytes[offset + 1];
    var position = offset + 2;
    var length = 0;
    if (lengthByte < 0x80) {
      length = lengthByte;
    } else {
      final count = lengthByte & 0x7F;
      if (count == 0 || count > 4) {
        throw const FormatException('Unsupported DER length');
      }
      for (var i = 0; i < count; i++) {
        if (position >= bytes.length) {
          throw const FormatException('Truncated DER length');
        }
        length = (length << 8) | bytes[position++];
      }
    }
    final end = position + length;
    if (end > bytes.length) throw const FormatException('Truncated DER value');
    return _Tlv(tag: tag, contentStart: position, end: end);
  }
}

final class _Tlv {
  const _Tlv({
    required this.tag,
    required this.contentStart,
    required this.end,
  });

  final int tag;
  final int contentStart;
  final int end;
}
