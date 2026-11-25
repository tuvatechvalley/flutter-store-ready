import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/core/l10n/app_localizations.dart';
import 'package:starter_app/features/auth/data/auth_repository.dart';
import 'package:starter_app/features/items/presentation/items_page.dart';

import '../helpers/test_app.dart';

void main() {
  final l10n = AppLocalizations.forLocale(const Locale('en'));

  setUp(() {
    // Deterministic locale for text lookups.
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .localesTestValue = [
      const Locale('en'),
    ];
  });

  testWidgets('shows validation errors and does not submit invalid input', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.validationRequired), findsNWidgets(2));
  });

  testWidgets('wrong password shows a generic message (no user enumeration)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login.email')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login.password')),
      'Wrong1234',
    );
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login.error')), findsOneWidget);
    expect(find.text(l10n.invalidCredentials), findsOneWidget);
  });

  testWidgets('valid credentials navigate to the items list', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('login.email')),
      FakeAuthRepository.demoEmail,
    );
    await tester.enterText(
      find.byKey(const Key('login.password')),
      FakeAuthRepository.demoPassword,
    );
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
    expect(find.byType(ItemsPage), findsOneWidget);
  });
}
