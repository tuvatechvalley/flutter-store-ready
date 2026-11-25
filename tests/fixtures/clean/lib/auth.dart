class Auth {
  Auth(this._storage);

  final FlutterSecureStorage _storage;

  Future<void> login(String email, String password) async {
    final r = await dio.post('/auth/login', data: {'e': email, 'p': password});
    await _storage.write(key: 'access', value: r.data['access'] as String);
  }

  Future<void> register(String email, String password) =>
      dio.post('/auth/register', data: {'e': email, 'p': password});

  Future<void> deleteAccount() async {
    await dio.delete('/account');
    await _storage.deleteAll();
  }
}
