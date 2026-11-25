import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:starter_app/app.dart';
import 'package:starter_app/core/config/env.dart';
import 'package:starter_app/core/providers.dart';
import 'package:starter_app/core/storage/preferences_store.dart';
import 'package:starter_app/core/storage/secure_store.dart';
import 'package:starter_app/features/auth/data/auth_repository.dart';
import 'package:starter_app/features/items/data/items_repository.dart';

final testEnv = Env.parse(
  flavor: 'dev',
  apiBaseUrl: 'https://api.example.com',
  sentryDsn: '',
  certificatePins: '',
  useMockApi: true,
  isReleaseBuild: false,
  privacyPolicyUrl: 'https://example.com/privacy',
);

/// Overrides that make the whole app run without platform channels/network.
List<Override> testOverrides({
  AuthRepository? auth,
  ItemsRepository? items,
  PreferencesStore? preferences,
  SecureStore? secureStore,
  DateTime Function()? clock,
}) => [
  envProvider.overrideWithValue(testEnv),
  secureStoreProvider.overrideWithValue(secureStore ?? InMemorySecureStore()),
  preferencesStoreProvider.overrideWithValue(
    preferences ?? InMemoryPreferencesStore(),
  ),
  authRepositoryProvider.overrideWithValue(
    auth ?? FakeAuthRepository(latency: Duration.zero),
  ),
  itemsRepositoryProvider.overrideWithValue(
    items ?? FakeItemsRepository(latency: Duration.zero),
  ),
  if (clock != null) clockProvider.overrideWithValue(clock),
];

/// [overrides] replaces the defaults (like [pumpApp]); build it with
/// [testOverrides] to change one dependency. Riverpod 3 rejects a provider
/// that is overridden twice, so defaults and extras are never concatenated.
ProviderContainer createTestContainer({List<Override>? overrides}) {
  final container = ProviderContainer(
    overrides: overrides ?? testOverrides(),
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> pumpApp(WidgetTester tester, {List<Override>? overrides}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides ?? testOverrides(),
      retry: (_, _) => null,
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Stores tokens so the app starts signed in.
Future<SecureStore> signedInStore() async {
  final store = InMemorySecureStore();
  await store.write('auth.access_token', 'fake-access-0');
  await store.write('auth.refresh_token', 'fake-refresh-0');
  return store;
}

/// Preferences of an existing install (so tokens are not wiped).
InMemoryPreferencesStore existingInstallPrefs([Map<String, Object>? extra]) =>
    InMemoryPreferencesStore({'app.install_marker': true, ...?extra});
