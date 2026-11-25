import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:starter_app/core/router/app_router.dart';
import 'package:starter_app/features/auth/presentation/login_page.dart';
import 'package:starter_app/features/items/presentation/item_detail_page.dart';
import 'package:starter_app/features/items/presentation/items_page.dart';
import 'package:starter_app/features/settings/presentation/settings_page.dart';

import 'helpers/test_app.dart';

/// Responsive QA gate.
///
/// Every main screen is rendered on small/large phones, landscape, foldables
/// and tablets, with the phone's font size at 1x, 1.5x, 2x and 3x (largest
/// iOS accessibility size), in both languages. Any RenderFlex overflow or
/// layout exception fails the test, so "yellow-black stripes" or clipped
/// pages can never ship.
const _sizes = <String, Size>{
  'small phone 320x568': Size(320, 568),
  'phone 390x844': Size(390, 844),
  'phone landscape 844x390': Size(844, 390),
  'foldable 673x841': Size(673, 841),
  'tablet 1024x1366': Size(1024, 1366),
};
const _textScales = [1.0, 1.5, 2.0, 3.0];
const _locales = [Locale('tr'), Locale('en')];

Future<void> _setUp(
  WidgetTester tester,
  Size size,
  double scale,
  Locale locale,
) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher
    ..textScaleFactorTestValue = scale
    ..localesTestValue = [locale];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
}

void main() {
  for (final MapEntry(key: name, value: size) in _sizes.entries) {
    for (final scale in _textScales) {
      for (final locale in _locales) {
        final label = '$name, text x$scale, ${locale.languageCode}';

        testWidgets('login renders without overflow: $label', (tester) async {
          await _setUp(tester, size, scale, locale);
          await pumpApp(tester);
          expect(find.byType(LoginPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testWidgets('signed-in screens render without overflow: $label', (
          tester,
        ) async {
          await _setUp(tester, size, scale, locale);
          await pumpApp(
            tester,
            overrides: testOverrides(
              secureStore: await signedInStore(),
              preferences: existingInstallPrefs(),
            ),
          );
          expect(find.byType(ItemsPage), findsOneWidget);
          expect(tester.takeException(), isNull);

          final router = GoRouter.of(tester.element(find.byType(ItemsPage)));
          router.go('/items/item_1');
          await tester.pumpAndSettle();
          expect(find.byType(ItemDetailPage), findsOneWidget);
          expect(tester.takeException(), isNull);

          router.go(Routes.settings);
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          expect(tester.takeException(), isNull);

          router.go('/does-not-exist');
          await tester.pumpAndSettle();
          expect(find.byType(NotFoundPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
