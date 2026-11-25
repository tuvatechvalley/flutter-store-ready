import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/items/presentation/item_detail_page.dart';
import '../../features/items/presentation/items_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/app_shell.dart';
import '../l10n/app_localizations.dart';
import '../security/input_validators.dart';
import '../widgets/state_views.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const items = '/items';
  static const settings = '/settings';
  static const home = items;
}

/// Pure redirect logic: easy to unit test, no BuildContext needed.
///
/// * Unknown auth  → splash (remember target).
/// * Signed out    → login (remember target, only if it is a safe path).
/// * Signed in     → never show login/splash again.
String? authRedirect(AuthState auth, Uri location) {
  final path = location.path;
  final atAuthPage = path == Routes.login || path == Routes.splash;
  final from = location.queryParameters['from'];
  final safeFrom = InputValidators.isSafeInternalPath(from) ? from : null;

  switch (auth) {
    case AuthUnknown():
      if (path == Routes.splash) return null;
      return _withFrom(
        Routes.splash,
        atAuthPage ? safeFrom : location.toString(),
      );
    case Unauthenticated():
      if (path == Routes.login) return null;
      return _withFrom(
        Routes.login,
        atAuthPage ? safeFrom : location.toString(),
      );
    case Authenticated():
      if (!atAuthPage) return null;
      return safeFrom ?? Routes.home;
  }
}

String _withFrom(String target, String? from) {
  if (from == null ||
      !InputValidators.isSafeInternalPath(from) ||
      from == Routes.home) {
    return target;
  }
  return Uri(path: target, queryParameters: {'from': from}).toString();
}

/// Bridges Riverpod auth state to go_router's refreshListenable.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) =>
        authRedirect(ref.read(authControllerProvider), state.uri),
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.items,
                builder: (context, state) => const ItemsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final id = state.pathParameters['id'];
                      // Deep links are untrusted input.
                      if (!InputValidators.isSafeId(id)) {
                        return const NotFoundPage();
                      }
                      return ItemDetailPage(id: id!);
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: EmptyView(
        icon: Icons.explore_off_outlined,
        title: l10n.notFoundTitle,
        message: l10n.notFoundMessage,
        action: FilledButton(
          onPressed: () => context.go(Routes.home),
          child: Text(l10n.goHome),
        ),
      ),
    );
  }
}
