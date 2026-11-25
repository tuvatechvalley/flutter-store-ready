// planted: LAN address that also ships in release
const baseUrl = 'http://192.168.1.20:8000';

class Api {
  // planted: tokens in a plain Hive box
  Box get _auth => Hive.box('auth');
  String? get accessToken => _auth.get('access') as String?;
  String? get refreshToken => _auth.get('refresh') as String?;

  Future<void> login(String email, String password) async {
    final r = await dio.post('/auth/login', data: {'e': email, 'p': password});
    await _auth.put('access', r.data['access']);
  }

  Future<void> register(String email, String password) async {
    try {
      await dio.post('/auth/register', data: {'e': email, 'p': password});
    } catch (_) {}
    debugPrint('registered');
  }
}
