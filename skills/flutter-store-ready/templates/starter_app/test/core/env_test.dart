import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/config/env.dart';

const _pinA = 'uqJAWHpktj4ILvvbvNEKgmdcjT8dEyVluBSCwW3xtMc=';
const _pinB = 'kygF0zI+1SEzkcGWkzYEq8jlbMJ6MIyFsjh736Y2/4w=';

Env _parse({
  String flavor = 'prod',
  String url = 'https://api.example.com',
  String pins = '$_pinA,$_pinB',
  bool mock = false,
  bool release = true,
  String privacy = 'https://example.com/privacy',
}) => Env.parse(
  flavor: flavor,
  apiBaseUrl: url,
  sentryDsn: '',
  certificatePins: pins,
  useMockApi: mock,
  isReleaseBuild: release,
  privacyPolicyUrl: privacy,
);

void main() {
  test('valid production config', () {
    final env = _parse();
    expect(env.isProd, isTrue);
    expect(env.certificatePins, hasLength(2));
  });

  test('rejects http outside dev', () {
    expect(
      () => _parse(url: 'http://api.example.com'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => _parse(flavor: 'dev', url: 'http://10.0.2.2:8080'),
      throwsA(isA<ConfigException>()),
      reason: 'release builds are always https',
    );
  });

  test('allows http for local dev debug builds', () {
    final env = _parse(
      flavor: 'dev',
      url: 'http://10.0.2.2:8080',
      pins: '',
      mock: true,
      release: false,
    );
    expect(env.apiBaseUrl.scheme, 'http');
  });

  test('prod requires two pins and a real backend', () {
    expect(() => _parse(pins: _pinA), throwsA(isA<ConfigException>()));
    expect(() => _parse(mock: true), throwsA(isA<ConfigException>()));
  });

  test('prod requires an https privacy policy URL', () {
    expect(() => _parse(privacy: ''), throwsA(isA<ConfigException>()));
    expect(
      () => _parse(privacy: 'http://example.com/privacy'),
      throwsA(isA<ConfigException>()),
    );
  });

  test('rejects malformed values', () {
    expect(() => _parse(flavor: 'production'), throwsA(isA<ConfigException>()));
    expect(
      () => _parse(url: 'api.example.com'),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => _parse(url: 'https://u:p@api.example.com'),
      throwsA(isA<ConfigException>()),
    );
    expect(() => _parse(pins: 'abc,$_pinB'), throwsA(isA<ConfigException>()));
  });
}
