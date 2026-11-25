# Navigation, lifecycle and permissions

Bugs that pass every unit test and still make the app feel broken on a real phone. Each rule below comes from a bug found in a shipped app.

## 1. The Android back button goes up, not out

On a second-level page (opened from a tab, a "More" menu, a list) the system back button must return to the parent page. It may close the app only from the first page of the first tab.

- With `go_router`: use `StatefulShellRoute` for tabs and real child routes for nested pages. Do not push pages with `Navigator.push` on top of a shell and then handle back somewhere else.
- A `PopScope` only works on the route that is on top. One placed in the shell or the root is never reached when a nested page is open — put it on the page that needs it.
- Predictive back (Android 14+): never block back without telling the user why (unsaved form → confirm dialog).

Test it (required when the app has tabs or nested pages):

```dart
testWidgets('back from a nested page returns to its tab, not out of the app', (tester) async {
  await tester.pumpWidget(app);
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Invoices'));
  await tester.pumpAndSettle();

  final handled = await tester.binding.handlePopRoute(); // the system back button
  await tester.pumpAndSettle();

  expect(handled, isTrue, reason: 'false = the app would close');
  expect(find.text('More'), findsOneWidget);
});
```

## 2. Page transitions exist

After a router or Flutter upgrade, check that pages still animate. A router that does not recognize the app type silently falls back to pages without a transition and nothing fails. If it happens, build the pages yourself (`pageBuilder` returning `MaterialPage` / `CustomTransitionPage`) and keep a test:

```dart
await tester.tap(find.text('Settings'));
await tester.pump();                                  // start the transition
await tester.pump(const Duration(milliseconds: 100)); // halfway
expect(find.byType(HomePage), findsOneWidget, reason: 'old page still visible mid-transition');
expect(find.byType(SettingsPage), findsOneWidget);
await tester.pumpAndSettle();
expect(find.byType(HomePage), findsNothing);
```

## 3. An action must survive the widget that started it

A menu, bottom sheet or dialog is removed from the tree as soon as it closes. Code that runs after `await showDialog(...)` inside that menu sees `mounted == false` — and the usual `if (!mounted) return;` then skips the real work. Symptom: "Sign out" in a menu asks for confirmation and then does nothing.

- `if (!mounted) return;` protects **UI updates** (`setState`, `context`). It must never be the reason a business action is skipped.
- Start the action from something that lives as long as the app: a provider / notifier / bloc captured **before** the await (`final auth = ref.read(authProvider.notifier);`), or a root navigator key.
- After the action, navigate through the router (state change → redirect), not through the closed menu's `context`.
- Test sign-out, delete-account and every destructive action through the real menu, not by calling the controller directly.

## 4. Ask for a permission where it is used, and only from who needs it

- Never at launch, never in `main()`, never on the splash or login page. Ask when the user taps the feature, after one sentence that says why.
- Only for the role that needs it. If only field staff are tracked, an administrator must not even see the location prompt — and the server must reject location sent by other roles.
- Denied is a normal state: the feature explains what is missing and offers "Open settings"; the rest of the app keeps working.
- Background location, contacts, microphone: both stores check that the reason is visible in the app. Collect the minimum.

The audit flags permission requests found in the start-up files.

## 5. Background code is a second client

Push handlers, `workmanager` tasks, background location and foreground services run in a **separate isolate** with their own HTTP client and their own copy of the tokens.

- With rotating refresh tokens, two clients refreshing at the same moment looks like token theft: the server revokes the session and the user is signed out for no visible reason. Give background work **its own session** (a separate token pair or a scoped device token), or let it never refresh (skip the request, the app refreshes on next open).
- Sign-out ends both sessions.
- Never let recovery depend on a pair of events both arriving ("location off" … "location on"). Messages get lost: the newest healthy report must clear the old problem on its own.

## 6. Development servers

- Plain `http://` to a dev machine must work in **debug** on a real phone and be impossible in **release**. `scripts/harden_platforms.dart` writes `android/app/src/debug/res/xml/network_security_config.xml` (cleartext allowed, debug only) next to the strict release config. Do not set `usesCleartextTraffic="true"` in the main manifest.
- iOS: `NSAllowsLocalNetworking` in Info.plist covers local addresses without disabling App Transport Security.
- Alternative for Android without any config: `adb reverse tcp:8000 tcp:8000` and use `http://localhost:8000`.
- The API address comes from the build configuration (`--dart-define-from-file`), never from a string that is also compiled into release. The audit flags `localhost`, LAN and staging addresses that are not guarded by `kDebugMode` / `kReleaseMode`.

## 7. After upgrading dependencies

A major version of a plugin can break the build or change behavior silently. After any upgrade: build a release (`flutter build appbundle`), run the tests, open every tab on a device. If a new version breaks the build, pin the last working one (`permission_handler: 12.0.1`) and leave a comment with the reason.
