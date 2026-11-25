import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:starter_app/features/items/presentation/item_detail_page.dart';
import 'package:starter_app/features/items/presentation/items_page.dart';

import 'helpers/test_app.dart';

/// Navigation regressions that unit tests and screenshots do not catch:
///
/// * Pages must animate. After a router or Flutter upgrade, a router that
///   does not recognize the app silently builds pages without a transition.
/// * The Android back button must go up one level, never close the app from
///   a nested page.
///
/// See NAVIGATION-AND-LIFECYCLE.md in the flutter-store-ready skill.
void main() {
  Future<void> pumpSignedIn(WidgetTester tester) async {
    await pumpApp(
      tester,
      overrides: testOverrides(
        secureStore: await signedInStore(),
        preferences: existingInstallPrefs(),
      ),
    );
    expect(find.byType(ItemsPage), findsOneWidget);
  }

  testWidgets('opening a page is animated (both pages visible mid-way)', (
    tester,
  ) async {
    await pumpSignedIn(tester);

    GoRouter.of(tester.element(find.byType(ItemsPage))).go('/items/item_1');
    await tester.pump(); // start the transition
    await tester.pump(const Duration(milliseconds: 50)); // part-way through

    expect(
      find.byType(ItemsPage),
      findsOneWidget,
      reason: 'the previous page must still be on screen during the transition',
    );
    expect(find.byType(ItemDetailPage), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailPage), findsOneWidget);
    expect(
      find.byType(ItemsPage),
      findsNothing,
      reason: 'covered once the transition ends',
    );
  });

  testWidgets('system back from a detail page returns to the list', (
    tester,
  ) async {
    await pumpSignedIn(tester);
    GoRouter.of(tester.element(find.byType(ItemsPage))).go('/items/item_1');
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailPage), findsOneWidget);

    // What the Android back button does.
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue, reason: 'false = the app would close');
    expect(find.byType(ItemsPage), findsOneWidget);
    expect(find.byType(ItemDetailPage), findsNothing);
  });
}
