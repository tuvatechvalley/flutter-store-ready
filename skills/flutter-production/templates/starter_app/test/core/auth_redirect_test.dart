import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/router/app_router.dart';
import 'package:starter_app/features/auth/domain/user.dart';
import 'package:starter_app/features/auth/presentation/auth_controller.dart';

const _user = User(id: 'u', email: 'u@x.com', name: 'U');

String? _redirect(AuthState s, String location) =>
    authRedirect(s, Uri.parse(location));

void main() {
  test('unknown auth shows splash and remembers target', () {
    expect(_redirect(const AuthUnknown(), '/items'), '/splash');
    expect(
      _redirect(const AuthUnknown(), '/settings'),
      '/splash?from=%2Fsettings',
    );
    expect(_redirect(const AuthUnknown(), '/splash'), isNull);
  });

  test('signed out users are sent to login', () {
    expect(
      _redirect(const Unauthenticated(), '/items/item_1'),
      '/login?from=%2Fitems%2Fitem_1',
    );
    expect(_redirect(const Unauthenticated(), '/login'), isNull);
    expect(
      _redirect(const Unauthenticated(), '/splash?from=/settings'),
      '/login?from=%2Fsettings',
    );
  });

  test('signed in users never see login, and go back to target', () {
    expect(_redirect(const Authenticated(_user), '/login'), '/items');
    expect(
      _redirect(const Authenticated(_user), '/login?from=/settings'),
      '/settings',
    );
    expect(_redirect(const Authenticated(_user), '/items'), isNull);
  });

  test('open redirect attempts are ignored', () {
    for (final evil in ['//evil.com', 'https://evil.com', r'/\evil.com']) {
      final loc = Uri(
        path: '/login',
        queryParameters: {'from': evil},
      ).toString();
      expect(
        _redirect(const Authenticated(_user), loc),
        '/items',
        reason: evil,
      );
    }
  });
}
