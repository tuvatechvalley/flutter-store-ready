import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:starter_app/core/l10n/app_localizations.dart';
import 'package:starter_app/core/responsive/breakpoints.dart';
import 'package:starter_app/core/responsive/text_scaling.dart';
import 'package:starter_app/core/router/app_router.dart';
import 'package:starter_app/features/items/presentation/items_page.dart';
import 'package:starter_app/features/settings/presentation/settings_page.dart';

import 'helpers/test_app.dart';

/// "When I make the text bigger, it must actually get bigger — and the page
/// must not break."
void main() {
  final en = AppLocalizations.forLocale(const Locale('en'));

  Future<void> setUpDevice(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool bold = false,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher
      ..textScaleFactorTestValue = textScale
      ..localesTestValue = [const Locale('en')]
      ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
        boldText: bold,
      );
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  double renderedScale(WidgetTester tester, String text) =>
      tester
          .renderObject<RenderParagraph>(find.text(text))
          .textScaler
          .scale(14) /
      14;

  group('TextScaling', () {
    test('multiplies the system scaler and caps it at 3x', () {
      expect(
        TextScaling.combine(const TextScaler.linear(2), 1.3).scale(10),
        closeTo(26, 0.001),
      );
      expect(
        TextScaling.combine(const TextScaler.linear(2.5), 1.5).scale(10),
        30,
        reason: 'capped at maxScaleFactor',
      );
      expect(
        TextScaling.combine(const TextScaler.linear(0.85), 1).scale(10),
        closeTo(8.5, 0.001),
        reason: 'small system fonts are respected too',
      );
    });

    test('large text switches to the roomier layout', () {
      expect(WindowSize.fromWidth(1024), WindowSize.expanded);
      // WindowSize.of divides the width by the text scale: 1024 / 2 = 512.
      expect(WindowSize.fromWidth(1024 / 2), WindowSize.compact);
    });
  });

  testWidgets('system font size is applied to the UI (2x → 2x text)', (
    tester,
  ) async {
    await setUpDevice(tester, textScale: 2);
    await pumpApp(tester);
    expect(renderedScale(tester, en.signIn), closeTo(2, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-app text size multiplies the system size and persists', (
    tester,
  ) async {
    await setUpDevice(tester, textScale: 1.5);
    final prefs = existingInstallPrefs();
    await pumpApp(
      tester,
      overrides: testOverrides(
        secureStore: await signedInStore(),
        preferences: prefs,
      ),
    );
    GoRouter.of(tester.element(find.byType(ItemsPage))).go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    // Pick "Largest" (1.5x) → 1.5 (system) × 1.5 (app) = 2.25x.
    final largest = find.byKey(const Key('settings.textScale.3'));
    await tester.ensureVisible(largest);
    await tester.tap(largest);
    await tester.pumpAndSettle();

    final preview = find.text(en.textSizePreview);
    await tester.ensureVisible(preview);
    expect(renderedScale(tester, en.textSizePreview), closeTo(2.25, 0.01));
    expect(await prefs.getString('settings.text_scale'), '1.5');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tablet with 2x text uses phone layout instead of a cramped grid',
    (tester) async {
      await setUpDevice(tester, size: const Size(1024, 1366), textScale: 2);
      await pumpApp(
        tester,
        overrides: testOverrides(
          secureStore: await signedInStore(),
          preferences: existingInstallPrefs(),
        ),
      );
      final context = tester.element(find.byType(ItemsPage));
      expect(WindowSize.of(context), WindowSize.compact);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('3x text + bold text on the smallest phone does not break', (
    tester,
  ) async {
    await setUpDevice(
      tester,
      size: const Size(320, 568),
      textScale: 3,
      bold: true,
    );
    await pumpApp(
      tester,
      overrides: testOverrides(
        secureStore: await signedInStore(),
        preferences: existingInstallPrefs(),
      ),
    );
    final router = GoRouter.of(tester.element(find.byType(ItemsPage)));
    for (final route in ['/items/item_1', Routes.settings, Routes.items]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
  });
}
