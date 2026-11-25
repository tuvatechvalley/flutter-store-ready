import '../storage/preferences_store.dart';
import '../storage/secure_store.dart';

/// Access + refresh token pair.
final class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  /// Never print tokens, even by accident.
  @override
  String toString() => 'AuthTokens(***)';
}

/// Persists tokens in [SecureStore] and caches the access token in memory.
final class TokenStore {
  TokenStore({required this._secureStore, required this._preferences});

  static const _accessKey = 'auth.access_token';
  static const _refreshKey = 'auth.refresh_token';
  static const _installMarkerKey = 'app.install_marker';

  final SecureStore _secureStore;
  final PreferencesStore _preferences;
  String? _cachedAccessToken;

  String? get cachedAccessToken => _cachedAccessToken;

  /// iOS Keychain survives app uninstall. Without this, a reinstalled app
  /// (or a phone sold to someone else) could silently log in as the previous
  /// user. Preferences are wiped on uninstall, so a missing marker means a
  /// fresh install: clear any stale secrets.
  Future<void> clearIfFreshInstall() async {
    final installed = await _preferences.getBool(_installMarkerKey) ?? false;
    if (installed) return;
    await _secureStore.deleteAll();
    await _preferences.setBool(_installMarkerKey, value: true);
  }

  Future<AuthTokens?> read() async {
    final access = await _secureStore.read(_accessKey);
    final refresh = await _secureStore.read(_refreshKey);
    if (access == null || refresh == null) return null;
    _cachedAccessToken = access;
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> save(AuthTokens tokens) async {
    await _secureStore.write(_accessKey, tokens.accessToken);
    await _secureStore.write(_refreshKey, tokens.refreshToken);
    _cachedAccessToken = tokens.accessToken;
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    await _secureStore.delete(_accessKey);
    await _secureStore.delete(_refreshKey);
  }
}
